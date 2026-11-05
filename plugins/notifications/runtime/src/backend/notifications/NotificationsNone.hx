package backend.notifications;

import ceramic.NotificationAuthorization;
import ceramic.NotificationOptions;

/**
 * System notifications where the platform has none (Unity for now, or a
 * backend without support): unavailable, every call does nothing.
 */
class NotificationsNone implements spec.Notifications {

    public function new() {}

    public function isAvailable():Bool {

        return false;

    }

    public function setAppIdentity(identifier:String, name:String):Void {}

    public function start(handleResponse:(tag:String, actionId:Null<String>) -> Void, handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void):Bool {

        return false;

    }

    public function readAuthorization():Void {}

    public function requestAuthorization():Void {}

    public function show(options:NotificationOptions):Void {}

    public function dismiss(tag:String):Void {}

    public function poll():Void {}

}
