package ceramic;

import ceramic.Shortcuts.*;

@:allow(ceramic.SceneSystem)
class Scene extends Layer {

    var _assets:Assets = null;

    var didCreate:Bool = false;

    public var assets(get, set):Assets;
    function get_assets():Assets {
        if (_assets == null && !destroyed) {
            _assets = new Assets();
        }
        return _assets;
    }
    function set_assets(assets:Assets):Assets {
        return _assets = assets;
    }

    /** Set to `false` if you want to disable auto update on this scene object.
        If auto update is disabled, you become responsible to explicitly call
        `update(delta)` at every frame yourself. Use this if you want to have control over
        when the animation update is actually happening. Don't use it to pause animation.
        (animation can be paused with `paused` property instead) */
    public var autoUpdate:Bool = true;

    /** Is this scene paused? */
    public var paused:Bool = false;

    public function new() {

        super();

        transparent = true;

        SceneSystem.shared.scenes.push(cast this);

    }

    function _boot() {

        preload();

        if (_assets != null && _assets.hasAnythingToLoad()) {
            // If assets have been added, load them
            _assets.onceComplete(this, _handleAssetsComplete);
            _assets.load();
        }
        else {
            // No asset, can call load() directly
            load(internalCreate);
        }

    }

    function internalCreate() {

        create();
        didCreate = true;

    }

    function _handleAssetsComplete(successful:Bool):Void {

        if (successful) {
            load(internalCreate);
        }
        else {
            log.error('Failed to load all scene assets!');
        }

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
    function load(next:Void->Void):Void {

        // Override in subclasses

        // Default: there is nothing asynchronous to load, just call next()
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

    override function destroy() {

        SceneSystem.shared.scenes.remove(cast this);

        if (_assets != null) {
            _assets.destroy();
            _assets = null;
        }

        super.destroy();

    }

}