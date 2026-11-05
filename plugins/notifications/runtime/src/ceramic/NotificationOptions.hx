package ceramic;

/**
 * A notification posted to the system's notification center
 * (see `Notifications.show`).
 */
typedef NotificationOptions = {

    /**
     * Stable identity of the notification. Showing a notification with the
     * same tag again replaces the previous one where the platform supports
     * it, `Notifications.dismiss` takes it, and the `response` event gives
     * it back.
     */
    var tag:String;

    /**
     * The headline of the notification.
     */
    var title:String;

    /**
     * Text displayed below the title (none when null or empty).
     */
    @:optional var body:String;

    /**
     * Buttons offered on the notification. Platforms that cannot display
     * buttons show the notification without them (a plain web page, see
     * `Notifications`).
     */
    @:optional var actions:Array<NotificationAction>;

}
