// New code for the Haxe port of GPUI (no GPUI origin): per-phase timing
// accumulator used by test/bench. Compiled to no-ops without the
// `gpui_profile_frames` define.
package gpui.util;

/**
 * Static accumulator of the time spent in each phase of a frame.
 *
 * Without `-D gpui_profile_frames` every method is an inline no-op (or
 * returns 0), so the calls can stay in the hot paths of `gpui.Window` and
 * `gpui.platform.SceneRenderable` at no cost. With the define, `begin(phase)`
 * stores `haxe.Timer.stamp()` in a preallocated array and `end(phase)` adds
 * the elapsed seconds to the phase total and increments its count. Nothing is
 * allocated per call.
 *
 * Phases and where they begin and end (the calls are to be inserted at these
 * exact points):
 *
 * - `UPDATE`: not measured by gpui itself. The bench measures it around
 *   `ceramic.App.app.flushImmediate()` (the observable change propagation that
 *   marks views dirty), before `window.drawIfDirty()`.
 * - `LAYOUT`: in `Window.drawRoots`, from just before
 *   `rootElement.requestLayout(this, app)` to just after
 *   `layoutEngine.stretchAutoSizeToFill(...)` (both branches of the
 *   `gpui_inspector` conditional). This includes rendering the dirty views,
 *   since `requestLayout` renders them.
 * - `PREPAINT`: in `Window.drawRoots`, from just before
 *   `rootElement.prepaintAsRoot(...)` to just after
 *   `mouseHitTest = nextFrame.hitTest(_mousePosition)`. It covers the
 *   inspector prepaint, `prepaintDeferredDraws()`, the active drag or tooltip
 *   prepaint and the hit test.
 * - `PAINT`: in `Window.drawRoots`, from just before
 *   `rootElement.paint(this, app)` to the end of `drawRoots` (inspector
 *   paint, deferred draws, drag or tooltip paint, inspector hitbox).
 * - `FINISH`: in `Window.drawFrame`, from just before
 *   `layoutEngine.finishFrame()` to the end of `drawFrame` (text system
 *   finish, `nextFrame.finish(renderedFrame)`, the frame swap, the scene
 *   handed to the renderable, focus and activation listeners).
 * - `RENDER`: the whole body of `SceneRenderable.render(draw)` (the scene
 *   turned into Ceramic draw calls).
 *
 * Usage in the bench: `FrameProfiler.reset()` before the measured block, then
 * `FrameProfiler.ms(FrameProfiler.LAYOUT)` and `count(...)` after it.
 */
class FrameProfiler {

    public static inline final UPDATE:Int = 0;
    public static inline final LAYOUT:Int = 1;
    public static inline final PREPAINT:Int = 2;
    public static inline final PAINT:Int = 3;
    public static inline final FINISH:Int = 4;
    public static inline final RENDER:Int = 5;

    /**
     * Number of phases (the valid phase ids are `0...PHASE_COUNT`).
     */
    public static inline final PHASE_COUNT:Int = 6;

    /**
     * Names of the phases, indexed by phase id.
     */
    public static final NAMES:Array<String> = ['update', 'layout', 'prepaint', 'paint', 'finish', 'render'];

    /**
     * True when the profiler is compiled in (`gpui_profile_frames`).
     */
    public static inline final ENABLED:Bool = #if gpui_profile_frames true #else false #end;

    #if gpui_profile_frames

    // Public so that the inline `begin` / `end` compile wherever they are
    // called; zeroed explicitly because a JS Vector starts undefined.
    @:noCompletion public static final starts:haxe.ds.Vector<Float> = zeroFloats();

    @:noCompletion public static final totals:haxe.ds.Vector<Float> = zeroFloats();

    @:noCompletion public static final counts:haxe.ds.Vector<Int> = zeroInts();

    static function zeroFloats():haxe.ds.Vector<Float> {
        final v = new haxe.ds.Vector<Float>(PHASE_COUNT);
        for (i in 0...PHASE_COUNT) v[i] = 0.0;
        return v;
    }

    static function zeroInts():haxe.ds.Vector<Int> {
        final v = new haxe.ds.Vector<Int>(PHASE_COUNT);
        for (i in 0...PHASE_COUNT) v[i] = 0;
        return v;
    }

    /**
     * Marks the start of a phase.
     */
    public static inline function begin(phase:Int):Void {
        starts[phase] = haxe.Timer.stamp();
    }

    /**
     * Marks the end of a phase begun with `begin(phase)` and accumulates the
     * elapsed time.
     */
    public static inline function end(phase:Int):Void {
        totals[phase] += haxe.Timer.stamp() - starts[phase];
        counts[phase]++;
    }

    /**
     * Resets every total and count.
     */
    public static function reset():Void {
        for (i in 0...PHASE_COUNT) {
            starts[i] = 0.0;
            totals[i] = 0.0;
            counts[i] = 0;
        }
    }

    /**
     * Total time spent in a phase since the last `reset()`, in milliseconds.
     */
    public static inline function ms(phase:Int):Float {
        return totals[phase] * 1000.0;
    }

    /**
     * Number of `end(phase)` calls since the last `reset()`.
     */
    public static inline function count(phase:Int):Int {
        return counts[phase];
    }

    #else

    public static inline function begin(phase:Int):Void {}

    public static inline function end(phase:Int):Void {}

    public static inline function reset():Void {}

    public static inline function ms(phase:Int):Float {
        return 0.0;
    }

    public static inline function count(phase:Int):Int {
        return 0;
    }

    #end

}
