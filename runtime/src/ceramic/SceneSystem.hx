package ceramic;

using ceramic.Extensions;

/**
 * System managing scenes display and lifecycle.
 * Use it to structure your app in different scenes.
 */
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
     * If `true`, main scene will be bound to screen size automatically
     */
    public var bindMainToScreenSize:Bool = true;

    /**
     * If `true`, when assigning a new main scene, previous main
     * scene will wait until the next scene is properly loaded and can fade-in
     * before starting its own fade-out transition.
     */
    public var fadeOutWhenNextMainCanFadeIn:Bool = true;

    /**
     * The main scene to display on screen.
     */
    public var main(default,set):Scene = null;

    public var rootScenes(default,null):ReadOnlyMap<String,Scene> = new Map();

    function set_main(main:Scene):Scene {
        
        if (this.main != main) {
            this.main = main;
            set('main', main, true, keepAssetsForNextMain);
        }

        return main;

    }

    /**
     * Assign secondary scenes to display them directly on screen.
     * @param name The slot name of the scene
     * @param scene The scene to assign
     * @param bindToScreenSize (optional) Set to `false` if you don't want the scene to follow screen size
     * @param keepAssets
     *          (optional) Set to `true` if you want this scene to keep the same **assets**
     *          instance as the previous scene on the same slot.
     */
    public function set(name:String, scene:Scene, bindToScreenSize:Bool = true, keepAssets:Bool = false):Void {

        var prevScene = rootScenes.get(name);

        if (scene != prevScene) {

            if (scene == null) {
                rootScenes.original.remove(name);
                if (name == 'main') {
                    this.main = null;
                }
                if (!prevScene.destroyed) {
                    switch prevScene.status {
                        case NONE | PRELOAD | LOAD | CREATE | FADE_IN:
                            prevScene.scheduleOnceReady(prevScene, prevScene.destroy);
                        case READY:
                            prevScene.fadeOut(prevScene.destroy);
                        case FADE_OUT | DISABLED:
                            prevScene.destroy();
                    }
                }
            }
            else {
    
                if (scene.destroyed)
                    throw 'Cannot assign a destroyed scene as root scene!';
    
                var prevAssets = null;
                rootScenes.original.set(name, scene);
                if (name == 'main') {
                    this.main = scene;
                }

                scene.onDestroy(this, destroyedScene -> {

                    var sceneInSlot = rootScenes.get(name);
                    if (destroyedScene == sceneInSlot) {
                        rootScenes.original.remove(name);
                        if (name == 'main') {
                            this.main = null;
                        }
                    }

                });
                
                if (prevScene != null) {
                    if (keepAssets) {
                        prevAssets = prevScene._assets;
                    }
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
                        switch scene.status {
    
                            case NONE | PRELOAD | LOAD | CREATE:
                                handleStatusChange = function(current:SceneStatus, previous:SceneStatus) {
                                    switch current {
                                        case NONE | PRELOAD | LOAD | CREATE:
                                        case FADE_IN | READY | FADE_OUT | DISABLED:
                                            scene.offStatusChange(handleStatusChange);
                                            prevSceneFadeOut();
                                    }
                                };
                                scene.onStatusChange(prevScene, handleStatusChange);
    
                            case FADE_IN | READY | FADE_OUT | DISABLED:
                                prevSceneFadeOut();
                        }
                    }
                    else {
                        prevSceneFadeOut();
                    }
                }
    
                scene._assets = prevAssets;
                if (bindToScreenSize) {
                    scene.bindToScreenSize();
                }
                scene._boot();
            }
        }

    }

    /**
     * Retrieve a secondary scene from the given slot name
     * @param name The slot name of the scene to retrieve
     * @return A `Scene` instance or `null` if nothing was found
     */
    public function get(name:String):Scene {

        return rootScenes.get(name);

    }

    @:deprecated('Deprecated: use `app.scenes.main = yourScene;` instead')
    inline public function setCurrentScene(scene:Scene, keepAssets:Bool = false):Void {

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

            if (!scene.active)
                continue;

            // Auto-boot scene it's been added to screen
            if (scene.status == NONE && scene.parent != null) {
                scene._boot();
            }

            // Auto-update scene if applicable
            if (!scene.paused && scene.autoUpdate) {
                switch scene.status {
                    case NONE | PRELOAD | LOAD | CREATE | DISABLED:
                    case FADE_IN | READY | FADE_OUT:
                        scene.update(delta);
                }
            }
        }

        // Cleanup array
        for (i in 0...len) {
            _updatingScenes.unsafeSet(i, null);
        }

    }

}
