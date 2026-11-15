// Ported from gpui-kit 0.8.1: crates/base/src/time_field.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectNextColumn;
import glaze.kit.base.Actions.SelectPrevColumn;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.NumberInput.Decrement;
import glaze.kit.base.NumberInput.Increment;
import glaze.kit.base.input.InputActions.Delete;

/**
 * The key bindings of the time field (Rust `time_field::init`), in a module
 * of their own so that `Base.init` registers them without loading
 * `TimeFieldState`.
 */
class TimeFieldKeys {

    public static inline final CONTEXT:String = "TimeField";

    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new Increment(), CONTEXT),
            new KeyBinding("down", new Decrement(), CONTEXT),
            new KeyBinding("left", new SelectLeft(), CONTEXT),
            new KeyBinding("right", new SelectRight(), CONTEXT),
            new KeyBinding("tab", new SelectNextColumn(), CONTEXT),
            new KeyBinding("shift-tab", new SelectPrevColumn(), CONTEXT),
            new KeyBinding("backspace", new Delete(), CONTEXT),
            new KeyBinding("delete", new Delete(), CONTEXT),
        ]);
    }

}
