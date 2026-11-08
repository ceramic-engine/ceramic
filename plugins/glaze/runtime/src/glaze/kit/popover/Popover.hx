// Ported from gpui-kit 0.8.1: crates/component/src/popover.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.popover;

import glaze.Anchor;
import glaze.Animation;
import glaze.AnimationElement;
import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Bounds;
import glaze.Component;
import glaze.Context;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.ParentElement;
import glaze.PathBuilder;
import glaze.Point;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.Popover as BasePopover;
import glaze.kit.base.Popover.PopoverState;
import glaze.kit.base.Positioner;
import glaze.kit.base.Positioner.Align;
import glaze.kit.base.Positioner.ResolvedPosition;
import glaze.kit.base.animation.Easings;
import glaze.kit.theme.Theme;
import glaze.util.MathUtil;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.AnimationExt;
using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * A popover element that can be triggered by a button or any other element.
 *
 * The state type is gpui-base's `PopoverState` (Rust re-exports it).
 */
class Popover extends Component implements Styled implements ParentElement {

    public static function bindKeys(_:AppContext):Void {}

    /**
     * How long a dropdown takes to settle into place after it opens, in seconds.
     *
     * This is shadcn/ui's figure: its popup surfaces carry `animate-in`, whose
     * duration is 150ms.
     */
    static inline final DROPDOWN_ENTER_DURATION:Float = 0.15;

    /**
     * Where a dropdown starts out, relative to where it comes to rest.
     *
     * Negative is above, so the surface slides down out of the trigger's edge
     * (shadcn/ui's `data-[side=bottom]:slide-in-from-top-2`, 0.5rem, which
     * is 8px at the default root size).
     */
    static inline final DROPDOWN_ENTER_OFFSET:Float = -8.;

    static function dropdownPositioner(bounds:Bounds):Positioner {
        return Positioner.side(bounds)
            .placement(Placement.Bottom)
            .align(Align.Start)
            .offset(glaze.Prelude.px(6.))
            .margin(glaze.Prelude.px(8.));
    }

    /**
     * Positions a dropdown surface under its trigger and animates it in.
     *
     * This is the shared open motion for Select, Combobox and DatePicker,
     * modelled on shadcn/ui: over 150ms the surface fades up from nothing
     * while sliding the last 8px out of the trigger's edge, on an ease-out
     * curve so it decelerates into place.
     *
     * `surface` must be the panel itself (the element carrying
     * `ThemeStyled.popoverStyle`) and not a wrapper around it: GPUI takes a
     * shadow's shape from the element it is set on.
     *
     * The shadow is animated too: GPUI has no group compositing, so a
     * translucent panel does not hide its own shadow. Ramping the ink by the
     * cube of the fade keeps it out of sight until the panel is opaque enough
     * to cover it. There is no scale (no element transform in GPUI) and no
     * exit motion, and the slide always comes from above.
     *
     * Reduced motion needs no handling here: GPUI's animation element adopts
     * the final value on the first frame when the system asks for it.
     */
    public static function dropdownPopup(id:ElementIdArg, bounds:Bounds, surface:Div, cx:App):Positioner {
        final travel:Float = DROPDOWN_ENTER_OFFSET;
        // Read out here: the animation runs long after `cx` is gone.
        final ring = ThemeStyled.popoverRing(cx);

        return dropdownPositioner(bounds).child(surface.withAnimation(
            id,
            new Animation(DROPDOWN_ENTER_DURATION).withEasing(Easings.easeOutCubic),
            (surface, delta) -> surface
                .top(glaze.Prelude.px(travel * (1. - delta)))
                .opacity(delta)
                .shadow(ThemeStyled.popoverShadow(ring, delta * delta * delta))
        ));
    }

    final id:ElementId;

    final popoverStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the anchor corner of the popover, default is `Anchor.TopLeft`.
     *
     * This names the popover's own anchor, not a corner of the trigger.
     * `TopLeft` opens below the trigger, left-aligned; `BottomRight` opens
     * above it, right-aligned. Legacy anchoring clamps without flipping.
     */
    @prop var anchor:Anchor = Anchor.TopLeft;

    /**
     * Gap from the trigger to the surface (or arrow tip), default 0.25rem.
     * Preserves the anchor and does not enable automatic flipping.
     */
    @prop var offset:Null<Float> = null;

    /**
     * Show an arrow pointing toward the trigger. Default is `false`.
     * Follows the anchor, with its base inset to avoid rounded corners.
     * Uses the surface background, falling back to the theme's popover color.
     */
    @prop var arrow:Bool = false;

    /**
     * Set the default open state of the popover, default is `false`.
     *
     * This is only used to initialize the open state of the popover, and is
     * ignored when `open` is used.
     */
    @prop var defaultOpen:Bool = false;

    /**
     * Force set the open state of the popover. The popover is then controlled
     * by this value: use it with `onOpenChange` to handle state changes.
     */
    @prop var open:Null<Bool> = null;

    /**
     * Bind the focus handle to receive focus when the popover is opened.
     * Without it, the popover focuses a handle of its own.
     */
    @prop var trackFocus:Null<FocusHandle> = null;

    var triggerBuilder:Null<(Bool, Window, App) -> AnyElement> = null;

    var contentBuilder:Null<(PopoverState, Window, Context<PopoverState>) -> AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    /**
     * Set the style for the trigger container.
     *
     * The container is the element laid out in the parent and measured to
     * anchor the popup, so this is where `wFull` or `flex1` must go for the
     * trigger to fill its slot.
     */
    @prop var triggerStyle:Null<StyleRefinement> = null;

    /**
     * Set the mouse button to trigger the popover, default is `MouseButton.Left`.
     */
    @prop var mouseButton:MouseButton = MouseButton.Left;

    /**
     * Set whether the popover has its default appearance, default is `true`.
     *
     * Without it the popover has no bg, border, shadow, or padding.
     */
    @prop var appearance:Bool = true;

    /**
     * Set whether clicking outside the popover will dismiss it, default is `true`.
     */
    @prop var overlayClosable:Bool = true;

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Create a new Popover with `view` mode.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return popoverStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Popover {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Popover {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Set the trigger element of the popover.
     */
    public function trigger(trigger:Selectable):Popover {
        triggerBuilder = (isOpen, _, _) -> {
            final open = trigger.isOpen();
            trigger.setOpen(open || isOpen);
            return BasePopover.selectableElement(trigger);
        };
        return this;
    }

    /**
     * Add a callback to be called when the open state changes, with the new
     * open state.
     */
    public function onOpenChange(callback:(Bool, Window, App) -> Void):Popover {
        onOpenChangeHandler = callback;
        return this;
    }

    /**
     * Set the content builder for content of the Popover.
     *
     * This callback is called every time the popover renders, so avoid
     * creating new elements or entities in it.
     */
    public function content(content:(PopoverState, Window, Context<PopoverState>) -> IntoElement):Popover {
        contentBuilder = (state, window, cx) -> content(state, window, cx);
        return this;
    }

    @:allow(glaze.kit)
    static function renderPopoverContent(anchor:Anchor, appearance:Bool, window:Window, cx:App):Div {
        final content = vFlex()
            .id('content')
            .occlude()
            .tabGroup();
        if (appearance) {
            content.popoverStyle(cx).p3();
        }
        switch anchor {
            case TopLeft | TopCenter | TopRight:
                content.top1();
            case BottomLeft | BottomCenter | BottomRight:
                content.bottom1();
            case LeftCenter | RightCenter:
                content.top1(); // Fallback for centered
        }
        return content;
    }

    public function render(window:Window, cx:App):IntoElement {
        final anchor = this.anchor;
        final arrowSize:Float = this.arrow ? window.remSize() * 0.375 : glaze.Prelude.px(0.);
        final offset:Float = (this.offset != null ? this.offset : window.remSize() * 0.25) + arrowSize;
        final resolved = new ResolvedCell();
        final arrowPosition = resolved;
        final arrow = this.arrow;
        final theme = Theme.global(cx);
        final styleBackground = popoverStyle.background != null ? popoverStyle.background.asSolid() : null;
        final background:Hsla = styleBackground != null ? styleBackground : theme.popover;
        final ring = ThemeStyled.popoverRing(cx);
        final radius = theme.radius;
        final appearance = this.appearance;
        final style = popoverStyle;
        final children = childElements;
        final content = contentBuilder;
        final triggerStyle = this.triggerStyle;

        final popover = new BasePopover(id)
            .anchor(this.anchor)
            .offset(offset)
            .onPosition((position, trigger) -> {
                resolved.position = position;
                resolved.trigger = trigger;
            })
            .mouseButton(mouseButton)
            .defaultOpen(defaultOpen)
            .overlayClosable(overlayClosable)
            .content((state, window, cx) -> {
                final surface = vFlex()
                    .id('content')
                    .occlude()
                    .tabGroup();
                if (appearance) {
                    surface.popoverStyle(cx.app).p3();
                }
                if (content != null) {
                    surface.child(content(state, window, cx));
                }
                surface.extend(children);
                surface.refineStyle(style);
                if (arrow) {
                    surface.child(
                        canvas((_, _, _) -> null, (bounds, _, window, _) -> {
                            if (arrowPosition.trigger == null) {
                                return;
                            }
                            final target = arrowAnchor(anchor, arrowPosition.trigger);
                            final trigger = new Bounds(target.point, new glaze.Size(glaze.Prelude.px(0.), glaze.Prelude.px(0.)));
                            final points = arrowPoints(bounds, trigger, target.side, arrowSize, radius);
                            final fill = PathBuilder.fill();
                            fill.moveTo(points[0]);
                            fill.lineTo(points[1]);
                            fill.lineTo(points[2]);
                            fill.close();
                            final path = tryBuild(fill);
                            if (path != null) {
                                window.paintPath(path, background);
                            }
                            // The triangle ends exactly at the surface edge.
                            // Cover the ring and the antialiased base on both
                            // sides of that edge before drawing its two slopes.
                            window.paintQuad(glaze.Prelude.fill(arrowJoinBounds(points, target.side, glaze.Prelude.px(1.)), background));
                            if (appearance) {
                                final outline = PathBuilder.stroke(glaze.Prelude.px(1.));
                                outline.moveTo(points[0]);
                                outline.lineTo(points[1]);
                                outline.lineTo(points[2]);
                                final path = tryBuild(outline);
                                if (path != null) {
                                    window.paintPath(path, ring);
                                }
                            }
                        })
                            .absolute()
                            .inset0()
                            .sizeFull()
                    );
                }
                return surface;
            });
        final trigger = triggerBuilder;
        if (trigger != null) popover.triggerWith(trigger);
        if (triggerStyle != null) popover.refineStyle(triggerStyle);
        if (this.open != null) popover.open(this.open);
        if (trackFocus != null) popover.trackFocus(trackFocus);
        final onOpenChange = onOpenChangeHandler;
        if (onOpenChange != null) {
            popover.onOpenChange((open, window, cx) -> onOpenChange(open, window, cx));
        }
        return popover;
    }

    static function tryBuild(builder:PathBuilder):Null<glaze.Path> {
        try {
            return builder.build();
        }
        catch (e:haxe.Exception) {
            return null;
        }
    }

    /**
     * The arrow follows the named anchor instead of always aiming at trigger center.
     */
    @:allow(tests)
    static function arrowAnchor(anchor:Anchor, trigger:Bounds):{side:Placement, point:Point} {
        return switch anchor {
            case TopLeft: {side: Placement.Bottom, point: trigger.bottomLeft()};
            case TopCenter: {side: Placement.Bottom, point: trigger.bottomCenter()};
            case TopRight: {side: Placement.Bottom, point: trigger.bottomRight()};
            case BottomLeft: {side: Placement.Top, point: trigger.origin};
            case BottomCenter: {side: Placement.Top, point: trigger.topCenter()};
            case BottomRight: {side: Placement.Top, point: trigger.topRight()};
            case LeftCenter: {side: Placement.Right, point: trigger.rightCenter()};
            case RightCenter: {side: Placement.Left, point: trigger.leftCenter()};
        }
    }

    /**
     * Clamp the arrow base clear of rounded corners while aiming at the trigger.
     */
    @:allow(tests)
    static function arrowPoints(surface:Bounds, trigger:Bounds, side:Placement, depth:Float, radius:Float):Array<Point> {
        final horizontal = side.isHorizontal();
        final start = horizontal ? surface.top() : surface.left();
        final end = horizontal ? surface.bottom() : surface.right();
        final target = horizontal ? trigger.center().y : trigger.center().x;
        final half = Math.min(depth, (end - start) * 0.5);
        final inset = Math.min(radius + half, (end - start) * 0.5);
        final center = MathUtil.clamp(target, start + inset, end - inset);
        return switch side {
            case Bottom: [
                    new Point(center - half, surface.top()),
                    new Point(center, surface.top() - depth),
                    new Point(center + half, surface.top())
                ];
            case Top: [
                    new Point(center - half, surface.bottom()),
                    new Point(center, surface.bottom() + depth),
                    new Point(center + half, surface.bottom())
                ];
            case Right: [
                    new Point(surface.left(), center - half),
                    new Point(surface.left() - depth, center),
                    new Point(surface.left(), center + half)
                ];
            case Left: [
                    new Point(surface.right(), center - half),
                    new Point(surface.right() + depth, center),
                    new Point(surface.right(), center + half)
                ];
        }
    }

    @:allow(tests)
    static function arrowJoinBounds(points:Array<Point>, side:Placement, stroke:Float):Bounds {
        // Inset by the stroke width so the patch remains inside the triangle's
        // slopes at the outer edge of the ring, including on very small surfaces.
        if (side.isHorizontal()) {
            final inset = Math.min(stroke, (points[2].y - points[0].y) * 0.5);
            return Bounds.fromCorners(
                new Point(points[0].x - stroke, points[0].y + inset),
                new Point(points[2].x + stroke, points[2].y - inset)
            );
        }
        else {
            final inset = Math.min(stroke, (points[2].x - points[0].x) * 0.5);
            return Bounds.fromCorners(
                new Point(points[0].x + inset, points[0].y - stroke),
                new Point(points[2].x - inset, points[2].y + stroke)
            );
        }
    }

}

/**
 * The geometry the popup resolved during the last prepaint (Rust
 * `Rc<Cell<Option<(ResolvedPosition, Bounds<Pixels>)>>>`).
 */
private class ResolvedCell {

    public var position:Null<ResolvedPosition> = null;

    public var trigger:Null<Bounds> = null;

    public function new() {}

}
