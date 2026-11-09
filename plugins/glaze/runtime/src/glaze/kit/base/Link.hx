// Ported from gpui-kit 0.8.1: crates/base/src/link.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.ParentElement;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled link: a focusable, keyboard activatable element whose target
 * is opened by an application-provided strategy (`openWith`). A link
 * without strategy never opens its `href` by itself.
 *
 * Interactive styles (`hover`, `active`, `focusVisible`...) go to `base`,
 * the stateful `Div` the link renders (Rust implements
 * `InteractiveElement` by delegation).
 */
class Link extends Component implements Styled implements ParentElement {

    final id:ElementId;

    /** The stateful element the link renders. */
    public final base:Div;

    final linkStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:LinkStyles = new LinkStyles();

    /**
     * The link target, opened by the `openWith` strategy when activated.
     */
    @prop var href:Null<String> = null;

    @prop var disabled:Bool = false;

    final childElements:Array<AnyElement> = [];

    /**
     * Called on pointer or keyboard activation, after the open strategy.
     */
    @prop var onActivate:Null<(ClickEvent, Window, App) -> Void> = null;

    /**
     * The strategy opening the link target (the application decides how).
     */
    @prop var openWith:Null<(String, ClickEvent, Window, App) -> Void> = null;

    @prop var accessibilityLabel:Null<String> = null;

    @prop var tabIndex:Int = 0;

    @prop var tabStop:Bool = true;

    /**
     * The accessibility properties the link exports (filled by `render`).
     */
    public final a11y:A11y = new A11y(Role.Link);

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
        this.base = div().id(id);
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

    public function styles(build:(LinkStyles) -> LinkStyles):Link {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        return StateStyle.resolveStyle(linkStyle, disabled ? [semanticStyles.disabledStyle] : []);
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Link {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):Link {
        base.active(f);
        return this;
    }

    /** Interactive style while focused by the keyboard (on `base`). */
    public function focusVisible(f:(StyleBuilder) -> StyleBuilder):Link {
        base.focusVisible(f);
        return this;
    }

    function focusHandle(window:Window, cx:App):FocusHandle {
        return window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final disabled = this.disabled;
        final style = resolvedStyle();
        final href = this.href;
        final openWith = this.openWith;
        final onActivate = this.onActivate;
        final activates = onActivate != null || href != null && openWith != null;

        a11y.label = accessibilityLabel;
        a11y.disabled = disabled;
        a11y.clickable = !disabled && activates;

        final element = base;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndex).tabStop(tabStop));
        }
        if (disabled) {
            element.onMouseDown(Left, (_, _, cx) -> cx.stopPropagation());
        }
        if (!disabled && activates) {
            element.onClick((event, window, cx) -> {
                if (href != null && openWith != null) {
                    openWith(href, event, window, cx);
                }
                if (onActivate != null) {
                    onActivate(event, window, cx);
                }
            });
        }
        element.extend(childElements);
        return element.refineStyle(style);
    }

}
