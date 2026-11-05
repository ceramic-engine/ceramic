package backend.notifications;

/**
 * System notifications on Android: not available yet (every call does
 * nothing).
 *
 * Planned, through JNI (like the other Android services of Ceramic):
 * `NotificationManager` with a notification channel named after
 * `setAppIdentity` (Android 8 and later need one), `NotificationCompat`
 * builders with `addAction` for the buttons, `notify(tag, 0, ...)` and
 * `cancel(tag, 0)` for the tag, `PendingIntent`s to the activity carrying
 * the tag and the action id (the response, read when the activity gets the
 * intent), and the `POST_NOTIFICATIONS` runtime permission on Android 13
 * and later (`requestAuthorization`: `requestPermissions`, the answer from
 * `onRequestPermissionsResult`; earlier versions answer `AUTHORIZED`, or
 * `DENIED` when `areNotificationsEnabled` is false). The API needs no
 * change.
 */
class NotificationsAndroid extends NotificationsNone {}
