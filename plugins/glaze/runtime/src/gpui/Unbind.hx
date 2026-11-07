// Ported from gpui-pre 0.3.10: src/action.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Action with special handling which unbinds later bindings for the same keystrokes when they
 * dispatch the named action, regardless of that action's context.
 *
 * In keymap JSON this is written as:
 *
 * `["zed::Unbind", "editor::NewLine"]`
 */
@:action(namespace = zed)
class Unbind implements Action {

    /**
     * The name of the action to unbind (Rust: the tuple field `.0`).
     */
    public final actionName:String;

    public function new(actionName:String) {
        this.actionName = actionName;
    }

    /**
     * Rust deserializes the newtype struct from the bare string.
     */
    public static function build(value:Dynamic):Action {
        if (!Std.isOfType(value, String)) {
            throw new haxe.Exception('invalid type: expected a string (the name of the action to unbind)');
        }
        return new Unbind(value);
    }

    public function boxedClone():Action {
        return new Unbind(actionName);
    }

    public function partialEq(action:Action):Bool {
        return isUnbind(action) && (cast action : Unbind).actionName == actionName;
    }

    /**
     * Returns whether or not this action represents an unbind marker.
     */
    public static function isUnbind(action:Action):Bool {
        return action != null && (cast Type.getClass(action) : Class<Dynamic>) == (cast Unbind : Class<Dynamic>);
    }

}
