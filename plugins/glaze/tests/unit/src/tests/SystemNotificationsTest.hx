// Ported from gpui-pre 0.3.10: src/app/test_context.rs (tests of the system
// notifications on the test platform)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.SystemNotification;
import gpui.SystemNotificationAction;
import gpui.SystemNotificationResponse;
import gpui.TestDispatcher;
import gpui.TestPlatformOperations;
import gpui.platform.CeramicPlatformOperations;
import testing.TestCase;

/**
 * System notifications (`App.setAppIdentity`, `showSystemNotification`,
 * `dismissSystemNotification`, `onSystemNotificationResponse`): GPUI's tests
 * on the test platform (`TestPlatformOperations`), then the Ceramic platform
 * through the `notifications` plugin: its recording backend in headless
 * builds, and natively on macOS the real notification center of the hidden
 * test app (never posting a notification nor asking the user).
 */
class SystemNotificationsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

/// test_context.rs

    function notification(tag:String, title:String, body:String, ?actions:Array<SystemNotificationAction>):SystemNotification {
        return new SystemNotification(tag, title, body, actions);
    }

    function testSystemNotificationsRequireIdentityAndReplaceMatchingTags() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;

        app.update(cx -> cx.showSystemNotification(notification('thread-1', 'Task started', 'Running tests')));
        assertEquals(0, platform.shownSystemNotifications.length);
        assertEquals(0, platform.deliveredSystemNotifications.length);

        app.update(cx -> {
            cx.setAppIdentity('com.example.tasks', 'Tasks');
            cx.showSystemNotification(notification('thread-1', 'Task started', 'Running tests'));
            cx.showSystemNotification(notification('thread-1', 'Task finished', 'All tests passed', [new SystemNotificationAction('open', 'Open')]));
        });

        assertEquals('com.example.tasks', platform.appIdentity.identifier);
        assertEquals('Tasks', platform.appIdentity.name);
        assertEquals(2, platform.shownSystemNotifications.length);
        assertEquals(1, platform.deliveredSystemNotifications.length);
        assertTrue(platform.deliveredSystemNotifications[0].equals(notification('thread-1', 'Task finished', 'All tests passed', [new SystemNotificationAction('open', 'Open')])));

        app.update(cx -> cx.dismissSystemNotification('thread-1'));
        assertEquals(0, platform.deliveredSystemNotifications.length);
        assertEquals('thread-1', platform.dismissedSystemNotifications.join(','));
    }

    function testSystemNotificationBodyAndActionResponses() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        final responses:Array<SystemNotificationResponse> = [];
        app.update(cx -> cx.onSystemNotificationResponse((response, _) -> responses.push(response)));

        platform.simulateSystemNotificationResponse(new SystemNotificationResponse('thread-1', null));
        platform.simulateSystemNotificationResponse(new SystemNotificationResponse('thread-1', 'default'));

        assertEquals(2, responses.length);
        assertTrue(responses[0].equals(new SystemNotificationResponse('thread-1', null)));
        assertTrue(responses[1].equals(new SystemNotificationResponse('thread-1', 'default')));
    }

    function testSystemNotificationResponseHandlerCanBeReplaced() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        final firstResponses:Array<SystemNotificationResponse> = [];
        final secondResponses:Array<SystemNotificationResponse> = [];
        app.update(cx -> {
            cx.onSystemNotificationResponse((response, _) -> firstResponses.push(response));
            cx.onSystemNotificationResponse((response, _) -> secondResponses.push(response));
        });

        final response = new SystemNotificationResponse('thread-1', null);
        platform.simulateSystemNotificationResponse(response.clone());

        assertEquals(0, firstResponses.length);
        assertEquals(1, secondResponses.length);
        assertTrue(secondResponses[0].equals(response));
    }

    function testSystemNotificationResponseHandlerCanReenterApp() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        app.update(cx -> {
            cx.setAppIdentity('com.example.tasks', 'Tasks');
            cx.showSystemNotification(notification('thread-1', 'Task finished', 'All tests passed'));
            cx.onSystemNotificationResponse((response, cx) -> cx.dismissSystemNotification(response.tag));
        });

        platform.simulateSystemNotificationResponse(new SystemNotificationResponse('thread-1', null));

        assertEquals(0, platform.deliveredSystemNotifications.length);
        assertEquals('thread-1', platform.dismissedSystemNotifications.join(','));
    }

    /** A handler that registers another one during the call keeps the new one (port check). */
    function testSystemNotificationResponseHandlerCanReplaceItselfDuringTheCall() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        final calls:Array<String> = [];
        app.update(cx -> cx.onSystemNotificationResponse((response, cx) -> {
            calls.push('first ' + response.tag);
            cx.onSystemNotificationResponse((response, _) -> calls.push('second ' + response.tag));
        }));

        platform.simulateSystemNotificationResponse(new SystemNotificationResponse('a', null));
        platform.simulateSystemNotificationResponse(new SystemNotificationResponse('b', null));

        assertEquals('first a,second b', calls.join(','));
    }

/// Ceramic platform (notifications plugin)

    #if plugin_notifications

    /** Runs what the plugin queued, like the start of a frame. */
    static function flushNotifications():Void {
        @:privateAccess ceramic.Notifications.shared.flush();
        ceramic.App.app.flushImmediate();
    }

    #if headless

    function headlessBackend():backend.notifications.NotificationsHeadless {
        final backend = ceramic.Notifications.shared.backend;
        backend.clear();
        backend.authorization = NOT_DETERMINED;
        backend.authorizationAnswer = AUTHORIZED;
        flushNotifications();
        @:privateAccess CeramicPlatformOperations.authorizationRequested = false;
        @:privateAccess CeramicPlatformOperations.postsAwaitingAuthorization = null;
        return backend;
    }

    function testCeramicOperationsAskOnceThenPost() {
        final backend = headlessBackend();
        final requestsBefore = backend.authorizationRequests;
        assertTrue(Std.isOfType(app.platformOperations, CeramicPlatformOperations));

        app.update(cx -> {
            cx.setAppIdentity('com.example.tasks', 'Tasks');
            cx.showSystemNotification(notification('thread-1', 'Task started', 'Running tests'));
            cx.showSystemNotification(notification('thread-1', 'Task finished', 'All tests passed', [new SystemNotificationAction('open', 'Open')]));
        });
        assertEquals('com.example.tasks', backend.identity.identifier);
        assertEquals('Tasks', ceramic.Notifications.shared.appName);
        // The first post asks the user; the posts wait for the answer
        assertEquals(requestsBefore + 1, backend.authorizationRequests);
        assertEquals(0, backend.shown.length);

        flushNotifications();
        assertEquals('thread-1:Task started,thread-1:Task finished', [for (n in backend.shown) n.tag + ':' + n.title].join(','));
        assertEquals(1, backend.delivered.length);
        assertEquals('open:Open', backend.delivered[0].actions[0].id + ':' + backend.delivered[0].actions[0].label);
        assertEquals('All tests passed', backend.delivered[0].body);

        // Asked once: later posts go straight to the center
        app.update(cx -> cx.showSystemNotification(notification('thread-2', 'Other', '')));
        assertEquals(3, backend.shown.length);
        assertEquals(requestsBefore + 1, backend.authorizationRequests);

        app.update(cx -> cx.dismissSystemNotification('thread-1'));
        assertEquals('thread-1', backend.dismissed.join(','));
        assertEquals('thread-2', [for (n in backend.delivered) n.tag].join(','));
    }

    function testCeramicOperationsDismissWhileAwaitingTheAnswer() {
        final backend = headlessBackend();
        app.update(cx -> {
            cx.showSystemNotification(notification('a', 'A', ''));
            cx.showSystemNotification(notification('b', 'B', ''));
            cx.dismissSystemNotification('a');
        });
        flushNotifications();
        assertEquals('b', [for (n in backend.shown) n.tag].join(','));
        assertEquals('a', backend.dismissed.join(','));
    }

    function testCeramicOperationsHandOverPostsWhenDenied() {
        final backend = headlessBackend();
        backend.authorizationAnswer = DENIED;
        app.update(cx -> cx.showSystemNotification(notification('a', 'A', '')));
        flushNotifications();
        // The system drops posts of a denied app: the platform still hands them over
        assertEquals(ceramic.NotificationAuthorization.DENIED, ceramic.Notifications.shared.authorization);
        assertEquals('a', [for (n in backend.shown) n.tag].join(','));
    }

    function testCeramicOperationsRouteResponsesToTheLastRegisteredCallback() {
        final backend = headlessBackend();
        final otherApp = new App(new TestDispatcher());
        final calls:Array<String> = [];
        app.update(cx -> cx.onSystemNotificationResponse((response, cx) -> calls.push('first ' + response.tag + ' ' + response.actionId + ' ' + (cx == app))));
        otherApp.update(cx -> cx.onSystemNotificationResponse((response, cx) -> calls.push('second ' + response.tag + ' ' + response.actionId + ' ' + (cx == otherApp))));

        backend.simulateResponse('thread-1', null);
        backend.simulateResponse('thread-1', 'open');
        // Delivered at the start of a frame, not during the call
        assertEquals('', calls.join(','));
        flushNotifications();
        assertEquals('second thread-1 null true,second thread-1 open true', calls.join(','));

        app.update(cx -> cx.onSystemNotificationResponse((response, cx) -> calls.push('again ' + response.tag)));
        backend.simulateResponse('thread-2', null);
        flushNotifications();
        assertEquals('again thread-2', calls[calls.length - 1]);
    }

    #end

    #if (clay && cpp && mac && !ios)

    /**
     * The real notification center of the hidden test app (its bundle
     * identifier is `mycompany.unit`): started by a response listener,
     * authorization read without asking, a request built (its category
     * registered) but never posted, and a response queued natively that
     * reaches the GPUI callback at the start of a frame.
     */
    function testNativeNotificationCenter() {
        final calls:Array<String> = [];
        app.update(cx -> cx.onSystemNotificationResponse((response, _) -> calls.push(response.tag + ':' + response.actionId)));

        assertTrue(ceramic.Notifications.shared.isAvailable());
        final described = notifications.linc.LincNotifications.describe();
        assertTrue(StringTools.startsWith(described, 'bundle=mycompany.unit started=1 center=1 delegate=1'), described);

        final authorization = notifications.linc.LincNotifications.readAuthorizationNow(5000);
        assertTrue(authorization >= 1 && authorization <= 3, 'authorization $authorization');

        final request = notifications.linc.LincNotifications.describeRequest('unit-tag', 'Title', 'Body', ['open'], ['Open']);
        assertTrue(StringTools.startsWith(request, 'id=unit-tag title=Title body=Body category=ceramic-notification-') && StringTools.endsWith(request, ' trigger=nil'), request);

        notifications.linc.LincNotifications.simulateResponse('unit-tag', null);
        notifications.linc.LincNotifications.simulateResponse('unit-tag', 'open');
        assertEquals('', calls.join(','));
        flushNotifications();
        assertEquals('unit-tag:null,unit-tag:open', calls.join(','));
    }

    #end

    #end

}
