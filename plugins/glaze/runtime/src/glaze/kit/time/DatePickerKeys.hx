// Ported from gpui-kit 0.8.1: crates/component/src/time/date_picker.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.time;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.input.InputActions.Delete;

/**
 * The key bindings of the date picker (Rust `date_picker::init`), in a module
 * of their own so that the kit registers them at startup without loading
 * `DatePickerState`.
 */
class DatePickerKeys {

    public static inline final CONTEXT:String = "DatePicker";

    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("enter", new Confirm(false), CONTEXT),
            new KeyBinding("escape", new Cancel(), CONTEXT),
            new KeyBinding("delete", new Delete(), CONTEXT),
            new KeyBinding("backspace", new Delete(), CONTEXT),
        ]);
    }

}
