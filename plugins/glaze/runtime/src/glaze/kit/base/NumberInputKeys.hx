// Ported from gpui-kit 0.8.1: crates/base/src/number_input.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.NumberInput.Decrement;
import glaze.kit.base.NumberInput.Increment;

/**
 * The key bindings of `NumberInput` (Rust `number_input::init`), in a class
 * of their own so that `Base.init` registers them without keeping the
 * number input itself.
 */
class NumberInputKeys {

    public static inline final CONTEXT:String = "NumberInput";

    public static function bindKeys(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new Increment(), CONTEXT),
            new KeyBinding("down", new Decrement(), CONTEXT),
        ]);
    }

}
