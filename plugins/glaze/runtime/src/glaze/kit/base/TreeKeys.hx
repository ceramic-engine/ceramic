// Ported from gpui-kit 0.8.1: crates/base/src/tree.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.Actions.SelectUp;

/**
 * The key bindings of the tree (Rust `tree::init`), in a module of their own
 * so that `Base.init` registers them without loading `TreeState`.
 */
class TreeKeys {

    public static inline final CONTEXT:String = "Tree";

    /** Rust `tree::init`: binds the tree keys. */
    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new SelectUp(), CONTEXT),
            new KeyBinding("down", new SelectDown(), CONTEXT),
            new KeyBinding("left", new SelectLeft(), CONTEXT),
            new KeyBinding("right", new SelectRight(), CONTEXT),
        ]);
    }

}
