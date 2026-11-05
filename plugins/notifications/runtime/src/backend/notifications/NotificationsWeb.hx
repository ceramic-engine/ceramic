package backend.notifications;

import ceramic.NotificationAuthorization;
import ceramic.NotificationOptions;

/**
 * System notifications in a browser (clay web, also Electron's renderer):
 * the Notification API.
 *
 * - The permission (`Notification.permission`) is the authorization;
 *   `requestAuthorization` calls `Notification.requestPermission()`, which
 *   browsers only honor during a user gesture (a click, a tap or a key
 *   press): call it from the handler of such an event. Outside of one,
 *   browsers deny it at once or show no prompt, and the answer stays
 *   `NOT_DETERMINED` or becomes `DENIED`.
 * - The tag of the notification is the Notification API tag: the browser
 *   replaces a notification with the same tag. `dismiss` closes it.
 * - Action buttons need a service worker (`ServiceWorkerRegistration.showNotification`
 *   and its `notificationclick` event), which a plain page does not have:
 *   the notification shows without them, and a click on it is the
 *   response, with a null action id (the page also gets the focus).
 */
class NotificationsWeb implements spec.Notifications {

    var handleResponse:(tag:String, actionId:Null<String>) -> Void = null;

    var handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void = null;

    final shown:Map<String, Dynamic> = new Map();

    public function new() {}

    public function isAvailable():Bool {

        return js.Syntax.code("typeof Notification !== 'undefined'");

    }

    public function setAppIdentity(identifier:String, name:String):Void {

        // A page has no identity of its own: the browser shows its origin

    }

    public function start(handleResponse:(tag:String, actionId:Null<String>) -> Void, handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void):Bool {

        this.handleResponse = handleResponse;
        this.handleAuthorization = handleAuthorization;
        return isAvailable();

    }

    static function currentAuthorization():NotificationAuthorization {

        final permission:String = js.Syntax.code("Notification.permission");
        return switch permission {
            case 'granted': AUTHORIZED;
            case 'denied': DENIED;
            default: NOT_DETERMINED;
        }

    }

    public function readAuthorization():Void {

        handleAuthorization(currentAuthorization(), false);

    }

    public function requestAuthorization():Void {

        if (currentAuthorization() != NOT_DETERMINED) {
            handleAuthorization(currentAuthorization(), true);
            return;
        }

        var answered = false;
        final answer = (_:Dynamic) -> {
            if (answered) return;
            answered = true;
            handleAuthorization(currentAuthorization(), true);
        };
        try {
            // Older Safari takes a callback and returns nothing
            final promise:Dynamic = js.Syntax.code("Notification.requestPermission({0})", answer);
            if (promise != null && js.Syntax.code("typeof {0}.then === 'function'", promise)) {
                js.Syntax.code("{0}.then({1}, {1})", promise, answer);
            }
        }
        catch (e:Dynamic) {
            answer(null);
        }

    }

    public function show(options:NotificationOptions):Void {

        if (currentAuthorization() != AUTHORIZED) return;

        final tag = options.tag;
        final previous = shown.get(tag);
        if (previous != null) {
            previous.onclick = null;
            previous.onclose = null;
        }

        var notification:Dynamic = null;
        try {
            notification = js.Syntax.code("new Notification({0}, { body: {1}, tag: {2} })", options.title != null ? options.title : '', options.body != null ? options.body : '', tag);
        }
        catch (e:Dynamic) {
            // Some mobile browsers only allow notifications from a service worker
            ceramic.Shortcuts.log.warning('Failed to show system notification: $e');
            return;
        }
        shown.set(tag, notification);

        notification.onclick = (event:Dynamic) -> {
            try {
                js.Syntax.code("window.focus()");
            }
            catch (e:Dynamic) {}
            notification.close();
            if (handleResponse != null) handleResponse(tag, null);
        };
        notification.onclose = (_:Dynamic) -> {
            if (shown.get(tag) == notification) shown.remove(tag);
        };

    }

    public function dismiss(tag:String):Void {

        final notification = shown.get(tag);
        if (notification != null) {
            shown.remove(tag);
            notification.onclick = null;
            notification.onclose = null;
            notification.close();
        }

    }

    public function poll():Void {}

}
