package tests;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.EntityReleasedError;
import glaze.Model;
import glaze.Subscription;
import glaze.Task;
import glaze.TestDispatcher;
import glaze.Unit;
import glaze.WeakEntity;
import testing.TestCase;

/**
 * Tests for `App`, entities, contexts, effects, globals and the executor.
 * `testGpuiBorrow` is ported from the tests of gpui-pre 0.3.10: src/app.rs and
 * `testSanityTasksRun` from src/executor.rs; the others check the behaviour of
 * src/app.rs, src/app/context.rs and src/subscription.rs.
 */
class AppTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
    }

    function newCounter(value:Int = 0):Entity<AppCounter> {
        return app.newEntity(cx -> new AppCounter(value));
    }

/// Effects batching

    function testGpuiBorrow() {
        // Ported from app.rs test_gpui_borrow: two updates that notify, observed twice
        var observationCount = 0;
        final state:Entity<AppCounter> = app.update(cx -> {
            final state = cx.newEntity(cx -> new AppCounter(0));
            cx.observe(state, (_, _) -> observationCount++).detach();
            state;
        });
        app.update(cx -> state.update(cx, (state, cx) -> {
            state.count = 1;
            cx.notify();
        }));
        app.update(cx -> state.update(cx, (state, cx) -> {
            state.count = 0;
            cx.notify();
        }));
        assertEquals(2, observationCount);
    }

    function testNotifyInNestedUpdatesFlushesOnce() {
        final counter = newCounter();
        var observed = 0;
        app.observe(counter, (_, _) -> observed++);

        app.update(cx -> {
            counter.update(cx, (_, cx) -> {
                cx.notify();
                app.update(cx -> {
                    counter.update(cx, (_, cx) -> cx.notify());
                    assertEquals(0, observed, 'no flush in a nested update');
                });
                assertEquals(0, observed, 'no flush before the outermost update ends');
            });
            assertEquals(0, observed);
        });
        assertEquals(1, observed);
    }

    function testNotifyDedup() {
        final counter = newCounter();
        var observed = 0;
        app.observe(counter, (_, _) -> observed++);

        counter.update(app, (_, cx) -> {
            cx.notify();
            cx.notify();
            cx.notify();
        });
        assertEquals(1, observed);

        counter.update(app, (_, cx) -> cx.notify());
        assertEquals(2, observed);
    }

    function testObserversRunAfterOutermostUpdate() {
        final a = newCounter();
        final b = newCounter();
        final log:Array<String> = [];
        app.observe(a, (_, _) -> log.push('a'));
        app.observe(b, (_, _) -> log.push('b'));

        app.update(cx -> {
            b.update(cx, (_, cx) -> cx.notify());
            a.update(cx, (_, cx) -> cx.notify());
            log.push('end of update');
        });
        assertEquals('end of update,b,a', log.join(','));
    }

    function testObserverEffectsCascade() {
        final a = newCounter();
        final b = newCounter();
        var bObserved = 0;
        // Observing `a` notifies `b`: effects pushed while flushing are flushed too
        app.observe(a, (_, cx) -> b.update(cx, (_, cx) -> cx.notify()));
        app.observe(b, (_, _) -> bObserved++);
        a.update(app, (_, cx) -> cx.notify());
        assertEquals(1, bObserved);
    }

    function testContextObserve() {
        final observed = newCounter(5);
        final observer = app.newEntity((cx:Context<AppCounter>) -> {
            final view = new AppCounter(0);
            cx.observe(observed, (view, observed, cx) -> {
                view.count = observed.read(cx).count;
            });
            view;
        });
        observed.update(app, (counter, cx) -> {
            counter.count = 7;
            cx.notify();
        });
        assertEquals(7, observer.read(app).count);
    }

    function testDeferRunsAtEndOfUpdate() {
        final log:Array<String> = [];
        app.update(cx -> {
            cx.defer(_ -> log.push('deferred'));
            log.push('update');
        });
        assertEquals('update,deferred', log.join(','));

        // Outside of an update, defer runs right away
        app.defer(_ -> log.push('immediate'));
        assertEquals('update,deferred,immediate', log.join(','));
    }

/// Events

    function testEmitAndSubscribeWithEventTypes() {
        final emitter = app.newEntity(cx -> new AppEmitter());
        final received:Array<String> = [];

        final subscriber = app.newEntity((cx:Context<AppCounter>) -> {
            final view = new AppCounter(0);
            cx.subscribe(emitter, ClickEvent, (view, emitter, event, cx) -> {
                view.count += event.clicks;
                received.push('click ${event.clicks}');
            });
            cx.subscribe(emitter, ChangeEvent, (view, emitter, event, cx) -> {
                switch event {
                    case Changed(value): received.push('changed $value');
                    case Cleared: received.push('cleared');
                }
            });
            view;
        });

        emitter.update(app, (_, cx) -> {
            cx.emit(new ClickEvent(2));
            cx.emit(Changed('x'));
            cx.emit(Cleared);
            cx.emit(new ClickEvent(3));
            cx.emit('ignored string event');
        });

        assertEquals('click 2,changed x,cleared,click 3', received.join(','));
        assertEquals(5, subscriber.read(app).count);
    }

    function testSubclassEventsMatch() {
        final emitter = app.newEntity(cx -> new AppEmitter());
        var count = 0;
        app.subscribe(emitter, ClickEvent, (_, event, _) -> count += event.clicks);
        emitter.update(app, (_, cx) -> cx.emit(new DoubleClickEvent()));
        assertEquals(2, count);
    }

    function testSubscriptionDispose() {
        final emitter = app.newEntity(cx -> new AppEmitter());
        var count = 0;
        final subscription = app.subscribe(emitter, ClickEvent, (_, _, _) -> count++);
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(1, count);
        subscription.dispose();
        assertFalse(subscription.isActive);
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(1, count);
    }

    function testSubscriptionDisposedWhenSubscriberDestroyed() {
        final emitter = app.newEntity(cx -> new AppEmitter());
        var count = 0;
        var subscription:Subscription = null;
        final subscriber = app.newEntity(cx -> {
            subscription = cx.subscribe(emitter, ClickEvent, (_, _, _, _) -> count++);
            new AppCounter(0);
        });
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(1, count);

        subscriber.read(app).destroy();
        assertFalse(subscription.isActive, 'owned subscription disposed');
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(1, count);
    }

    function testDetachedSubscriptionStopsWithSubscriber() {
        final emitter = app.newEntity(cx -> new AppEmitter());
        var count = 0;
        final subscriber = app.newEntity(cx -> {
            cx.subscribe(emitter, ClickEvent, (_, _, _, _) -> count++).detach();
            new AppCounter(0);
        });
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(1, count);
        subscriber.read(app).destroy();
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(1, count, 'callbacks check that the subscriber is alive');
    }

    function testSubscriptionCreatedDuringDispatchIsDeferred() {
        // Like GPUI, a subscriber added while an effect is dispatched is activated
        // at the end of the effect cycle and does not receive that event
        final emitter = app.newEntity(cx -> new AppEmitter());
        var outer = 0;
        var inner = 0;
        app.subscribe(emitter, ClickEvent, (emitter, _, cx) -> {
            outer++;
            if (outer == 1) {
                cx.subscribe(emitter, ClickEvent, (_, _, _) -> inner++);
            }
        });
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(1, outer);
        assertEquals(0, inner);
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(1)));
        assertEquals(2, outer);
        assertEquals(1, inner);
    }

    function testSubscribeSelfDuringBuild() {
        var received = 0;
        final emitter = app.newEntity(cx -> {
            cx.subscribeSelf(ClickEvent, (view, event, cx) -> received += event.clicks);
            new AppEmitter();
        });
        emitter.update(app, (_, cx) -> cx.emit(new ClickEvent(4)));
        assertEquals(4, received);
    }

    function testSubscriptionJoin() {
        final emitter = app.newEntity(cx -> new AppEmitter());
        var count = 0;
        final joined = Subscription.join(
            app.subscribe(emitter, ClickEvent, (_, _, _) -> count++),
            app.subscribe(emitter, ChangeEvent, (_, _, _) -> count++)
        );
        emitter.update(app, (_, cx) -> {
            cx.emit(new ClickEvent(1));
            cx.emit(Cleared);
        });
        assertEquals(2, count);
        joined.dispose();
        emitter.update(app, (_, cx) -> {
            cx.emit(new ClickEvent(1));
            cx.emit(Cleared);
        });
        assertEquals(2, count);
    }

/// Release

    function testReleaseObservers() {
        final counter = newCounter(3);
        final log:Array<String> = [];
        app.observeRelease(counter, (counter, _) -> log.push('released ${counter.count}'));
        final observer = app.newEntity(cx -> {
            cx.observeRelease(counter, (view, released, _) -> log.push('observer saw ${released.count}'));
            new AppCounter(0);
        });
        final weak = counter.downgrade();
        assertTrue(weak.upgrade() != null);

        counter.read(app).destroy();
        assertEquals('released 3,observer saw 3', log.join(','));
        assertNull(weak.upgrade());
        assertFalse(weak.isUpgradable());

        // Release observers are removed with the entity
        observer.read(app).destroy();
        assertEquals(2, log.length);
    }

    function testOnReleaseRunsBeforeOwnedThingsAreDisposed() {
        final log:Array<String> = [];
        final parent = app.newEntity((cx:Context<AppParent>) -> {
            final child = cx.newEntity(cx -> {
                cx.onRelease((child, _) -> log.push('child released'));
                new AppCounter(1);
            });
            cx.onRelease((parent, _) -> log.push('parent released, child alive: ${!parent.child.read(cx).destroyed}'));
            new AppParent(child);
        });
        final child = parent.read(app).child;
        assertFalse(child.read(app).destroyed);

        parent.read(app).destroy();
        assertEquals('parent released, child alive: true,child released', log.join(','));
        assertTrue(child.read(app).destroyed, 'owned child destroyed with its owner');
    }

    function testDestroyInsideUpdateReleasesAtFlush() {
        final counter = newCounter();
        var released = false;
        app.observeRelease(counter, (_, _) -> released = true);
        app.update(cx -> {
            counter.read(cx).destroy();
            assertFalse(released, 'released when effects are flushed');
        });
        assertTrue(released);
    }

    function testWeakEntityUpdate() {
        final counter = newCounter(1);
        final weak:WeakEntity<AppCounter> = counter.downgrade();
        assertEquals(counter.entityId(), weak.entityId());
        assertTrue(weak.equals(counter.downgrade()));
        weak.update(app, (counter, cx) -> counter.count = 2);
        assertEquals(2, counter.read(app).count);

        counter.read(app).destroy();
        var raised:Dynamic = null;
        try {
            weak.update(app, (counter, cx) -> counter.count = 3);
        }
        catch (e:EntityReleasedError) {
            raised = e;
        }
        assertNotNull(raised);
        assertFalse(weak.tryUpdate(app, (counter, cx) -> counter.count = 4));
        assertEquals(2, counter.read(app).count);
    }

    function testEntityIdsAreUnique() {
        final a = newCounter();
        final b = newCounter();
        assertTrue(a.entityId() != b.entityId());
        assertTrue(a.equals(a));
        assertFalse(a.equals(b));
        // A model constructed directly gets an id from App.current when first used
        final c = new AppCounter(0);
        assertTrue(c.entityId > 0);
        assertTrue(c.entityId != a.entityId());
    }

    function testObserveNew() {
        var created = 0;
        app.observeNew(AppCounter, (counter, cx) -> {
            created++;
            counter.count = 42;
        });
        final counter = newCounter();
        assertEquals(1, created);
        assertEquals(42, counter.read(app).count);
        app.newEntity(cx -> new AppEmitter());
        assertEquals(1, created);
    }

/// Globals

    function testGlobals() {
        assertFalse(app.hasGlobal(AppSettings));
        assertNull(app.tryGlobal(AppSettings));
        assertRaises(() -> app.global(AppSettings));

        var observed = 0;
        app.observeGlobal(AppSettings, _ -> observed++);

        app.setGlobal(new AppSettings(12));
        assertTrue(app.hasGlobal(AppSettings));
        assertEquals(12, app.global(AppSettings).fontSize);
        assertEquals(1, observed);

        final result = app.updateGlobal(AppSettings, (settings, cx) -> {
            settings.fontSize++;
            settings.fontSize;
        });
        assertEquals(13, result);
        assertEquals(13, app.global(AppSettings).fontSize);
        assertEquals(2, observed);

        // Several global changes in one update notify observers once
        app.update(cx -> {
            cx.globalMut(AppSettings).fontSize = 20;
            cx.updateGlobal(AppSettings, (settings, _) -> settings.fontSize++);
        });
        assertEquals(21, app.global(AppSettings).fontSize);
        assertEquals(3, observed);

        final removed = app.removeGlobal(AppSettings);
        assertEquals(21, removed.fontSize);
        assertFalse(app.hasGlobal(AppSettings));
        assertEquals(4, observed);

        final defaultSettings = app.defaultGlobal(AppSettings);
        assertEquals(14, defaultSettings.fontSize);
        assertEquals(14, app.readGlobal(AppSettings, (settings, _) -> settings.fontSize));
    }

    function testContextObserveGlobal() {
        app.setGlobal(new AppSettings(10));
        final view = app.newEntity((cx:Context<AppCounter>) -> {
            cx.observeGlobal(AppSettings, (view, cx) -> view.count = cx.global(AppSettings).fontSize);
            new AppCounter(0);
        });
        app.updateGlobal(AppSettings, (settings, _) -> settings.fontSize = 30);
        assertEquals(30, view.read(app).count);
        view.read(app).destroy();
        app.updateGlobal(AppSettings, (settings, _) -> settings.fontSize = 40);
        assertEquals(30, view.read(app).count);
    }

/// Tasks and executor

    function testSanityTasksRun() {
        // Ported from executor.rs sanity_test_tasks_run
        var taskRan = false;
        app.foregroundExecutor().spawn(() -> {
            taskRan = true;
            return Task.done();
        }).detach();
        assertTrue(Task.done().value == Unit.unit);
        assertFalse(taskRan, 'spawned work never runs synchronously');
        dispatcher.runUntilParked();
        assertTrue(taskRan);
    }

    function testTimerFires() {
        final executor = app.backgroundExecutor();
        var fired = false;
        executor.timer(0.5).then(_ -> fired = true);
        dispatcher.advanceClock(0.4);
        dispatcher.runUntilParked();
        assertFalse(fired);
        // Like GPUI's test scheduler, advanceClock runs the timers it reaches
        dispatcher.advanceClock(0.1);
        assertTrue(fired);
        assertFloatEquals(0.5, executor.now());
    }

    function testTimerCancel() {
        var fired = false;
        final timer = app.backgroundExecutor().timer(1);
        final next = timer.then(_ -> fired = true);
        next.cancel();
        assertTrue(timer.isCancelled, 'cancelling a continuation cancels what it awaits');
        assertEquals(0, dispatcher.pendingTimerCount());
        dispatcher.advanceClock(2);
        dispatcher.runUntilParked();
        assertFalse(fired);
    }

    function testBackgroundSpawnAndChain() {
        final executor = app.backgroundExecutor();
        var result = 0;
        executor.spawn(() -> 20)
            .andThen(value -> executor.timer(1).map(_ -> value + 1))
            .map(value -> value * 2)
            .then(value -> result = value);
        dispatcher.runUntilParked();
        assertEquals(0, result);
        dispatcher.advanceClock(1);
        dispatcher.runUntilParked();
        assertEquals(42, result);
    }

    function testTaskAll() {
        final executor = app.backgroundExecutor();
        var values:Array<Int> = null;
        Task.all([
            executor.timer(2).map(_ -> 1),
            executor.spawn(() -> 2),
            Task.ready(3)
        ]).then(result -> values = result);
        dispatcher.runUntilParked();
        assertNull(values);
        dispatcher.advanceClock(2);
        dispatcher.runUntilParked();
        assertEquals('1,2,3', values.join(','));
    }

    function testTaskFailurePropagates() {
        var caught:Dynamic = null;
        var skipped = true;
        app.backgroundExecutor().spawn(() -> 1)
            .map(value -> {
                if (value == 1) throw 'boom';
                value;
            })
            .map(value -> {
                skipped = false;
                value;
            })
            .catchError(error -> {
                caught = error;
                -1;
            });
        dispatcher.runUntilParked();
        assertTrue(skipped);
        assertEquals('boom', caught);
    }

    function testContextSpawnUpdatesEntity() {
        final counter = app.newEntity(cx -> new AppCounter(0));
        var observed = 0;
        app.observe(counter, (_, _) -> observed++);
        counter.update(app, (_, cx) -> {
            cx.spawn((weak, cx) -> {
                return cx.backgroundExecutor().timer(0.1).then(_ -> {
                    weak.update(cx, (counter, cx) -> {
                        counter.count = 10;
                        cx.notify();
                    });
                });
            }).detach();
        });
        dispatcher.runUntilParked();
        dispatcher.advanceClock(0.1);
        dispatcher.runUntilParked();
        assertEquals(10, counter.read(app).count);
        assertEquals(1, observed);
    }

    function testOwnedTaskCancelledOnDestroy() {
        var fired = false;
        var task:glaze.AnyTask = null;
        final counter = app.newEntity(cx -> {
            task = cx.spawn((weak, cx) -> cx.backgroundExecutor().timer(1).then(_ -> {
                fired = true;
            }));
            new AppCounter(0);
        });
        dispatcher.runUntilParked();
        assertTrue(task.isPending);
        counter.read(app).destroy();
        assertTrue(task.isCancelled);
        assertEquals(0, dispatcher.pendingTimerCount(), 'the awaited timer is cancelled too');
        dispatcher.advanceClock(2);
        dispatcher.runUntilParked();
        assertFalse(fired);
    }

    function testDetachedTaskFailsWhenEntityReleased() {
        // A detached task keeps running; `weak.update` then throws, failing the task like `?`
        var task:glaze.AnyTask = null;
        var after = false;
        final counter = app.newEntity((cx:Context<AppCounter>) -> {
            task = cx.spawn((weak, cx) -> cx.backgroundExecutor().timer(1).then(_ -> {
                weak.update(cx, (counter, _) -> counter.count = 1);
                after = true;
            }));
            task.detach();
            new AppCounter(0);
        });
        dispatcher.runUntilParked();
        counter.read(app).destroy();
        assertTrue(task.isPending);
        dispatcher.advanceClock(1);
        dispatcher.runUntilParked();
        assertTrue(task.isFailed);
        assertTrue(Std.isOfType(task.error, EntityReleasedError));
        assertFalse(after);
    }

    function testTaskCancelledBeforeRunning() {
        var ran = false;
        final task = app.spawn(cx -> {
            ran = true;
            return Task.ready(1);
        });
        task.cancel();
        dispatcher.runUntilParked();
        assertFalse(ran);
        assertTrue(task.isCancelled);
    }

    function testSpawnResult() {
        final task = app.spawn(cx -> cx.backgroundExecutor().spawn(() -> 'done'));
        dispatcher.runUntilParked();
        assertTrue(task.isReady);
        assertEquals('done', task.value);
    }

}

class AppCounter extends Model {

    @observe public var count:Int = 0;

    public function new(count:Int) {
        super();
        this.count = count;
    }

}

class AppParent extends Model {

    public final child:Entity<AppCounter>;

    public function new(child:Entity<AppCounter>) {
        super();
        this.child = child;
    }

}

class AppEmitter extends Model {

    public function new() {
        super();
    }

}

class ClickEvent {

    public final clicks:Int;

    public function new(clicks:Int) {
        this.clicks = clicks;
    }

}

class DoubleClickEvent extends ClickEvent {

    public function new() {
        super(2);
    }

}

enum ChangeEvent {
    Changed(value:String);
    Cleared;
}

class AppSettings {

    public var fontSize:Int;

    public function new(fontSize:Int = 14) {
        this.fontSize = fontSize;
    }

}
