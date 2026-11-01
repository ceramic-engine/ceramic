// Ported from gpui-pre 0.3.10: src/action.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Action with special handling which unbinds the keybinding this is associated with,
 * if it is the highest precedence match.
 */
@:action(namespace = zed)
class NoAction implements Action {

    /**
     * Returns whether or not this action represents a removed key binding.
     */
    public static function isNoAction(action:Action):Bool {
        return action != null && (cast Type.getClass(action) : Class<Dynamic>) == (cast NoAction : Class<Dynamic>);
    }

}
