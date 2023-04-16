package ceramic;

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