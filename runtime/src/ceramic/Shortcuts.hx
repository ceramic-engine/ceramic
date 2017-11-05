package ceramic;

import ceramic.App;
import ceramic.Screen;
import ceramic.Settings;
import haxe.PosInfos;

#if editor
import editor.Editor;
#end

/** Shortcuts adds convenience identifiers to access ceramic app, screen, ...
    Use it by adding `import ceramic.Shortcuts.*;` in your files. */
class Shortcuts {

    /** Shared app instance */
    public static var app(get,never):App;
    inline static function get_app():App { return App.app; }

    /** Shared screen instance */
    public static var screen(get,never):Screen;
    inline static function get_screen():Screen { return App.app.screen; }

    /** Shared settings instance */
    public static var settings(get,never):Settings;
    inline static function get_settings():Settings { return App.app.settings; }

    /** Shared project instance */
    public static var project(get,never):Project;
    inline static function get_project():Project { return App.app.project; }

    /** Shared collections instance */
    public static var collections(get,never):Collections;
    inline static function get_collections():Collections { return App.app.collections; }

#if editor

    /** Shared editor instance */
    public static var editor(get,never):Editor;
    inline static function get_editor():Editor { return Editor.editor; }

#end

    /** Log message */
    inline public static function log(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.log(value, pos);
    }

    /** Log success */
    inline public static function success(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.success(value, pos);
    }

    /** Log warning */
    inline public static function warning(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.warning(value, pos);
    }

    /** Log error */
    inline public static function error(value:Dynamic, ?pos:PosInfos) {
        App.app.logger.error(value, pos);
    }

} //Shortcuts
