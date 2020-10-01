package ceramic;

import ceramic.App;
import ceramic.Screen;
import ceramic.Settings;
import haxe.PosInfos;

/** Shortcuts adds convenience identifiers to access ceramic app, screen, ...
    Use it by adding `import ceramic.Shortcuts.*;` in your files. */
class Shortcuts {

    /** Shared app instance */
    public static var app(get,never):App;
    #if !haxe_server inline #end static function get_app():App { return App.app; }

    /** Shared screen instance */
    public static var screen(get,never):Screen;
    #if !haxe_server inline #end static function get_screen():Screen { return App.app.screen; }

    /** Shared audio instance */
    public static var audio(get,never):Audio;
    #if !haxe_server inline #end static function get_audio():Audio { return App.app.audio; }

    /** Shared settings instance */
    public static var settings(get,never):Settings;
    #if !haxe_server inline #end static function get_settings():Settings { return App.app.settings; }

    /** Shared logger instance */
    public static var log(get,never):Logger;
    #if !haxe_server inline #end static function get_log():Logger { return App.app.logger; }

}
