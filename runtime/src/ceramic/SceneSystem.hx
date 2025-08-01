package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * Core system responsible for managing scene lifecycle, transitions, and display hierarchy.
 * 
 * SceneSystem provides centralized management of scenes in a Ceramic application,
 * handling their loading, transitions, and display. It supports multiple simultaneous
 * scenes through named slots, with special handling for the main scene.
 * 
 * Key features:
 * - **Main scene management**: Primary scene with automatic screen binding
 * - **Named scene slots**: Support for multiple concurrent scenes (overlays, HUD, etc.)
 * - **Automatic lifecycle**: Handles preload → load → create → fade transitions
 * - **Asset preservation**: Option to keep assets when switching scenes
 * - **Filter support**: Post-processing effects for all root scenes
 * - **Transition control**: Configurable fade in/out behaviors
 * 
 * The system automatically updates active scenes and manages their transitions,
 * ensuring smooth scene changes and proper resource management.
 * 
 * Example usage:
 * ```haxe
 * // Set main scene
 * app.scenes.main = new GameScene();
 * 
 * // Add overlay scene
 * app.scenes.set('hud', new HudScene());
 * 
 * // Configure transitions
 * app.scenes.keepAssetsForNextMain = true;
 * app.scenes.fadeOutWhenNextMainCanFadeIn = true;
 * ```
 * 
 * @see Scene
 * @see App#scenes
 * @see SceneStatus
 */
@:allow(ceramic.Scene)
class SceneSystem extends System {

    /**
     * Singleton instance of the scene system.
     * Automatically created on first access.
     */
    @lazy public static var shared = new SceneSystem();

    /**
     * Read-only array containing all active scenes in the system.
     * Includes both root scenes and child scenes.
     */
    public var all(default, null):ReadOnlyArray<Scene> = [];

    /**
     * Internal array used during update cycles to safely iterate scenes.
     * Prevents issues when scenes are added/removed during iteration.
     */
    var _updatingScenes:Array<Scene> = [];

    /**
     * Controls asset preservation when switching main scenes.
     * 
     * When `true`, assets from the previous main scene are transferred to the new
     * main scene instead of being destroyed. This allows seamless transitions
     * without reloading shared assets like textures, sounds, or fonts.
     * 
     * Useful for:
     * - Level transitions that share common assets
     * - Menu → gameplay transitions
     * - Reducing loading times between related scenes
     * 
     * Default: `false`
     */
    public var keepAssetsForNextMain:Bool = false;

    /**
     * Controls automatic screen size binding for the main scene.
     * 
     * When `true`, the main scene's size will automatically match the screen
     * dimensions and update when the screen is resized. This ensures the main
     * scene always fills the entire display area.
     * 
     * Set to `false` if you need custom scene sizing or positioning.
     * 
     * Default: `true`
     */
    public var bindMainToScreenSize:Bool = true;

    /**
     * Controls the timing of scene transitions.
     * 
     * When `true`, the previous scene's fade-out animation is delayed until
     * the new scene is fully loaded and ready to fade in. This creates smoother
     * transitions by ensuring the new content is ready before removing the old.
     * 
     * When `false`, the previous scene fades out immediately, potentially
     * showing a loading state or blank screen.
     * 
     * Default: `true`
     */
    public var fadeOutWhenNextMainCanFadeIn:Bool = true;

    /**
     * The primary scene of the application.
     * 
     * Setting this property automatically handles scene transitions, including:
     * - Fading out the previous main scene
     * - Loading and initializing the new scene
     * - Managing asset preservation (if enabled)
     * - Binding to screen size (if enabled)
     * 
     * The main scene typically represents the core content of your application
     * (game level, menu screen, etc.).
     */
    public var main(default,set):Scene = null;

    /**
     * Controls automatic cleanup of replaced filters.
     * 
     * When `true`, filters are automatically destroyed when:
     * - Replaced by a new filter
     * - Set to null
     * - The scene system is destroyed
     * 
     * Set to `false` if you want to manage filter lifecycle manually or
     * reuse filters across different contexts.
     * 
     * Default: `true`
     */
    public var autoDestroyFilter:Bool = true;

    /**
     * Controls automatic scaling of scene filters.
     * 
     * When `true`, filters are automatically scaled to match screen dimensions,
     * ensuring post-processing effects cover the entire display area. The filter
     * and its content are scaled inversely to maintain proper rendering.
     * 
     * Set to `false` for custom filter sizing or when using filters that
     * shouldn't match screen size.
     * 
     * Default: `true`
     */
    public var autoScaleFilter:Bool = true;

    /**
     * Post-processing filter applied to all root scenes.
     * 
     * When set, all root scenes are rendered through this filter, enabling
     * global visual effects like:
     * - Color grading
     * - Blur or pixelation
     * - Shader-based effects
     * 
     * The filter automatically includes all root scenes and handles their
     * proper rendering order.
     */
    public var filter(default, set):Filter = null;
    /**
     * Internal setter for the filter property.
     * 
     * Handles the complex logic of transitioning between filters, including:
     * - Removing scenes from the previous filter
     * - Cleaning up or destroying the old filter
     * - Adding all root scenes to the new filter
     * - Setting up proper scaling
     */
    function set_filter(filter:Filter):Filter {
        if (this.filter != filter) {
            var prevFilter = this.filter;
            if (prevFilter != null) {
                for (scene in rootScenes) {
                    if (scene.parent == prevFilter.content) {
                        prevFilter.content.remove(scene);
                        scene.scaleX = 1;
                        scene.scaleY = 1;
                    }
                }
                // Remove any child that is a scene from this previous filter content
                if (prevFilter.content.children != null) {
                    var toRemove = null;
                    for (i in 0...prevFilter.content.children.length) {
                        var child = prevFilter.content.children.unsafeGet(i);
                        if (child is Scene) {
                            var childScene:Scene = cast child;
                            if (childScene.isRootScene) {
                                if (toRemove == null)
                                    toRemove = [];
                                toRemove.push(childScene);
                            }
                        }
                    }
                    if (toRemove != null) {
                        for (i in 0...toRemove.length) {
                            var childScene = toRemove.unsafeGet(i);
                            prevFilter.content.remove(childScene);
                            childScene.active = false;
                        }
                    }
                }
                if (autoDestroyFilter)
                    prevFilter.destroy();
                else
                    prevFilter.scale(1.0);
            }
            this.filter = filter;
            if (filter != null) {
                if (autoScaleFilter) {
                    scaleFilter();
                }
                for (scene in rootScenes) {
                    if (scene.parent != filter.content) {
                        filter.content.add(scene);
                    }
                }
            }

        }
        return filter;
    }

    /**
     * Updates filter scaling to match current screen dimensions.
     * 
     * Scales the filter to cover the screen while inversely scaling its content
     * to maintain proper aspect ratio and sizing of contained scenes.
     */
    function scaleFilter() {

        filter.scale(screen.width / filter.width, screen.height / filter.height);
        filter.content.scale(filter.width / screen.width, filter.height / screen.height);

    }

    /**
     * Map of all root scenes indexed by their slot names.
     * 
     * Root scenes are directly managed by the scene system and rendered
     * to screen. The 'main' slot contains the primary scene, while other
     * slots can hold overlays, HUD elements, or secondary scenes.
     */
    public var rootScenes(default,null):ReadOnlyMap<String,Scene> = new Map();

    /**
     * Internal setter for the main scene property.
     * 
     * Delegates to the general `set()` method with the 'main' slot name,
     * using the configured settings for screen binding and asset preservation.
     */
    function set_main(main:Scene):Scene {

        if (this.main != main) {
            this.main = main;
            set('main', main, bindMainToScreenSize, keepAssetsForNextMain);
        }

        return main;

    }

    /**
     * Assigns a scene to a named slot in the scene system.
     * 
     * This method handles the complete lifecycle of scene assignment, including:
     * - Removing and cleaning up previous scenes in the slot
     * - Initializing and displaying the new scene
     * - Managing scene transitions and asset preservation
     * - Setting up proper parent-child relationships
     * 
     * Special handling for 'main' slot updates the main property.
     * 
     * Example:
     * ```haxe
     * // Add a HUD overlay
     * app.scenes.set('hud', new HudScene());
     * 
     * // Add a pause menu with asset sharing
     * app.scenes.set('pause', new PauseMenu(), true, true);
     * ```
     * 
     * @param name The slot name for the scene (e.g., 'main', 'hud', 'overlay')
     * @param scene The scene to assign, or null to remove the current scene
     * @param bindToScreenSize Whether the scene should automatically match screen size (default: true)
     * @param keepAssets Whether to preserve assets from the previous scene in this slot (default: false)
     */
    public function set(name:String, scene:Scene, bindToScreenSize:Bool = true, keepAssets:Bool = false):Void {

        var prevScene = rootScenes.get(name);

        // Detect if moving from another name
        var movingFromName = null;
        if (scene != null && scene.isRootScene) {
            for (name => rootScene in rootScenes) {
                if (rootScene == scene) {
                    movingFromName = name;
                    break;
                }
            }
        }

        if (movingFromName != null) {
            if (movingFromName == name) {
                return;
            }
            else {
                rootScenes.original.remove(movingFromName);
            }
        }

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
                if (movingFromName == null) {
                    scene.isRootScene = true;

                    rootScenes.original.set(name, scene);
                    if (name == 'main') {
                        this.main = scene;
                    }

                    scene.onDestroy(this, destroyedScene -> {

                        var rootName = null;
                        if (scene != null && scene.isRootScene) {
                            for (name => rootScene in rootScenes) {
                                if (rootScene == destroyedScene) {
                                    rootName = name;
                                    break;
                                }
                            }
                        }

                        if (rootName != null) {
                            rootScenes.original.remove(name);
                            if (rootName == 'main' && this.main == destroyedScene) {
                                this.main = null;
                            }
                        }

                    });

                    scene.onReplace(this, newScene -> {

                        var rootName = null;
                        if (scene != null && scene.isRootScene) {
                            for (name => rootScene in rootScenes) {
                                if (rootScene == scene) {
                                    rootName = name;
                                    break;
                                }
                            }
                        }

                        if (rootName != null) {
                            set(rootName, newScene);
                        }

                    });
                }
                else {
                    if (movingFromName == 'main') {
                        this.main = null;
                    }

                    rootScenes.original.set(name, scene);
                    if (name == 'main') {
                        this.main = scene;
                    }
                }

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

                if (movingFromName == null) {
                    scene._assets = prevAssets;
                    if (bindToScreenSize) {
                        scene.bindToScreenSize();
                    }
                    if (filter != null) {
                        filter.content.add(scene);
                    }
                    scene._boot();
                }
            }
        }

    }

    /**
     * Retrieves a scene from the specified slot.
     * 
     * Useful for accessing secondary scenes like HUD, overlays, or other
     * named scenes managed by the system.
     * 
     * Example:
     * ```haxe
     * var hudScene = app.scenes.get('hud');
     * if (hudScene != null) {
     *     hudScene.updateScore(100);
     * }
     * ```
     * 
     * @param name The slot name of the scene to retrieve
     * @return The scene in the specified slot, or null if empty
     */
    public function get(name:String):Scene {

        return rootScenes.get(name);

    }

    @:deprecated('Deprecated: use `app.scenes.main = yourScene;` instead')
    inline public function setCurrentScene(scene:Scene, keepAssets:Bool = false):Void {

        keepAssetsForNextMain = keepAssets;
        main = scene;

    }

    /**
     * Creates a new SceneSystem instance.
     * 
     * Typically not called directly - use the shared singleton instance
     * via `SceneSystem.shared` or through `app.scenes`.
     */
    override function new() {

        super();

        lateUpdateOrder = 5000;

    }

    /**
     * Updates all active scenes and handles auto-booting.
     * 
     * Called automatically each frame after regular updates. This method:
     * - Auto-boots scenes that have been added to the display hierarchy
     * - Updates active, non-paused scenes that have autoUpdate enabled
     * - Maintains filter scaling if autoScaleFilter is enabled
     * 
     * @param delta Time elapsed since last frame in seconds
     */
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

            if (!scene.active && !scene.autoUpdateWhenInactive)
                continue;

            if (scene.destroyed)
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

        // Update filter (if any)
        if (autoScaleFilter && filter != null) {
            scaleFilter();
        }

    }

}
