// Ported from gpui-kit 0.8.1: crates/base/src/lib.rs (init)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.AppContext;

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
     */
    public static function init(cx:AppContext):Void {
        gpui.base.theme.Theme.globalMut(cx);
        GlobalState.init(cx);
        Dialog.DialogKeys.init(cx);
        FocusTrap.init(cx);
        Popover.init(cx);
        Sheet.init(cx);
        // Rust order: sheet, combobox, color_picker, select, number_input
        Combobox.init(cx);
        ColorPicker.ColorPickerState.init(cx);
        Select.init(cx);
        NumberInput.init(cx);
        TimeField.TimeFieldState.init(cx);
        gpui.base.input.InputKeyBindings.init(cx);
        Tree.TreeState.init(cx);
        gpui.base.text.Text.init(cx);
        Root.init(cx);
    }

}
