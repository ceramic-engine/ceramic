// System notifications on macOS through UNUserNotificationCenter
// (UserNotifications framework). Written for iOS too: it builds there with
// the same framework once the plugin enables it (the parts that differ are
// guarded with TARGET_OS_IOS).
//
// Like GPUI's macOS platform (gpui-pre-macos 0.3.10, src/system_notifications.rs),
// nothing touches the notification center until it is started: the center
// raises NSInternalInconsistencyException ("bundleProxyForCurrentProcess is
// nil"), aborting the process, when the binary is not part of an app bundle,
// so a bundle identifier is required first. Action buttons are notification
// categories, shared by the notifications that have the same actions
// (setNotificationCategories replaces the whole registered set, so the union
// is registered each time). The request identifier is the tag: posting the
// same tag again replaces the notification. A delegate gets the responses
// (possibly on another thread: they go to the event queue) and lets
// notifications show while the app is in the foreground.

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#include <TargetConditionals.h>

#include "linc_notifications.h"

#include <map>
#include <vector>

#if __has_feature(objc_arc)
#define LINC_NOTIFICATIONS_RETAIN(x) (x)
#define LINC_NOTIFICATIONS_RELEASE(x)
#else
#define LINC_NOTIFICATIONS_RETAIN(x) [(x) retain]
#define LINC_NOTIFICATIONS_RELEASE(x) [(x) release]
#endif

static int lincNotificationsAuthorizationFromStatus(UNAuthorizationStatus status) {
    switch (status) {
        case UNAuthorizationStatusNotDetermined:
            return linc::notifications::AUTHORIZATION_NOT_DETERMINED;
        case UNAuthorizationStatusDenied:
            return linc::notifications::AUTHORIZATION_DENIED;
        default:
            // Authorized, provisional (and ephemeral on iOS) can post
            return linc::notifications::AUTHORIZATION_AUTHORIZED;
    }
}

@interface LincNotificationsDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation LincNotificationsDelegate

// The user activated a notification (its body or an action button)
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
    withCompletionHandler:(void (^)(void))completionHandler {

    NSString *tag = response.notification.request.identifier;
    NSString *action = response.actionIdentifier;
    std::string tagValue = tag != nil ? std::string([tag UTF8String]) : std::string();
    if (action == nil || [action isEqualToString:UNNotificationDefaultActionIdentifier]) {
        linc::notifications::pushResponse(tagValue, NULL);
    }
    else if ([action isEqualToString:UNNotificationDismissActionIdentifier]) {
        // Only delivered to categories asking for dismiss callbacks, never requested
    }
    else {
        std::string actionValue([action UTF8String]);
        linc::notifications::pushResponse(tagValue, &actionValue);
    }
    completionHandler();
}

// Without this, the system does not show notifications while the app is in
// the foreground. Posting is the application's decision (GPUI does the same).
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    willPresentNotification:(UNNotification *)notification
    withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {

    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList);
}

@end

static BOOL _lincNotificationsStarted = NO;
static UNUserNotificationCenter *_lincNotificationsCenter = nil;
static LincNotificationsDelegate *_lincNotificationsDelegate = nil;

// Registered categories: the actions (ids and labels) and the category
static std::vector< std::vector<std::string> > _lincNotificationsCategoryKeys;
static NSMutableArray *_lincNotificationsCategories = nil;

static NSString *lincNotificationsString(::String value) {
    if (value.__s == NULL) return @"";
    const char *utf8 = value.utf8_str();
    NSString *result = utf8 != NULL ? [NSString stringWithUTF8String:utf8] : nil;
    return result != nil ? result : @"";
}

static std::vector<std::string> lincNotificationsActionsKey(::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
    std::vector<std::string> key;
    int count = actionIds != null() ? actionIds->length : 0;
    for (int i = 0; i < count; i++) {
        key.push_back(linc::notifications::toStdString(actionIds[i]));
        key.push_back(actionLabels != null() && i < actionLabels->length ? linc::notifications::toStdString(actionLabels[i]) : std::string());
    }
    return key;
}

static UNNotificationCategory *lincNotificationsMakeCategory(NSString *identifier, const std::vector<std::string> &key) {
    NSMutableArray *actions = [NSMutableArray array];
    for (size_t i = 0; i + 1 < key.size(); i += 2) {
        NSString *actionId = [NSString stringWithUTF8String:key[i].c_str()];
        NSString *label = [NSString stringWithUTF8String:key[i + 1].c_str()];
        [actions addObject:[UNNotificationAction
            actionWithIdentifier:(actionId != nil ? actionId : @"")
            title:(label != nil ? label : @"")
            options:UNNotificationActionOptionNone]];
    }
    return [UNNotificationCategory
        categoryWithIdentifier:identifier
        actions:actions
        intentIdentifiers:@[]
        options:UNNotificationCategoryOptionNone];
}

// The category identifier of these actions, registering the category the
// first time (nil without actions)
static NSString *lincNotificationsCategoryFor(const std::vector<std::string> &key, BOOL registerCategory) {
    if (key.empty()) return nil;
    for (size_t i = 0; i < _lincNotificationsCategoryKeys.size(); i++) {
        if (_lincNotificationsCategoryKeys[i] == key) {
            return [NSString stringWithFormat:@"ceramic-notification-%d", (int)i];
        }
    }
    NSString *identifier = [NSString stringWithFormat:@"ceramic-notification-%d", (int)_lincNotificationsCategoryKeys.size()];
    if (!registerCategory) return identifier;
    _lincNotificationsCategoryKeys.push_back(key);
    if (_lincNotificationsCategories == nil) {
        _lincNotificationsCategories = LINC_NOTIFICATIONS_RETAIN([NSMutableArray array]);
    }
    [_lincNotificationsCategories addObject:lincNotificationsMakeCategory(identifier, key)];
    [_lincNotificationsCenter setNotificationCategories:[NSSet setWithArray:_lincNotificationsCategories]];
    return identifier;
}

static UNNotificationRequest *lincNotificationsMakeRequest(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels, BOOL registerCategory) {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = lincNotificationsString(title);
    content.body = lincNotificationsString(body);
    NSString *category = lincNotificationsCategoryFor(lincNotificationsActionsKey(actionIds, actionLabels), registerCategory);
    if (category != nil) {
        content.categoryIdentifier = category;
    }
    // A nil trigger delivers at once; the tag as identifier replaces the
    // notification posted earlier with the same tag
    UNNotificationRequest *request = [UNNotificationRequest
        requestWithIdentifier:lincNotificationsString(tag)
        content:content
        trigger:nil];
    LINC_NOTIFICATIONS_RELEASE(content);
    return request;
}

static void lincNotificationsReadSettings(bool requested) {
    [_lincNotificationsCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        linc::notifications::pushAuthorization(lincNotificationsAuthorizationFromStatus(settings.authorizationStatus), requested);
    }];
}

namespace linc {
    namespace notifications {

        bool available() {
            @autoreleasepool {
                return [[NSBundle mainBundle] bundleIdentifier] != nil;
            }
        }

        void setAppIdentity(::String identifier, ::String name) {
            // The bundle identifier and name are the identity on Apple platforms
        }

        bool start() {
            if (_lincNotificationsStarted) return _lincNotificationsCenter != nil;
            _lincNotificationsStarted = YES;
            @autoreleasepool {
                if ([[NSBundle mainBundle] bundleIdentifier] == nil) {
                    NSLog(@"System notifications disabled: not running from an app bundle");
                    return false;
                }
                _lincNotificationsCenter = LINC_NOTIFICATIONS_RETAIN([UNUserNotificationCenter currentNotificationCenter]);
                // The delegate property is weak: the delegate is kept here
                _lincNotificationsDelegate = [[LincNotificationsDelegate alloc] init];
                _lincNotificationsCenter.delegate = _lincNotificationsDelegate;
                return true;
            }
        }

        void readAuthorization() {
            if (!start()) {
                pushAuthorization(AUTHORIZATION_UNAVAILABLE, false);
                return;
            }
            @autoreleasepool {
                lincNotificationsReadSettings(false);
            }
        }

        void requestAuthorization() {
            if (!start()) {
                pushAuthorization(AUTHORIZATION_UNAVAILABLE, true);
                return;
            }
            @autoreleasepool {
                // Alert and sound, like GPUI. The system asks the user only once;
                // the answer is read from the settings afterwards
                [_lincNotificationsCenter
                    requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                    completionHandler:^(BOOL granted, NSError *error) {
                        if (error != nil) {
                            NSLog(@"System notification authorization failed: %@", error.localizedDescription);
                        }
                        lincNotificationsReadSettings(true);
                    }];
            }
        }

        void show(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
            if (!start()) return;
            @autoreleasepool {
                UNNotificationRequest *request = lincNotificationsMakeRequest(tag, title, body, actionIds, actionLabels, YES);
                [_lincNotificationsCenter addNotificationRequest:request withCompletionHandler:^(NSError *error) {
                    if (error != nil) {
                        NSLog(@"Failed to deliver system notification: %@", error.localizedDescription);
                    }
                }];
            }
        }

        void dismiss(::String tag) {
            if (!start()) return;
            @autoreleasepool {
                NSArray *identifiers = @[lincNotificationsString(tag)];
                [_lincNotificationsCenter removePendingNotificationRequestsWithIdentifiers:identifiers];
                [_lincNotificationsCenter removeDeliveredNotificationsWithIdentifiers:identifiers];
            }
        }

        void poll() {
            // Responses arrive through the delegate (event queue)
        }

        ::String describe() {
            @autoreleasepool {
                NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
                NSString *out = [NSString stringWithFormat:@"bundle=%@ started=%d center=%d delegate=%d categories=%d",
                    bundle != nil ? bundle : @"(none)",
                    _lincNotificationsStarted ? 1 : 0,
                    _lincNotificationsCenter != nil ? 1 : 0,
                    (_lincNotificationsCenter != nil && _lincNotificationsCenter.delegate == _lincNotificationsDelegate && _lincNotificationsDelegate != nil) ? 1 : 0,
                    (int)_lincNotificationsCategoryKeys.size()];
                return ::String::create([out UTF8String]);
            }
        }

        ::String describeRequest(::String tag, ::String title, ::String body, ::Array< ::String > actionIds, ::Array< ::String > actionLabels) {
            @autoreleasepool {
                // Built like show() builds it (registering its category), not posted
                if (!start()) return ::String::create("unavailable");
                UNNotificationRequest *request = lincNotificationsMakeRequest(tag, title, body, actionIds, actionLabels, YES);
                UNNotificationContent *content = request.content;
                NSString *out = [NSString stringWithFormat:@"id=%@ title=%@ body=%@ category=%@ trigger=%@",
                    request.identifier, content.title, content.body,
                    content.categoryIdentifier.length > 0 ? content.categoryIdentifier : @"(none)",
                    request.trigger != nil ? @"set" : @"nil"];
                return ::String::create([out UTF8String]);
            }
        }

        ::String describeCategories(int timeoutMs) {
            if (!start()) return ::String::create("unavailable");
            __block NSString *result = nil;
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            @autoreleasepool {
                [_lincNotificationsCenter getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *categories) {
                    NSArray *sorted = [[categories allObjects] sortedArrayUsingComparator:^NSComparisonResult(UNNotificationCategory *a, UNNotificationCategory *b) {
                        return [a.identifier compare:b.identifier];
                    }];
                    NSMutableArray *lines = [NSMutableArray array];
                    for (UNNotificationCategory *category in sorted) {
                        NSMutableArray *actions = [NSMutableArray array];
                        for (UNNotificationAction *action in category.actions) {
                            [actions addObject:[NSString stringWithFormat:@"%@:%@", action.identifier, action.title]];
                        }
                        [lines addObject:[NSString stringWithFormat:@"%@ [%@]", category.identifier, [actions componentsJoinedByString:@", "]]];
                    }
                    result = LINC_NOTIFICATIONS_RETAIN([lines componentsJoinedByString:@"\n"]);
                    dispatch_semaphore_signal(done);
                }];
            }
            // The completion runs on a queue of the framework, not the main thread
            if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeoutMs * NSEC_PER_MSEC)) != 0) {
                return ::String::create("timeout");
            }
            ::String out = ::String::create([result UTF8String]);
            LINC_NOTIFICATIONS_RELEASE(result);
            return out;
        }

        int readAuthorizationNow(int timeoutMs) {
            if (!start()) return AUTHORIZATION_UNAVAILABLE;
            __block int result = -1;
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            @autoreleasepool {
                [_lincNotificationsCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                    result = lincNotificationsAuthorizationFromStatus(settings.authorizationStatus);
                    dispatch_semaphore_signal(done);
                }];
            }
            if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeoutMs * NSEC_PER_MSEC)) != 0) {
                return -1;
            }
            return result;
        }

    }
}
