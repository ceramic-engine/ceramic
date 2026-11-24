// New code for the Haxe port of gpui-kit (no Rust origin). See NOTICE.md.
package glaze.kit.dial;

import glaze.App;
import glaze.Bounds;
import glaze.Component;
import glaze.Context;
import glaze.CursorStyle;
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
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/** The drag value of an angle dial. */
private class DragDial {

    public final id:ElementId;

    public function new(id:ElementId) {
        this.id = id;
    }

}

/** The (empty) view of a dial drag: the needle itself shows the drag. */
private class EmptyDialView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new glaze.Empty();
    }

}

/** A turn of the needle in progress, kept as long as the dial is rendered. */
private class DialGesture {

    public var active:Bool = false;

    /** Where the dial was drawn last. */
    public var bounds:Null<Bounds> = null;

    /** The direction of the pointer at its last position, in degrees. */
    public var pointerAngle:Float = 0.;

    /** The value the gesture has reached, before it is rounded to the step. */
    public var value:Float = 0.;

    public function new() {}

}

/**
 * A small dial that shows an angle with a needle and lets it be turned:
 * press anywhere on the dial to point the needle there, drag to turn it.
 *
 * The angle is in degrees: 0 points to the right and the angle grows
 * clockwise, as rotations do on screen. The value is not kept between 0 and
 * 360: turning the needle past a full turn keeps counting, in both
 * directions, so that a value of 720 or -90 stays what it is.
 *
 * Like a `Slider`, the dial has a value, a step, and tells its changes:
 * `onChange` at each move, `onRelease` once when the pointer is released.
 * The value is the caller's: give it back through `value` to move the needle.
 *
 * ```haxe
 * AngleDial.component('rotation').value(item.rotation).step(1)
 *     .onChange((degrees, _, _) -> item.rotation = degrees)
 * ```
 */
class AngleDial extends Component implements Styled implements Sizable {

    final id:ElementId;

    final dialStyle:StyleRefinement = new StyleRefinement();

    /** The angle shown, in degrees. */
    @prop var value:Float = 0.;

    /** The values a turn stops on: multiples of the step (default 1). */
    @prop var step:Float = 1.;

    @prop var disabled:Bool = false;

    /** Called with the angle at each move of the needle. */
    @prop var onChange:Null<(Float, Window, App) -> Void> = null;

    /** Called with the angle when the pointer is released after turning the needle. */
    @prop var onRelease:Null<(Float, Window, App) -> Void> = null;

    /** Sets the label exposed to accessibility clients. */
    @prop var accessibilityLabel:Null<String> = null;

    var needleColor:Null<Hsla> = null;

    var sizeValue:Size = Medium;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return dialStyle;
    }

    /** The color of the needle, instead of the primary color of the theme. */
    public function color(color:IntoHsla):AngleDial {
        needleColor = color;
        return this;
    }

    public function withSize(size:IntoSize):AngleDial {
        this.sizeValue = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.sizeValue = size;
    }

    /** The direction from the center of `bounds` to `position`, in degrees, clockwise from the right. */
    static function directionTo(bounds:Bounds, position:Point):Float {
        final center = bounds.center();
        return Math.atan2((position.y : Float) - (center.y : Float), (position.x : Float) - (center.x : Float)) * 180. / Math.PI;
    }

    /** The shortest way from an angle to another, between -180 and 180 degrees. */
    static function shortestTurn(from:Float, to:Float):Float {
        var turn = (to - from) % 360.;
        if (turn > 180.) turn -= 360.;
        if (turn < -180.) turn += 360.;
        return turn;
    }

    static function rounded(value:Float, step:Float):Float {
        if (!(step > 0.)) return value;
        final stepped = Math.round(value / step) * step;
        // Without the noise of the multiplication (0.1 * 3)
        return Math.round(stepped * 1e6) / 1e6;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final diameter:Float = switch sizeValue {
            case XSmall: 18.;
            case Small: 22.;
            case Medium: 28.;
            case Large: 36.;
            case Size(value): value;
        }
        final degrees = value;
        final step = this.step;
        final color:Hsla = needleColor != null ? needleColor : theme.primary;
        final dialId = id;
        final gesture:DialGesture = window.useKeyedState(ElementId.NamedChild(dialId, 'dial-gesture'), cx, _ -> new DialGesture()).read(cx).value;
        final change = onChange;
        final release = onRelease;

        final dial = div()
            .id(dialId)
            .flexShrink0()
            .w(px(diameter))
            .h(px(diameter))
            .roundedFull()
            .border(px(1.5))
            .borderColor(theme.border)
            .refineStyle(dialStyle)
            .child(canvas((bounds, _, _) -> {
                gesture.bounds = bounds;
                return null;
            }, (bounds, _, window, _) -> {
                final center = bounds.center();
                final angle = degrees * Math.PI / 180.;
                // The needle stops short of the ring
                final reach = (bounds.size.width : Float) / 2. - 2.;
                final needle = PathBuilder.stroke(px(1.5));
                needle.moveTo(center);
                needle.lineTo(new Point((center.x : Float) + Math.cos(angle) * reach, (center.y : Float) + Math.sin(angle) * reach));
                final path = try needle.build() catch (e:haxe.Exception) null;
                if (path != null) window.paintPath(path, color);
            }).absolute().inset0());
        dial.relative();
        if (disabled) return dial.opacity(0.5);

        // A turn starts from the value shown, and adds what the pointer turns by
        function turnTo(position:Point, window:Window, cx:App):Void {
            final bounds = gesture.bounds;
            if (bounds == null) return;
            final direction = directionTo(bounds, position);
            if (!gesture.active) {
                gesture.active = true;
                // A press points the needle at the pointer, by the shortest way
                gesture.value = degrees + shortestTurn(degrees, direction);
            } else {
                gesture.value += shortestTurn(gesture.pointerAngle, direction);
            }
            gesture.pointerAngle = direction;
            if (change != null) change(rounded(gesture.value, step), window, cx);
        }
        function end(window:Window, cx:App):Void {
            if (!gesture.active) return;
            gesture.active = false;
            if (release != null) release(rounded(gesture.value, step), window, cx);
        }
        return dial
            .cursor(CursorStyle.PointingHand)
            .onMouseDown(MouseButton.Left, (event, window, cx) -> {
                cx.stopPropagation();
                turnTo(event.position, window, cx);
            })
            .onDrag(new DragDial(dialId), (_, _, _, cx) -> {
                cx.stopPropagation();
                return cx.newEntity((_:Context<EmptyDialView>) -> new EmptyDialView());
            })
            .onDragMove(DragDial, (event:DragMoveEvent<DragDial>, window, cx) -> {
                if (!Type.enumEq(event.drag(cx).id, dialId)) return;
                turnTo(event.event.position, window, cx);
            })
            .onMouseUp(MouseButton.Left, (_, window, cx) -> end(window, cx))
            .onMouseUpOut(MouseButton.Left, (_, window, cx) -> end(window, cx));
    }

}
