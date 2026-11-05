package;

import ceramic.App;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.NotificationAuthorization;
import ceramic.Notifications;

/**
 * Checks of the notifications plugin (see `check.sh`). Nothing is shown on
 * screen, no notification is posted and the user is never asked: headless
 * runs the API against the recording backend, macOS reads the real
 * notification center of the hidden app bundle.
 */
class Project extends Entity {

    var checks = 0;

    var failures = 0;

    var steps:Array<() -> Bool> = [];

    var stepFrames = 0;

    final responses:Array<String> = [];

    final authorizationChanges:Array<String> = [];

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 320;
        settings.targetHeight = 240;

        App.app.onceReady(this, ready);

    }

    function ready() {

        final notifications = Notifications.shared;
        notifications.onAuthorizationChange(this, authorization -> authorizationChanges.push(authorization.toString()));

        #if headless
        steps = headlessSteps();
        #elseif (clay && cpp && mac && !ios)
        steps = macSteps();
        #elseif (clay && web)
        webChecks();
        return;
        #else
        App.app.logger.info('notifications: nothing to run on this target (compile check)');
        return;
        #end

        App.app.onUpdate(this, _ -> runSteps());

    }

    function runSteps():Void {

        if (steps.length == 0) return;
        stepFrames++;
        if (stepFrames > 600) {
            fail('step timed out');
            steps.shift();
            stepFrames = 0;
        }
        else if (steps[0]()) {
            steps.shift();
            stepFrames = 0;
        }
        if (steps.length == 0) finish();

    }

    function finish():Void {

        App.app.logger.info('notifications: $checks checks, $failures failed');
        final code = failures == 0 ? 0 : 1;
        #if (headless && nodejs)
        js.Node.process.exit(code);
        #elseif sys
        Sys.exit(code);
        #end

    }

    function check(condition:Bool, what:String):Void {

        checks++;
        if (!condition) fail(what);

    }

    function equals(expected:Dynamic, actual:Dynamic, what:String):Void {

        checks++;
        if (Std.string(expected) != Std.string(actual)) fail('$what: expected <$expected>, got <$actual>');

    }

    function fail(what:String):Void {

        failures++;
        App.app.logger.error('FAILED: $what');

    }

    function listenResponses():Void {

        Notifications.shared.onResponse(this, (tag, actionId) -> responses.push(tag + ':' + (actionId == null ? 'body' : actionId)));

    }

#if headless

    function headlessSteps():Array<() -> Bool> {

        final notifications = Notifications.shared;
        final backend = notifications.backend;
        var requestAnswers:Array<String> = [];
        var readAnswers:Array<String> = [];

        return [
            () -> {
                // Nothing touched before the API is used
                check(notifications.isAvailable(), 'available headless');
                equals(NOT_DETERMINED, notifications.authorization, 'initial authorization');
                check(!backend.started, 'not started before use');

                notifications.setAppIdentity('com.example.tasks', 'Tasks');
                equals('com.example.tasks', notifications.appIdentifier, 'app identifier');
                equals('Tasks', backend.identity.name, 'backend identity');
                check(!backend.started, 'identity does not start the center');

                listenResponses();
                check(backend.started, 'a response listener starts the center');

                notifications.show({ tag: 'thread-1', title: 'Task started', body: 'Running tests' });
                notifications.show({ tag: 'thread-1', title: 'Task finished', body: 'All tests passed', actions: [{ id: 'open', label: 'Open' }] });
                notifications.show({ tag: 'thread-2', title: 'Other' });
                equals(3, backend.shown.length, 'shown');
                equals('thread-1:Task finished,thread-2:Other', [for (n in backend.delivered) n.tag + ':' + n.title].join(','), 'delivered replaces the same tag');
                equals('open:Open', backend.delivered[0].actions[0].id + ':' + backend.delivered[0].actions[0].label, 'actions kept');
                equals('', backend.delivered[1].body, 'missing body');

                notifications.dismiss('thread-1');
                equals('thread-2', [for (n in backend.delivered) n.tag].join(','), 'dismiss removes');
                equals('thread-1', backend.dismissed.join(','), 'dismissed');

                backend.simulateResponse('thread-1', null);
                backend.simulateResponse('thread-1', 'default');
                equals('', responses.join(','), 'responses are not emitted during the call');
                true;
            },
            () -> {
                equals('thread-1:body,thread-1:default', responses.join(','), 'responses at the start of the next frame, in order');

                notifications.requestAuthorization(a -> requestAnswers.push(a.toString()));
                notifications.requestAuthorization(a -> requestAnswers.push(a.toString()));
                equals('', requestAnswers.join(','), 'request answers later');
                true;
            },
            () -> {
                equals('AUTHORIZED,AUTHORIZED', requestAnswers.join(','), 'both requests answered');
                equals(1, backend.authorizationRequests, 'the user is asked once');
                equals(AUTHORIZED, notifications.authorization, 'authorization after the request');
                equals('AUTHORIZED', authorizationChanges.join(','), 'one change');

                notifications.requestAuthorization(a -> requestAnswers.push(a.toString()));
                notifications.readAuthorization(a -> readAnswers.push(a.toString()));
                true;
            },
            () -> {
                equals(1, backend.authorizationRequests, 'not asked again');
                equals('AUTHORIZED,AUTHORIZED,AUTHORIZED', requestAnswers.join(','), 'asked again answers at once');
                equals('AUTHORIZED', readAnswers.join(','), 'read');
                equals('AUTHORIZED', authorizationChanges.join(','), 'no change event for the same value');

                // Turned off in the system settings
                backend.authorization = DENIED;
                notifications.readAuthorization(a -> readAnswers.push(a.toString()));
                true;
            },
            () -> {
                equals('AUTHORIZED,DENIED', readAnswers.join(','), 'read after a change');
                equals(DENIED, notifications.authorization, 'denied');
                equals('AUTHORIZED,DENIED', authorizationChanges.join(','), 'change event');
                true;
            }
        ];

    }

#end

#if (clay && web)

    /**
     * Driven by check-web.js in headless Chromium: logs what happens
     * (`NOTIFICATIONS ...` console lines); the first click asks for the
     * authorization (a user gesture), then posts.
     */
    function webChecks():Void {

        final notifications = Notifications.shared;
        function report(line:String) {
            js.Browser.console.log('NOTIFICATIONS ' + line);
        }
        notifications.onResponse(this, (tag, actionId) -> report('response $tag $actionId'));
        notifications.readAuthorization(a -> report('ready available=${notifications.isAvailable()} read=$a'));

        var clicks = 0;
        App.app.screen.onPointerDown(this, _ -> {
            clicks++;
            if (clicks != 1) return;
            notifications.requestAuthorization(a -> {
                report('authorization $a');
                notifications.show({ tag: 't1', title: 'Title', body: 'Body', actions: [{ id: 'open', label: 'Open' }] });
                notifications.show({ tag: 't2', title: 'Two' });
                notifications.dismiss('t2');
                report('posted');
            });
        });

    }

#end

#if (clay && cpp && mac && !ios)

    function macSteps():Array<() -> Bool> {

        final notifications = Notifications.shared;
        var direct = -1;
        var read:Null<NotificationAuthorization> = null;

        return [
            () -> {
                // The hidden test app runs from its bundle: notifications are available
                check(notifications.isAvailable(), 'available in the app bundle');
                final before = LincNotificationsAccess.describe();
                check(before.indexOf('bundle=ceramic.tests.notifications ') == 0, 'bundle identifier: $before');
                check(before.indexOf('started=0') != -1, 'not started before use: $before');

                listenResponses();
                final after = LincNotificationsAccess.describe();
                check(after.indexOf('started=1 center=1 delegate=1') != -1, 'center and delegate after a listener: $after');

                // Read without asking the user
                direct = LincNotificationsAccess.readAuthorizationNow(5000);
                check(direct >= 1 && direct <= 3, 'authorization read: $direct');
                App.app.logger.info('notifications: authorization of the test app: ' + (direct : NotificationAuthorization).toString());

                notifications.readAuthorization(a -> read = a);
                true;
            },
            () -> {
                if (read == null) return false;
                equals((direct : NotificationAuthorization).toString(), read.toString(), 'read through the API');
                equals(read.toString(), notifications.authorization.toString(), 'authorization kept');

                // Requests built like show() builds them, never posted
                equals('id=ceramic-test-tag title=Title body=Body category=ceramic-notification-0 trigger=nil',
                    LincNotificationsAccess.describeRequest('ceramic-test-tag', 'Title', 'Body', ['open', 'snooze'], ['Open', 'Snooze']), 'request with actions');
                equals('id=ceramic-test-tag title=Title 2 body= category=ceramic-notification-0 trigger=nil',
                    LincNotificationsAccess.describeRequest('ceramic-test-tag', 'Title 2', '', ['open', 'snooze'], ['Open', 'Snooze']), 'same actions, same category');
                equals('id=other title=Other body=Text category=ceramic-notification-1 trigger=nil',
                    LincNotificationsAccess.describeRequest('other', 'Other', 'Text', ['open'], ['Open']), 'other actions, other category');
                equals('id=plain title=Plain body=Text category=(none) trigger=nil',
                    LincNotificationsAccess.describeRequest('plain', 'Plain', 'Text', [], []), 'no actions, no category');
                check(LincNotificationsAccess.describe().indexOf('categories=2') != -1, 'two categories registered');

                // Retracting a tag that is not delivered changes nothing visible
                notifications.dismiss('ceramic-test-tag');
                true;
            },
            () -> {
                // The system keeps the registered categories (read back; the
                // registration may take a moment)
                final categories = LincNotificationsAccess.describeCategories(5000);
                final expected = 'ceramic-notification-0 [open:Open, snooze:Snooze]\nceramic-notification-1 [open:Open]';
                if (categories != expected && stepFrames < 120) return false;
                equals(expected, categories, 'categories read back');
                true;
            }
        ];

    }

#end

}

#if (clay && cpp && mac && !ios)
typedef LincNotificationsAccess = notifications.linc.LincNotifications;
#end
