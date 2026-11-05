package ceramic;

/**
 * A button offered on a system notification (see `NotificationOptions.actions`).
 */
typedef NotificationAction = {

    /**
     * Identifies the action: the `actionId` of the `response` event when the
     * user presses this button.
     */
    var id:String;

    /**
     * The label of the button.
     */
    var label:String;

}
