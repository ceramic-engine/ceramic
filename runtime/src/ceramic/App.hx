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

    /**
     * @event keyDown
     * Triggered when a key from the keyboard is being pressed.
     * @param key The key being pressed
     */
    @event function keyDown(key:Key);
    /**
     * @event keyUp
     * Triggered when a key from the keyboard is being released.
     * @param key The key being released
     */
    @event function keyUp(key:Key);

    @event function controllerAxis(controllerId:Int, axisId:Int, value:Float);
    @event function controllerDown(controllerId:Int, buttonId:Int);
    @event function controllerUp(controllerId:Int, buttonId:Int);
    @event function controllerEnable(controllerId:Int, name:String);
    @event function controllerDisable(controllerId:Int);

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

    var immediateCallbacksLen:Int = 0;

    var postFlushImmediateCallbacks:Array<Void->Void> = [];

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
        immediateCallbacks[immediateCallbacksLen++] = handleImmediate;
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
                postFlushImmediateCallbacks[postFlushImmediateCallbacksLen++] = handlePostFlushImmediate;
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
                immediateCallbacks[i] = null;
            }

            for (i in 0...len) {
                var cb = callbacks.get(i);
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
                postFlushImmediateCallbacks[i] = null;
            }

            for (i in 0...len) {
                var cb = callbacks.get(i);
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

    /** Current frame delta time */
    public var delta(default,null):Float;

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

    /** Visuals (ordered) */
    public var visuals(default,null):Array<Visual> = [];

    /** Groups */
    public var groups(default,null):Array<Group<Entity>> = [];

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

    var pressedScanCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedKeyCodes:IntIntMap = new IntIntMap(16, 0.5, false);

#if (web && hotml && ceramic_hotreload)
    var hotReloadClient:hotml.client.Client;
#end

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

        Runner.init();

        Tracker.backend = new TrackerBackend();

        settings = new Settings();
        screen = new Screen();
        audio = new Audio();

        backend = new Backend();
        backend.onceReady(this, backendReady);
        backend.init(this);

    }

    function backendReady():Void {

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

#if (web && hotml && ceramic_hotreload)
        log.debug('Initialize hot reload client');
        var port:Null<Int> = ceramic.macros.DefinesMacro.getDefine('ceramic_hotreload_port');
        hotReloadClient = new hotml.client.Client(port);
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
            
        });

        assets.load();

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
                                    var instance:CollectionEntry = Type.createInstance(entryClass, []);
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

        backend.onUpdate(this, update);

        // Forward key events
        //
        backend.onKeyDown(this, function(key) {
            beginUpdateCallbacks.push(function() {
                emitKeyDown(key);
            });
        });
        backend.onKeyUp(this, function(key) {
            beginUpdateCallbacks.push(function() emitKeyUp(key));
        });

        // Forward controller events
        backend.onControllerEnable(this, function(controllerId, name) {
            beginUpdateCallbacks.push(function() emitControllerEnable(controllerId, name));
        });
        backend.onControllerDisable(this, function(controllerId) {
            beginUpdateCallbacks.push(function() emitControllerDisable(controllerId));
        });
        backend.onControllerDown(this, function(controllerId, buttonId) {
            beginUpdateCallbacks.push(function() emitControllerDown(controllerId, buttonId));
        });
        backend.onControllerUp(this, function(controllerId, buttonId) {
            beginUpdateCallbacks.push(function() emitControllerUp(controllerId, buttonId));
        });
        backend.onControllerAxis(this, function(controllerId, axisId, value) {
            beginUpdateCallbacks.push(function() emitControllerAxis(controllerId, axisId, value));
        });

    }

    function update(delta:Float):Void {

        // Update computed fps
        _computeFps.addFrame(delta);

        // Update frame delta time
        this.delta = delta;

#if (cpp && linc_sdl)
        SDL.setLCNumericCLocale();
#end

#if hxtelemetry
        hxt.advance_frame();
#end

        Timer.update(delta);

        Runner.tick();

        // Screen pointer over/out events detection
        screen.updatePointerOverState(delta);

        // Run 'begin update' callbacks, like touch/mouse/key events etc...
        if (beginUpdateCallbacks.length > 0) {
            var callbacks = beginUpdateCallbacks;
            beginUpdateCallbacks = [];
            for (callback in callbacks) {
                callback();
            }
        }

        inUpdate = true;
        shouldUpdateAndDrawAgain = true;
        var isFirstUpdateInFrame = true;

        // Allow update section to be run multiple times before drawing
        // if this has been explicitly requested with requestFullUpdateBeforeDraw()
        while (shouldUpdateAndDrawAgain) {
            shouldUpdateAndDrawAgain = false;
            var _delta:Float = isFirstUpdateInFrame ? delta : 0;

            // Trigger pre-update event
            emitPreUpdate(_delta);

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

            // Then update
            emitUpdate(_delta);

            // Flush immediate callbacks
            flushImmediate();

            // Post-update physics bodies (if enabled)
#if ceramic_arcade_physics
            if (_delta > 0) arcade.postUpdate(_delta);
            flushImmediate();
#end

            // Emit post-update event
            emitPostUpdate(_delta);

            // Flush immediate callbacks
            flushImmediate();

            // Update visuals
            updateVisuals(visuals);

            // Update hierarchy from depth
            computeHierarchy();

            // Compute render textures priority
            computeRenderTexturesPriority(renderTextures);

            // Sort visuals depending on their settings
            sortVisuals(visuals);

            // First update in frame finished
            isFirstUpdateInFrame = false;

            // Begin draw
            emitBeginDraw();

            // Draw (clears anything drawn before)
            backend.draw.draw(visuals);

            // End draw
            emitFinishDraw();

            // Will update again if requested
            // or continue with drawing
        }

        // Swap display (if backends needs to)
        backend.draw.swap();

        // Update finished
        inUpdate = false;

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

            for (visual in visuals) {

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

            // Dispatch visual transforms changes
            for (visual in visuals) {

                if (visual.transform != null) {
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
                    for (visual in visuals) {
                        if (visual.contentDirty) {
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
        for (visual in visuals) {

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

    @:noCompletion
    #if (!debug && !ceramic_debug_perf) inline #end public function computeHierarchy() {

        if (hierarchyDirty) {

            // Compute visuals depth
            for (visual in visuals) {

                #if ceramic_debug_num_visuals
                if (visual.destroyed) {
                    throw 'Visual is destroyed but in hierarchy: $visual';
                }
                #end

                if (visual.parent == null) {
                    visual.computedDepth = visual.depth * Visual.DEPTH_FACTOR;

                    if (visual.children != null) {
                        visual.computeChildrenDepth();
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

/// Keyboard

    function willEmitKeyDown(key:Key):Void {

        var prevScan = pressedScanCodes.get(key.scanCode);
        var prevKey = pressedKeyCodes.get(key.keyCode);

        pressedScanCodes.set(key.scanCode, prevScan + 1);
        pressedKeyCodes.set(key.keyCode, prevKey + 1);

        if (prevScan == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            beginUpdateCallbacks.push(function() {
                if (pressedScanCodes.get(key.scanCode) == 1) {
                    pressedScanCodes.set(key.scanCode, 2);
                }
                if (pressedKeyCodes.get(key.keyCode) == 1) {
                    pressedKeyCodes.set(key.keyCode, 2);
                }
            });
        }

    }

    function willEmitKeyUp(key:Key):Void {

        pressedScanCodes.set(key.scanCode, 0);
        pressedKeyCodes.set(key.keyCode, 0);

    }

    public function keyCodePressed(keyCode:Int):Bool {

        return pressedKeyCodes.get(keyCode) > 0;

    }

    public function keyCodeJustPressed(keyCode:Int):Bool {

        return pressedKeyCodes.get(keyCode) == 1;

    }

    public function scanCodePressed(scanCode:Int):Bool {

        return pressedScanCodes.get(scanCode) > 0;

    }

    public function scanCodeJustPressed(scanCode:Int):Bool {

        return pressedScanCodes.get(scanCode) == 1;

    }

    public function keyPressed(key:Key):Bool {

        return pressedScanCodes.get(key.scanCode) > 0;

    }

    public function keyJustPressed(key:Key):Bool {

        return pressedScanCodes.get(key.scanCode) == 1;

    }

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
