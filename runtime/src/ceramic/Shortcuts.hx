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

    /** Shared settings instance */
    public static var settings(get,never):Settings;
    #if !haxe_server inline #end static function get_settings():Settings { return App.app.settings; }

    /** Shared collections instance */
    public static var collections(get,never):Collections;
    #if !haxe_server inline #end static function get_collections():Collections { return App.app.collections; }

    /** Log message */
    #if !haxe_server inline #end public static function log(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.log(value, pos);
    }

    /** Log success */
    #if !haxe_server inline #end public static function success(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.success(value, pos);
    }

    /** Log warning */
    #if !haxe_server inline #end public static function warning(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.warning(value, pos);
    }

    /** Log error */
    #if !haxe_server inline #end public static function error(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.error(value, pos);
    }

} //Shortcuts
