package backend.notifications;

import ceramic.NotificationAuthorization;
import ceramic.NotificationOptions;

/**
 * System notifications of the headless backend: nothing reaches a system.
 * The calls are recorded and tests answer like the user would
 * (`simulateResponse`, `authorizationAnswer`).
 */
class NotificationsHeadless implements spec.Notifications {

    /**
     * Every notification shown, in order.
     */
    public final shown:Array<NotificationOptions> = [];

    /**
     * The notifications currently delivered (a notification shown again with
     * the same tag replaces the previous one at its place; dismissed ones are
     * removed).
     */
    public final delivered:Array<NotificationOptions> = [];

    /**
     * The tags given to `dismiss`, in order.
     */
    public final dismissed:Array<String> = [];

    /**
     * The identity given to `setAppIdentity`.
     */
    public var identity(default, null):Null<{identifier:String, name:String}> = null;

    /**
     * What a read answers until the user was asked.
     */
    public var authorization:NotificationAuthorization = NOT_DETERMINED;

    /**
     * What the user answers to `requestAuthorization` (`AUTHORIZED` unless a
     * test changes it); `authorization` then keeps it.
     */
    public var authorizationAnswer:NotificationAuthorization = AUTHORIZED;

    /**
     * How many times the user was asked.
     */
    public var authorizationRequests(default, null):Int = 0;

    /**
     * Whether the notification center was started.
     */
    public var started(default, null):Bool = false;

    var handleResponse:(tag:String, actionId:Null<String>) -> Void = null;

    var handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void = null;

    final pending:Array<() -> Void> = [];

    public function new() {}

    public function isAvailable():Bool {

        return true;

    }

    public function setAppIdentity(identifier:String, name:String):Void {

        identity = { identifier: identifier, name: name };

    }

    public function start(handleResponse:(tag:String, actionId:Null<String>) -> Void, handleAuthorization:(authorization:NotificationAuthorization, requested:Bool) -> Void):Bool {

        this.handleResponse = handleResponse;
        this.handleAuthorization = handleAuthorization;
        started = true;
        return true;

    }

    public function readAuthorization():Void {

        final value = authorization;
        pending.push(() -> handleAuthorization(value, false));

    }

    public function requestAuthorization():Void {

        if (authorization == NOT_DETERMINED) {
            authorizationRequests++;
            authorization = authorizationAnswer;
        }
        final value = authorization;
        pending.push(() -> handleAuthorization(value, true));

    }

    public function show(options:NotificationOptions):Void {

        final copy = copyOptions(options);
        shown.push(copy);
        for (i in 0...delivered.length) {
            if (delivered[i].tag == copy.tag) {
                delivered[i] = copy;
                return;
            }
        }
        delivered.push(copy);

    }

    public function dismiss(tag:String):Void {

        var i = delivered.length - 1;
        while (i >= 0) {
            if (delivered[i].tag == tag) delivered.splice(i, 1);
            i--;
        }
        dismissed.push(tag);

    }

    /**
     * The user activates a notification: its body (`actionId` null) or an
     * action button. The `response` event is emitted at the start of the next
     * frame, like on a platform (also for a tag that was never shown: a
     * platform can deliver a response for a notification posted by an
     * earlier run).
     */
    public function simulateResponse(tag:String, actionId:Null<String>):Void {

        pending.push(() -> {
            if (handleResponse != null) handleResponse(tag, actionId);
        });

    }

    /**
     * Forgets the recorded calls (not the identity nor the authorization).
     */
    public function clear():Void {

        shown.resize(0);
        delivered.resize(0);
        dismissed.resize(0);

    }

    public function poll():Void {

        while (pending.length > 0) {
            pending.shift()();
        }

    }

    static function copyOptions(options:NotificationOptions):NotificationOptions {

        return {
            tag: options.tag,
            title: options.title,
            body: options.body != null ? options.body : '',
            actions: options.actions != null ? [for (action in options.actions) { id: action.id, label: action.label }] : []
        };

    }

}
