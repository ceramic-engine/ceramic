// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/indent.rs (`impl InputBaseState` blocks,
// `impl TextElement` block)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Context;
import glaze.Hsla;
import glaze.Path;
import glaze.PathBuilder;
import glaze.Point;
import glaze.Range;
import glaze.TextRun;
import glaze.TextStyle;
import glaze.Window;

import glaze.kit.base.input.InputActions;

using glaze.kit.base.input.RopeExt;

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
 * `tabSize` / `setTabSize` belong to the multi-line modes (Rust
 * `impl<M: MultiLineMode>`). The indent guides of gpui-kit's code editor
 * (`indentGuides`, `layoutIndentGuides`) are not part of Glaze: its code
 * editor is Cityscape.
 *
 * The state is read through the Rust fields (`text`, `selections`, `mode`,
 * `undoManager`) and methods (`isEditable`, `isMultiLine`,
 * `replaceTextInRanges`, `scrollTo`, `cursor`), named like the Rust ones.
 */
@:access(glaze.kit.base.input.InputBaseState)
@:access(glaze.kit.base.input.LayoutMode)
class InputIndentExt {

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
        final tabLen = glaze.util.Utf8.byteLength(tabIndent);

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
        // A sign (a difference returned through the function value is boxed on hxcpp)
        haxe.ds.ArraySort.sort(ranges, (a, b) -> a.start < b.start ? -1 : (a.start > b.start ? 1 : 0));
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
