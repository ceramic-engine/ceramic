package ceramic;

import ceramic.App;
import ceramic.Screen;
import ceramic.Settings;
import ceramic.System;
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

    /** Shared input instance */
    public static var input(get,never):Input;
    #if !haxe_server inline #end static function get_input():Input { return App.app.input; }

    /** Shared settings instance */
    public static var settings(get,never):Settings;
    #if !haxe_server inline #end static function get_settings():Settings { return App.app.settings; }

    /** Shared logger instance */
    public static var log(get,never):Logger;
    #if !haxe_server inline #end static function get_log():Logger { return App.app.logger; }

    /** Systems manager */
    public static var systems(get,never):Systems;
    #if !haxe_server inline #end static function get_systems():Systems { return App.app.systems; }

}
