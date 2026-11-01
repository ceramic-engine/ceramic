// Ported from gpui-pre 0.3.10: src/app/context.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The app context, with specialized behavior for the given entity.
 *
 * One `Context` exists per entity and is reused. In Rust it derefs to `App`:
 * here the most used `App` methods are forwarded, and `cx.app` gives the rest.
 *
 * Subscriptions and tasks created through a context are owned by its entity:
 * they are disposed / cancelled when the entity is destroyed, unless detached.
 * Entities created with `cx.newEntity` are owned too, and destroyed with it.
 *
 * Window related methods: `listener`, `processor`, `onNextFrame`, `deferIn`,
 * `observeIn`, `subscribeIn`, `focusHandle` and the focus listeners.
 */
class Context<T:Model> extends EntitySlot {

    @:allow(gpui)
    function new(app:App, id:Int) {
        super(app, id);
    }

    /**
     * The entity id of the entity backing this context.
     */
    public inline function entityId():Int {
        return id;
    }

    /**
     * Returns a handle to the entity belonging to this context.
     */
    public function entity():Entity<T> {
        if (!isAlive()) {
            throw 'The entity must be alive if we have a entity context';
        }
        return cast model;
    }

    /**
     * Returns a weak handle to the entity belonging to this context.
     */
    public inline function weakEntity():WeakEntity<T> {
        return new WeakEntity<T>(this);
    }

    /**
     * Arranges for the given function to be called whenever `notify` is called
     * with the given entity.
     */
    public function observe<W:Model>(entity:Entity<W>, onNotify:(T, Entity<W>, Context<T>) -> Void):Subscription {
        final observer = this;
        return ownSubscription(app.observeInternal(entity, (entity, cx) -> {
            if (!observer.isAlive())
                return false;
            cx.updateEntity((cast observer.model : T), (view, cx) -> onNotify(view, entity, cx));
            return true;
        }));
    }

    /**
     * Observe changes to ourselves.
     */
    public function observeSelf(onEvent:(T, Context<T>) -> Void):Subscription {
        final self = this;
        return ownSubscription(app.newObserver(id, cx -> {
            if (!self.isAlive())
                return false;
            cx.updateEntity((cast self.model : T), onEvent);
            return true;
        }));
    }

    /**
     * Subscribe to an event type from another entity.
     */
    public function subscribe<T2:Model, E>(entity:Entity<T2>, eventType:EventType<E>, onEvent:(T, Entity<T2>, E, Context<T>) -> Void):Subscription {
        final subscriber = this;
        return ownSubscription(app.subscribeInternal(entity, eventType, (emitter, event, cx) -> {
            if (!subscriber.isAlive())
                return false;
            cx.updateEntity((cast subscriber.model : T), (view, cx) -> onEvent(view, emitter, event, cx));
            return true;
        }));
    }

    /**
     * Subscribe to an event type from ourself.
     */
    public function subscribeSelf<E>(eventType:EventType<E>, onEvent:(T, E, Context<T>) -> Void):Subscription {
        final self = this;
        return ownSubscription(app.newSubscription(id, new EventListener(cast eventType, (event, cx) -> {
            if (!self.isAlive())
                return false;
            cx.updateEntity((cast self.model : T), (view, cx) -> onEvent(view, event, cx));
            return true;
        })));
    }

    /**
     * Register a callback to be invoked when GPUI releases this entity.
     */
    public function onRelease(onRelease:(T, App) -> Void):Subscription {
        final subscriber = app.releaseListeners.insert(id, (entity, cx) -> onRelease(cast entity, cx));
        subscriber.activate();
        return ownSubscription(subscriber.subscription);
    }

    /**
     * Register a callback to be run on the release of another entity.
     */
    public function observeRelease<T2:Model>(entity:Entity<T2>, onRelease:(T, T2, Context<T>) -> Void):Subscription {
        final observer = this;
        final subscriber = app.releaseListeners.insert(entity.entityId(), (released, cx) -> {
            if (observer.isAlive()) {
                cx.updateEntity((cast observer.model : T), (view, cx) -> onRelease(view, cast released, cx));
            }
        });
        subscriber.activate();
        return ownSubscription(subscriber.subscription);
    }

    /**
     * Register a callback for updates to the given global.
     * To re-render on global changes, reading the global in render is enough.
     */
    public function observeGlobal<G>(type:Class<G>, f:(T, Context<T>) -> Void):Subscription {
        final observer = this;
        final subscriber = app.globalObservers.insert(App.typeIdOf(type), cx -> {
            if (!observer.isAlive())
                return false;
            cx.updateEntity((cast observer.model : T), f);
            return true;
        });
        app.defer(_ -> subscriber.activate());
        return ownSubscription(subscriber.subscription);
    }

    /**
     * Tell GPUI that this entity has changed and observers of it should be notified.
     * Not needed after changing `@observe` fields read in render.
     */
    public inline function notify():Void {
        app.notify(id);
    }

    /**
     * Forwarded from `App` (Rust `Context` derefs to `App`): stop dispatching
     * the current event to other handlers.
     */
    public inline function stopPropagation():Void {
        app.stopPropagation();
    }

    /**
     * Forwarded from `App`: let the current action propagate to handlers
     * higher in the tree.
     */
    public inline function propagate():Void {
        app.propagate();
    }

    /**
     * Emit an event, which can be handled by other entities that have subscribed
     * via `subscribe` methods on their respective contexts.
     */
    public function emit(event:Dynamic):Void {
        app.pushEffect(Emit(id, event));
    }

    /**
     * Spawn an async block, given a weak handle to the entity owned by this context
     * and a context that can be held across await points. The block returns the task
     * it ends with (see `ForegroundExecutor.spawn`). The returned task is owned by
     * this entity (cancelled when it is destroyed) unless detached.
     */
    public function spawn<R>(f:(WeakEntity<T>, AsyncApp) -> Task<R>):Task<R> {
        final weak = weakEntity();
        final task = app.spawn(cx -> f(weak, cx));
        ownTask(task);
        return task;
    }

    /**
     * Builds an entity owned by this entity (Rust: `cx.new(|cx| ...)`).
     * It is destroyed when this entity is destroyed.
     */
    public function newEntity<U:Model>(build:Context<U>->U):Entity<U> {
        return app.newEntityIn(build, this);
    }

    /**
     * Schedules the given function to be run at the end of the current effect cycle.
     */
    public inline function defer(f:App->Void):Void {
        app.defer(f);
    }

    /**
     * Schedules all windows to be redrawn.
     */
    public inline function refreshWindows():Void {
        app.refreshWindows();
    }

    /**
     * Returns the background executor.
     */
    public inline function backgroundExecutor():BackgroundExecutor {
        return app.backgroundExecutor();
    }

    /**
     * Returns the foreground executor.
     */
    public inline function foregroundExecutor():ForegroundExecutor {
        return app.foregroundExecutor();
    }

    /**
     * Check whether a global of the given type has been assigned.
     */
    public inline function hasGlobal<G>(type:Class<G>):Bool {
        return app.hasGlobal(type);
    }

    /**
     * Access the global of the given type. Throws if it has not been assigned.
     */
    public inline function global<G>(type:Class<G>):G {
        return app.global(type);
    }

    /**
     * Access the global of the given type if a value has been assigned.
     */
    public inline function tryGlobal<G>(type:Class<G>):Null<G> {
        return app.tryGlobal(type);
    }

    /**
     * Sets the value of the global of the given type.
     */
    public inline function setGlobal<G>(global:G, ?type:Class<G>):Void {
        app.setGlobal(global, type);
    }

    /**
     * Updates the global of the given type in place.
     */
    public function updateGlobal<G, R>(type:Class<G>, f:(G, App) -> R):R {
        return app.updateGlobal(type, f);
    }

    /**
     * Access the global of the given type mutably: observers and readers are notified.
     */
    public inline function globalMut<G>(type:Class<G>):G {
        return app.globalMut(type);
    }

    /**
     * Access the global of the given type, creating it with its default constructor if needed.
     */
    public inline function defaultGlobal<G>(type:Class<G>):G {
        return app.defaultGlobal(type);
    }


/// Window related methods (steps 8 and 9)

    /**
     * Convenience method for producing view state in a closure.
     * The returned listener updates the entity, then calls `listener` with it.
     */
    public function listener<E>(listener:(T, E, Window, Context<T>) -> Void):(E, Window, App) -> Void {
        final weak = weakEntity();
        return (event:E, window:Window, cx:App) -> {
            final view = weak.upgrade();
            if (view != null) {
                cx.updateEntity((view : T), (view, cx) -> listener(view, event, window, cx));
            }
        };
    }

    /**
     * Convenience method for producing a processor of values with the view: the
     * returned function updates the entity and returns the result of `f`.
     */
    public function processor<E, R>(f:(T, E, Window, Context<T>) -> R):(E, Window, App) -> R {
        final view:T = cast model;
        return (e:E, window:Window, cx:App) -> cx.updateEntity(view, (view, cx) -> f(view, e, window, cx));
    }

    /**
     * Reads data from the platform clipboard (`App.readFromClipboard`).
     */
    public inline function readFromClipboard():Null<ClipboardItem> {
        return app.readFromClipboard();
    }

    /**
     * Writes data to the platform clipboard (`App.writeToClipboard`).
     */
    public inline function writeToClipboard(item:ClipboardItem):Void {
        app.writeToClipboard(item);
    }

    /**
     * Obtain a new `FocusHandle`, which allows you to track and manipulate the keyboard focus
     * for elements rendered within this window.
     */
    public inline function focusHandle():FocusHandle {
        return app.focusHandle();
    }

    /**
     * Schedule the given closure to be run directly after the current frame is rendered.
     */
    public function onNextFrame(window:Window, f:(T, Window, Context<T>) -> Void):Void {
        final weak = weakEntity();
        window.onNextFrame((window, cx) -> {
            final view = weak.upgrade();
            if (view != null) {
                cx.updateEntity((view : T), (view, cx) -> f(view, window, cx));
            }
        });
    }

    /**
     * Schedules the given function to be run at the end of the current effect cycle, allowing entities
     * that are currently on the stack to be returned to the app.
     */
    public function deferIn(window:Window, f:(T, Window, Context<T>) -> Void):Void {
        final weak = weakEntity();
        app.defer(cx -> {
            final view = weak.upgrade();
            if (view != null && !window.isDestroyed()) {
                cx.updateEntity((view : T), (view, cx) -> f(view, window, cx));
            }
        });
    }

    /**
     * Observe another entity for changes to its state, as tracked by `notify`, with the window.
     */
    public function observeIn<W:Model>(observed:Entity<W>, window:Window, onNotify:(T, Entity<W>, Window, Context<T>) -> Void):Subscription {
        final observer = this;
        return ownSubscription(app.observeInternal(observed, (entity, cx) -> {
            if (!observer.isAlive() || window.isDestroyed())
                return false;
            cx.updateEntity((cast observer.model : T), (view, cx) -> onNotify(view, entity, window, cx));
            return true;
        }));
    }

    /**
     * Subscribe to events emitted by another entity, with the window.
     */
    public function subscribeIn<T2:Model, E>(emitter:Entity<T2>, eventType:EventType<E>, window:Window, onEvent:(T, Entity<T2>, E, Window, Context<T>) -> Void):Subscription {
        final subscriber = this;
        return ownSubscription(app.subscribeInternal(emitter, eventType, (emitter, event, cx) -> {
            if (!subscriber.isAlive() || window.isDestroyed())
                return false;
            cx.updateEntity((cast subscriber.model : T), (view, cx) -> onEvent(view, emitter, event, window, cx));
            return true;
        }));
    }

    /**
     * Register a callback to be invoked when the given focus handle receives focus.
     * This does not fire if the given focus handle - or one of its descendants - was previously focused.
     */
    public function onFocus(handle:FocusHandle, window:Window, listener:(T, Window, Context<T>) -> Void):Subscription {
        final focusId = handle.id;
        return newFocusSubscription(window, (event, window, view, cx) -> {
            if (event.previousLast() != focusId && event.currentLast() == focusId) {
                listener(view, window, cx);
            }
        });
    }

    /**
     * Register a callback to be invoked when the given focus handle or one of its descendants receives focus.
     * This does not fire if the given focus handle - or one of its descendants - was previously focused.
     */
    public function onFocusIn(handle:FocusHandle, window:Window, listener:(T, Window, Context<T>) -> Void):Subscription {
        final focusId = handle.id;
        return newFocusSubscription(window, (event, window, view, cx) -> {
            if (event.isFocusIn(focusId)) {
                listener(view, window, cx);
            }
        });
    }

    /**
     * Register a callback to be invoked when the given focus handle loses focus.
     */
    public function onBlur(handle:FocusHandle, window:Window, listener:(T, Window, Context<T>) -> Void):Subscription {
        final focusId = handle.id;
        return newFocusSubscription(window, (event, window, view, cx) -> {
            if (event.previousLast() == focusId && event.currentLast() != focusId) {
                listener(view, window, cx);
            }
        });
    }

    /**
     * Register a callback to be invoked when the given focus handle or one of its descendants loses focus.
     */
    public function onFocusOut(handle:FocusHandle, window:Window, listener:(T, FocusOutEvent, Window, Context<T>) -> Void):Subscription {
        final focusId = handle.id;
        return newFocusSubscription(window, (event, window, view, cx) -> {
            final blurredId = event.previousLast();
            if (blurredId != -1 && event.isFocusOut(focusId)) {
                listener(view, new FocusOutEvent(blurredId), window, cx);
            }
        });
    }

    /**
     * Register a callback to be invoked when the window is activated or deactivated.
     */
    public function observeWindowActivation(window:Window, callback:(T, Window, Context<T>) -> Void):Subscription {
        final self = this;
        final result = window.newActivationObserver((window, cx) -> {
            if (!self.isAlive())
                return false;
            cx.updateEntity((cast self.model : T), (view, cx) -> callback(view, window, cx));
            return true;
        });
        result.activate();
        return ownSubscription(result.subscription);
    }

    /**
     * Register a callback to be invoked when the window loses focus (nothing is focused anymore).
     */
    public function onFocusLost(window:Window, listener:(T, Window, Context<T>) -> Void):Subscription {
        final self = this;
        final result = window.newFocusLostListener((window, cx) -> {
            if (!self.isAlive())
                return false;
            cx.updateEntity((cast self.model : T), (view, cx) -> listener(view, window, cx));
            return true;
        });
        defer(_ -> result.activate());
        return ownSubscription(result.subscription);
    }

    function newFocusSubscription(window:Window, f:(WindowFocusEvent, Window, T, Context<T>) -> Void):Subscription {
        final self = this;
        final result = window.newFocusListener((event, window, cx) -> {
            if (!self.isAlive())
                return false;
            cx.updateEntity((cast self.model : T), (view, cx) -> f(event, window, view, cx));
            return true;
        });
        defer(_ -> result.activate());
        return ownSubscription(result.subscription);
    }

}
