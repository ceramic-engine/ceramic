package ceramic;

using ceramic.Extensions;

@:allow(ceramic.Scene)
class SceneSystem extends System {

    /**
     * Shared scene system
     */
    @lazy public static var shared = new SceneSystem();

    public var all(default, null):ReadOnlyArray<Scene> = [];

    var _updatingScenes:Array<Scene> = [];

    /**
     * If `true`, when assigning a new main scene, assets of the previous
     * main scene will be kept instead of being destroyed and can be
     * reused by the new main scene without having to reload these
     */
    public var keepAssetsForNextMain:Bool = false;

    /**
     * If `true`, when assigning a new main scene, previous main
     * scene will wait until the next scene is properly loaded and can fade-in
     * before starting its own fade-out transition.
     */
    public var fadeOutWhenNextMainCanFadeIn:Bool = true;

    public var main(default,set):Scene = null;

    function set_main(main:Scene):Scene {
        
        if (this.main != main) {

            var prevScene = this.main;
            if (main == null) {
                this.main = null;
                switch prevScene.status {
                    case NONE | PRELOAD | LOAD | CREATE | FADE_IN:
                        prevScene.scheduleOnceReady(prevScene, prevScene.destroy);
                    case READY:
                        prevScene.fadeOut(prevScene.destroy);
                    case FADE_OUT | DISABLED:
                        prevScene.destroy();
                }
            }
            else {

                if (main.destroyed)
                    throw 'Cannot assign a destroyed scene as main scene!';

                var prevAssets = null;
                this.main = main;
                
                if (prevScene != null) {
                    var keepAssets = keepAssetsForNextMain;
                    if (keepAssets) {
                        prevAssets = prevScene._assets;
                    }
                    this.main = null;
                    var fadeOutDone = function() {
                        if (keepAssets) {
                            prevScene._assets = null;
                        }
                        prevScene.destroy();
                        prevScene = null;
                    };

                    inline function prevSceneFadeOut() {
                        switch prevScene.status {
                            case READY:
                                prevScene.fadeOut(fadeOutDone);
                            case NONE | PRELOAD | LOAD | CREATE | FADE_IN | FADE_OUT | DISABLED:
                                fadeOutDone();
                        }
                    }

                    if (fadeOutWhenNextMainCanFadeIn) {
                        var handleStatusChange = null;
                        switch main.status {

                            case NONE | PRELOAD | LOAD | CREATE:
                                handleStatusChange = function(current:SceneStatus, previous:SceneStatus) {
                                    switch current {
                                        case NONE | PRELOAD | LOAD | CREATE:
                                        case FADE_IN | READY | FADE_OUT | DISABLED:
                                            main.offStatusChange(handleStatusChange);
                                            prevSceneFadeOut();
                                    }
                                };
                                main.onStatusChange(prevScene, handleStatusChange);

                            case FADE_IN | READY | FADE_OUT | DISABLED:
                                prevSceneFadeOut();
                        }
                    }
                    else {
                        prevSceneFadeOut();
                    }
                }

                main._assets = prevAssets;
                main.bindToScreenSize();
                main._boot();
            }

        }

        return main;

    }

    @:deprecated('Deprecated: use `app.scenes.main = yourScene;` instead')
    inline function setCurrentScene(scene:Scene, keepAssets:Bool = false):Void {

        keepAssetsForNextMain = keepAssets;
        main = scene;

    }

    override function new() {

        super();

        lateUpdateOrder = 5000;

    }

    override function lateUpdate(delta:Float):Void {

        // Work on a copy of list, to ensure nothing bad happens
        // if a new item is created or destroyed during iteration
        var len = all.length;
        for (i in 0...len) {
            _updatingScenes[i] = all.unsafeGet(i);
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
