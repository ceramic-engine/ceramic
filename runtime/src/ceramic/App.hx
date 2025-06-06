package ceramic;

import backend.Backend;
import ceramic.Assets;
import ceramic.BitmapFont;
import ceramic.CollectionEntry;
import ceramic.ConvertField;
import ceramic.Platform;
import ceramic.Settings;
import ceramic.Shortcuts.*;
import ceramic.Texture;
import haxe.CallStack;
import tracker.Tracker;

using ceramic.Extensions;
#if hxtelemetry
import hxtelemetry.HxTelemetry;
#end

#if clay_sdl
import clay.sdl.SDL;
#end

#if (!ceramic_cppia_host && !ceramic_no_bind_assets)
import assets.AllAssets;
#end


/**
 * `App` class is the root instance of any ceramic app.
 */
#if !macro
@:build(ceramic.macros.AppMacro.build())
#end
@:allow(ceramic.Visual)
@:allow(ceramic.Screen)
@:allow(ceramic.Entity)
@:allow(ceramic.Timer)
#if lua
@dynamicEvents
@:dce
#end
class App extends Entity {

/// Shared instances

    /**
     * Shared `App` instance singleton.
     */
    public static var app(get,null):App;
    static inline function get_app():App { return app; }

/// Events

    /**
     * Fired when the app is ready
     * and the game logic can be started.
     */
    @event function ready();

    /**
     * Fired as many times as there are frames per seconds.
     * It is in sync with screen FPS but used for everything that needs
     * to get updated depending on time (ceramic.Timer relies on it).
     * Use this event to update your contents before they get drawn again.
     * @param delta The elapsed delta time since last frame
     */
    @event function update(delta:Float);

    /**
     * Fired right before update event and
     * can be used when you want to run garantee your code
     * will be run before regular update event.
     * @param delta The elapsed delta time since last frame
     */
    @event function preUpdate(delta:Float);

    /**
     * Fired right after update event and
     * can be used when you want to run garantee your code
     * will be run after regular update event.
     * @param delta The elapsed delta time since last frame
     */
    @event function postUpdate(delta:Float);

    /**
     * Fired right before default assets are being loaded.
     * @param assets
     *      The `Assets` instance used to load default assets.
     *      If you add custom assets to this instance, they will be loaded as well.
     */
    @event function defaultAssetsLoad(assets:Assets);

    /**
     * Fired when the app hits an critical (uncaught) error.
     * Can be used to perform custom crash reporting.
     * If this even is handled, app exit should be performed by the event handler.
     * @param error The error
     * @param stack The stack trace of the error
     */
    @event function criticalError(error:Dynamic, stack:Array<StackItem>);

    /**
     * Fired when the app will enter background state.
     *
     * CAUTION: Can execute outside main thread!
     */
    @event @synchronized function beginEnterBackground();

    /**
     * Fired when the app did finish entering background state.
     *
     * CAUTION: Can execute outside main thread!
     */
    @event @synchronized function finishEnterBackground();

    /**
     * Fired when the app will enter foreground state.
     *
     * CAUTION: Can execute outside main thread!
     */
    @event @synchronized function beginEnterForeground();

    /**
     * Fired when the app did finish entering foreground state.
     *
     * CAUTION: Can execute outside main thread!
     */
    @event @synchronized function finishEnterForeground();

    /**
     * Fired right before sorting all visuals.
     * Visual are sorted at each frame depending on their properties:
     * depth, texture, blending, shader...
     */
    @event function beginSortVisuals();

    /**
     * Fired right after all visuals have been sort.
     */
    @event function finishSortVisuals();

    /**
     * Fired right before drawing phase of visuals.
     */
    @event function beginDraw();

    /**
     * Fired right after drawing phase of visuals.
     */
    @event function finishDraw();

    /**
     * Fired if the app is running low on memory.
     * (not be implemented by all platforms/targets).
     *
     * CAUTION: Can execute outside main thread!
     */
    @event @synchronized function lowMemory();

    /**
     * Fired when the app terminates.
     *
     * CAUTION: Can execute outside main thread!
     */
    @event @synchronized function terminate();

/// Immediate update system

    /**
     * Array of callbacks to be executed immediately before the next frame.
     * These callbacks are guaranteed to run before visual updates and rendering.
     */
    var immediateCallbacks:Array<Void->Void> = [];

    /**
     * Current capacity of immediate callbacks array to optimize array operations
     */
    var immediateCallbacksCapacity:Int = 0;

    /**
     * Current number of pending immediate callbacks
     */
    var immediateCallbacksLen:Int = 0;

    /**
     * Array of callbacks to be executed after all immediate callbacks are done
     */
    var postFlushImmediateCallbacks:Array<Void->Void> = [];

    /**
     * Current capacity of post flush immediate callbacks array
     */
    var postFlushImmediateCallbacksCapacity:Int = 0;

    /**
     * Current number of pending post flush immediate callbacks
     */
    var postFlushImmediateCallbacksLen:Int = 0;

#if ceramic_use_component_initializers
    /**
     * Map of component initializers used to create components from serialized data
     */
    public var componentInitializers:Map<String,Array<Dynamic>->Component> = new Map();
#end

#if hxtelemetry
    var hxt:HxTelemetry;
#end

    @:noCompletion public var loaders:Array<(done:()->Void)->Void> = [];

    /**
     * Schedule immediate callback that is garanteed to be executed before the next time frame
     * (before elements are drawn onto screen)
     * @param owner Owner of this callback, allowing to cancel callback if owner is destroyed
     * @param handleImmediate The callback to execute
     */
    extern inline overload public function onceImmediate(owner:Entity, handleImmediate:Void->Void #if ceramic_debug_immediate , ?pos:haxe.PosInfos #end):Void {

        _onceImmediateWithOwner(owner, handleImmediate #if ceramic_debug_immediate , pos #end);

    }

    /**
     * Schedule immediate callback that is garanteed to be executed before the next time frame
     * (before elements are drawn onto screen)
     * @param handleImmediate The callback to execute
     */
    extern inline overload public function onceImmediate(handleImmediate:Void->Void #if ceramic_debug_immediate , ?pos:haxe.PosInfos #end):Void {

        _onceImmediate(handleImmediate #if ceramic_debug_immediate , pos #end);

    }

    function _onceImmediateWithOwner(owner:Entity, handleImmediate:Void->Void #if ceramic_debug_immediate , ?pos:haxe.PosInfos #end):Void {

        _onceImmediate(function() {
            if (owner == null || !owner.destroyed) {
                handleImmediate();
            }
        } #if ceramic_debug_immediate , pos #end);

    }

    function _onceImmediate(handleImmediate:Void->Void #if ceramic_debug_immediate , ?pos:haxe.PosInfos #end):Void {

        if (handleImmediate == null) {
            throw 'Immediate callback should not be null!';
        }

        #if ceramic_debug_immediate
        immediateCallbacks[immediateCallbacksLen++] = function() {
            haxe.Log.trace('immediate flush', pos);
            handleImmediate();
        };
        #else
        if (immediateCallbacksLen < immediateCallbacksCapacity) {
            immediateCallbacks.unsafeSet(immediateCallbacksLen, handleImmediate);
            immediateCallbacksLen++;
        }
        else {
            immediateCallbacks[immediateCallbacksLen++] = handleImmediate;
            immediateCallbacksCapacity++;
        }
        #end

    }

    /**
     * Schedule callback that is garanteed to be executed when no immediate callback are pending anymore.
     * @param owner Owner of this callback, allowing to cancel callback if owner is destroyed
     * @param handlePostFlushImmediate The callback to execute
     * @param defer if `true` (default), will box this call into an immediate callback
     */
    extern inline overload public function oncePostFlushImmediate(owner:Entity, handlePostFlushImmediate:Void->Void, defer:Bool = true):Void {

        _oncePostFlushImmediateWithOwner(owner, handlePostFlushImmediate, defer);

    }

    /**
     * Schedule callback that is garanteed to be executed when no immediate callback are pending anymore.
     * @param handlePostFlushImmediate The callback to execute
     * @param defer if `true` (default), will box this call into an immediate callback
     */
    extern inline overload public function oncePostFlushImmediate(handlePostFlushImmediate:Void->Void, defer:Bool = true):Void {

        _oncePostFlushImmediate(handlePostFlushImmediate, defer);

    }

    function _oncePostFlushImmediateWithOwner(owner:Entity, handlePostFlushImmediate:Void->Void, defer:Bool):Void {

        _oncePostFlushImmediate(function() {
            if (owner == null || !owner.destroyed) {
                handlePostFlushImmediate();
            }
        }, defer);

    }

    /**
     * Schedule callback that is garanteed to be executed when no immediate callback are pending anymore.
     * @param handlePostFlushImmediate The callback to execute
     * @param defer if `true` (default), will box this call into an immediate callback
     */
    function _oncePostFlushImmediate(handlePostFlushImmediate:Void->Void, defer:Bool):Void {

        if (!defer) {
            if (immediateCallbacksLen == 0) {
                handlePostFlushImmediate();
            }
            else {

                if (postFlushImmediateCallbacksLen < postFlushImmediateCallbacksCapacity) {
                    postFlushImmediateCallbacks.unsafeSet(postFlushImmediateCallbacksLen, handlePostFlushImmediate);
                    postFlushImmediateCallbacksLen++;
                }
                else {
                    postFlushImmediateCallbacks[postFlushImmediateCallbacksLen++] = handlePostFlushImmediate;
                    postFlushImmediateCallbacksCapacity++;
                }
            }
        }
        else {
            app.onceImmediate(function() {
                oncePostFlushImmediate(handlePostFlushImmediate, false);
            });
        }

    }

    /**
     * Execute and flush every awaiting immediate callback, including the ones that
     * could have been added with `onceImmediate()` after executing the existing callbacks.
     * @return `true` if anything was flushed
     */
    public function flushImmediate():Bool {

        var didFlush = false;

        // Immediate callbacks
        while (immediateCallbacksLen > 0) {

            didFlush = true;

            var pool = ArrayPool.pool(immediateCallbacksLen);
            var callbacks = pool.get();
            var len = immediateCallbacksLen;
            immediateCallbacksLen = 0;

            for (i in 0...len) {
                callbacks.set(i, immediateCallbacks.unsafeGet(i));
                immediateCallbacks.unsafeSet(i, null);
            }

            for (i in 0...len) {
                var cb:Dynamic = callbacks.get(i);
                cb();
            }

            pool.release(callbacks);

        }

        // Post flush immediate callbacks
        if (postFlushImmediateCallbacksLen > 0) {

            var pool = ArrayPool.pool(postFlushImmediateCallbacksLen);
            var callbacks = pool.get();
            var len = postFlushImmediateCallbacksLen;
            postFlushImmediateCallbacksLen = 0;

            for (i in 0...len) {
                callbacks.set(i, postFlushImmediateCallbacks.unsafeGet(i));
                postFlushImmediateCallbacks.unsafeSet(i, null);
            }

            for (i in 0...len) {
                var cb:Dynamic = callbacks.get(i);
                cb();
            }

            pool.release(callbacks);

        }

        return didFlush;

    }

    /**
     * Extended updates system that allows scheduling callbacks after X update frames.
     * Provides a pooled handler system to efficiently manage delayed callbacks.
     */
    var _xUpdatesHandlersPool:Pool<AppXUpdatesHandler> = new Pool<AppXUpdatesHandler>();

    /**
     * Active handlers for the extended updates system
     */
    var _xUpdatesHandlers:Array<AppXUpdatesHandler> = [];

    /**
     * Temporary array to store callbacks that need to be called immediately
     */
    var _xUpdatesToCallNow:Array<Void->Void> = [];

    /**
     * Schedule a callback to be executed after a specific number of update frames.
     * @param owner The entity that owns this callback (used to prevent execution if owner is destroyed)
     * @param numUpdates Number of update frames to wait before executing the callback
     * @param callback The function to execute after numUpdates frames
     */
    public function onceXUpdates(owner:Entity, numUpdates:Int, callback:Void->Void):Void {

        var handler = _xUpdatesHandlersPool.get();
        if (handler == null)
            handler = new AppXUpdatesHandler();
        handler.owner = owner;
        handler.numUpdates = numUpdates;
        handler.callback = callback;
        var didAdd = false;
        for (i in 0..._xUpdatesHandlers.length) {
            var existing = _xUpdatesHandlers.unsafeGet(i);
            if (existing == null) {
                _xUpdatesHandlers.unsafeSet(i, handler);
                didAdd = true;
                break;
            }
        }
        if (!didAdd) {
            _xUpdatesHandlers.push(handler);
        }

    }

    /**
     * Remove a previously scheduled extended update callback
     * @param callback The callback to remove
     */
    public function offXUpdates(callback:Void->Void):Void {

        var needsClean = false;
        for (i in 0..._xUpdatesHandlers.length) {
            var handler = _xUpdatesHandlers.unsafeGet(i);
            if (Utils.functionEquals(handler.callback, callback)) {
                handler.reset();
                _xUpdatesHandlersPool.recycle(handler);
                _xUpdatesHandlers.unsafeSet(i, null);
                needsClean = true;
            }
        }

        if (needsClean) {
            cleanXUpdatesNullValues();
        }

    }

    /**
     * Internal method to handle execution of extended update callbacks
     */
    function tickOnceXUpdates():Void {

        var numToCall = 0;
        var needsClean = false;
        for (i in 0..._xUpdatesHandlers.length) {
            var handler = _xUpdatesHandlers.unsafeGet(i);
            if (handler != null) {
                handler.numUpdates--;
                if (handler.numUpdates <= 0) {
                    var owner = handler.owner;
                    if (owner == null || !owner.destroyed) {
                        _xUpdatesToCallNow[numToCall] = handler.callback;
                        numToCall++;
                    }
                    _xUpdatesHandlers.unsafeSet(i, null);
                    needsClean = true;
                }
            }
        }

        if (numToCall > 0) {
            for (i in 0...numToCall) {
                var callback = _xUpdatesToCallNow.unsafeGet(i);
                _xUpdatesToCallNow.unsafeSet(i, null);
                callback();
            }
        }

        if (needsClean) {
            cleanXUpdatesNullValues();
        }

    }

    function cleanXUpdatesNullValues():Void {

        var i = 0;
        var gap = 0;
        var len = _xUpdatesHandlers.length;
        while (i < len) {

            do {

                var handler = _xUpdatesHandlers.unsafeGet(i);
                if (handler == null) {
                    i++;
                    gap++;
                }
                else {
                    break;
                }

            }
            while (i < len);

            if (gap != 0 && i < len) {
                var key = i - gap;
                _xUpdatesHandlers.unsafeSet(key, _xUpdatesHandlers.unsafeGet(i));
            }

            i++;
        }

        // Reduce array size
        _xUpdatesHandlers.setArrayLength(len - gap);

    }

    /**
     * `true` if the app is currently running its update phase.
     */
    public var inUpdate(default,null):Bool = false;

/// Static pre-init code (used to add plugins)

    static var preInitCallbacks:Array<Void->Void>;
    static function oncePreInit(handle:Void->Void):Void {
        if (preInitCallbacks == null) preInitCallbacks = [];
        preInitCallbacks.push(handle);
    }

/// Properties

    /**
     * Computed fps of the app. Read only.
     * Value is automatically computed from last second of frame updates.
     */
    public var computedFps(get,never):Int;
    inline function get_computedFps():Int {
        return _computeFps.fps;
    }
    var _computeFps = new ComputeFps();

    /**
     * Current frame number
     */
    public var frame(default,null):Int = 0;

    /**
     * Current frame delta time (never above `settings.maxDelta`)
     */
    public var delta(default,null):Float;

    /**
     * Current frame real delta time (the actual elapsed time since last frame update)
     */
    public var realDelta(default,null):Float;

    /**
     * Backend instance
     */
    public var backend(default,null):Backend;

    /**
     * Screen instance
     */
    public var screen(default,null):Screen;

    /**
     * Audio instance
     */
    public var audio(default,null):Audio;

    /**
     * App settings
     */
    public var settings(default,null):Settings;

    /**
     * Systems are objects to structure app work/phases and update cycle
     */
    public var systems(default,null):Systems;

    /**
     * Logger. Used by log shortcut
     */
    public var logger(default,null):Logger = new Logger();

    /**
     * Visuals (ordered)
     * Active list of visuals being managed by ceramic.
     * This list is ordered and updated at every frame.
     * In between, it could contain destroyed visuals as they
     * are removed only at the end of the frame for performance reasons.
     */
    public var visuals(default,null):Array<Visual> = [];

    /**
     * Pending visuals: visuals that have been created this frame
     * but were not added to the `visual` list yet
     */
    public var pendingVisuals(default,null):Array<Visual> = [];

    /**
     * Pending destroyed visuals: visuals that have been destroyed this frame
     * but were not removed to the `visual` list yet
     */
    public var destroyedVisuals(default,null):Array<Visual> = [];

    /**
     * All groups of entities in this app
     */
    public var groups(default,null):Array<Group<Entity>> = [];

    /**
     * Shared instance of `Input`
     */
    public var input(default,null):Input;

    /**
     * All active render textures in this app
     */
    public var renderTextures(default,null):Array<RenderTexture> = [];

    /**
     * App level assets. Used to load default assets (font, texture, shader)
     * required to make ceramic work properly.
     */
    public var assets(default,null):Assets;

    /**
     * Default textured shader.
     * This is the shader used for any visual (quad or mesh) that don't have a custom shader assigned.
     */
    public var defaultTexturedShader(default,null):Shader = null;

    /**
     * Default white texture.
     * When a quad or mesh doesn't have a texture assigned, it will use the default white texture
     * instead to render as plain flat coloured object. This means that the same default shader
     * is used and everything can be batched together (textured & non-textured in the same batch).
     */
    public var defaultWhiteTexture(default,null):Texture = null;

    /**
     * Default font used by `Text` instances.
     */
    public var defaultFont(default,null):BitmapFont = null;

    /**
     * Project directory. May be null depending on the platform.
     */
    public var projectDir:String = null;

    /**
     * App level persistent data.
     * This is a simple key-value store ready to be used.
     * Don't forget to call `persistent.save()` to apply changes permanently.
     */
    public var persistent(default,null):PersistentData = null;

    /**
     * Shared text input manager. Usually not used directly as is.
     * You might want to use `EditText` component instead.
     */
    public var textInput(default,null):TextInput = null;

/// Field converters

    /**
     * Converters are used to transform field data in `Fragment` instances.
     * This map is matching a type (as string, like `"Array<Float>"`) with an instance
     * of a `ConvertField` subclass.
     */
    public var converters:Map<String,ConvertField<Dynamic,Dynamic>> = new Map();

    /**
     * All active timelines in this app.
     */
    public var timelines:Timelines = new Timelines();

#if plugin_arcade

    /**
     * Shared arcade system.
     * (arcade plugin)
     */
    public var arcade:ArcadeSystem = null;

#end

#if plugin_nape

    /**
     * Shared nape system.
     * (nape plugin)
     */
    public var nape:NapeSystem = null;

#end

    /**
     * Shared scene system.
     */
    @lazy public var scenes:SceneSystem = SceneSystem.shared;

/// Internal

    var hierarchyDirty:Bool = false;

    var visualsContentDirty:Bool = false;

    /**
     * List of functions that will be called and purged when update iteration begins.
     * Useful to run some specific code once exactly before update event is sent.
     */
    var beginUpdateCallbacks:Array<Void->Void> = [];

    var disposedEntities:Array<Entity> = [];

#if (cppia || ceramic_cppia_host)
    @:noCompletion public var initSettings:InitSettings;
#end

    @:noCompletion public var numBlockingDefaultScroll:Int = 0;

/// Public initializer

    @:noCompletion
    public static function init():InitSettings {

#if cpp
        untyped __global__.__hxcpp_set_critical_error_handler(function(message:String) throw message);
#end

#if clay_sdl
        SDL.setLCNumericCLocale();
#end

#if (!ceramic_cppia_host && !ceramic_no_bind_assets)
        AllAssets.bind();
#end

        new App();
        var initSettings = new InitSettings(app.settings);
#if ceramic_cppia_host
        app.initSettings = initSettings;
#end
        return initSettings;

    }

/// Lifecycle

    function new() {

        super();

        app = this;

#if hxtelemetry
        var cfg = new hxtelemetry.HxTelemetry.Config();
        cfg.allocations = true;
        hxt = new HxTelemetry(cfg);
#end

        // Initialize plugins
        // (resolved from `plugin_*` defines)
        ceramic.macros.PluginsMacro.initPlugins();

        Runner.init();

        Tracker.backend = new TrackerBackend();

        settings = new Settings();
        screen = new Screen();
        audio = new Audio();
        input = new Input();
        systems = new Systems();

        assets = new Assets();

        backend = new Backend();
        backend.onceReady(this, backendReady);
        backend.init(this);

    }

    /**
     * Quit the application.
     * Works on desktop (windows, mac, linux), unity.
     * Can also work on web by closing the window if **electron** plugin is enabled
     * and the app is running via electron instead of a regular browser.
     */
    public function quit() {

        Platform.quit();

    }

    /**
     * When backend is ready, initialize core systems and load default assets.
     * Steps:
     * 1. Initialize persistent data and text input
     * 2. Bind settings
     * 3. Run pre-init callbacks
     * 4. Initialize field converters and collections
     * 5. Load default shaders, fonts and textures
     */
    function backendReady():Void {

        backend.onUpdate(this, updatePreReady);

#if clay_sdl
        SDL.setLCNumericCLocale();
#end

        // Init persistent data (that relies on backend)
        persistent = new PersistentData('app');

        // Init text input manager
        textInput = new TextInput();

        // Bind settings
        bindSettings();

        // Notify screen
        screen.backendReady();

        // Run pre-init callbacks
        if (preInitCallbacks != null) {
            for (callback in [].concat(preInitCallbacks)) {
                callback();
            }
            preInitCallbacks = null;
        }

        // Init field converters
        initFieldConverters();

        // Init collections
        if (settings.collections != null) {
            initCollections(settings.collections(), settings.appInfo);
        }

#if plugin_arcade
        arcade = new ArcadeSystem();
#end

#if plugin_nape
        nape = new NapeSystem();
#end

        // Load default assets
        //

        // Default shaders (need to load these first because font loading needs MSDF shader)
        assets.add(settings.defaultShader);
        assets.add('shader:msdf');

#if unity
        assets.add('shader:stencil');
#end

#if !ceramic_no_pixel_art_shader
        // Pixel art shader
        assets.add('shader:pixelArt');
#end

        assets.onceComplete(this, function(success) {
            // Default font
            assets.add(settings.defaultFont);

            // Default textures
            assets.add('image:white');

            assets.onceComplete(this, function(success) {

                if (success) {

                    // Get default asset instances now that they are loaded
                    defaultFont = assets.font(settings.defaultFont);
                    defaultWhiteTexture = assets.texture('image:white');
                    defaultTexturedShader = assets.shader(settings.defaultShader);

                    logger.success('Default assets loaded.');
                    assetsLoaded();
                } else {
                    log.error('Failed to load default assets.');
                }

            });

            // Allow to load more default assets
            emitDefaultAssetsLoad(assets);

            assets.load();
            assets.immediate.flush();
            flushImmediate();

        });

        assets.load();
        assets.immediate.flush();
        flushImmediate();

    }

    /**
     * Bind app settings to their corresponding backend implementations.
     * Currently handles FPS target synchronization.
     */
    function bindSettings():Void {

        settings.onTargetFpsChange(this, function(targetFps, prevTargetFps) {
            #if debug log.info('Setting targetFps=$targetFps'); #end
            app.backend.setTargetFps(targetFps);
        });

        app.backend.setTargetFps(settings.targetFps);

    }

    /**
     * Initialize all field converters used to transform field data in Fragment instances.
     * Registers default converters for common types like:
     * - Textures, Fonts, Colors
     * - Maps and Arrays
     * - Components
     */
    function initFieldConverters():Void {

        converters.set('ceramic.Texture', new ConvertTexture());
        converters.set('ceramic.BitmapFont', new ConvertFont());
        converters.set('ceramic.FragmentData', new ConvertFragmentData());
        converters.set('ceramic.Color', new ConvertColor());
        converters.set('Map<String,String>', new ConvertMap<String>());
        converters.set('Map<String,Bool>', new ConvertMap<Bool>());
        converters.set('ceramic.ReadOnlyMap<String,String>', new ConvertMap<String>());
        converters.set('ceramic.ReadOnlyMap<String,Bool>', new ConvertMap<Bool>());
        converters.set('Array<Float>', new ConvertArray<Float>());
        converters.set('Array<Int>', new ConvertArray<Int>());
        converters.set('Array<String>', new ConvertArray<String>());
        converters.set('ceramic.ReadOnlyArray<Float>', new ConvertArray<Float>());
        converters.set('ceramic.ReadOnlyArray<Int>', new ConvertArray<Int>());
        converters.set('ceramic.ReadOnlyArray<String>', new ConvertArray<String>());
        converters.set('Map<String,ceramic.Component>', new ConvertComponentMap());
        converters.set('ceramic.ReadOnlyMap<String,ceramic.Component>', new ConvertComponentMap());
        converters.set('ceramic.IntBoolMap', new ConvertIntBoolMap());

    }

    /**
     * Initialize collections from app info configuration.
     * Loads collection data from assets and instantiates collection entries.
     * @param collections The collections container
     * @param info Optional info object containing collection definitions
     */
    function initCollections(collections:AutoCollections, ?info:Dynamic):Void {

        if (info == null)
            info = this.info;

        var addedAssets = new Map<String,Bool>();
        var numAdded = 0;

        // Compute databases to load
        //
        for (key in Reflect.fields(info.collections)) {
            for (collectionName in Reflect.fields(Reflect.field(info.collections, key))) {
                var collectionInfo:Dynamic = Reflect.field(Reflect.field(info.collections, key), collectionName);
                if (!Std.isOfType(collectionInfo, String)) {
                    var dataName = collectionInfo.data;
                    if (dataName != null) {
                        if (!addedAssets.exists(dataName)) {
                            addedAssets.set(dataName, true);
                            assets.addDatabase(dataName);
                            numAdded++;
                        }
                    }
                }
            }
        }

        if (numAdded > 0) {

            assets.onceComplete(this, function(success) {

                // Fill collections with loaded data
                //
                for (key in Reflect.fields(info.collections)) {
                    for (collectionName in Reflect.fields(Reflect.field(info.collections, key))) {
                        var collectionInfo:Dynamic = Reflect.field(Reflect.field(info.collections, key), collectionName);
                        if (!Std.isOfType(collectionInfo, String)) {
                            var dataName = collectionInfo.data;
                            if (dataName != null) {

                                var data = assets.database(dataName);
                                var collection:Collection<CollectionEntry> = Reflect.field(collections, collectionName);

                                var entryClass = Type.resolveClass(collectionInfo.type);

                                for (item in data) {
                                    var instance:CollectionEntry = Type.createInstance(entryClass, [null, null]);
                                    instance.setRawData(item);
                                    collection.push(instance);
                                }

                                collection.synchronize();

                            }
                        }
                    }
                }

            });

        }

    }

    /**
     * Called when all default assets are loaded.
     * Proceeds with running any pending loaders.
     */
    function assetsLoaded():Void {

        runNextLoader();

    }

    /**
     * Run pending loaders sequentially until none remain,
     * then trigger app ready state.
     */
    function runNextLoader():Void {

        if (loaders.length > 0) {
            var loader = loaders.shift();
            loader(runNextLoader);
        }
        else {
            loaders = null;
            runReady();
        }

    }

    #if ceramic_debug_num_entities
    static var _entities:Array<Entity> = [];
    #end

    /**
     * Initialize app ready state:
     * - Run platform specific initialization
     * - Setup debug entity tracking if enabled
     * - Configure screen
     * - Setup update/render pipeline
     * - Configure input handling
     */
    function runReady():Void {

        // Platform specific code (which is not in backend code)
        Platform.postAppInit();

        emitReady();

        #if ceramic_log_fps
        Timer.interval(this, 1.0, function() {
            log.info('FPS: ' + computedFps);
        });
        #end

        #if (ceramic_debug_num_entities || ceramic_debug_num_visuals)
        Timer.interval(this, 5.0, function() {
            var numEntitiesByClass = new Map<String,Int>();
            var usedClasses:Array<String> = [];
            var entities = #if ceramic_debug_num_entities _entities #else visuals #end;
            #if ceramic_debug_entity_allocs
            var allocDetailedData = new Map<String, {
                pos:haxe.PosInfos,
                count:Int
            }>();
            var allocDetailedDataList = [];
            #end
            for (i in 0...entities.length) {
                var entity = entities[i];
                var clazz = Type.getClassName(Type.getClass(entity));
                if (numEntitiesByClass.exists(clazz)) {
                    numEntitiesByClass.set(clazz, numEntitiesByClass.get(clazz) + 1);
                }
                else {
                    usedClasses.push(clazz);
                    numEntitiesByClass.set(clazz, 1);
                }
                #if ceramic_debug_entity_allocs
                if (clazz == ceramic.macros.DefinesMacro.getDefine('ceramic_debug_entity_allocs')) {
                    var pos = entity.posInfos;
                    if (pos != null) {
                        var posStr = ''+pos;
                        var data = allocDetailedData.get(posStr);
                        if (data == null) {
                            data = {
                                pos: pos,
                                count: 1
                            };
                            allocDetailedData.set(posStr, data);
                            allocDetailedDataList.push(data);
                        }
                        else {
                            data.count++;
                        }
                    }
                }
                #end
            }
            usedClasses.sort(function(a, b) {
                return numEntitiesByClass.get(a) - numEntitiesByClass.get(b);
            });
            #if ceramic_debug_num_entities
            log.success(' - num entities: ${entities.length} - ');
            #else
            log.success(' - num visuals: ${entities.length} - ');
            #end
            for (clazz in usedClasses) {
                log.success('    $clazz / ${numEntitiesByClass.get(clazz)}');
            }
            #if ceramic_debug_entity_allocs
            if (allocDetailedDataList.length > 0) {
                log.info(' - detailed allocs for class: ' + ceramic.macros.DefinesMacro.getDefine('ceramic_debug_entity_allocs'));
                allocDetailedDataList.sort(function(a, b) {
                    return a.count - b.count;
                });
                for (data in allocDetailedDataList) {
                    log.info('    ${data.count}', data.pos);
                }
            }
            #end
        });
        #end

        screen.resize();

        backend.offUpdate(updatePreReady);
        backend.onUpdate(this, update);
        backend.onRender(this, render);

        // Forward key events
        //
        backend.input.onKeyDown(this, function(key) {
            beginUpdateCallbacks.push(function() {
                input.emitKeyDown(key);
            });
        });
        backend.input.onKeyUp(this, function(key) {
            beginUpdateCallbacks.push(function() input.emitKeyUp(key));
        });

        // Forward gamepad events
        backend.input.onGamepadEnable(this, function(gamepadId, name) {
            beginUpdateCallbacks.push(function() input.emitGamepadEnable(gamepadId, name));
        });
        backend.input.onGamepadDisable(this, function(gamepadId) {
            beginUpdateCallbacks.push(function() input.emitGamepadDisable(gamepadId));
        });
        backend.input.onGamepadDown(this, function(gamepadId, buttonId) {
            beginUpdateCallbacks.push(function() input.emitGamepadDown(gamepadId, buttonId));
        });
        backend.input.onGamepadUp(this, function(gamepadId, buttonId) {
            beginUpdateCallbacks.push(function() input.emitGamepadUp(gamepadId, buttonId));
        });
        backend.input.onGamepadGyro(this, function(gamepadId, dx, dy, dz) {
            beginUpdateCallbacks.push(function() input.emitGamepadGyro(gamepadId, dx, dy, dz));
        });
        backend.input.onGamepadAxis(this, function(gamepadId, axisId, value) {
            beginUpdateCallbacks.push(function() input.emitGamepadAxis(gamepadId, axisId, value));
        });

    }

    /**
     * Update method called before the app is fully ready.
     * Handles basic asset and immediate callback processing.
     */
    function updatePreReady(delta:Float):Void {

        #if sys
        sys.thread.Thread.current().events.progress();
        #end

        Assets.flushAllInstancesImmediate();
        flushImmediate();

    }

    #if ceramic_pending_finish_draw
    var _pendingFinishDraw:Bool = false;
    #end

    /**
     * Main update method called every frame once the app is ready.
     * Handles:
     * - Frame timing and FPS management
     * - System updates
     * - Input processing
     * - Visual hierarchy updates
     * - Entity lifecycle
     * @param realDelta Actual time elapsed since last frame
     */
    function update(realDelta:Float):Void {

        #if ceramic_pending_finish_draw
        if (_pendingFinishDraw) {
            _pendingFinishDraw = false;
            emitFinishDraw();
        }
        #end

        if (++frame > 999999999)
            frame -= 999999999;

        var delta = realDelta;

        // Never allow an update delta above maxDelta
        if (delta > settings.maxDelta) {
            delta = settings.maxDelta;
        }

        // Override delta?
        if (settings.overrideDelta >= 0) {
            delta = settings.overrideDelta;
        }

        // Update computed fps
        _computeFps.addFrame(delta);

        // Update frame delta time
        this.delta = delta;
        this.realDelta = realDelta;

#if clay_sdl
        SDL.setLCNumericCLocale();
#end

#if hxtelemetry
        hxt.advance_frame();
#end

#if cs
        untyped __cs__('global::System.Threading.Thread.CurrentThread.CurrentCulture = global::System.Globalization.CultureInfo.CreateSpecificCulture("en-GB")');
#end

        Timer.update(delta, realDelta);

        Runner.tick();

        #if sys
        sys.thread.Thread.current().events.progress();
        #end

        // Screen pointer over/out events detection
        screen.updatePointerOverState(delta);

        inUpdate = true;

        // Reset screen deltas
        screen.resetDeltas();

        // Reset input deltas
        input.resetDeltas();

        // Run 'begin update' callbacks, like touch/mouse/key events etc...
        if (beginUpdateCallbacks.length > 0) {
            var callbacks = beginUpdateCallbacks;
            beginUpdateCallbacks = [];
            for (callback in callbacks) {
                callback();
            }
        }

        // Trigger pre-update event
        emitPreUpdate(delta);

        // Run systems early update
        systems.earlyUpdate(delta);

        // Flush assets immediate callbacks
        Assets.flushAllInstancesImmediate();

        // Flush immediate callbacks
        flushImmediate();

        if (delta > 0) {

            // Update tweens
            Tween.tick(delta);

            // Flush immediate callbacks
            flushImmediate();
        }

        // Then update
        emitUpdate(delta);

        // Flush after x udpates
        tickOnceXUpdates();

        // Flush immediate callbacks
        flushImmediate();

        // Run systems late update
        systems.lateUpdate(delta);

        // Emit post-update event
        emitPostUpdate(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Destroy disposed entities
        while (disposedEntities.length > 0) {
            var toDestroy = disposedEntities.shift();
            toDestroy.destroy();
        }

        // Sync pending and destroyed visuals
        syncPendingVisuals();

        // Update visuals
        updateVisuals(visuals);

        // Update hierarchy from depth
        computeHierarchy();

        // Compute render textures priority
        computeRenderTexturesPriority(renderTextures);

        // Sync destroyed visuals again, if needed, before sorting
        syncDestroyedVisuals();

        // Sort visuals depending on their settings
        sortVisuals(visuals);

        // Update finished
        inUpdate = false;

    }

    /**
     * Main render method called every frame.
     * Handles the complete rendering pipeline:
     * - Begins draw phase
     * - Renders all visible visuals
     * - Ends draw phase
     * - Handles display buffer swapping
     */
    function render():Void {

        // Begin draw
        emitBeginDraw();

        // Draw (clears anything drawn before)
        backend.draw.draw(visuals);

        // End draw
        #if ceramic_pending_finish_draw
        _pendingFinishDraw = true;
        #else
        emitFinishDraw();
        #end

        // Tween end frame
        Tween.endFrame();

        // Swap display (if backends needs to)
        backend.draw.swap();

    }

    /**
     * Add a visual to be managed by the app.
     * Visual will be added to the update/render pipeline at the
     * end of the update step of current frame, before rendering.
     */
    @:noCompletion
    inline public function addVisual(visual:Visual):Void {

        pendingVisuals.push(visual);

    }

    /**
     * Remove a visual from app management.
     * Visual will be removed from update/render pipeline at the
     * end of the update step of current frame, before rendering.
     */
    @:noCompletion
    inline public function removeVisual(visual:Visual):Void {

        destroyedVisuals.push(visual);

    }

    /**
     * Synchronize pending visuals into the main visuals list.
     * @return True if any visuals were synchronized
     */
    function syncPendingVisuals():Bool {

        if (pendingVisuals.length > 0) {

            // Add pending visuals
            while (pendingVisuals.length > 0) {
                visuals.push(pendingVisuals.pop());
            }

            hierarchyDirty = true;

            return true;

        }

        return false;

    }

    /**
     * Remove destroyed visuals from the main visuals list.
     * Uses an efficient gap-closing algorithm to maintain array density.
     */
    function syncDestroyedVisuals():Void {

        if (destroyedVisuals.length > 0) {

            // Remove destroyed visuals
            var i = 0;
            var gap = 0;
            var len = visuals.length;
            while (i < len) {

                do {

                    var visual = visuals.unsafeGet(i);
                    if (visual.destroyed) {
                        i++;
                        gap++;
                    }
                    else {
                        break;
                    }

                }
                while (i < len);

                if (gap != 0 && i < len) {
                    var key = i - gap;
                    visuals.unsafeSet(key, visuals.unsafeGet(i));
                }

                i++;
            }

            // Reduce array size
            destroyedVisuals.setArrayLength(0);
            visuals.setArrayLength(len - gap);

            hierarchyDirty = true;

        }

    }

    /**
     * Update all managed visuals, handling:
     * - Touch state
     * - Content updates
     * - Transform changes
     * - Render target dependencies
     * - Visibility state
     */
    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end public function updateVisuals(visuals:Array<Visual>) {

        var numIterations = 0;
        var didFlush = false;
        var didSyncVisuals = false;

        do {
            visualsContentDirty = false;

            // Notify if screen matrix has changed
            screen.matrix.computeChanged();
            if (screen.matrix.changed) {
                screen.matrix.emitChange();
            }

            for (i in 0...visuals.length) {

                var visual = visuals.unsafeGet(i);
                if (!visual.destroyed) {

                    // Compute touchable state
                    if (visual.touchableDirty) {
                        visual.computeTouchable();
                    }

                    // Compute displayed content
                    if (visual.contentDirty) {

                        // Compute content only if visual is currently visible
                        //
                        if (visual.visibilityDirty) {
                            visual.computeVisibility();
                        }

                        if (visual.computedVisible) {
                            visual.computeContent();
                        }
                    }
                }
            }

            // Dispatch visual transforms changes
            for (i in 0...visuals.length) {

                var visual = visuals.unsafeGet(i);
                if (!visual.destroyed && visual.transform != null) {
                    visual.transform.computeChanged();
                    if (visual.transform.changed) {
                        visual.transform.emitChange();
                    }
                }

            }

            if (numIterations++ > 9999) {
                if (didFlush && visualsContentDirty) {
                    throw 'Failed to update visuals because flushImmediate() is being called continuously and visuals content stays dirty.';
                }
                else if (didFlush) {
                    throw 'Failed to update visuals because flushImmediate() is being called continuously.';
                }
                else {
                    for (i in 0...visuals.length) {
                        var visual = visuals.unsafeGet(i);
                        if (!visual.destroyed && visual.contentDirty) {
                            throw 'Failed to update visuals because visuals content stays dirty. ($visual)';
                        }
                    }
                }
            }

            didFlush = flushImmediate();

            didSyncVisuals = syncPendingVisuals();
        }
        while (didFlush || visualsContentDirty || didSyncVisuals);

        // Reset render texture dependencies to recompute them
        for (i in 0...renderTextures.length) {
            var renderTexture = renderTextures.unsafeGet(i);
            renderTexture.resetDependingTextureCounts();
        }

        // Update visuals render target, matrix and visibility
        for (i in 0...visuals.length) {

            var visual = visuals.unsafeGet(i);
            if (!visual.destroyed) {

                if (visual.renderTargetDirty) {
                    visual.computeRenderTarget();
                }

                if (visual.matrixDirty) {
                    visual.computeMatrix();
                }

                if (visual.visibilityDirty) {
                    visual.computeVisibility();
                }

                if (visual.computedVisible) {
                    if (visual.clipDirty) {
                        visual.computeClip();
                    }

                    if (visual.computedRenderTarget != null) {
                        if (visual.asQuad != null) {
                            if (visual.asQuad.texture != null) {
                                visual.computedRenderTarget.incrementDependingTextureCount(visual.asQuad.texture);
                            }
                            if (visual.shader != null && visual.shader.usedTextures != null) {
                                final usedTextures = visual.shader.usedTextures;
                                for (t in 0...usedTextures.length) {
                                    visual.computedRenderTarget.incrementDependingTextureCount(usedTextures.unsafeGet(t));
                                }
                            }
                        }
                        else if (visual.asMesh != null) {
                            if (visual.asMesh.texture != null) {
                                visual.computedRenderTarget.incrementDependingTextureCount(visual.asMesh.texture);
                            }
                            if (visual.shader != null && visual.shader.usedTextures != null) {
                                final usedTextures = visual.shader.usedTextures;
                                for (t in 0...usedTextures.length) {
                                    visual.computedRenderTarget.incrementDependingTextureCount(usedTextures.unsafeGet(t));
                                }
                            }
                        }
                    }
                }
            }

        }

    }

    /**
     * Recompute visual hierarchy when depth values have changed.
     * Updates computed depth values for all visuals and their children.
     */
    @:noCompletion
    public function computeHierarchy() {

        if (hierarchyDirty) {

            // Compute visuals depth
            for (i in 0...visuals.length) {

                var visual = visuals.unsafeGet(i);
                if (!visual.destroyed) {

                    if (visual.parent == null) {
                        visual.computedDepth = visual.depth * Visual.DEPTH_FACTOR;

                        if (visual.children != null) {
                            Visual.computeChildrenDepth(visual);
                        }
                    }
                }
            }

            hierarchyDirty = false;
        }

    }

    /**
     * An array queue used to sort render textures based on their priority before computing them.
     * Not meant to be accessed directly.
     */
    @:noCompletion private var _computeRenderTexturesPriorityQueue:Array<RenderTexture> = [];

    #if ceramic_new_texture_priority_sort
    /**
     * Compute render texture priorities to handle proper rendering order
     * when textures depend on each other.
     * Uses Kahn's algorithm for topological sorting.
     * @param renderTextures Array of render textures to process
     */
    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end
    public function computeRenderTexturesPriority(renderTextures:Array<RenderTexture>) {

        final len = renderTextures.length;

        if (len == 0)
            return;

        // Reset priorities and incoming edges
        for (i in 0...len) {
            var renderTexture = renderTextures.unsafeGet(i);
            renderTexture.priority = 0;
            renderTexture.incomingEdges = 0;
        }

        // Count dependencies - REVERSED from before
        for (i in 0...len) {
            var a = renderTextures.unsafeGet(i);
            for (j in 0...len) {
                var b = renderTextures.unsafeGet(j);
                // When A depends on B, increment B's incoming edges
                if (a.dependsOnTexture(b)) {
                    b.incomingEdges++;
                }
            }
        }

        // Start with nodes that have no dependencies
        var queueLength = 0;
        for (i in 0...len) {
            var texture = renderTextures.unsafeGet(i);
            if (texture.incomingEdges == 0) {
                _computeRenderTexturesPriorityQueue[queueLength++] = texture;
            }
        }

        // Process queue
        var currentPriority = 0;
        var queueIndex = 0;
        while (queueIndex < queueLength) {
            var current = _computeRenderTexturesPriorityQueue[queueIndex++];
            current.priority = currentPriority++;

            // Look for textures that this one depends on
            for (i in 0...len) {
                var texture = renderTextures.unsafeGet(i);
                // When current depends on texture, decrement texture's edges
                if (current.dependsOnTexture(texture)) {
                    var edges = texture.incomingEdges - 1;
                    texture.incomingEdges = edges;
                    if (edges == 0) {
                        _computeRenderTexturesPriorityQueue[queueLength++] = texture;
                    }
                }
            }
        }

        // Handle remaining cyclic dependencies
        for (i in 0...len) {
            var texture = renderTextures.unsafeGet(i);
            if (texture.incomingEdges > 0) {
                texture.priority = currentPriority++;
            }
        }

        // Clear queue array references
        for (i in 0...queueLength) {
            _computeRenderTexturesPriorityQueue[i] = null;
        }
    }

    #else

    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end public function computeRenderTexturesPriority(renderTextures:Array<RenderTexture>) {

        if (renderTextures.length == 0)
            return;

        // Not so sure about the robustness of this in some edge cases,
        // but this 2-pass walk to update priorities works better than stable sort
        var len = renderTextures.length;
        for (i in 0...len) {
            var renderTexture = renderTextures.unsafeGet(i);
            renderTexture.priority = 0;
        }
        for (n in 0...2) {
            for (i in 0...len) {
                var a = renderTextures.unsafeGet(i);
                for (j in 0...len) {
                    var b = renderTextures.unsafeGet(j);
                    if (a.dependsOnTexture(b) && b.priority <= a.priority) {
                        b.priority = a.priority + 1;
                    }
                }
            }
        }

    }

    #end

    /**
     * Sort visuals based on their computed depth and other properties.
     * Emits events before and after sorting to allow custom sorting tweaks.
     * @param visuals Array of visuals to sort
     */
    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end
    public function sortVisuals(visuals:Array<Visual>) {

        // Emit event before sorting visuals (last moment we can tweak visuals sorting)
        emitBeginSortVisuals();

        // Sort visuals by (computed) depth
        SortVisuals.sort(visuals);

        // Emit event after sorting visuals (if we want to reverse any tweak)
        emitFinishSortVisuals();

    }

/// Groups

    /**
     * Get a group with the given id.
     * @param id The id of the group
     * @param createIfNeeded `true` (default) to create a group if not created already for this id
     * @return the group or null if no group was found and none created.
     */
    public function group(id:String, createIfNeeded:Bool = true):Group<Entity> {

        for (i in 0...groups.length) {
            var group = groups.unsafeGet(i);
            if (group.id == id)
                return group;
        }

        if (createIfNeeded) {
            return new Group<Entity>(id);
        }

        return null;

    }

}
