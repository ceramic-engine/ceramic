package ceramic;

import ceramic.Shortcuts.*;

#if (clay && cpp && ios)
typedef NotificationsBackend = backend.notifications.NotificationsIos;
#elseif (clay && cpp && android)
typedef NotificationsBackend = backend.notifications.NotificationsAndroid;
#elseif (clay && cpp && (mac || linux || windows))
typedef NotificationsBackend = backend.notifications.NotificationsNative;
#elseif headless
typedef NotificationsBackend = backend.notifications.NotificationsHeadless;
#elseif (clay && web)
typedef NotificationsBackend = backend.notifications.NotificationsWeb;
#else
typedef NotificationsBackend = backend.notifications.NotificationsNone;
#end

/**
 * System notifications: notifications posted to the operating system's
 * notification center, outside of the app window, with action buttons and
 * the user's response. Generic for any Ceramic app (plugin `notifications`).
 *
 * ```haxe
 * final notifications = Notifications.shared;
 * notifications.setAppIdentity('com.example.tasks', 'Tasks');
 * notifications.onResponse(this, (tag, actionId) -> {
 *     // actionId is null when the body of the notification was clicked
 * });
 * notifications.requestAuthorization(authorization -> {
 *     if (authorization.isAuthorized()) {
 *         notifications.show({
 *             tag: 'build',
 *             title: 'Build finished',
 *             body: 'All tests passed',
 *             actions: [{ id: 'open', label: 'Open' }]
 *         });
 *     }
 * });
 * ```
 *
 * Nothing touches the system until the API is used: the notification center
 * starts on the first `show`, `dismiss`, authorization call or `response`
 * listener. Responses and authorization changes are emitted on the main
 * thread, at the start of a frame (before the update).
 *
 * Platforms:
 *
 * - **macOS** (clay native): `UNUserNotificationCenter`. The app must run
 *   from a signed app bundle with a bundle identifier (`ceramic clay build
 *   mac` makes one, signed ad hoc unless `CERAMIC_MAC_CODESIGN_IDENTITY` is
 *   set, with the `app.package` of ceramic.yml as bundle identifier):
 *   otherwise `authorization` is `UNAVAILABLE` and nothing is posted. macOS
 *   asks the user once, on `requestAuthorization`. Action buttons are
 *   notification categories. Notifications also show while the app is in
 *   the foreground. `setAppIdentity` changes nothing: macOS uses the bundle
 *   identifier and name.
 * - **Linux** (clay native): the `org.freedesktop.Notifications` service
 *   over the session DBus (libdbus loaded at run time: no dependency at
 *   build time, `UNAVAILABLE` without it or without a notification
 *   service). The name given to `setAppIdentity` is the application name
 *   shown, the identifier the `desktop-entry` hint. Never asks the user.
 * - **Windows** (clay native, untested so far): toasts through WinRT's
 *   `ToastNotificationManager`, with the identifier given to
 *   `setAppIdentity` as AppUserModelID; an unpackaged app gets a Start menu
 *   shortcut carrying that id (Windows only shows toasts of apps it knows).
 *   Call `setAppIdentity` early, before anything else.
 * - **Web** (clay web): the browser's Notification API. Browsers only ask
 *   the user from a user gesture: call `requestAuthorization` from a click
 *   or key handler. Outside of a gesture, while the permission is not
 *   determined, the browser is not asked and the answer is `NOT_DETERMINED`
 *   (where the browser has `navigator.userActivation`). A plain page has no
 *   action buttons (they need a service worker): a click on the
 *   notification is the response, with a null action id.
 * - **Headless**: nothing reaches a system; the backend records the calls
 *   (`backend.shown`, `delivered`, `dismissed`) and tests emit responses
 *   (`backend.simulateResponse`).
 * - **iOS**, **Android**, **Unity**: not available yet (`UNAVAILABLE`, calls
 *   do nothing). iOS will share the macOS implementation
 *   (`UNUserNotificationCenter`), Android will use `NotificationManager`
 *   with a channel and the `POST_NOTIFICATIONS` permission.
 */
class Notifications extends Entity {

    /**
     * The notification center of the application.
     */
    @lazy public static var shared = new Notifications();

    /**
     * The user activated a notification: its body (`actionId` null) or one
     * of its action buttons (`actionId` is the `NotificationAction.id`).
     * Emitted on the main thread at the start of a frame.
     */
    @event function response(tag:String, actionId:Null<String>);

    /**
     * `authorization` changed (an answer to `requestAuthorization`, or a
     * different value read by `readAuthorization`).
     */
    @event function authorizationChange(authorization:NotificationAuthorization);

    /**
     * The platform backend (the headless one records what is posted, for
     * tests).
     */
    public var backend(default, null):NotificationsBackend;

    /**
     * What is known of the authorization: `NOT_DETERMINED` until it was read
     * (`readAuthorization`) or asked (`requestAuthorization`) where the
     * platform asks the user, `UNAVAILABLE` where nothing can be posted.
     */
    public var authorization(default, null):NotificationAuthorization;

    /**
     * The identifier given to `setAppIdentity`, if any.
     */
    public var appIdentifier(default, null):Null<String> = null;

    /**
     * The name given to `setAppIdentity`, if any.
     */
    public var appName(default, null):Null<String> = null;

    var started:Bool = false;

    var startFailed:Bool = false;

    var pendingRequests:Array<(authorization:NotificationAuthorization) -> Void> = [];

    var pendingReads:Array<(authorization:NotificationAuthorization) -> Void> = [];

    var queue:Array<() -> Void> = [];

    private function new() {

        super();

        backend = new NotificationsBackend();
        authorization = backend.isAvailable() ? NOT_DETERMINED : UNAVAILABLE;

    }

    /**
     * Whether system notifications can be posted here (see the platforms in
     * the class description). False when `authorization` is `UNAVAILABLE`.
     */
    public function isAvailable():Bool {

        return authorization != UNAVAILABLE && backend.isAvailable();

    }

    /**
     * Sets the identity of the application: the Windows AppUserModelID and
     * the name shown by the system where the platform takes it from the app
     * (Linux, Windows). macOS and iOS use the bundle identifier and name
     * instead. Call it once, early in startup, before posting.
     */
    public function setAppIdentity(identifier:String, name:String):Void {

        appIdentifier = identifier;
        appName = name;
        backend.setAppIdentity(identifier, name);

    }

    /**
     * Posts a notification to the system's notification center. A
     * notification with the same `tag` replaces the previous one where the
     * platform supports it. Nothing is asked to the user: when
     * notifications are not authorized, the system drops it (call
     * `requestAuthorization` before).
     */
    public function show(notification:NotificationOptions):Void {

        if (notification == null || notification.tag == null) {
            log.warning('Notifications.show: a notification needs a tag');
            return;
        }
        if (!start()) return;
        backend.show(notification);

    }

    /**
     * Removes the delivered or pending notification with this tag, where
     * the platform can retract it.
     */
    public function dismiss(tag:String):Void {

        if (tag == null) return;
        if (!start()) return;
        backend.dismiss(tag);

    }

    /**
     * Asks the user whether the application may post notifications, where
     * the platform asks (macOS and iOS once per app, browsers from a user
     * gesture only, Android 13 and later). `done` gets the answer later
     * (never during this call), also when the user was asked before: then
     * the system answers without asking again. In a browser, outside of a
     * user gesture and while the permission is not determined, nobody is
     * asked and the answer is `NOT_DETERMINED`: call it again from a click
     * or key handler.
     */
    public function requestAuthorization(?done:(authorization:NotificationAuthorization) -> Void):Void {

        if (!start()) {
            if (done != null) app.onceImmediate(() -> done(UNAVAILABLE));
            return;
        }
        final first = pendingRequests.length == 0;
        pendingRequests.push(done);
        if (first) backend.requestAuthorization();

    }

    /**
     * Reads the authorization without asking the user (it may have changed
     * in the system settings). `done` gets it later (never during this call).
     */
    public function readAuthorization(?done:(authorization:NotificationAuthorization) -> Void):Void {

        if (!start()) {
            if (done != null) app.onceImmediate(() -> done(UNAVAILABLE));
            return;
        }
        final first = pendingReads.length == 0;
        pendingReads.push(done);
        if (first) backend.readAuthorization();

    }

    /**
     * Starts the notification center when a response listener is added, so
     * that responses get delivered.
     */
    function willListenResponse():Void {

        start();

    }

    function start():Bool {

        if (started) return true;
        if (startFailed) return false;

        if (!backend.isAvailable() || !backend.start(handleResponse, handleAuthorization)) {
            startFailed = true;
            setAuthorization(UNAVAILABLE);
            return false;
        }

        started = true;
        app.onPreUpdate(this, _ -> flush());
        return true;

    }

    function handleResponse(tag:String, actionId:Null<String>):Void {

        queue.push(() -> emitResponse(tag, actionId));

    }

    function handleAuthorization(authorization:NotificationAuthorization, requested:Bool):Void {

        queue.push(() -> {
            setAuthorization(authorization);
            final callbacks = requested ? pendingRequests : pendingReads;
            if (requested) pendingRequests = [];
            else pendingReads = [];
            for (callback in callbacks) {
                if (callback != null) callback(authorization);
            }
        });

    }

    function setAuthorization(value:NotificationAuthorization):Void {

        if (authorization != value) {
            authorization = value;
            emitAuthorizationChange(value);
        }

    }

    /**
     * Polls the backend and emits what it reported, in order (at the start
     * of every frame once started).
     */
    function flush():Void {

        backend.poll();
        while (queue.length > 0) {
            final callbacks = queue;
            queue = [];
            for (callback in callbacks) {
                callback();
            }
        }

    }

}
