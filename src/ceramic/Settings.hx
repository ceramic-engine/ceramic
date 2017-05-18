package ceramic;

enum ScreenScaling {
    FIT;
    FILL;
}

class Settings implements Observable {

    @:allow(ceramic.App)
    private function new() {}

    /** Target width. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    public var targetWidth:Int = 0;

    /** Target height. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    public var targetHeight:Int = 0;

    /** Target density. Affects the quality of textures
        being loaded. Changing it at runtime will update
        texture quality if needed.
        Ignored if set to 0 (default) */
    public var targetDensity:Int = 0;

    public var antialiasing:Bool = true;

    public var resizable:Bool = false;

    public var background:Int = Color.BLACK;

    public var scaling:ScreenScaling = FIT;

    public var title:String = 'App';

}