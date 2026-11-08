// Ported from gpui-kit 0.8.1: crates/component/src/hover_card.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.hovercard;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.HoverCard as BaseHoverCard;
import glaze.kit.base.HoverCard.HoverCardState;
import glaze.kit.popover.Popover;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A hover card element that displays content when hovering over a trigger element.
 *
 * Similar to Popover but triggered by mouse hover instead of click, with
 * configurable delays (in seconds) for showing and hiding the content. On iOS
 * and Android, tapping the trigger toggles the card and tapping outside
 * dismisses it; hover delays are ignored.
 *
 * The state type is gpui-base's `HoverCardState` (Rust re-exports it).
 */
class HoverCard extends Component implements Styled implements ParentElement {

    /** The error thrown by `trigger(null)` (the same as gpui-base's). */
    public static inline final NULL_TRIGGER_ERROR = BaseHoverCard.NULL_TRIGGER_ERROR;

    final id:ElementId;

    final hoverCardStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the style for the trigger container.
     *
     * The container is the element laid out in the parent and measured to
     * anchor the card, so this is where `wFull` or `flex1` must go for the
     * trigger to fill its slot.
     */
    @prop var triggerStyle:Null<StyleRefinement> = null;

    /**
     * Set the anchor corner of the hover card, default is `Anchor.TopCenter`.
     */
    @prop var anchor:Anchor = Anchor.TopCenter;

    var triggerBuilder:Null<(Window, App) -> AnyElement> = null;

    var contentBuilder:Null<(HoverCardState, Window, Context<HoverCardState>) -> AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    /**
     * Set the delay before showing the hover card, default is 600ms.
     */
    @prop var openDelay:Float = 0.6;

    /**
     * Set the delay before hiding the hover card, default is 300ms.
     */
    @prop var closeDelay:Float = 0.3;

    /**
     * Set whether to apply default appearance styles, default is `true`.
     */
    @prop var appearance:Bool = true;

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Create a new HoverCard.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return hoverCardStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):HoverCard {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):HoverCard {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Set the trigger element of the hover card.
     *
     * The trigger is mandatory: a null trigger throws (a card without one
     * could never be opened).
     */
    public function trigger(trigger:IntoElement):HoverCard {
        if (trigger == null) throw NULL_TRIGGER_ERROR;
        triggerBuilder = (_, _) -> trigger;
        return this;
    }

    /**
     * Set the content builder of the hover card.
     */
    public function content(content:(HoverCardState, Window, Context<HoverCardState>) -> IntoElement):HoverCard {
        contentBuilder = (state, window, cx) -> content(state, window, cx);
        return this;
    }

    /**
     * Set a callback to be called when the open state changes.
     */
    public function onOpenChange(callback:(Bool, Window, App) -> Void):HoverCard {
        onOpenChangeHandler = callback;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final trigger = triggerBuilder;
        if (trigger == null) {
            return div().id('empty');
        }

        final anchor = this.anchor;
        final appearance = this.appearance;
        final content = contentBuilder;
        final children = childElements;
        final style = hoverCardStyle;
        final triggerStyle = this.triggerStyle;

        final card = new BaseHoverCard(id)
            .anchor(anchor)
            .openDelay(openDelay)
            .closeDelay(closeDelay)
            .trigger(trigger(window, cx))
            .content((state, window, cx) -> {
                final surface = @:privateAccess Popover.renderPopoverContent(anchor, appearance, window, cx.app)
                    .overflowHidden();
                if (content != null) {
                    surface.child(content(state, window, cx));
                }
                surface.extend(children);
                return surface.refineStyle(style);
            });
        final onOpenChange = onOpenChangeHandler;
        if (onOpenChange != null) {
            card.onOpenChange((open, window, cx) -> onOpenChange(open, window, cx));
        }
        if (triggerStyle != null) card.refineStyle(triggerStyle);
        return card;
    }

}
