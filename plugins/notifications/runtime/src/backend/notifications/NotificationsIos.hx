package backend.notifications;

/**
 * System notifications on iOS: not available yet (every call does nothing).
 *
 * Planned: the same `UNUserNotificationCenter` code as macOS
 * (`notifications/linc/linc_notifications_apple.mm`, compiled for iOS with
 * the UserNotifications framework; the parts that differ are guarded with
 * `TARGET_OS_IOS`), through `NotificationsApple`. The API needs no change:
 * iOS asks the user like macOS (`requestAuthorization`), and the delegate
 * must be installed before the app finishes launching to get the response
 * that launched it.
 */
class NotificationsIos extends NotificationsNone {}
