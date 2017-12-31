package ceramic;

class Settings implements Observable {

    @:allow(ceramic.App)
    private function new() {}

    /** Target width. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    @observable public var targetWidth:Int = 0;

    /** Target height. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    @observable public var targetHeight:Int = 0;

    /** Target density. Affects the quality of textures
        being loaded. Changing it at runtime will update
        texture quality if needed.
        Ignored if set to 0 (default) */
    @observable public var targetDensity:Int = 0;

    /** Background color. */
    @observable public var background:Color = Color.BLACK;

    /** Screen scaling (FIT or FILL). */
    @observable public var scaling:ScreenScaling = FIT;

    /** App window title.
        Can only be set at `app startup` from `Project constructor`. */
    public var title(default,null):String = 'App';

    /** Whether antialiasing is enabled or not. */
    public var antialiasing(default,null):Bool = true;

    /** Whether the window can be resized or not. */
    public var resizable(default,null):Bool = false;

    /** Assets path. */
    public var assetsPath(default,null):String = 'assets';

    /** Settings passed to backend. */
    public var backend(default,null):Dynamic = {};

}
