// Ported from gpui-kit 0.8.1: crates/component/src/empty.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.empty;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.IntoElement;
import glaze.ParentElement;
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
class Empty extends Component implements Styled implements ParentElement {

    @:allow(tests)
    final emptyStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    @prop var header:Null<EmptyHeader> = null;

    @:allow(tests)
    @prop var content:Null<EmptyContent> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
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
        if (header != null) element.child(header);
        if (content != null) element.child(content);
        element.extend(childElements);
        return element;
    }

}

/**
 * The header of an `Empty`: media, title and description, in that order.
 */
class EmptyHeader extends Component implements Styled {

    @:allow(tests)
    final headerStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    @prop var media:Null<EmptyMedia> = null;

    @:allow(tests)
    @prop var title:Null<EmptyTitle> = null;

    @:allow(tests)
    @prop var description:Null<EmptyDescription> = null;

    public function new() {
        super();
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
        if (media != null) element.child(media);
        if (title != null) element.child(title);
        if (description != null) element.child(description);
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
class EmptyMedia extends Component implements Styled implements ParentElement {

    @:allow(tests)
    final mediaStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var variant:EmptyMediaVariant = Default;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

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
class EmptyTitle extends Component implements Styled implements ParentElement {

    @:allow(tests)
    final titleStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

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
class EmptyDescription extends Component implements Styled implements ParentElement {

    @:allow(tests)
    final descriptionStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

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
class EmptyContent extends Component implements Styled implements ParentElement {

    @:allow(tests)
    final contentStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

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
