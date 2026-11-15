// Ported from gpui-kit 0.8.1: crates/base/src/color_picker.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;

/**
 * The key bindings of the color picker (Rust `color_picker::init`), in a
 * module of their own so that `Base.init` registers them without loading
 * `ColorPickerState`.
 */
class ColorPickerKeys {

    public static inline final CONTEXT:String = "ColorPicker";

    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("enter", new Confirm(false), CONTEXT),
            new KeyBinding("escape", new Cancel(), CONTEXT),
        ]);
    }

}
