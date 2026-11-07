// Ported from gpui-kit 0.8.1: crates/component/src/message.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.message;

import gpui.AnyElement;
import gpui.App;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y.RoleOverride;
import gpui.component.bubble.Bubble;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * Horizontal alignment for a message and message-owned chat surfaces.
 */
enum abstract MessageAlignment(Int) {

    /** Place the message at the leading edge (the default). */
    var Start;

    /** Place the message at the trailing edge. */
    var End;

}

/**
 * A vertical stack of consecutive messages from the same sender.
 */
class MessageGroup implements RenderOnce implements Styled implements ParentElement {

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message group. */
    public function new() {}

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):MessageGroup {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):MessageGroup {
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
 * A composable message row with named avatar, header, content, and footer slots.
 *
 * Named slots let the message apply its alignment consistently while every
 * part remains independently styleable.
 */
class Message implements RenderOnce implements Styled {

    @:allow(tests)
    var idValue:Null<ElementId> = null;

    @:allow(tests)
    var roleValue:RoleOverride = Implicit;

    final messageStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var stackStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var alignmentValue:MessageAlignment = Start;

    @:allow(tests)
    var avatarValue:Null<MessageAvatar> = null;

    @:allow(tests)
    var headerValue:Null<MessageHeader> = null;

    @:allow(tests)
    var contentValue:Null<MessageContent> = null;

    @:allow(tests)
    var footerValue:Null<MessageFooter> = null;

    /** Create a leading-aligned message. */
    public function new() {}

    /** Set whether the message is aligned to the leading or trailing edge. */
    public function alignment(alignment:MessageAlignment):Message {
        alignmentValue = alignment;
        return this;
    }

    /**
     * Set a stable identity so the message can appear in the accessibility
     * tree and keep element state across frames.
     */
    public function id(id:ElementIdArg):Message {
        idValue = id;
        return this;
    }

    /**
     * Set the accessibility role announced for this message.
     *
     * A message is presentational by default. Give the rows of a transcript
     * a role such as `Role.ListItem` so assistive technology can move
     * between them. The role takes effect only together with `id`.
     */
    public function role(role:RoleOverride):Message {
        roleValue = role;
        return this;
    }

    /** Refine the inner vertical stack that contains the named slots. */
    public function withStackStyle(style:StyleRefinement):Message {
        stackStyle = style;
        return this;
    }

    /**
     * Set an optional avatar or other sender identity element.
     *
     * A null avatar means no avatar: the message renders as if no avatar
     * had been set (no avatar slot, no footer inset).
     */
    public function avatar(avatar:IntoElement):Message {
        avatarValue = avatar != null ? new MessageAvatar().child(avatar) : null;
        return this;
    }

    /** Set a fully configured avatar slot (null for none). */
    public function avatarSlot(avatar:MessageAvatar):Message {
        avatarValue = avatar;
        return this;
    }

    /** Set the message header. */
    public function header(header:MessageHeader):Message {
        headerValue = header;
        return this;
    }

    /** Set the message body. */
    public function content(content:MessageContent):Message {
        contentValue = content;
        return this;
    }

    /** Set the message footer. */
    public function footer(footer:MessageFooter):Message {
        footerValue = footer;
        return this;
    }

    public inline function style():StyleRefinement {
        return messageStyle;
    }

    public function render(_:Window, _:App):IntoElement {
        final alignment = alignmentValue;
        final hasAvatar = avatarValue != null;
        final hasGhostBubble = contentValue != null && contentValue.hasGhostBubble;

        // No text size or line height here: the header and footer set their
        // own, and content typography belongs to the bubble or the caller.
        final row = gpui.base.Prelude.vFlex()
            .relative()
            .wFull()
            .minW0()
            .gap(rems(0.625));
        switch alignment {
            case Start: row.itemsStart();
            case End: row.itemsEnd();
        }
        row.refineStyle(messageStyle);

        // The footer lives outside this row so the bottom-anchored avatar
        // always sits flush with the content's bottom edge, whatever the
        // footer contains.
        final line = gpui.base.Prelude.hFlex()
            .wFull()
            .minW0()
            .itemsEnd()
            .gap2();
        if (alignment == End) line.flexRowReverse();
        if (avatarValue != null) line.child(avatarValue);
        final stack = gpui.base.Prelude.vFlex()
            .wFull()
            .minW0()
            .gap(rems(0.625));
        switch alignment {
            case Start: stack.itemsStart();
            case End: stack.itemsEnd();
        }
        stack.refineStyle(stackStyle);
        if (headerValue != null) stack.child(headerValue.withInheritedContentInset(!hasGhostBubble));
        if (contentValue != null) stack.child(contentValue.aligned(alignment));
        line.child(stack);
        row.child(line);

        if (footerValue != null) {
            final footer = footerValue.withInheritedContentInset(!hasGhostBubble);
            // Align the footer with the content column: the avatar's shared
            // `size-8` baseline plus the row gap.
            if (hasAvatar && alignment == Start) footer.ml(rems(2.5));
            if (hasAvatar && alignment == End) footer.mr(rems(2.5));
            row.child(footer);
        }

        // Rust puts `role` on the stateful element (accessibility nodes need
        // the stable identity of an element id); the port has no
        // accessibility tree, so only the id is applied.
        if (idValue != null) row.id(idValue);
        return row;
    }

}

/**
 * The sender identity slot rendered beside a `Message`.
 *
 * The slot reserves the shared `size-8` baseline; the message row keeps it
 * flush with the bottom edge of the visible message surface.
 */
class MessageAvatar implements RenderOnce implements Styled implements ParentElement {

    final avatarStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty avatar slot. */
    public function new() {}

    public inline function style():StyleRefinement {
        return avatarStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):MessageAvatar {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):MessageAvatar {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();

        final element = gpui.base.Prelude.hFlex()
            .relative()
            .minW8()
            .flexNone()
            .itemsCenter()
            .justifyCenter()
            .selfEnd()
            .overflowHidden()
            .rounded(theme.radiusFull())
            .bg(tokens.colors.muted)
            .refineStyle(avatarStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * Header content such as a sender name and timestamp.
 */
class MessageHeader implements RenderOnce implements Styled implements ParentElement {

    final headerStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var contentInsetValue:Null<Bool> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message header. */
    public function new() {}

    /** Set whether the header keeps its default horizontal content inset. */
    public function contentInset(contentInset:Bool):MessageHeader {
        contentInsetValue = contentInset;
        return this;
    }

    @:allow(gpui.component.message, tests)
    function withInheritedContentInset(contentInset:Bool):MessageHeader {
        if (contentInsetValue == null) contentInsetValue = contentInset;
        return this;
    }

    public inline function style():StyleRefinement {
        return headerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):MessageHeader {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):MessageHeader {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final tokens = Theme.global(cx).semanticTokens();

        final element = gpui.base.Prelude.hFlex()
            .maxWFull()
            .minW0()
            .gap1()
            .textXs()
            .lineHeight(gpui.Prelude.relative(1.25))
            .fontMedium()
            .textColor(tokens.colors.mutedForeground);
        if (contentInsetValue == null || contentInsetValue) element.px3();
        element.refineStyle(headerStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * The message body slot. It can contain bubbles, images, code, or files.
 */
class MessageContent implements RenderOnce implements Styled implements ParentElement {

    final contentStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var alignment:MessageAlignment = Start;

    @:allow(gpui.component.message, tests)
    var hasGhostBubble:Bool = false;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message body. */
    public function new() {}

    /**
     * Add a typed bubble and inherit ghost-surface metadata layout.
     *
     * Ordinary `child(...)` content remains available for arbitrary elements;
     * use this builder when surrounding message slots should react to a
     * bubble's variant.
     */
    public function bubble(bubble:Bubble):MessageContent {
        hasGhostBubble = hasGhostBubble || bubble.isGhost();
        childElements.push((bubble : IntoElement).intoAnyElement());
        return this;
    }

    @:allow(gpui.component.message, tests)
    function aligned(alignment:MessageAlignment):MessageContent {
        this.alignment = alignment;
        return this;
    }

    public inline function style():StyleRefinement {
        return contentStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):MessageContent {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):MessageContent {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        final element = gpui.base.Prelude.vFlex()
            .wFull()
            .maxWFull()
            .minW0()
            .gap(rems(0.625));
        switch alignment {
            case Start: element.itemsStart();
            case End: element.itemsEnd();
        }
        element.refineStyle(contentStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * Footer content such as delivery state, reactions, or action buttons.
 */
class MessageFooter implements RenderOnce implements Styled implements ParentElement {

    final footerStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var contentInsetValue:Null<Bool> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message footer. */
    public function new() {}

    /** Set whether the footer keeps its default horizontal content inset. */
    public function contentInset(contentInset:Bool):MessageFooter {
        contentInsetValue = contentInset;
        return this;
    }

    @:allow(gpui.component.message, tests)
    function withInheritedContentInset(contentInset:Bool):MessageFooter {
        if (contentInsetValue == null) contentInsetValue = contentInset;
        return this;
    }

    public inline function style():StyleRefinement {
        return footerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):MessageFooter {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):MessageFooter {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final tokens = Theme.global(cx).semanticTokens();

        final element = gpui.base.Prelude.hFlex()
            .maxWFull()
            .minW0()
            .gap1()
            .textXs()
            .lineHeight(gpui.Prelude.relative(1.25))
            .fontMedium()
            .textColor(tokens.colors.mutedForeground);
        if (contentInsetValue == null || contentInsetValue) element.px3();
        element.refineStyle(footerStyle);
        element.extend(childElements);
        return element;
    }

}
