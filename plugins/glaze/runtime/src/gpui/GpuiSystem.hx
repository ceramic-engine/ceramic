// New code for the Haxe port of GPUI (no GPUI origin): runs the frames of the
// GPUI windows from Ceramic's update loop. See CERAMIC_GPUI_PLAN_1.md and NOTICE.md.
package gpui;

/**
 * Ceramic system drawing the dirty GPUI windows in `lateUpdate`, after input
 * and the app update (plan, principle 7).
 *
 * Tracker reactions are scheduled with `app.onceImmediate`: they are flushed
 * first, so a model changed during `update` (a timer, a tween...) is drawn
 * in the same frame. A reaction triggered while drawing only marks its view
 * dirty for the next frame.
 */
class GpuiSystem extends ceramic.System {

    static var instance:Null<GpuiSystem> = null;

    /**
     * Creates the system if needed.
     */
    public static function ensure():GpuiSystem {
        if (instance == null || instance.destroyed) {
            instance = new GpuiSystem();
        }
        return instance;
    }

    function new() {
        super();
        name = 'gpui';
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
