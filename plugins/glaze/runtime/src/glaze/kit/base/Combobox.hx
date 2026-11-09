// Ported from gpui-kit 0.8.1: crates/base/src/combobox.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.ParentElement;
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
class Combobox extends Component implements Styled implements ParentElement {

    static inline final CONTEXT:String = "Combobox";

    /**
     * Rust `combobox::init`: binds the combobox keys.
     */
    public static function bindKeys(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new SelectUp(), CONTEXT),
            new KeyBinding("down", new SelectDown(), CONTEXT),
            new KeyBinding("enter", new Confirm(false), CONTEXT),
            new KeyBinding(OperatingSystem.current.isMac() ? "cmd-enter" : "ctrl-enter", new Confirm(true), CONTEXT),
            new KeyBinding("escape", new Cancel(), CONTEXT),
        ]);
    }

    final id:ElementIdArg;

    @prop var open:Bool = false;

    @prop var disabled:Bool = false;

    @prop var focusHandle:Null<FocusHandle> = null;

    @prop var contentFocusHandle:Null<FocusHandle> = null;

    final comboboxStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    @prop var onOpenChange:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Handles the Confirm action while the combobox is open.
     */
    @prop var onConfirm:Null<(Window, App) -> Void> = null;

    /**
     * Handles a dismissal requested through the Cancel action.
     *
     * This runs before the controlled open state is asked to close, so a
     * combobox that commits its pending value on dismissal can still read
     * that value here.
     */
    @prop var onDismiss:Null<(Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
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
            .open(this.open)
            .disabled(disabled)
            .keyContext(CONTEXT);
        if (focusHandle != null) select.focusHandle(focusHandle);
        if (contentFocusHandle != null) select.contentFocusHandle(contentFocusHandle);
        if (onOpenChange != null) {
            final handler = onOpenChange;
            select.onOpenChange((open, window, cx) -> handler(open, window, cx));
        }
        if (onConfirm != null) {
            final handler = onConfirm;
            select.onConfirm((window, cx) -> handler(window, cx));
        }
        if (onDismiss != null) {
            final handler = onDismiss;
            select.onDismiss((window, cx) -> handler(window, cx));
        }
        select.extend(childElements);
        return select.refineStyle(comboboxStyle);
    }

}
