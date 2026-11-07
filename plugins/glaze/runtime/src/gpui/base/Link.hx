// Ported from gpui-kit 0.8.1: crates/base/src/link.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.ClickEvent;
import gpui.Div;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.MouseButton;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * An unstyled link: a focusable, keyboard activatable element whose target
 * is opened by an application-provided strategy (`openWith`). A link
 * without strategy never opens its `href` by itself.
 *
 * Interactive styles (`hover`, `active`, `focusVisible`...) go to `base`,
 * the stateful `Div` the link renders (Rust implements
 * `InteractiveElement` by delegation).
 */
class Link implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    /** The stateful element the link renders. */
    public final base:Div;

    final linkStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:LinkStyles = new LinkStyles();

    var hrefValue:Null<String> = null;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    var onActivateHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    var openWithHandler:Null<(String, ClickEvent, Window, App) -> Void> = null;

    var accessibilityLabelValue:Null<String> = null;

    var tabIndexValue:Int = 0;

    var tabStopValue:Bool = true;

    /**
     * The accessibility properties the link exports (filled by `render`).
     */
    public final a11y:A11y = new A11y(Role.Link);

    public function new(id:ElementIdArg) {
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

    /**
     * The link target, opened by the `openWith` strategy when activated.
     */
    public function href(href:String):Link {
        hrefValue = href;
        return this;
    }

    /**
     * The strategy opening the link target (the application decides how).
     */
    public function openWith(open:(String, ClickEvent, Window, App) -> Void):Link {
        openWithHandler = open;
        return this;
    }

    /**
     * Called on pointer or keyboard activation, after the open strategy.
     */
    public function onActivate(handler:(ClickEvent, Window, App) -> Void):Link {
        onActivateHandler = handler;
        return this;
    }

    public function disabled(disabled:Bool):Link {
        disabledValue = disabled;
        return this;
    }

    public function styles(build:(LinkStyles) -> LinkStyles):Link {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        return StateStyle.resolveStyle(linkStyle, disabledValue ? [semanticStyles.disabledStyle] : []);
    }

    public function accessibilityLabel(label:String):Link {
        accessibilityLabelValue = label;
        return this;
    }

    public function tabIndex(tabIndex:Int):Link {
        tabIndexValue = tabIndex;
        return this;
    }

    public function tabStop(tabStop:Bool):Link {
        tabStopValue = tabStop;
        return this;
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
        final disabled = disabledValue;
        final style = resolvedStyle();
        final href = hrefValue;
        final openWith = openWithHandler;
        final onActivate = onActivateHandler;
        final activates = onActivate != null || href != null && openWith != null;

        a11y.label = accessibilityLabelValue;
        a11y.disabled = disabled;
        a11y.clickable = !disabled && activates;

        final element = base;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndexValue).tabStop(tabStopValue));
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
