// Ported from gpui-pre 0.3.10: src/app.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.ds.IntMap;
import tracker.Autorun;

/**
 * Contains the state of the full application, and passed as a reference to a
 * variety of callbacks. Other contexts such as `Context<T>` give access to it.
 *
 * There is one `App` per Ceramic app (`App.current`), but more can be created
 * (tests give each one its own `TestDispatcher`).
 *
 * Every callback run by the app (observers, event subscribers, release
 * observers, deferred functions, global observers) runs with tracker capture
 * disabled, so a handler never subscribes the view being rendered.
 */
class App {

    static var _current:Null<App> = null;

    /**
     * The current app: the last one created, or a default one created on first
     * access (with a `CeramicDispatcher`).
     */
    public static var current(get, set):App;
    static function get_current():App {
        if (_current == null) {
            _current = new App();
        }
        return _current;
    }
    static function set_current(current:App):App {
        return _current = current;
    }

    static final typeIds:Map<String, Int> = new Map();

    static var nextTypeId:Int = 1;

    /**
     * A small integer identifying a class (Rust: `TypeId`), used as key for
     * globals and new entity observers.
     */
    public static function typeIdOf(type:Class<Dynamic>):Int {
        return typeIdOfName(Type.getClassName(type));
    }

    static function typeIdOfName(name:String):Int {
        var id = typeIds.get(name);
        if (id == null) {
            id = nextTypeId++;
            typeIds.set(name, id);
        }
        return id;
    }

    /**
     * The dispatcher scheduling the work of both executors.
     */
    public final dispatcher:PlatformDispatcher;

    final _backgroundExecutor:BackgroundExecutor;

    final _foregroundExecutor:ForegroundExecutor;

    var nextEntityId:Int = 1;

    var pendingEffects:Array<Effect> = [];

    var pendingEffectsHead:Int = 0;

    final pendingNotifications:IntMap<Bool> = new IntMap();

    final pendingGlobalNotifications:IntMap<Bool> = new IntMap();

    var pendingUpdates:Int = 0;

    var pendingReleases:Array<Model> = [];

    @:allow(gpui)
    final observers:SubscriberSet<App->Bool> = new SubscriberSet();

    @:allow(gpui)
    final eventListeners:SubscriberSet<EventListener> = new SubscriberSet();

    @:allow(gpui)
    final releaseListeners:SubscriberSet<(Model, App) -> Void> = new SubscriberSet();

    @:allow(gpui)
    final globalObservers:SubscriberSet<App->Bool> = new SubscriberSet();

    @:allow(gpui)
    final newEntityObservers:SubscriberSet<(Model, App) -> Void> = new SubscriberSet();

    final globalsByType:IntMap<GlobalCell> = new IntMap();

    final windowInvalidatorsByEntity:IntMap<IntMap<WindowInvalidator>> = new IntMap();

    /**
     * Called when a `RefreshWindows` effect is applied. Plugged by windows (step 7).
     */
    public var onRefreshWindows:Null<App->Void> = null;

    /**
     * Called each time `flushEffects` has emptied the effect queue. Windows (step 7)
     * use it to schedule a frame when they are dirty.
     */
    public var onEffectsFlushed:Null<App->Void> = null;

/// Text, assets and SVG

    static var _defaultTextSystem:Null<TextSystem> = null;

    static var _defaultAssetSource:Null<CeramicAssetSource> = null;

    /**
     * The text system shared by apps that don't set their own: a
     * `CeramicTextSystem` where `.SystemUIFont` is Inter. The gpui plugin
     * adds its bundled fonts (Inter and JetBrains Mono) to it once the
     * default assets are loaded (unless `gpui_no_default_fonts` is defined).
     * On native desktop targets, characters missing from every added font
     * are taken from the fonts of the operating system
     * (`gpui.platform.SystemFontFallback`, loaded on first use; define
     * `gpui_no_system_fonts` to skip). In browsers (clay web, Electron),
     * graphemes missing from the added fonts are drawn by the browser like
     * gpui-pre-web's Canvas fallback, with GPUI's default policy
     * (`CanvasFontFallback.Emoji`; change it with
     * `CeramicTextSystem.canvasFontFallback`, define
     * `gpui_no_canvas_fallback` to skip).
     */
    public static function defaultTextSystem():TextSystem {
        if (_defaultTextSystem == null) {
            final platform = new gpui.platform.CeramicTextSystem('Inter');
            #if (sys && !gpui_no_system_fonts && !ios && !android && !tvos)
            platform.systemFallback = new gpui.platform.SystemFontFallback();
            #end
            #if (js && !gpui_no_canvas_fallback)
            if (gpui.platform.CanvasText.BrowserCanvasText.available())
                platform.canvasText = new gpui.platform.CanvasText.BrowserCanvasText();
            #end
            _defaultTextSystem = new TextSystem(platform);
        }
        return _defaultTextSystem;
    }

    /**
     * The asset source shared by apps that don't set their own.
     */
    public static function defaultAssetSource():CeramicAssetSource {
        if (_defaultAssetSource == null) {
            _defaultAssetSource = new CeramicAssetSource();
        }
        return _defaultAssetSource;
    }

    var _textSystem:Null<TextSystem> = null;

    var _assetSource:Null<AssetSource> = null;

    var _svgRenderer:Null<SvgRenderer> = null;

    #if gpui_inspector
    @:allow(gpui)
    var inspectorRenderer:Null<Inspector.InspectorRenderer> = null;

    @:allow(gpui)
    final inspectorElementRegistry:Inspector.InspectorElementRegistry = new Inspector.InspectorElementRegistry();

    /**
     * Sets the renderer for the inspector.
     */
    public function setInspectorRenderer(f:Inspector.InspectorRenderer):Void {
        inspectorRenderer = f;
    }

    /**
     * Registers a renderer specific to an inspector state (states of type
     * `type`, such as `DivInspectorState`).
     */
    public function registerInspectorElement<T>(type:Class<T>, factory:(Window, App) -> ((InspectorElementId, T, Window, App) -> IntoElement)):Void {
        inspectorElementRegistry.register(type, factory);
    }

    /**
     * The active window of this app (Rust `active_window`): the most
     * recently opened window of this app that is active.
     */
    public function activeWindow():Null<Window> {
        return Window.activeWindowOf(this);
    }
    #end

    /**
     * The text system of this app (Rust `cx.text_system()`). Add fonts with
     * `cx.textSystem().addFonts([bytes])`.
     */
    public function textSystem():TextSystem {
        if (_textSystem == null) {
            _textSystem = defaultTextSystem();
        }
        return _textSystem;
    }

    /**
     * Replaces the text system of this app (before opening windows).
     */
    public function setTextSystem(textSystem:TextSystem):Void {
        _textSystem = textSystem;
    }

    /**
     * The asset source of this app (Rust `cx.asset_source()`), used by
     * `svg()` and `img()` paths.
     */
    public function assetSource():AssetSource {
        if (_assetSource == null) {
            _assetSource = defaultAssetSource();
        }
        return _assetSource;
    }

    /**
     * Replaces the asset source of this app (Rust `Application::with_assets`).
     */
    public function setAssetSource(assetSource:AssetSource):Void {
        _assetSource = assetSource;
        _svgRenderer = null;
    }

    /**
     * The SVG renderer of this app.
     */
    public function svgRenderer():SvgRenderer {
        if (_svgRenderer == null) {
            _svgRenderer = new SvgRenderer(assetSource(), textSystem());
        }
        return _svgRenderer;
    }

    public function new(?dispatcher:PlatformDispatcher) {
        this.dispatcher = dispatcher != null ? dispatcher : new CeramicDispatcher();
        _backgroundExecutor = new BackgroundExecutor(this.dispatcher);
        _foregroundExecutor = new ForegroundExecutor(this.dispatcher);
        syncedAnimationEpoch = _backgroundExecutor.now();
        _current = this;
    }

/// Updates and effects

    /**
     * Runs `update` with effects batched: effects pushed during the update (and
     * nested updates) are flushed when the outermost update finishes.
     */
    public function update<R>(update:App->R):R {
        startUpdate();
        var result:R;
        try {
            result = update(this);
        }
        catch (e:haxe.Exception) {
            pendingUpdates--;
            throw gpui.util.Exceptions.rethrow(e);
        }
        finishUpdate();
        return result;
    }

    @:allow(gpui)
    inline function startUpdate():Void {
        pendingUpdates++;
    }

    @:allow(gpui)
    function finishUpdate():Void {
        if (pendingUpdates == 1) {
            try {
                flushEffects();
            }
            catch (e:haxe.Exception) {
                pendingUpdates--;
                throw gpui.util.Exceptions.rethrow(e);
            }
        }
        pendingUpdates--;
    }

    /**
     * `true` while inside `update` (or while effects are flushed).
     */
    public inline function isUpdating():Bool {
        return pendingUpdates > 0;
    }

    @:allow(gpui)
    function pushEffect(effect:Effect):Void {
        switch effect {
            case Notify(emitter):
                if (pendingNotifications.exists(emitter))
                    return;
                pendingNotifications.set(emitter, true);
            case NotifyGlobalObservers(globalType):
                if (pendingGlobalNotifications.exists(globalType))
                    return;
                pendingGlobalNotifications.set(globalType, true);
            case _:
        }

        pendingEffects.push(effect);

        // Outside of any update (a timer, a tracker reaction...): flush right away
        if (pendingUpdates == 0) {
            startUpdate();
            finishUpdate();
        }
    }

    /**
     * Called at the end of `update` to complete any side effects such as
     * notifying observers, emitting events, etc. Effects can themselves cause
     * effects, so we continue looping until all effects are processed.
     */
    function flushEffects():Void {
        while (true) {
            releaseDroppedEntities();
            if (pendingEffectsHead < pendingEffects.length) {
                final effect = pendingEffects[pendingEffectsHead];
                pendingEffects[pendingEffectsHead] = null;
                pendingEffectsHead++;
                switch effect {
                    case Notify(emitter):
                        applyNotifyEffect(emitter);
                    case Emit(emitter, event):
                        applyEmitEffect(emitter, event);
                    case RefreshWindows:
                        applyRefreshEffect();
                    case NotifyGlobalObservers(globalType):
                        applyNotifyGlobalObserversEffect(globalType);
                    case Defer(callback):
                        applyDeferEffect(callback);
                    case EntityCreated(entity, typeId):
                        applyEntityCreatedEffect(entity, typeId);
                }
            }
            else {
                pendingEffects.resize(0);
                pendingEffectsHead = 0;
                if (onEffectsFlushed != null) {
                    runUnobserved(onEffectsFlushed);
                }
                if (pendingEffects.length == 0 && pendingReleases.length == 0) {
                    break;
                }
            }
        }
    }

    /**
     * Called at the start of each iteration of `flushEffects` to release
     * destroyed entities. We invoke any release observers, then dispose what
     * each entity owns (which may release child entities in turn).
     */
    function releaseDroppedEntities():Void {
        while (pendingReleases.length > 0) {
            final dropped = pendingReleases;
            pendingReleases = [];
            for (entity in dropped) {
                final slot = entity._slot;
                final entityId = slot.id;
                observers.remove(entityId);
                eventListeners.remove(entityId);
                windowInvalidatorsByEntity.remove(entityId);
                for (releaseCallback in releaseListeners.remove(entityId)) {
                    Autorun.unobserve();
                    try {
                        releaseCallback(entity, this);
                    }
                    catch (e:haxe.Exception) {
                        Autorun.reobserve();
                        throw gpui.util.Exceptions.rethrow(e);
                    }
                    Autorun.reobserve();
                }
                slot.releaseOwned();
                if (slot.parent != null) {
                    slot.parent.removeOwnedEntity(entity);
                    slot.parent = null;
                }
            }
        }
    }

    function applyNotifyEffect(emitter:Int):Void {
        pendingNotifications.remove(emitter);
        observers.retain(emitter, invokeHandler);
    }

    function applyEmitEffect(emitter:Int, event:Dynamic):Void {
        eventListeners.retain(emitter, listener -> {
            if (listener.eventType.matches(event)) {
                Autorun.unobserve();
                var keep = false;
                try {
                    keep = listener.handler(event, this);
                }
                catch (e:haxe.Exception) {
                    Autorun.reobserve();
                    throw gpui.util.Exceptions.rethrow(e);
                }
                Autorun.reobserve();
                return keep;
            }
            return true;
        });
    }

    function applyRefreshEffect():Void {
        if (onRefreshWindows != null) {
            runUnobserved(onRefreshWindows);
        }
    }

    function applyNotifyGlobalObserversEffect(globalType:Int):Void {
        pendingGlobalNotifications.remove(globalType);
        globalObservers.retain(globalType, invokeHandler);
    }

    function applyDeferEffect(callback:App->Void):Void {
        runUnobserved(callback);
    }

    function applyEntityCreatedEffect(entity:Model, typeId:Int):Void {
        newEntityObservers.retain(typeId, observer -> {
            if (entity.destroyed)
                return true;
            Autorun.unobserve();
            try {
                observer(entity, this);
            }
            catch (e:haxe.Exception) {
                Autorun.reobserve();
                throw gpui.util.Exceptions.rethrow(e);
            }
            Autorun.reobserve();
            return true;
        });
    }

    function invokeHandler(handler:App->Bool):Bool {
        Autorun.unobserve();
        var keep = false;
        try {
            keep = handler(this);
        }
        catch (e:haxe.Exception) {
            Autorun.reobserve();
            throw gpui.util.Exceptions.rethrow(e);
        }
        Autorun.reobserve();
        return keep;
    }

    function runUnobserved(callback:App->Void):Void {
        Autorun.unobserve();
        try {
            callback(this);
        }
        catch (e:haxe.Exception) {
            Autorun.reobserve();
            throw gpui.util.Exceptions.rethrow(e);
        }
        Autorun.reobserve();
    }

    /**
     * Schedules all windows in the application to be redrawn. This can be called
     * multiple times in an update cycle and still result in a single redraw.
     */
    public function refreshWindows():Void {
        pushEffect(RefreshWindows);
    }

    /**
     * Schedules the given function to be run at the end of the current effect cycle,
     * allowing entities that are currently on the stack to be returned to the app.
     */
    public function defer(f:App->Void):Void {
        pushEffect(Defer(f));
    }

    /**
     * Tell GPUI that an entity has changed and observers of it should be notified.
     * Windows displaying the entity mark its view dirty.
     *
     * Like GPUI (`App::notify`, `WindowInvalidator::invalidate_view`), an
     * entity accessed during the last draw of a window (a view it rendered,
     * an entity read or updated while it drew) is invalidated in that window,
     * and the `Notify` effect is pushed only by a window that is not drawing:
     * a notify sent while that window draws reaches no observer (the view is
     * rendered again on the next frame, whatever causes it). An entity no
     * window accessed only pushes the effect.
     */
    public function notify(entityId:Int):Void {
        final invalidators = windowInvalidatorsByEntity.get(entityId);
        var live = false;
        var effect = false;
        if (invalidators != null) {
            for (invalidator in invalidators) {
                live = true;
                if (invalidator.invalidateView(entityId, this)) {
                    effect = true;
                }
            }
        }
        if (effect || !live) {
            pushEffect(Notify(entityId));
        }
    }

/// Window invalidators

    /**
     * Registers the invalidator of a window displaying the given entity
     * (GPUI's `window_invalidators_by_entity`).
     */
    public function addWindowInvalidator(entityId:Int, windowId:Int, invalidator:WindowInvalidator):Void {
        var invalidators = windowInvalidatorsByEntity.get(entityId);
        if (invalidators == null) {
            invalidators = new IntMap();
            windowInvalidatorsByEntity.set(entityId, invalidators);
        }
        invalidators.set(windowId, invalidator);
    }

    /**
     * Unregisters the invalidator of a window for the given entity.
     */
    public function removeWindowInvalidator(entityId:Int, windowId:Int):Void {
        final invalidators = windowInvalidatorsByEntity.get(entityId);
        if (invalidators != null) {
            invalidators.remove(windowId);
        }
    }

/// Entities

    /**
     * Builds an entity that is owned by the application (Rust: `cx.new(|cx| ...)`).
     * The given function is invoked with the `Context` of the new entity.
     */
    public function newEntity<T:Model>(build:Context<T>->T):Entity<T> {
        return newEntityIn(build, null);
    }

    @:allow(gpui)
    function newEntityIn<T:Model>(build:Context<T>->T, parent:Null<EntitySlot>):Entity<T> {
        startUpdate();
        final cx = new Context<T>(this, nextEntityId++);
        var entity:T = null;
        try {
            entity = build(cx);
            attach(entity, cx, parent);
            Window.recordAccess(cx.id);
        }
        catch (e:haxe.Exception) {
            pendingUpdates--;
            throw gpui.util.Exceptions.rethrow(e);
        }
        final typeId = typeIdOf(Type.getClass(entity));
        if (newEntityObservers.hasSubscribers(typeId)) {
            pushEffect(EntityCreated(entity, typeId));
        }
        finishUpdate();
        return entity;
    }

    /**
     * Attaches a model constructed directly (without `newEntity`) to this app.
     */
    @:allow(gpui)
    function attachEntity(model:Model):Void {
        if (model._slot != null)
            return;
        attach(model, new Context<Model>(this, nextEntityId++), null);
    }

    function attach(model:Model, slot:EntitySlot, parent:Null<EntitySlot>):Void {
        if (model == null) {
            throw 'Entity build function returned null';
        }
        if (model._slot != null) {
            throw 'This model is already an entity (id ${model._slot.id})';
        }
        model._slot = slot;
        slot.model = model;
        if (parent != null) {
            slot.parent = parent;
            parent.ownEntity(model);
        }
    }

    /**
     * Updates the given entity. The function is passed the entity along with its
     * `Context`, inside an update (effects are batched).
     */
    public function updateEntity<T:Model, R>(entity:T, update:(T, Context<T>) -> R):R {
        final cx:Context<T> = cast entity.slot();
        Window.recordAccess(cx.id);
        startUpdate();
        var result:R;
        try {
            result = update(entity, cx);
        }
        catch (e:haxe.Exception) {
            pendingUpdates--;
            throw gpui.util.Exceptions.rethrow(e);
        }
        finishUpdate();
        return result;
    }

    @:allow(gpui)
    function releaseEntity(entity:Model):Void {
        pendingReleases.push(entity);
        if (pendingUpdates == 0) {
            startUpdate();
            finishUpdate();
        }
    }

/// Observers and subscribers

    /**
     * Arrange a callback to be invoked when the given entity calls `notify` on its
     * respective context.
     */
    public function observe<W:Model>(entity:Entity<W>, onNotify:(Entity<W>, App) -> Void):Subscription {
        return observeInternal(entity, (entity, cx) -> {
            onNotify(entity, cx);
            return true;
        });
    }

    @:allow(gpui)
    function newObserver(key:Int, value:App->Bool):Subscription {
        final subscriber = observers.insert(key, value);
        defer(_ -> subscriber.activate());
        return subscriber.subscription;
    }

    @:allow(gpui)
    function observeInternal<W:Model>(entity:Entity<W>, onNotify:(Entity<W>, App) -> Bool):Subscription {
        final handle = entity.downgrade();
        return newObserver(entity.entityId(), cx -> {
            final entity = handle.upgrade();
            if (entity != null) {
                return onNotify(entity, cx);
            }
            return false;
        });
    }

    /**
     * Arrange for the given callback to be invoked whenever the given entity emits
     * an event of the given type.
     */
    public function subscribe<T:Model, E>(entity:Entity<T>, eventType:EventType<E>, onEvent:(Entity<T>, E, App) -> Void):Subscription {
        return subscribeInternal(entity, eventType, (entity, event, cx) -> {
            onEvent(entity, event, cx);
            return true;
        });
    }

    @:allow(gpui)
    function newSubscription(key:Int, value:EventListener):Subscription {
        final subscriber = eventListeners.insert(key, value);
        defer(_ -> subscriber.activate());
        return subscriber.subscription;
    }

    @:allow(gpui)
    function subscribeInternal<T:Model, E>(entity:Entity<T>, eventType:EventType<E>, onEvent:(Entity<T>, E, App) -> Bool):Subscription {
        final handle = entity.downgrade();
        return newSubscription(entity.entityId(), new EventListener(cast eventType, (event, cx) -> {
            final entity = handle.upgrade();
            if (entity != null) {
                return onEvent(entity, event, cx);
            }
            return false;
        }));
    }

    /**
     * Observe the release of an entity. The callback is invoked when the entity is
     * destroyed, before what it owns is disposed.
     */
    public function observeRelease<T:Model>(entity:Entity<T>, onRelease:(T, App) -> Void):Subscription {
        final subscriber = releaseListeners.insert(entity.entityId(), (entity, cx) -> onRelease(cast entity, cx));
        subscriber.activate();
        return subscriber.subscription;
    }

    /**
     * Arrange for the given function to be invoked whenever an entity of the
     * specified class is created (exact class, subclasses are not included).
     */
    public function observeNew<T:Model>(type:Class<T>, onNew:(T, Context<T>) -> Void):Subscription {
        final subscriber = newEntityObservers.insert(typeIdOf(type), (entity, cx) -> {
            cx.updateEntity((cast entity : T), onNew);
        });
        subscriber.activate();
        return subscriber.subscription;
    }

/// Executors

    /**
     * Returns the background executor.
     */
    public inline function backgroundExecutor():BackgroundExecutor {
        return _backgroundExecutor;
    }

    /**
     * Returns the foreground executor.
     */
    public inline function foregroundExecutor():ForegroundExecutor {
        return _foregroundExecutor;
    }

    /**
     * Spawns an async block on the main thread. The closure is invoked with the
     * app (`AsyncApp`) and returns the task it ends with
     * (see `ForegroundExecutor.spawn`).
     */
    public function spawn<R>(f:AsyncApp->Task<R>):Task<R> {
        return _foregroundExecutor.spawn(() -> f(this));
    }

    /**
     * Whether the app runs on a `TestDispatcher`.
     */
    public inline function isTest():Bool {
        return _backgroundExecutor.isTest();
    }

/// Globals

    function globalCell(type:Class<Dynamic>):GlobalCell {
        return globalCellById(typeIdOf(type));
    }

    function globalCellById(typeId:Int):GlobalCell {
        var cell = globalsByType.get(typeId);
        if (cell == null) {
            cell = new GlobalCell();
            globalsByType.set(typeId, cell);
        }
        return cell;
    }

    /**
     * Check whether a global of the given type has been assigned.
     * Inside a tracker capture, the view reacts when it is set or removed.
     */
    public function hasGlobal<G>(type:Class<G>):Bool {
        return globalCell(type).value != null;
    }

    /**
     * Access the global of the given type. Throws if a global for that type has
     * not been assigned. Inside a tracker capture (render), the view reacts to
     * `setGlobal`, `updateGlobal` and `globalMut` on this type.
     */
    public function global<G>(type:Class<G>):G {
        final value:G = globalCell(type).value;
        if (value == null) {
            throw 'no state of type ${Type.getClassName(type)} exists';
        }
        return value;
    }

    /**
     * Access the global of the given type if a value has been assigned.
     */
    public function tryGlobal<G>(type:Class<G>):Null<G> {
        return globalCell(type).value;
    }

    /**
     * Read the global of the given type with the given function.
     */
    public function readGlobal<G, R>(type:Class<G>, read:(G, App) -> R):R {
        return read(global(type), this);
    }

    /**
     * Access the global of the given type mutably. Global observers and views
     * reading it are notified (the reaction happens later, after the mutation).
     */
    public function globalMut<G>(type:Class<G>):G {
        final typeId = typeIdOf(type);
        final cell = globalCellById(typeId);
        final value:G = @:privateAccess cell.unobservedValue;
        if (value == null) {
            throw 'no state of type ${Type.getClassName(type)} exists';
        }
        pushEffect(NotifyGlobalObservers(typeId));
        cell.invalidateValue();
        return value;
    }

    /**
     * Access the global of the given type mutably, creating it with its default
     * constructor if it has not been assigned yet.
     */
    public function defaultGlobal<G>(type:Class<G>):G {
        final typeId = typeIdOf(type);
        final cell = globalCellById(typeId);
        var value:G = @:privateAccess cell.unobservedValue;
        pushEffect(NotifyGlobalObservers(typeId));
        if (value == null) {
            value = Type.createInstance(type, []);
            cell.value = value;
        }
        else {
            cell.invalidateValue();
        }
        return value;
    }

    /**
     * Sets the value of the global of the given type (by default the class of `global`).
     */
    public function setGlobal<G>(global:G, ?type:Class<G>):Void {
        if (type == null) {
            type = Type.getClass(global);
        }
        final typeId = typeIdOf(type);
        final cell = globalCellById(typeId);
        pushEffect(NotifyGlobalObservers(typeId));
        if (@:privateAccess cell.unobservedValue == global) {
            cell.invalidateValue();
        }
        else {
            cell.value = global;
        }
    }

    /**
     * Remove the global of the given type from the app context and return it.
     */
    public function removeGlobal<G>(type:Class<G>):G {
        final typeId = typeIdOf(type);
        final cell = globalCellById(typeId);
        final value:G = @:privateAccess cell.unobservedValue;
        if (value == null) {
            throw 'no global added for ${Type.getClassName(type)}';
        }
        pushEffect(NotifyGlobalObservers(typeId));
        cell.value = null;
        return value;
    }

    /**
     * Updates the global of the given type in place. Global observers and views
     * reading it are notified.
     */
    public function updateGlobal<G, R>(type:Class<G>, update:(G, App) -> R):R {
        final typeId = typeIdOf(type);
        final cell = globalCellById(typeId);
        final value:G = @:privateAccess cell.unobservedValue;
        if (value == null) {
            throw 'no global registered of type ${Type.getClassName(type)}';
        }
        startUpdate();
        var result:R;
        try {
            result = update(value, this);
        }
        catch (e:haxe.Exception) {
            pendingUpdates--;
            throw gpui.util.Exceptions.rethrow(e);
        }
        pushEffect(NotifyGlobalObservers(typeId));
        cell.invalidateValue();
        finishUpdate();
        return result;
    }

    /**
     * Register a callback to be invoked when a global of the given type is updated.
     */
    public function observeGlobal<G>(type:Class<G>, f:App->Void):Subscription {
        final subscriber = globalObservers.insert(typeIdOf(type), cx -> {
            f(cx);
            return true;
        });
        defer(_ -> subscriber.activate());
        return subscriber.subscription;
    }

/// Key bindings and actions (step 9)

    /**
     * The key bindings of the app (Rust: `Rc<RefCell<Keymap>>`), shared with
     * the windows' dispatch trees.
     */
    @:allow(gpui)
    final keymap:Keymap = new Keymap();

    var _actions:Null<ActionRegistry> = null;

    /**
     * The registry building actions by name, created on first use from every
     * registered action.
     */
    public var actions(get, never):ActionRegistry;
    function get_actions():ActionRegistry {
        if (_actions == null) {
            _actions = new ActionRegistry();
        }
        return _actions;
    }

    /**
     * Maps keybinding keystrokes to the platform keyboard layout.
     */
    public var keyboardMapper:PlatformKeyboardMapper = DummyKeyboardMapper.instance;

    /**
     * Register key bindings.
     */
    public function bindKeys(bindings:Array<KeyBinding>):Void {
        keymap.addBindings(bindings);
        pushEffect(RefreshWindows);
    }

    /**
     * Clear all key bindings in the app.
     */
    public function clearKeyBindings():Void {
        keymap.clear();
        pushEffect(RefreshWindows);
    }

    /**
     * Get all key bindings in the app.
     */
    public inline function keyBindings():Keymap {
        return keymap;
    }

    /**
     * Build an action from some arbitrary data, typically a keymap entry
     * (`data` is a value parsed by `haxe.Json.parse`). Throws `ActionBuildError`.
     */
    public function buildAction(name:String, ?data:Dynamic):Action {
        return actions.buildAction(name, data);
    }

    /**
     * Get all action names that have been registered. Note that registration
     * only allows for actions to be built dynamically, and is unrelated to
     * binding actions in the element tree.
     */
    public function allActionNames():Array<String> {
        return actions.allActionNames();
    }

    /**
     * Returns key bindings that match the given input, without checking
     * context, in precedence order.
     */
    public function allBindingsForInput(input:Array<Keystroke>):Array<KeyBinding> {
        return keymap.allBindingsForInput(input);
    }


/// Input and focus (steps 8 and 9)

    /**
     * Whether the event being dispatched should keep propagating
     * (Rust `propagate_event`). See `stopPropagation` and `propagate`.
     */
    public var propagateEvent:Bool = true;

    /**
     * The active drag, if something is being dragged (Rust `active_drag`).
     */
    public var activeDrag:Null<AnyDrag> = null;

    var _reduceMotion:Bool = false;

    /**
     * The clock origin of synced animations (`Animation.repeatSynced()`), in seconds.
     */
    public var syncedAnimationEpoch(default, null):Float = 0;

    /**
     * Whether animations should be reduced: animation elements render a single
     * static frame (end state for oneshot animations, start state for repeating ones).
     */
    public inline function reduceMotion():Bool {
        return _reduceMotion;
    }

    /**
     * Sets whether animations should be reduced, and redraws the windows.
     */
    public function setReduceMotion(reduceMotion:Bool):Void {
        if (_reduceMotion != reduceMotion) {
            _reduceMotion = reduceMotion;
            refreshWindows();
        }
    }

    /**
     * Group hitboxes of the elements being painted (Rust global `GroupHitboxes`).
     */
    @:allow(gpui)
    final groupHitboxes:Map<String, Array<Int>> = new Map();

    final globalActionListeners:Map<String, Array<(Action, DispatchPhase, App) -> Void>> = new Map();

    final keystrokeObservers:SubscriberSet<(KeystrokeEvent, Window, App) -> Bool> = new SubscriberSet();

    final keystrokeInterceptors:SubscriberSet<(KeystrokeEvent, Window, App) -> Bool> = new SubscriberSet();

    /**
     * Event handlers propagate events by default. Call this method to stop dispatching to
     * event handlers with a lower z-index (mouse) or higher in the tree (keyboard). This is
     * the opposite of `propagate`.
     */
    public inline function stopPropagation():Void {
        propagateEvent = false;
    }

    /**
     * Action handlers stop propagation by default during the bubble phase of action dispatch
     * dispatching to action handlers higher in the element tree. This is the opposite of
     * `stopPropagation`.
     */
    public inline function propagate():Void {
        propagateEvent = true;
    }

    /**
     * Is there currently something being dragged?
     */
    public inline function hasActiveDrag():Bool {
        return activeDrag != null;
    }

    /**
     * Gets the cursor style of the currently active drag operation.
     */
    public function activeDragCursorStyle():Null<CursorStyle> {
        return activeDrag != null ? activeDrag.cursorStyle : null;
    }

    /**
     * Stops active drag and clears any related effects.
     */
    public function stopActiveDrag(window:Window):Bool {
        if (activeDrag != null) {
            activeDrag = null;
            window.refresh();
            return true;
        }
        return false;
    }

    /**
     * Obtain a new `FocusHandle`, which allows you to track and manipulate the keyboard focus
     * for elements rendered within this window.
     */
    public function focusHandle():FocusHandle {
        return new FocusHandle();
    }

    /**
     * The system clipboard used by `readFromClipboard` / `writeToClipboard`
     * (Rust: the platform). `CeramicClipboard` by default, a `TestClipboard`
     * for tests.
     */
    public var platformClipboard:PlatformClipboard = new CeramicClipboard();

    /**
     * Reads data from the platform clipboard.
     */
    public function readFromClipboard():Null<ClipboardItem> {
        return platformClipboard.readFromClipboard();
    }

    /**
     * Writes data to the platform clipboard.
     */
    public function writeToClipboard(item:ClipboardItem):Void {
        platformClipboard.writeToClipboard(item);
    }

    /**
     * Opens URLs for `openUrl` (Rust: the platform). By default, the Ceramic
     * backend's `openUrl` (the system's handler, a new tab on the web).
     */
    public var platformOpenUrl:String->Void = defaultOpenUrl;

    /**
     * Opens the given URL in the system's default handler (browser).
     */
    public function openUrl(url:String):Void {
        platformOpenUrl(url);
    }

    static function defaultOpenUrl(url:String):Void {
        ceramic.App.app.backend.openUrl(url);
    }

    /**
     * Register a global listener for actions of exactly the given class, invoked in the
     * bubble phase after the window's element listeners.
     */
    public function onAction<A:Action>(actionType:Class<A>, listener:(A, App) -> Void):Void {
        final name = Type.getClassName(actionType);
        var listeners = globalActionListeners.get(name);
        if (listeners == null) {
            listeners = [];
            globalActionListeners.set(name, listeners);
        }
        listeners.push((action, phase, cx) -> {
            if (phase == Bubble) {
                listener(cast action, cx);
            }
        });
    }

    @:allow(gpui)
    function globalActionListenersFor(actionType:Class<Dynamic>):Null<Array<(Action, DispatchPhase, App) -> Void>> {
        final listeners = globalActionListeners.get(Type.getClassName(actionType));
        return listeners != null ? listeners.copy() : null;
    }

    /**
     * Register a callback to be invoked when a keystroke is received by the application
     * in any window. Note that this fires after all other action and event mechanisms have resolved
     * and that this API will not be invoked if the event's propagation is stopped.
     */
    public function observeKeystrokes(f:(KeystrokeEvent, Window, App) -> Void):Subscription {
        final subscriber = keystrokeObservers.insert(0, (event, window, cx) -> {
            f(event, window, cx);
            return true;
        });
        subscriber.activate();
        return subscriber.subscription;
    }

    /**
     * Register a callback to be invoked when a keystroke is received by the application
     * in any window, before any other mechanism: calling `stopPropagation` stops the keystroke.
     */
    public function interceptKeystrokes(f:(KeystrokeEvent, Window, App) -> Void):Subscription {
        final subscriber = keystrokeInterceptors.insert(0, (event, window, cx) -> {
            f(event, window, cx);
            return true;
        });
        subscriber.activate();
        return subscriber.subscription;
    }

    @:allow(gpui)
    function dispatchKeystrokeObservers(keystroke:Keystroke, inputPreference:InputPreference, action:Null<Action>, contextStack:Array<KeyContext>, window:Window):Void {
        final event = new KeystrokeEvent(keystroke, inputPreference, action, contextStack);
        keystrokeObservers.retain(0, callback -> callback(event, window, this));
    }

    @:allow(gpui)
    function dispatchKeystrokeInterceptors(keystroke:Keystroke, inputPreference:InputPreference, contextStack:Array<KeyContext>, window:Window):Void {
        final event = new KeystrokeEvent(keystroke, inputPreference, null, contextStack);
        keystrokeInterceptors.retain(0, callback -> callback(event, window, this));
    }

}
