// Ported from gpui-kit 0.8.1: crates/base/src/plot/appear.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.SpringMath;
import glaze.Style;
import glaze.Window;
import glaze.kit.base.motion.Easing;
import glaze.kit.base.motion.Presence;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.base.theme.Theme;

/**
 * How far a plot's data marks have appeared this frame, handed to
 * `Plot.updateAppear`.
 *
 * The appear starts on the first frame a plot's id is painted and runs over
 * the active `PlotMotion`'s appear. Base's default duration is zero, and
 * reduced motion skips it, so a plot is then complete from its first frame.
 *
 * The appear lives in the plot's element state, so a plot that stops being
 * painted (a row a virtual list scrolled away) forgets it and draws in again
 * when it comes back. A `PlotAppearScope` around the list remembers which
 * plots have finished, for as long as the scope itself is painted.
 */
class PlotAppear {

    /** Linear time through the appear, from `0` to `1`. */
    final time:Float;

    final easing:Easing;

    @:allow(glaze.kit.base.plot)
    @:allow(tests)
    function new(time:Float, easing:Easing) {
        this.time = time;
        this.easing = easing;
    }

    /** A finished appear: every mark is complete. */
    public static function complete():PlotAppear {
        return new PlotAppear(1., Easing.Linear);
    }

    /** How far the whole plot has appeared, from `0` to `1`, eased. */
    public function progress():Float {
        // Charts read this per mark on every frame, long after the appear is
        // done, so a finished appear skips sampling the curve.
        if (time >= 1.) {
            return 1.;
        }
        return easing.sample(time);
    }

    /** Whether the appear is still running. */
    public inline function isAppearing():Bool {
        return time < 1.;
    }

    /**
     * How far mark `index` of `count` has appeared, from `0` to `1`, eased.
     *
     * The marks start one after another across the first `spread` of the
     * appear (`0..1`) and each runs for the rest of it, so the last mark
     * still finishes with the appear however many marks there are. A
     * `spread` of `0` moves every mark together.
     */
    public function staggered(index:Int, count:Int, spread:Float):Float {
        if (count <= 1 || time >= 1.) {
            return progress();
        }
        final spread = spread < 0. ? 0. : (spread > 0.95 ? f(0.95) : spread);
        final start = f(f(spread * (index < count - 1 ? index : count - 1)) / (count - 1));
        final t = f(f(time - start) / f(1. - spread));
        return easing.sample(t < 0. ? 0. : (t > 1. ? 1. : t));
    }

    /** The element-state key of a plot's appear, within the plot's scope. */
    static inline final APPEAR:String = '__plot-appear';

    /**
     * The scopes being laid out or painted, innermost last. Only non-empty
     * while a `PlotAppearScope` is drawing its child.
     */
    @:allow(glaze.kit.base.plot)
    static final scopes:Array<PlotAppeared> = [];

    /**
     * Sample the appear of the plot painting under the window's current
     * element id, `globalId`. A new `generation` starts it over, and one the
     * innermost `PlotAppearScope` saw finish is complete at once. Called by
     * `PlotElement` within the plot's element scope on every frame.
     */
    @:allow(glaze.kit.base.plot)
    static function trackAppear(globalId:GlobalElementId, generation:String, window:Window, cx:App):PlotAppear {
        final scope = scopes.length > 0 ? scopes[scopes.length - 1] : null;
        if (scope != null && scope.finished.get(globalId.key) == generation) {
            return complete();
        }
        final theme = cx.tryGlobal(Theme);
        if (theme == null) {
            return complete();
        }
        final policy = theme.plot.motion().appear();
        final easing = policy.curve();
        // Presence keeps the linear time so the marks can each ease over
        // their own slice of it; see `staggered`.
        final sample = new Presence(TransitionId.named(ElementId.Name(generation), APPEAR), true)
            .transition(policy.easing(Easing.Linear))
            .sample(window, cx);
        if (sample.progress >= 1. && scope != null) {
            scope.finished.set(globalId.key, generation);
        }
        return new PlotAppear(sample.progress, easing);
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

/**
 * The plots a `PlotAppearScope` has seen finish appearing, by global id key,
 * with the generation that finished.
 */
@:keep
class PlotAppeared {

    public final finished:Map<String, String> = new Map();

    public function new() {}

}

/**
 * Remembers which plots inside it have finished appearing, so a plot that is
 * painted again after a gap (a row a virtual list scrolled out of view and
 * back) shows its data whole instead of drawing in again.
 *
 * A plot is remembered by its global element id and its
 * `Plot.appearGeneration`, once its appear has finished; a new generation
 * still replays it, and one taken away mid-appear draws in again from the
 * start. The memory is the scope's own element state: it lasts while the
 * scope is painted every frame and goes with it. The innermost scope wins.
 *
 * The scope takes no part in layout: it hands on its child's layout.
 */
class PlotAppearScope extends Element {

    final id:ElementId;

    var child:Null<AnyElement>;

    var appeared:PlotAppeared = new PlotAppeared();

    /**
     * Remember the appears of the plots in `child` under `id`, unique among
     * its siblings.
     */
    public function new(id:ElementIdArg, child:IntoElement) {
        this.id = id;
        this.child = child.intoAnyElement();
    }

    /** Run `f` with `appeared` as the innermost scope. */
    static function within<R>(appeared:PlotAppeared, f:() -> R):R {
        PlotAppear.scopes.push(appeared);
        final result = f();
        PlotAppear.scopes.pop();
        return result;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        if (globalId != null) {
            appeared = window.withElementState(globalId, PlotAppeared, (state, _) -> {
                if (state.value == null) {
                    state.value = new PlotAppeared();
                }
                return state.value;
            });
        }
        else {
            appeared = new PlotAppeared();
        }
        final child = this.child;
        return within(appeared, () -> child != null ? child.requestLayout(window, cx) : window.requestLayout(@:privateAccess glaze.Style.sharedDefaultStyle(), null, cx));
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        // A virtual list lays its rows out here, so their plots appear here.
        final child = this.child;
        if (child != null) {
            within(appeared, () -> {
                child.prepaint(window, cx);
                return true;
            });
        }
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final child = this.child;
        if (child != null) {
            within(appeared, () -> {
                child.paint(window, cx);
                return true;
            });
        }
    }

}
