package ceramic;

/**
 * Whether the application may post system notifications
 * (see `Notifications.authorization`).
 */
enum abstract NotificationAuthorization(Int) from Int to Int {

    /**
     * System notifications cannot be posted here: no notification support on
     * this platform or backend, a macOS app not running from an app bundle,
     * no notification service reachable on Linux, a browser without the
     * Notification API.
     */
    var UNAVAILABLE = 0;

    /**
     * The user was not asked yet (or the answer was not read yet): call
     * `Notifications.requestAuthorization`.
     */
    var NOT_DETERMINED = 1;

    /**
     * The user refused system notifications for this application, or turned
     * them off in the system settings. Posts are dropped by the system.
     */
    var DENIED = 2;

    /**
     * Notifications can be posted (also the answer where the platform does not
     * ask the user: Linux, Windows).
     */
    var AUTHORIZED = 3;

    /**
     * Whether notifications can be posted.
     */
    public inline function isAuthorized():Bool {

        return this == AUTHORIZED;

    }

    public function toString():String {

        return switch (this) {
            case UNAVAILABLE: 'UNAVAILABLE';
            case NOT_DETERMINED: 'NOT_DETERMINED';
            case DENIED: 'DENIED';
            case AUTHORIZED: 'AUTHORIZED';
            default: 'UNAVAILABLE';
        }

    }

}
