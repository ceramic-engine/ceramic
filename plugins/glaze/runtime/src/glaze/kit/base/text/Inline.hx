// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.ClickEvent.MouseClickEvent;
import glaze.Edges;
import glaze.Element;
import glaze.GlobalElementId;
import glaze.Hitbox;
import glaze.Hsla;
import glaze.LayoutId;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Pixels;
import glaze.Point;
import glaze.Range;
import glaze.Size;
import glaze.StyledText;
import glaze.TextAlign;
import glaze.TextLayout;
import glaze.TextRun;
import glaze.TextStyle;
import glaze.Window;
import glaze.WrappedLineLayout;
import glaze.kit.base.GlobalState;
import glaze.kit.base.TextSelection;
import glaze.kit.base.TextSelectionRun;
import glaze.kit.base.input.Selection;
import glaze.kit.base.input.TouchSelectionSnapshot;
import glaze.kit.base.theme.Theme;
import glaze.util.Utf8;

/** Rust `LinkClickHandlerFn` (text_view.rs): `(url, event, window, cx)`. */
private typedef LinkClickHandler = (url:String, event:glaze.ClickEvent, window:glaze.Window, cx:glaze.App) -> Void;

/**
 * A inline element used to render a inline text and support selectable.
 *
 * All text in TextView (including the CodeBlock) used this for text rendering.
 *
 * Differences with gpui-kit: Rust keeps the request layout and prepaint
 * states (the hitbox) apart from the element; here they are fields, as for
 * every element of the port. The retained layout table is a slot on each
 * `InlineState` (see `RetainedLayout`).
 */
class Inline extends Element {

    var text:String;

    var links:Array<RangedLink>;

    var highlights:Array<RangedHighlight>;

    var styledText:StyledText;

    /** The resolved style from a parent deferred layout, when there is one. */
    var textStyle_:Null<TextStyle> = null;

    var paintOrigin_:Null<Point> = null;

    var selectionBounds_:Null<Bounds> = null;

    var selectionSourceState:Null<InlineState> = null;

    var selectionSourceRange:Null<Range> = null;

    /** Range highlight backgrounds, painted behind the text. */
    var rangeBackgrounds_:Array<RangedColor> = [];

    /** The start of a pending reveal, when it is in this text. */
    var reveal_:Null<RevealAt> = null;

    var linkClickHandler:Null<LinkClickHandler>;

    /**
     * What this frame's layout was shaped with (runs and text style), to
     * hand the shaped text to the next frame (see `RetainedLayout`).
     */
    var retainedKeyRuns:Null<Array<TextRun>> = null;

    var retainedKeyTextStyle:Null<TextStyle> = null;

    /**
     * The shaped text is in the table, not in `styledText`, until paint
     * takes it back.
     */
    var handedOver:Bool = false;

    /**
     * A fragment of an editor leaf laid out by `InlineFlow`: the leaf's key
     * and the leaf byte offset of this text's index 0.
     */
    var editorPiece_:Null<EditorPiece> = null;

    var state:InlineState;

    /** Rust `PrepaintState`. */
    var hitbox:Null<Hitbox> = null;

    public function new(state:InlineState, links:Array<RangedLink>, highlights:Array<RangedHighlight>, linkClickHandler:Null<LinkClickHandler>) {
        final text = state != null ? state.text : '';
        this.links = links;
        this.highlights = highlights;
        this.text = text;
        this.styledText = new StyledText(text);
        this.linkClickHandler = linkClickHandler;
        this.state = state;
    }

    /** Use the resolved style captured by a deferred parent layout. */
    public function textStyle(textStyle:TextStyle):Inline {
        this.textStyle_ = textStyle;
        return this;
    }

    /**
     * Report this text as a fragment of the editor leaf `key`, starting at
     * the leaf's byte `start` (see `reportToEditor`).
     */
    public function editorPiece(piece:Null<EditorPiece>):Inline {
        this.editorPiece_ = piece;
        return this;
    }

    /** Preserve the shared inline-flow baseline through GPUI's element-bound snapping. */
    public function paintOrigin(origin:Point):Inline {
        this.paintOrigin_ = origin;
        return this;
    }

    public function selectionBounds(bounds:Bounds):Inline {
        this.selectionBounds_ = bounds;
        return this;
    }

    public function selectionSource(state:InlineState, range:Range):Inline {
        this.selectionSourceState = state;
        this.selectionSourceRange = range;
        return this;
    }

    /**
     * Paint `backgrounds` behind the text. They are not part of the text
     * runs, so changing them does not shape the text again.
     */
    public function rangeBackgrounds(backgrounds:Array<RangedColor>):Inline {
        this.rangeBackgrounds_ = backgrounds.copy();
        return this;
    }

    /** Scroll the line `reveal` starts on into view during prepaint. */
    public function reveal(reveal:Null<RevealAt>):Inline {
        this.reveal_ = reveal;
        return this;
    }

/// Retained layouts

    /**
     * Rust installs the App's retained-layout cleanup (a channel and a
     * foreground task sweeping the thread-local table when an `InlineState`
     * drops). The port keeps each retained layout on its `InlineState`, so
     * the layout is released together with the state and there is nothing
     * to install.
     */
    public static function init(cx:App):Void {}

    /**
     * How many states hold a retained layout (Rust reads the length of its
     * table in tests). A slot is counted when filled and uncounted when
     * taken; a state that is dropped while holding one is not uncounted.
     */
    @:allow(tests)
    static var retainedLayoutCount:Int = 0;

    /** Takes the layout retained for `state`, if the previous frame left one. */
    static function takeRetainedLayout(state:InlineState):Null<RetainedLayout> {
        final retained = state.retainedLayout;
        if (retained != null) {
            retainedLayoutCount--;
        }
        state.retainedLayout = null;
        return retained;
    }

    /**
     * Whether the table already holds a layout for `state`: every entry left
     * by the previous frame is taken at layout time, so one that is present
     * afterwards was put there this frame, by another element of the same state.
     */
    static function hasRetainedLayout(state:InlineState):Bool {
        return state.retainedLayout != null;
    }

    static function retainLayout(state:InlineState, retained:RetainedLayout):Void {
        if (state.retainedLayout == null) {
            retainedLayoutCount++;
        }
        state.retainedLayout = retained;
    }

    /**
     * Editor seam (design D3): report this leaf's layout and take the
     * editor's backgrounds. Inert unless the state carries an editor key
     * and an editor sink is installed.
     */
    function reportToEditor():Void {
        final sink = EditorSeam.current();
        if (sink == null) {
            return;
        }
        final piece = editorPiece_;
        if (piece != null) {
            final key = piece.key;
            final start = piece.start;
            final layout = styledText.layout();
            final end = start + layout.len();
            sink.reportTextPiece(key, start, layout);
            for (item in sink.backgrounds(key)) {
                final lo = item.range.start > start ? item.range.start : start;
                final hi = item.range.end < end ? item.range.end : end;
                if (lo < hi) {
                    rangeBackgrounds_.push(new RangedColor(new Range(lo - start, hi - start), item.color));
                }
            }
            return;
        }
        final key = state.editorKey;
        if (key == null) {
            return;
        }
        sink.report(key, styledText.layout());
        for (item in sink.backgrounds(key)) {
            rangeBackgrounds_.push(item);
        }
    }

    /**
     * Hands the shaped text to the next frame (see `RetainedLayout`).
     * Called after prepaint, so an element that is laid out but never
     * painted (scrolled out of view) keeps its layout too; paint takes it
     * back for the duration of painting.
     *
     * When another element of the same state already handed one over this
     * frame (the same document shown twice), this one keeps its own: the
     * table holds one layout per state, and an element must never be left
     * to paint without its shaped text.
     */
    function retainStyledText(cx:App):Void {
        if (handedOver || retainedKeyRuns == null || hasRetainedLayout(state)) {
            return;
        }
        final runs = retainedKeyRuns;
        final textStyle = retainedKeyTextStyle;
        retainedKeyRuns = null;
        retainedKeyTextStyle = null;
        final styled = styledText;
        styledText = new StyledText('');
        retainLayout(state, new RetainedLayout(styled, text, runs, textStyle));
        handedOver = true;
    }

    /**
     * Takes the shaped text back from the table for painting. `false` when
     * it is gone, in which case there is nothing to paint with.
     */
    function reclaimStyledText():Bool {
        if (!handedOver) {
            return true;
        }
        final retained = takeRetainedLayout(state);
        if (retained == null) {
            return false;
        }
        styledText = retained.styledText;
        retainedKeyRuns = retained.runs;
        retainedKeyTextStyle = retained.textStyle;
        handedOver = false;
        return true;
    }

/// Reveal, links and selection

    /**
     * Ask the enclosing list to scroll the line of the pending reveal into
     * view, and report where it is and whether it is inside the visible
     * area.
     */
    function requestReveal(window:Window):Void {
        final reveal = reveal_;
        if (reveal == null) {
            return;
        }
        final textLayout = styledText.layout();
        final bounds = textLayout.bounds();
        final lineHeight = textLayout.lineHeight();
        final glyphs = glyphBoxes(textLayout, window.textStyle().textAlign, bounds.size.width);
        // The glyph drawing the text at the offset, or, for text with no
        // glyph of its own such as a line break, the next glyph, or the last.
        final offset = reveal.offset();
        final boxes = rangeBoxes(glyphs, new Range(offset, offset + 1));
        var row = 0;
        var left:Float = 0;
        var right:Float = 0;
        if (boxes.length > 0) {
            row = boxes[0].row;
            left = boxes[0].left;
            right = boxes[0].right;
        }
        else {
            var found:Null<GlyphBox> = null;
            for (glyph in glyphs) {
                if (glyph.text.start >= offset) {
                    found = glyph;
                    break;
                }
            }
            if (found == null && glyphs.length > 0) {
                found = glyphs[glyphs.length - 1];
            }
            if (found != null) {
                row = found.row;
                left = found.left;
                right = found.right;
            }
        }
        final line = Bounds.fromCorners(
            new Point(f32(bounds.left() + left), f32(bounds.top() + f32(lineHeight * row))),
            new Point(f32(bounds.left() + Math.max(right, f32(left + 1.))), f32(bounds.top() + f32(lineHeight * (row + 1))))
        );
        window.requestAutoscroll(line);
        // A list scrolls the line to its edge, which layout may miss by a
        // fraction of a pixel.
        final visible = window.contentMask().bounds.dilate(0.5);
        reveal.report(line, line.top() >= visible.top() && line.bottom() <= visible.bottom());
    }

    /** Get link at given mouse position. */
    static function linkForPosition(layout:TextLayout, links:Array<RangedLink>, position:Point):Null<LinkMark> {
        final offset = switch layout.indexForPosition(position) {
            case Ok(ix): ix;
            case Err(_): return null;
        }
        for (item in links) {
            if (item.range.contains(offset)) {
                return item.link.clone();
            }
        }
        return null;
    }

    /** Get the range of the link at given mouse position. */
    static function linkRangeForPosition(layout:TextLayout, links:Array<RangedLink>, position:Point):Null<Range> {
        final offset = switch layout.indexForPosition(position) {
            case Ok(ix): ix;
            case Err(_): return null;
        }
        for (item in links) {
            if (item.range.contains(offset)) {
                return item.range;
            }
        }
        return null;
    }

    function layoutSelections(textLayout:TextLayout, bounds:Bounds, cx:App):SelectionLayout {
        final textViewState = GlobalState.global(cx).textViewState();
        if (textViewState == null) {
            return new SelectionLayout(false, false, null);
        }

        final textViewState = textViewState.read(cx);
        final isSelectable = textViewState.isSelectable();
        if (!isSelectable) {
            return new SelectionLayout(false, false, null);
        }

        if (textViewState.isAllSelected()) {
            return new SelectionLayout(isSelectable, true, new Selection(0, Utf8.byteLength(text)));
        }

        if (textViewState.preserveInlineSelection) {
            var selection:Null<Selection> = null;
            if (selectionSourceState != null) {
                final range = selectionSourceRange;
                final sourceSelection = selectionSourceState.selection;
                if (sourceSelection != null) {
                    final start = sourceSelection.start > range.start ? sourceSelection.start : range.start;
                    final end = sourceSelection.end < range.end ? sourceSelection.end : range.end;
                    if (start < end) {
                        selection = new Selection(start - range.start, end - range.start);
                    }
                }
            }
            else {
                selection = state.selection != null ? state.selection.copy() : null;
            }
            return new SelectionLayout(true, selection != null, selection);
        }

        final multiClick = textViewState.multiClickSelection();
        if (multiClick != null) {
            if (multiClick.kind == TextViewMultiClickKind.Line) {
                final row = multiClick.lineBounds;
                return new SelectionLayout(true, true, row != null && row.contains(bounds.center()) ? new Selection(0, Utf8.byteLength(text)) : null);
            }
            final range = selectionForMultiClick(text, textLayout, bounds, multiClick.pos, multiClick.kind);
            return new SelectionLayout(isSelectable, true, range != null ? Selection.fromRange(range) : null);
        }

        final points = textViewState.paintedSelectionPoints(cx);
        if (points == null) {
            return new SelectionLayout(isSelectable, false, null);
        }
        return new SelectionLayout(true, true, projectSelection(text, new TextLayoutGeometry(textLayout), selectionBounds_, points.start, points.end));
    }

    /**
     * One box per laid-out row, from the row's start to its last character,
     * clipped to `maskBounds`.
     *
     * Walks the wrapped line layouts rather than every character: a
     * per-character walk with `TextLayout.positionForIndex` costs
     * O(chars x glyphs) for every selectable inline on every frame.
     *
     * A row followed by another row (a wrap or a newline) is extended by half
     * a line height past its last glyph: the character walk gave that width
     * to a character whose successor sits on the next row, and the selection
     * geometry was tuned against it.
     */
    static function textLineBounds(textLayout:PaintedSelectionLayout, lineHeight:Pixels, maskBounds:Bounds):Array<Bounds> {
        final origin = textLayout.bounds.origin;
        final lines = textLayout.lines;
        var rowCount = 0;
        for (line in lines) {
            rowCount += line.wrapBoundaries.length + 1;
        }
        final lineBounds:Array<Bounds> = [];
        var rowIx = 0;
        var y:Float = origin.y;
        for (line in lines) {
            final layout = line.unwrappedLayout;
            var rowStart = 0;
            final rowEnds:Array<Int> = [
                for (boundary in line.wrapBoundaries) layout.runs[boundary.runIx].glyphs[boundary.glyphIx].index
            ];
            rowEnds.push(line.len());
            for (rowEnd in rowEnds) {
                var width = f32(layout.xForIndex(rowEnd) - layout.xForIndex(rowStart));
                rowIx += 1;
                if (rowIx < rowCount) {
                    width = f32(width + lineHeight / 2);
                }
                final bounds = new Bounds(new Point(origin.x, y), new Size(width, lineHeight)).intersect(maskBounds);
                if (bounds.size.width > 0 && bounds.size.height > 0) {
                    lineBounds.push(bounds);
                }
                y = f32(y + lineHeight);
                rowStart = rowEnd;
            }
        }
        return lineBounds;
    }

    /**
     * The caret line boxes at the two ends of a painted selection, where the
     * touch handles are drawn.
     */
    static function selectionEdges(selection:Selection, textLayout:TextLayout):Null<BoundsPair> {
        final start = selection.start < selection.end ? selection.start : selection.end;
        final end = selection.start > selection.end ? selection.start : selection.end;
        final lineHeight = textLayout.lineHeight();
        final startPosition = textLayout.positionForIndex(start);
        if (startPosition == null) {
            return null;
        }
        final endPosition = textLayout.positionForIndex(end);
        if (endPosition == null) {
            return null;
        }
        return new BoundsPair(TouchSelectionSnapshot.caretLineBox(startPosition, lineHeight), TouchSelectionSnapshot.caretLineBox(endPosition, lineHeight));
    }

    /** Paint the selection background. */
    static function paintSelection(selection:Selection, textLayout:TextLayout, bounds:Bounds, window:Window, color:Hsla):Void {
        var start = selection.start;
        var end = selection.end;
        if (end < start) {
            final tmp = start;
            start = end;
            end = tmp;
        }
        final startPosition = textLayout.positionForIndex(start);
        if (startPosition == null) {
            return;
        }
        final endPosition = textLayout.positionForIndex(end);
        if (endPosition == null) {
            return;
        }

        final lineHeight = textLayout.lineHeight();
        inline function paint(topLeft:Point, bottomRight:Point) {
            window.paintQuad(glaze.Prelude.quad(Bounds.fromCorners(topLeft, bottomRight), new glaze.Corners(), color, new Edges(), Hsla.transparentBlack(), glaze.scene.BorderStyle.Solid));
        }
        if (startPosition.y == endPosition.y) {
            paint(startPosition, new Point(endPosition.x, f32(endPosition.y + lineHeight)));
        }
        else {
            paint(startPosition, new Point(bounds.right(), f32(startPosition.y + lineHeight)));

            if (endPosition.y > f32(startPosition.y + lineHeight)) {
                paint(new Point(bounds.left(), f32(startPosition.y + lineHeight)), new Point(bounds.right(), endPosition.y));
            }

            paint(new Point(bounds.left(), endPosition.y), new Point(endPosition.x, f32(endPosition.y + lineHeight)));
        }
    }

    /** Paint each range highlight behind the text of its range. */
    function paintRangeHighlights(textLayout:TextLayout, window:Window):Void {
        final glyphs = glyphBoxes(textLayout, window.textStyle().textAlign, textLayout.bounds().size.width);
        final origin = textLayout.bounds().origin;
        final lineHeight = textLayout.lineHeight();
        for (item in rangeBackgrounds_) {
            for (box in rangeBoxes(glyphs, item.range)) {
                window.paintQuad(glaze.Prelude.fill(Bounds.fromCorners(
                    new Point(f32(origin.x + box.left), f32(origin.y + f32(lineHeight * box.row))),
                    new Point(f32(origin.x + box.right), f32(origin.y + f32(lineHeight * (box.row + 1))))
                ), item.color));
            }
        }
    }

/// Element

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final textStyle = textStyle_ != null ? textStyle_.clone() : window.textStyle();
        final runs = InlineHighlight.textRuns(Utf8.byteLength(text), textStyle, highlights);

        // Reuse the previous frame's shaped text when it was shaped from the
        // same text, runs and style; `StyledText` consumes its runs on every
        // layout, so they are handed over again either way.
        var retained = takeRetainedLayout(state);
        if (retained != null && !(retained.text == text && sameRuns(retained.runs, runs) && retained.textStyle.equals(textStyle))) {
            retained = null;
        }
        styledText = retained != null ? retained.styledText.withRuns(runs.copy()) : new StyledText(text).withRuns(runs.copy());
        retainedKeyRuns = runs;
        retainedKeyTextStyle = textStyle;
        return styledText.requestLayout(globalId, window, cx);
    }

    static function sameRuns(a:Array<TextRun>, b:Array<TextRun>):Bool {
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!a[i].equals(b[i])) {
                return false;
            }
        }
        return true;
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final bounds = new Bounds(paintOrigin_ != null ? paintOrigin_ : bounds.origin, bounds.size);
        styledText.prepaint(globalId, bounds, window, cx);
        reportToEditor();

        // Report this element's laid-out extent so an ancestor TextView with
        // `maxLines` can snap its clip to a whole-line boundary. The state
        // stack only holds an entry during prepaint when that view set
        // `maxLines`, so this is a no-op otherwise.
        final textViewState = GlobalState.global(cx).textViewState();
        if (textViewState != null) {
            final state = textViewState.read(cx);
            if (state.maxLines != null) {
                state.lineSpans.push(new LineSpan(bounds.top(), bounds.bottom(), window.lineHeight()));
            }
        }

        requestReveal(window);

        hitbox = window.insertHitbox(bounds, Normal);
        retainStyledText(cx);
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final bounds = new Bounds(paintOrigin_ != null ? paintOrigin_ : bounds.origin, bounds.size);
        final currentView = window.currentView();
        final hitbox = this.hitbox;
        if (!reclaimStyledText()) {
            // Cannot happen (only this element takes what it handed over,
            // and a live state is never swept); skip the frame rather than
            // paint an unmeasured placeholder.
            return;
        }
        final textLayout = styledText.layout();
        if (rangeBackgrounds_.length > 0) {
            paintRangeHighlights(textLayout, window);
        }
        textLayout.paintBackground(window, cx);

        // layout selections
        final layout = layoutSelections(textLayout, bounds, cx);
        final isSelectable = layout.isSelectable;
        final isSelection = layout.isSelection;
        final selection = layout.selection;

        final state = this.state;
        state.selection = selection;
        if (selectionSourceState != null && selection != null) {
            final source = selectionSourceState;
            final start = selectionSourceRange.start + selection.start;
            final end = selectionSourceRange.start + selection.end;
            final previous = source.selection;
            source.selection = previous != null ? new Selection(previous.start < start ? previous.start : start,
                previous.end > end ? previous.end : end) : new Selection(start, end);
        }

        if (isSelection || isSelectable) {
            window.setCursorStyle(IBeam, hitbox);
        }

        // link cursor pointer. Only text under the pointer reads where the pointer
        // is: under GPUI's retained views, reading it makes the text depend on
        // every pointer move, so a transcript of markdown would be drawn again
        // whenever the pointer moved anywhere.
        final hoveredLink = hitbox.isHovered(window) ? linkRangeForPosition(textLayout, links, window.mousePosition()) : null;
        if (hoveredLink != null) {
            window.setCursorStyle(PointingHand, hitbox);
        }

        final stateSelection = state.selection;
        if (stateSelection != null) {
            final textViewState = GlobalState.global(cx).textViewState();
            final color = textViewState != null ? textViewState.read(cx).textViewStyle.selection() : Theme.global(cx).tokens.colors.selection;
            paintSelection(stateSelection, textLayout, bounds, window, color);
            final edges = selectionEdges(stateSelection, textLayout);
            if (edges != null && textViewState != null) {
                textViewState.read(cx).selectionAdapter.registerSelectionEdges(edges.start, edges.end);
            }
        }

        textLayout.paintForeground(window, cx);

        if (isSelectable) {
            final textViewState = GlobalState.global(cx).textViewState();
            if (textViewState != null) {
                final copyLayout = new PaintedSelectionLayout(textLayout);
                final textBounds = textLineBounds(copyLayout, textLayout.lineHeight(), window.contentMask().bounds);
                final adapter = textViewState.read(cx).selectionAdapter;
                adapter.registerInline(textBounds);
                adapter.registerTextRun(new TextSelectionRun(text, textLayout, hitbox.bounds).withParagraph(selectionBounds_));
                final source = selectionSourceState != null ? selectionSourceState : this.state;
                final range = selectionSourceState != null ? selectionSourceRange : new Range(0, Utf8.byteLength(text));
                adapter.registerCopyProjection(CopyProjection.Text(new InlineSelectionProjection(source, range, text, copyLayout, selectionBounds_)), cx);
            }

            final text = this.text;
            final inlineState = this.state;
            final lineBounds = selectionBounds_;
            window.onMouseEvent(MouseDown, (e, phase, window, cx) -> {
                final event:MouseDownEvent = cast e;
                if (!phase.bubble() || !hitbox.isHovered(window) || event.button != MouseButton.Left) {
                    return;
                }

                if (event.clickCount == 3 && lineBounds != null) {
                    GlobalState.suppressTextSelection(cx);
                    if (textViewState != null) {
                        textViewState.update(cx, (state, cx) -> state.setMultiClickLine(lineBounds, cx.app));
                    }
                    cx.notify(currentView);
                    return;
                }

                // A finger selects read-only text with a long press only;
                // a double tap selects nothing here, neither the mouse's
                // plain word nor the window layer's touch selection. The
                // handles and the menu on a double tap belong to `Input`.
                if (event.clickCount == 2 && GlobalState.isTouchPress(cx)) {
                    GlobalState.suppressTextSelection(cx);
                    return;
                }

                final kind = switch event.clickCount {
                    case 2: TextViewMultiClickKind.Word;
                    case 3: TextViewMultiClickKind.Paragraph;
                    case _: return;
                };

                final range = selectionForMultiClick(text, textLayout, hitbox.bounds, event.position, kind);
                if (range == null) {
                    return;
                }
                final carets = rangeCarets(textLayout, range, lineBounds);
                if (carets == null) {
                    return;
                }

                final selectedText = Utf8.substring(text, range.start, range.end);

                // This renderer owns multi-click selection. Prevent the
                // window selection layer from handling the same press.
                GlobalState.suppressTextSelection(cx);

                inlineState.selection = Selection.fromRange(range);
                if (textViewState != null) {
                    textViewState.update(cx, (state, cx) -> {
                        state.setMultiClickSelection(event.position, kind, selectedText, carets.start, carets.end, cx.app);
                    });
                }
                cx.notify(currentView);
            });
        }

        // Mouse move: repaint only when the pointer enters, leaves or moves
        // between links, so the link cursor follows it. Hovering plain text
        // changes nothing painted.
        if (links.length > 0) {
            final links = this.links;
            var hoveredLink = hoveredLink;
            window.onMouseEvent(MouseMove, (e, phase, window, cx) -> {
                final event:MouseMoveEvent = cast e;
                if (!phase.bubble() || !hitbox.isHovered(window)) {
                    return;
                }

                final updated = linkRangeForPosition(textLayout, links, event.position);
                if (!sameRange(hoveredLink, updated)) {
                    hoveredLink = updated;
                    cx.notify(currentView);
                }
            });
        }

        if (!isSelection) {
            // click to open link
            final links = this.links;
            final textViewState = GlobalState.global(cx).textViewState();
            final linkClickHandler = this.linkClickHandler;
            window.onMouseEvent(MouseUp, (e, phase, window, cx) -> {
                final event:MouseUpEvent = cast e;
                if (!phase.bubble() || !hitbox.isHovered(window)) {
                    return;
                }
                if (textViewState != null && textViewState.read(cx).hasSelection(cx)) {
                    return;
                }

                final link = linkForPosition(textLayout, links, event.position);
                if (link != null) {
                    TextSelection.end(window, cx);
                    cx.stopPropagation();
                    final click = ClickEvent.Mouse(new MouseClickEvent(new MouseDownEvent(event.button, event.position, event.modifiers, event.clickCount, false), event));
                    TextView.handleLinkClick(linkClickHandler, link.url, click, window, cx);
                }
            });
        }

        retainStyledText(cx);
    }

    static inline function sameRange(a:Null<Range>, b:Null<Range>):Bool {
        return a == null ? b == null : b != null && a.start == b.start && a.end == b.end;
    }

/// Glyph boxes

    /**
     * The glyphs of `textLayout`, sorted by the text they draw, each placed
     * the way GPUI paints it: every row aligned in `alignWidth` by `align`,
     * and a glyph reaching to the next one on its row, or to the row's end.
     *
     * Glyphs are read in the order they paint, so right-to-left text, whose
     * glyphs paint in the reverse order of its text, is placed as it shows.
     */
    static function glyphBoxes(textLayout:TextLayout, align:TextAlign, alignWidth:Pixels):Array<GlyphBox> {
        final boxes:Array<GlyphBox> = [];
        var row = 0;
        var lineStart = 0;
        for (line in textLayout.lineLayouts()) {
            final layout = line.unwrappedLayout;
            final glyphs:Array<glaze.ShapedGlyph> = [];
            for (run in layout.runs) {
                for (glyph in run.glyphs) {
                    glyphs.push(glyph);
                }
            }
            // Each row starts at a wrap boundary glyph, and ends where the next
            // row starts, or at the end of the line.
            final runOffsets:Array<Int> = [];
            var offset = 0;
            for (run in layout.runs) {
                runOffsets.push(offset);
                offset += run.glyphs.length;
            }
            final rowEnds:Array<Int> = [for (boundary in line.wrapBoundaries) runOffsets[boundary.runIx] + boundary.glyphIx];
            rowEnds.push(glyphs.length);
            final lineBoxes = boxes.length;
            var from = 0;
            for (rowInLine in 0...rowEnds.length) {
                final to = rowEnds[rowInLine];
                final startX:Float = rowInLine == 0 ? 0 : glyphs[from].position.x;
                final endX:Float = to < glyphs.length ? glyphs[to].position.x : layout.width;
                final shift = f32(alignedRowLeft(align, alignWidth, f32(endX - startX)) - startX);
                for (ix in from...to) {
                    final glyph = glyphs[ix];
                    final right:Float = ix + 1 < to ? glyphs[ix + 1].position.x : endX;
                    boxes.push(new GlyphBox(new Range(lineStart + glyph.index, lineStart + glyph.index), row + rowInLine, f32(shift + glyph.position.x),
                        f32(shift + right)));
                }
                from = to;
            }

            // A glyph draws its text up to where the next glyph's text starts.
            // `sort_by_key` is stable: Haxe's `ArraySort` keeps the order of equal keys too.
            final sorted = boxes.splice(lineBoxes, boxes.length - lineBoxes);
            haxe.ds.ArraySort.sort(sorted, (a, b) -> a.text.start - b.text.start);
            final lineEnd = lineStart + line.len();
            for (ix in 0...sorted.length) {
                final start = sorted[ix].text.start;
                var end = lineEnd;
                for (k in (ix + 1)...sorted.length) {
                    if (sorted[k].text.start > start) {
                        end = sorted[k].text.start;
                        break;
                    }
                }
                sorted[ix].text = new Range(start, end);
            }
            for (glyph in sorted) {
                boxes.push(glyph);
            }

            row += line.wrapBoundaries.length + 1;
            lineStart = lineEnd + 1;
        }
        return boxes;
    }

    static function alignedRowLeft(align:TextAlign, alignWidth:Pixels, width:Pixels):Pixels {
        return switch align {
            case Left: 0;
            case Center: f32(f32(alignWidth - width) / 2.);
            case Right: f32(alignWidth - width);
        }
    }

    /**
     * The boxes behind the text of `range`, as a row and the horizontal extent
     * on it, from `glyphs` sorted by the text they draw: every glyph drawing
     * some of that text, joined where they touch on a row.
     */
    static function rangeBoxes(glyphs:Array<GlyphBox>, range:Range):Array<RowBox> {
        // `partition_point(|glyph| glyph.text.end <= range.start)`
        var lo = 0;
        var hi = glyphs.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (glyphs[mid].text.end <= range.start) {
                lo = mid + 1;
            }
            else {
                hi = mid;
            }
        }
        final hits:Array<RowBox> = [];
        for (ix in lo...glyphs.length) {
            final glyph = glyphs[ix];
            if (glyph.text.start >= range.end) {
                break;
            }
            hits.push(new RowBox(glyph.row, glyph.left, glyph.right));
        }
        haxe.ds.ArraySort.sort(hits, (a, b) -> {
            if (a.row != b.row) {
                return a.row < b.row ? -1 : 1;
            }
            return a.left < b.left ? -1 : (a.left > b.left ? 1 : 0);
        });

        final boxes:Array<RowBox> = [];
        for (hit in hits) {
            final last = boxes.length > 0 ? boxes[boxes.length - 1] : null;
            if (last != null && last.row == hit.row && hit.left <= last.right) {
                last.right = Math.max(last.right, hit.right);
            }
            else {
                boxes.push(new RowBox(hit.row, hit.left, hit.right));
            }
        }
        return boxes;
    }

    static function selectionForMultiClick(text:String, textLayout:TextLayout, bounds:Bounds, pos:Point, kind:TextViewMultiClickKind):Null<Range> {
        if (!bounds.contains(pos)) {
            return null;
        }

        final offset = switch textLayout.indexForPosition(pos) {
            case Ok(ix): ix;
            case Err(_): return null;
        }

        return switch kind {
            case Word: glaze.kit.base.text.Selection.wordRangeAt(text, offset);
            // Known limitation: a paragraph maps to a single Inline run here. When a
            // paragraph embeds an inline image it is split into multiple Inline runs,
            // so triple-click only selects the run on the clicked side of the image.
            case Paragraph | Line: text.length > 0 ? new Range(0, Utf8.byteLength(text)) : null;
        }
    }

    /**
     * The carets at the two ends of `range` in `textLayout`, spanning the
     * laid-out `row` when the text is one piece of a row.
     */
    static function rangeCarets(textLayout:TextLayout, range:Range, row:Null<Bounds>):Null<BoundsPair> {
        function caret(index:Int):Null<Bounds> {
            final position = textLayout.positionForIndex(index);
            if (position == null) {
                return null;
            }
            return row != null ? TouchSelectionSnapshot.caretLineBox(new Point(position.x, row.top()),
                row.size.height) : TouchSelectionSnapshot.caretLineBox(position, textLayout.lineHeight());
        }
        final start = caret(range.start);
        if (start == null) {
            return null;
        }
        final end = caret(range.end);
        if (end == null) {
            return null;
        }
        return new BoundsPair(start, end);
    }

    /**
     * Shared by paint and Copy: project the current gesture onto the same shaped
     * UTF-8 text, including rendered inline-code spacing.
     */
    static function projectSelection(text:String, textLayout:SelectionGeometry, selectionBounds:Null<Bounds>, selectionStart:Point,
            selectionEnd:Point):Null<Selection> {
        if (text.length == 0) {
            return null;
        }
        final textLen = Utf8.byteLength(text);
        final lineHeight = textLayout.lineHeight();
        var rowsTop:Float;
        var rowsBottom:Float;
        if (selectionBounds != null) {
            rowsTop = selectionBounds.top();
            rowsBottom = selectionBounds.bottom();
        }
        else {
            final extent = textLayout.rowsExtent();
            rowsTop = extent.top;
            rowsBottom = extent.bottom;
        }
        final bandTop = Math.min(selectionStart.y, selectionEnd.y);
        final bandBottom = Math.max(selectionStart.y, selectionEnd.y);
        if (rowsBottom <= bandTop || rowsTop > bandBottom) {
            return null;
        }
        if (bandTop < rowsTop && bandBottom >= rowsBottom && textLayout.len() >= textLen) {
            return new Selection(0, textLen);
        }

        var selection:Null<Selection> = null;
        final decoded = new Utf8Text(text);
        for (k in 0...decoded.count) {
            final offset = decoded.byteOffsets[k];
            final pos = textLayout.positionForIndex(offset);
            if (pos == null) {
                continue;
            }
            final nextOffset = offset + Utf8.codePointLength(decoded.codePoints[k]);
            var charWidth:Float = f32(lineHeight / 2);
            final nextPos = textLayout.positionForIndex(nextOffset);
            if (nextPos != null && nextPos.y == pos.y) {
                charWidth = f32(nextPos.x - pos.x);
            }
            final selectionPos = selectionBounds != null ? new Point(pos.x, selectionBounds.top()) : pos;
            final selectionHeight:Float = selectionBounds != null ? selectionBounds.size.height : lineHeight;
            if (pointInTextSelection(selectionPos, charWidth, selectionStart, selectionEnd, selectionHeight)) {
                if (selection == null) {
                    selection = new Selection(offset, offset);
                }
                selection.end = nextOffset;
            }
        }
        return selection;
    }

    /** Check if a `pos` is within a `bounds`, considering multi-line selections. */
    public static function pointInTextSelection(pos:Point, charWidth:Pixels, selectionStart:Point, selectionEnd:Point, lineHeight:Pixels):Bool {
        inline function pointInLine(point:Point):Bool {
            return point.y >= pos.y && point.y < f32(pos.y + lineHeight);
        }
        final top = Math.min(selectionStart.y, selectionEnd.y);
        final bottom = Math.max(selectionStart.y, selectionEnd.y);
        final x = f32(pos.x + f32(charWidth / 2));

        // Out of the vertical bounds
        if (f32(pos.y + lineHeight) <= top || pos.y > bottom) {
            return false;
        }

        // Treat the selection as single-line when both drag points fall within the
        // same rendered line, even if their y coordinates differ inside that line.
        if (pointInLine(selectionStart) && pointInLine(selectionEnd)) {
            final left = Math.min(selectionStart.x, selectionEnd.x);
            final right = Math.max(selectionStart.x, selectionEnd.x);
            return x >= left && x <= right;
        }

        final topPoint = selectionStart.y < selectionEnd.y ? selectionStart : selectionEnd;
        final bottomPoint = selectionStart.y < selectionEnd.y ? selectionEnd : selectionStart;
        final isTopLine = pointInLine(topPoint);
        final isBottomLine = pointInLine(bottomPoint);

        if (isTopLine) {
            return x >= topPoint.x;
        }
        else if (isBottomLine) {
            return x <= bottomPoint.x;
        }
        else {
            return true;
        }
    }

    /** Rust `f32` arithmetic: rounds a result to single precision. */
    static inline function f32(value:Float):Float {
        return taffy.util.F32.fround(value);
    }

}

/**
 * Rust `(u64, usize)` of `Inline::editor_piece`: the editor leaf `key` and
 * the leaf byte offset of the text's index 0.
 */
class EditorPiece {

    public final key:Int;

    public final start:Int;

    public inline function new(key:Int, start:Int) {
        this.key = key;
        this.start = start;
    }

}

/**
 * One frame's `StyledText`, kept for the next frame's `Inline` of the same
 * `InlineState`.
 *
 * A `TextLayout` remembers the size and the shaped lines of its last
 * measurement and answers a repeated measure at the same wrap width from
 * them, but a fresh `StyledText` every frame throws that away. Handing the
 * same `StyledText` to the next frame makes those measurements hits. A
 * layout is only reused when the text, the runs (colors, fades, fonts) and
 * the text style (font size, line height) it was shaped with are unchanged;
 * a different wrap width misses inside `TextLayout` and reshapes as before.
 *
 * Rust keeps these in a thread-local table keyed by the state's address,
 * with a `Weak` to tell a live state from a reused address, and sweeps the
 * entries of dropped states (a counter of drops, cleanup senders on each
 * state and a foreground task). The port is single threaded and has no
 * destructors, so the table is one slot on each `InlineState`
 * (`InlineState.retainedLayout`): an entry lives exactly as long as its
 * state, which is what the sweep achieves, and the Rust `state` field,
 * `cleanup_senders`, `RETAINED_SWEEP_AT` and `DROPPED_STATES` have no
 * counterpart.
 */
class RetainedLayout {

    public final styledText:StyledText;

    public final text:String;

    public final runs:Array<TextRun>;

    public final textStyle:TextStyle;

    public function new(styledText:StyledText, text:String, runs:Array<TextRun>, textStyle:TextStyle) {
        this.styledText = styledText;
        this.text = text;
        this.runs = runs;
        this.textStyle = textStyle;
    }

}

/**
 * The geometry a selection is projected on: a live `TextLayout`, or the
 * lines kept from a completed paint (Rust trait `SelectionGeometry`).
 */
interface SelectionGeometry {
    function len():Int;
    function lineHeight():Pixels;
    function rowsExtent():RowsExtentPair;
    function positionForIndex(index:Int):Null<Point>;
}

/** `(Pixels, Pixels)`: the top and the bottom of the laid-out rows. */
class RowsExtentPair {

    public final top:Float;

    public final bottom:Float;

    public inline function new(top:Float, bottom:Float) {
        this.top = top;
        this.bottom = bottom;
    }

}

/** `impl SelectionGeometry for TextLayout`. */
class TextLayoutGeometry implements SelectionGeometry {

    final layout:TextLayout;

    public inline function new(layout:TextLayout) {
        this.layout = layout;
    }

    public function len():Int {
        return layout.len();
    }

    public function lineHeight():Pixels {
        return layout.lineHeight();
    }

    public function rowsExtent():RowsExtentPair {
        final extent = TextSelection.textRowsExtent(layout, layout.lineHeight());
        return new RowsExtentPair(extent.top, extent.bottom);
    }

    public function positionForIndex(index:Int):Null<Point> {
        return layout.positionForIndex(index);
    }

}

/**
 * The native lines and placement of a completed paint. A `TextLayout` is
 * remeasured in place on the next frame; these shaped lines are not.
 */
class PaintedSelectionLayout implements SelectionGeometry {

    public final lines:Array<WrappedLineLayout>;

    public final bounds:Bounds;

    final lineHeight_:Pixels;

    final len_:Int;

    public function new(layout:TextLayout) {
        this.lines = layout.lineLayouts();
        this.bounds = layout.bounds();
        this.lineHeight_ = layout.lineHeight();
        this.len_ = layout.len();
    }

    public function len():Int {
        return len_;
    }

    public function lineHeight():Pixels {
        return lineHeight_;
    }

    public function positionForIndex(index:Int):Null<Point> {
        var originX:Float = bounds.origin.x;
        var originY:Float = bounds.origin.y;
        var start = 0;
        for (line in lines) {
            final end = start + line.len();
            if (index < start) {
                break;
            }
            if (index <= end) {
                final position = line.positionForIndex(index - start, lineHeight_);
                if (position == null) {
                    return null;
                }
                return new Point(taffy.util.F32.fround(originX + position.x), taffy.util.F32.fround(originY + position.y));
            }
            originY = taffy.util.F32.fround(originY + line.size(lineHeight_).height);
            start = end + 1;
        }
        return null;
    }

    public function rowsExtent():RowsExtentPair {
        final top = bounds.top();
        var lastLineTop:Float = top;
        for (i in 0...(lines.length > 0 ? lines.length - 1 : 0)) {
            lastLineTop = taffy.util.F32.fround(lastLineTop + lines[i].size(lineHeight_).height);
        }
        final lastRowTop:Float = lines.length == 0 ? top : taffy.util.F32.fround(lastLineTop
            + taffy.util.F32.fround(lines[lines.length - 1].wrapBoundaries.length * (lineHeight_ : Float)));
        return new RowsExtentPair(top, taffy.util.F32.fround(lastRowTop + lineHeight_));
    }

}

/** Targets the document-owned source state, never an ephemeral flow fragment. */
class InlineSelectionProjection {

    /** Rust holds a `Weak`: the port has no weak references, the projection lives for one frame. */
    final source:InlineState;

    final range:Range;

    final text:String;

    final layout:PaintedSelectionLayout;

    final selectionBounds:Null<Bounds>;

    public function new(source:InlineState, range:Range, text:String, layout:PaintedSelectionLayout, selectionBounds:Null<Bounds>) {
        this.source = source;
        this.range = range;
        this.text = text;
        this.layout = layout;
        this.selectionBounds = selectionBounds;
    }

    public function reset():Void {
        source.selection = null;
    }

    public function project(start:Point, end:Point):Void {
        @:privateAccess final selection = Inline.projectSelection(text, layout, selectionBounds, start, end);
        if (selection != null) {
            final start = range.start + selection.start;
            final end = range.start + selection.end;
            final previous = source.selection;
            source.selection = previous != null ? new Selection(previous.start < start ? previous.start : start,
                previous.end > end ? previous.end : end) : new Selection(start, end);
        }
    }

}

/**
 * Where one glyph of laid-out text paints: its row, and its horizontal
 * extent past the text's origin, alignment applied. `text` is the byte range
 * of the text it draws.
 */
class GlyphBox {

    public var text:Range;

    public final row:Int;

    public final left:Float;

    public final right:Float;

    public inline function new(text:Range, row:Int, left:Float, right:Float) {
        this.text = text;
        this.row = row;
        this.left = left;
        this.right = right;
    }

}

/** `(usize, Pixels, Pixels)`: a row and a horizontal extent on it. */
class RowBox {

    public final row:Int;

    public final left:Float;

    public var right:Float;

    public inline function new(row:Int, left:Float, right:Float) {
        this.row = row;
        this.left = left;
        this.right = right;
    }

}

/** `(Bounds<Pixels>, Bounds<Pixels>)`: the caret boxes at both ends of a selection. */
class BoundsPair {

    public final start:Bounds;

    public final end:Bounds;

    public inline function new(start:Bounds, end:Bounds) {
        this.start = start;
        this.end = end;
    }

}

/** `(is_selectable, is_selection, selection)` of `Inline::layout_selections`. */
private class SelectionLayout {

    public final isSelectable:Bool;

    public final isSelection:Bool;

    public final selection:Null<Selection>;

    public inline function new(isSelectable:Bool, isSelection:Bool, selection:Null<Selection>) {
        this.isSelectable = isSelectable;
        this.isSelection = isSelection;
        this.selection = selection;
    }

}
