// Ported from gpui-kit 0.8.1: crates/base/src/popover.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.NoAction;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;

/**
 * The key bindings of `Popover` (Rust `popover::init`), in a module of their
 * own so that `Base.init` registers them without loading the popover.
 */
class PopoverKeys {

    public static inline final CONTEXT = 'Popover';

    public static inline final CONTENT_CONTEXT = 'PopoverContent';

    public static function bindKeys(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('escape', new Cancel(), CONTEXT),
            new KeyBinding('enter', new Confirm(false), CONTEXT),
            new KeyBinding('space', new Confirm(false), CONTEXT),
            new KeyBinding('escape', new Cancel(), CONTENT_CONTEXT),
            // The content is still a descendant of the trigger's dispatch node.
            // Leave activation to its controls, not the trigger or an outer dialog.
            // More deeply scoped input bindings retain precedence.
            new KeyBinding('enter', new NoAction(), CONTENT_CONTEXT),
            new KeyBinding('space', new NoAction(), CONTENT_CONTEXT)
        ]);
    }

}
