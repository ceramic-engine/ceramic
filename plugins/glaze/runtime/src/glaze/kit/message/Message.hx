// Ported from gpui-kit 0.8.1: crates/component/src/message.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.message;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y.RoleOverride;
import glaze.kit.bubble.Bubble;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

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
class MessageGroup extends Component implements Styled implements ParentElement {

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message group. */
    public function new() {
        super();
    }

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
        final element = glaze.kit.base.Prelude.vFlex()
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
class Message extends Component implements Styled {

    @:allow(tests)
    @prop var id:Null<ElementId> = null;

    /**
     * Set the accessibility role announced for this message.
     *
     * A message is presentational by default. Give the rows of a transcript
     * a role such as `Role.ListItem` so assistive technology can move
     * between them. The role takes effect only together with `id`.
     */
    @:allow(tests)
    @prop var role:RoleOverride = Implicit;

    final messageStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var stackStyle:StyleRefinement = new StyleRefinement();

    /** Set whether the message is aligned to the leading or trailing edge. */
    @:allow(tests)
    @prop var alignment:MessageAlignment = Start;

    /** Set a fully configured avatar slot (null for none). */
    @:allow(tests)
    @prop var avatarSlot:Null<MessageAvatar> = null;

    /** Set the message header. */
    @:allow(tests)
    @prop var header:Null<MessageHeader> = null;

    /** Set the message body. */
    @:allow(tests)
    @prop var content:Null<MessageContent> = null;

    /** Set the message footer. */
    @:allow(tests)
    @prop var footer:Null<MessageFooter> = null;

    /** Create a leading-aligned message. */
    public function new() {
        super();
    }

    /**
     * Set a stable identity so the message can appear in the accessibility
     * tree and keep element state across frames.
     */
    public function id(id:ElementIdArg):Message {
        this.id = id;
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
        avatarSlot = avatar != null ? MessageAvatar.component().child(avatar) : null;
        return this;
    }

    public inline function style():StyleRefinement {
        return messageStyle;
    }

    public function render(_:Window, _:App):IntoElement {
        final alignment = this.alignment;
        final hasAvatar = avatarSlot != null;
        final hasGhostBubble = content != null && content.hasGhostBubble;

        // No text size or line height here: the header and footer set their
        // own, and content typography belongs to the bubble or the caller.
        final row = glaze.kit.base.Prelude.vFlex()
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
        final line = glaze.kit.base.Prelude.hFlex()
            .wFull()
            .minW0()
            .itemsEnd()
            .gap2();
        if (alignment == End) line.flexRowReverse();
        if (avatarSlot != null) line.child(avatarSlot);
        final stack = glaze.kit.base.Prelude.vFlex()
            .wFull()
            .minW0()
            .gap(rems(0.625));
        switch alignment {
            case Start: stack.itemsStart();
            case End: stack.itemsEnd();
        }
        stack.refineStyle(stackStyle);
        if (header != null) stack.child(header.withInheritedContentInset(!hasGhostBubble));
        if (content != null) stack.child(content.aligned(alignment));
        line.child(stack);
        row.child(line);

        if (this.footer != null) {
            final footer = this.footer.withInheritedContentInset(!hasGhostBubble);
            // Align the footer with the content column: the avatar's shared
            // `size-8` baseline plus the row gap.
            if (hasAvatar && alignment == Start) footer.ml(rems(2.5));
            if (hasAvatar && alignment == End) footer.mr(rems(2.5));
            row.child(footer);
        }

        // Rust puts `role` on the stateful element (accessibility nodes need
        // the stable identity of an element id); the port has no
        // accessibility tree, so only the id is applied.
        if (id != null) row.id(id);
        return row;
    }

}

/**
 * The sender identity slot rendered beside a `Message`.
 *
 * The slot reserves the shared `size-8` baseline; the message row keeps it
 * flush with the bottom edge of the visible message surface.
 */
class MessageAvatar extends Component implements Styled implements ParentElement {

    final avatarStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty avatar slot. */
    public function new() {
        super();
    }

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

        final element = glaze.kit.base.Prelude.hFlex()
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
class MessageHeader extends Component implements Styled implements ParentElement {

    final headerStyle:StyleRefinement = new StyleRefinement();

    /** Set whether the header keeps its default horizontal content inset. */
    @:allow(tests)
    @prop var contentInset:Null<Bool> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message header. */
    public function new() {
        super();
    }

    @:allow(glaze.kit.message, tests)
    function withInheritedContentInset(contentInset:Bool):MessageHeader {
        if (this.contentInset == null) this.contentInset = contentInset;
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

        final element = glaze.kit.base.Prelude.hFlex()
            .maxWFull()
            .minW0()
            .gap1()
            .textXs()
            .lineHeight(glaze.Prelude.relative(1.25))
            .fontMedium()
            .textColor(tokens.colors.mutedForeground);
        if (contentInset == null || contentInset) element.px3();
        element.refineStyle(headerStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * The message body slot. It can contain bubbles, images, code, or files.
 */
class MessageContent extends Component implements Styled implements ParentElement {

    final contentStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var alignment:MessageAlignment = Start;

    @:allow(glaze.kit.message, tests)
    var hasGhostBubble:Bool = false;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message body. */
    public function new() {
        super();
    }

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

    @:allow(glaze.kit.message, tests)
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
        final element = glaze.kit.base.Prelude.vFlex()
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
class MessageFooter extends Component implements Styled implements ParentElement {

    final footerStyle:StyleRefinement = new StyleRefinement();

    /** Set whether the footer keeps its default horizontal content inset. */
    @:allow(tests)
    @prop var contentInset:Null<Bool> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty message footer. */
    public function new() {
        super();
    }

    @:allow(glaze.kit.message, tests)
    function withInheritedContentInset(contentInset:Bool):MessageFooter {
        if (this.contentInset == null) this.contentInset = contentInset;
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

        final element = glaze.kit.base.Prelude.hFlex()
            .maxWFull()
            .minW0()
            .gap1()
            .textXs()
            .lineHeight(glaze.Prelude.relative(1.25))
            .fontMedium()
            .textColor(tokens.colors.mutedForeground);
        if (contentInset == null || contentInset) element.px3();
        element.refineStyle(footerStyle);
        element.extend(childElements);
        return element;
    }

}
