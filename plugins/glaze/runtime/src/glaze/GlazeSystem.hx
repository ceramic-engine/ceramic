// New code for the Haxe port of GPUI (no GPUI origin): runs the frames of the
// GPUI windows from Ceramic's update loop. See NOTICE.md.
package glaze;

/**
 * Ceramic system drawing the dirty GPUI windows in `lateUpdate`, after input
 * and the app update (plan, principle 7).
 *
 * Tracker reactions are scheduled with `app.onceImmediate`: they are flushed
 * first, so a model changed during `update` (a timer, a tween...) is drawn
 * in the same frame. A reaction triggered while drawing only marks its view
 * dirty for the next frame.
 */
class GlazeSystem extends ceramic.System {

    static var instance:Null<GlazeSystem> = null;

    /**
     * Creates the system if needed.
     */
    public static function ensure():GlazeSystem {
        if (instance == null || instance.destroyed) {
            instance = new GlazeSystem();
        }
        return instance;
    }

    function new() {
        super();
        name = 'glaze';
        lateUpdateOrder = 10000;
    }

    override function lateUpdate(delta:Float):Void {
        ceramic.App.app.flushImmediate();
        final windows = Window.windows;
        var i = 0;
        while (i < windows.length) {
            final window = windows[i];
            if (window.autoDraw) {
                // Like a platform frame request: next frame callbacks first, then draw if dirty
                window.runNextFrameCallbacks();
                window.drawIfDirty();
            }
            i++;
        }
    }

}
