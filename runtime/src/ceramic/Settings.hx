package ceramic;

import tracker.Observable;

class Settings implements Observable {

    @:allow(ceramic.App)
    private function new() {}

    /** Target width. Affects window size at startup (unless `windowWidth` is specified)
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    @observe public var targetWidth:Int = 0;

    /** Target height. Affects window size at startup (unless `windowHeight` is specified)
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    @observe public var targetHeight:Int = 0;

    /** Target window width at startup
        Use `targetWidth` as fallback if set to 0 (default) */
    @observe public var windowWidth(default,null):Int = 0;

    /** Target window height at startup
        Use `targetHeight` as fallback if set to 0 (default) */
    @observe public var windowHeight(default,null):Int = 0;

    /** Target density. Affects the quality of textures
        being loaded. Changing it at runtime will update
        texture quality if needed.
        Ignored if set to 0 (default) */
    @observe public var targetDensity:Int = 0;

    /** Background color. */
    @observe public var background:Color = Color.BLACK;

    /** Screen scaling (FIT, FILL, RESIZE or FIT_RESIZE). */
    @observe public var scaling:ScreenScaling = FIT;

    /** App window title. */
    @observe public var title:String = 'App';

    /** Fullscreen enabled or not. */
    @observe public var fullscreen:Bool = false;

    /**
     * Setup screen orientation. Default is `NONE`,
     * meaning nothing is enforced and project defaults will be used.
     */
    public var orientation(default,null):ScreenOrientation = NONE;

    /** App collections. */
    public var collections(default,null):Void->AutoCollections = null;

    /** App info (useful when dynamically loaded, not needed otherwise). */
    public var appInfo(default,null):Dynamic = null;

    /** Antialiasing value (0 means disabled). */
    public var antialiasing(default,null):Int = 0;

    /** Whether the window can be resized or not. */
    public var resizable(default,null):Bool = false;

    /** Assets path. */
    public var assetsPath(default,null):String = 'assets';

    /** Settings passed to backend. */
    public var backend(default,null):Dynamic = {};

    /** Default font */
    public var defaultFont(default,null):AssetId<String> = 'font:RobotoMedium';

    /** Default shader */
    public var defaultShader(default,null):AssetId<String> = 'shader:textured';

}
