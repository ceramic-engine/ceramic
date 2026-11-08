// Ported from gpui-kit 0.8.1: crates/base/src/select.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Component;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;

import glaze.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;

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
class Select extends Component implements Styled implements ParentElement {

    static inline final CONTEXT:String = "Select";

    /**
     * Rust `select::init`: binds the select keys.
     */
    public static function bindKeys(cx:AppContext):Void {
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

    /** Sets the application-controlled open state. */
    @prop var open:Bool = false;

    /** Prevents keyboard and accessible activation and removes the trigger from tab traversal. */
    @prop var disabled:Bool = false;

    /** Supplies the focus handle for the select trigger. */
    @prop var focusHandle:Null<FocusHandle> = null;

    /** Supplies the focus handle that receives keyboard navigation while open. */
    @prop var contentFocusHandle:Null<FocusHandle> = null;

    /** Sets the accessible name exposed by the controlled root. */
    @prop var accessibilityLabel:Null<String> = null;

    /**
     * Sets the committed value exposed by the controlled root.
     *
     * Supply a readable selection title, not the current search query or cursor.
     */
    @prop var accessibilityValue:Null<String> = null;

    final selectStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /** Handles requests to update the controlled open state. */
    @prop var onOpenChange:Null<(Bool, Window, App) -> Void> = null;

    /** Rust `key_context` (hidden). */
    @prop var keyContext:String = CONTEXT;

    /**
     * Handles a dismissal, however it was requested: the Cancel action, or
     * the accessible activation that closes an open control.
     *
     * This runs before the controlled open state is asked to close, so a
     * caller that commits its pending value on dismissal can still read that
     * value here.
     */
    @prop var onDismiss:Null<(Window, App) -> Void> = null;

    /**
     * Handles the Confirm action while the select is open.
     *
     * Confirming a closed select opens it instead, so this never runs for
     * that case.
     */
    @prop var onConfirm:Null<(Window, App) -> Void> = null;

    /** The accessibility properties the root exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ComboBox);

    /**
     * The accessible Click activation (Rust `on_a11y_action(Click)`), set by
     * `render` when the select is enabled.
     */
    public var a11yClick(default, null):Null<(Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        super();
        base = div().id(id).testSupport();
    }

    public inline function style():StyleRefinement {
        return selectStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Select {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Select {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final open = this.open;
        final disabled = this.disabled;
        final focusHandle = this.focusHandle;
        final contentFocusHandle = this.contentFocusHandle;
        final onOpenChange = this.onOpenChange;
        final onDismiss = this.onDismiss;
        final onConfirm = this.onConfirm;

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
        if (accessibilityLabel != null) a11y.label = accessibilityLabel;
        if (accessibilityValue != null) a11y.value = accessibilityValue;
        element.keyContext(keyContext);
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
