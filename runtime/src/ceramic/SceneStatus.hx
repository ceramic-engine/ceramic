package ceramic;

/**
 * Represents the lifecycle status of a Scene in the Ceramic framework.
 * 
 * SceneStatus tracks a scene through its complete lifecycle, from initialization
 * through loading, creation, display, and eventual removal. Each status represents
 * a specific phase that scenes go through, allowing the framework and developers
 * to coordinate actions based on the scene's current state.
 * 
 * Lifecycle flow:
 * 1. **NONE** → Initial state when scene is created
 * 2. **PRELOAD** → Scene is preparing assets to load
 * 3. **LOAD** → Assets are actively being loaded
 * 4. **CREATE** → Scene content is being created
 * 5. **FADE_IN** → Scene is transitioning to visible
 * 6. **READY** → Scene is fully active and interactive
 * 7. **FADE_OUT** → Scene is transitioning out
 * 8. **DISABLED** → Scene is inactive and should be destroyed
 * 
 * The status progression is typically automatic, managed by the Scene class
 * and the framework's scene management system. Developers can override scene
 * methods (preload, create, fadeIn, fadeOut) to customize behavior at each phase.
 * 
 * Example usage:
 * ```haxe
 * if (scene.status == SceneStatus.READY) {
 *     // Scene is fully loaded and interactive
 *     scene.handleUserInput();
 * }
 * ```
 * 
 * @see Scene
 * @see SceneSystem
 * @see App#scene
 */
enum abstract SceneStatus(Int) from Int to Int {

    /**
     * No status. The scene is likely not assigned to anything.
     */
    var NONE:Int = 0;

    /**
     * The scene is calling the `preload()` method.
     * That happens when the scene is added as root scene or is added as a child of another visual.
     */
    var PRELOAD:Int = 1;

    /**
     * The scene is actually loading. Any asset that was
     * added with `assets.add()` in the `preload()` method is
     * getting loaded.
     */
    var LOAD:Int = 2;

    /**
     * The scene has finished loading and is calling the `create()` method
     * to fill it with any object, visual needed etc...
     */
    var CREATE:Int = 3;

    /**
     * The `create()` method has finished running so the scene is now ready to **fade in**.
     * Default fade in implementation is _instant_, but this can be changed by overriding
     * the `fadeIn()` method.
     */
    var FADE_IN:Int = 4;

    /**
     * When **fade in** has finished, the scene is marked as **ready**.
     */
    var READY:Int = 5;

    /**
     * The scene begins to **fade out**, likely because it was explicitly asked to do so,
     * or is being replaced by another scene.
     */
    var FADE_OUT:Int = 6;

    /**
     * Happens after **fade out**. When the scene has this status, it should not be used anymore.
     */
    var DISABLED:Int = 7;

    /**
     * Converts the status to a human-readable string representation.
     * 
     * Useful for debugging and logging scene state transitions.
     * 
     * @return String representation of the current status (e.g., "READY", "FADE_IN")
     */
    function toString() {

        return switch this {
            case NONE: 'NONE';
            case PRELOAD: 'PRELOAD';
            case LOAD: 'LOAD';
            case CREATE: 'CREATE';
            case FADE_IN: 'FADE_IN';
            case READY: 'READY';
            case FADE_OUT: 'FADE_OUT';
            case DISABLED: 'DISABLED';
            case _: '_';
        }

    }

}