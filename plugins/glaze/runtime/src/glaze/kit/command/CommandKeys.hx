// Ported from gpui-kit 0.8.1: crates/component/src/command/state.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.command;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;

/**
 * The key bindings of the command palette (Rust `command::init`), in a module
 * of their own so that the kit registers them at startup without loading
 * `CommandState`.
 */
class CommandKeys {

    public static inline final CONTEXT:String = "Command";

    public static function init(cx:AppContext):Void {
        final context = CONTEXT;
        (cx : App).bindKeys([
            new KeyBinding("escape", new Cancel(), context),
            new KeyBinding("enter", new Confirm(false), context),
            new KeyBinding("up", new SelectUp(), context),
            new KeyBinding("down", new SelectDown(), context),
        ]);
    }

}
