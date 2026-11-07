package tests;

import gpui.App;
import gpui.Entity;
import gpui.Model;
import gpui.TestDispatcher;
import gpui.ViewTracker;
import testing.TestCase;
import tracker.Autorun;

/**
 * Tests for the tracker integration: `ViewTracker` capture and reaction,
 * observable globals, and capture being disabled in handlers and executors.
 */
class ReactivityTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var invalidations:Int;

    var tracker:ViewTracker;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        invalidations = 0;
        tracker = new ViewTracker(() -> invalidations++);
        flushImmediate();
    }

    override function teardown() {
        tracker.destroy();
        flushImmediate();
    }

    /**
     * Tracker reactions run through `app.onceImmediate`, flushed by Ceramic each
     * frame. Tests flush them explicitly.
     */
    inline function flushImmediate():Void {
        ceramic.App.app.flushImmediate();
    }

    function testReadDuringCaptureReactsOnce() {
        final model = app.newEntity(cx -> new ReactiveModel());
        tracker.capture(() -> model.read(app).count);

        model.read(app).count = 1;
        assertEquals(0, invalidations, 'the reaction is deferred to the immediate flush');
        model.read(app).count = 2;
        model.read(app).label = 'changed';
        flushImmediate();
        assertEquals(1, invalidations);

        // Dependencies are dropped once invalidated, until the next capture
        model.read(app).count = 3;
        flushImmediate();
        assertEquals(1, invalidations);

        tracker.capture(() -> model.read(app).count);
        model.read(app).count = 4;
        flushImmediate();
        assertEquals(2, invalidations);
    }

    function testSettingSameValueDoesNotReact() {
        final model = app.newEntity(cx -> new ReactiveModel());
        tracker.capture(() -> model.read(app).count);
        model.read(app).count = 0;
        flushImmediate();
        assertEquals(0, invalidations);
    }

    function testReadsOutsideCaptureDoNotSubscribe() {
        final model = app.newEntity(cx -> new ReactiveModel());
        final value = model.read(app).count;
        tracker.capture(() -> {});
        final other = model.read(app).label;
        model.read(app).count = value + 1;
        model.read(app).label = other + '!';
        flushImmediate();
        assertEquals(0, invalidations);
    }

    function testRecaptureDropsOldDependencies() {
        final model = app.newEntity(cx -> new ReactiveModel());
        final render = () -> {
            final m = model.read(app);
            return m.flag ? m.count : m.label.length;
        };

        tracker.capture(render);
        // Not read by the current branch
        model.read(app).count = 5;
        flushImmediate();
        assertEquals(0, invalidations);

        model.read(app).flag = true;
        flushImmediate();
        assertEquals(1, invalidations);

        tracker.capture(render);
        model.read(app).label = 'not read anymore';
        flushImmediate();
        assertEquals(1, invalidations);
        model.read(app).count = 6;
        flushImmediate();
        assertEquals(2, invalidations);
    }

    function testStaleReactionAfterRecaptureReactsOnce() {
        final model = app.newEntity(cx -> new ReactiveModel());
        tracker.capture(() -> model.read(app).count);
        model.read(app).count = 1;
        // The view renders again before the reaction is flushed
        tracker.capture(() -> model.read(app).count);
        flushImmediate();
        assertEquals(0, invalidations, 'the stale reaction is ignored');
        model.read(app).count = 2;
        tracker.capture(() -> model.read(app).count);
        model.read(app).count = 3;
        flushImmediate();
        assertEquals(1, invalidations);
    }

    function testDestroyStopsNotifications() {
        final model = app.newEntity(cx -> new ReactiveModel());
        tracker.capture(() -> model.read(app).count);
        tracker.destroy();
        model.read(app).count = 1;
        flushImmediate();
        assertEquals(0, invalidations);
    }

    function testTrackerDestroyedWithOwner() {
        final model = app.newEntity(cx -> new ReactiveModel());
        final view = app.newEntity(cx -> new ReactiveModel());
        var viewInvalidations = 0;
        final viewTracker = new ViewTracker(() -> viewInvalidations++, view.read(app));
        assertEquals('tests.ReactiveModel', viewTracker.name);
        viewTracker.capture(() -> model.read(app).count);
        view.read(app).destroy();
        assertTrue(viewTracker.destroyed);
        model.read(app).count = 1;
        flushImmediate();
        assertEquals(0, viewInvalidations);
    }

    function testCaptureRestoresCurrentAutorun() {
        final model = app.newEntity(cx -> new ReactiveModel());
        var childInvalidations = 0;
        final child = new ViewTracker(() -> childInvalidations++);
        assertNull(Autorun.current);
        tracker.capture(() -> {
            model.read(app).count;
            child.capture(() -> model.read(app).label);
            assertTrue(Autorun.current == tracker);
            model.read(app).flag;
        });
        assertNull(Autorun.current);

        model.read(app).label = 'child only';
        flushImmediate();
        assertEquals(0, invalidations);
        assertEquals(1, childInvalidations);

        model.read(app).flag = true;
        flushImmediate();
        assertEquals(1, invalidations);
        child.destroy();
    }

    function testHandlersDuringCaptureDoNotSubscribe() {
        final model = app.newEntity(cx -> new ReactiveModel());
        final emitter = app.newEntity(cx -> new ReactiveModel());
        var handlerReads = 0;
        app.subscribe(emitter, String, (_, _, _) -> {
            handlerReads += model.read(app).count;
        });
        app.observe(emitter, (_, _) -> {
            handlerReads += model.read(app).label.length;
        });
        var deferredRan = false;

        tracker.capture(() -> {
            // An update ending inside the capture flushes effects, and runs handlers
            app.update(cx -> {
                emitter.update(cx, (_, cx) -> {
                    cx.emit('event');
                    cx.notify();
                });
                cx.defer(_ -> {
                    deferredRan = true;
                    model.read(app).flag;
                });
            });
        });
        assertTrue(deferredRan);

        model.read(app).count = 1;
        model.read(app).label = 'x';
        model.read(app).flag = true;
        flushImmediate();
        assertEquals(0, invalidations);
    }

    function testExecutorCallbacksDuringCaptureDoNotSubscribe() {
        final model = app.newEntity(cx -> new ReactiveModel());
        var reads = 0;
        app.backgroundExecutor().spawn(() -> reads += model.read(app).count);
        app.backgroundExecutor().timer(1).then(_ -> reads += model.read(app).label.length);
        app.spawn(cx -> {
            reads++;
            model.read(app).flag;
            return gpui.Task.done();
        });

        tracker.capture(() -> {
            dispatcher.advanceClock(1);
            dispatcher.runUntilParked();
        });
        assertEquals(1, reads);

        model.read(app).count = 1;
        model.read(app).label = 'x';
        model.read(app).flag = true;
        flushImmediate();
        assertEquals(0, invalidations);
    }

    function testGlobalReadInCaptureReactsToSetGlobal() {
        app.setGlobal(new ReactiveTheme('light'));
        tracker.capture(() -> app.global(ReactiveTheme).name);

        app.setGlobal(new ReactiveTheme('dark'));
        flushImmediate();
        assertEquals(1, invalidations);

        tracker.capture(() -> app.global(ReactiveTheme).name);
        app.updateGlobal(ReactiveTheme, (theme, _) -> theme.name = 'contrast');
        flushImmediate();
        assertEquals(2, invalidations);

        tracker.capture(() -> app.global(ReactiveTheme).name);
        app.globalMut(ReactiveTheme).name = 'mut';
        flushImmediate();
        assertEquals(3, invalidations);

        // Reading another global does not subscribe to this one
        tracker.capture(() -> app.tryGlobal(ReactiveOtherGlobal));
        app.updateGlobal(ReactiveTheme, (theme, _) -> theme.name = 'again');
        flushImmediate();
        assertEquals(3, invalidations);

        // A missing global read with tryGlobal reacts when it is set
        app.setGlobal(new ReactiveOtherGlobal());
        flushImmediate();
        assertEquals(4, invalidations);
    }

    function testContextGlobalInCapture() {
        app.setGlobal(new ReactiveTheme('light'));
        final view = app.newEntity(cx -> new ReactiveModel());
        view.update(app, (view, cx) -> tracker.capture(() -> cx.global(ReactiveTheme)));
        view.update(app, (view, cx) -> cx.setGlobal(new ReactiveTheme('dark')));
        flushImmediate();
        assertEquals(1, invalidations);
    }

    function testWriteDuringCaptureIsDetected() {
        final prevCheck = ViewTracker.checkWritesDuringCapture;
        final prevHandler = ViewTracker.onWriteDuringCapture;
        final detected:Array<String> = [];
        ViewTracker.checkWritesDuringCapture = true;
        ViewTracker.onWriteDuringCapture = tracker -> detected.push(tracker.name);

        final model = app.newEntity(cx -> new ReactiveModel());
        final view = new ViewTracker(() -> invalidations++, null, 'CounterView');
        view.capture(() -> {
            final value = model.read(app).count;
            model.read(app).count = value + 1;
        });
        assertEquals('CounterView', detected.join(','));

        // The view is marked dirty again for the next frame
        flushImmediate();
        assertEquals(1, invalidations);

        // Writing a field that was not read does not count
        view.capture(() -> model.read(app).label = 'written, not read');
        assertEquals(1, detected.length);

        view.destroy();
        ViewTracker.checkWritesDuringCapture = prevCheck;
        ViewTracker.onWriteDuringCapture = prevHandler;
    }

    function testReactionGoesThroughNotify() {
        // The path windows will use: the reaction notifies the view entity
        final model = app.newEntity(cx -> new ReactiveModel());
        final view = app.newEntity(cx -> new ReactiveModel());
        var observed = 0;
        app.observe(view, (_, _) -> observed++);
        final viewTracker = new ViewTracker(() -> app.notify(view.entityId()), view.read(app));
        viewTracker.capture(() -> model.read(app).count);
        model.read(app).count = 1;
        model.read(app).count = 2;
        flushImmediate();
        assertEquals(1, observed);
        view.read(app).destroy();
    }

    function testModelAutorunOwnedByEntity() {
        // Plain tracker autoruns owned by a model (gpui-kit side effects) stop on destroy
        final model = app.newEntity(cx -> new ReactiveModel());
        final owner = app.newEntity(cx -> new ReactiveModel());
        var runs = 0;
        owner.read(app).autorun(() -> {
            model.read(app).count;
            runs++;
        });
        assertEquals(1, runs);
        model.read(app).count = 1;
        flushImmediate();
        assertEquals(2, runs);
        owner.read(app).destroy();
        model.read(app).count = 2;
        flushImmediate();
        assertEquals(2, runs);
    }

    function testManyFieldsCapture() {
        // A render reading 200 fields: every one of them is tracked
        final models:Array<Entity<ReactiveModel>> = [for (i in 0...200) app.newEntity(cx -> new ReactiveModel())];
        tracker.capture(() -> {
            var sum = 0;
            for (model in models) sum += model.read(app).count;
            sum;
        });
        models[199].read(app).count = 1;
        flushImmediate();
        assertEquals(1, invalidations);
        tracker.capture(() -> {
            var sum = 0;
            for (model in models) sum += model.read(app).count;
            sum;
        });
        models[0].read(app).count = 1;
        flushImmediate();
        assertEquals(2, invalidations);
    }

}

class ReactiveModel extends Model {

    @observe public var count:Int = 0;

    @observe public var label:String = '';

    @observe public var flag:Bool = false;

    public function new() {
        super();
    }

}

class ReactiveTheme {

    public var name:String;

    public function new(name:String) {
        this.name = name;
    }

}

class ReactiveOtherGlobal {

    public function new() {}

}
