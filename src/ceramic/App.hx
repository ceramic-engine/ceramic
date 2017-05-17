package ceramic;

import backend.Backend;

enum ScreenScaling {
    FIT;
    FILL;
}

class AppSettings {

    @:allow(ceramic.App)
    private function new() {}

    public var width:Int = 0;

    public var height:Int = 0;

    public var antialiasing:Bool = true;

    public var resizable:Bool = false;

    public var background:Int = Color.BLACK;

    public var scaling:ScreenScaling = FIT;

    public var title:String = 'App';

}

class BaseProject extends Entity {

    @:final function new() {}

} //BaseProject

@:allow(ceramic.Visual)
class App extends Entity {

/// Shared instances

    public static var app(get,null):App;
    static inline function get_app():App { return app; }

/// Events

    @event function ready();

    @event function tick();

/// Properties

    public var project(default,null):Project;

    public var backend(default,null):Backend;

    public var screen(default,null):Screen;

    public var settings(default,null):AppSettings;

    public var visuals(default,null):Array<Visual> = [];

/// Internal

    var hierarchyDirty:Bool = false;

/// Lifecycle

    function new() {

        app = this;

        settings = new AppSettings();
        screen = new Screen();

        project = @:privateAccess new Project();

        backend = new Backend();
        backend.onceReady(this, backendReady);
        backend.init(this);

    } //new

    function backendReady():Void {

        screen.backendReady();

        emitReady();

        backend.onUpdate(this, update);

    } //backendReady

    function update(delta:Float):Void {

        app.emitTick();

        screen.emitUpdate(delta);

        for (visual in visuals) {

            // Compute displayed content
            if (visual.contentDirty) {

                // Compute content only if visual is currently visible
                //
                if (visual.visibilityDirty) {
                    visual.computeVisibility();
                }

                if (visual.computedVisible) {
                    visual.computeContent();
                }
            }

        }

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
