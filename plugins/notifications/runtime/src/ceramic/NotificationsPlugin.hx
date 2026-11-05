package ceramic;

/**
 * Plugin initialization for system notifications.
 *
 * The plugin gives Ceramic applications the system's notification center
 * (`Notifications.shared`): posting, replacing and dismissing notifications
 * with action buttons, the user's response, and the authorization. Add it to
 * the project's ceramic.yml:
 * ```yaml
 * plugins:
 *   - notifications
 * ```
 *
 * Nothing touches the system until the application uses the API.
 *
 * @see Notifications
 */
@:access(ceramic.App)
class NotificationsPlugin {

    /**
     * Static initializer called when the plugin loads.
     */
    static function __init__():Void {

        // Calling a static method inside __init__ makes this snippet
        // compatible with haxe-modular or similar bundling tools
        NotificationsPlugin.pluginInit();

    }

    /**
     * Nothing to set up: `Notifications.shared` starts the platform's
     * notification center lazily.
     */
    static function pluginInit() {

        //

    }

}
