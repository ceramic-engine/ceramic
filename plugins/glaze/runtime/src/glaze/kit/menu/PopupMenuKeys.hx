// Ported from gpui-kit 0.8.1: crates/component/src/menu/popup_menu.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.menu;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.Actions.SelectUp;

/**
 * The key bindings of the popup menu (Rust `popup_menu::init`), in a module
 * of their own so that the kit registers them at startup without loading
 * `PopupMenu`.
 */
class PopupMenuKeys {

    public static inline final CONTEXT:String = 'PopupMenu';

    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('enter', new Confirm(false), CONTEXT),
            new KeyBinding('escape', new Cancel(), CONTEXT),
            new KeyBinding('up', new SelectUp(), CONTEXT),
            new KeyBinding('down', new SelectDown(), CONTEXT),
            new KeyBinding('left', new SelectLeft(), CONTEXT),
            new KeyBinding('right', new SelectRight(), CONTEXT),
        ]);
    }

}
