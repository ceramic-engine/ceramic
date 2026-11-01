// Ported from gpui-kit 0.8.1: crates/base/src/select.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.Div;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.OperatingSystem;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Actions.Cancel;
import gpui.base.Actions.Confirm;
import gpui.base.Actions.SelectDown;
import gpui.base.Actions.SelectUp;

import gpui.Prelude.*;

using gpui.base.Observe;
using gpui.base.StyledExt;

/**
 * An unstyled controlled select root.
 *
 * Applications own the trigger and popup presentation, the option collection,
 * and the selected value. This root owns combobox accessibility semantics,
 * keyboard opening and dismissal, and focus transfer between the trigger and
 * popup content.
 *
 * GPUI marks the active option on the option element itself rather than on the
 * container, so the application marks its highlighted option with
 * `aria_active_descendant()`; this root cannot do it on the caller's behalf.
 *
 * The port has no accessibility tree: the properties the root exports are
 * kept in `a11y` (filled by `render`), and the accessible Click activation is
 * `a11yClick` (set by `render` when the select is enabled).
 */
class Select implements RenderOnce implements Styled implements ParentElement {

    static inline final CONTEXT:String = "Select";

    /**
     * Rust `select::init`: binds the select keys.
     */
    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("space", new Confirm(false), "Select && !Input"),
            new KeyBinding("up", new SelectUp(), CONTEXT),
            new KeyBinding("down", new SelectDown(), CONTEXT),
            new KeyBinding("enter", new Confirm(false), CONTEXT),
            new KeyBinding(OperatingSystem.current.isMac() ? "cmd-enter" : "ctrl-enter", new Confirm(true), CONTEXT),
            new KeyBinding("escape", new Cancel(), CONTEXT),
        ]);
    }

    /** The stateful element the root renders. */
    public final base:Div;

    var openValue:Bool = false;

    var disabledValue:Bool = false;

    var focusHandleValue:Null<FocusHandle> = null;

    var contentFocusHandleValue:Null<FocusHandle> = null;

    var accessibilityLabelValue:Null<String> = null;

    var accessibilityValueValue:Null<String> = null;

    final selectStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    var keyContextValue:String = CONTEXT;

    var onDismissHandler:Null<(Window, App) -> Void> = null;

    var onConfirmHandler:Null<(Window, App) -> Void> = null;

    /** The accessibility properties the root exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ComboBox);

    /**
     * The accessible Click activation (Rust `on_a11y_action(Click)`), set by
     * `render` when the select is enabled.
     */
    public var a11yClick(default, null):Null<(Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        base = div().id(id).testSupport();
    }

    /** Sets the application-controlled open state. */
    public function open(open:Bool):Select {
        openValue = open;
        return this;
    }

    /** Prevents keyboard and accessible activation and removes the trigger from tab traversal. */
    public function disabled(disabled:Bool):Select {
        disabledValue = disabled;
        return this;
    }

    /** Supplies the focus handle for the select trigger. */
    public function focusHandle(focusHandle:FocusHandle):Select {
        focusHandleValue = focusHandle;
        return this;
    }

    /** Supplies the focus handle that receives keyboard navigation while open. */
    public function contentFocusHandle(focusHandle:FocusHandle):Select {
        contentFocusHandleValue = focusHandle;
        return this;
    }

    /** Sets the accessible name exposed by the controlled root. */
    public function accessibilityLabel(label:String):Select {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Sets the committed value exposed by the controlled root.
     *
     * Supply a readable selection title, not the current search query or cursor.
     */
    public function accessibilityValue(value:String):Select {
        accessibilityValueValue = value;
        return this;
    }

    /** Handles requests to update the controlled open state. */
    public function onOpenChange(handler:(Bool, Window, App) -> Void):Select {
        onOpenChangeHandler = handler;
        return this;
    }

    /** Rust `key_context` (hidden). */
    public function keyContext(keyContext:String):Select {
        keyContextValue = keyContext;
        return this;
    }

    /**
     * Handles a dismissal, however it was requested: the Cancel action, or
     * the accessible activation that closes an open control.
     *
     * This runs before the controlled open state is asked to close, so a
     * caller that commits its pending value on dismissal can still read that
     * value here.
     */
    public function onDismiss(handler:(Window, App) -> Void):Select {
        onDismissHandler = handler;
        return this;
    }

    /**
     * Handles the Confirm action while the select is open.
     *
     * Confirming a closed select opens it instead, so this never runs for
     * that case.
     */
    public function onConfirm(handler:(Window, App) -> Void):Select {
        onConfirmHandler = handler;
        return this;
    }

    public inline function style():StyleRefinement {
        return selectStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Select {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Select {
        for (child in children) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final open = openValue;
        final disabled = disabledValue;
        final focusHandle = focusHandleValue;
        final contentFocusHandle = contentFocusHandleValue;
        final onOpenChange = onOpenChangeHandler;
        final onDismiss = onDismissHandler;
        final onConfirm = onConfirmHandler;

        // Every way of closing runs the same steps. A caller that tracks
        // dismissal has to see one however the popup was closed, and the
        // accessible activation closes exactly what Escape closes.
        final close = (window:Window, cx:App) -> {
            if (onDismiss != null) {
                onDismiss(window, cx);
            }
            if (onOpenChange != null) {
                onOpenChange(false, window, cx);
            }
            if (focusHandle != null) {
                focusHandle.focus(window, cx);
            }
        };

        final element = base;
        a11y.expanded = open;
        if (accessibilityLabelValue != null) a11y.label = accessibilityLabelValue;
        if (accessibilityValueValue != null) a11y.value = accessibilityValueValue;
        element.keyContext(keyContextValue);
        if (focusHandle != null && !disabled) {
            element.trackFocus(focusHandle.tabStop(true));
        }
        if (!disabled) {
            // Platform adapters may flatten the trigger child.
            // Expose activation on the semantic root itself.
            a11y.clickable = true;
            a11yClick = (window, cx) -> {
                if (open) {
                    close(window, cx);
                    return;
                }

                if (onOpenChange != null) {
                    onOpenChange(true, window, cx);
                }
                if (contentFocusHandle != null) {
                    contentFocusHandle.focus(window, cx);
                }
            };
        }
        element.onAction(SelectUp, (_, window, cx) -> {
            if (disabled) {
                cx.propagate();
                return;
            }

            if (!open) {
                if (onOpenChange != null) {
                    onOpenChange(true, window, cx);
                }
            }

            if (contentFocusHandle != null) {
                contentFocusHandle.focus(window, cx);
            }
            cx.propagate();
        });
        element.onAction(SelectDown, (_, window, cx) -> {
            if (disabled) {
                cx.propagate();
                return;
            }

            if (!open) {
                if (onOpenChange != null) {
                    onOpenChange(true, window, cx);
                }
            }

            if (contentFocusHandle != null) {
                contentFocusHandle.focus(window, cx);
            }
            cx.propagate();
        });
        element.onAction(Confirm, (_, window, cx) -> {
            if (disabled) {
                cx.propagate();
                return;
            }

            if (open) {
                if (onConfirm != null) {
                    onConfirm(window, cx);
                }
            } else if (onOpenChange != null) {
                onOpenChange(true, window, cx);
            }

            if (contentFocusHandle != null) {
                contentFocusHandle.focus(window, cx);
            }
        });
        element.onAction(Cancel, (_, window, cx) -> {
            if (!open) {
                cx.propagate();
                return;
            }

            cx.stopPropagation();
            close(window, cx);
        });
        element.extend(childElements);
        element.refineStyle(selectStyle);
        // Rust `.a11y_disabled(disabled)`: marks the node, adds no layout node.
        a11y.disabled = disabled;
        return element;
    }

}
