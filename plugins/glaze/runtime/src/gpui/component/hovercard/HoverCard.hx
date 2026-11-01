// Ported from gpui-kit 0.8.1: crates/component/src/hover_card.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.hovercard;

import gpui.Anchor;
import gpui.AnyElement;
import gpui.App;
import gpui.Context;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.HoverCard as BaseHoverCard;
import gpui.base.HoverCard.HoverCardState;
import gpui.component.popover.Popover;

import gpui.Prelude.*;

using gpui.base.StyledExt;

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
class HoverCard implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    final hoverCardStyle:StyleRefinement = new StyleRefinement();

    /**
     * Style for the trigger container, the element laid out in the parent
     * and measured to anchor the card.
     */
    var triggerStyleValue:Null<StyleRefinement> = null;

    var anchorValue:Anchor = Anchor.TopCenter;

    var triggerBuilder:Null<(Window, App) -> AnyElement> = null;

    var contentBuilder:Null<(HoverCardState, Window, Context<HoverCardState>) -> AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    var openDelayValue:Float = 0.6;

    var closeDelayValue:Float = 0.3;

    var appearanceValue:Bool = true;

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Create a new HoverCard.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return hoverCardStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):HoverCard {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):HoverCard {
        for (child in children) childElements.push(child);
        return this;
    }

    /**
     * Set the anchor corner of the hover card, default is `Anchor.TopCenter`.
     */
    public function anchor(anchor:Anchor):HoverCard {
        anchorValue = anchor;
        return this;
    }

    /**
     * Set the trigger element of the hover card.
     */
    public function trigger(trigger:IntoElement):HoverCard {
        triggerBuilder = (_, _) -> trigger;
        return this;
    }

    /**
     * Set the style for the trigger container.
     *
     * The container is the element laid out in the parent and measured to
     * anchor the card, so this is where `wFull` or `flex1` must go for the
     * trigger to fill its slot.
     */
    public function triggerStyle(style:StyleRefinement):HoverCard {
        triggerStyleValue = style;
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
     * Set the delay before showing the hover card, default is 600ms.
     */
    public function openDelay(duration:Float):HoverCard {
        openDelayValue = duration;
        return this;
    }

    /**
     * Set the delay before hiding the hover card, default is 300ms.
     */
    public function closeDelay(duration:Float):HoverCard {
        closeDelayValue = duration;
        return this;
    }

    /**
     * Set whether to apply default appearance styles, default is `true`.
     */
    public function appearance(appearance:Bool):HoverCard {
        appearanceValue = appearance;
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

        final anchor = anchorValue;
        final appearance = appearanceValue;
        final content = contentBuilder;
        final children = childElements;
        final style = hoverCardStyle;
        final triggerStyle = triggerStyleValue;

        final card = new BaseHoverCard(id)
            .anchor(anchor)
            .openDelay(openDelayValue)
            .closeDelay(closeDelayValue)
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
