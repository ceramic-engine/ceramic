// Ported from gpui-kit 0.8.1: crates/component/src/bubble.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.bubble;

import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.button.Button;
import gpui.component.message.Message.MessageAlignment;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;
using gpui.component.theme.Colorize;

/**
 * Visual treatment for a chat bubble.
 */
enum abstract BubbleVariant(Int) {

    /** A filled primary surface (the default). */
    var Filled;

    /** A neutral secondary surface. */
    var Secondary;

    /** A lower-emphasis surface. */
    var Muted;

    /** A subtle primary-tinted surface. */
    var Tinted;

    /** A background surface with a visible border. */
    var Outline;

    /** No surface, padding, or border. */
    var Ghost;

    /** A destructive surface for failed or invalid content. */
    var Destructive;

}

/**
 * Edge on which reaction feedback is attached.
 */
enum abstract BubbleReactionSide(Int) {

    /** Attach reactions above the bubble. */
    var Top;

    /** Attach reactions below the bubble (the default). */
    var Bottom;

}

/**
 * A chat bubble layout that owns alignment, width, and reaction positioning.
 *
 * The visible surface is rendered by `BubbleContent`. Direct children are
 * added to that content slot as a convenience.
 */
class Bubble implements RenderOnce implements Styled implements ParentElement {

    final bubbleStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var alignmentValue:Null<MessageAlignment> = null;

    @:allow(tests)
    var variant:BubbleVariant = Filled;

    @:allow(tests)
    var contentValue:BubbleContent = new BubbleContent();

    @:allow(tests)
    var reactionsValue:Null<BubbleReactions> = null;

    /** Create a filled bubble that can inherit alignment from its parent. */
    public function new() {}

    /** Set the bubble alignment. */
    public function alignment(alignment:MessageAlignment):Bubble {
        alignmentValue = alignment;
        return this;
    }

    /** Set the visual treatment. */
    public function withVariant(variant:BubbleVariant):Bubble {
        this.variant = variant;
        return this;
    }

    @:allow(gpui.component, tests)
    function isGhost():Bool {
        return variant == Ghost;
    }

    /**
     * Replace the visible content surface.
     *
     * Children already added directly to the bubble move into the new
     * surface, in front of its own children, so `child(...)` composes the
     * same way on either side of this call.
     */
    public function content(content:BubbleContent):Bubble {
        final children = contentValue.childElements.copy();
        for (child in content.childElements) children.push(child);
        content.childElements.resize(0);
        for (child in children) content.childElements.push(child);
        contentValue = content;
        return this;
    }

    /** Set an optional reaction region anchored to the bubble edge. */
    public function reactions(reactions:BubbleReactions):Bubble {
        reactionsValue = reactions;
        return this;
    }

    public inline function style():StyleRefinement {
        return bubbleStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) contentValue.childElements.push(element);
    }

    public function child(child:IntoElement):Bubble {
        if (child != null) contentValue.childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Bubble {
        for (child in children) if (child != null) contentValue.childElements.push(child);
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        final variant = this.variant;
        final content = contentValue;
        content.variant = variant;
        content.alignment = alignmentValue;

        final element = div()
            .relative()
            .flex()
            .minW0()
            .flexCol()
            .flexNone()
            .gap1()
            .maxW(gpui.Prelude.relative(0.8));
        if (variant == Ghost) element.wFull().maxWFull();
        if (alignmentValue != null) {
            switch (alignmentValue : MessageAlignment) {
                case Start: element.selfStart().mrAuto();
                case End: element.selfEnd().mlAuto();
            }
        }
        element.refineStyle(bubbleStyle).child(content);
        if (reactionsValue != null) element.child(reactionsValue);
        return element;
    }

}

/**
 * The visible surface inside a `Bubble`.
 *
 * This part owns padding, radius, border, typography, and semantic colors so
 * callers can refine the surface without changing the bubble's row layout.
 */
class BubbleContent implements RenderOnce implements Styled implements ParentElement {

    final contentStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.component.bubble, tests)
    var variant:BubbleVariant = Filled;

    @:allow(gpui.component.bubble, tests)
    var alignment:Null<MessageAlignment> = null;

    @:allow(gpui.component.bubble, tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty bubble content surface. */
    public function new() {}

    public inline function style():StyleRefinement {
        return contentStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):BubbleContent {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):BubbleContent {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();

        final element = div()
            .minW0()
            .maxWFull();
        // A ghost bubble has no surface to clip against; clipping would only
        // cut the shadows and overhanging controls of rich content.
        if (variant != Ghost) element.overflowHidden();
        element
            .rounded(theme.radius2xl())
            .border1()
            .borderColor(theme.transparent)
            .px3()
            .py2()
            .textSm()
            .lineHeight(gpui.Prelude.relative(1.625));
        if (alignment != null) {
            switch (alignment : MessageAlignment) {
                case Start: element.selfStart();
                case End: element.selfEnd();
            }
        }
        switch variant {
            case Filled:
                element
                    .bg(tokens.colors.primary)
                    .textColor(tokens.colors.primaryForeground);
            // The theme's `secondary` role is tuned for buttons and sits a
            // tier darker than shadcn's conversation secondary; the
            // near-background `muted` tier matches shadcn's value in both
            // light and dark themes.
            case Secondary:
                element
                    .bg(tokens.colors.muted)
                    .textColor(tokens.colors.secondaryForeground);
            case Muted:
                element
                    .bg(tokens.colors.muted)
                    .textColor(tokens.colors.foreground);
            case Tinted:
                element
                    .bg(tokens.colors.primary.mixOklab(tokens.colors.background, theme.isDark() ? 0.24 : 0.12))
                    .textColor(tokens.colors.foreground);
            case Outline:
                element
                    .borderColor(tokens.colors.border)
                    .bg(tokens.colors.background)
                    .textColor(tokens.colors.foreground);
            case Ghost:
                element
                    .rounded(tokens.radius.none)
                    .border0()
                    .bg(theme.transparent)
                    .textColor(tokens.colors.foreground)
                    .p0();
            case Destructive:
                element
                    .bg(tokens.colors.destructive.opacity(theme.isDark() ? 0.2 : 0.1))
                    .textColor(tokens.colors.destructive);
        }
        element.refineStyle(contentStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * A vertical stack of consecutive bubbles from one sender.
 */
class BubbleGroup implements RenderOnce implements Styled implements ParentElement {

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty bubble group. */
    public function new() {}

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):BubbleGroup {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):BubbleGroup {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        final element = gpui.base.Prelude.vFlex()
            .minW0()
            .gap2()
            .refineStyle(groupStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * A child of `BubbleReactions`: a typed action button or any element.
 */
enum BubbleReactionChild {
    Action(action:Button);
    Element(element:AnyElement);
}

/**
 * A styleable reaction region positioned on a bubble edge.
 *
 * Compose existing `gpui.component.button.Button` values inside this region
 * to preserve button semantics and keyboard behavior.
 */
class BubbleReactions implements RenderOnce implements Styled implements ParentElement {

    final reactionsStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var sideValue:BubbleReactionSide = Bottom;

    @:allow(tests)
    var alignmentValue:MessageAlignment = End;

    @:allow(tests)
    final childElements:Array<BubbleReactionChild> = [];

    /** Create a trailing-aligned reaction region on the lower edge. */
    public function new() {}

    /** Set the edge on which reactions are positioned. */
    public function side(side:BubbleReactionSide):BubbleReactions {
        sideValue = side;
        return this;
    }

    /** Set the reaction region alignment along the bubble edge. */
    public function alignment(alignment:MessageAlignment):BubbleReactions {
        alignmentValue = alignment;
        return this;
    }

    /**
     * Add an interactive action that shares the reaction surface.
     *
     * Typed actions remove the reaction region's decorative content padding
     * and use the theme's full radius so the button reads as part of one
     * surface. The typed action owns that pill geometry; use `child(...)`
     * for emoji, labels, and arbitrary elements when the child should retain
     * its own styling, including a custom button radius.
     */
    public function action(action:Button):BubbleReactions {
        childElements.push(Action(action));
        return this;
    }

    public inline function style():StyleRefinement {
        return reactionsStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(Element(element));
    }

    public function child(child:IntoElement):BubbleReactions {
        if (child != null) childElements.push(Element(child));
        return this;
    }

    public function children(children:Array<IntoElement>):BubbleReactions {
        for (child in children) if (child != null) childElements.push(Element(child));
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();
        var hasAction = false;
        for (child in childElements) {
            switch child {
                case Action(_): hasAction = true;
                case Element(_):
            }
        }
        final actionRadius = theme.radiusFull();
        final children:Array<AnyElement> = [for (child in childElements) switch child {
            case Action(action): ((action.rounded(actionRadius) : IntoElement) : AnyElement);
            case Element(element): element;
        }];

        final element = div()
            .absolute()
            .flex()
            .flexNone()
            .itemsCenter()
            .justifyCenter()
            .gap1()
            .rounded(theme.radiusFull())
            .border3()
            .borderColor(tokens.colors.background)
            .bg(tokens.colors.muted)
            .textColor(tokens.colors.foreground);
        if (!hasAction) element.px1p5().py0p5();
        element.textSm();
        // Approximates shadcn's `translate-y-3/4`: GPUI cannot offset by a
        // fraction of the pill's own height, so this fixed value leaves
        // about three quarters of the default pill outside the bubble.
        if (sideValue == Top) element.top(rems(-1.25));
        if (sideValue == Bottom) element.bottom(rems(-1.25));
        if (alignmentValue == Start) element.left3();
        if (alignmentValue == End) element.right3();
        element.refineStyle(reactionsStyle);
        element.extend(children);
        return element;
    }

}
