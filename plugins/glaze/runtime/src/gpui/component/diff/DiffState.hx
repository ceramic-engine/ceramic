// Ported from gpui-kit 0.8.1: crates/component/src/diff/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.App;
import gpui.Context;
import gpui.FocusHandle;
import gpui.HighlightStyle;
import gpui.ListAlignment;
import gpui.ListOffset;
import gpui.ListState;
import gpui.Model;
import gpui.Point;
import gpui.Range;
import gpui.ScrollHandle;
import gpui.Size;
import gpui.Subscription;
import gpui.Task;
import gpui.Window;
import gpui.base.TextSelection;
import gpui.base.TextSelectionContentKey;
import gpui.base.TextSelectionEvent;
import gpui.base.TextSelectionHandle;
import gpui.component.diff.Presentation.DiffStyledRange;
import gpui.component.diff.Presentation.DiffSyntaxHighlighter;
import gpui.component.diff.Presentation.FilePresentation;
import gpui.component.diff.Presentation.PresentationOptions;
import gpui.component.diff.Selection.SelectionGeometry;
import gpui.component.highlighter.SyntaxHighlighter;

/**
 * One virtualized row. Every row belongs to exactly one file.
 */
enum DisplayRow {

    /** The file header, with any file-level annotations. */
    File(file:Int);

    /** Binary, metadata-only or empty file summary, for a file without source rows. */
    Notice(file:Int);

    Hunk(file:Int, hunk:Int);

    Fold(file:Int, pairs:Range);

    /**
     * The heading of one part of a merge conflict; for a resolved conflict,
     * the `ConflictPart.Current` heading stands for the whole conflict.
     */
    Conflict(file:Int, conflict:Int, part:ConflictPart);

    Code(file:Int, original:Null<Int>, modified:Null<Int>, changed:Bool);

}

class DisplayRowTools {

    public static function file(row:DisplayRow):Int {
        return switch (row) {
            case File(file) | Notice(file): file;
            case Hunk(file, _) | Fold(file, _) | Conflict(file, _, _) | Code(file, _, _, _): file;
        }
    }

    public static function equals(a:DisplayRow, b:DisplayRow):Bool {
        return switch [a, b] {
            case [File(x), File(y)]: x == y;
            case [Notice(x), Notice(y)]: x == y;
            case [Hunk(f1, h1), Hunk(f2, h2)]: f1 == f2 && h1 == h2;
            case [Fold(f1, p1), Fold(f2, p2)]: f1 == f2 && p1.equals(p2);
            case [Conflict(f1, c1, p1), Conflict(f2, c2, p2)]: f1 == f2 && c1 == c2 && p1 == p2;
            case [Code(f1, o1, m1, c1), Code(f2, o2, m2, c2)]: f1 == f2 && o1 == o2 && m1 == m2 && c1 == c2;
            default: false;
        }
    }

}

/**
 * Which part of a collapsed unchanged range a disclosure reveals.
 */
enum abstract FoldExpansion(Int) {

    /** The lines just above the following source. */
    var Up;

    /** The lines just below the preceding source. */
    var Down;

    var All;

}

/**
 * Notifications from the readonly comparison surface.
 */
enum DiffEvent {

    /** A pointer gesture began selecting source lines from a line number. */
    SelectionStarted(range:DiffLineRange);

    /** A pointer, gutter or keyboard operation changed the selected source lines. */
    SelectionChanged(range:Null<DiffLineRange>);

    /** A selection gesture finished; the range is ready to act on. */
    SelectionEnded(range:DiffLineRange);

    /** The user expanded a collapsed file from its header. */
    FileExpanded(path:String);

    /** The user collapsed a file from its header. */
    FileCollapsed(path:String);

    /**
     * The user resolved a merge conflict, or undid its resolution; read it
     * with `DiffState.conflictResolution`.
     */
    ConflictResolved(path:String, ix:Int);

}

/**
 * Inputs that determine row heights and content width.
 */
@:allow(gpui.component.diff)
class LayoutKey {

    final rem:Float;
    final fontSize:Float;
    final fontFamily:String;
    final mode:DiffMode;
    final lineNumber:Bool;
    final markerLane:Bool;
    final softWrap:Bool;

    function new(rem:Float, fontSize:Float, fontFamily:String, mode:DiffMode, lineNumber:Bool, markerLane:Bool, softWrap:Bool) {
        this.rem = rem;
        this.fontSize = fontSize;
        this.fontFamily = fontFamily;
        this.mode = mode;
        this.lineNumber = lineNumber;
        this.markerLane = markerLane;
        this.softWrap = softWrap;
    }

    function equals(other:Null<LayoutKey>):Bool {
        return other != null && other.rem == rem && other.fontSize == fontSize && other.fontFamily == fontFamily && other.mode == mode
            && other.lineNumber == lineNumber && other.markerLane == markerLane && other.softWrap == softWrap;
    }

}

/**
 * The row showing each source line, or the disclosure hiding it.
 */
@:allow(gpui.component.diff)
private class FileRows {

    final original:Array<Null<Int>>;

    final modified:Array<Null<Int>>;

    function new(originalCount:Int, modifiedCount:Int) {
        original = [for (_ in 0...originalCount) null];
        modified = [for (_ in 0...modifiedCount) null];
    }

}

/**
 * The selected source lines of one file, resolved for membership tests.
 */
enum SelectedLines {

    /** Lines numbered `lines` on one side. */
    Side(file:Int, side:DiffSide, lines:Range);

    /** Patch lines in `patch` order, across both sides. */
    Patch(file:Int, patch:Range);

}

class SelectedLinesTools {

    public static function contains(self:SelectedLines, files:Array<DiffFile>, file:Int, side:DiffSide, ix:Int):Bool {
        return switch (self) {
            case Side(selected, selectedSide, lines):
                selected == file && selectedSide == side && lines.contains(files[file].lineNumber(side, ix));
            case Patch(selected, patch):
                selected == file && patch.contains(files[file].patchIx(side, ix));
        }
    }

    /** The last selected line, where a selection's add-annotation button sits. */
    public static function isLast(self:SelectedLines, files:Array<DiffFile>, file:Int, side:DiffSide, ix:Int):Bool {
        return switch (self) {
            case Side(selected, selectedSide, lines):
                selected == file && selectedSide == side && files[file].lineNumber(side, ix) + 1 == lines.end;
            case Patch(selected, patch):
                selected == file && files[file].patchIx(side, ix) + 1 == patch.end;
        }
    }

}

/**
 * Retained focus, viewport, context expansion and selection for a `Diff`
 * showing one or more files of a patch.
 *
 * Create once in the owning view. Mutations notify observers; the
 * application owns the patch and chooses when to install new files. Syntax
 * and inline emphasis are prepared by a task and appear once ready.
 */
class DiffState extends Model {

    var _files:Array<DiffFile>;

    /** Each path's index in `files`; the first file wins a duplicated path. */
    var fileIxs:Map<String, Int>;

    var _mode:DiffMode = Unified;

    var _contextLines:Null<Int> = 3;

    var _expansionLines:Int = 20;

    var _minCollapsedLines:Int = 2;

    var expanded:Array<Array<Range>>;

    final collapsed:Map<String, Bool> = new Map();

    /** Keyed by `index + ':' + path`. */
    final resolutions:Map<String, DiffConflictResolution> = new Map();

    var fileRows:Array<FileRows> = [];

    var headerRows:Array<Int> = [];

    var _rows:Array<DisplayRow> = [];

    var changeRows:Array<Int> = [];

    final _list:ListState;

    final _horizontalScroll:ScrollHandle;

    final focus:FocusHandle;

    final _selection:TextSelectionHandle;

    final _geometry:SelectionGeometry;

    var _selectedLines:Null<DiffLineRange> = null;

    var selectionAnchor:Null<DiffLinePosition> = null;

    var selectionCursor:Null<DiffLinePosition> = null;

    var selecting:Bool = false;

    final presentationOptions:PresentationOptions = new PresentationOptions(Word, 1000, 1000);

    var syntaxHighlighter:Null<DiffSyntaxHighlighter> = null;

    var _presentations:Array<Null<FilePresentation>>;

    var _viewport:Size = new Size(0, 0);

    var layout:Null<LayoutKey> = null;

    var _contentWidth:Float = 0;

    var rowHeight:Null<Float> = null;

    /** The list width the row-height hint was last applied at. */
    var hintedWidth:Null<Float> = null;

    var annotations:Map<String, Bool> = new Map();

    var window:Null<Int> = null;

    /**
     * Bumped when files or presentation options change, so a preparation
     * started for earlier ones never installs its results.
     */
    var presentationGeneration:Int = 0;

    var preparing:Null<Int> = null;

    var presentationTask:Null<Task<gpui.Unit>> = null;

    final selectionSubscription:Subscription;

    /** Creates a unified viewer with three unchanged lines around each change. */
    public function new(files:Iterable<DiffFile>, cx:Context<DiffState>) {
        super();
        focus = cx.focusHandle().tabStop(true);
        final selection = TextSelectionHandle.create('', cx.app);
        final geometry = new SelectionGeometry();
        final weak = cx.weakEntity();
        selection.resolveContentKeyWith((point, cx) -> {
            final state = weak.upgrade();
            if (state == null)
                return null;
            final selection = state.read(cx)._selection;
            var snapshot = selection.snapshot(cx);
            final entity = selection.entityId();
            if (snapshot != null && snapshot.anchor().entityId() != entity)
                snapshot = null;
            final anchorKey = snapshot != null ? snapshot.anchor().contentKey() : null;
            final side = anchorKey != null ? Selection.decodeKey(anchorKey.value()).side : null;
            final key = geometry.keyAt(point, side);
            if (key != null)
                return new TextSelectionContentKey(key);
            if (snapshot != null && snapshot.cursor().entityId() == entity)
                return snapshot.cursor().contentKey();
            return null;
        }, cx.app);
        selection.copyWith(cx -> {
            final state = weak.upgrade();
            return state == null ? '' : state.read(cx).selectedText(cx);
        }, cx.app);
        final focus = this.focus;
        selection.focusWith((window, cx) -> window.focus(focus, cx), cx.app);
        selectionSubscription = selection.subscribe((event, cx) -> {
            weak.tryUpdate(cx, (state, cx) -> {
                if (!state._selection.hasLocalSelection(cx.app)) {
                    switch (event) {
                        case SelectionChanged(snapshot) if (snapshot != null):
                            final changed = state._selectedLines != null;
                            state._selectedLines = null;
                            // A new text gesture ends the previous gutter anchor.
                            state.selectionAnchor = null;
                            state.selectionCursor = null;
                            if (changed)
                                cx.emit(DiffEvent.SelectionChanged(null));
                        case Cleared:
                            // A replacement gutter gesture has local selection and
                            // skips this branch. Keep its anchor for Shift-click,
                            // but report a clear that leaves no replacement range.
                            if (state._selectedLines != null) {
                                state._selectedLines = null;
                                cx.emit(DiffEvent.SelectionChanged(null));
                            }
                        default:
                    }
                }
                cx.notify();
            });
        }, cx.app);
        _selection = selection;
        _geometry = geometry;
        _files = gpui.util.Iterables.toArray(files);
        expanded = [for (_ in _files) []];
        _presentations = [for (_ in _files) null];
        fileIxs = fileIxsOf(_files);
        _list = new ListState(0, ListAlignment.Top, 0.);
        _horizontalScroll = new ScrollHandle();
        rebuild(true);
    }

    /** Sets the initial display mode. Default is `DiffMode.Unified`. */
    public function withMode(mode:DiffMode):DiffState {
        _mode = mode;
        rebuild(true);
        return this;
    }

    /**
     * Sets the initial unchanged context around each change. Default is 3;
     * null shows every supplied patch line.
     */
    public function withContextLines(lines:Null<Int>):DiffState {
        _contextLines = lines;
        rebuild(true);
        return this;
    }

    /** Sets how many lines an up or down disclosure reveals. Default is 20. */
    public function withExpansionLines(lines:Int):DiffState {
        _expansionLines = lines < 1 ? 1 : lines;
        return this;
    }

    /**
     * Sets the shortest unchanged range that collapses; shorter ranges stay
     * visible. Default is 2.
     */
    public function withMinCollapsedLines(lines:Int):DiffState {
        _minCollapsedLines = lines < 1 ? 1 : lines;
        rebuild(true);
        return this;
    }

    /**
     * Sets the unit inline changes between paired lines are emphasized in,
     * or null to emphasize whole lines only. Default is `DiffInlineUnit.Word`.
     */
    public function withInlineUnit(unit:Null<DiffInlineUnit>):DiffState {
        presentationOptions.inlineUnit = unit;
        resetPresentation();
        return this;
    }

    /** Sets the longest line, in bytes, compared for inline changes. Default is 1,000. */
    public function withInlineMaxLineLength(length:Int):DiffState {
        presentationOptions.inlineMaxLineLength = length;
        resetPresentation();
        return this;
    }

    /** Sets the longest line, in bytes, given syntax emphasis. Default is 1,000. */
    public function withSyntaxMaxLineLength(length:Int):DiffState {
        presentationOptions.syntaxMaxLineLength = length;
        resetPresentation();
        return this;
    }

    /**
     * Highlights syntax with the application's highlighter instead of GPUI
     * Kit's. Given a file's language and the source text of one side of one
     * hunk, it returns byte ranges into that text with their styles; a range
     * that splits a character is ignored.
     *
     * It runs once for each side of each hunk, so an unterminated comment in
     * one hunk cannot color the next. Styles are kept as returned rather than
     * resolved against the theme when a line paints; set a new highlighter
     * when its colors change.
     */
    public function withSyntaxHighlighter(highlighter:DiffSyntaxHighlighter):DiffState {
        syntaxHighlighter = highlighter;
        resetPresentation();
        return this;
    }

    /**
     * Replaces the application's highlighter, preparing syntax again without
     * resetting selection or scrolling. See `withSyntaxHighlighter`.
     */
    public function setSyntaxHighlighter(highlighter:DiffSyntaxHighlighter, cx:Context<DiffState>):Void {
        replaceSyntaxHighlighter(highlighter, cx);
    }

    /**
     * Returns to GPUI Kit's highlighter, preparing syntax again without
     * resetting selection or scrolling.
     */
    public function clearSyntaxHighlighter(cx:Context<DiffState>):Void {
        replaceSyntaxHighlighter(null, cx);
    }

    function replaceSyntaxHighlighter(highlighter:Null<DiffSyntaxHighlighter>, cx:Context<DiffState>):Void {
        syntaxHighlighter = highlighter;
        resetPresentation();
        ensurePresentation(cx);
        cx.notify();
    }

    /** Changes the number of lines each disclosure reveals, preserving selection and scrolling. */
    public function setExpansionLines(lines:Int, cx:Context<DiffState>):Void {
        lines = lines < 1 ? 1 : lines;
        if (_expansionLines == lines)
            return;
        _expansionLines = lines;
        cx.notify();
    }

    /** Changes the shortest unchanged range that collapses, preserving selection and scrolling. */
    public function setMinCollapsedLines(lines:Int, cx:Context<DiffState>):Void {
        lines = lines < 1 ? 1 : lines;
        if (_minCollapsedLines == lines)
            return;
        _minCollapsedLines = lines;
        rebuildAtAnchor();
        cx.notify();
    }

    /** Changes the inline comparison unit without resetting selection or scrolling. */
    public function setInlineUnit(unit:Null<DiffInlineUnit>, cx:Context<DiffState>):Void {
        if (presentationOptions.inlineUnit == unit)
            return;
        presentationOptions.inlineUnit = unit;
        resetPresentation();
        ensurePresentation(cx);
        cx.notify();
    }

    /** Changes the inline comparison line limit in bytes without resetting selection or scrolling. */
    public function setInlineMaxLineLength(length:Int, cx:Context<DiffState>):Void {
        if (presentationOptions.inlineMaxLineLength == length)
            return;
        presentationOptions.inlineMaxLineLength = length;
        resetPresentation();
        ensurePresentation(cx);
        cx.notify();
    }

    /** Changes the syntax emphasis line limit in bytes without resetting selection or scrolling. */
    public function setSyntaxMaxLineLength(length:Int, cx:Context<DiffState>):Void {
        if (presentationOptions.syntaxMaxLineLength == length)
            return;
        presentationOptions.syntaxMaxLineLength = length;
        resetPresentation();
        ensurePresentation(cx);
        cx.notify();
    }

    /** The files in patch order. */
    public function files():Array<DiffFile> {
        return _files;
    }

    public function mode():DiffMode {
        return _mode;
    }

    public function contextLines():Null<Int> {
        return _contextLines;
    }

    public function expansionLines():Int {
        return _expansionLines;
    }

    public function minCollapsedLines():Int {
        return _minCollapsedLines;
    }

    public function inlineUnit():Null<DiffInlineUnit> {
        return presentationOptions.inlineUnit;
    }

    public function inlineMaxLineLength():Int {
        return presentationOptions.inlineMaxLineLength;
    }

    public function syntaxMaxLineLength():Int {
        return presentationOptions.syntaxMaxLineLength;
    }

    public function selectedLines():Null<DiffLineRange> {
        return _selectedLines;
    }

    /** Whether the file at `path` shows only its header. */
    public function isFileCollapsed(path:String):Bool {
        return collapsed.exists(path);
    }

    /** The focus handle of the code body (Rust `Focusable::focus_handle`). */
    public function focusHandleOf():FocusHandle {
        return focus;
    }

    @:allow(gpui.component.diff, tests)
    function rows():Array<DisplayRow> {
        return _rows;
    }

    @:allow(gpui.component.diff, tests)
    function list():ListState {
        return _list;
    }

    @:allow(gpui.component.diff, tests)
    function horizontalScroll():ScrollHandle {
        return _horizontalScroll;
    }

    @:allow(gpui.component.diff, tests)
    function selection():TextSelectionHandle {
        return _selection;
    }

    @:allow(gpui.component.diff, tests)
    function geometry():SelectionGeometry {
        return _geometry;
    }

    @:allow(gpui.component.diff, tests)
    function presentations():Array<Null<FilePresentation>> {
        return _presentations;
    }

    /** The body's size as of the last paint. */
    @:allow(gpui.component.diff, tests)
    function viewport():Size {
        return _viewport;
    }

    /** The width rows need to show their longest line. */
    @:allow(gpui.component.diff, tests)
    function contentWidth():Float {
        return _contentWidth;
    }

    @:allow(gpui.component.diff)
    function setContentWidth(width:Float):Void {
        _contentWidth = width;
    }

    /**
     * Records the painted body size and widest painted row. Returns whether
     * either changed, so the frame must be laid out again.
     */
    @:allow(gpui.component.diff)
    function recordPaint(viewport:Size, paintedWidth:Float):Bool {
        final wider = paintedWidth > _contentWidth;
        if (wider)
            _contentWidth = paintedWidth;
        final resized = !_viewport.equals(viewport);
        _viewport = viewport;
        return wider || resized;
    }

    /**
     * Replaces the files and resets expansion, selection and viewport.
     * Collapsed files stay collapsed when their path is still present.
     */
    public function setFiles(files:Iterable<DiffFile>, cx:Context<DiffState>):Void {
        if (window != null && selectionIsLocal(cx.app))
            TextSelection.clearForWindow(window, cx.app);
        _files = gpui.util.Iterables.toArray(files);
        fileIxs = fileIxsOf(_files);
        for (path in [for (path in collapsed.keys()) path]) {
            if (!fileIxs.exists(path))
                collapsed.remove(path);
        }
        resolutions.clear();
        expanded = [for (_ in _files) []];
        resetPresentation();
        layout = null;
        annotations = new Map();
        _selection.setLocalSelection(false, cx.app);
        _selection.setFallbackCopyText('', cx.app);
        _selectedLines = null;
        selectionAnchor = null;
        selectionCursor = null;
        selecting = false;
        _geometry.clear();
        rebuild(true);
        _horizontalScroll.setOffset(new Point(0, 0));
        ensurePresentation(cx);
        cx.notify();
    }

    /**
     * Changes the display mode while preserving source-line selection and a
     * nearby source row.
     */
    public function setMode(mode:DiffMode, cx:Context<DiffState>):Void {
        if (_mode == mode)
            return;
        _mode = mode;
        rebuildAtAnchor();
        _horizontalScroll.setOffset(new Point(0, 0));
        cx.notify();
    }

    /** Sets surrounding context. Null shows every supplied patch line. */
    public function setContextLines(lines:Null<Int>, cx:Context<DiffState>):Void {
        if (_contextLines == lines)
            return;
        _contextLines = lines;
        for (e in expanded)
            e.resize(0);
        rebuildAtAnchor();
        cx.notify();
    }

    /** Reveals all unchanged source while preserving the configured context count. */
    public function expandUnchanged(cx:Context<DiffState>):Void {
        for (ix in 0...expanded.length)
            expanded[ix] = [new Range(0, _files[ix].pairs().length)];
        rebuildAtAnchor();
        cx.notify();
    }

    /** Restores the configured context disclosures. */
    public function collapseUnchanged(cx:Context<DiffState>):Void {
        for (e in expanded)
            e.resize(0);
        rebuildAtAnchor();
        cx.notify();
    }

    /**
     * Collapses the file at `path` to its header, or expands it, without
     * emitting a user event.
     */
    public function setFileCollapsed(path:String, isCollapsed:Bool, cx:Context<DiffState>):Void {
        final file = fileIx(path);
        if (file == null)
            return;
        final path = _files[file].path();
        final changed = if (isCollapsed) {
            final had = collapsed.exists(path);
            collapsed.set(path, true);
            !had;
        }
        else {
            collapsed.remove(path);
        }
        if (changed) {
            rebuildAtAnchor();
            cx.notify();
        }
    }

    static inline function resolutionKey(path:String, ix:Int):String {
        return ix + ':' + path;
    }

    /**
     * The resolution of conflict `ix` in the file at `path`, if any. Use
     * `DiffFile.conflicts` to enumerate valid indices; null means unresolved,
     * or that the file or index does not exist.
     */
    public function conflictResolution(path:String, ix:Int):Null<DiffConflictResolution> {
        final file = fileIx(path);
        if (file == null)
            return null;
        return resolutions.get(resolutionKey(_files[file].path(), ix));
    }

    /**
     * Resolves conflict `ix` (an index in `DiffFile.conflicts`) in the file
     * at `path`, or clears its resolution with null, without emitting a user
     * event.
     */
    public function resolveConflict(path:String, ix:Int, resolution:Null<DiffConflictResolution>, cx:Context<DiffState>):Void {
        final file = fileIx(path);
        if (file == null)
            return;
        if (ix >= _files[file].conflicts().length)
            return;
        final key = resolutionKey(_files[file].path(), ix);
        final previous = resolutions.get(key);
        if (resolution != null)
            resolutions.set(key, resolution);
        else
            resolutions.remove(key);
        if (previous != resolution) {
            rebuildAtAnchor();
            cx.notify();
        }
    }

    /**
     * The working file with every conflict replaced by its resolution, or
     * null while a conflict is unresolved or `path` names no conflicted file.
     */
    public function resolvedText(path:String):Null<String> {
        final ix = fileIx(path);
        if (ix == null)
            return null;
        final file = _files[ix];
        if (file.status() != Conflicted)
            return null;
        final lines = file.lines(Modified);
        final source = file.source(Modified);
        final text = new StringBuf();
        var lineIx = 0;
        final conflicts = file.conflicts();
        for (conflictIx in 0...conflicts.length) {
            final conflict = conflicts[conflictIx];
            final resolution = resolutions.get(resolutionKey(file.path(), conflictIx));
            if (resolution == null)
                return null;
            for (i in lineIx...conflict.sourceLines().start)
                text.add(lines[i].sourceText(source));
            for (range in conflict.kept(resolution)) {
                for (i in range.start...range.end)
                    text.add(lines[i].sourceText(source));
            }
            lineIx = conflict.sourceLines().end;
        }
        for (i in lineIx...lines.length)
            text.add(lines[i].sourceText(source));
        return text.toString();
    }

    /**
     * Synchronizes source-line selection without emitting a user event.
     * Clips to supplied patch lines; a range containing none clears selection.
     */
    public function setSelectedLines(range:Null<DiffLineRange>, cx:Context<DiffState>):Void {
        final range = range != null ? clipRange(range) : null;
        if (DiffLineRange.same(_selectedLines, range))
            return;
        selectionAnchor = range != null ? range.startPosition() : null;
        selectionCursor = range != null ? range.endPosition() : null;
        _selection.setLocalSelection(range != null, cx.app);
        _selectedLines = range;
        cx.notify();
    }

    /** Returns selected source without gutters, diff markers or annotation content. */
    public function selectedText(cx:App):String {
        if (_selection.hasLocalSelection(cx)) {
            final selected = selectedSpan();
            if (selected != null) {
                return switch (selected) {
                    case Side(file, side, lines):
                        _files[file].textForLines(side, lines.start, lines.end - 1);
                    case Patch(file, patch):
                        final file = _files[file];
                        var text = '';
                        for (i in patch.start...patch.end) {
                            final line = file.patchLines()[i];
                            // An unchanged line reads the same on both sides.
                            final modified = line.line(Modified);
                            final side:DiffSide = modified != null ? Modified : Original;
                            final ix:Int = modified != null ? modified : (line.line(Original) != null ? line.line(Original) : 0);
                            // A side's unterminated final line can precede the
                            // other side's lines in patch order.
                            if (text.length > 0 && !StringTools.endsWith(text, '\n'))
                                text += '\n';
                            text += file.lines(side)[ix].sourceText(file.source(side));
                        }
                        text;
                }
            }
        }
        final range = Selection.selectedSourceRange(_selection, cx);
        if (range == null)
            return '';
        if (range.file >= _files.length)
            return '';
        final source = _files[range.file].source(range.side);
        final len = gpui.util.Utf8.byteLength(source);
        if (range.range.end > len || !gpui.util.Utf8.isCharBoundary(source, range.range.start)
            || !gpui.util.Utf8.isCharBoundary(source, range.range.end))
            return '';
        return gpui.util.Utf8.substring(source, range.range.start, range.range.end);
    }

    /**
     * Reveals and scrolls to a source line, expanding its file and hidden
     * context if needed.
     */
    public function scrollToLine(position:DiffLinePosition, cx:Context<DiffState>):Void {
        if (lineIndex(position) == null)
            return;
        if (collapsed.remove(position.path()))
            rebuildAtAnchor();
        if (expandLine(position) != null) {
            revealLine(position);
            cx.notify();
        }
    }

    /** Scrolls to the header of the file at `path`, a `DiffFile.path`. */
    public function scrollToFile(path:String, cx:Context<DiffState>):Void {
        final file = fileIx(path);
        if (file == null || file >= headerRows.length)
            return;
        _list.scrollTo(new ListOffset(headerRows[file], 0.));
        cx.notify();
    }

    /**
     * Moves to the next changed group after the current viewport, across
     * files, wrapping to the first once the list is scrolled to its end.
     */
    public function nextChange(cx:Context<DiffState>):Void {
        moveChange(true, cx);
    }

    /** Moves to the previous changed group before the current viewport, across files. */
    public function previousChange(cx:Context<DiffState>):Void {
        moveChange(false, cx);
    }

    /** Reveals part or all of a collapsed unchanged range. */
    @:allow(gpui.component.diff, tests)
    function expandFold(file:Int, pairs:Range, expansion:FoldExpansion, cx:Context<DiffState>):Void {
        final lines = _expansionLines;
        final revealed = switch (expansion) {
            case All: pairs;
            case Up:
                final start = pairs.end > lines ? pairs.end - lines : 0;
                new Range(start > pairs.start ? start : pairs.start, pairs.end);
            case Down:
                final end = pairs.start + lines;
                new Range(pairs.start, end < pairs.end ? end : pairs.end);
        }
        if (file < expanded.length) {
            expanded[file].push(revealed);
            rebuildAtAnchor();
            cx.notify();
        }
    }

    /** Resolves a conflict from its heading and reports the user's change. */
    @:allow(gpui.component.diff, tests)
    function chooseConflict(file:Int, ix:Int, resolution:Null<DiffConflictResolution>, cx:Context<DiffState>):Void {
        final path = _files[file].path();
        resolveConflict(path, ix, resolution, cx);
        cx.emit(DiffEvent.ConflictResolved(path, ix));
    }

    /** Toggles a file from its header and reports the user's change. */
    @:allow(gpui.component.diff, tests)
    function toggleFileCollapsed(file:Int, cx:Context<DiffState>):Void {
        final path = _files[file].path();
        final isCollapsed = !collapsed.exists(path);
        setFileCollapsed(path, isCollapsed, cx);
        cx.emit(isCollapsed ? DiffEvent.FileCollapsed(path) : DiffEvent.FileExpanded(path));
    }

    /**
     * Starts a line-number selection gesture, extending the current anchor
     * in the same file when `extend` is set.
     */
    @:allow(gpui.component.diff, tests)
    function beginLineSelection(position:DiffLinePosition, extend:Bool, window:Window, cx:Context<DiffState>):Void {
        if (lineIndex(position) == null)
            return;
        final anchor = selectionAnchor != null && extend && canExtend(selectionAnchor, position) ? selectionAnchor : position;
        TextSelection.clear(window, cx.app);
        window.focus(focus, cx.app);
        selecting = true;
        cx.emit(DiffEvent.SelectionStarted(rangeBetween(anchor, position)));
        selectUserRange(anchor, position, cx);
    }

    /** Extends an active line-number gesture to `position` in the same file. */
    @:allow(gpui.component.diff, tests)
    function dragLineSelection(position:DiffLinePosition, cx:Context<DiffState>):Void {
        final anchor = selectionAnchor;
        if (anchor == null)
            return;
        if (!selecting || !canExtend(anchor, position) || (selectionCursor != null && selectionCursor.equals(position))
            || lineIndex(position) == null)
            return;
        selectUserRange(anchor, position, cx);
    }

    /**
     * Whether a selection anchored at `anchor` may extend to `position`:
     * within one file, and across sides only in Unified mode, whose rows
     * follow patch order.
     */
    function canExtend(anchor:DiffLinePosition, position:DiffLinePosition):Bool {
        return anchor.path() == position.path() && (anchor.side() == position.side() || _mode == Unified);
    }

    /** Finishes an active line-number gesture. */
    @:allow(gpui.component.diff, tests)
    function endLineSelection(cx:Context<DiffState>):Void {
        final was = selecting;
        selecting = false;
        if (!was)
            return;
        if (_selectedLines != null)
            cx.emit(DiffEvent.SelectionEnded(_selectedLines));
    }

    /** Selects one line, or extends to it, as a complete gesture. */
    @:allow(gpui.component.diff, tests)
    function clickLine(position:DiffLinePosition, extend:Bool, window:Window, cx:Context<DiffState>):Void {
        beginLineSelection(position, extend, window, cx);
        endLineSelection(cx);
    }

    @:allow(gpui.component.diff, tests)
    function keyboardSelect(direction:Int, extend:Bool, window:Window, cx:Context<DiffState>):Void {
        final active = activeSide(cx.app);
        if (active == null)
            return;
        final file = active.file;
        final side = active.side;
        final count = _files[file].linesCount(side);
        var ix = 0;
        final cursor = selectionCursor;
        if (cursor != null && cursor.side() == side && fileIx(cursor.path()) == file) {
            final current = lineIndex(cursor);
            if (current != null) {
                var next = current + direction;
                if (next < 0)
                    next = 0;
                ix = next < count - 1 ? next : count - 1;
            }
        }
        final position = this.position(file, side, ix);
        final anchor = selectionAnchor != null && extend && selectionAnchor.path() == position.path() ? selectionAnchor : position;
        TextSelection.clear(window, cx.app);
        window.focus(focus, cx.app);
        final range = selectUserRange(anchor, position, cx);
        cx.emit(DiffEvent.SelectionEnded(range));
        final row = expandLine(position);
        if (row != null)
            _list.scrollToRevealItem(row);
    }

    @:allow(gpui.component.diff, tests)
    function selectAll(window:Window, cx:Context<DiffState>):Void {
        final active = activeSide(cx.app);
        if (active == null)
            return;
        final count = _files[active.file].linesCount(active.side);
        TextSelection.clear(window, cx.app);
        window.focus(focus, cx.app);
        final range = selectUserRange(position(active.file, active.side, 0), position(active.file, active.side, count - 1), cx);
        cx.emit(DiffEvent.SelectionEnded(range));
    }

    /** The selected lines, resolved for membership tests. */
    @:allow(gpui.component.diff, tests)
    function selectedSpan():Null<SelectedLines> {
        final range = _selectedLines;
        if (range == null)
            return null;
        final file = fileIx(range.path());
        if (file == null)
            return null;
        if (range.isSingleSide()) {
            final start = range.start() < range.end() ? range.start() : range.end();
            final end = range.start() > range.end() ? range.start() : range.end();
            return Side(file, range.side(), new Range(start, end + 1));
        }
        final document = _files[file];
        final startIx = document.lineIndex(range.side(), range.start());
        if (startIx == null)
            return null;
        final start = document.patchIx(range.side(), startIx);
        final endIx = document.lineIndex(range.endSide(), range.end());
        if (endIx == null)
            return null;
        final end = document.patchIx(range.endSide(), endIx);
        return Patch(file, new Range(start < end ? start : end, (start > end ? start : end) + 1));
    }

    /** Records the window that renders this state, for clearing its text selection. */
    @:allow(gpui.component.diff)
    function setWindow(window:Int):Void {
        this.window = window;
    }

    /**
     * Updates width and row-height measurement when fonts or layout change.
     * Returns whether content width must be measured again.
     */
    @:allow(gpui.component.diff)
    function updateLayout(key:LayoutKey, rowHeight:Float):Bool {
        if (layout != null && layout.equals(key))
            return false;
        if (layout != null)
            _list.remeasure();
        layout = key;
        this.rowHeight = rowHeight;
        applyRowHeightHint();
        return true;
    }

    /**
     * Re-measures rows whose annotations were added, removed or replaced.
     * Visible rows are re-measured every frame, so content changes inside an
     * annotation need no notification.
     */
    @:allow(gpui.component.diff)
    function syncAnnotations(items:Array<DiffAnnotation>):Void {
        final current = new Map<String, DiffAnnotation>();
        for (annotation in items)
            current.set(annotationKey(annotation), annotation);
        var same = true;
        var count = 0;
        for (key in current.keys()) {
            count++;
            if (!annotations.exists(key))
                same = false;
        }
        var previousCount = 0;
        for (_ in annotations.keys())
            previousCount++;
        if (same && count == previousCount)
            return;
        final rows:Array<Int> = [];
        function rowOf(annotation:DiffAnnotation):Null<Int> {
            final position = annotation.position();
            if (position != null)
                return sourceRow(position);
            final file = fileIx(annotation.path());
            return file != null && file < headerRows.length ? headerRows[file] : null;
        }
        for (key => annotation in current) {
            if (!annotations.exists(key)) {
                final row = rowOf(annotation);
                if (row != null)
                    rows.push(row);
            }
        }
        for (key in annotations.keys()) {
            if (!current.exists(key)) {
                final row = removedAnnotationRow(key);
                if (row != null)
                    rows.push(row);
            }
        }
        for (row in rows)
            _list.remeasureItems(row, row + 1);
        annotations = [for (key in current.keys()) key => true];
        annotationTargets = [for (key => annotation in current) key => annotation];
    }

    /** The annotations of the last sync, to find the rows of removed ones. */
    var annotationTargets:Map<String, DiffAnnotation> = new Map();

    function removedAnnotationRow(key:String):Null<Int> {
        final annotation = annotationTargets.get(key);
        if (annotation == null)
            return null;
        final position = annotation.position();
        if (position != null)
            return sourceRow(position);
        final file = fileIx(annotation.path());
        return file != null && file < headerRows.length ? headerRows[file] : null;
    }

    static function annotationKey(annotation:DiffAnnotation):String {
        final position = annotation.position();
        return (position != null ? position.key() : '-') + '|' + annotation.path() + '|' + Std.string(annotation.id());
    }

    @:allow(gpui.component.diff, tests)
    function position(file:Int, side:DiffSide, ix:Int):DiffLinePosition {
        final document = _files[file];
        return new DiffLinePosition(document.path(), side, document.lineNumber(side, ix));
    }

    function fileIx(path:String):Null<Int> {
        return fileIxs.get(path);
    }

    function lineIndex(position:DiffLinePosition):Null<Int> {
        final file = fileIx(position.path());
        if (file == null)
            return null;
        return _files[file].lineIndex(position.side(), position.line());
    }

    /** Clips a range to supplied lines, normalizing a single-side range. */
    function clipRange(range:DiffLineRange):Null<DiffLineRange> {
        final ix = fileIx(range.path());
        if (ix == null)
            return null;
        final file = _files[ix];
        function firstAtOrAfter(side:DiffSide, line:Int):Null<Int> {
            final lines = file.lines(side);
            var i = 0;
            while (i < lines.length && lines[i].lineNumber() < line)
                i++;
            return i < lines.length ? lines[i].lineNumber() : null;
        }
        function lastAtOrBefore(side:DiffSide, line:Int):Null<Int> {
            final lines = file.lines(side);
            var i = 0;
            while (i < lines.length && lines[i].lineNumber() <= line)
                i++;
            return i > 0 ? lines[i - 1].lineNumber() : null;
        }
        if (range.isSingleSide()) {
            final lo = range.start() < range.end() ? range.start() : range.end();
            final hi = range.start() > range.end() ? range.start() : range.end();
            final start = firstAtOrAfter(range.side(), lo);
            if (start == null)
                return null;
            final end = lastAtOrBefore(range.side(), hi);
            if (end == null)
                return null;
            return start <= end ? new DiffLineRange(range.path(), range.side(), start, end) : null;
        }
        var start = firstAtOrAfter(range.side(), range.start());
        if (start == null)
            start = lastAtOrBefore(range.side(), range.start());
        if (start == null)
            return null;
        var end = lastAtOrBefore(range.endSide(), range.end());
        if (end == null)
            end = firstAtOrAfter(range.endSide(), range.end());
        if (end == null)
            return null;
        return new DiffLineRange(range.path(), range.side(), start, end).withEndSide(range.endSide());
    }

    function selectionIsLocal(cx:App):Bool {
        final entity = _selection.entityId();
        final snapshot = _selection.snapshot(cx);
        return snapshot != null && snapshot.anchor().entityId() == entity;
    }

    /** The file and side that keyboard selection and Select All act on. */
    function activeSide(cx:App):Null<{file:Int, side:DiffSide}> {
        var file:Null<Int> = null;
        var side:Null<DiffSide> = null;
        var found = false;
        if (selectionCursor != null) {
            final ix = fileIx(selectionCursor.path());
            if (ix != null && _selectedLines != null) {
                file = ix;
                side = selectionCursor.side();
                found = true;
            }
        }
        if (!found) {
            final range = Selection.selectedSourceRange(_selection, cx);
            if (range != null) {
                file = range.file;
                side = range.side;
                found = true;
            }
        }
        if (!found) {
            final top = _list.logicalScrollTop().itemIx;
            if (top < _rows.length) {
                file = DisplayRowTools.file(_rows[top]);
                found = true;
            }
        }
        if (!found || file >= _files.length)
            return null;
        final document = _files[file];
        final resolved:DiffSide = side != null ? side : (document.linesCount(Modified) > 0 ? Modified : Original);
        return document.linesCount(resolved) > 0 ? {file: file, side: resolved} : null;
    }

    function expandLine(position:DiffLinePosition):Null<Int> {
        final row = sourceRow(position);
        if (row == null)
            return null;
        switch (_rows[row]) {
            case Fold(file, pairs):
                expanded[file].push(pairs);
                rebuildAtAnchor();
            default:
        }
        return sourceRow(position);
    }

    /** Selects from `anchor` to `cursor` in one file and reports a change. */
    function selectUserRange(anchor:DiffLinePosition, cursor:DiffLinePosition, cx:Context<DiffState>):DiffLineRange {
        final range = rangeBetween(anchor, cursor);
        final changed = !range.equals(_selectedLines);
        _selectedLines = range;
        selectionAnchor = anchor;
        selectionCursor = cursor;
        _selection.setLocalSelection(true, cx.app);
        if (changed)
            cx.emit(DiffEvent.SelectionChanged(range));
        cx.notify();
        return range;
    }

    function moveChange(forward:Bool, cx:Context<DiffState>):Void {
        final top = _list.logicalScrollTop().itemIx;
        final groups = changeRows;
        var target:Null<Int> = null;
        if (forward) {
            // Scrolled to the end, the list clamps any later change below the
            // top, so the top never passes it and the key would stop there.
            // The last row's bounds answer even when the rows above the
            // viewport were never measured, as after a jump to the end.
            var atEnd = false;
            final count = _list.itemCount();
            if (count > 0) {
                final last = _list.boundsForItem(count - 1);
                atEnd = last != null && last.bottom() <= _list.viewportBounds().bottom();
            }
            var ix = 0;
            while (ix < groups.length && groups[ix] <= top)
                ix++;
            if (ix < groups.length && !atEnd)
                target = groups[ix];
            else if (groups.length > 0)
                target = groups[0];
        }
        else {
            var ix = 0;
            while (ix < groups.length && groups[ix] < top)
                ix++;
            if (ix > 0)
                target = groups[ix - 1];
            else if (groups.length > 0)
                target = groups[groups.length - 1];
        }
        if (target != null) {
            _list.scrollTo(new ListOffset(target, 0.));
            cx.notify();
        }
    }

    /** The source line shown by a row, looking past headers within its file. */
    function rowPosition(ix:Int):Null<DiffLinePosition> {
        if (ix < 0 || ix >= _rows.length)
            return null;
        final row = _rows[ix];
        final file = DisplayRowTools.file(row);
        function pairPosition(original:Null<Int>, modified:Null<Int>):Null<DiffLinePosition> {
            if (modified != null)
                return position(file, Modified, modified);
            if (original != null)
                return position(file, Original, original);
            return null;
        }
        return switch (row) {
            case Code(_, original, modified, _):
                pairPosition(original, modified);
            case Fold(_, pairs):
                final list = _files[file].pairs();
                pairs.start < list.length ? pairPosition(list[pairs.start].original(), list[pairs.start].modified()) : null;
            case File(_) | Notice(_) | Hunk(_, _) | Conflict(_, _, _):
                ix + 1 < _rows.length && DisplayRowTools.file(_rows[ix + 1]) == file ? rowPosition(ix + 1) : null;
        }
    }

    @:allow(gpui.component.diff, tests)
    function sourceRow(position:DiffLinePosition):Null<Int> {
        final file = fileIx(position.path());
        if (file == null || file >= fileRows.length)
            return null;
        final rows = position.side() == Original ? fileRows[file].original : fileRows[file].modified;
        final index = lineIndex(position);
        if (index == null || index >= rows.length)
            return null;
        return rows[index];
    }

    function revealLine(position:DiffLinePosition):Void {
        final itemIx = sourceRow(position);
        if (itemIx != null)
            _list.scrollTo(new ListOffset(itemIx, 0.));
    }

    /** Rebuilds rows and restores the source line at the top of the viewport. */
    function rebuildAtAnchor():Void {
        final anchor = rowPosition(_list.logicalScrollTop().itemIx);
        rebuild(false);
        if (anchor != null)
            revealLine(anchor);
    }

    /**
     * Projects rows. Without `reset`, only the changed middle is spliced so
     * measured heights of unchanged rows survive disclosure changes.
     */
    function rebuild(reset:Bool):Void {
        final rows = projectRows();
        fileRows = sourceRows(_files, rows);
        changeRows = changedGroups(rows);
        headerRows = [for (ix in 0...rows.length) if (rows[ix].match(File(_))) ix];
        if (reset) {
            _list.reset(rows.length);
        }
        else {
            final old = _rows;
            var prefix = 0;
            while (prefix < old.length && prefix < rows.length && DisplayRowTools.equals(old[prefix], rows[prefix]))
                prefix++;
            final limit = (old.length < rows.length ? old.length : rows.length) - prefix;
            var suffix = 0;
            while (suffix < limit && DisplayRowTools.equals(old[old.length - 1 - suffix], rows[rows.length - 1 - suffix]))
                suffix++;
            _list.splice(prefix, old.length - suffix, rows.length - prefix - suffix);
        }
        _rows = rows;
        applyRowHeightHint();
    }

    function projectRows():Array<DisplayRow> {
        final rows = [];
        for (ix in 0..._files.length) {
            final file = _files[ix];
            rows.push(File(ix));
            if (collapsed.exists(file.path()))
                continue;
            if (file.pairs().length == 0) {
                rows.push(Notice(ix));
            }
            else if (file.status() == Unchanged) {
                for (line in 0...file.pairs().length)
                    rows.push(Code(ix, null, line, false));
            }
            else if (file.status() == Conflicted) {
                final resolutions = [
                    for (conflict in 0...file.conflicts().length)
                        this.resolutions.get(resolutionKey(file.path(), conflict))
                ];
                final visible = visiblePairs(file, _contextLines, _minCollapsedLines, expanded[ix]);
                projectConflicts(rows, ix, file, visible, resolutions);
            }
            else {
                projectFile(rows, ix, file, _mode, _contextLines, _minCollapsedLines, expanded[ix]);
            }
        }
        return rows;
    }

    /**
     * Applies the row-height hint again once the list has laid out at a new
     * width. Returns whether it did, so the frame must be laid out again.
     *
     * A list that lays out at a new width forgets every row height, hints
     * included, which happens on its first layout too. The patch then
     * measures only the rows rendered so far, and scrolling stops once the
     * last of them reaches the bottom of the viewport. Call this after the
     * list's prepaint, so the hint is back before the next wheel event.
     */
    @:allow(gpui.component.diff)
    function keepRowHeightHint():Bool {
        final width = _list.viewportBounds().size.width;
        if (rowHeight == null || hintedWidth == width)
            return false;
        hintedWidth = width;
        applyRowHeightHint();
        return true;
    }

    /**
     * Gives unmeasured rows a code-row height so the scrollbar is sized for
     * the whole patch before every row has been rendered.
     */
    function applyRowHeightHint():Void {
        if (rowHeight != null)
            _list.withUniformItemHeight(rowHeight);
    }

    /** Discards prepared emphasis after files or options change. */
    function resetPresentation():Void {
        _presentations = [for (_ in _files) null];
        presentationGeneration += 1;
        preparing = null;
        if (presentationTask != null) {
            presentationTask.cancel();
            presentationTask = null;
        }
    }

    /**
     * Prepares syntax and inline emphasis for files that lack it, one file
     * at a time, reusing highlighters per language. Starts on first render,
     * so builders applied after `new` take effect.
     *
     * Rust prepares each file on the background executor; the port runs the
     * preparation in a task of the background executor too (which runs on
     * the main thread here), one file per task.
     */
    @:allow(gpui.component.diff, tests)
    function ensurePresentation(cx:Context<DiffState>):Void {
        final generation = presentationGeneration;
        if (preparing == generation)
            return;
        final pending = [for (ix in 0..._presentations.length) if (_presentations[ix] == null) ix];
        if (pending.length == 0)
            return;
        final options = presentationOptions.copy();
        final custom = syntaxHighlighter;
        final files = [for (ix in pending) _files[ix]];
        preparing = generation;
        final highlighters = new Map<String, SyntaxHighlighter>();
        presentationTask = cx.spawn((weak, acx) -> {
            final done = new Task<gpui.Unit>();
            function step(i:Int):Void {
                if (i >= pending.length) {
                    done.resolve(gpui.Unit.unit);
                    return;
                }
                final ix = pending[i];
                final file = files[i];
                acx.backgroundExecutor().spawn(() -> FilePresentation.prepare(file, options, highlighters, custom)).then(presentation -> {
                    var current = false;
                    try {
                        current = weak.update(acx, (state:DiffState, cx:Context<DiffState>) -> {
                            if (state.presentationGeneration != generation)
                                return false;
                            if (ix < state._presentations.length)
                                state._presentations[ix] = presentation;
                            cx.notify();
                            return true;
                        });
                    }
                    catch (e:gpui.EntityReleasedError) {
                        current = false;
                    }
                    if (!current) {
                        done.resolve(gpui.Unit.unit);
                        return;
                    }
                    step(i + 1);
                });
            }
            step(0);
            return done;
        });
    }

    /** The range from `anchor` to `cursor`, normalized when both are on one side. */
    static function rangeBetween(anchor:DiffLinePosition, cursor:DiffLinePosition):DiffLineRange {
        if (anchor.side() == cursor.side()) {
            final lo = anchor.line() < cursor.line() ? anchor.line() : cursor.line();
            final hi = anchor.line() > cursor.line() ? anchor.line() : cursor.line();
            return new DiffLineRange(cursor.path(), cursor.side(), lo, hi);
        }
        return new DiffLineRange(cursor.path(), anchor.side(), anchor.line(), cursor.line()).withEndSide(cursor.side());
    }

    static function fileIxsOf(files:Array<DiffFile>):Map<String, Int> {
        final ixs = new Map<String, Int>();
        for (ix in 0...files.length) {
            if (!ixs.exists(files[ix].path()))
                ixs.set(files[ix].path(), ix);
        }
        return ixs;
    }

    /**
     * Every source line maps to its code row or the disclosure hiding it;
     * lines of a collapsed file have no row.
     */
    static function sourceRows(files:Array<DiffFile>, rows:Array<DisplayRow>):Array<FileRows> {
        final fileRows = [for (file in files) new FileRows(file.linesCount(Original), file.linesCount(Modified))];
        for (rowIx in 0...rows.length) {
            function map(file:Int, original:Null<Int>, modified:Null<Int>) {
                if (original != null)
                    fileRows[file].original[original] = rowIx;
                if (modified != null)
                    fileRows[file].modified[modified] = rowIx;
            }
            switch (rows[rowIx]) {
                case Code(file, original, modified, _):
                    map(file, original, modified);
                case Fold(file, pairs):
                    final list = files[file].pairs();
                    for (i in pairs.start...pairs.end)
                        map(file, list[i].original(), list[i].modified());
                default:
            }
        }
        return fileRows;
    }

    static function isChangedRow(row:DisplayRow):Bool {
        return switch (row) {
            case Code(_, _, _, true): true;
            default: false;
        }
    }

    static function changedGroups(rows:Array<DisplayRow>):Array<Int> {
        return [
            for (ix in 0...rows.length)
                if (isChangedRow(rows[ix])
                    && (ix == 0 || !isChangedRow(rows[ix - 1]) || DisplayRowTools.file(rows[ix - 1]) != DisplayRowTools.file(rows[ix])))
                    ix
        ];
    }

    /** The end of the hunk containing each pair; a fixture without hunks is one. */
    static function hunkEnds(document:DiffFile):Array<Int> {
        final pairs = document.pairs();
        final hunkEnd = [for (_ in 0...pairs.length) pairs.length];
        for (hunk in document.hunks()) {
            for (i in hunk.pairs().start...hunk.pairs().end)
                hunkEnd[i] = hunk.pairs().end;
        }
        return hunkEnd;
    }

    /**
     * Which pairs show as code: changes with their context, expanded ranges,
     * and collapsed ranges shorter than `minCollapsedLines`.
     */
    static function visiblePairs(document:DiffFile, context:Null<Int>, minCollapsedLines:Int, expanded:Array<Range>):Array<Bool> {
        final pairs = document.pairs();
        final hunks = document.hunks();
        final hunkEnd = [for (_ in 0...pairs.length) pairs.length];
        final hunkStart = [for (_ in 0...pairs.length) 0];
        for (hunk in hunks) {
            for (i in hunk.pairs().start...hunk.pairs().end) {
                hunkStart[i] = hunk.pairs().start;
                hunkEnd[i] = hunk.pairs().end;
            }
        }
        // Interval boundaries avoid repeatedly filling overlapping context windows.
        final boundaries = [for (_ in 0...pairs.length + 1) 0];
        if (context != null) {
            var ix = 0;
            while (ix < pairs.length) {
                if (!pairs[ix].isChanged()) {
                    ix += 1;
                    continue;
                }
                final start = ix;
                while (ix < pairs.length && ix < hunkEnd[start] && pairs[ix].isChanged())
                    ix += 1;
                final from = start > context ? start - context : 0;
                boundaries[from > hunkStart[start] ? from : hunkStart[start]] += 1;
                final to = ix + context;
                boundaries[to < hunkEnd[start] ? to : hunkEnd[start]] -= 1;
            }
        }
        else {
            boundaries[0] += 1;
            boundaries[pairs.length] -= 1;
        }
        for (range in expanded) {
            final start = range.start < pairs.length ? range.start : pairs.length;
            final end = range.end < pairs.length ? range.end : pairs.length;
            if (start < end) {
                boundaries[start] += 1;
                boundaries[end] -= 1;
            }
        }
        var active = 0;
        final visible = [
            for (i in 0...pairs.length) {
                active += boundaries[i];
                active > 0;
            }
        ];
        // A disclosure shorter than the threshold would hide almost nothing.
        var ix = 0;
        while (ix < pairs.length) {
            if (visible[ix]) {
                ix += 1;
                continue;
            }
            final start = ix;
            while (ix < pairs.length && ix < hunkEnd[start] && !visible[ix])
                ix += 1;
            if (ix - start < minCollapsedLines) {
                for (i in start...ix)
                    visible[i] = true;
            }
        }
        return visible;
    }

    static function projectFile(rows:Array<DisplayRow>, file:Int, document:DiffFile, mode:DiffMode, context:Null<Int>, minCollapsedLines:Int,
            expanded:Array<Range>):Void {
        final pairs = document.pairs();
        final hunks = document.hunks();
        final hunkEnd = hunkEnds(document);
        final visible = visiblePairs(document, context, minCollapsedLines, expanded);
        var hunkIx = 0;
        var ix = 0;
        while (ix < pairs.length) {
            while (hunkIx < hunks.length) {
                if (hunks[hunkIx].pairs().start != ix)
                    break;
                rows.push(Hunk(file, hunkIx));
                hunkIx += 1;
            }
            if (!visible[ix]) {
                final start = ix;
                while (ix < pairs.length && ix < hunkEnd[start] && !visible[ix])
                    ix += 1;
                rows.push(Fold(file, new Range(start, ix)));
            }
            else if (mode == Unified && pairs[ix].isChanged()) {
                final start = ix;
                while (ix < pairs.length && ix < hunkEnd[start] && pairs[ix].isChanged())
                    ix += 1;
                for (i in start...ix) {
                    final original = pairs[i].original();
                    if (original != null)
                        rows.push(Code(file, original, null, true));
                }
                for (i in start...ix) {
                    final modified = pairs[i].modified();
                    if (modified != null)
                        rows.push(Code(file, null, modified, true));
                }
            }
            else {
                final pair = pairs[ix];
                rows.push(Code(file, pair.original(), pair.modified(), pair.isChanged()));
                ix += 1;
            }
        }
    }

    /**
     * Projects a conflicted working file: shared lines fold like context,
     * and each conflict shows its parts, or only the kept lines once resolved.
     */
    static function projectConflicts(rows:Array<DisplayRow>, file:Int, document:DiffFile, visible:Array<Bool>,
            resolutions:Array<Null<DiffConflictResolution>>):Void {
        // Each line of a conflicted file is its own pair.
        final conflicts = document.conflicts();
        var next = 0;
        var ix = 0;
        while (ix < visible.length) {
            if (next < conflicts.length && conflicts[next].sourceLines().start == ix) {
                final conflict = conflicts[next];
                final resolution = resolutions[next];
                if (resolution == null) {
                    for (part in [ConflictPart.Current, ConflictPart.Base, ConflictPart.Incoming]) {
                        final lines = conflict.part(part);
                        if (lines != null) {
                            rows.push(Conflict(file, next, part));
                            for (line in lines.start...lines.end)
                                rows.push(Code(file, null, line, true));
                        }
                    }
                }
                else {
                    rows.push(Conflict(file, next, Current));
                    for (lines in conflict.kept(resolution)) {
                        for (line in lines.start...lines.end)
                            rows.push(Code(file, null, line, false));
                    }
                }
                ix = conflict.sourceLines().end;
                next += 1;
                continue;
            }
            if (visible[ix]) {
                rows.push(Code(file, null, ix, false));
                ix += 1;
                continue;
            }
            final start = ix;
            while (ix < visible.length && !visible[ix])
                ix += 1;
            rows.push(Fold(file, new Range(start, ix)));
        }
    }

}
