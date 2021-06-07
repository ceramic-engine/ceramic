package ceramic;

using ceramic.Extensions;

@:allow(ceramic.Scene)
class SceneSystem extends System {

    /**
     * Shared scene system
     */
    @lazy public static var shared = new SceneSystem();

    var scenes:Array<Scene> = [];

    var _updatingScenes:Array<Scene> = [];

    public var currentScene(default,null):Scene = null;

    /**
     * Set the given scene as current.
     * @param scene the scene to use as current scene
     * @param keepAssets
     *          if `true`, assets of the previous current scene will be kept instead of being destroyed
     *          and can be reused by the new current scene without having to reload these
     */
    public function setCurrentScene(scene:Scene, keepAssets:Bool = false):Void {

        if (this.currentScene != scene) {

            var prevScene = this.currentScene;
            if (scene == null) {
                this.currentScene = null;
                prevScene.destroy();
            }
            else {
                var prevAssets = null;
                if (prevScene != null) {
                    if (keepAssets) {
                        prevAssets = prevScene._assets;
                        prevScene._assets = null;
                    }
                    this.currentScene = null;
                    prevScene.destroy();
                }
                scene._assets = prevAssets;
                scene.bindToScreenSize();
                scene._boot();
            }

        }

    }

    override function new() {

        super();

        lateUpdateOrder = 5000;

    }

    override function lateUpdate(delta:Float):Void {

        // Work on a copy of list, to ensure nothing bad happens
        // if a new item is created or destroyed during iteration
        var len = scenes.length;
        for (i in 0...len) {
            _updatingScenes[i] = scenes.unsafeGet(i);
        }

        // Call
        for (i in 0...len) {
            var scene = _updatingScenes.unsafeGet(i);
            if (!scene.paused && scene.autoUpdate && scene.didCreate) {
                scene.update(delta);
            }
        }

        // Cleanup array
        for (i in 0...len) {
            _updatingScenes.unsafeSet(i, null);
        }

    }

}
