// Ported from gpui-pre 0.3.10: src/platform.rs (SystemNotificationAction)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A button offered on a `SystemNotification`.
 */
class SystemNotificationAction {

    /**
     * Identifies the action in `SystemNotificationResponse.actionId` when
     * the user presses this button.
     */
    public var id:String;

    /** The button's user-visible label. */
    public var label:String;

    public function new(id:String, label:String) {
        this.id = id;
        this.label = label;
    }

    /** Rust `#[derive(PartialEq)]`. */
    public function equals(other:SystemNotificationAction):Bool {
        return other != null && id == other.id && label == other.label;
    }

    /** Rust `#[derive(Clone)]`. */
    public function clone():SystemNotificationAction {
        return new SystemNotificationAction(id, label);
    }

    public function toString():String {
        return 'SystemNotificationAction { id: $id, label: $label }';
    }

}
