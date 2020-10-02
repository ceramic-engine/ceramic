package ceramic;

import tracker.Observable;

class Settings implements Observable {

    @:allow(ceramic.App)
    private function new() {}

    /** Target width. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    @observe public var targetWidth:Int = 0;

    /** Target height. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    @observe public var targetHeight:Int = 0;

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
    public var defaultFont(default,null):AssetId<String> = Fonts.ROBOTO_MEDIUM;

    /** Default shader */
    public var defaultShader(default,null):AssetId<String> = Shaders.TEXTURED;

}
