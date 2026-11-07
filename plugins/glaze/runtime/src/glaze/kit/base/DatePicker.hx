// Ported from gpui-kit 0.8.1: crates/base/src/date_picker.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.IntoKeyContext;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Unstyled controlled date-picker root. Applications own its trigger, calendar,
 * positioning, and visual presentation; Base owns focus and open/dismiss keyboard behavior.
 *
 * Listeners and the key context go to `base` (Rust `InteractiveElement`).
 */
class DatePicker implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the picker renders. */
    public final base:Div;

    var openValue:Bool = false;

    var disabledValue:Bool = false;

    final focusHandle:FocusHandle;

    final pickerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    /** The accessibility properties the picker exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ComboBox);

    public function new(id:ElementIdArg, focusHandle:FocusHandle) {
        this.base = div().id(id);
        this.focusHandle = focusHandle;
    }

    public function open(open:Bool):DatePicker {
        openValue = open;
        return this;
    }

    public function disabled(disabled:Bool):DatePicker {
        disabledValue = disabled;
        return this;
    }

    public function onOpenChange(handler:(Bool, Window, App) -> Void):DatePicker {
        onOpenChangeHandler = handler;
        return this;
    }

    /** The value exposed to accessibility clients (Rust `aria_value`). */
    public function ariaValue(value:String):DatePicker {
        a11y.value = value;
        return this;
    }

    public inline function style():StyleRefinement {
        return pickerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** The key context (on `base`). */
    public function keyContext(context:IntoKeyContext):DatePicker {
        base.keyContext(context);
        return this;
    }

    /** An action listener (on `base`). */
    public function onAction<A:glaze.Action>(type:Class<A>, listener:(A, Window, App) -> Void):DatePicker {
        base.onAction(type, listener);
        return this;
    }

    /** A click listener (on `base`). */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):DatePicker {
        base.onClick(listener);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final open = openValue;
        final disabled = disabledValue;
        final handler = onOpenChangeHandler;
        a11y.expanded = open;
        base
            .trackFocus(focusHandle.tabStop(!disabled))
            .onAction(Confirm, (_, window, cx) -> {
                // Enter opens the picker, and closes it again once the
                // value shown in the popup is the one the user wants.
                if (disabled) {
                    cx.propagate();
                } else if (handler != null) {
                    handler(!open, window, cx);
                }
            })
            .onAction(Cancel, (_, window, cx) -> {
                if (open) {
                    if (handler != null) {
                        handler(false, window, cx);
                    }
                } else {
                    cx.propagate();
                }
            });
        base.refineStyle(pickerStyle);
        base.extend(childElements);
        a11y.disabled = disabled;
        return base;
    }

}
