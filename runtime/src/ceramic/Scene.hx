package ceramic;

import ceramic.Shortcuts.*;
import tracker.Observable;

/**
 * Base class for creating scenes in Ceramic.
 * 
 * Scenes are self-contained units of gameplay or application screens that manage
 * their own assets, lifecycle, and update loop. They provide a structured way to
 * organize different parts of your application (menus, levels, settings, etc.).
 * 
 * Key features:
 * - Automatic asset loading and management
 * - Lifecycle management (boot, preload, create, update, destroy)
 * - Scene transition support
 * - Pause/resume functionality
 * - Observable status for tracking scene state
 * 
 * Typical scene lifecycle:
 * 1. `new()` - Constructor
 * 2. `preload()` - Load assets (optional)
 * 3. `create()` - Initialize scene content
 * 4. `update()` - Called every frame while active
 * 5. `destroy()` - Cleanup
 * 
 * Example usage:
 * ```haxe
 * class GameScene extends Scene {
 *     override function preload() {
 *         assets.add(Images.PLAYER);
 *         assets.add(Sounds.MUSIC);
 *     }
 *     
 *     override function create() {
 *         // Initialize game objects
 *     }
 *     
 *     override function update(delta:Float) {
 *         // Update game logic
 *     }
 * }
 * ```
 */
#if (!macro && !completion)
@:autoBuild(ceramic.macros.SceneMacro.build())
#end
@:allow(ceramic.SceneSystem)
class Scene #if (plugin_ui && ceramic_scene_ui) extends View #else extends Layer #end implements Observable implements Preloadable {

    var _assets:Assets = null;

    var _assetsProgress:Int = 0;

    var _assetsTotal:Int = 0;

    var _assetsFailure:Bool = false;

    /**
     * An event to replace this scene with a new one.
     * By default, this has effect only if our current scene instance was initially assigned
     * to the scene system, like when using `app.scenes.main = MyScene();`, but you
     * could implement your own logic by listening to that event in other situations too.
     * @param newScene
     */
    @event function replace(newScene:Scene);

    /**
     * Observable status of this scene.
     * Possible values: NONE, PRELOAD, PRELOAD_COMPLETE, CREATE, READY
     */
    @observe var status:SceneStatus = NONE;

    /**
     * Asset manager for this scene.
     * Automatically created when accessed for the first time.
     * Use this to load images, sounds, fonts, etc. during the preload phase.
     */
    public var assets(get, set):Assets;
    function get_assets():Assets {
        if (_assets == null && !destroyed) {
            _assets = new Assets();

            // These can be changed on scene subclasses if needed,
            // but so far it should be a good compromise between
            // fast loading of assets and still prevent screen
            // from freezing to allow display (of progress) to update.
            _assets.loadMethod = ASYNC;
            _assets.scheduleMethod = PARALLEL;
            _assets.delayBetweenXAssets = 4;

            _assets.onProgress(this, (loaded, total, success) -> {
                _assetsProgress = loaded;
                _assetsTotal = total;
            });
            _assets.onceComplete(this, (success) -> {
                if (!success) {
                    _assetsFailure = true;
                }
            });
        }
        return _assets;
    }
    function set_assets(assets:Assets):Assets {
        return _assets = assets;
    }

    /**
     * Whether this scene is a root scene.
     * Root scenes are managed by the SceneSystem and receive automatic updates.
     */
    public var isRootScene(default, null):Bool = false;

    /**
     * Set to `false` if you want to disable auto update on this scene object.
     * If auto update is disabled, you become responsible to explicitly call
     * `update(delta)` at every frame yourself. Use this if you want to have control over
     * when the animation update is actually happening. Don't use it to pause animation.
     * (animation can be paused with `paused` property instead)
     */
    public var autoUpdate:Bool = true;

    /**
     * If `autoUpdate` is enabled, setting `autoUpdateWhenInactive` to `true`
     * will keep updating the scene even when inactive.
     */
    public var autoUpdateWhenInactive:Bool = false;

    /**
     * Whether this scene is paused.
     * When paused, the update() method will not be called.
     */
    public var paused:Bool = false;

    /**
     * Create a new scene instance.
     */
    public function new() {

        super();

        transparent = true;

        SceneSystem.shared.all.original.push(cast this);

    }

    function _boot() {

        if (status != NONE) {
            log.warning('Scene already booted! (status: $status)');
            return;
        }

        status = PRELOAD;
        preload();

        status = LOAD;
        if (_assets != null && _assets.hasAnythingToLoad()) {
            // If assets have been added, load them
            _assets.onceComplete(this, _handleAssetsComplete);
            _assets.load(false);
        }
        else {
            // No asset, can call load() directly
            internalLoad();
        }

    }

    function internalCreate() {

        status = CREATE;
        try {
            create();
            fadeIn(_fadeInDone);
        }
        catch (e:Any) {
            @:privateAccess Errors.handleUncaughtError(e);
        }

    }

    function _fadeInDone():Void {

        // Nothing to do here

    }

    function _handleAssetsComplete(successful:Bool):Void {

        if (successful) {
            app.onceImmediate(this, internalLoad);
        }
        else {
            log.error('Failed to load all scene assets!');
        }

    }

    function internalLoad() {

        if (_preloadedFragments != null) {
            _createPreloadedFragments();
        }
        else {
            load(internalCreate);
        }

    }

/// Fragments

    /**
     * Fragments asked with `preloadFragment()` and not given yet by `loadFragment()`:
     * fragments asset name, fragment id and instance (once created) of each.
     */
    var _preloadedFragmentAssets:Array<String> = null;

    var _preloadedFragmentIds:Array<String> = null;

    var _preloadedFragments:Array<Fragment> = null;

    /**
     * Preload a fragment of a fragments file, along with everything it
     * displays (textures, fonts...). To be called from `preload()`.
     *
     * The fragment is then available from `create()` with `loadFragment()`.
     *
     * ```haxe
     * override function preload() {
     *     preloadFragment(Fragments.MENUS, 'main-menu');
     * }
     *
     * override function create() {
     *     var menu = loadFragment('main-menu');
     * }
     * ```
     *
     * @param fragments The fragments asset (name or asset id)
     * @param fragmentId The id of the fragment in that asset
     */
    public function preloadFragment(fragments:Either<String,AssetId<String>>, fragmentId:String):Void {

        var name:String = cast fragments;
        if (StringTools.startsWith(name, 'fragments:')) name = name.substr(10);

        if (assets.fragmentsAsset(name) == null) {
            assets.addFragments(name);
        }

        if (_preloadedFragments == null) {
            _preloadedFragmentAssets = [];
            _preloadedFragmentIds = [];
            _preloadedFragments = [];
        }
        _preloadedFragmentAssets.push(name);
        _preloadedFragmentIds.push(fragmentId);
        _preloadedFragments.push(null);

    }

    /**
     * Create a fragment from a fragments file and add it to this scene.
     *
     * A fragment preloaded with `preloadFragment()` is ready to be displayed.
     * Otherwise, `fragments` is required and what the fragment displays
     * is loaded on the fly (see `Fragment.ready`).
     *
     * When the app reloads its assets as files change (see
     * `Assets.watchDirectory()`), the fragment follows its file.
     *
     * @param fragmentId The id of the fragment
     * @param fragments The fragments asset (name or asset id) the fragment is in.
     *                  Can be omitted if the fragment has been preloaded.
     * @return The fragment, or null if it could not be found
     */
    public function loadFragment(fragmentId:String, ?fragments:Either<String,AssetId<String>>):Null<Fragment> {

        var name:String = fragments != null ? cast fragments : null;
        if (name != null && StringTools.startsWith(name, 'fragments:')) name = name.substr(10);

        // Preloaded?
        if (_preloadedFragments != null) {
            for (i in 0..._preloadedFragments.length) {
                if (_preloadedFragmentIds[i] == fragmentId && (name == null || name == _preloadedFragmentAssets[i])) {
                    var fragment = _preloadedFragments[i];
                    if (fragment != null) {
                        _preloadedFragmentAssets.splice(i, 1);
                        _preloadedFragmentIds.splice(i, 1);
                        _preloadedFragments.splice(i, 1);
                        fragment.active = true;
                        add(fragment);
                        return fragment;
                    }
                    else if (name == null) {
                        name = _preloadedFragmentAssets[i];
                    }
                }
            }
        }

        if (name == null) {
            log.error('Cannot load fragment $fragmentId: it was not preloaded and no fragments asset is given');
            return null;
        }

        var asset = assets.fragmentsAsset(name);
        if (asset == null) {
            log.error('Cannot load fragment $fragmentId: fragments asset $name was not added to the assets of the scene');
            return null;
        }

        var fragment = new Fragment(assets);
        fragment.loadFromAsset(asset, fragmentId);
        add(fragment);
        return fragment;

    }

    function _createPreloadedFragments():Void {

        var pending = 1;
        var done = function() {
            pending--;
            if (pending == 0 && !destroyed) {
                load(internalCreate);
            }
        };

        for (i in 0..._preloadedFragments.length) {
            if (_preloadedFragments[i] == null) {
                var asset = assets.fragmentsAsset(_preloadedFragmentAssets[i]);
                if (asset != null) {
                    // Created now, displayed when `loadFragment()` asks for it
                    var fragment = new Fragment(assets);
                    fragment.active = false;
                    _preloadedFragments[i] = fragment;
                    pending++;
                    fragment.loadFromAsset(asset, _preloadedFragmentIds[i]);
                    fragment.scheduleWhenReady(this, done);
                }
            }
        }

        done();

    }

    override function willEmitResize(width:Float, height:Float):Void {

        resize(width, height);

    }

/// Lifecycle

    /**
     * Override this method to configure the scene, add assets to it...
     * example: `assets.add(Images.SOME_IMAGE);`
     * Added assets will be loaded automatically
     */
    function preload():Void {

        // Override in subclasses

    }

    /**
     * Override this method to perform any additional asynchronous loading.
     * `next()` must be called once the loading has finished so that the scene
     * can continue its createialization process.
     * @param next The callback to call once asynchronous loading is done
     */
    function load(next:()->Void):Void {

        // Override in subclasses

        // Default: there is nothing asynchronous to load, just call next()
        if (!destroyed)
            next();

    }

    /**
     * Called once the scene has finished its loading.
     * At this point, and after `create()`, `update(delta)` will be called at every frame until the scene gets destroyed
     */
    function create():Void {

        // Override in subclasses

    }

    /**
     * Called when the scene's status becomes `READY`
     */
    public function ready():Void {

        // Override in subclasses

    }

    /**
     * Called at every frame, but only after create() has been called and when the scene is not paused
     * @param delta
     */
    public function update(delta:Float):Void {

        // Override in subclasses

    }

    /**
     * Called if the scene size has been changed during this frame.
     * @param width new width
     * @param height new height
     */
    public function resize(width:Float, height:Float):Void {

        // Override in subclasses

    }

    @:noCompletion function _fadeIn(done:()->Void):Void {

        done();

    }

    @:noCompletion function _fadeOut(done:()->Void):Void {

        done();

    }

    /**
     * Play **fade-in** transition of this scene. This is automatically called right after
     * the scene is ready to use, meaning after `create()` has been called.
     * Default implementation does nothing and calls `done()` right away.
     * Override in subclasses to perform custom transitions.
     * @param done Called when the fade-in transition has finished.
     */
    public function fadeIn(done:()->Void):Void {

        status = FADE_IN;
        _fadeIn(() -> {
            status = READY;

            if (!destroyed) {
                ready();
                done();
            }
        });

    }

    /**
     * Play **fade-out** transition of this scene. This is called manually on secondary scene
     * but will be called automatically if the scene is the **main scene** and is replaced
     * by a new scene or simply removed.
     * @param done Called when the fade-out transition has finished.
     */
    public function fadeOut(done:()->Void):Void {

        status = FADE_OUT;
        _fadeOut(() -> {
            status = DISABLED;

            if (!destroyed) {
                done();
            }
        });

    }

    /**
     * Check if the scene is ready (has completed initialization).
     * @return True if the scene status is READY, false otherwise
     */
    public function isReady():Bool {

        return switch status {
            case NONE: false;
            case PRELOAD: false;
            case LOAD: false;
            case CREATE: false;
            case FADE_IN: false;
            case READY: true;
            case FADE_OUT: false;
            case DISABLED: false;
        }

    }

    /**
     * Schedule a callback to be executed once the scene is ready.
     * If the scene is already ready, the callback is executed immediately.
     * @param owner The entity that owns the callback (for proper cleanup)
     * @param callback The function to call when the scene is ready
     * @return True if the callback was scheduled/executed, false if scene is destroyed or in invalid state
     */
    public function scheduleOnceReady(owner:Entity, callback:()->Void):Bool {

        if (destroyed) {
            log.warning('Cannot schedule callback on destroyed scene');
            return false;
        }

        switch status {

            case NONE | PRELOAD | LOAD | CREATE | FADE_IN:
                onceStatusChange(owner, function(_, _) {
                    scheduleOnceReady(owner, callback);
                });
                return true;

            case READY:
                callback();
                return true;

            case FADE_OUT | DISABLED:
                log.warning('Cannot schedule callback on scene with status: $status');
                return false;
        }

    }

    @:noCompletion
    public function requestPreloadUpdate(updatePreload:(progress:Int, total:Int, status:PreloadStatus)->Void):Void {

        final total:Int = _assetsTotal >= 1 ? _assetsTotal : 1;

        if (_assetsFailure) {
            updatePreload(_assetsProgress, total, ERROR);
        }
        else {
            switch status {
                case NONE:
                    updatePreload(0, 0, NONE);
                case PRELOAD:
                    updatePreload(_assetsProgress, total, LOADING);
                case LOAD:
                    updatePreload(_assetsProgress, total, LOADING);
                case CREATE:
                    updatePreload(total, total, LOADING);
                case FADE_IN:
                    updatePreload(total, total, SUCCESS);
                case READY:
                    updatePreload(total, total, SUCCESS);
                case FADE_OUT:
                    updatePreload(total, total, SUCCESS);
                case DISABLED:
                    updatePreload(total, total, SUCCESS);
            }
        }

    }

    override function destroy() {

        SceneSystem.shared.all.original.remove(cast this);

        if (_preloadedFragments != null) {
            // Preloaded fragments that were never displayed
            for (fragment in _preloadedFragments) {
                if (fragment != null) {
                    fragment.destroy();
                }
            }
            _preloadedFragments = null;
        }

        if (_assets != null) {
            _assets.destroy();
            _assets = null;
        }

        super.destroy();

    }

}
