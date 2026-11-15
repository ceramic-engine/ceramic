// Ported from gpui-kit 0.8.1: crates/base/src/lib.rs (init)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;

/**
 * Behavior and infrastructure foundations for GPUI applications (the
 * `gpui-base` crate). Primitives deliberately avoid presentation styles.
 */
class Base {

    /**
     * Initializes global infrastructure owned by the base layer.
     *
     * Ported so far: the Base theme global, `GlobalState`, the focus trap
     * manager, the dialog, popover, sheet, input and root key bindings. The other modules register their
     * globals and bindings here as they are ported.
     *
     * The key bindings are registered here in the Rust order, from classes
     * that do not refer to their component (`SelectKeys`, `TreeKeys`...), so
     * that `-dce full` removes a component the app never uses (see `Kit`).
     */
    public static function init(cx:AppContext):Void {
        // Once per app: the kit's initialization runs it too, after an app
        // that initializes the Base layer itself
        final app:App = cx;
        if (app.hasGlobal(BaseInitialized)) return;
        app.setGlobal(BaseInitialized.instance, BaseInitialized);
        glaze.kit.base.theme.Theme.globalMut(cx);
        GlobalState.init(cx);
        Dialog.DialogKeys.init(cx);
        FocusTrap.init(cx);
        PopoverKeys.bindKeys(cx);
        SheetKeys.bindKeys(cx);
        // Rust order: sheet, combobox, color_picker, select, number_input
        ComboboxKeys.bindKeys(cx);
        // `ColorPickerState.init`
        ColorPickerKeys.init(cx);
        SelectKeys.bindKeys(cx);
        NumberInputKeys.bindKeys(cx);
        // `TimeFieldState.init`
        TimeFieldKeys.init(cx);
        glaze.kit.base.input.InputKeyBindings.init(cx);
        // `TreeState.init`
        TreeKeys.init(cx);
        // `Text.bindKeys`: `Inline.init` (empty), then `TextViewState.init`
        glaze.kit.base.text.TextViewKeys.init(cx);
        Root.bindKeys(cx);
    }

}

/**
 * The global marking an app whose Base layer is initialized.
 */
private class BaseInitialized {

    public static final instance:BaseInitialized = new BaseInitialized();

    function new() {}

}
