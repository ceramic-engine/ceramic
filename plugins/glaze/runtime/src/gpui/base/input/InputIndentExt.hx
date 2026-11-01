// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/indent.rs (`impl InputBaseState` blocks,
// `impl TextElement` block)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Bounds;
import gpui.Context;
import gpui.Hsla;
import gpui.Path;
import gpui.PathBuilder;
import gpui.Point;
import gpui.Range;
import gpui.TextRun;
import gpui.TextStyle;
import gpui.Window;

import gpui.base.input.InputActions;

using gpui.base.input.RopeExt;

/**
 * A text edit of a batch (Rust tuple `(Range<usize>, String)`).
 */
class RangeEdit {

    public final range:Range;

    public final text:String;

    public inline function new(range:Range, text:String) {
        this.range = range;
        this.text = text;
    }

}

/**
 * The direction of an indent operation.
 */
enum abstract IndentDirection(Int) {

    var Indent = 0;

    var Outdent = 1;

}

/**
 * The indentation methods of `InputBaseState` (Rust `impl InputBaseState`
 * blocks of `indent.rs`), as static extensions: see `InputSearchExt`.
 *
 * - `tabSize` / `setTabSize` belong to the multi-line modes (Rust
 *   `impl<M: MultiLineMode>`), `indentGuides` / `setIndentGuides` to the
 *   editor (`impl InputBaseState<EditorMode>`);
 * - `measureIndentWidth` / `layoutIndentGuides` are Rust `TextElement`
 *   methods that do not read the element: they take the state instead.
 *
 * The state is read through the Rust fields (`text`, `selections`, `mode`,
 * `undoManager`) and methods (`isEditable`, `isMultiLine`,
 * `replaceTextInRanges`, `scrollTo`, `cursor`), named like the Rust ones.
 */
@:access(gpui.base.input.InputBaseState)
@:access(gpui.base.input.LayoutMode)
class InputIndentExt {

/// impl<M: InputModeKind> TextElement<M>

    /** Measure the indent width in pixels for given column count. */
    public static function measureIndentWidth(style:TextStyle, column:Int, window:Window):Float {
        final fontSize = gpui.AbsoluteLengthTools.toPixels(style.fontSize, window.remSize());
        final layout = window.textSystem().shapeLine(StringTools.lpad('', ' ', column), fontSize, [new TextRun(column, style.font(), new Hsla())]);

        return layout.width();
    }

    public static function layoutIndentGuides(state:InputBaseState, bounds:Bounds, lastLayout:LastLayout, textStyle:TextStyle, window:Window):Null<Path> {
        if (!state.isMultiLine() || !state.mode.hasIndentGuides())
            return null;

        final indentWidth = measureIndentWidth(textStyle, state.mode.tabSize().tabSize, window);

        final tabSize = state.mode.tabSize();
        final lineHeight:Float = lastLayout.lineHeight;
        final builder = PathBuilder.stroke(1.);
        var offsetY:Float = lastLayout.visibleTop;
        var lastIndents:Array<Float> = [];

        final count = lastLayout.visibleBufferLines.length < lastLayout.lines.length ? lastLayout.visibleBufferLines.length : lastLayout.lines.length;
        for (i in 0...count) {
            final bufferLine = lastLayout.visibleBufferLines[i];
            final lineLayout = lastLayout.lines[i];
            final line = state.text.sliceLine(bufferLine);
            var currentIndents:Array<Float> = [];
            if (line.len() > 0) {
                final indentCount = tabSize.indentCount(line);
                // (0..indent_count).step_by(tab_size): `step_by(0)` panics in Rust
                if (tabSize.tabSize == 0)
                    throw 'assertion failed: step != 0';
                var offset = 0;
                while (offset < indentCount) {
                    final x = indentCount > 0 ? indentWidth * offset / tabSize.tabSize : 0.0;

                    final pos = new Point(x + lastLayout.lineNumberWidth, offsetY);

                    builder.moveTo(pos);
                    builder.lineTo(new Point(pos.x, pos.y + lineHeight));
                    currentIndents.push(pos.x);
                    offset += tabSize.tabSize;
                }
            }
            else if (lastIndents.length > 0) {
                for (x in lastIndents) {
                    final pos = new Point(x, offsetY);
                    builder.moveTo(pos);
                    builder.lineTo(new Point(pos.x, pos.y + lineHeight));
                }
                currentIndents = lastIndents.copy();
            }

            offsetY += lineLayout.wrappedLines.length * lineHeight;
            lastIndents = currentIndents;
        }

        builder.translate(bounds.origin);
        return builder.build();
    }

/// impl InputBaseState<EditorMode>

    /** Set whether to show indent guides, default is true. */
    public static function indentGuides(self:InputBaseState, indentGuides:Bool):InputBaseState {
        if (self.mode.kind == CodeEditor)
            self.mode.indentGuides = indentGuides;
        return self;
    }

    /** Set indent guides at runtime. */
    public static function setIndentGuides(self:InputBaseState, indentGuides:Bool, window:Window, cx:Context<InputBaseState>):Void {
        if (self.mode.kind == CodeEditor)
            self.mode.indentGuides = indentGuides;
        cx.notify();
    }

/// impl<M: MultiLineMode> InputBaseState<M>

    /** Set the tab size for the input. */
    public static function tabSize(self:InputBaseState, tab:TabSize):InputBaseState {
        self.mode.setTabSize(tab);
        return self;
    }

    public static function setTabSize(self:InputBaseState, tab:TabSize, cx:Context<InputBaseState>):Void {
        self.mode.setTabSize(tab);
        cx.notify();
    }

/// impl<M: InputModeKind> InputBaseState<M>

    public static function indentInline(self:InputBaseState, action:IndentInline, window:Window, cx:Context<InputBaseState>):Void {
        // First, try to accept inline completion if present
        if (self.modeKind.acceptInlineCompletion(self, window, cx))
            return;
        indent(self, false, window, cx);
    }

    public static function indentBlock(self:InputBaseState, action:Indent, window:Window, cx:Context<InputBaseState>):Void {
        indent(self, true, window, cx);
    }

    public static function outdentInline(self:InputBaseState, action:OutdentInline, window:Window, cx:Context<InputBaseState>):Void {
        outdent(self, false, window, cx);
    }

    public static function outdentBlock(self:InputBaseState, action:Outdent, window:Window, cx:Context<InputBaseState>):Void {
        outdent(self, true, window, cx);
    }

    public static function indent(self:InputBaseState, block:Bool, window:Window, cx:Context<InputBaseState>):Void {
        applyIndent(self, IndentDirection.Indent, block, window, cx);
    }

    public static function outdent(self:InputBaseState, block:Bool, window:Window, cx:Context<InputBaseState>):Void {
        applyIndent(self, IndentDirection.Outdent, block, window, cx);
    }

    /**
     * Apply an indent or outdent across all selections as one batch edit.
     *
     * A batch keeps the whole operation a single undo transaction (instead of
     * one push per line) and restores the correct multi-selection extents on
     * undo/redo.
     */
    static function applyIndent(self:InputBaseState, direction:IndentDirection, block:Bool, window:Window, cx:Context<InputBaseState>):Void {
        if (!self.isEditable() || !self.isMultiLine() || !self.mode.isIndentable()) {
            cx.propagate();
            return;
        }

        final tabIndent = self.mode.tabSize().toString();
        final tabLen = gpui.util.Utf8.byteLength(tabIndent);

        // Non-collapsed selections and explicit block operations indent whole lines.
        var hasNonCollapsed = false;
        for (sel in self.selections.iter()) {
            if (!sel.isCollapsed())
                hasNonCollapsed = true;
        }
        final useBlock = hasNonCollapsed || block;

        final before = [for (sel in self.selections.iter()) sel.copy()];

        final edits:Array<RangeEdit> = [];
        final newSelections = useBlock ? computeBlockIndent(self, direction, tabIndent, tabLen, edits) : computeInlineIndent(self, direction, tabLen, edits);

        if (edits.length == 0)
            return;

        self.undoManager.beginTransaction();
        self.replaceTextInRanges(edits, window, cx);
        self.selections.replaceAll(newSelections);
        final after = [for (sel in self.selections.iter()) sel.copy()];
        self.undoManager.recordSelections(before, after);
        self.undoManager.commitTransaction();

        self.scrollTo(self.cursor(), null, cx);
        cx.notify();
    }

    /** `rope.slice(start..).chars().take(n).eq(indent.chars())` */
    static function startsWithIndent(self:InputBaseState, start:Int, tabIndent:String):Bool {
        final chars = self.text.charsAt(start);
        for (i in 0...tabIndent.length) {
            final c = chars.next();
            if (c != StringTools.fastCodeAt(tabIndent, i))
                return false;
        }
        return true;
    }

    /**
     * Build the per-line edits (into `edits`) and return the resulting
     * selections for a block indent/outdent across every selection.
     */
    static function computeBlockIndent(self:InputBaseState, direction:IndentDirection, tabIndent:String, tabLen:Int, edits:Array<RangeEdit>):Array<CursorSelection> {
        final rowSet = new Map<Int, Bool>();
        for (sel in self.selections.iter()) {
            final startRow = self.text.offsetToPoint(sel.start).row;
            final endRow = self.text.offsetToPoint(sel.end).row;
            for (row in startRow...endRow + 1)
                rowSet.set(row, true);
        }

        final rows = [for (row in rowSet.keys()) row];
        rows.sort((a, b) -> a - b);

        for (row in rows) {
            final lineStart = self.text.lineStartOffset(row);
            switch direction {
                case IndentDirection.Indent:
                    edits.push(new RangeEdit(new Range(lineStart, lineStart), tabIndent));
                case IndentDirection.Outdent:
                    if (startsWithIndent(self, lineStart, tabIndent))
                        edits.push(new RangeEdit(new Range(lineStart, lineStart + tabLen), ''));
            }
        }

        // Map both endpoints through every earlier edit, including edits belonging
        // to other cursors. A point inside removed indentation stays on its line.
        final mapOffset = (offset:Int) -> switch direction {
            case IndentDirection.Indent:
                var count = 0;
                while (count < edits.length && edits[count].range.start <= offset)
                    count++;
                offset + count * tabLen;
            case IndentDirection.Outdent:
                var preceding = 0;
                while (preceding < edits.length && edits[preceding].range.end <= offset)
                    preceding++;
                final partial = preceding < edits.length ? (offset > edits[preceding].range.start ? offset - edits[preceding].range.start : 0) : 0;
                offset - preceding * tabLen - partial;
        }
        return [for (sel in self.selections.iter()) {
            final selection = sel.copy();
            selection.start = mapOffset(sel.start);
            selection.end = mapOffset(sel.end);
            selection.columnAnchor = null;
            selection;
        }];
    }

    /**
     * Build the per-cursor edits (into `edits`) and return the resulting
     * cursors for a collapsed inline indent/outdent.
     */
    static function computeInlineIndent(self:InputBaseState, direction:IndentDirection, tabLen:Int, edits:Array<RangeEdit>):Array<CursorSelection> {
        final tabIndent = self.mode.tabSize().toString();

        // The edit range for each cursor: an insertion point for indent, the
        // removed range for a removable outdent.
        final ranges:Array<Range> = [];
        for (sel in self.selections.iter()) {
            final cursor = sel.cursorOffset();
            switch direction {
                case IndentDirection.Indent:
                    ranges.push(new Range(cursor, cursor));
                case IndentDirection.Outdent:
                    final row = self.text.offsetToPoint(cursor).row;
                    final start = self.text.lineStartOffset(row);
                    if (startsWithIndent(self, start, tabIndent))
                        ranges.push(new Range(start, start + tabLen));
            }
        }

        // Build disjoint edits, dropping any that would overlap a previous one.
        // (`sort_by_key` is stable, like `ArraySort`)
        haxe.ds.ArraySort.sort(ranges, (a, b) -> a.start - b.start);
        var lastEnd:Null<Int> = null;
        for (range in ranges) {
            if (lastEnd != null && range.start < lastEnd)
                continue;
            lastEnd = range.end;
            edits.push(new RangeEdit(range, direction == IndentDirection.Indent ? tabIndent : ''));
        }

        // Shift every cursor by the surviving edits before (or at) it. Cursors
        // whose own edit was dropped or not applicable keep their position.
        final newSelections:Array<CursorSelection> = [];
        for (sel in self.selections.iter()) {
            final cursor = sel.cursorOffset();
            final newOffset = switch direction {
                case IndentDirection.Indent:
                    var insertedBefore = 0;
                    for (edit in edits) {
                        if (edit.range.start <= cursor)
                            insertedBefore++;
                    }
                    cursor + insertedBefore * tabLen;
                case IndentDirection.Outdent:
                    var removedBefore = 0;
                    for (edit in edits) {
                        final end = edit.range.end < cursor ? edit.range.end : cursor;
                        final start = edit.range.start < cursor ? edit.range.start : cursor;
                        removedBefore += end - start;
                    }
                    cursor - removedBefore;
            }
            final selection = new CursorSelection(sel.id, newOffset, newOffset);
            selection.columnAnchor = null;
            newSelections.push(selection);
        }

        return newSelections;
    }

}
