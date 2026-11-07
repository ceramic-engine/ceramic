// Ported from gpui-kit 0.8.1: crates/base/src/text/inline_object.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.ClickEvent;
import gpui.ClickEvent.MouseClickEvent;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.GlobalElementId;
import gpui.Hitbox;
import gpui.LayoutId;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseUpEvent;
import gpui.Pixels;
import gpui.Point;
import gpui.Size;
import gpui.SizeOf;
import gpui.Style;
import gpui.StyledText;
import gpui.TextStyle;
import gpui.Window;
import gpui.base.GlobalState;
import gpui.base.TextSelection;
import gpui.base.input.TouchSelectionSnapshot;
import gpui.base.text.InlineNode.SharedFlag;
import gpui.util.Utf8;

using StringTools;

/** Rust `LinkClickHandlerFn` (text_view.rs): `(url, event, window, cx)`. */
private typedef LinkClickHandler = (url:String, event:gpui.ClickEvent, window:gpui.Window, cx:gpui.App) -> Void;

/**
 * The size of an inline object and the distance from its top to its
 * alphabetic baseline.
 */
class InlineMetrics {

    public var size:Size;

    public var baseline:Pixels;

    public inline function new(size:Size, baseline:Pixels) {
        this.size = size;
        this.baseline = baseline;
    }

    public inline function copy():InlineMetrics {
        return new InlineMetrics(size, baseline);
    }

    @:allow(gpui.base.text)
    function isValid():Bool {
        final width:Float = size.width;
        final height:Float = size.height;
        final baseline:Float = this.baseline;
        return Math.isFinite(width) && Math.isFinite(height) && Math.isFinite(baseline) && width > 0. && height > 0. && baseline >= 0.
            && baseline <= height;
    }

}

/**
 * The element of an inline object measured this frame, consumed once by the
 * paint (Rust `Rc<RefCell<Option<AnyElement>>>`, shared by the clones).
 */
class InlineObjectContent {

    public var element:Null<AnyElement>;

    public inline function new(element:AnyElement) {
        this.element = element;
    }

}

/** Geometry can be cloned during wrapping; the frame's element is consumed once. */
class MeasuredInlineObject {

    public var metrics:InlineMetrics;

    var content:Null<InlineObjectContent>;

    var text:String;

    var fontSize:Pixels;

    var textStyle:TextStyle;

    function new(metrics:InlineMetrics, content:Null<InlineObjectContent>, text:String, fontSize:Pixels, textStyle:TextStyle) {
        this.metrics = metrics;
        this.content = content;
        this.text = text;
        this.fontSize = fontSize;
        this.textStyle = textStyle;
    }

    public function clone():MeasuredInlineObject {
        return new MeasuredInlineObject(metrics.copy(), content, text, fontSize, textStyle);
    }

    /**
     * Must run before entering a GPUI measured-layout callback: native element
     * layout itself uses the window's layout engine.
     */
    public static function measure(text:String, presentation:Null<InlineElement>, style:TextStyle, window:Window, cx:App):MeasuredInlineObject {
        final fontSize:Pixels = style.fontSize.toPixels(window.remSize());
        final text = text.replace('\r', ' ').replace('\n', ' ');
        final line = window.textSystem().shapeLine(text, fontSize, [style.toRun(Utf8.byteLength(text))]);
        final ascent:Float = line.ascent();
        final descent:Float = line.descent();
        final lineWidth:Float = line.width();
        final height:Float = Math.max(style.lineHeightInPixels(window.remSize()), f32(ascent + descent));
        final fallback = new InlineMetrics(new Size(Math.max(lineWidth, 1.), height), f32(f32(f32(f32(height - ascent) - descent) / 2.) + ascent));
        final result = new MeasuredInlineObject(fallback, null, text, fontSize, style.clone());
        if (presentation != null) {
            // The wrapper carries inherited marks into both layout and painting.
            final wrapper = gpui.Prelude.div().child(presentation.element);
            wrapper.style().text = style.subtract(new gpui.TextStyleRefinement());
            final element = wrapper.intoAnyElement();
            final measured = element.layoutAsRoot(new SizeOf<AvailableSpace>(MaxContent, MaxContent), window, cx);
            final metrics = new InlineMetrics(measured,
                presentation.baseline != null ? presentation.baseline : Math.max(f32(measured.height - f32(fallback.size.height - (fallback.baseline : Float))), 0.));
            if (metrics.isValid()) {
                result.metrics = metrics;
                result.content = new InlineObjectContent(element);
            }
        }
        return result;
    }

    public function fitText(width:Null<Pixels>):MeasuredInlineObject {
        final result = clone();
        // GPUI has no general subtree scale. Only our own plain-text fallback
        // can be proportionally fitted; custom elements retain their real size.
        if (result.content == null) {
            final scale:Float = width == null ? 1. : Math.min(f32(Math.max(width, 0.) / result.metrics.size.width), 1.);
            result.metrics.size = new Size(f32(result.metrics.size.width * scale), f32(result.metrics.size.height * scale));
            result.metrics.baseline = f32(result.metrics.baseline * scale);
            result.fontSize = f32(result.fontSize * scale);
        }
        return result;
    }

    /** The element to paint, and whether it was measured already. */
    function element():{element:AnyElement, measured:Bool} {
        if (content != null) {
            final element = content.element;
            if (element == null) {
                throw 'inline element painted once per frame';
            }
            content.element = null;
            return {element: element, measured: true};
        }
        final text = new StyledText(this.text).withRuns([textStyle.toRun(Utf8.byteLength(this.text))]);
        return {
            element: gpui.Prelude.div()
                .w(gpui.Prelude.px(metrics.size.width))
                .h(gpui.Prelude.px(metrics.size.height))
                .textSize(gpui.Prelude.px(fontSize))
                .lineHeight(gpui.Prelude.px(metrics.size.height))
                .whitespaceNowrap()
                .overflowHidden()
                .child(text)
                .intoAnyElement(),
            measured: false
        };
    }

    static inline function f32(value:Float):Float {
        return taffy.util.F32.fround(value);
    }

}

class InlineObjectSelectionProjection {

    /** Rust holds a `Weak`: the port has no weak references, the projection lives for one frame. */
    final selected:SharedFlag;

    final bounds:Bounds;

    public function new(selected:SharedFlag, bounds:Bounds) {
        this.selected = selected;
        this.bounds = bounds;
    }

    public function project(start:Point, end:Point):Void {
        selected.value = InlineObject.objectInSelection(bounds, start, end);
    }

    public function deselect():Void {
        selected.value = false;
    }

}

/**
 * Atomic selection wrapper that leaves child styling and interaction to GPUI.
 *
 * Not ported: the accessibility hooks (`a11y_role`, `write_a11y_info`,
 * role `GenericContainer` labelled with `accessibilityLabel`), the port has
 * no accessibility tree yet; the label is kept.
 */
class InlineObject extends gpui.Element {

    final id:ElementId;

    final text:String;

    final accessibilityLabel:String;

    final object:MeasuredInlineObject;

    final selected:SharedFlag;

    final selectionBounds:Bounds;

    final lineBounds:Bounds;

    final content:AnyElement;

    final contentMeasured:Bool;

    var link_:Null<LinkMark> = null;

    var linkClickHandler:Null<LinkClickHandler> = null;

    /** Rust `PrepaintState`. */
    var hitbox:Null<Hitbox> = null;

    public function link(link:Null<LinkMark>, handler:Null<LinkClickHandler>):InlineObject {
        this.link_ = link;
        this.linkClickHandler = handler;
        return this;
    }

    public function new(id:ElementIdArg, text:String, accessibilityLabel:String, object:MeasuredInlineObject, selected:SharedFlag, selectionBounds:Bounds,
            lineBounds:Bounds) {
        @:privateAccess final element = object.element();
        this.id = id;
        this.text = text;
        this.accessibilityLabel = accessibilityLabel;
        this.object = object;
        this.selected = selected;
        this.selectionBounds = selectionBounds;
        this.lineBounds = lineBounds;
        this.content = element.element;
        this.contentMeasured = element.measured;
    }

    /** The label the Rust element reports to assistive technologies. */
    public inline function a11yLabel():String {
        return accessibilityLabel;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    @:allow(gpui.base.text)
    static function objectInSelection(bounds:Bounds, start:Point, end:Point):Bool {
        return Inline.pointInTextSelection(bounds.origin, bounds.size.width, start, end, bounds.size.height);
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final metrics = object.metrics;
        final style = new Style();
        style.sizeWidth = gpui.Length.Definite(gpui.DefiniteLength.Absolute(gpui.AbsoluteLength.Pixels(metrics.size.width)));
        style.sizeHeight = gpui.Length.Definite(gpui.DefiniteLength.Absolute(gpui.AbsoluteLength.Pixels(metrics.size.height)));
        return window.requestLayout(style, [], cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        hitbox = window.insertHitbox(bounds, Normal);
        if (contentMeasured) {
            content.prepaintAt(bounds.origin, window, cx);
        }
        else {
            content.prepaintAsRoot(bounds.origin, new SizeOf<AvailableSpace>(Definite(bounds.size.width), Definite(bounds.size.height)), window, cx);
        }
        final view = GlobalState.global(cx).textViewState();
        if (view != null) {
            final state = view.read(cx);
            if (state.maxLines != null) {
                state.lineSpans.push(new LineSpan(bounds.top(), bounds.bottom(), bounds.size.height));
            }
        }
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hitbox = this.hitbox;
        final view = GlobalState.global(cx).textViewState();
        final selectable = view != null && view.read(cx).isSelectable();
        var selected = false;
        if (view != null) {
            final state = view.read(cx);
            if (selectable && state.preserveInlineSelection && !state.isAllSelected()) {
                selected = this.selected.value;
            }
            else {
                function multiClickHit():Bool {
                    final s = state.multiClickSelection();
                    return s != null && (s.lineBounds == null ? bounds.contains(s.pos) : s.lineBounds.contains(bounds.center()));
                }
                function dragHit():Bool {
                    final points = state.paintedSelectionPoints(cx);
                    return points != null && objectInSelection(selectionBounds, points.start, points.end);
                }
                selected = selectable && (state.isAllSelected() || multiClickHit() || dragHit());
            }
        }
        this.selected.value = selected;
        if (selected) {
            final color = view.read(cx).textViewStyle.selection();
            window.paintQuad(gpui.Prelude.fill(bounds, color));
        }
        final link = this.link_;
        if (link != null) {
            window.setCursorStyle(PointingHand, hitbox);
            final linkHitbox = hitbox;
            final linkView = view;
            final handler = linkClickHandler;
            window.onMouseEvent(MouseUp, (e, phase, window, cx) -> {
                final event:MouseUpEvent = cast e;
                if (!phase.bubble() || !linkHitbox.isHovered(window) || (linkView != null && linkView.read(cx).hasSelection(cx))) {
                    return;
                }
                TextSelection.end(window, cx);
                cx.stopPropagation();
                final click = ClickEvent.Mouse(new MouseClickEvent(new MouseDownEvent(event.button, event.position, event.modifiers, event.clickCount, false), event));
                TextView.handleLinkClick(handler, link.url, click, window, cx);
            });
        }
        if (selectable) {
            view.read(cx).selectionAdapter.registerCopyProjection(CopyProjection.InlineObject(new InlineObjectSelectionProjection(this.selected,
                selectionBounds)), cx);
            if (this.link_ == null) {
                window.setCursorStyle(IBeam, hitbox);
            }
            final visible = bounds.intersect(window.contentMask().bounds);
            if (visible.size.width > 0 && visible.size.height > 0) {
                view.read(cx).selectionAdapter.registerInline([visible]);
            }
            final selectedState = this.selected;
            final text = this.text;
            final currentView = window.currentView();
            final lineBounds = this.lineBounds;
            final objectBounds = this.selectionBounds;
            window.onMouseEvent(MouseDown, (e, phase, window, cx) -> {
                final event:MouseDownEvent = cast e;
                if (!phase.bubble() || !hitbox.isHovered(window) || event.button != MouseButton.Left || !(event.clickCount >= 2 && event.clickCount <= 3)) {
                    return;
                }
                GlobalState.suppressTextSelection(cx);
                selectedState.value = true;
                if (view != null) {
                    view.update(cx, (state, cx) -> {
                        if (event.clickCount == 3) {
                            state.setMultiClickLine(lineBounds, cx.app);
                        }
                        else {
                            state.setMultiClickSelection(event.position, TextViewMultiClickKind.Word, text,
                                TouchSelectionSnapshot.caretLineBox(objectBounds.origin, objectBounds.size.height),
                                TouchSelectionSnapshot.caretLineBox(objectBounds.topRight(), objectBounds.size.height), cx.app);
                        }
                    });
                }
                cx.notify(currentView);
            });
        }
        content.paint(window, cx);
    }

}
