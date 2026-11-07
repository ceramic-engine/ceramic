// Ported from gpui-pre 0.3.10: src/platform.rs (SystemNotificationResponse)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The user's activation of a `SystemNotification`.
 */
class SystemNotificationResponse {

    /** The `SystemNotification.tag` of the activated notification. */
    public var tag:String;

    /**
     * The pressed action button's `SystemNotificationAction.id`, or `null`
     * when the user activated the notification body itself.
     */
    public var actionId:Null<String>;

    public function new(tag:String, ?actionId:String) {
        this.tag = tag;
        this.actionId = actionId;
    }

    /** Rust `#[derive(PartialEq)]`. */
    public function equals(other:SystemNotificationResponse):Bool {
        return other != null && tag == other.tag && actionId == other.actionId;
    }

    /** Rust `#[derive(Clone)]`. */
    public function clone():SystemNotificationResponse {
        return new SystemNotificationResponse(tag, actionId);
    }

    public function toString():String {
        return 'SystemNotificationResponse { tag: $tag, actionId: $actionId }';
    }

}
