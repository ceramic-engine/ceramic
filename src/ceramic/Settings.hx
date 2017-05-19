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

    @observable public var antialiasing:Bool = true;

    @observable public var resizable:Bool = false;

    @observable public var background:Int = Color.BLACK;

    @observable public var scaling:ScreenScaling = FIT;

    @observable public var title:String = 'App';

}