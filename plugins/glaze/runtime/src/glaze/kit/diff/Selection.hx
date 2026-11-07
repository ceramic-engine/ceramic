// Ported from gpui-kit 0.8.1: crates/component/src/diff/selection.rs
// and the selection keys of crates/component/src/diff/state.rs (`encode_key`, `decode_key`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Element;
import gpui.ElementId;
import gpui.GlobalElementId;
import gpui.HighlightStyle;
import gpui.Hitbox;
import gpui.HitboxBehavior;
import gpui.IndexResult;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.ListState;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.Point;
import gpui.Range;
import gpui.ScrollHandle;
import gpui.StyledText;
import gpui.TextLayout;
import gpui.Window;
import gpui.base.Scrollbar.ScrollbarHandle;
import gpui.base.TextSelectionHandle;
import gpui.base.TextSelectionRegistration;
import gpui.base.TextSelectionRun;
import gpui.component.diff.Presentation.DiffStyledRange;
import gpui.component.theme.ActiveTheme;
import gpui.util.Utf8;

/**
 * A painted chunk of a source line.
 */
@:allow(gpui.component.diff)
class CodeRun {

    final file:Int;
    final side:DiffSide;
    final lineIx:Int;
    final displayRange:Range;
    final layout:TextLayout;
    final bounds:Bounds;
    final document:DiffFile;

    function new(file:Int, side:DiffSide, lineIx:Int, displayRange:Range, layout:TextLayout, bounds:Bounds, document:DiffFile) {
        this.file = file;
        this.side = side;
        this.lineIx = lineIx;
        this.displayRange = displayRange;
        this.layout = layout;
        this.bounds = bounds;
        this.document = document;
    }

}

/**
 * The painted code runs of the frame, shared by the code texts and the
 * selection layer (Rust `Rc<RefCell<SelectionGeometry>>`).
 */
@:allow(gpui.component.diff)
class SelectionGeometry {

    var bounds:Bounds = new Bounds(new Point(0, 0), new gpui.Size(0, 0));

    var scrollOffset:Point = new Point(0, 0);

    /** `(click count, position, cursor)` of a multi-click, or null. */
    var multiClick:Null<{count:Int, position:Point, cursor:Bool}> = null;

    var runs:Array<CodeRun> = [];

    public function new() {}

    public function clear():Void {
        runs.resize(0);
    }

    /** The widest painted source line, measured from its first text run. */
    public function paintedWidth():Float {
        var previousFile = -1;
        var previousSide:Null<DiffSide> = null;
        var previousLine = -1;
        var left = 0.0;
        var widest = 0.0;
        for (run in runs) {
            final same = previousFile == run.file && previousSide == run.side && previousLine == run.lineIx;
            if (!same)
                left = run.bounds.left();
            previousFile = run.file;
            previousSide = run.side;
            previousLine = run.lineIx;
            final width = run.bounds.right() - left;
            if (width > widest)
                widest = width;
        }
        return widest;
    }

    public function keyAt(point:Point, side:Null<DiffSide>):Null<Int> {
        final click = multiClick;
        if (click != null) {
            final run = runAt(click.position, null);
            if (run == null)
                return null;
            final line = run.document.lines(run.side)[run.lineIx];
            final ix = run.displayRange.start + indexValue(run.layout.indexForPosition(click.position));
            final range = if (click.count >= 3) {
                new Range(0, line.displayLen());
            }
            else {
                final word = Selection.wordRange(line.display(), ix);
                if (word == null)
                    return null;
                word;
            }
            multiClick = !click.cursor ? {count: click.count, position: click.position, cursor: true} : null;
            return Selection.encodeKey(run.file, run.side, line.source().start + line.sourceOffset(click.cursor ? range.end : range.start));
        }
        final point = point.add(bounds.origin).add(scrollOffset);
        final run = runAt(point, side);
        if (run == null)
            return null;
        final ix = run.displayRange.start + indexValue(run.layout.indexForPosition(point));
        final line = run.document.lines(run.side)[run.lineIx];
        return Selection.encodeKey(run.file, run.side, line.source().start + line.sourceOffset(ix));
    }

    static inline function indexValue(result:IndexResult):Int {
        return switch (result) {
            case Ok(index) | Err(index): index;
        }
    }

    function runAt(point:Point, side:Null<DiffSide>):Null<CodeRun> {
        if (side == null) {
            var best:Null<CodeRun> = null;
            var bestDistance = 0.0;
            for (run in runs) {
                final distance = Selection.distanceToBounds(point, run.bounds);
                if (best == null || distance < bestDistance) {
                    best = run;
                    bestDistance = distance;
                }
            }
            if (best == null)
                return null;
            side = best.side;
        }
        var best:Null<CodeRun> = null;
        var bestOutside = false;
        var bestLine = 0.0;
        var bestDistance = 0.0;
        for (run in runs) {
            if (run.side != side)
                continue;
            final lineDistance = Selection.lineDistance(point, run.bounds);
            final outside = lineDistance.outside;
            final line = lineDistance.distance;
            final distance = Selection.distanceToBounds(point, run.bounds);
            // `min_by`: the first of equal elements wins.
            final better = best == null || (outside != bestOutside ? !outside : (line != bestLine ? line < bestLine : distance < bestDistance));
            if (better) {
                best = run;
                bestOutside = outside;
                bestLine = line;
                bestDistance = distance;
            }
        }
        return best;
    }

}

/**
 * Bridges the virtualized code surface to Base's window text selection.
 * Content keys are exact source offsets, so copying does not depend on which
 * rows are still painted when the gesture ends.
 */
@:allow(gpui.component.diff)
class Selection {

    // Rust packs `(file, side, offset)` into a `u64` (file << 41, side bit 40).
    // The port's content keys and document orders are 32-bit `Int`s: the
    // key packs the file in 7 bits, the side in 1 and the offset in 24,
    // biased by -2^31 so that the signed order is the order of the fields.
    static inline final FILE_UNIT:Float = 33554432.0; // 2^25
    static inline final SIDE_UNIT:Float = 16777216.0; // 2^24
    static inline final BIAS:Float = 2147483648.0; // 2^31

    /** Packs a source offset into a selection key, ordered by file, side and offset. */
    static function encodeKey(file:Int, side:DiffSide, offset:Int):Int {
        final file = file > 127 ? 127 : file;
        final offset = offset > 16777215 ? 16777215 : offset;
        return Std.int(file * FILE_UNIT + (side == Modified ? SIDE_UNIT : 0) + offset - BIAS);
    }

    static function decodeKey(key:Int):{file:Int, side:DiffSide, offset:Int} {
        final value = key + BIAS;
        final file = Math.floor(value / FILE_UNIT);
        final rest = value - file * FILE_UNIT;
        final side:DiffSide = rest >= SIDE_UNIT ? Modified : Original;
        return {file: file, side: side, offset: Std.int(rest - (side == Modified ? SIDE_UNIT : 0))};
    }

    static inline function f32(v:Float):Float {
        return haxe.io.FPHelper.i32ToFloat(haxe.io.FPHelper.floatToI32(v));
    }

    /**
     * Prefer the half-open line band before proximity. Multi-click endpoints
     * are positioned at the line top, shared with the preceding line's bottom.
     * Rust returns `(outside, distance bits)`, compared as a tuple.
     */
    static function lineDistance(point:Point, bounds:Bounds):{outside:Bool, distance:Float} {
        final outside = point.y < bounds.top() || point.y >= bounds.bottom();
        return {outside: outside, distance: f32(Math.abs(point.y - bounds.center().y))};
    }

    /** Compares two `lineDistance` results like Rust tuples (`false < true`). */
    static function compareLineDistance(a:{outside:Bool, distance:Float}, b:{outside:Bool, distance:Float}):Int {
        if (a.outside != b.outside)
            return a.outside ? 1 : -1;
        return a.distance < b.distance ? -1 : (a.distance > b.distance ? 1 : 0);
    }

    static function clipHighlight(range:Range, chunk:Range):Null<Range> {
        final start = range.start > chunk.start ? range.start : chunk.start;
        final end = range.end < chunk.end ? range.end : chunk.end;
        return start < end ? new Range(start - chunk.start, end - chunk.start) : null;
    }

    /**
     * Match Base's bounded native word selection across rendering chunks.
     * Classification and the 128-character flank bound follow text_boundary.rs.
     */
    static function wordRange(text:String, offset:Int):Null<Range> {
        final codePoints:Array<Int> = [];
        final offsets:Array<Int> = [];
        final count = Utf8.decode(text, codePoints, offsets);
        final len = Utf8.byteLength(text);
        if (offset > len)
            offset = len;
        // Step back to a character boundary.
        var ix = 0;
        while (ix < count && offsets[ix] + Utf8.codePointLength(codePoints[ix]) <= offset)
            ix++;
        if (ix >= count)
            return null;
        offset = offsets[ix];
        function classOf(c:Int):Int {
            if (c == '_'.code || Utf8.isAsciiAlphanumeric(c) || (c >= 0xC0 && c <= 0x24F) || (c >= 0x400 && c <= 0x4FF) || (c >= 0x1E00 && c <= 0x1EFF)
                || (c >= 0x300 && c <= 0x36F))
                return 1;
            if (c == '\n'.code || c == '\r'.code)
                return 0;
            if (Utf8.isWhitespace(c))
                return 2;
            return 0;
        }
        final kind = classOf(codePoints[ix]);
        function connects(c:Int):Bool {
            return kind != 0 && classOf(c) == kind;
        }
        var start = offset;
        var back = ix - 1;
        var taken = 0;
        while (back >= 0 && taken < 128 && connects(codePoints[back])) {
            start -= Utf8.codePointLength(codePoints[back]);
            back--;
            taken++;
        }
        var end = offset + Utf8.codePointLength(codePoints[ix]);
        var forward = ix + 1;
        taken = 0;
        while (forward < count && taken < 128 && connects(codePoints[forward])) {
            end += Utf8.codePointLength(codePoints[forward]);
            forward++;
            taken++;
        }
        return new Range(start, end);
    }

    static function distanceToBounds(point:Point, bounds:Bounds):Float {
        var dx = bounds.left() - point.x;
        if (point.x - bounds.right() > dx)
            dx = point.x - bounds.right();
        if (dx < 0)
            dx = 0;
        var dy = bounds.top() - point.y;
        if (point.y - bounds.bottom() > dy)
            dy = point.y - bounds.bottom();
        if (dy < 0)
            dy = 0;
        dx = f32(dx);
        dy = f32(dy);
        return f32(f32(dx * dx) + f32(dy * dy));
    }

    /** The native text selection as a source range within one side of one file. */
    static function selectedSourceRange(selection:TextSelectionHandle, cx:App):Null<{file:Int, side:DiffSide, range:Range}> {
        final snapshot = selection.snapshot(cx);
        if (snapshot == null)
            return null;
        final entity = selection.entityId();
        if (snapshot.anchor().entityId() != entity || snapshot.cursor().entityId() != entity)
            return null;
        final anchorKey = snapshot.anchor().contentKey();
        if (anchorKey == null)
            return null;
        final cursorKey = snapshot.cursor().contentKey();
        if (cursorKey == null)
            return null;
        final anchor = decodeKey(anchorKey.value());
        final cursor = decodeKey(cursorKey.value());
        if (anchor.file != cursor.file || anchor.side != cursor.side || anchor.offset == cursor.offset)
            return null;
        final lo = anchor.offset < cursor.offset ? anchor.offset : cursor.offset;
        final hi = anchor.offset > cursor.offset ? anchor.offset : cursor.offset;
        return {file: anchor.file, side: anchor.side, range: new Range(lo, hi)};
    }

    /**
     * Later layers override only their specified fields, preserving syntax
     * color when inline and selection backgrounds overlap it.
     */
    static function mergeHighlights(len:Int, layers:Array<DiffStyledRange>):Array<DiffStyledRange> {
        // Sweep range edges while retaining precedence separately for each field.
        final events:Array<Array<Int>> = [];
        for (ix in 0...layers.length) {
            final range = layers[ix].range;
            final start = range.start < len ? range.start : len;
            final end = range.end < len ? range.end : len;
            if (start < end) {
                events.push([start, ix, 1]);
                events.push([end, ix, 0]);
            }
        }
        // Rust sorts `(position, ix, entering)` tuples, `false < true`.
        events.sort((a, b) -> a[0] != b[0] ? a[0] - b[0] : (a[1] != b[1] ? a[1] - b[1] : a[2] - b[2]));
        final active:Array<Array<Int>> = [for (_ in 0...7) []];
        final output = [];
        var position = 0;
        var eventIx = 0;
        while (position < len) {
            while (eventIx < events.length && events[eventIx][0] == position) {
                final ix = events[eventIx][1];
                final entering = events[eventIx][2] == 1;
                final style = layers[ix].style;
                final specified = [
                    style.color != null,
                    style.backgroundColor != null,
                    style.fontWeight != null,
                    style.fontStyle != null,
                    style.underline != null,
                    style.strikethrough != null,
                    style.fadeOut != null
                ];
                for (field in 0...7) {
                    if (specified[field]) {
                        final set = active[field];
                        if (entering) {
                            if (set.indexOf(ix) == -1) {
                                set.push(ix);
                                set.sort((a, b) -> a - b);
                            }
                        }
                        else {
                            set.remove(ix);
                        }
                    }
                }
                eventIx += 1;
            }
            final end = eventIx < events.length ? events[eventIx][0] : len;
            final style = new HighlightStyle();
            inline function last(field:Int):Null<HighlightStyle> {
                final set = active[field];
                return set.length > 0 ? layers[set[set.length - 1]].style : null;
            }
            if (last(0) != null)
                style.color = last(0).color;
            if (last(1) != null)
                style.backgroundColor = last(1).backgroundColor;
            if (last(2) != null)
                style.fontWeight = last(2).fontWeight;
            if (last(3) != null)
                style.fontStyle = last(3).fontStyle;
            if (last(4) != null)
                style.underline = last(4).underline;
            if (last(5) != null)
                style.strikethrough = last(5).strikethrough;
            if (last(6) != null)
                style.fadeOut = last(6).fadeOut;
            output.push(new DiffStyledRange(new Range(position, end), style));
            position = end;
        }
        return output;
    }

}

/**
 * One chunk of a source line: a `StyledText` that records its layout for
 * the selection layer.
 */
@:allow(gpui.component.diff)
class CodeText extends Element {

    final id:ElementId;
    final document:DiffFile;
    final file:Int;
    final side:DiffSide;
    final lineIx:Int;
    final range:Range;
    final highlights:Array<DiffStyledRange>;
    final selection:TextSelectionHandle;
    final geometry:SelectionGeometry;
    var styledText:Null<StyledText> = null;

    public function new(id:ElementId, document:DiffFile, file:Int, side:DiffSide, lineIx:Int, range:Range, highlights:Array<DiffStyledRange>,
            selection:TextSelectionHandle, geometry:SelectionGeometry) {
        this.id = id;
        this.document = document;
        this.file = file;
        this.side = side;
        this.lineIx = lineIx;
        this.range = range;
        this.highlights = highlights;
        this.selection = selection;
        this.geometry = geometry;
    }

    override public function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final line = document.lines(side)[lineIx];
        final layers = highlights.copy();
        final selected = Selection.selectedSourceRange(selection, cx);
        if (selected != null && selected.file == file && selected.side == side) {
            final start = selected.range.start > line.source().start ? selected.range.start : line.source().start;
            final end = selected.range.end < line.contentEnd() ? selected.range.end : line.contentEnd();
            if (start < end) {
                final style = new HighlightStyle();
                style.backgroundColor = ActiveTheme.theme(cx).selection;
                layers.push(new DiffStyledRange(line.displayRange(new Range(start - line.source().start, end - line.source().start)), style));
            }
        }
        final clipped = [];
        for (layer in layers) {
            final r = Selection.clipHighlight(layer.range, range);
            if (r != null)
                clipped.push(new DiffStyledRange(r, layer.style));
        }
        final text = line.chunkText(range);
        final merged = Selection.mergeHighlights(range.len(), clipped);
        styledText = new StyledText(text).withHighlights([for (h in merged) new gpui.HighlightStyle.TextHighlight(h.range.start, h.range.end, h.style)]);
        return styledText.requestLayout(id, window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final text = styledText;
        text.prepaint(id, bounds, window, cx);
        geometry.runs.push(new CodeRun(file, side, lineIx, range, text.layout(), bounds, document));
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        styledText.paint(id, bounds, window, cx);
    }

}

/**
 * The selection participant of the code surface: registers the painted
 * runs with Base's window text selection.
 */
@:allow(gpui.component.diff)
class SelectionLayer extends Element {

    final child:AnyElement;
    final scroll:ListState;
    final horizontal:ScrollHandle;
    final selection:TextSelectionHandle;
    final geometry:SelectionGeometry;

    public function new(child:AnyElement, scroll:ListState, horizontal:ScrollHandle, selection:TextSelectionHandle, geometry:SelectionGeometry) {
        this.child = child;
        this.scroll = scroll;
        this.horizontal = horizontal;
        this.selection = selection;
        this.geometry = geometry;
    }

    override public function elementId():Null<ElementId> {
        return ElementId.NamedInteger('diff-selection', selection.entityId());
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        geometry.clear();
        geometry.bounds = bounds;
        // This participant's hitbox is behind its child disclosures and gutters.
        final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        child.prepaint(window, cx);
        final listOffset = (scroll : ScrollbarHandle).offset();
        final offset = new Point(horizontal.offset().x, listOffset.y);
        geometry.scrollOffset = offset;
        final textBounds = [for (run in geometry.runs) run.bounds];
        selection.register(new TextSelectionRegistration(hitbox, bounds).withScrollOffset(offset)
            .withTextBounds(textBounds)
            .withRenderedElement(selection, window, cx), window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final runs = [
            for (run in geometry.runs) {
                final line = run.document.lines(run.side)[run.lineIx];
                final text = line.chunkText(run.displayRange);
                new TextSelectionRun(text, run.layout, run.bounds).withDocumentOrder(Selection.encodeKey(run.file, run.side,
                    line.source().start + line.sourceOffset(run.displayRange.start)));
            }
        ];
        selection.updateRuns(runs, cx);
        final geometry = this.geometry;
        window.onMouseEvent(MouseDown, (event, phase, _, _) -> {
            final event:MouseDownEvent = cast event;
            if (phase.capture() && event.button == MouseButton.Left)
                geometry.multiClick = event.clickCount >= 2 ? {count: event.clickCount, position: event.position, cursor: false} : null;
        });
        window.onMouseEvent(MouseMove, (_, phase, _, _) -> {
            if (phase.capture())
                geometry.multiClick = null;
        });
        window.onMouseEvent(MouseUp, (_, phase, _, _) -> {
            if (phase.capture())
                geometry.multiClick = null;
        });
        child.paint(window, cx);
    }

}
