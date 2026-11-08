// Ported from gpui-kit 0.8.1: crates/base/src/combobox.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;

using glaze.kit.base.StyledExt;

/**
 * An unstyled controlled combobox root.
 *
 * Applications own the trigger, popup, searchable collection, selection, and
 * appearance. This root owns combobox semantics and keyboard focus transfer.
 */
class Combobox implements RenderOnce implements Styled implements ParentElement {

    static inline final CONTEXT:String = "Combobox";

    /**
     * Rust `combobox::init`: binds the combobox keys.
     */
    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new SelectUp(), CONTEXT),
            new KeyBinding("down", new SelectDown(), CONTEXT),
            new KeyBinding("enter", new Confirm(false), CONTEXT),
            new KeyBinding(OperatingSystem.current.isMac() ? "cmd-enter" : "ctrl-enter", new Confirm(true), CONTEXT),
            new KeyBinding("escape", new Cancel(), CONTEXT),
        ]);
    }

    final id:ElementIdArg;

    var openValue:Bool = false;

    var disabledValue:Bool = false;

    var focusHandleValue:Null<FocusHandle> = null;

    var contentFocusHandleValue:Null<FocusHandle> = null;

    final comboboxStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    var onConfirmHandler:Null<(Window, App) -> Void> = null;

    var onDismissHandler:Null<(Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public function open(open:Bool):Combobox {
        openValue = open;
        return this;
    }

    public function disabled(disabled:Bool):Combobox {
        disabledValue = disabled;
        return this;
    }

    public function focusHandle(focusHandle:FocusHandle):Combobox {
        focusHandleValue = focusHandle;
        return this;
    }

    public function contentFocusHandle(focusHandle:FocusHandle):Combobox {
        contentFocusHandleValue = focusHandle;
        return this;
    }

    public function onOpenChange(handler:(Bool, Window, App) -> Void):Combobox {
        onOpenChangeHandler = handler;
        return this;
    }

    /**
     * Handles the Confirm action while the combobox is open.
     */
    public function onConfirm(handler:(Window, App) -> Void):Combobox {
        onConfirmHandler = handler;
        return this;
    }

    /**
     * Handles a dismissal requested through the Cancel action.
     *
     * This runs before the controlled open state is asked to close, so a
     * combobox that commits its pending value on dismissal can still read
     * that value here.
     */
    public function onDismiss(handler:(Window, App) -> Void):Combobox {
        onDismissHandler = handler;
        return this;
    }

    public inline function style():StyleRefinement {
        return comboboxStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Combobox {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Combobox {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final select = Select.component(id)
            .open(openValue)
            .disabled(disabledValue)
            .keyContext(CONTEXT);
        if (focusHandleValue != null) select.focusHandle(focusHandleValue);
        if (contentFocusHandleValue != null) select.contentFocusHandle(contentFocusHandleValue);
        if (onOpenChangeHandler != null) {
            final handler = onOpenChangeHandler;
            select.onOpenChange((open, window, cx) -> handler(open, window, cx));
        }
        if (onConfirmHandler != null) {
            final handler = onConfirmHandler;
            select.onConfirm((window, cx) -> handler(window, cx));
        }
        if (onDismissHandler != null) {
            final handler = onDismissHandler;
            select.onDismiss((window, cx) -> handler(window, cx));
        }
        select.extend(childElements);
        return select.refineStyle(comboboxStyle);
    }

}
