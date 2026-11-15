// Ported from gpui-kit 0.8.1: crates/component/src/list/list.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.list;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.kit.base.Actions.Cancel as CancelAction;
import glaze.kit.base.Actions.Confirm as ConfirmAction;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;

/**
 * The key bindings of the list (Rust `list::init`), in a module of their own
 * so that the kit registers them at startup without loading `ListState`.
 */
class ListKeys {

    public static inline final CONTEXT:String = "List";

    public static function init(cx:AppContext):Void {
        final context = CONTEXT;
        (cx : App).bindKeys([
            new KeyBinding("escape", new CancelAction(), context),
            new KeyBinding("enter", new ConfirmAction(false), context),
            new KeyBinding(OperatingSystem.current.isMac() ? "cmd-enter" : "ctrl-enter", new ConfirmAction(true), context),
            new KeyBinding("up", new SelectUp(), context),
            new KeyBinding("down", new SelectDown(), context),
        ]);
    }

}
