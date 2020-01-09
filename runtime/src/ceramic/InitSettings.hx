package ceramic;

/** Same as Settings, but for app startup (inside Project.new(settings)).
    Read-only values can still
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
    public var background(get,set):Color;
    inline function get_background():Color {
        return settings.background;
    }
    inline function set_background(background:Int):Int {
        return settings.background = background;
    }

    /** Screen scaling (FIT, FILL, RESIZE, FIT_RESIZE). */
    public var scaling(get,set):ScreenScaling;
    inline function get_scaling():ScreenScaling {
        return settings.scaling;
    }
    inline function set_scaling(scaling:ScreenScaling):ScreenScaling {
        return settings.scaling = scaling;
    }

    /** App window title. */
    public var title(get,set):String;
    inline function get_title():String {
        return settings.title;
    }
    inline function set_title(title:String):String {
        return @:privateAccess settings.title = title;
    }

    /** Antialiasing value (0 means disabled). */
    public var antialiasing(get,set):Int;
    inline function get_antialiasing():Int {
        return settings.antialiasing;
    }
    inline function set_antialiasing(antialiasing:Int):Int {
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

    /** Assets path. */
    public var assetsPath(get,set):String;
    inline function get_assetsPath():String {
        return settings.assetsPath;
    }
    inline function set_assetsPath(assetsPath:String):String {
        return @:privateAccess settings.assetsPath = assetsPath;
    }

    /** Settings passed to backend. */
    public var backend(get,set):Dynamic;
    inline function get_backend():Dynamic {
        return settings.backend;
    }
    inline function set_backend(backend:Dynamic):Dynamic {
        return @:privateAccess settings.backend = backend;
    }

    /** Default font asset */
    public var defaultFont(get,set):AssetId<String>;
    inline function get_defaultFont():AssetId<String> {
        return settings.defaultFont;
    }
    inline function set_defaultFont(defaultFont:AssetId<String>):AssetId<String> {
        return @:privateAccess settings.defaultFont = defaultFont;
    }

    /** Default shader asset */
    public var defaultShader(get,set):AssetId<String>;
    inline function get_defaultShader():AssetId<String> {
        return settings.defaultShader;
    }
    inline function set_defaultShader(defaultShader:AssetId<String>):AssetId<String> {
        return @:privateAccess settings.defaultShader = defaultShader;
    }

}
