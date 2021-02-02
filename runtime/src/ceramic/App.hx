package ceramic;

import haxe.ds.ArraySort;
#if hxtelemetry
import hxtelemetry.HxTelemetry;
#end

#if (cpp && linc_sdl)
import sdl.SDL;
#end

#if (!ceramic_cppia_host && !ceramic_no_bind_assets)
import assets.AllAssets;
#end

import ceramic.PlatformSpecific;

import ceramic.Settings;
import ceramic.Assets;
import ceramic.Fragment;
import ceramic.Texture;
import ceramic.BitmapFont;
import ceramic.ConvertField;
import ceramic.CollectionEntry;
import ceramic.Shortcuts.*;

import tracker.Tracker;

import haxe.CallStack;

import backend.Backend;

using ceramic.Extensions;

/**
 * `App` class is the starting point of any ceramic app.
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
     * @event ready
     * Ready event is triggered when the app is ready
     * and the game logic can be started.
     */
    @event function ready();

    /**
     * @event update
     * Update event is triggered as many times as there are frames per seconds.
     * It is in sync with screen FPS but used for everything that needs
     * to get updated depending on time (ceramic.Timer relies on it).
     * Use this event to update your contents before they get drawn again.
     * @param delta The elapsed delta time since last frame
     */
    @event function update(delta:Float);

    /**
     * @event preUpdate
     * Pre-update event is triggered right before update event and
     * can be used when you want to run garantee your code
     * will be run before regular update event.
     * @param delta The elapsed delta time since last frame
     */
    @event function preUpdate(delta:Float);

    /**
     * @event postUpdate
     * Post-update event is triggered right after update event and
     * can be used when you want to run garantee your code
     * will be run after regular update event.
     * @param delta The elapsed delta time since last frame
     */
    @event function postUpdate(delta:Float);

    /** Assets events */
    @event function defaultAssetsLoad(assets:Assets);

    /** Fired when the app hits an critical (uncaught) error. Can be used to perform custom crash reporting.
        If this even is handled, app exit should be performed by the event handler. */
    @event function criticalError(error:Dynamic, stack:Array<StackItem>);

    @event function beginEnterBackground();
    @event function finishEnterBackground();

    @event function beginEnterForeground();
    @event function finishEnterForeground();

    @event function beginSortVisuals();
    @event function finishSortVisuals();

    @event function beginDraw();
    @event function finishDraw();

    @event function lowMemory();

    @event function terminate();

/// Immediate update event, custom implementation

    var immediateCallbacks:Array<Void->Void> = [];

    var immediateCallbacksCapacity:Int = 0;

    var immediateCallbacksLen:Int = 0;

    var postFlushImmediateCallbacks:Array<Void->Void> = [];

    var postFlushImmediateCallbacksCapacity:Int = 0;

    var postFlushImmediateCallbacksLen:Int = 0;

#if hxtelemetry
    var hxt:HxTelemetry;
#end

    /** Schedule immediate callback that is garanteed to be executed before the next time frame
        (before elements are drawn onto screen) */
    public function onceImmediate(handleImmediate:Void->Void #if ceramic_debug_immediate , ?pos:haxe.PosInfos #end):Void {

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

    /** Schedule callback that is garanteed to be executed when no immediate callback are pending anymore.
        @param defer if `true` (default), will box this call into an immediate callback */
    public function oncePostFlushImmediate(handlePostFlushImmediate:Void->Void, defer:Bool = true):Void {

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

    /** Execute and flush every awaiting immediate callback, including the ones that
        could have been added with `onceImmediate()` after executing the existing callbacks. */
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

    public var inUpdate(default,null):Bool = false;

    var shouldUpdateAndDrawAgain(default,null):Bool = false;

    inline public function requestFullUpdateAndDrawInFrame():Void {

        if (inUpdate) {
            shouldUpdateAndDrawAgain = true;
        }

    }

/// Static pre-init code (used to add plugins)

    static var preInitCallbacks:Array<Void->Void>;
    static function oncePreInit(handle:Void->Void):Void {
        if (preInitCallbacks == null) preInitCallbacks = [];
        preInitCallbacks.push(handle);
    }

/// Properties

    /** Computed fps of the app. Read only.
        Value is automatically computed from last second of frame updates. */
    public var computedFps(get,never):Int;
    inline function get_computedFps():Int {
        return _computeFps.fps;
    }
    var _computeFps = new ComputeFps();

    /** Current frame delta time (never above `settings.maxDelta`) */
    public var delta(default,null):Float;

    /** Current frame real delta time (the actual elapsed time since last frame update) */
    public var realDelta(default,null):Float;

    /** Backend instance */
    public var backend(default,null):Backend;

    /** Screen instance */
    public var screen(default,null):Screen;

    /** Audio instance */
    public var audio(default,null):Audio;

    /** App settings */
    public var settings(default,null):Settings;

    /** Logger. Used by log.info() shortcut */
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

    /** Groups */
    public var groups(default,null):Array<Group<Entity>> = [];

    /** Input */
    public var input(default,null):Input;

    /** Render Textures */
    public var renderTextures(default,null):Array<RenderTexture> = [];

    /** App level assets. Used to load default bitmap font */
    public var assets(default,null):Assets = new Assets();

    /** Default textured shader **/
    public var defaultTexturedShader(default,null):Shader = null;

    /** Default white texture **/
    public var defaultWhiteTexture(default,null):Texture = null;

    /** Default font */
    public var defaultFont(default,null):BitmapFont = null;

    /** Project directory. May be null depending on the platform. */
    public var projectDir:String = null;

    /** App level persistent data */
    public var persistent(default,null):PersistentData = null;

    /** Text input manager */
    public var textInput(default,null):TextInput = null;

/// Field converters

    public var converters:Map<String,ConvertField<Dynamic,Dynamic>> = new Map();

    public var timelines:Timelines = new Timelines();

#if ceramic_arcade_physics

    public var arcade:ArcadePhysics = null;

#end

#if ceramic_nape_physics

    public var nape:NapePhysics = null;

#end

/// Internal

    var hierarchyDirty:Bool = false;

    var visualsContentDirty:Bool = false;

    /** List of functions that will be called and purged when update iteration begins.
        Useful to run some specific code once exactly before update event is sent. */
    var beginUpdateCallbacks:Array<Void->Void> = [];

    var disposedEntities:Array<Entity> = [];

#if (cppia || ceramic_cppia_host)
    @:noCompletion public var initSettings:InitSettings;
#end

/// Public initializer

    public static function init():InitSettings {

#if cpp
        untyped __global__.__hxcpp_set_critical_error_handler(function(message:String) throw message);
#end

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

#if (!ceramic_cppia_host && !ceramic_no_bind_assets)
        AllAssets.bind();
#end

        app = new App();
        var initSettings = new InitSettings(app.settings);
#if ceramic_cppia_host
        app.initSettings = initSettings;
#end
        return initSettings;
        
    }
    
/// Lifecycle

    function new() {

        super();
        
#if hxtelemetry
        var cfg = new hxtelemetry.HxTelemetry.Config();
        cfg.allocations = true;
        hxt = new HxTelemetry(cfg);
#end

        // TODO find a way to insert this code with any enabled plugin
        // (doable with macro that checks `plugin_*` defines and looks for `*Plugin` type)

#if plugin_spine
        @:privateAccess ceramic.SpinePlugin.pluginInit();
#end

#if plugin_tilemap
        @:privateAccess ceramic.TilemapPlugin.pluginInit();
#end

        Runner.init();

        Tracker.backend = new TrackerBackend();

        settings = new Settings();
        screen = new Screen();
        audio = new Audio();
        input = new Input();

        backend = new Backend();
        backend.onceReady(this, backendReady);
        backend.init(this);

    }

    function backendReady():Void {

        backend.onUpdate(this, updatePreReady);

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

        // Init persistent data (that relies on backend)
        persistent = new PersistentData('app');

        // Init text input manager
        textInput = new TextInput();

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

#if ceramic_arcade_physics
        arcade = new ArcadePhysics();
#end

#if ceramic_nape_physics
        nape = new NapePhysics();
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
            flushImmediate();
            
        });

        assets.load();
        flushImmediate();

    }

    function initFieldConverters():Void {

        converters.set('ceramic.Texture', new ConvertTexture());
        converters.set('ceramic.BitmapFont', new ConvertFont());
        converters.set('ceramic.FragmentData', new ConvertFragmentData());
        converters.set('Map<String,String>', new ConvertMap<String>());
        converters.set('Map<String,Bool>', new ConvertMap<Bool>());
        converters.set('Array<Float>', new ConvertArray<Float>());
        converters.set('Array<Int>', new ConvertArray<Int>());
        converters.set('Array<String>', new ConvertArray<String>());
        converters.set('ceramic.ReadOnlyMap<String,String>', new ConvertMap<String>());
        converters.set('ceramic.ReadOnlyMap<String,Bool>', new ConvertMap<Bool>());
        converters.set('ceramic.ReadOnlyMap<String,ceramic.Component>', new ConvertComponentMap());

    }

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
                if (!Std.is(collectionInfo, String)) {
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
                        if (!Std.is(collectionInfo, String)) {
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

    function assetsLoaded():Void {

        // Platform specific code (which is not in backend code)
        PlatformSpecific.postAppInit();

        emitReady();

        #if ceramic_debug_num_visuals
        Timer.interval(this, 5.0, function() {
            var numVisualsByClass = new Map<String,Int>();
            var usedClasses:Array<String> = [];
            for (i in 0...visuals.length) {
                var visual = visuals[i];
                var clazz = '' + Type.getClass(visual);
                if (numVisualsByClass.exists(clazz)) {
                    numVisualsByClass.set(clazz, numVisualsByClass.get(clazz) + 1);
                }
                else {
                    usedClasses.push(clazz);
                    numVisualsByClass.set(clazz, 1);
                }
                #if ceramic_debug_entity_allocs
                /*if (clazz == 'ceramic.Quad') {
                    var pos = visual.posInfos;
                    haxe.Log.trace(visual, pos);
                }*/
                #end
            }
            usedClasses.sort(function(a, b) {
                return numVisualsByClass.get(a) - numVisualsByClass.get(b);
            });
            log.success(' - num visuals: ${visuals.length} - ');
            for (clazz in usedClasses) {
                log.success('    $clazz / ${numVisualsByClass.get(clazz)}');
            }
        });
        #end

        screen.resize();

        backend.offUpdate(updatePreReady);
        backend.onUpdate(this, update);

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

        // Forward controller events
        backend.input.onControllerEnable(this, function(controllerId, name) {
            beginUpdateCallbacks.push(function() input.emitControllerEnable(controllerId, name));
        });
        backend.input.onControllerDisable(this, function(controllerId) {
            beginUpdateCallbacks.push(function() input.emitControllerDisable(controllerId));
        });
        backend.input.onControllerDown(this, function(controllerId, buttonId) {
            beginUpdateCallbacks.push(function() input.emitControllerDown(controllerId, buttonId));
        });
        backend.input.onControllerUp(this, function(controllerId, buttonId) {
            beginUpdateCallbacks.push(function() input.emitControllerUp(controllerId, buttonId));
        });
        backend.input.onControllerAxis(this, function(controllerId, axisId, value) {
            beginUpdateCallbacks.push(function() input.emitControllerAxis(controllerId, axisId, value));
        });

    }

    function updatePreReady(delta:Float):Void {

        flushImmediate();

    }

    function update(realDelta:Float):Void {

        var delta = realDelta;

        // Never allow an update delta above maxDelta
        if (delta > settings.maxDelta) {
            delta = settings.maxDelta;
        }

#if ceramic_debug_cputime
        _debugCpuTimeThisFrame();
#end

        // Update computed fps
        _computeFps.addFrame(delta);

        // Update frame delta time
        this.delta = delta;
        this.realDelta = realDelta;

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

#if hxtelemetry
        hxt.advance_frame();
#end

#if ceramic_debug_cputime cpuTimeRec(0); #end

        Timer.update(delta, realDelta);
        
#if ceramic_debug_cputime cpuTimePause(0); #end
#if ceramic_debug_cputime cpuTimeRec(1); #end

        Runner.tick();

#if ceramic_debug_cputime cpuTimePause(1); #end
#if ceramic_debug_cputime cpuTimeRec(2); #end

        // Screen pointer over/out events detection
        screen.updatePointerOverState(delta);

#if ceramic_debug_cputime cpuTimePause(2); #end

        inUpdate = true;
        shouldUpdateAndDrawAgain = true;
        var isFirstUpdateInFrame = true;

        // Allow update section to be run multiple times before drawing
        // if this has been explicitly requested with requestFullUpdateBeforeDraw()
        while (shouldUpdateAndDrawAgain) {
            shouldUpdateAndDrawAgain = false;
            var _delta:Float = isFirstUpdateInFrame ? delta : 0;

#if ceramic_debug_cputime cpuTimeRec(3); #end
            
            // Reset screen deltas
            screen.resetDeltas();
            
            // Run 'begin update' callbacks, like touch/mouse/key events etc...
            if (beginUpdateCallbacks.length > 0) {
                var callbacks = beginUpdateCallbacks;
                beginUpdateCallbacks = [];
                for (callback in callbacks) {
                    callback();
                }
            }
            
#if ceramic_debug_cputime cpuTimePause(3); #end
#if ceramic_debug_cputime cpuTimeRec(4); #end

            // Trigger pre-update event
            emitPreUpdate(_delta);

#if ceramic_debug_cputime cpuTimePause(4); #end
#if ceramic_debug_cputime cpuTimeRec(5); #end

            // Update/pre-update physics bodies (if enabled)
#if ceramic_arcade_physics
            flushImmediate();
            if (_delta > 0) arcade.preUpdate(_delta);
#end
#if ceramic_nape_physics
            flushImmediate();
            if (_delta > 0) nape.update(_delta);
#end

            // Flush immediate callbacks
            flushImmediate();

            if (_delta > 0) {

                // Update tweens
                Tween.tick(delta);

                // Flush immediate callbacks
                flushImmediate();
            }

#if ceramic_debug_cputime cpuTimePause(5); #end
#if ceramic_debug_cputime cpuTimeRec(6); #end

            // Then update
            emitUpdate(_delta);

            // Flush immediate callbacks
            flushImmediate();

            // Post-update physics bodies (if enabled)
#if ceramic_arcade_physics
            if (_delta > 0) arcade.postUpdate(_delta);
            flushImmediate();
#end

#if ceramic_debug_cputime cpuTimePause(6); #end
#if ceramic_debug_cputime cpuTimeRec(7); #end

            // Emit post-update event
            emitPostUpdate(_delta);

            // Flush immediate callbacks
            flushImmediate();

            // Destroy disposed entities
            while (disposedEntities.length > 0) {
                var toDestroy = disposedEntities.shift();
                toDestroy.destroy();
            }

#if ceramic_debug_cputime cpuTimePause(7); #end
#if ceramic_debug_cputime cpuTimeRec(8); #end

            // Sync pending and destroyed visuals
            syncPendingVisuals();

            // Update visuals
            updateVisuals(visuals);

#if ceramic_debug_cputime cpuTimePause(8); #end
#if ceramic_debug_cputime cpuTimeRec(9); #end

            // Update hierarchy from depth
            computeHierarchy();

#if ceramic_debug_cputime cpuTimePause(9); #end
#if ceramic_debug_cputime cpuTimeRec(10); #end

            // Compute render textures priority
            computeRenderTexturesPriority(renderTextures);

#if ceramic_debug_cputime cpuTimePause(10); #end
#if ceramic_debug_cputime cpuTimeRec(11); #end

            // Sync destroyed visuals again, if needed, before sorting
            syncDestroyedVisuals();

            // Sort visuals depending on their settings
            sortVisuals(visuals);

#if ceramic_debug_cputime cpuTimePause(11); #end
#if ceramic_debug_cputime cpuTimeRec(12); #end

            // First update in frame finished
            isFirstUpdateInFrame = false;

            // Begin draw
            emitBeginDraw();

            // Draw (clears anything drawn before)
            backend.draw.draw(visuals);

            // End draw
            emitFinishDraw();

#if ceramic_debug_cputime cpuTimePause(12); #end

            // Will update again if requested
            // or continue with drawing
        }

        // Swap display (if backends needs to)
        backend.draw.swap();

        // Update finished
        inUpdate = false;

    }

    @:noCompletion
    inline public function addVisual(visual:Visual):Void {

        pendingVisuals.push(visual);

    }

    @:noCompletion
    inline public function removeVisual(visual:Visual):Void {

        destroyedVisuals.push(visual);

    }

    /*inline*/ function syncPendingVisuals():Void {

        if (pendingVisuals.length > 0) {

            // Add pending visuals
            while (pendingVisuals.length > 0) {
                visuals.push(pendingVisuals.pop());
            }

            hierarchyDirty = true;

        }

    }

    inline function syncDestroyedVisuals():Void {

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

    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end public function updateVisuals(visuals:Array<Visual>) {

        var numIterations = 0;
        var didFlush = false;

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
        }
        while (didFlush || visualsContentDirty);

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
                }

                if (visual.computedRenderTarget != null) {
                    if (visual.asQuad != null) {
                        if (visual.asQuad.texture != null) {
                            visual.computedRenderTarget.incrementDependingTextureCount(visual.asQuad.texture);
                        }
                    }
                    else if (visual.asMesh != null) {
                        if (visual.asMesh.texture != null) {
                            visual.computedRenderTarget.incrementDependingTextureCount(visual.asMesh.texture);
                        }
                    }
                }
            }

        }

    }

    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end public function computeHierarchy() {

        if (hierarchyDirty) {

            // Compute visuals depth
            for (i in 0...visuals.length) {

                var visual = visuals.unsafeGet(i);
                if (!visual.destroyed) {

                    if (visual.parent == null) {
                        visual.computedDepth = visual.depth * Visual.DEPTH_FACTOR;

                        if (visual.children != null) {
                            visual.computeChildrenDepth();
                        }
                    }
                }
            }

            hierarchyDirty = false;
        }

    }

    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end public function computeRenderTexturesPriority(renderTextures:Array<RenderTexture>) {

        if (renderTextures.length == 0)
            return;

        // Sort by dependance
        SortRenderTextures.sort(renderTextures);
    
        // Update priorities from order
        var len = renderTextures.length;
        for (i in 0...len) {
            var renderTexture = renderTextures.unsafeGet(i);
            renderTexture.priority = i + 1;
        }

    }

    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end public function sortVisuals(visuals:Array<Visual>) {

        // Emit event before sorting visuals (last moment we can tweak visuals sorting)
        emitBeginSortVisuals();

        // Sort visuals by (computed) depth
        SortVisuals.sort(visuals);

        // Emit event after sorting visuals (if we want to reverse any tweak)
        emitFinishSortVisuals();

    }

/// Groups

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

#if ceramic_debug_cputime

    @:noCompletion public var _cpuStart:Array<Float> = [];
    @:noCompletion public var _cpuTotal:Array<Float> = [];

    var _debugCpuTime:Bool = false;
    var _lastDebugCpuTime:Float = -1;

    @:noCompletion inline public function cpuTimeRec(index:Int):Void {
        _cpuStart.unsafeSet(index, Sys.cpuTime());
    }

    @:noCompletion inline public function cpuTimePause(index:Int):Void {
        var val = Sys.cpuTime() - _cpuStart.unsafeGet(index);
        val += _cpuTotal.unsafeGet(index);
        _cpuTotal.unsafeSet(index, val);
    }

    function _debugCpuTimeThisFrame() {

        if (ceramic.Timer.now - _lastDebugCpuTime > 10) {
            _debugCpuTime = true;
            _lastDebugCpuTime = ceramic.Timer.now;

            if (_cpuTotal.length > 0) {
                _printCpuTime();
            }

            for (i in 0..._cpuTotal.length) {
                _cpuTotal[i] = 0.0;
            }
        } else {
            _debugCpuTime = false;
        }

        _cpuStart[200] = 0;
        _cpuTotal[200] = 0;

    }

    function _printCpuTime() {

        log.info('// cpu time //');
        log.debug(' - timer: ' + _cpuTotal[0]);
        log.debug(' - runner: ' + _cpuTotal[1]);
        log.debug(' - pointer over: ' + _cpuTotal[2]);
        log.debug(' - begin update cb: ' + _cpuTotal[3]);
        log.debug(' - pre update: ' + _cpuTotal[4]);
        log.debug(' - physics: ' + _cpuTotal[5]);
        log.debug(' - update: ' + _cpuTotal[6]);
        log.debug(' - post update: ' + _cpuTotal[7]);
        log.debug(' - update visuals: ' + _cpuTotal[8]);
        log.debug(' - compute hierarchy: ' + _cpuTotal[9]);
        log.debug(' - texture priority: ' + _cpuTotal[10]);
        log.debug(' - sort visuals: ' + _cpuTotal[11]);
        log.debug(' - draw: ' + _cpuTotal[12]);

    }

#end

}
