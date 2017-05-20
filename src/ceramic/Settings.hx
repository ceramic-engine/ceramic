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

    /** Background color. */
    @observable public var background:Int = Color.BLACK;

    /** Screen scaling (FIT or FILL). */
    @observable public var scaling:ScreenScaling = FIT;

    /** App window title.
        Can only be set at `app startup` from `Project constructor`. */
    public var title(default,null):String = 'App';

    /** Whether antialiasing is enabled or not. */
    public var antialiasing(default,null):Bool = true;

    /** Whether the window can be resized or not. */
    public var resizable(default,null):Bool = false;

}

/** Same as Settings, but for app startup (inside Project.new(settings)).
    Values that are normally read only can still
    be edited at that stage. */
class InitSettings {

    /** App settings */
    private var settings:Settings;

    @:allow(ceramic.App)
    private function new(settings:Settings) {

        this.settings = settings;

    } //new

    /** Target width. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    public var targetWidth(get,set):Int;
    inline function get_targetWidth():Int {
        return settings.targetWidth;
    }
    inline function set_targetWidth(targetWidth:Int):Int {
        return settings.targetWidth = targetWidth;
    }

    /** Target height. Affects window size at startup
        and affects screen scaling at any time.
        Ignored if set to 0 (default) */
    public var targetHeight(get,set):Int;
    inline function get_targetHeight():Int {
        return settings.targetHeight;
    }
    inline function set_targetHeight(targetHeight:Int):Int {
        return settings.targetHeight = targetHeight;
    }

    /** Target density. Affects the quality of textures
        being loaded. Changing it at runtime will update
        texture quality if needed.
        Ignored if set to 0 (default) */
    public var targetDensity(get,set):Int;
    inline function get_targetDensity():Int {
        return settings.targetDensity;
    }
    inline function set_targetDensity(targetDensity:Int):Int {
        return settings.targetDensity = targetDensity;
    }

    /** Background color. */
    public var background(get,set):Int;
    inline function get_background():Int {
        return settings.background;
    }
    inline function set_background(background:Int):Int {
        return settings.background = background;
    }

    /** Screen scaling (FIT or FILL). */
    public var scaling(get,set):ScreenScaling;
    inline function get_scaling():ScreenScaling {
        return settings.scaling;
    }
    inline function set_scaling(scaling:ScreenScaling):ScreenScaling {
        return settings.scaling = scaling;
    }

    /** App window title.
        Can only be set at `app startup` from `Project constructor`. */
    public var title(get,set):String;
    inline function get_title():String {
        return settings.title;
    }
    inline function set_title(title:String):String {
        return @:privateAccess settings.title = title;
    }

    /** Whether antialiasing is enabled or not. */
    public var antialiasing(get,set):Bool;
    inline function get_antialiasing():Bool {
        return settings.antialiasing;
    }
    inline function set_antialiasing(antialiasing:Bool):Bool {
        return @:privateAccess settings.antialiasing = antialiasing;
    }

    /** Whether the window can be resized or not. */
    public var resizable(get,set):Bool;
    inline function get_resizable():Bool {
        return settings.resizable;
    }
    inline function set_resizable(resizable:Bool):Bool {
        return @:privateAccess settings.resizable = resizable;
    }

}