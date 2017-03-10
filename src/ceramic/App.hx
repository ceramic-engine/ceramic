package ceramic;

import ceramic.Backend;

import ceramic.components.Hello;

enum ScreenScaling {
    CENTER;
    FIT;
    FILL;
}

typedef AppSettings = {

    @:optional var width:Int;

    @:optional var height:Int;

    @:optional var antialiasing:Bool;

    @:optional var background:Int;

    @:optional var scaling:ScreenScaling;

    @:optional var title:String;

}

class App extends Entity {

/// Shared instances

    public static var app(get,null):App;
    static inline function get_app():App { return app; }

/// Properties

    public var screen(default,null):Screen;

    public var settings(default,null):AppSettings;

/// Lifecycle

    public static function init(settings:AppSettings, callback:App->Void):Void {

        app = new App(settings, new Screen());
        app.postInit(callback);

    } //init

    function new(settings:AppSettings, screen:Screen) {

        if (settings == null) {
            settings = {};
        }

        if (settings.antialiasing == null) {
            settings.antialiasing = true;
        }

        if (settings.title == null) {
            settings.title = 'App';
        }

        this.settings = settings;
        this.screen = screen;

    } //new

    function postInit(callback:App->Void):Void {

        screen.postInit();

        callback(app);

    } //postInit

}
