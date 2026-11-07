// Ported from gpui-kit 0.8.1: crates/base/src/text/inline_flow.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.AbsoluteLength;
import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.ClickEvent;
import gpui.Corners;
import gpui.DefiniteLength;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.GlobalElementId;
import gpui.HighlightStyle;
import gpui.Hsla;
import gpui.ImageSource;
import gpui.LayoutId;
import gpui.LineWrapper;
import gpui.LineWrapper.IndentAdjustment;
import gpui.LineWrapper.LineFragment;
import gpui.ObjectFit;
import gpui.Pixels;
import gpui.Point;
import gpui.Range;
import gpui.ShapedLine;
import gpui.Size;
import gpui.SizeOf;
import gpui.Style;
import gpui.StyleRefinement;
import gpui.TextRun;
import gpui.TextStyle;
import gpui.TextStyleRefinement;
import gpui.Window;
import gpui.base.GlobalState;
import gpui.base.TextSelection;
import gpui.base.text.Inline.EditorPiece;
import gpui.base.theme.Theme;
import gpui.base.text.InlineNode.SharedFlag;
import gpui.base.text.InlineObject.MeasuredInlineObject;
import gpui.util.Utf8;
import unicode_segmentation.UnicodeSegmentation;

using gpui.AbsoluteLengthTools;
using gpui.DefiniteLengthTools;

/** Rust `LinkClickHandlerFn` (text_view.rs): `(url, event, window, cx)`. */
private typedef LinkClickHandler = (url:String, event:gpui.ClickEvent, window:gpui.Window, cx:gpui.App) -> Void;

/** Renders an inline element for a custom inline node, or `null` for its text. */
typedef InlineRenderer = (context:InlineRenderContext, window:Window, cx:App) -> Null<InlineElement>;

/**
 * One run of an inline flow: an atomic object, marked text or an image.
 */
enum InlineFlowItem {

    Object(text:String, id:Int, renderer:InlineRenderer, accessibilityLabel:String, selected:SharedFlag, style:HighlightStyle, link:Null<LinkMark>);

    /**
     * `backgrounds` are range highlight backgrounds, in this item's byte
     * space. They are only painted, so unlike `highlights` they take no part
     * in layout. `reveal` is the start of a pending reveal, when it is in
     * this item.
     */
    Text(state:InlineState, text:String, links:Array<RangedLink>, highlights:Array<RangedHighlight>, backgrounds:Array<RangedColor>, reveal:Null<RevealAt>);

    Image(source:ImageSource, link:Null<LinkMark>, title:String, width:Null<DefiniteLength>, height:Null<DefiniteLength>);

}

/**
 * Lays out mixed text, images and inline objects with wrapping, on one
 * shared baseline per line, then paints every fragment as its own element
 * (`Inline` for text, `InlineObject` for objects, `Img` for images).
 *
 * Differences with gpui-kit: Rust's `InlineFlowLayoutState` and prepaint
 * state are fields of the element.
 */
class InlineFlow extends gpui.Element {

    static final IMAGE_LEN:Int = 1;

    public static final INLINE_CODE_PADDING:Float = 4.;

    /** Bytes an image or custom inline node occupies in an editor leaf (one U+FFFC). */
    static final EDITOR_ATOM_LEN:Int = 3;

    /** How many wrap widths a flow keeps a layout for. */
    static final LAYOUTS_PER_FLOW:Int = 3;

    /** How many flows were laid out (wrapped and shaped). Rust counts it in tests only. */
    @:allow(tests)
    static var FLOW_LAYOUTS:Int = 0;

    var id:ElementId;

    final items:Array<InlineFlowItem>;

    final linkClickHandler:Null<LinkClickHandler>;

    /**
     * The block editor leaf this flow renders (design D3): its fragments
     * and atoms are reported to the editor sink as pieces.
     */
    var editorKey_:Null<Int> = null;

    /** Rust `InlineFlowLayoutState`. */
    var layoutState:Null<InlineFlowLayoutState> = null;

    /** Rust `PrepaintState`. */
    var paintItems:Array<FlowPaintItem> = [];

    public function new(id:ElementIdArg, items:Array<InlineFlowItem>, linkClickHandler:Null<LinkClickHandler>) {
        this.id = id;
        this.items = items;
        this.linkClickHandler = linkClickHandler;
    }

    public function editorKey(key:Null<Int>):InlineFlow {
        if (key != null) {
            this.id = ElementId.NamedInteger('editor-leaf', key);
        }
        this.editorKey_ = key;
        return this;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    static function imageElement(ix:Int, source:ImageSource, link:Null<LinkMark>, title:String, size:Size, linkClickHandler:Null<LinkClickHandler>):AnyElement {
        var image = gpui.Prelude.img(source).id(ix).objectFit(ObjectFit.Contain).maxW(gpui.Prelude.relative(1.)).w(gpui.Prelude.px(size.width)).h(gpui.Prelude.px(size.height));
        if (link != null) {
            final auxLink = link.clone();
            final auxLinkClickHandler = linkClickHandler;
            image = image.cursorPointer()
                .onClick((event, window, cx) -> {
                    TextSelection.end(window, cx);
                    cx.stopPropagation();
                    TextView.handleLinkClick(linkClickHandler, link.url, event, window, cx);
                })
                .onAuxClick((event, window, cx) -> {
                    TextSelection.end(window, cx);
                    cx.stopPropagation();
                    TextView.handleLinkClick(auxLinkClickHandler, auxLink.url, event, window, cx);
                });
        }
        return image.intoAnyElement();
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final frameState = window.withOptionalElementState(globalId, InlineFlowFrameState, (state, _) -> {
            var frameState:Null<InlineFlowFrameState> = state != null ? state.value : null;
            if (frameState == null) {
                frameState = new InlineFlowFrameState();
            }
            if (state != null) {
                state.value = frameState;
            }
            return frameState;
        });
        final measureItems = [for (item in items) MeasureItemTools.from(item)];
        // A measured-layout callback runs after the parent's text-style stack
        // is gone. Capture every resolved typography input while this element
        // is still requested under its Markdown block (notably headings).
        final typography = new InlineFlowTypography(window.textStyle(), window.remSize(), window.lineHeight());
        final imageSizes:Array<Null<Size>> = [
            for (ix in 0...measureItems.length)
                switch measureItems[ix] {
                    case Image(imageSource, width, height):
                        measureImageSize(ix, imageSource, width, height, typography.lineHeight, typography.remSize, window, cx);
                    case Text(_, _, _) | Object(_, _, _, _):
                        null;
                }
        ];
        final objects = prepareObjects(measureItems, typography.textStyle, window, cx);
        frameState.setKey(new FlowLayoutKey(measureItems, imageSizes, typography));
        final layoutState = new InlineFlowLayoutState(typography, frameState);
        this.layoutState = layoutState;

        return window.requestMeasuredLayout(@:privateAccess gpui.Style.sharedDefaultStyle(), (knownDimensions, availableSpace, window, cx) -> {
            final wrapWidth:Null<Float> = if (typography.textStyle.whiteSpace == Normal) {
                knownDimensions.width != null ? knownDimensions.width : switch availableSpace.width {
                    case Definite(width): width;
                    case _: null;
                };
            }
            else {
                null;
            };
            final state = frameState;
            final cached = state.layoutAt(wrapWidth);
            if (cached != null) {
                layoutState.current = cached;
                return cached.size;
            }
            final key = state.key;
            final layout = window.withRemSize(typography.remSize, window -> {
                window.withTextStyle(typography.textStyle.subtract(new TextStyleRefinement()), window -> {
                    layoutMeasuredFlow(key.items, key.imageSizes, objects, typography.textStyle, wrapWidth, window, cx);
                });
            });
            final size = layout.size;
            layoutState.current = layout;
            state.pushLayout(layout);
            return size;
        });
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        paintItems = [];
        final requestLayout = layoutState;
        if (requestLayout == null) {
            return;
        }
        final frameState = requestLayout.frameState;
        final layout = requestLayout.current;
        if (layout == null) {
            return;
        }
        final typography = requestLayout.typography;
        final textStyle = typography.textStyle;
        final elements:Array<FlowPaintItem> = [];

        // A reveal goes to the fragment it starts in. A line break lays out
        // no fragment, so a reveal starting on one, or on an empty line, goes
        // to the next fragment of its text, or to the last when none follows.
        var revealFound:Null<Int> = null;
        var revealFoundAfter = false;
        for (ix in 0...layout.fragments.length) {
            switch layout.fragments[ix] {
                case Text(itemIx, _, _, sourceRange, _, _, _, _, _, _):
                    switch items[itemIx] {
                        case Text(_, _, _, _, _, reveal) if (reveal != null):
                            final after = sourceRange.end > reveal.offset();
                            // `reduce(|found, next| if found.1 { found } else { next })`
                            if (revealFound == null || !revealFoundAfter) {
                                revealFound = ix;
                                revealFoundAfter = after;
                            }
                        case _:
                    }
                case _:
            }
        }
        final revealFragment = revealFound;

        // Editor leaf byte offset where each item starts: text items count
        // their bytes, images and custom nodes one U+FFFC.
        final key = editorKey_;
        final sink = key != null ? EditorSeam.current() : null;
        final editor = key != null && sink != null;
        // Ordinary TextViews do not allocate editor bookkeeping.
        final itemStarts:Array<Int> = [];
        if (editor) {
            sink.beginPieces(key);
            var at = 0;
            for (item in items) {
                itemStarts.push(at);
                at += switch item {
                    case Text(_, text, _, _, _, _): Utf8.byteLength(text);
                    case _: EDITOR_ATOM_LEN;
                };
            }
        }
        if (editor) {
            for (empty in layout.emptyLines) {
                final start = empty.start;
                final lineBounds = empty.bounds;
                // Flow layout uses a one-byte object placeholder; the public
                // leaf coordinate space uses the three-byte U+FFFC instead.
                var flowStart = 0;
                var leafStart = 0;
                for (item in items) {
                    final len = switch item {
                        case Text(_, text, _, _, _, _): Utf8.byteLength(text);
                        case _: IMAGE_LEN;
                    };
                    if (flowStart + len > start) {
                        break;
                    }
                    flowStart += len;
                    leafStart += switch item {
                        case Text(_, text, _, _, _, _): Utf8.byteLength(text);
                        case _: EDITOR_ATOM_LEN;
                    };
                }
                sink.reportEmptyPiece(key, leafStart + start - flowStart, new Bounds(bounds.origin.add(lineBounds.origin), lineBounds.size));
            }
        }
        final decorations = editor ? sink.backgrounds(key) : null;
        function reportBox(itemIx:Int, bounds:Bounds):Array<FlowOverlay> {
            final overlays:Array<FlowOverlay> = [];
            if (editor) {
                final start = itemStarts[itemIx];
                final end = start + EDITOR_ATOM_LEN;
                sink.reportBoxPiece(key, new Range(start, end), bounds);
                for (decoration in (decorations != null ? decorations : [])) {
                    final range = decoration.range;
                    if (range.start < range.end && range.start < end && range.end > start) {
                        overlays.push(new FlowOverlay(bounds, decoration.color));
                    }
                }
            }
            return overlays;
        }

        var textFragmentCount = 0;
        for (fragmentIx in 0...layout.fragments.length) {
            switch layout.fragments[fragmentIx] {
                case Object(itemIx, origin, object, selectionBounds):
                    switch items[itemIx] {
                        case Object(text, id, _, accessibilityLabel, selected, _, link):
                            final objectSize = object.metrics.size;
                            final overlays = reportBox(itemIx, new Bounds(bounds.origin.add(origin), objectSize));
                            final element = new InlineObject(ElementId.NamedInteger('inline-object', id), text, accessibilityLabel, object.clone(), selected,
                                new Bounds(bounds.origin.add(selectionBounds.origin), selectionBounds.size),
                                new Bounds(new Point(bounds.left(), f32(bounds.top() + selectionBounds.top())),
                                    new Size(bounds.size.width, selectionBounds.size.height)))
                                .link(link, linkClickHandler)
                                .intoAnyElement();
                            element.prepaintAsRoot(bounds.origin.add(origin),
                                new SizeOf<AvailableSpace>(Definite(objectSize.width), Definite(objectSize.height)), window, cx);
                            elements.push(new FlowPaintItem(element, null, overlays));
                        case _:
                            continue;
                    }
                case Text(itemIx, origin, fragmentSize, sourceRange, fontSize, text, links, highlights, selectionBounds, codeBackground):
                    switch items[itemIx] {
                        case Text(sourceState, _, _, _, backgrounds, reveal):
                            final state = frameState.fragmentState(textFragmentCount);
                            textFragmentCount += 1;
                            state.setText(text);

                            final insets = InlineHighlight.codeInsetsOf(highlights, fontSize, window.remSize());
                            final background = codeBackground != null ? codeBackground.offset(bounds.origin) : null;
                            // The fragment's typography: the flow's style at the
                            // fragment's size, on one line. Fragments are already
                            // wrapped, so this leaf must not wrap independently.
                            final fragmentStyle = textStyle.clone();
                            fragmentStyle.fontSize = AbsoluteLength.Pixels(fontSize);
                            fragmentStyle.lineHeight = DefiniteLength.Absolute(AbsoluteLength.Pixels(f32(f32(fragmentSize.height - insets.top) - insets.bottom)));
                            fragmentStyle.whiteSpace = Nowrap;
                            final paintOrigin = bounds.origin.add(origin).add(new Point(insets.left, insets.top));
                            final element = new Inline(state, links.copy(), [for (h in highlights) new RangedHighlight(h.range, h.highlight.clone())], linkClickHandler)
                                .selectionSource(sourceState, sourceRange)
                                .rangeBackgrounds(sliceRanges(backgrounds, b -> b.range, sourceRange.start, sourceRange.end, (range, b) -> new RangedColor(range, b.color)))
                                .reveal(reveal != null && revealFragment == fragmentIx ? reveal.clamp(sourceRange.start, sourceRange.end) : null)
                                .textStyle(fragmentStyle.clone())
                                .editorPiece(editor ? new EditorPiece(key, itemStarts[itemIx] + sourceRange.start) : null)
                                .selectionBounds(new Bounds(new Point(bounds.left(), f32(bounds.top() + selectionBounds.top())),
                                    new Size(bounds.size.width, selectionBounds.size.height)))
                                .paintOrigin(paintOrigin)
                                .intoAnyElement();
                            // The `Inline` is its own layout root, with no box around
                            // it: its text measures with the window's text style, so
                            // the fragment's style is pushed for the layout.
                            window.withRemSize(typography.remSize, window -> {
                                window.withTextStyle(fragmentStyle.subtract(new TextStyleRefinement()), window -> {
                                    element.prepaintAsRoot(paintOrigin,
                                        new SizeOf<AvailableSpace>(Definite(f32(f32(fragmentSize.width - insets.left) - insets.right)),
                                            Definite(f32(f32(fragmentSize.height - insets.top) - insets.bottom))), window, cx);
                                });
                            });
                            elements.push(new FlowPaintItem(element, background, []));
                        case _:
                            continue;
                    }
                case Image(itemIx, origin, fragmentSize):
                    switch items[itemIx] {
                        case Image(imageSource, link, title, _, _):
                            final overlays = reportBox(itemIx, new Bounds(bounds.origin.add(origin), fragmentSize));
                            final element = imageElement(elements.length, imageSource, link, title, fragmentSize, linkClickHandler);
                            element.prepaintAsRoot(bounds.origin.add(origin),
                                new SizeOf<AvailableSpace>(Definite(fragmentSize.width), Definite(fragmentSize.height)), window, cx);
                            elements.push(new FlowPaintItem(element, null, overlays));
                        case _:
                            continue;
                    }
            }
        }

        frameState.truncateFragmentStates(textFragmentCount);

        paintItems = elements;
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final view = GlobalState.global(cx).textViewState();
        final preserveSelection = view != null && view.read(cx).preserveInlineSelection;
        for (item in items) {
            if (!preserveSelection) {
                switch item {
                    case Text(state, _, _, _, _, _):
                        state.selection = null;
                    case _:
                }
            }
        }
        final radius = Theme.global(cx).tokens.radius.sm;
        for (item in paintItems) {
            final code = item.background;
            if (code != null) {
                final style = new Style();
                style.cornerRadiusTopLeft = AbsoluteLength.Pixels(radius);
                style.cornerRadiusTopRight = AbsoluteLength.Pixels(radius);
                style.cornerRadiusBottomLeft = AbsoluteLength.Pixels(radius);
                style.cornerRadiusBottomRight = AbsoluteLength.Pixels(radius);
                style.refine(code.style);
                style.paint(code.bounds, window, cx, (_, _) -> {});
            }
            item.element.paint(window, cx);
            for (overlay in item.overlays) {
                window.paintQuad(gpui.Prelude.fill(overlay.bounds, overlay.color));
            }
        }
    }

    /** Intrinsic width for table sizing, using the same objects and wrapping inputs as painting. */
    public static function intrinsicWidth(items:Array<InlineFlowItem>, window:Window, cx:App):Pixels {
        final items = [for (item in items) MeasureItemTools.from(item)];
        final lineHeight = window.lineHeight();
        final remSize = window.remSize();
        final images:Array<Null<Size>> = [
            for (ix in 0...items.length)
                switch items[ix] {
                    case Image(imageSource, width, height):
                        measureImageSize(ix, imageSource, width, height, lineHeight, remSize, window, cx);
                    case _:
                        null;
                }
        ];
        return layoutFlow(items, images, window.textStyle(), null, window, cx).size.width;
    }

    static function prepareObjects(items:Array<MeasureItem>, textStyle:TextStyle, window:Window, cx:App):Array<Null<MeasuredInlineObject>> {
        return [
            for (item in items)
                switch item {
                    case Object(text, id, renderer, style):
                        final style = textStyle.clone().highlight(style);
                        final context = new InlineRenderContext(style.clone(), style.fontSize.toPixels(window.remSize()),
                            style.lineHeightInPixels(window.remSize()), window.remSize());
                        // Must be the id `InlineObject` paints under: GPUI asserts a
                        // stateful child (a plugin's HoverCard) sees the same id path
                        // in request_layout as in prepaint, and the element is laid
                        // out here but painted inside `InlineObject`.
                        window.withId(ElementId.NamedInteger('inline-object', id), window -> {
                            final element = window.withTextStyle(style.subtract(new TextStyleRefinement()), window -> renderer(context, window, cx));
                            return MeasuredInlineObject.measure(text, element, style, window, cx);
                        });
                    case _:
                        null;
                }
        ];
    }

    static function layoutFlow(items:Array<MeasureItem>, imageSizes:Array<Null<Size>>, textStyle:TextStyle, wrapWidth:Null<Pixels>, window:Window,
            cx:App):InlineFlowLayout {
        final objects = prepareObjects(items, textStyle, window, cx);
        return layoutMeasuredFlow(items, imageSizes, objects, textStyle, wrapWidth, window, cx);
    }

    static function layoutMeasuredFlow(items:Array<MeasureItem>, imageSizes:Array<Null<Size>>, preparedObjects:Array<Null<MeasuredInlineObject>>,
            textStyle:TextStyle, wrapWidth:Null<Pixels>, window:Window, cx:App):InlineFlowLayout {
        FLOW_LAYOUTS += 1;
        final remSize = window.remSize();
        final lineHeight = plainLineHeight(textStyle, remSize, window);
        var totalLen = 0;
        for (item in items) {
            totalLen += MeasureItemTools.len(item);
        }
        if (totalLen == 0) {
            return new InlineFlowLayout([], [], new Size(0, 0), null);
        }

        final objects = [for (object in preparedObjects) object != null ? object.fitText(wrapWidth) : null];
        final lineRanges = lineRanges(items, imageSizes, objects, textStyle, wrapWidth, window);
        final fontSize:Pixels = textStyle.fontSize.toPixels(remSize);
        final fragments:Array<PositionedFragment> = [];
        final emptyLines:Array<EmptyLine> = [];
        var maxWidth:Float = 0;
        var y:Float = 0;

        for (lineRange in lineRanges) {
            final lineFragments:Array<LineFragmentLayout> = [];
            var lineWidth:Float = 0;
            // `LineLayout` is the metric source used by the text paint path. Its
            // descent is normalized positive by native backends, whereas
            // `FontMetrics.descent` remains signed. Start with the same shaped
            // body metrics used below for every text fragment rather than mixing
            // those two conventions through `TextSystem.baselineOffset`.
            final bodyRuns = InlineHighlight.textRuns(1, textStyle, []);
            final bodyLine = shapeLine(' ', fontSize, bodyRuns, window);
            final bodyBaseline = centeredBaseline(bodyLine, lineHeight);
            // Like a plain text line, the body line box is the line height even
            // when the font's glyphs are taller; runs may overflow it as far as
            // body glyphs do.
            final bodyOverflowAbove = Math.max(f32(bodyLine.ascent() - bodyBaseline), 0);
            final bodyOverflowBelow = Math.max(f32(bodyLine.descent() - f32(lineHeight - bodyBaseline)), 0);
            var lineAscent:Float = bodyBaseline;
            var lineDescent:Float = f32(lineHeight - bodyBaseline);
            var itemStart = 0;

            for (itemIx in 0...items.length) {
                final item = items[itemIx];
                final itemEnd = itemStart + MeasureItemTools.len(item);
                if (itemEnd <= lineRange.start) {
                    itemStart = itemEnd;
                    continue;
                }
                if (itemStart >= lineRange.end) {
                    break;
                }

                switch item {
                    case Text(text, links, highlights):
                        final localStart = (lineRange.start > itemStart ? lineRange.start : itemStart) - itemStart;
                        final localEnd = (lineRange.end < itemEnd ? lineRange.end : itemEnd) - itemStart;
                        for (sized in InlineHighlight.textSizeRanges(Utf8.byteLength(text), highlights, fontSize, window.remSize())) {
                            final segment = sized.range;
                            final scale = sized.fadeOut;
                            final start = localStart > segment.start ? localStart : segment.start;
                            final end = localEnd < segment.end ? localEnd : segment.end;
                            if (start >= end) {
                                continue;
                            }
                            final subtext = Utf8.substring(text, start, end);
                            final highlights = sliceRanges(highlights, h -> h.range, start, end, (range, h) -> new RangedHighlight(range, h.highlight.clone()));
                            final links = sliceRanges(links, l -> l.range, start, end, (range, l) -> new RangedLink(range, l.link.clone()));
                            final runs = InlineHighlight.textRuns(Utf8.byteLength(subtext), textStyle, highlights);
                            final segmentFontSize = f32(fontSize * scale);
                            final shapedLine = shapeLine(subtext, segmentFontSize, runs, window);
                            var isCode = false;
                            for (h in highlights) {
                                if (h.highlight.fontSizeScale != null) {
                                    isCode = true;
                                    break;
                                }
                            }
                            final insets = InlineHighlight.codeInsetsOf(highlights, segmentFontSize, window.remSize());
                            final width = f32(f32(shapedLine.width() + insets.left) + insets.right);
                            // Measure the run by its glyph box. The body strut already
                            // carries the line's leading, so a run only has to fit its
                            // glyphs: leading of its own would make a smaller or
                            // differently proportioned run, such as inline code, push
                            // its line taller than a plain one. Positioning grows the
                            // box back to the line. The compact code background is
                            // painted independently.
                            final glyphSize = new Size(width, f32(f32(f32(shapedLine.ascent() + shapedLine.descent()) + insets.top) + insets.bottom));
                            final baseline = f32(shapedLine.ascent() + insets.top);
                            final codeBackground = isCode ? codeBackground(shapedLine, runs, segmentFontSize, highlights, glyphSize, baseline, window) : null;
                            lineAscent = Math.max(lineAscent, f32(baseline - bodyOverflowAbove));
                            lineDescent = Math.max(lineDescent, f32(f32(glyphSize.height - baseline) - bodyOverflowBelow));
                            lineWidth = f32(lineWidth + width);
                            lineFragments.push(new LineFragmentLayout(itemIx, LineFragmentKind.Text(segmentFontSize, subtext, links, highlights, codeBackground),
                                glyphSize, new Range(start, end), baseline));
                        }
                    case Object(_, _, _, _):
                        final object = objects[itemIx].clone();
                        final metrics = object.metrics;
                        lineAscent = Math.max(lineAscent, metrics.baseline);
                        lineDescent = Math.max(lineDescent, f32(metrics.size.height - (metrics.baseline : Float)));
                        lineWidth = f32(lineWidth + metrics.size.width);
                        lineFragments.push(new LineFragmentLayout(itemIx, LineFragmentKind.Object(object), metrics.size, new Range(0, IMAGE_LEN), metrics.baseline));
                    case Image(_, _, _):
                        if (lineRange.start <= itemStart && itemEnd <= lineRange.end) {
                            final size = imageSizes[itemIx];
                            if (size == null) {
                                throw 'image size should be measured before layout';
                            }
                            lineWidth = f32(lineWidth + size.width);
                            final baseline = Math.min(Math.max(f32(f32(f32(size.height / 2.) + bodyBaseline) - f32(lineHeight / 2.)), 0), size.height);
                            lineAscent = Math.max(lineAscent, baseline);
                            lineDescent = Math.max(lineDescent, f32(size.height - baseline));
                            lineFragments.push(new LineFragmentLayout(itemIx, LineFragmentKind.Image, size, new Range(0, IMAGE_LEN), baseline));
                        }
                }

                itemStart = itemEnd;
            }

            if (lineRange.isEmpty()) {
                emptyLines.push(new EmptyLine(lineRange.start, new Bounds(new Point(0, y), new Size(0, f32(lineAscent + lineDescent)))));
            }
            var x:Float = 0;
            for (fragment in lineFragments) {
                // Give a text run's glyph box equal leading on both sides, as
                // much as the line allows: its glyphs are painted centered in the
                // box, so this keeps them on the line's baseline, and a body run
                // gets exactly the line box. The leading is negative where the
                // glyphs overflow the line, as a plain text line's do.
                final leading:Float = switch fragment.kind {
                    case Text(_, _, _, _, _):
                        Math.max(Math.min(f32(lineAscent - fragment.baseline), f32(lineDescent - f32(fragment.size.height - fragment.baseline))),
                            f32(-fragment.size.height / 2.));
                    case _:
                        0;
                };
                fragment.size = new Size(fragment.size.width, f32(fragment.size.height + f32(leading * 2.)));
                fragment.baseline = f32(fragment.baseline + leading);
                final origin = new Point(x, f32(f32(y + lineAscent) - fragment.baseline));
                final selectionBounds = new Bounds(new Point(x, y), new Size(fragment.size.width, f32(lineAscent + lineDescent)));
                final positioned = switch fragment.kind {
                    case Object(object):
                        PositionedFragment.Object(fragment.itemIx, origin, object, selectionBounds);
                    case Text(fontSize, text, links, highlights, codeBackground):
                        PositionedFragment.Text(fragment.itemIx, origin, fragment.size, fragment.sourceRange, fontSize, text, links, highlights,
                            selectionBounds, codeBackground != null ? codeBackground.offset(origin.add(new Point(0, leading))) : null);
                    case Image:
                        PositionedFragment.Image(fragment.itemIx, origin, fragment.size);
                };
                x = f32(x + fragment.size.width);
                fragments.push(positioned);
            }

            maxWidth = Math.max(maxWidth, lineWidth);
            y = f32(y + f32(lineAscent + lineDescent));
        }

        return new InlineFlowLayout(fragments, emptyLines, new Size(maxWidth, y), wrapWidth);
    }

    /**
     * The rounded box behind a code span, relative to the fragment: centered on
     * the capital-height body of the text, with the descender room shared
     * between both sides instead of added only below. Takes the background
     * color out of `highlights`, so the text does not paint it a second time
     * at the full line height.
     */
    static function codeBackground(shapedLine:ShapedLine, runs:Array<TextRun>, fontSize:Pixels, highlights:Array<RangedHighlight>, fragmentSize:Size,
            baseline:Pixels, window:Window):Null<CodeBox> {
        var capHeight:Float = 0;
        for (run in runs) {
            final font = window.textSystem().resolveFont(run.font);
            capHeight = Math.max(capHeight, window.textSystem().textSystem.capHeight(font, fontSize));
        }
        final verticalPadding = f32(f32(fontSize * 0.125) + f32(shapedLine.descent() / 2.));
        var color:Null<Hsla> = null;
        for (h in highlights) {
            if (h.highlight.style.backgroundColor != null) {
                color = h.highlight.style.backgroundColor;
                break;
            }
        }
        var style:Null<StyleRefinement> = null;
        for (h in highlights) {
            if (h.highlight.codeStyle != null) {
                style = h.highlight.codeStyle.clone();
                break;
            }
        }
        if (style == null) {
            style = new StyleRefinement();
        }
        if (style.background == null && color != null) {
            style.background = gpui.Background.fromHsla(color);
        }
        for (h in highlights) {
            h.highlight.style.backgroundColor = null;
        }
        final insets = InlineHighlight.codeInsetsOf(highlights, fontSize, window.remSize());
        final top = if (style.paddingTop != null) {
            f32(f32(shapedLine.ascent() - capHeight) + insets.top);
        }
        else {
            f32(verticalPadding + (style.borderWidthTop != null ? style.borderWidthTop.toPixels(window.remSize()) : 0.));
        };
        final bottom = if (style.paddingBottom != null) {
            f32(shapedLine.descent() + insets.bottom);
        }
        else {
            f32(verticalPadding + (style.borderWidthBottom != null ? style.borderWidthBottom.toPixels(window.remSize()) : 0.));
        };
        return new CodeBox(new Bounds(new Point(0, f32(f32(baseline - capHeight) - top)), new Size(fragmentSize.width, f32(f32(capHeight + top) + bottom))),
            style);
    }

    static function lineRanges(items:Array<MeasureItem>, imageSizes:Array<Null<Size>>, objects:Array<Null<MeasuredInlineObject>>, textStyle:TextStyle,
            wrapWidth:Null<Pixels>, window:Window):Array<Range> {
        var totalLen = 0;
        for (item in items) {
            totalLen += MeasureItemTools.len(item);
        }
        final hardLines:Array<Range> = [];
        var lineStart = 0;
        var itemStart = 0;

        for (item in items) {
            switch item {
                case Text(text, _, _):
                    // `match_indices('\n')`: a newline is one byte, the same in UTF-8 and here.
                    final decoded = new gpui.util.Utf8.Utf8Text(text);
                    for (k in 0...decoded.count) {
                        if (decoded.codePoints[k] == '\n'.code) {
                            final newline = itemStart + decoded.byteOffsets[k];
                            hardLines.push(new Range(lineStart, newline));
                            lineStart = newline + 1;
                        }
                    }
                case _:
            }
            itemStart += MeasureItemTools.len(item);
        }
        hardLines.push(new Range(lineStart, totalLen));

        if (wrapWidth == null) {
            return hardLines;
        }
        final wrapWidth:Float = wrapWidth;
        final remSize = window.remSize();
        final fontSize:Pixels = textStyle.fontSize.toPixels(remSize);
        final wrapper = window.textSystem().lineWrapper(textStyle.font(), fontSize);
        final ranges:Array<Range> = [];

        for (hardLine in hardLines) {
            if (hardLine.isEmpty()) {
                ranges.push(hardLine);
                continue;
            }
            var itemStart = 0;
            final wrapFragments:Array<WrapFragment> = [];
            for (ix in 0...items.length) {
                final item = items[ix];
                final itemEnd = itemStart + MeasureItemTools.len(item);
                if (itemEnd > hardLine.start && itemStart < hardLine.end) {
                    switch item {
                        case Text(text, _, highlights):
                            final start = (hardLine.start > itemStart ? hardLine.start : itemStart) - itemStart;
                            final end = (hardLine.end < itemEnd ? hardLine.end : itemEnd) - itemStart;
                            if (start < end) {
                                pushTextWrapFragments(wrapFragments, text, highlights, new Range(start, end), textStyle, wrapWidth, window);
                            }
                        case Object(_, _, _, _):
                            wrapFragments.push(WrapFragment.Element(objects[ix].metrics.size.width, IMAGE_LEN));
                        case Image(_, _, _):
                            if (hardLine.start <= itemStart && itemEnd <= hardLine.end) {
                                final size = imageSizes[ix];
                                if (size == null) {
                                    throw 'image size should be measured before wrapping';
                                }
                                wrapFragments.push(WrapFragment.Element(size.width, IMAGE_LEN));
                            }
                    }
                }
                itemStart = itemEnd;
            }

            // The wrapper sums per-character widths, which can be narrower than the
            // shaped run (CoreText sets an isolated full-width `，` at half width).
            // Check each line against the shaped spans and re-wrap it tighter when
            // it overflows, so the painted line never exceeds `wrapWidth`.
            final spans = shapedSpans(items, imageSizes, objects, textStyle, hardLine, window);
            var start = hardLine.start;
            while (start < hardLine.end) {
                final rest = fragmentsFrom(wrapFragments, start - hardLine.start);
                var budget:Float = wrapWidth;
                var end = nextWrap(wrapper, rest, budget, start, hardLine.end);
                var overflow = f32(spansWidth(spans, new Range(start, end)) - wrapWidth);
                // Shrink the wrapper's budget by the overflow until it breaks earlier,
                // doubling the step while the break stays put. A single glyph wider
                // than the line keeps its line and overflows as before.
                var step = overflow;
                while (overflow > 0) {
                    budget = f32(budget - Math.max(step, 0.5));
                    if (budget <= 0) {
                        break;
                    }
                    final tighter = nextWrap(wrapper, rest, budget, start, hardLine.end);
                    if (tighter < end) {
                        end = tighter;
                        overflow = f32(spansWidth(spans, new Range(start, end)) - wrapWidth);
                        step = overflow;
                    }
                    else {
                        step = f32(step * 2.);
                    }
                }
                // The wrapper can also break a rest that fits: kerning makes a
                // shaped run narrower than its summed characters. A table column
                // sized to its measured text would drop its last character.
                if (end < hardLine.end && spansWidth(spans, new Range(start, hardLine.end)) <= wrapWidth) {
                    end = hardLine.end;
                }
                ranges.push(new Range(start, end));
                start = end;
            }

            if (hardLine.isEmpty()) {
                ranges.push(hardLine);
            }
        }

        return ranges;
    }

    /**
     * Where the first line of `fragments` (which start at byte `start`) wraps at
     * `wrapWidth`; `end` when it all fits.
     */
    static function nextWrap(wrapper:LineWrapper, fragments:Array<WrapFragment>, wrapWidth:Pixels, start:Int, end:Int):Int {
        final lineFragments = [
            for (fragment in fragments)
                switch fragment {
                    case Text(text): LineFragment.Text(text);
                    case Element(width, lenUtf8): LineFragment.Element(width, lenUtf8);
                }
        ];
        final boundaries = wrapper.wrapLine(lineFragments, wrapWidth, SameIndent);
        if (boundaries.length == 0) {
            return end;
        }
        final ix = start + boundaries[0].ix;
        return ix < end ? ix : end;
    }

    /**
     * `fragments` with their first `skip` bytes dropped. Wrap boundaries fall on
     * character or element starts, so a text fragment is split on a char boundary.
     */
    static function fragmentsFrom(fragments:Array<WrapFragment>, skip:Int):Array<WrapFragment> {
        var offset = 0;
        final out:Array<WrapFragment> = [];
        for (fragment in fragments) {
            final len = switch fragment {
                case Text(text): Utf8.byteLength(text);
                case Element(_, lenUtf8): lenUtf8;
            };
            if (offset + len <= skip) {
                offset += len;
                continue;
            }
            out.push(switch fragment {
                case Text(text): WrapFragment.Text(Utf8.substringFrom(text, skip > offset ? skip - offset : 0));
                case Element(width, lenUtf8): WrapFragment.Element(width, lenUtf8);
            });
            offset += len;
        }
        return out;
    }

    static function shapedSpans(items:Array<MeasureItem>, imageSizes:Array<Null<Size>>, objects:Array<Null<MeasuredInlineObject>>, textStyle:TextStyle,
            hardLine:Range, window:Window):Array<ShapedSpan> {
        final fontSize:Pixels = textStyle.fontSize.toPixels(window.remSize());
        final spans:Array<ShapedSpan> = [];
        var itemStart = 0;
        for (ix in 0...items.length) {
            final item = items[ix];
            final itemEnd = itemStart + MeasureItemTools.len(item);
            if (itemEnd > hardLine.start && itemStart < hardLine.end) {
                switch item {
                    case Text(text, _, highlights):
                        final localStart = (hardLine.start > itemStart ? hardLine.start : itemStart) - itemStart;
                        final localEnd = (hardLine.end < itemEnd ? hardLine.end : itemEnd) - itemStart;
                        for (sized in InlineHighlight.textSizeRanges(Utf8.byteLength(text), highlights, fontSize, window.remSize())) {
                            final segment = sized.range;
                            final scale = sized.fadeOut;
                            final start = localStart > segment.start ? localStart : segment.start;
                            final end = localEnd < segment.end ? localEnd : segment.end;
                            if (start >= end) {
                                continue;
                            }
                            final highlights = sliceRanges(highlights, h -> h.range, start, end, (range, h) -> new RangedHighlight(range, h.highlight.clone()));
                            final runs = InlineHighlight.textRuns(end - start, textStyle, highlights);
                            final line = shapeLine(Utf8.substring(text, start, end), f32(fontSize * scale), runs, window);
                            final insets = InlineHighlight.codeInsetsOf(highlights, f32(fontSize * scale), window.remSize());
                            final padding = f32(insets.left + insets.right);
                            spans.push(ShapedSpan.Text(new Range(itemStart + start, itemStart + end), line, padding));
                        }
                    case Object(_, _, _, _):
                        spans.push(ShapedSpan.Fixed(new Range(itemStart, itemEnd), objects[ix].metrics.size.width));
                    case Image(_, _, _):
                        final size = imageSizes[ix];
                        if (size != null) {
                            spans.push(ShapedSpan.Fixed(new Range(itemStart, itemEnd), size.width));
                        }
                }
            }
            itemStart = itemEnd;
        }
        return spans;
    }

    /**
     * Painted width of `range`: in-context glyph advances of the shaped spans it
     * covers, plus the fixed spans that lie inside it.
     */
    static function spansWidth(spans:Array<ShapedSpan>, range:Range):Pixels {
        var sum:Float = 0;
        for (span in spans) {
            final width:Float = switch span {
                case Text(spanRange, line, padding):
                    final start = range.start > spanRange.start ? range.start : spanRange.start;
                    final end = range.end < spanRange.end ? range.end : spanRange.end;
                    if (start >= end) {
                        0;
                    }
                    else {
                        f32(f32(line.xForIndex(end - spanRange.start) - line.xForIndex(start - spanRange.start)) + padding);
                    }
                case Fixed(spanRange, width):
                    range.start <= spanRange.start && spanRange.end <= range.end ? width : 0;
            };
            sum = f32(sum + width);
        }
        return sum;
    }

    /**
     * Appends the wrap fragments for `range` of `text`. The line wrapper
     * measures text fragments in the body font, so a span whose highlight sets
     * another family is shaped with the same run the renderer uses and enters
     * the wrapper as measured elements. Oversized spans retain word boundaries;
     * oversized words can break at grapheme boundaries without splitting Unicode.
     */
    static function pushTextWrapFragments(fragments:Array<WrapFragment>, text:String, highlights:Array<RangedHighlight>, range:Range, textStyle:TextStyle,
            wrapWidth:Pixels, window:Window):Void {
        final fontSize:Pixels = textStyle.fontSize.toPixels(window.remSize());
        var cursor = range.start;
        for (item in highlights) {
            final highlightRange = item.range;
            final highlight = item.highlight;
            if (highlight.fontFamily == null) {
                continue;
            }
            final start = highlightRange.start > cursor ? highlightRange.start : cursor;
            final end = highlightRange.end < range.end ? highlightRange.end : range.end;
            if (start >= end) {
                continue;
            }
            if (cursor < start) {
                fragments.push(WrapFragment.Text(Utf8.substring(text, cursor, start)));
            }
            final span = Utf8.substring(text, start, end);
            final remSize = window.remSize();
            final measuredFontSize = highlight.fontSize(fontSize, remSize);
            function measure(text:String):Float {
                final len = Utf8.byteLength(text);
                final runs = InlineHighlight.textRuns(len, textStyle, [new RangedHighlight(new Range(0, len), highlight.clone())]);
                return window.textSystem().layoutLine(text, measuredFontSize, runs).width;
            }
            final insets = highlight.codeInsets(measuredFontSize, remSize);
            final padding = f32(insets.left + insets.right);
            final width = f32(measure(span) + padding);
            if (width <= wrapWidth) {
                fragments.push(WrapFragment.Element(width, Utf8.byteLength(span)));
            }
            else {
                for (word in UnicodeSegmentation.splitWordBounds(span)) {
                    final width = f32(measure(word) + padding);
                    if (width <= wrapWidth) {
                        fragments.push(WrapFragment.Element(width, Utf8.byteLength(word)));
                    }
                    else {
                        for (grapheme in UnicodeSegmentation.graphemes(word, true)) {
                            fragments.push(WrapFragment.Element(f32(measure(grapheme) + padding), Utf8.byteLength(grapheme)));
                        }
                    }
                }
            }
            cursor = end;
        }
        if (cursor < range.end) {
            fragments.push(WrapFragment.Text(Utf8.substring(text, cursor, range.end)));
        }
    }

    static function measureImageSize(ix:Int, source:ImageSource, width:Null<DefiniteLength>, height:Null<DefiniteLength>, lineHeight:Pixels, remSize:Pixels,
            window:Window, cx:App):Size {
        final intrinsicSize = width != null && height != null ? null : intrinsicImageSize(ix, source, width, height, window, cx);
        return imageSize(width, height, intrinsicSize, lineHeight, remSize);
    }

    static function intrinsicImageSize(ix:Int, source:ImageSource, width:Null<DefiniteLength>, height:Null<DefiniteLength>, window:Window,
            cx:App):Null<Size> {
        var image = gpui.Prelude.img(source).id(ix).objectFit(ObjectFit.Contain).maxW(gpui.Prelude.relative(1.));
        if (width != null) {
            image = image.w(width);
        }
        if (height != null) {
            image = image.h(height);
        }
        final element = image.intoAnyElement();
        final measuredSize = element.layoutAsRoot(new SizeOf<AvailableSpace>(MinContent, MinContent), window, cx);

        if (measuredSize.width <= 0 || measuredSize.height <= 0) {
            return null;
        }
        return measuredSize;
    }

    static function imageSize(width:Null<DefiniteLength>, height:Null<DefiniteLength>, intrinsicSize:Null<Size>, lineHeight:Pixels, remSize:Pixels):Size {
        final baseSize = AbsoluteLength.Pixels(lineHeight);
        if (width != null && height != null) {
            return new Size(width.toPixels(baseSize, remSize), height.toPixels(baseSize, remSize));
        }
        else if (width != null) {
            final width:Float = width.toPixels(baseSize, remSize);
            final height:Float = intrinsicSize != null && intrinsicSize.width > 0 && intrinsicSize.height > 0 ? f32(width * f32(intrinsicSize.height / intrinsicSize.width)) : lineHeight;
            return new Size(width, height);
        }
        else if (height != null) {
            final height:Float = height.toPixels(baseSize, remSize);
            final width:Float = intrinsicSize != null && intrinsicSize.width > 0 && intrinsicSize.height > 0 ? f32(height * f32(intrinsicSize.width / intrinsicSize.height)) : height;
            return new Size(width, height);
        }
        else {
            return inlineImageSizeForLine(intrinsicSize, lineHeight);
        }
    }

    static function inlineImageSizeForLine(intrinsicSize:Null<Size>, lineHeight:Pixels):Size {
        final height = f32(lineHeight * 0.75);
        final aspectRatio:Float = intrinsicSize != null && intrinsicSize.width > 0 && intrinsicSize.height > 0 ? f32(intrinsicSize.width / intrinsicSize.height) : 1.;
        return new Size(Math.max(f32(height * aspectRatio), 1.), Math.max(height, 1.));
    }

    static function shapeLine(text:String, fontSize:Pixels, runs:Array<TextRun>, window:Window):ShapedLine {
        return window.textSystem().shapeLine(text, fontSize, runs);
    }

    /**
     * The line height GPUI's text layout gives a plain line in `textStyle`.
     * Unlike `Window.lineHeight`, it is not first rounded to a whole logical
     * pixel, which would make a flow line taller than a plain one.
     */
    static function plainLineHeight(textStyle:TextStyle, remSize:Pixels, window:Window):Pixels {
        return window.pixelSnap(textStyle.lineHeight.toPixels(textStyle.fontSize, remSize));
    }

    /**
     * Returns where GPUI text painting puts the baseline of `shapedLine` in a
     * box `lineHeight` tall: centered, even when the glyphs overflow the box.
     * `ShapedLine.descent` is positive; do not substitute the signed
     * `FontMetrics.descent` exposed by `TextSystem.baselineOffset` here.
     */
    static function centeredBaseline(shapedLine:ShapedLine, lineHeight:Pixels):Pixels {
        final ascent:Float = shapedLine.ascent();
        final descent:Float = shapedLine.descent();
        return f32(f32(f32(f32((lineHeight : Float) - ascent) - descent) / 2.) + ascent);
    }

    /**
     * Clips each `(range, value)` of `ranges` to `start..end` and maps the
     * ones left, rebased to `start` (Rust takes `&[(Range<usize>, T)]`; here
     * `rangeOf` reads the range of an item).
     */
    public static function sliceRanges<T, U>(ranges:Array<T>, rangeOf:(T) -> Range, start:Int, end:Int, map:(Range, T) -> U):Array<U> {
        final result:Array<U> = [];
        for (value in ranges) {
            final range = rangeOf(value);
            final clippedStart = range.start > start ? range.start : start;
            final clippedEnd = range.end < end ? range.end : end;
            if (clippedStart < clippedEnd) {
                result.push(map(new Range(clippedStart - start, clippedEnd - start), value));
            }
        }
        return result;
    }

    /** Rust `f32` arithmetic: rounds a result to single precision. */
    static inline function f32(value:Float):Float {
        return taffy.util.F32.fround(value);
    }

}

/** Rust `InlineFlowLayoutState`. */
private class InlineFlowLayoutState {

    public final typography:InlineFlowTypography;

    public final frameState:InlineFlowFrameState;

    /**
     * The layout this element's last measurement returned, which is the
     * one to paint. Per element, not per state: two flows under the same
     * id (the same document shown twice) share the state's layouts but
     * paint their own.
     */
    public var current:Null<InlineFlowLayout> = null;

    public function new(typography:InlineFlowTypography, frameState:InlineFlowFrameState) {
        this.typography = typography;
        this.frameState = frameState;
    }

}

/**
 * What a flow keeps from one frame to the next, as GPUI element state under
 * the flow's id.
 */
@:allow(gpui.base.text)
@:allow(tests)
class InlineFlowFrameState {

    /**
     * One state per text fragment, by text-fragment index. A fragment's
     * `Inline` retains its shaped text under its state (see
     * `RetainedLayout`), so the state has to be the same one next frame for
     * the text to be found.
     */
    var fragmentStates:Array<InlineState> = [];

    /** What `layouts` were laid out from. A frame whose items or typography differ starts over. */
    var key:Null<FlowLayoutKey> = null;

    /**
     * The layouts of `key`, one per wrap width the flow was measured at:
     * taffy probes a flow at more than one width in a frame. A frame that
     * changes nothing finds every width here and wraps and shapes nothing.
     */
    var layouts:Array<InlineFlowLayout> = [];

    public function new() {}

    function fragmentState(fragmentIx:Int):InlineState {
        while (fragmentStates.length <= fragmentIx) {
            fragmentStates.push(new InlineState());
        }
        return fragmentStates[fragmentIx];
    }

    function truncateFragmentStates(len:Int):Void {
        if (fragmentStates.length > len) {
            fragmentStates.resize(len);
        }
    }

    /** Makes `key` the current one, dropping the layouts of another key. */
    function setKey(key:FlowLayoutKey):Void {
        if (!(this.key != null && this.key.matches(key))) {
            layouts = [];
        }
        this.key = key;
    }

    /** The layout at `wrapWidth`, if the key was laid out there already. */
    function layoutAt(wrapWidth:Null<Float>):Null<InlineFlowLayout> {
        for (layout in layouts) {
            if (layout.wrapWidth == wrapWidth) {
                return layout;
            }
        }
        return null;
    }

    /**
     * Keeps `layout`, in place of the oldest one when the flow has been
     * measured at more widths than it keeps.
     */
    function pushLayout(layout:InlineFlowLayout):Void {
        if (layouts.length >= @:privateAccess InlineFlow.LAYOUTS_PER_FLOW) {
            layouts.shift();
        }
        layouts.push(layout);
    }

}

/** Everything but the wrap width that a flow's layout depends on. */
private class FlowLayoutKey {

    public final items:Array<MeasureItem>;

    public final imageSizes:Array<Null<Size>>;

    public final typography:InlineFlowTypography;

    public function new(items:Array<MeasureItem>, imageSizes:Array<Null<Size>>, typography:InlineFlowTypography) {
        this.items = items;
        this.imageSizes = imageSizes;
        this.typography = typography;
    }

    public function matches(other:FlowLayoutKey):Bool {
        if (items.length != other.items.length) {
            return false;
        }
        for (i in 0...items.length) {
            if (!MeasureItemTools.sameLayoutInput(items[i], other.items[i])) {
                return false;
            }
        }
        if (imageSizes.length != other.imageSizes.length) {
            return false;
        }
        for (i in 0...imageSizes.length) {
            final a = imageSizes[i];
            final b = other.imageSizes[i];
            if (a == null ? b != null : (b == null || !a.equals(b))) {
                return false;
            }
        }
        return typography.equals(other.typography);
    }

}

/**
 * Resolved before `requestMeasuredLayout`, while the parent's text-style
 * and rem stacks are still active.
 */
private class InlineFlowTypography {

    public final textStyle:TextStyle;

    public final remSize:Pixels;

    public final lineHeight:Pixels;

    public function new(textStyle:TextStyle, remSize:Pixels, lineHeight:Pixels) {
        this.textStyle = textStyle;
        this.remSize = remSize;
        this.lineHeight = lineHeight;
    }

    public function equals(other:InlineFlowTypography):Bool {
        return textStyle.equals(other.textStyle) && remSize == other.remSize && lineHeight == other.lineHeight;
    }

}

/** `(usize, Bounds<Pixels>)`: the flow byte offset of an empty line and its box. */
class EmptyLine {

    public final start:Int;

    public final bounds:Bounds;

    public inline function new(start:Int, bounds:Bounds) {
        this.start = start;
        this.bounds = bounds;
    }

}

@:allow(gpui.base.text)
@:allow(tests)
class InlineFlowLayout {

    final fragments:Array<PositionedFragment>;

    final emptyLines:Array<EmptyLine>;

    final size:Size;

    final wrapWidth:Null<Float>;

    function new(fragments:Array<PositionedFragment>, emptyLines:Array<EmptyLine>, size:Size, wrapWidth:Null<Float>) {
        this.fragments = fragments;
        this.emptyLines = emptyLines;
        this.size = size;
        this.wrapWidth = wrapWidth;
    }

}

enum PositionedFragment {

    Object(itemIx:Int, origin:Point, object:MeasuredInlineObject, selectionBounds:Bounds);

    /** `codeBackground` is the rounded box behind a code span, relative to the flow. */
    Text(itemIx:Int, origin:Point, size:Size, sourceRange:Range, fontSize:Pixels, text:String, links:Array<RangedLink>, highlights:Array<RangedHighlight>,
        selectionBounds:Bounds, codeBackground:Null<CodeBox>);

    Image(itemIx:Int, origin:Point, size:Size);

}

enum MeasureItem {

    Object(text:String, id:Int, renderer:InlineRenderer, style:HighlightStyle);

    Text(text:String, links:Array<RangedLink>, highlights:Array<RangedHighlight>);

    Image(source:ImageSource, width:Null<DefiniteLength>, height:Null<DefiniteLength>);

}

class MeasureItemTools {

    /** `From<&InlineFlowItem> for MeasureItem`. */
    public static function from(item:InlineFlowItem):MeasureItem {
        return switch item {
            case Object(text, id, renderer, _, _, style, _):
                MeasureItem.Object(text, id, renderer, style);
            case Text(_, text, links, highlights, _, _):
                MeasureItem.Text(text, [for (l in links) new RangedLink(l.range, l.link.clone())], [for (h in highlights) new RangedHighlight(h.range, h.highlight.clone())]);
            case Image(imageSource, _, _, width, height):
                MeasureItem.Image(imageSource, width, height);
        }
    }

    public static function len(item:MeasureItem):Int {
        return switch item {
            case Text(text, _, _): Utf8.byteLength(text);
            case Image(_, _, _) | Object(_, _, _, _): 1;
        }
    }

    /**
     * Whether `other` lays out the same as this item. An object is
     * rendered anew every frame, so a flow with one is never reused.
     */
    public static function sameLayoutInput(item:MeasureItem, other:MeasureItem):Bool {
        return switch [item, other] {
            case [Text(text, links, highlights), Text(otherText, otherLinks, otherHighlights)]:
                text == otherText && sameLinks(links, otherLinks) && sameHighlights(highlights, otherHighlights);
            case [Image(_, width, height), Image(_, otherWidth, otherHeight)]:
                sameLength(width, otherWidth) && sameLength(height, otherHeight);
            case _:
                false;
        }
    }

    static function sameLength(a:Null<DefiniteLength>, b:Null<DefiniteLength>):Bool {
        return a == null ? b == null : b != null && DefiniteLengthTools.equals(a, b);
    }

    static function sameLinks(a:Array<RangedLink>, b:Array<RangedLink>):Bool {
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!a[i].range.equals(b[i].range) || !a[i].link.equals(b[i].link)) {
                return false;
            }
        }
        return true;
    }

    static function sameHighlights(a:Array<RangedHighlight>, b:Array<RangedHighlight>):Bool {
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!a[i].range.equals(b[i].range) || !a[i].highlight.equals(b[i].highlight)) {
                return false;
            }
        }
        return true;
    }

}

private class LineFragmentLayout {

    public final itemIx:Int;

    public final kind:LineFragmentKind;

    public var size:Size;

    public final sourceRange:Range;

    public var baseline:Float;

    public function new(itemIx:Int, kind:LineFragmentKind, size:Size, sourceRange:Range, baseline:Float) {
        this.itemIx = itemIx;
        this.kind = kind;
        this.size = size;
        this.sourceRange = sourceRange;
        this.baseline = baseline;
    }

}

private enum LineFragmentKind {

    Object(object:MeasuredInlineObject);

    /** `codeBackground` is the code span's box, relative to the fragment. */
    Text(fontSize:Pixels, text:String, links:Array<RangedLink>, highlights:Array<RangedHighlight>, codeBackground:Null<CodeBox>);

    Image;

}

/** The rounded box behind an inline code span, with its optional ring. */
@:allow(tests)
class CodeBox {

    public final bounds:Bounds;

    public final style:StyleRefinement;

    public function new(bounds:Bounds, style:StyleRefinement) {
        this.bounds = bounds;
        this.style = style;
    }

    public function offset(by:Point):CodeBox {
        return new CodeBox(new Bounds(by.add(bounds.origin), bounds.size), style);
    }

}

/** `(Bounds<Pixels>, Hsla)`: an atom decoration. */
private class FlowOverlay {

    public final bounds:Bounds;

    public final color:Hsla;

    public function new(bounds:Bounds, color:Hsla) {
        this.bounds = bounds;
        this.color = color;
    }

}

/** Atom decorations are overlays so they remain visible over opaque content. */
private class FlowPaintItem {

    public final element:AnyElement;

    public final background:Null<CodeBox>;

    public final overlays:Array<FlowOverlay>;

    public function new(element:AnyElement, background:Null<CodeBox>, overlays:Array<FlowOverlay>) {
        this.element = element;
        this.background = background;
        this.overlays = overlays;
    }

}

/**
 * `gpui::LineFragment` with an owned text (Rust borrows `&'a str`), kept
 * apart from the wrapper's enum so that a rest can be rebuilt cheaply.
 */
private enum WrapFragment {
    Text(text:String);
    Element(width:Float, lenUtf8:Int);
}

/**
 * One run of a hard line as the renderer lays it out: text shaped once in
 * context, or an object / image of fixed width. Ranges are hard-line offsets.
 */
private enum ShapedSpan {
    Text(range:Range, line:ShapedLine, padding:Float);
    Fixed(range:Range, width:Float);
}
