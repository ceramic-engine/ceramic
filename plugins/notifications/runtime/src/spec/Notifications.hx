package spec;

import ceramic.NotificationAuthorization;
import ceramic.NotificationOptions;

/**
 * Backend interface of system notifications (`ceramic.Notifications`).
 *
 * Every method is called on the main thread. The backend reports responses
 * and authorization answers through the handlers given to `start`, from the
 * main thread (from `poll`, or from an event of the platform's main loop):
 * `ceramic.Notifications` queues them and emits its events at the start of
 * the next frame.
 */
interface Notifications {

    /**
     * Whether system notifications can be posted on this platform, as far as
     * it is known without starting the notification center (a macOS app runs
     * from an app bundle, a browser has the Notification API...).
     */
    function isAvailable():Bool;

    /**
     * The identity of the application: the Windows AppUserModelID, the
     * application name shown by the Linux notification service.
     */
    function setAppIdentity(identifier:String, name:String):Void;

    /**
     * Starts the notification center (once, lazily): installs what delivers
     * the responses. Returns false when notifications are unavailable.
     */
    function start(handleResponse:(tag:String, actionId:Null<String>) -> Void, handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void):Bool;

    /**
     * Reads the authorization without asking the user: `handleAuthorization`
     * gets it later with `requested` false.
     */
    function readAuthorization():Void;

    /**
     * Asks the user (when not asked yet): `handleAuthorization` gets the
     * answer later with `requested` true.
     */
    function requestAuthorization():Void;

    /**
     * Posts a notification, replacing the one with the same tag.
     */
    function show(options:NotificationOptions):Void;

    /**
     * Removes the delivered or pending notification with this tag.
     */
    function dismiss(tag:String):Void;

    /**
     * Called at the start of every frame once started: reports what the
     * platform delivered since the previous frame.
     */
    function poll():Void;

}
