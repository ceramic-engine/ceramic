// New code for the Haxe port of gpui-kit (no Rust origin). See NOTICE.md.
package glaze.kit.curve;

import glaze.App;
import glaze.Bounds;
import glaze.Component;
import glaze.Context;
import glaze.DragMoveEvent;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Model;
import glaze.MouseButton;
import glaze.PathBuilder;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/** The drag value of a handle of a curve editor. */
private class DragCurveHandle {

    public final id:ElementId;

    /** 0: the handle that leaves the start. 1: the handle that arrives at the end. */
    public final handle:Int;

    public function new(id:ElementId, handle:Int) {
        this.id = id;
        this.handle = handle;
    }

}

/** The (empty) view of a handle drag: the handle itself shows the drag. */
private class EmptyCurveView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new glaze.Empty();
    }

}

/** A handle being dragged, kept as long as the editor is rendered. */
private class CurveGesture {

    public var active:Bool = false;

    /** The curve the gesture has reached. */
    public var bezier:Array<Float> = [0., 0., 1., 1.];

    public function new() {}

}

/**
 * Shows a timing curve, from (0, 0) to (1, 1), and edits it when it is a
 * cubic bezier curve: two handles to drag, one that leaves the start and
 * one that arrives at the end.
 *
 * A bezier curve is its four numbers, `[x1, y1, x2, y2]`, as in CSS
 * `cubic-bezier()`: x stays between 0 and 1, y may go past 0 and 1 for a
 * curve that overshoots. `onChange` is called at each move of a handle and
 * `onRelease` once when it is released. The curve is the caller's: give it
 * back through `bezier` to move the handles.
 *
 * `curve` draws any other function of time instead (a bounce, an elastic
 * curve), which has no handles. With both, the function is what is drawn
 * and the handles are shown `faded`: a curve that looks like the bezier
 * curve it could become.
 *
 * Under the curve, a row of points shows its pace: one point per equal
 * share of the time, close together where the curve is slow.
 *
 * The size is the element's (`w()`, `h()`): the drawing follows it.
 *
 * ```haxe
 * CurveEditor.component('easing').bezier([0.25, 0.1, 0.25, 1]).w(px(236)).h(px(176))
 *     .onChange((bezier, _, _) -> draft = bezier)
 *     .onRelease((bezier, _, _) -> commit(bezier))
 * ```
 */
class CurveEditor extends Component implements Styled {

    /** How many points a curve is drawn with. */
    static inline final SAMPLES:Int = 160;

    /** How many points show the pace. */
    static inline final PACE:Int = 12;

    /** The room around the square of 0 to 1, on the sides, for a handle at 0 or at 1. */
    static inline final SIDE:Float = 18.;

    /** The height of the row of pace points. */
    static inline final PACE_ROW:Float = 16.;

    final id:ElementId;

    final curveStyle:StyleRefinement = new StyleRefinement();

    /** The four numbers of the bezier curve, or null when the curve has no handles. */
    @prop var bezier:Null<Array<Float>> = null;

    /** A function of time (0 to 1) to draw instead of the bezier curve. */
    @prop var curve:Null<(Float) -> Float> = null;

    /** Draws the handles dimmed: they are not what defines the curve yet. */
    @prop var faded:Bool = false;

    /** How far past 0 and 1 a curve and its handles may go vertically, as a share of the height of 0 to 1. */
    @prop var overshoot:Float = 0.34;

    /** Whether the row of pace points is shown, default: true. */
    @prop var pace:Bool = true;

    @prop var disabled:Bool = false;

    /** Called with the four numbers at each move of a handle. */
    @prop var onChange:Null<(Array<Float>, Window, App) -> Void> = null;

    /** Called with the four numbers when a handle is released. */
    @prop var onRelease:Null<(Array<Float>, Window, App) -> Void> = null;

    var lineColor:Null<Hsla> = null;

    var squareColor:Null<Hsla> = null;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return curveStyle;
    }

    /** The color of the curve, instead of the primary color of the theme. */
    public function color(color:IntoHsla):CurveEditor {
        lineColor = color;
        return this;
    }

    /** The color of the square of 0 to 1 drawn behind the curve, instead of the border color of the theme. */
    public function frame(color:IntoHsla):CurveEditor {
        squareColor = color;
        return this;
    }

    /** The value of a bezier curve at a time from 0 to 1. */
    public static function valueAt(bezier:Array<Float>, time:Float):Float {
        final x1 = bezier[0], y1 = bezier[1], x2 = bezier[2], y2 = bezier[3];
        // x is monotonic for x1 and x2 between 0 and 1: found by bisection
        var low = 0.;
        var high = 1.;
        for (_ in 0...24) {
            final t = (low + high) * 0.5;
            final x = 3. * (1. - t) * (1. - t) * t * x1 + 3. * (1. - t) * t * t * x2 + t * t * t;
            if (x < time) low = t;
            else high = t;
        }
        final t = (low + high) * 0.5;
        return 3. * (1. - t) * (1. - t) * t * y1 + 3. * (1. - t) * t * t * y2 + t * t * t;
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /** The square of 0 to 1 inside the bounds of the plot: room on the sides, and above and under for what overshoots. */
    static function unitSquare(plot:Bounds, overshoot:Float):Bounds {
        final width:Float = (plot.size.width : Float) - SIDE * 2.;
        final height:Float = (plot.size.height : Float) / (1. + overshoot * 2.);
        return new Bounds(new Point((plot.origin.x : Float) + SIDE, (plot.origin.y : Float) + height * overshoot), new Size(px(width), px(height)));
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final editorId = id;
        final overshoot = this.overshoot;
        final control = bezier;
        final given = curve;
        final value:(Float) -> Float = given != null ? given : (control != null ? time -> valueAt(control, time) : time -> time);
        final color:Hsla = lineColor != null ? lineColor : theme.primary;
        final handleColor = theme.foreground.opacity(faded ? 0.45 : 1.);
        final frameColor:Hsla = squareColor != null ? squareColor : theme.border;
        final paceColor = theme.mutedForeground;
        final ground = theme.background;
        final gesture:CurveGesture = window.useKeyedState(ElementId.NamedChild(editorId, 'curve-gesture'), cx, _ -> new CurveGesture()).read(cx).value;
        final change = onChange;
        final release = onRelease;

        function stroke(window:Window, points:Array<Point>, width:Float, color:Hsla):Void {
            final line = PathBuilder.stroke(px(width));
            line.moveTo(points[0]);
            for (i in 1...points.length) line.lineTo(points[i]);
            final path = try line.build() catch (e:haxe.Exception) null;
            if (path != null) window.paintPath(path, color);
        }

        final plot = div().id(ElementId.NamedChild(editorId, 'plot')).relative().flex1().minH0().wFull();
        plot.child(canvas((_, _, _) -> null, (bounds, _, window, _) -> {
            final unit = unitSquare(bounds, overshoot);
            final left:Float = unit.origin.x;
            final top:Float = unit.origin.y;
            final width:Float = unit.size.width;
            final height:Float = unit.size.height;
            inline function at(x:Float, y:Float):Point {
                return new Point(left + width * x, top + height * (1. - clamp(y, -overshoot, 1. + overshoot)));
            }
            stroke(window, [at(0, 0), at(1, 0), at(1, 1), at(0, 1), at(0, 0)], 1., frameColor);
            stroke(window, [for (i in 0...SAMPLES + 1) at(i / SAMPLES, value(i / SAMPLES))], 2., color);
            if (control != null) {
                stroke(window, [at(0, 0), at(control[0], control[1])], 1., handleColor);
                stroke(window, [at(1, 1), at(control[2], control[3])], 1., handleColor);
            }
        }).absolute().inset0());

        if (control != null) {
            // The handles sit in the square of 0 to 1, which the plot leaves room around
            final share = overshoot / (1. + overshoot * 2.);
            final square = div().absolute().left(px(SIDE)).right(px(SIDE)).top(relative(share)).bottom(relative(share));
            for (index in 0...2) {
                final handle = index;
                final knob = div()
                    .id(ElementId.NamedChild(editorId, 'handle-' + handle))
                    .absolute()
                    .left(relative(clamp(control[handle * 2], 0., 1.)))
                    .top(relative(1. - clamp(control[handle * 2 + 1], -overshoot, 1. + overshoot)))
                    .ml(px(-6.))
                    .mt(px(-6.))
                    .w(px(12.))
                    .h(px(12.))
                    .roundedFull()
                    .border(px(1.5))
                    .borderColor(handleColor)
                    .bg(ground);
                if (!disabled) {
                    knob.cursorPointer().onDrag(new DragCurveHandle(editorId, handle), (_, _, _, cx) -> {
                        cx.stopPropagation();
                        return cx.newEntity((_:Context<EmptyCurveView>) -> new EmptyCurveView());
                    });
                }
                square.child(knob);
            }
            plot.child(square);
            if (!disabled) {
                plot.onDragMove(DragCurveHandle, (event:DragMoveEvent<DragCurveHandle>, window, cx) -> {
                    final drag = event.drag(cx);
                    if (!Type.enumEq(drag.id, editorId)) return;
                    final unit = unitSquare(event.bounds, overshoot);
                    final x = clamp(((event.event.position.x : Float) - (unit.origin.x : Float)) / (unit.size.width : Float), 0., 1.);
                    final y = clamp(1. - ((event.event.position.y : Float) - (unit.origin.y : Float)) / (unit.size.height : Float), -overshoot, 1. + overshoot);
                    if (!gesture.active) {
                        gesture.active = true;
                        gesture.bezier = control.copy();
                    }
                    final next = gesture.bezier.copy();
                    next[drag.handle * 2] = Math.round(x * 100.) / 100.;
                    next[drag.handle * 2 + 1] = Math.round(y * 100.) / 100.;
                    gesture.bezier = next;
                    if (change != null) change(next, window, cx);
                });
            }
        }

        final root = div().id(editorId).flex().flexCol().rounded(theme.radius).bg(ground).refineStyle(curveStyle).child(plot);
        if (pace) {
            root.child(canvas((_, _, _) -> null, (bounds, _, window, _) -> {
                final left:Float = (bounds.origin.x : Float) + SIDE;
                final width:Float = (bounds.size.width : Float) - SIDE * 2.;
                final middle:Float = (bounds.origin.y : Float) + (bounds.size.height : Float) / 2.;
                for (i in 0...PACE + 1) {
                    final x = left + width * clamp(value(i / PACE), 0., 1.);
                    window.paintQuad(fill(new Bounds(new Point(x - 1.5, middle - 1.5), new Size(px(3.), px(3.))), paceColor));
                }
            }).wFull().h(px(PACE_ROW)).flexShrink0());
        }
        if (disabled) return root.opacity(0.5);
        function end(window:Window, cx:App):Void {
            if (!gesture.active) return;
            gesture.active = false;
            if (release != null) release(gesture.bezier, window, cx);
        }
        return root
            .onMouseUp(MouseButton.Left, (_, window, cx) -> end(window, cx))
            .onMouseUpOut(MouseButton.Left, (_, window, cx) -> end(window, cx));
    }

}
