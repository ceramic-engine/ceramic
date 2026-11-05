// Ported from gpui-kit 0.8.1: crates/component/src/link.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.link;

import gpui.AnyElement;
import gpui.App;
import gpui.ClickEvent;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.PlatformUrl;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * A text link, opening its `href` with the platform (and calling
 * `onClick`) when clicked with the pointer. It stays pointer-only, and
 * `disabled` is stored but inert, like the original legacy component; use
 * `gpui.base.Link` for a focusable, keyboard activatable link.
 */
class Link implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    final linkStyle:StyleRefinement = new StyleRefinement();

    var hrefValue:Null<String> = null;

    var disabledValue:Bool = false;

    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    final childElements:Array<AnyElement> = [];

    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return linkStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Link {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Link {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function href(href:String):Link {
        hrefValue = href;
        return this;
    }

    public function onClick(handler:(ClickEvent, Window, App) -> Void):Link {
        onClickHandler = handler;
        return this;
    }

    public function disabled(disabled:Bool):Link {
        disabledValue = disabled;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final href = hrefValue;
        final onClick = onClickHandler;
        final link = Theme.global(cx).link;

        final element = div()
            .id(id)
            .textColor(link)
            .textDecoration1()
            .textDecorationColor(link.opacity(0.5))
            .hover(s -> s.textColor(link.opacity(0.8)).textDecoration1().textDecorationColor(link))
            .active(s -> s.textColor(link.opacity(0.6)).textDecoration1().textDecorationColor(link))
            .cursorPointer()
            .refineStyle(linkStyle)
            .onMouseDown(Left, (_, _, cx) -> cx.stopPropagation())
            .onClick((e, window, cx) -> {
                if (href != null) {
                    PlatformUrl.openUrl(cx, href);
                }
                if (onClick != null) {
                    onClick(e, window, cx);
                }
            });
        element.extend(childElements);
        return element;
    }

}
