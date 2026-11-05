// Ported from gpui-pre 0.3.10: src/platform.rs (SystemNotification)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A notification posted to the operating system's notification center,
 * rather than rendered as in-app UI (`App.showSystemNotification`).
 */
class SystemNotification {

    /**
     * Stable identity for the notification. Posting a new notification with
     * the same tag replaces the previous one where the platform supports it,
     * and responses carry the tag back to the application.
     */
    public var tag:String;

    /** The notification's headline. */
    public var title:String;

    /** Additional text displayed below the title. */
    public var body:String;

    /**
     * Buttons offered on the notification. Platforms that cannot display
     * action buttons show the notification without them.
     */
    public var actions:Array<SystemNotificationAction>;

    public function new(tag:String, title:String, body:String = '', ?actions:Array<SystemNotificationAction>) {
        this.tag = tag;
        this.title = title;
        this.body = body;
        this.actions = actions != null ? actions : [];
    }

    /** Rust `#[derive(PartialEq)]`. */
    public function equals(other:SystemNotification):Bool {
        if (other == null || tag != other.tag || title != other.title || body != other.body || actions.length != other.actions.length)
            return false;
        for (i in 0...actions.length) {
            if (!actions[i].equals(other.actions[i]))
                return false;
        }
        return true;
    }

    /** Rust `#[derive(Clone)]`. */
    public function clone():SystemNotification {
        return new SystemNotification(tag, title, body, [for (action in actions) action.clone()]);
    }

    public function toString():String {
        return 'SystemNotification { tag: $tag, title: $title, body: $body, actions: ${actions.join(', ')} }';
    }

}
