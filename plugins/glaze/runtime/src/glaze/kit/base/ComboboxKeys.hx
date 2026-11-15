// Ported from gpui-kit 0.8.1: crates/base/src/combobox.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;

/**
 * The key bindings of `Combobox` (Rust `combobox::init`), in a module of
 * their own so that `Base.init` registers them without loading the combobox.
 */
class ComboboxKeys {

    public static inline final CONTEXT:String = "Combobox";

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

}
