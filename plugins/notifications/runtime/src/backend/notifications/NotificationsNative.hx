package backend.notifications;

import ceramic.NotificationAuthorization;
import ceramic.NotificationOptions;
import notifications.linc.LincNotifications;

/**
 * System notifications of clay native targets, implemented in C++ and
 * Objective-C (`notifications/linc`): macOS (`UNUserNotificationCenter`),
 * Linux (`org.freedesktop.Notifications` over DBus, libdbus loaded at run
 * time), Windows (WinRT toasts, untested). The native side queues what the
 * platform delivers, possibly from another thread; `poll` reads the queue on
 * the main thread at the start of a frame.
 */
class NotificationsNative implements spec.Notifications {

    var handleResponse:(tag:String, actionId:Null<String>) -> Void = null;

    var handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void = null;

    public function new() {}

    public function isAvailable():Bool {

        return LincNotifications.available();

    }

    public function setAppIdentity(identifier:String, name:String):Void {

        LincNotifications.setAppIdentity(identifier, name);

    }

    public function start(handleResponse:(tag:String, actionId:Null<String>) -> Void, handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void):Bool {

        this.handleResponse = handleResponse;
        this.handleAuthorization = handleAuthorization;
        return LincNotifications.start();

    }

    public function readAuthorization():Void {

        LincNotifications.readAuthorization();

    }

    public function requestAuthorization():Void {

        LincNotifications.requestAuthorization();

    }

    public function show(options:NotificationOptions):Void {

        final ids:Array<String> = [];
        final labels:Array<String> = [];
        if (options.actions != null) {
            for (action in options.actions) {
                ids.push(action.id != null ? action.id : '');
                labels.push(action.label != null ? action.label : '');
            }
        }
        LincNotifications.show(options.tag, options.title != null ? options.title : '', options.body != null ? options.body : '', ids, labels);

    }

    public function dismiss(tag:String):Void {

        LincNotifications.dismiss(tag);

    }

    public function poll():Void {

        LincNotifications.poll();
        while (true) {
            final kind = LincNotifications.nextEvent();
            switch kind {
                case 1:
                    if (handleResponse != null) handleResponse(LincNotifications.eventTag(), LincNotifications.eventActionId());
                case 2 | 3:
                    if (handleAuthorization != null) handleAuthorization(LincNotifications.eventAuthorization(), kind == 3);
                default:
                    return;
            }
        }

    }

}
