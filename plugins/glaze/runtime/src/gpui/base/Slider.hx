// Ported from gpui-kit 0.8.1: crates/base/src/slider.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Context;
import gpui.Div;
import gpui.DragMoveEvent;
import gpui.ElementId;
import gpui.Entity;
import gpui.MouseButton;
import gpui.HitboxBehavior;
import gpui.IntoElement;
import gpui.Model;
import gpui.ParentElement;
import gpui.Point;
import gpui.Render;
import gpui.RenderOnce;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;

import gpui.Prelude.*;

using gpui.base.ElementExt;
using gpui.base.Slider.SliderValueTools;

/**
 * Events emitted by the `SliderState`.
 */
enum SliderEvent {
    /** Emitted continuously while the slider value is being changed by the user. */
    Change(value:SliderValue);
    /** Emitted once when the user releases the slider after a drag or click. */
    Release(value:SliderValue);
}

/**
 * The value of the slider, a single value or a range of values (default
 * `Single(0)`). Methods are in `SliderValueTools`.
 */
@:using(gpui.base.Slider.SliderValueTools)
enum SliderValue {
    Single(value:Float);
    Range(start:Float, end:Float);
}

/**
 * Rust `impl Into<SliderValue>`: a `SliderValue`, or a number for `Single`.
 */
abstract IntoSliderValue(SliderValue) from SliderValue to SliderValue {

    @:from static inline function fromFloat(value:Float):IntoSliderValue {
        return Single(value);
    }

    @:from static inline function fromInt(value:Int):IntoSliderValue {
        return Single(value);
    }

    /** Rust `From<(f32, f32)>` and `From<Range<f32>>`. */
    @:from static inline function fromArray(value:Array<Float>):IntoSliderValue {
        return Range(value[0], value[1]);
    }

}

/**
 * Methods of `SliderValue`.
 */
class SliderValueTools {

    static inline function clampF(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /**
     * Clamp the value to the given range.
     */
    public static function clamp(self:SliderValue, min:Float, max:Float):SliderValue {
        return switch self {
            case Single(value): Single(clampF(value, min, max));
            case Range(start, end): Range(clampF(start, min, max), clampF(end, min, max));
        }
    }

    /**
     * Check if the value is a single value.
     */
    public static inline function isSingle(self:SliderValue):Bool {
        return self.match(Single(_));
    }

    /**
     * Check if the value is a range of values.
     */
    public static inline function isRange(self:SliderValue):Bool {
        return self.match(Range(_, _));
    }

    /**
     * Get the start value.
     */
    public static function start(self:SliderValue):Float {
        return switch self {
            case Single(value): value;
            case Range(start, _): start;
        }
    }

    /**
     * Get the end value.
     */
    public static function end(self:SliderValue):Float {
        return switch self {
            case Single(value): value;
            case Range(_, end): end;
        }
    }

    @:allow(gpui.base)
    static function withStart(self:SliderValue, value:Float):SliderValue {
        return switch self {
            case Range(_, end): Range(Math.min(value, end), end);
            case Single(_): Single(value);
        }
    }

    @:allow(gpui.base)
    static function withEnd(self:SliderValue, value:Float):SliderValue {
        return switch self {
            case Range(start, _): Range(start, Math.max(value, start));
            case Single(_): Single(value);
        }
    }

    /**
     * Structural equality (Rust `PartialEq`).
     */
    public static function equals(self:SliderValue, other:SliderValue):Bool {
        return switch [self, other] {
            case [Single(a), Single(b)]: a == b;
            case [Range(a, b), Range(c, d)]: a == c && b == d;
            case _: false;
        }
    }

    /**
     * Rust `Display`: `{}` of the f32 value, or `start..end`.
     */
    public static function toDisplayString(self:SliderValue):String {
        return switch self {
            case Single(value): f32String(value);
            case Range(start, end): f32String(start) + '..' + f32String(end);
        }
    }

    /**
     * Rust's `{}` of an `f32`: the shortest representation that reads back as
     * the same `f32`, without exponent.
     */
    public static function f32String(value:Float):String {
        if (Math.isNaN(value)) return 'NaN';
        if (value == Math.POSITIVE_INFINITY) return 'inf';
        if (value == Math.NEGATIVE_INFINITY) return '-inf';
        final target = f32(value);
        if (target == Math.ffloor(target) && Math.abs(target) < 1e15) {
            return formatInteger(target);
        }
        for (digits in 1...18) {
            final s = toFixedTrimmed(target, digits);
            if (f32(Std.parseFloat(s)) == target) return s;
        }
        return '' + target;
    }

    static function formatInteger(value:Float):String {
        final s = Std.string(value);
        final dot = s.indexOf('.');
        return dot >= 0 ? s.substr(0, dot) : s;
    }

    static function toFixedTrimmed(value:Float, digits:Int):String {
        final scale = Math.pow(10, digits);
        final negative = value < 0;
        final scaled = Math.fround(Math.abs(value) * scale);
        var intPart = Math.ffloor(scaled / scale);
        var frac = Std.string(Std.int(scaled - intPart * scale));
        while (frac.length < digits) frac = '0' + frac;
        while (frac.length > 0 && frac.charAt(frac.length - 1) == '0') frac = frac.substr(0, frac.length - 1);
        final s = formatInteger(intPart) + (frac.length > 0 ? '.' + frac : '');
        return negative ? '-' + s : s;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

}

/**
 * The scale mode of the slider.
 */
enum abstract SliderScale(Int) {

    /**
     * Linear scale where values change uniformly across the slider range.
     * This is the default mode.
     */
    var Linear;

    /**
     * Logarithmic scale where the distance between values increases exponentially.
     *
     * This is useful for parameters that have a large range of values where smaller
     * changes are more significant at lower values: volume, frequency, zoom levels.
     * `min` must be greater than 0. Moving the slider 1/3 of the way between 1 and
     * 1000 yields about 10, 2/3 of the way about 100.
     */
    var Logarithmic;

    public inline function isLinear():Bool {
        return (cast this:SliderScale) == Linear;
    }

    public inline function isLogarithmic():Bool {
        return (cast this:SliderScale) == Logarithmic;
    }

}

/**
 * State of the `Slider` (an entity: `cx.newEntity(_ -> new SliderState())`).
 *
 * The value and the thumb percentages are observable: views rendering the
 * slider re-render when they change. Rust's `Range<f32>` percentage is
 * `percentageStart` / `percentageEnd`; in single value mode only the end is
 * used and the start is always 0.
 */
class SliderState extends Model {

    var minimum:Float = 0.0;

    var maximum:Float = 100.0;

    var stepSize:Float = 1.0;

    @observe var currentValue:SliderValue = Single(0.);

    @observe var percentageStart:Float = 0.0;

    @observe var percentageEnd:Float = 0.0;

    /** The bounds of the slider after rendered. */
    var stateBounds:Bounds = new Bounds(new Point(0, 0), new gpui.Size(0, 0));

    var scaleMode:SliderScale = Linear;

    /**
     * Tracks whether the user is currently interacting with the slider so we
     * only emit `SliderEvent.Release` after a real press/drag.
     */
    var dragging:Bool = false;

    /** The touch drag this slider claimed, while one is live. */
    @:allow(gpui.base)
    var touchDrag:Null<SliderTouchDrag> = null;

    /**
     * Create a new `SliderState`.
     */
    public function new() {
        super();
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    static inline function clampF(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /**
     * Set the minimum value of the slider, default: 0.0
     */
    public function min(min:Float):SliderState {
        if (scaleMode.isLogarithmic()) {
            if (!(min > 0.0)) throw '`min` must be greater than 0 for SliderScale::Logarithmic';
            if (!(min < maximum)) throw '`min` must be less than `max` for Logarithmic scale';
        }
        minimum = min;
        updateThumbPos();
        return this;
    }

    /**
     * Set the maximum value of the slider, default: 100.0
     */
    public function max(max:Float):SliderState {
        if (scaleMode.isLogarithmic()) {
            if (!(max > minimum)) throw '`max` must be greater than `min` for Logarithmic scale';
        }
        maximum = max;
        updateThumbPos();
        return this;
    }

    /**
     * Set the step value of the slider, default: 1.0
     */
    public function step(step:Float):SliderState {
        stepSize = step;
        return this;
    }

    /**
     * Set the scale of the slider, default: `SliderScale.Linear`.
     */
    public function scale(scale:SliderScale):SliderState {
        if (scale.isLogarithmic()) {
            if (!(minimum > 0.0)) throw '`min` must be greater than 0 for Logarithmic scale';
            if (!(maximum > minimum)) throw '`max` must be greater than `min` for Logarithmic scale';
        }
        scaleMode = scale;
        updateThumbPos();
        return this;
    }

    /**
     * Set the default value of the slider, default: 0.0
     */
    public function defaultValue(value:IntoSliderValue):SliderState {
        currentValue = value;
        updateThumbPos();
        return this;
    }

    /**
     * Set the value of the slider.
     */
    public function setValue(value:IntoSliderValue, window:Null<Window>, cx:Null<Context<SliderState>>):Void {
        currentValue = value;
        updateThumbPos();
    }

    /**
     * Get the value of the slider.
     */
    public function value():SliderValue {
        return currentValue;
    }

    /**
     * Get the minimum value.
     */
    public function minValue():Float {
        return minimum;
    }

    /**
     * Get the maximum value.
     */
    public function maxValue():Float {
        return maximum;
    }

    /**
     * Get the step value.
     */
    public function stepValue():Float {
        return stepSize;
    }

    /**
     * Converts a value between 0.0 and 1.0 to a value between the minimum and maximum value,
     * depending on the chosen scale.
     */
    function percentageToValue(percentage:Float):Float {
        return switch scaleMode {
            case Linear: f32(minimum + f32(f32(maximum - minimum) * percentage));
            case Logarithmic:
                // when percentage is 0, this simplifies to (max/min)^0 * min = 1 * min = min
                // when percentage is 1, this simplifies to (max/min)^1 * min = (max*min)/min = max
                // we clamp just to make sure we don't have issue with floating point precision
                final base = f32(maximum / minimum);
                clampF(f32(f32(Math.pow(base, percentage)) * minimum), minimum, maximum);
        }
    }

    /**
     * Converts a value between the minimum and maximum value to a value between 0.0 and 1.0,
     * depending on the chosen scale.
     */
    function valueToPercentage(value:Float):Float {
        return switch scaleMode {
            case Linear:
                final range = f32(maximum - minimum);
                if (range <= 0.0) 0.0 else f32(f32(value - minimum) / range);
            case Logarithmic:
                final base = f32(maximum / minimum);
                clampF(f32(f32(Math.log(f32(value / minimum))) / f32(Math.log(base))), 0.0, 1.0);
        }
    }

    function updateThumbPos():Void {
        switch currentValue {
            case Single(value):
                final percentage = valueToPercentage(clampF(value, minimum, maximum));
                percentageStart = 0.0;
                percentageEnd = percentage;
            case Range(start, end):
                final clampedStart = clampF(start, minimum, maximum);
                final clampedEnd = clampF(end, minimum, maximum);
                percentageStart = valueToPercentage(clampedStart);
                percentageEnd = valueToPercentage(clampedEnd);
        }
    }

    /**
     * Update value by mouse position.
     */
    @:noCompletion
    public function updateValueByPosition(axis:Axis, position:Point, isStart:Bool, window:Window, cx:Context<SliderState>):Void {
        dragging = true;
        final bounds = stateBounds;
        final step = stepSize;

        final innerPos = axis == Axis.Horizontal ? f32(position.x - bounds.left()) : f32(bounds.bottom() - position.y);
        final totalSize = f32(bounds.size.along(axis));
        var percentage = f32(clampF(innerPos, 0., totalSize) / totalSize);

        percentage = if (isStart) {
            clampF(percentage, 0.0, percentageEnd);
        } else {
            clampF(percentage, percentageStart, 1.0);
        }

        var value = percentageToValue(percentage);
        value = f32(f32(gpui.util.MathUtil.round(f32(value / step))) * step);

        if (isStart) {
            percentageStart = percentage;
            currentValue = currentValue.withStart(value);
        } else {
            percentageEnd = percentage;
            currentValue = currentValue.withEnd(value);
        }
        cx.emit(SliderEvent.Change(currentValue));
    }

    /**
     * Whether `position` is closer to the range start thumb than to the end thumb.
     */
    @:allow(gpui.base)
    function isNearerStart(axis:Axis, position:Point):Bool {
        final size = f32(stateBounds.size.along(axis));
        final along = axis == Axis.Horizontal ? f32(position.x - stateBounds.left()) : f32(stateBounds.bottom() - position.y);
        final center = f32(f32(f32(f32(percentageEnd - percentageStart) / 2.) + percentageStart) * size);
        return along < center;
    }

    /**
     * Emit `SliderEvent.Release` if the user was actively interacting with
     * the slider. Called on mouse-up both inside and outside the slider.
     */
    @:noCompletion
    public function handleRelease(cx:Context<SliderState>):Void {
        if (!dragging) return;
        dragging = false;
        cx.emit(SliderEvent.Release(currentValue));
    }

    /**
     * The thumb positions, between 0 and 1.
     */
    @:noCompletion
    public function percentage():SliderPercentage {
        return new SliderPercentage(percentageStart, percentageEnd);
    }

    @:noCompletion
    public function bounds():Bounds {
        return stateBounds;
    }

    @:noCompletion
    public function setBounds(bounds:Bounds):Void {
        stateBounds = bounds;
    }

}

/**
 * The thumb positions of a slider, between 0 and 1 (Rust `Range<f32>`).
 */
class SliderPercentage {

    public final start:Float;

    public final end:Float;

    public inline function new(start:Float, end:Float) {
        this.start = start;
        this.end = end;
    }

}

/**
 * The drag value of a slider thumb: the slider's entity id and whether it
 * is the range start thumb.
 */
private class DragThumb {

    public final entityId:Int;

    public final start:Bool;

    public function new(entityId:Int, start:Bool) {
        this.entityId = entityId;
        this.start = start;
    }

}

/**
 * The drag value of a slider track.
 */
private class DragSlider {

    public final entityId:Int;

    public function new(entityId:Int) {
        this.entityId = entityId;
    }

}

/**
 * The (empty) view of a slider drag.
 */
private class EmptyDragView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}

/**
 * An unstyled slider behavior root.
 *
 * Applications provide the track, range, and thumb presentation as children.
 */
class Slider implements RenderOnce implements Styled implements ParentElement {

    final state:Entity<SliderState>;

    var axisValue:Axis = Axis.Horizontal;

    var disabledValue:Bool = false;

    var accessibilityLabelValue:Null<String> = null;

    final base:Div = div();

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the slider exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Slider);

    public function new(state:Entity<SliderState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Slider {
        childElements.push(child);
        return this;
    }

    public function horizontal():Slider {
        axisValue = Axis.Horizontal;
        return this;
    }

    public function vertical():Slider {
        axisValue = Axis.Vertical;
        return this;
    }

    public function axis(axis:Axis):Slider {
        axisValue = axis;
        return this;
    }

    public function disabled(disabled:Bool):Slider {
        disabledValue = disabled;
        return this;
    }

    /**
     * Sets the label exposed to accessibility clients.
     */
    public function accessibilityLabel(label:String):Slider {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * The accessibility increment action (Rust `AccessibleAction::Increment`):
     * one step up, while enabled.
     */
    public static function increment(state:Entity<SliderState>, window:Window, cx:App):Void {
        state.update(cx, (state, cx) -> {
            final value = Math.min(state.value().end() + state.stepValue(), state.maxValue());
            state.setValue(value, window, cx);
        });
    }

    /**
     * The accessibility decrement action (Rust `AccessibleAction::Decrement`):
     * one step down, while enabled.
     */
    public static function decrement(state:Entity<SliderState>, window:Window, cx:App):Void {
        state.update(cx, (state, cx) -> {
            final value = Math.max(state.value().end() - state.stepValue(), state.minValue());
            state.setValue(value, window, cx);
        });
    }

    public function render(window:Window, cx:App):IntoElement {
        final axis = axisValue;
        final entityId = state.entityId();
        final current = state.read(cx);
        final sliderState = state;

        final element = base.id(ElementId.NamedInteger('slider', entityId));
        if (accessibilityLabelValue != null) a11y.label = accessibilityLabelValue;
        a11y.numericValue = current.value().end();
        a11y.minNumericValue = current.minValue();
        a11y.maxNumericValue = current.maxValue();
        a11y.numericValueStep = current.stepValue();
        a11y.orientation = axis == Axis.Vertical ? Orientation.Vertical : Orientation.Horizontal;
        // A disabled slider takes no value, from the pointer or from
        // assistive technology.
        if (!disabledValue) {
            a11y.adjustable = true;
            element
                .onMouseUp(MouseButton.Left, (_, _, cx) -> sliderState.update(cx, (state, cx) -> state.handleRelease(cx)))
                .onMouseUpOut(MouseButton.Left, (_, _, cx) -> sliderState.update(cx, (state, cx) -> state.handleRelease(cx)));
        }
        element.extend(childElements);
        a11y.disabled = disabledValue;
        return element;
    }

}

/**
 * An unstyled track that records the geometry used to map pointer positions.
 */
class SliderTrack implements RenderOnce implements Styled implements ParentElement {

    final state:Entity<SliderState>;

    var axisValue:Axis = Axis.Horizontal;

    var disabledValue:Bool = false;

    /** The element the track renders (interactive styles and listeners). */
    public final base:Div = div();

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<SliderState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):SliderTrack {
        childElements.push(child);
        return this;
    }

    public function axis(axis:Axis):SliderTrack {
        axisValue = axis;
        return this;
    }

    public function disabled(disabled:Bool):SliderTrack {
        disabledValue = disabled;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final axis = axisValue;
        final entityId = state.entityId();
        final current = state.read(cx);
        final isRange = current.value().isRange();
        final percentage = current.percentage();
        final sliderState = state;
        final element = base.id('slider-bar-container');
        element.extend(childElements);
        // Touch: GPUI routes a finger drag to `TouchDragEvent` (claimed with
        // `preventDefault`) or to scrolling; `onDrag` below is mouse-only.
        // Claim drags that start on the track, as the scrollbar thumb does.
        if (!disabledValue) {
            element.extend([
                canvas((bounds, window, _) -> window.insertHitbox(bounds, HitboxBehavior.Normal), (_, hitbox, window, _) -> {
                    window.onMouseEvent(TouchDrag, (e, phase, window, cx) -> {
                        final event:gpui.TouchDragEvent = cast e;
                        if (!phase.bubble()) {
                            return;
                        }
                        sliderState.update(cx, (state, cx) -> {
                            if (event.phase == Started) {
                                // A drag whose end never arrived (the slider was
                                // disabled or not painted) ends when another begins.
                                if (state.touchDrag != null) {
                                    state.touchDrag = null;
                                    state.handleRelease(cx);
                                }
                                // The hitbox, not the bounds, so a layer covering
                                // the track keeps its own drags.
                                if (window.defaultPrevented() || !hitbox.isHovered(window)) {
                                    return;
                                }
                                window.preventDefault();
                                final isStart = isRange && state.isNearerStart(axis, event.startPosition);
                                state.touchDrag = new SliderTouchDrag(event.startPosition, isStart);
                            }
                            final drag = state.touchDrag;
                            if (drag == null) {
                                return;
                            }
                            if (!drag.startPosition.equals(event.startPosition)) {
                                return;
                            }
                            cx.stopPropagation();
                            switch event.phase {
                                case Started | Moved:
                                    state.updateValueByPosition(axis, event.position, drag.isStart, window, cx);
                                case Ended | Cancelled:
                                    state.touchDrag = null;
                                    state.handleRelease(cx);
                            }
                        });
                    });
                })
                    .absolute()
                    .sizeFull()
                    .intoAnyElement()
            ]);
        }
        if (!disabledValue) {
            element.onMouseDown(MouseButton.Left, (event, window, cx) -> sliderState.update(cx, (state, cx) -> {
                final isStart = if (isRange) {
                    final size = f32(state.bounds().size.along(axis));
                    final position = axis == Axis.Horizontal ? f32(event.position.x - state.bounds().left()) : f32(state.bounds().bottom() - event.position.y);
                    final center = f32(f32(f32(f32(percentage.end - percentage.start) / 2.) + percentage.start) * size);
                    position < center;
                } else {
                    false;
                }
                state.updateValueByPosition(axis, event.position, isStart, window, cx);
            }));
            if (!isRange) {
                element
                    .onDrag(new DragSlider(entityId), (drag, _, _, cx) -> {
                        cx.stopPropagation();
                        return cx.newEntity((_:Context<EmptyDragView>) -> new EmptyDragView());
                    })
                    .onDragMove(DragSlider, (event:DragMoveEvent<DragSlider>, window, cx) -> {
                        if (event.drag(cx).entityId == entityId) {
                            sliderState.update(cx, (state, cx) -> state.updateValueByPosition(axis, event.event.position, false, window, cx));
                        }
                    });
            }
        }
        return element;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

}

/**
 * An unstyled slider indicator that records the value-mapping bounds.
 */
class SliderIndicator implements RenderOnce implements Styled implements ParentElement {

    final state:Entity<SliderState>;

    /** The element the indicator renders (interactive styles and listeners). */
    public final base:Div = div();

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<SliderState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):SliderIndicator {
        childElements.push(child);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:StyleBuilder->StyleBuilder):SliderIndicator {
        base.active(f);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = base.id('slider-bar');
        element.extend(childElements);
        final state = this.state;
        // Only when they moved: with retained views, an update while the
        // window draws renders every view that reads the state again.
        return element.onPrepaint((bounds, _, cx) -> {
            if (!state.read(cx).bounds().equals(bounds)) {
                state.update(cx, (state, _) -> state.setBounds(bounds));
            }
        });
    }

}

/**
 * An unstyled draggable slider thumb.
 */
class SliderThumb implements RenderOnce implements Styled implements ParentElement {

    final state:Entity<SliderState>;

    var axisValue:Axis = Axis.Horizontal;

    var startValue:Bool = false;

    var disabledValue:Bool = false;

    /** The element the thumb renders (interactive styles and listeners). */
    public final base:Div = div();

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<SliderState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):SliderThumb {
        childElements.push(child);
        return this;
    }

    public function axis(axis:Axis):SliderThumb {
        axisValue = axis;
        return this;
    }

    public function start(start:Bool):SliderThumb {
        startValue = start;
        return this;
    }

    public function disabled(disabled:Bool):SliderThumb {
        disabledValue = disabled;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final entityId = state.entityId();
        final axis = axisValue;
        final start = startValue;
        final sliderState = state;
        final element = base.id(ElementId.NamedInteger('slider-thumb', start ? 1 : 0));
        element.extend(childElements);
        if (!disabledValue) {
            element
                .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation())
                .onDrag(new DragThumb(entityId, start), (drag, _, _, cx) -> {
                    cx.stopPropagation();
                    return cx.newEntity((_:Context<EmptyDragView>) -> new EmptyDragView());
                })
                .onDragMove(DragThumb, (event:DragMoveEvent<DragThumb>, window, cx) -> {
                    final drag = event.drag(cx);
                    if (drag.entityId == entityId) {
                        sliderState.update(cx, (state, cx) -> state.updateValueByPosition(axis, event.event.position, drag.start, window, cx));
                    }
                });
        }
        return element;
    }

}

/**
 * A touch drag claimed by a slider.
 */
@:allow(gpui.base)
class SliderTouchDrag {

    /** Identifies the gesture: every event of one drag carries the same start. */
    public final startPosition:Point;

    /** Whether it moves the range start thumb. */
    public final isStart:Bool;

    public function new(startPosition:Point, isStart:Bool) {
        this.startPosition = startPosition;
        this.isStart = isStart;
    }

}
