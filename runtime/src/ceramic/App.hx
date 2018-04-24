package ceramic;

import ceramic.internal.PlatformSpecific;

import ceramic.Settings;
import ceramic.Assets;
import ceramic.Fragment;
import ceramic.Texture;
import ceramic.BitmapFont;
import ceramic.ConvertField;
import ceramic.Collections;
import ceramic.Shortcuts.*;

import backend.Backend;

#if !macro
@:build(ceramic.macros.AppMacro.build())
#end
@:allow(ceramic.Visual)
@:allow(ceramic.Screen)
class App extends Entity {

/// Shared instances

    public static var app(get,null):App;
    static inline function get_app():App { return app; }

/// Events

    /** Ready event is triggered when the app is ready and
        the game logic can be started. */
    @event function ready();

    /** Update event is triggered as many times as there are frames per seconds.
        It is in sync with screen FPS but used for everything that needs
        to get updated depending on time (ceramic.Timer relies on it).
        Use this event to update your contents before they get drawn again. */
    @event function update(delta:Float);

    /** Pre-update event is triggered right before update event and
        can be used when you want to run garantee your code
        will be run before regular update event.*/
    @event function preUpdate(delta:Float);

    /** Post-update event is triggered right after update event and
        can be used when you want to run garantee your code
        will be run after regular update event.*/
    @event function postUpdate(delta:Float);

    @event function keyDown(key:Key);
    @event function keyUp(key:Key);

    @event function controllerAxis(controllerId:Int, axisId:Int, value:Float);
    @event function controllerDown(controllerId:Int, buttonId:Int);
    @event function controllerUp(controllerId:Int, buttonId:Int);
    @event function controllerEnable(controllerId:Int, name:String);
    @event function controllerDisable(controllerId:Int);

    /** Assets events */
    @event function defaultAssetsLoad(assets:Assets);

/// Immediate update event, custom implementation

    var immediateCallbacks:Array<Void->Void> = null;

    /** Schedule immediate callback that is garanteed to be executed before the next time frame
        (before elements are draw onto screen) */
    public function onceImmediate(handleImmediate):Void {

        if (immediateCallbacks == null) {
            immediateCallbacks = [handleImmediate];
        }
        else {
            immediateCallbacks.push(handleImmediate);
        }

    } //onceImmediate

    /** Execute and flush every awaiting immediate callback, including the ones that
        could have been added with `onceImmediate()` after executing the existing callbacks. */
    inline function flushImmediate():Void {

        while (immediateCallbacks != null) {

            var callbacks = immediateCallbacks;
            immediateCallbacks = null;

            for (cb in callbacks) {
                cb();
            }

        }

    } //flushImmediate

/// Static pre-init code (used to add plugins)

    static var preInitCallbacks:Array<Void->Void>;
    static function oncePreInit(handle:Void->Void):Void {
        if (preInitCallbacks == null) preInitCallbacks = [];
        preInitCallbacks.push(handle);
    }

/// Properties

    /** Backend instance */
    public var backend(default,null):Backend;

    /** Screen instance */
    public var screen(default,null):Screen;

    /** App settings */
    public var settings(default,null):Settings;

    /** Logger. Used by log() shortcut */
    public var logger(default,null):Logger = new Logger();

    /** Visuals (ordered) */
    public var visuals(default,null):Array<Visual> = [];

    /** App level assets. Used to load default bitmap font */
    public var assets(default,null):Assets = new Assets();

    /** App level collections */
    public var collections(default,null):Collections = new Collections();

    /** Default color shader **/
    public var defaultColorShader(default,null):Shader = null;

    /** Default textured shader **/
    public var defaultTexturedShader(default,null):Shader = null;

    /** Default font */
    public var defaultFont(default,null):BitmapFont = null;

/// Field converters

    public var converters:Map<String,ConvertField<Dynamic,Dynamic>> = new Map();

    public var componentInitializers:Map<String,Array<Dynamic>->Component> = new Map();

/// Internal

    var hierarchyDirty:Bool = false;

    /** List of functions that will be called and purged when update iteration begins.
        Useful to run some specific code once exactly before update event is sent. */
    var beginUpdateCallbacks:Array<Void->Void> = [];

/// Public initializer

    public static function init():InitSettings {

#if cpp
        untyped __global__.__hxcpp_set_critical_error_handler(function(message:String) throw message);
#end

        app = new App();
        return new InitSettings(app.settings);
        
    } //init
    
/// Lifecycle

    function new() {

        settings = new Settings();
        screen = new Screen();

        backend = new Backend();
        backend.onceReady(this, backendReady);
        backend.init(this);

    } //new

    function backendReady():Void {

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

        // Init component initializers
        initComponentInitializers();

        // Init collections
        initCollections();

        // Load default assets
        //
        // Default font
        assets.add(Fonts.ARIAL_20);

        // Default shaders
        assets.add(Shaders.COLOR);
        assets.add(Shaders.TEXTURED);

        assets.onceComplete(this, function(success) {

            if (success) {

                // Get default asset instances now that they are loaded
                defaultFont = assets.font(Fonts.ARIAL_20);
                defaultColorShader = assets.shader(Shaders.COLOR);
                defaultTexturedShader = assets.shader(Shaders.TEXTURED);

                logger.success('Default assets loaded.');
                assetsLoaded();
            } else {
                error('Failed to load default assets.');
            }

        });
        
        // Allow to load more default assets
        emitDefaultAssetsLoad(assets);

        assets.load();

    } //backendReady

    function initFieldConverters():Void {

        converters.set('ceramic.Texture', new ConvertTexture());
        converters.set('ceramic.BitmapFont', new ConvertFont());
        converters.set('ceramic.FragmentData', new ConvertFragmentData());
        converters.set('Map<String,String>', new ConvertMap<String>());
        converters.set('Map<String,Bool>', new ConvertMap<Bool>());
        converters.set('ImmutableMap<String,String>', new ConvertMap<String>());
        converters.set('ceramic.ImmutableMap<String,Bool>', new ConvertMap<Bool>());
        converters.set('ceramic.ImmutableMap<String,ceramic.Component>', new ConvertComponentMap());

    } //initFieldConverters

    function initComponentInitializers():Void {

        // Nothing to do for now

    } //initComponentInitializers

    function initCollections():Void {

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

                            }
                        }
                    }
                }

            });

        }

    } //initCollections

    function assetsLoaded():Void {

        // Platform specific code (which is not in backend code)
        PlatformSpecific.postAppInit();

        emitReady();

        screen.resize();

        backend.onUpdate(this, update);

        // Forward key events
        //
        backend.onKeyDown(this, function(key) {
            beginUpdateCallbacks.push(function() emitKeyDown(key));
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

    } //assetsLoaded

    function update(delta:Float):Void {

        Timer.update(delta);

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

        // Flush immediate callbacks
        flushImmediate();

        // Then update
        emitUpdate(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Emit post-update event
        emitPostUpdate(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Notify if screen matrix has changed
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

        // Update hierarchy from depth
        computeHierarchy();

        // Dispatch visual transforms changes
        for (visual in visuals) {

            if (visual.transform != null && visual.transform.changed) {
                visual.transform.emitChange();
            }

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

        }

        // Flush immediate callbacks
        flushImmediate();

        // Emit pre-draw event
        screen.emitPreDraw(delta);

        // Flush immediate callbacks
        flushImmediate();

        // Draw
        backend.draw.draw(visuals);

        // Emit post-draw event
        screen.emitPostDraw(delta);

    } //update

    inline function computeHierarchy() {

        if (hierarchyDirty) {

            // Compute visuals depth
            for (visual in visuals) {

                if (visual.parent == null) {
                    visual.computedDepth = visual.depth;

                    if (visual.children != null) {
                        visual.computeChildrenDepth();
                    }
                }
            }

            sortVisuals();

            hierarchyDirty = false;
        }

    } //computeHierarchy

    inline function sortVisuals() {

        // Sort visuals by (computed) depth
        haxe.ds.ArraySort.sort(visuals, function(a:Visual, b:Visual):Int {

            if (a.computedDepth > b.computedDepth) return 1;
            if (a.computedDepth < b.computedDepth) return -1;
            // TODO handle meshes
            var aQuad:Quad = a.quad;
            var bQuad:Quad = b.quad;
            if (aQuad != null && bQuad == null) return 1;
            if (aQuad == null && bQuad != null) return -1;
            if (aQuad != null && bQuad != null) {
                if (aQuad.texture != null && bQuad.texture == null) return 1;
                if (aQuad.texture == null && bQuad.texture != null) return -1;
                if (aQuad.texture != null && bQuad.texture != null) {
                    if (aQuad.texture.index > bQuad.texture.index) return 1;
                    if (aQuad.texture.index < bQuad.texture.index) return -1;
                }
            }
            return 0;

        });

    } //sortVisuals

/// Uncaught errors

    static function handleUncaughtError(e:Dynamic):Void {

        throw e; // TODO don't rethrow and add logic to be able to save crash dump

#if sys
        Sys.exit(1);
#end

    } //handleUncaughtError

}
