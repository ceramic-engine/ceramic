// Ported from gpui-kit 0.8.1: crates/component/src/empty.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.empty;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An empty state: an optional header (media, title, description), an
 * optional content slot, then free children, in a dashed rounded panel
 * (give it a border width to show the border). The slots always render in
 * that order, whatever order they are set in.
 *
 * Not to be confused with `glaze.Empty` (the element that renders nothing).
 */
class Empty implements RenderOnce implements Styled implements ParentElement {

    @:allow(tests)
    final emptyStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var headerValue:Null<EmptyHeader> = null;

    @:allow(tests)
    var contentValue:Null<EmptyContent> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {}

    public function header(header:EmptyHeader):Empty {
        headerValue = header;
        return this;
    }

    public function content(content:EmptyContent):Empty {
        contentValue = content;
        return this;
    }

    public inline function style():StyleRefinement {
        return emptyStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Empty {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Empty {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final element = glaze.kit.base.Prelude.vFlex()
            .wFull()
            .minW0()
            .flex1()
            .itemsCenter()
            .justifyCenter()
            .gap4()
            .p6()
            .rounded(theme.radiusTokens().xl)
            .borderDashed()
            .borderColor(theme.border)
            .textCenter()
            .textColor(theme.foreground)
            .refineStyle(emptyStyle);
        if (headerValue != null) element.child(headerValue);
        if (contentValue != null) element.child(contentValue);
        element.extend(childElements);
        return element;
    }

}

/**
 * The header of an `Empty`: media, title and description, in that order.
 */
class EmptyHeader implements RenderOnce implements Styled {

    @:allow(tests)
    final headerStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var mediaValue:Null<EmptyMedia> = null;

    @:allow(tests)
    var titleValue:Null<EmptyTitle> = null;

    @:allow(tests)
    var descriptionValue:Null<EmptyDescription> = null;

    public function new() {}

    public function media(media:EmptyMedia):EmptyHeader {
        mediaValue = media;
        return this;
    }

    public function title(title:EmptyTitle):EmptyHeader {
        titleValue = title;
        return this;
    }

    public function description(description:EmptyDescription):EmptyHeader {
        descriptionValue = description;
        return this;
    }

    public inline function style():StyleRefinement {
        return headerStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = glaze.kit.base.Prelude.vFlex()
            .wFull()
            .maxW(rems(24.))
            .minW0()
            .itemsCenter()
            .gap2()
            .refineStyle(headerStyle);
        if (mediaValue != null) element.child(mediaValue);
        if (titleValue != null) element.child(titleValue);
        if (descriptionValue != null) element.child(descriptionValue);
        return element;
    }

}

/**
 * How `EmptyMedia` frames its content.
 */
enum abstract EmptyMediaVariant(Int) {
    var Default;
    /** A small rounded tile on the muted color, for an icon. */
    var Icon;
}

/**
 * The media slot of an `EmptyHeader` (an icon, an avatar...).
 */
class EmptyMedia implements RenderOnce implements Styled implements ParentElement {

    @:allow(tests)
    final mediaStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var variant:EmptyMediaVariant = Default;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {}

    public function withVariant(variant:EmptyMediaVariant):EmptyMedia {
        this.variant = variant;
        return this;
    }

    public inline function style():StyleRefinement {
        return mediaStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):EmptyMedia {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        // A column preserves the intrinsic width of nested rows such as AvatarGroup.
        final element = glaze.kit.base.Prelude.vFlex()
            .flexShrink0()
            .itemsCenter()
            .justifyCenter()
            .mb2();
        if (variant == Icon) {
            element.size8()
                .rounded(theme.radiusTokens().lg)
                .bg(theme.muted)
                .textColor(theme.foreground)
                // Icon inherits one rem unless it has an explicit size.
                .textBase();
        }
        element.refineStyle(mediaStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * The title of an `EmptyHeader`.
 */
class EmptyTitle implements RenderOnce implements Styled implements ParentElement {

    @:allow(tests)
    final titleStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return titleStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):EmptyTitle {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = div()
            .maxWFull()
            .minW0()
            .textSm()
            .fontMedium()
            .whitespaceNormal()
            .refineStyle(titleStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * The description of an `EmptyHeader`.
 */
class EmptyDescription implements RenderOnce implements Styled implements ParentElement {

    @:allow(tests)
    final descriptionStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return descriptionStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):EmptyDescription {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):EmptyDescription {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = div()
            .wFull()
            .minW0()
            .textSm()
            .lineHeight(glaze.Prelude.relative(1.625))
            .textColor(Theme.global(cx).mutedForeground)
            .whitespaceNormal()
            .refineStyle(descriptionStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * The content slot of an `Empty` (actions...).
 */
class EmptyContent implements RenderOnce implements Styled implements ParentElement {

    @:allow(tests)
    final contentStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return contentStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):EmptyContent {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):EmptyContent {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = glaze.kit.base.Prelude.vFlex()
            .wFull()
            .maxW(rems(24.))
            .minW0()
            .itemsCenter()
            .gap2p5()
            .textSm()
            .refineStyle(contentStyle);
        element.extend(childElements);
        return element;
    }

}
