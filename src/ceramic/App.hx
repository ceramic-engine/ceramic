package ceramic;

import ceramic.Backend;

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

@:allow(ceramic.Visual)
class App extends Entity {

/// Shared instances

    public static var app(get,null):App;
    static inline function get_app():App { return app; }

/// Properties

    public var backend(default,null):Backend;

    public var screen(default,null):Screen;

    public var settings(default,null):AppSettings;

    public var visuals(default,null):Array<Visual> = [];

/// Internal

    var hierarchyDirty:Bool = false;

/// Lifecycle

    public static function init(settings:AppSettings, callback:App->Void):Void {

        app = new App(settings, new Screen());
        app.postInit(callback);

    } //init

    function new(settings:AppSettings, screen:Screen) {

        backend = new Backend();

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

        backend.onUpdate(update);

    } //postInit

    function update(delta:Float):Void {

        screen.emitUpdate(delta);

        if (hierarchyDirty) {

            // Compute visuals depth
            for (visual in visuals) {

                if (visual.parent == null) {
                    visual.computedDepth = visual.depth;

                    if (visual.children != null) {
                        visual.computeChildrenDepth();
                    }
                }
            }

            // Sort visuals by (computed) depth
            haxe.ds.ArraySort.sort(visuals, function(a:Visual, b:Visual):Int {

                if (a.computedDepth < b.computedDepth) return -1;
                if (a.computedDepth > b.computedDepth) return 1;
                return 0;

            });

            hierarchyDirty = false;
        }

        // Dispatch visual transforms changes
        for (visual in visuals) {

            if (visual.transform != null && visual.transform.changed) {
                visual.transform.emitChange();
            }

        }

        // Update visuals matrix and visibility
        for (visual in visuals) {

            if (visual.matrixDirty) {
                visual.computeMatrix();
            }

            if (visual.visibilityDirty) {
                visual.computeVisibility();
            }

        }

        // Draw
        backend.draw.draw(visuals);

    } //update

}
