// Ported from gpui-kit 0.8.1: crates/base/src/sheet.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.Cancel;

/**
 * The key bindings of the base `Sheet` (Rust `sheet::init`), in a module of
 * their own so that `Base.init` registers them without loading the sheet.
 */
class SheetKeys {

    public static inline final CONTEXT = 'Sheet';

    public static function bindKeys(cx:AppContext):Void {
        (cx:App).bindKeys([new KeyBinding('escape', new Cancel(), CONTEXT)]);
    }

}
