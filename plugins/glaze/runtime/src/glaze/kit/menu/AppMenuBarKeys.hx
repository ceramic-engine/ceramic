// Ported from gpui-kit 0.8.1: crates/component/src/menu/app_menu_bar.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.menu;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;

/**
 * The key bindings of the app menu bar (Rust `app_menu_bar::init`), in a
 * module of their own so that the kit registers them at startup without
 * loading `AppMenuBar`.
 */
class AppMenuBarKeys {

    public static inline final CONTEXT:String = 'AppMenuBar';

    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('escape', new Cancel(), CONTEXT),
            new KeyBinding('left', new SelectLeft(), CONTEXT),
            new KeyBinding('right', new SelectRight(), CONTEXT),
        ]);
    }

}
