// Ported from gpui-kit 0.8.1: crates/base/src/time_field.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.Empty;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.KeyDownEvent;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.Render;
import glaze.RenderOnce;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectNextColumn;
import glaze.kit.base.Actions.SelectPrevColumn;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.NumberInput.Decrement;
import glaze.kit.base.NumberInput.Increment;
import glaze.kit.base.chrono.NaiveTime;
import glaze.kit.base.input.InputActions.Delete;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * The smallest unit a `TimeField` edits.
 */
enum abstract TimePrecision(Int) {

    /** Hours and minutes, e.g. `09:30` (the default). */
    var Minute;

    /** Hours, minutes and seconds, e.g. `09:30:15`. */
    var Second;

    /** The default, `Minute` (Rust `TimePrecision::default()`). */
    public static inline function defaultValue():TimePrecision {
        return Minute;
    }

    /** The `chrono` format that displays a time at this precision and cycle. */
    public function format(hourCycle:HourCycle):String {
        return switch [(cast this : TimePrecision), hourCycle] {
            case [Minute, H23]: '%H:%M';
            case [Second, H23]: '%H:%M:%S';
            case [Minute, H12]: '%I:%M %p';
            case [Second, H12]: '%I:%M:%S %p';
        }
    }

    /** Drop the components finer than this precision. */
    public function truncate(time:NaiveTime):NaiveTime {
        final second = (cast this : TimePrecision) == Minute ? 0 : time.second();
        final result = NaiveTime.fromHmsOpt(time.hour(), time.minute(), second);
        return result != null ? result : time;
    }

}

/**
 * How a `TimeField` counts the hours of a day.
 *
 * The names follow the Unicode `hourCycle` values.
 */
enum abstract HourCycle(Int) {

    /** A 24-hour clock from `00` to `23` (the default). */
    var H23;

    /** A 12-hour clock from `12` to `11`, with an AM/PM segment. */
    var H12;

    public static inline function defaultValue():HourCycle {
        return H23;
    }

}

/**
 * One editable component of a `TimeField`.
 */
enum abstract TimeSegment(Int) {

    var Hour;
    var Minute;
    var Second;

    /** AM or PM, present with `HourCycle.H12`. */
    var Period;

    @:allow(glaze.kit.base)
    function name():String {
        return switch (cast this : TimeSegment) {
            case Hour: 'hour';
            case Minute: 'minute';
            case Second: 'second';
            case Period: 'period';
        }
    }

    /** The Rust `Debug` name. */
    public function toString():String {
        return switch (cast this : TimeSegment) {
            case Hour: 'Hour';
            case Minute: 'Minute';
            case Second: 'Second';
            case Period: 'Period';
        }
    }

}

/**
 * A semantic notification from a `TimeFieldState`.
 */
enum TimeFieldEvent {
    /** Keyboard editing changed the time. */
    Change(time:NaiveTime);
}

/**
 * The pure editing rules of a `TimeFieldState`, kept apart from focus so
 * they can be tested without a window.
 */
@:allow(glaze.kit.base)
@:allow(tests)
class SegmentEditor {

    var time:NaiveTime;
    var precision:TimePrecision;
    var hourCycle:HourCycle;
    var segment:TimeSegment;

    /** The first digit typed into the selected segment, awaiting a second. */
    var pendingDigit:Null<Int>;

    function new() {
        time = NaiveTime.MIN;
        precision = TimePrecision.defaultValue();
        hourCycle = HourCycle.defaultValue();
        segment = TimeSegment.Hour;
        pendingDigit = null;
    }

    /** A copy (Rust `Copy`). */
    function copy():SegmentEditor {
        final result = new SegmentEditor();
        result.time = time;
        result.precision = precision;
        result.hourCycle = hourCycle;
        result.segment = segment;
        result.pendingDigit = pendingDigit;
        return result;
    }

    static final MINUTE_H23:Array<TimeSegment> = [Hour, Minute];
    static final SECOND_H23:Array<TimeSegment> = [Hour, Minute, Second];
    static final MINUTE_H12:Array<TimeSegment> = [Hour, Minute, Period];
    static final SECOND_H12:Array<TimeSegment> = [Hour, Minute, Second, Period];

    /** The segments shown, in reading order. */
    function segments():Array<TimeSegment> {
        return switch [precision, hourCycle] {
            case [TimePrecision.Minute, H23]: MINUTE_H23;
            case [TimePrecision.Second, H23]: SECOND_H23;
            case [TimePrecision.Minute, H12]: MINUTE_H12;
            case [TimePrecision.Second, H12]: SECOND_H12;
        }
    }

    /** The inclusive range a segment's displayed value takes. */
    function bounds(segment:TimeSegment):{min:Int, max:Int} {
        return switch [segment, hourCycle] {
            case [Hour, H23]: {min: 0, max: 23};
            case [Hour, H12]: {min: 1, max: 12};
            case [Minute | Second, _]: {min: 0, max: 59};
            case [Period, _]: {min: 0, max: 1};
        }
    }

    /**
     * The displayed value of a segment: the hour follows the cycle, and the
     * period is `0` for AM and `1` for PM.
     */
    function value(segment:TimeSegment):Int {
        final hour = time.hour();
        return switch [segment, hourCycle] {
            case [Hour, H23]: hour;
            case [Hour, H12]: (hour + 11) % 12 + 1;
            case [Minute, _]: time.minute();
            case [Second, _]: time.second();
            case [Period, _]: Std.int(hour / 12);
        }
    }

    function label(segment:TimeSegment):String {
        if (segment == Period) {
            return value(segment) == 0 ? 'AM' : 'PM';
        }
        final v = value(segment);
        return v < 10 ? '0' + v : Std.string(v);
    }

    function withValue(segment:TimeSegment, value:Int):NaiveTime {
        final time = this.time;
        final pmOffset = Std.int(time.hour() / 12) * 12;
        final result:Null<NaiveTime> = switch [segment, hourCycle] {
            case [Hour, H23]: time.withHour(value);
            // 12 AM is midnight and 12 PM is noon.
            case [Hour, H12]: time.withHour(value % 12 + pmOffset);
            case [Minute, _]: time.withMinute(value);
            case [Second, _]: time.withSecond(value);
            case [Period, _]: time.withHour(time.hour() % 12 + value * 12);
        }
        return result != null ? result : time;
    }

    function setPrecision(precision:TimePrecision):Void {
        this.precision = precision;
        this.time = precision.truncate(this.time);
        resetSegment();
    }

    function setHourCycle(hourCycle:HourCycle):Void {
        this.hourCycle = hourCycle;
        resetSegment();
    }

    function resetSegment():Void {
        if (segments().indexOf(segment) == -1) {
            segment = Hour;
        }
        pendingDigit = null;
    }

    function setTime(time:NaiveTime):Bool {
        final time = precision.truncate(time);
        if (this.time == time) {
            // Keep a half-typed segment when the owner echoes the same value back.
            return false;
        }
        this.time = time;
        pendingDigit = null;
        return true;
    }

    function selectSegment(segment:TimeSegment):Bool {
        if (segments().indexOf(segment) == -1) {
            return false;
        }
        this.segment = segment;
        pendingDigit = null;
        return true;
    }

    /** Move the selected segment by `offset`; returns `false` at either end. */
    function moveSegment(offset:Int):Bool {
        final segments = this.segments();
        var ix = segments.indexOf(segment);
        if (ix == -1) ix = 0;
        final next = ix + offset;
        if (next < 0 || next >= segments.length) {
            return false;
        }
        return selectSegment(segments[next]);
    }

    /** Step the selected segment by `delta`, wrapping within the segment. */
    function step(delta:Int):Bool {
        pendingDigit = null;
        final b = bounds(segment);
        final span = b.max - b.min + 1;
        var v = (value(segment) - b.min + delta) % span;
        if (v < 0) v += span;
        return replaceSegment(v + b.min);
    }

    function inputDigit(digit:Int):Bool {
        if (segment == Period) {
            return false;
        }
        final b = bounds(segment);
        final first = pendingDigit;
        pendingDigit = null;
        var value:Int;
        var complete:Bool;
        if (first != null && first * 10 + digit >= b.min && first * 10 + digit <= b.max) {
            value = first * 10 + digit;
            complete = true;
        } else {
            // The two digits cannot form a valid value, so the new digit starts over.
            value = digit;
            complete = digit * 10 > b.max;
        }
        if (!complete) {
            pendingDigit = digit;
        }
        final changed = replaceSegment(value);
        if (complete) {
            moveSegment(1);
        }
        return changed;
    }

    /** Type `a` or `p` into the period segment. */
    function inputPeriod(pm:Bool):Bool {
        if (segment != Period) {
            return false;
        }
        return replaceSegment(pm ? 1 : 0);
    }

    /**
     * Reset the selected segment to its first value: zero, or `12` / AM on a
     * 12-hour clock.
     */
    function clearSegment():Bool {
        pendingDigit = null;
        return replaceSegment(0);
    }

    function replaceSegment(value:Int):Bool {
        final time = withValue(segment, value);
        final changed = time != this.time;
        this.time = time;
        return changed;
    }

}

/**
 * Retained editing behavior for a segmented time field.
 *
 * The field is one Tab stop. Inside it, one segment is selected at a time:
 * Up/Down step the selected segment and wrap within it (no carry into the
 * next unit), Left/Right and Tab/Shift-Tab move between segments, digits are
 * typed with a two-digit buffer that advances to the next segment once no
 * further digit could fit, `a`/`p` set the AM/PM segment, and
 * Backspace/Delete reset the segment.
 *
 * The owner supplies the value with `setTime`, which does not emit; user
 * edits emit `TimeFieldEvent.Change`.
 */
class TimeFieldState extends Model implements Render {

    @:allow(glaze.kit.base)
    static inline final CONTEXT:String = "TimeField";

    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new Increment(), CONTEXT),
            new KeyBinding("down", new Decrement(), CONTEXT),
            new KeyBinding("left", new SelectLeft(), CONTEXT),
            new KeyBinding("right", new SelectRight(), CONTEXT),
            new KeyBinding("tab", new SelectNextColumn(), CONTEXT),
            new KeyBinding("shift-tab", new SelectPrevColumn(), CONTEXT),
            new KeyBinding("backspace", new Delete(), CONTEXT),
            new KeyBinding("delete", new Delete(), CONTEXT),
        ]);
    }

    public final focusHandle:FocusHandle;

    /** The editor (Rust `Copy` value), replaced on every change so renders observe it. */
    @observe var editor:SegmentEditor = new SegmentEditor();

    public function new(window:Window, cx:Context<TimeFieldState>) {
        super();
        focusHandle = cx.focusHandle().tabStop(true);
    }

    function edited(edit:(SegmentEditor) -> Bool):Bool {
        final next = editor.copy();
        final result = edit(next);
        editor = next;
        return result;
    }

    /** Set the precision, default: `TimePrecision.Minute`. */
    public function precision(precision:TimePrecision):TimeFieldState {
        edited(e -> {
            e.setPrecision(precision);
            return true;
        });
        return this;
    }

    public function setPrecision(precision:TimePrecision, window:Window, cx:Context<TimeFieldState>):Void {
        if (editor.precision != precision) {
            edited(e -> {
                e.setPrecision(precision);
                return true;
            });
            cx.notify();
        }
    }

    /** Set the hour cycle, default: `HourCycle.H23`. */
    public function hourCycle(hourCycle:HourCycle):TimeFieldState {
        edited(e -> {
            e.setHourCycle(hourCycle);
            return true;
        });
        return this;
    }

    public function setHourCycle(hourCycle:HourCycle, window:Window, cx:Context<TimeFieldState>):Void {
        if (editor.hourCycle != hourCycle) {
            edited(e -> {
                e.setHourCycle(hourCycle);
                return true;
            });
            cx.notify();
        }
    }

    public function time():NaiveTime {
        return editor.time;
    }

    /** Replace the time without emitting `TimeFieldEvent.Change`. */
    public function setTime(time:NaiveTime, window:Window, cx:Context<TimeFieldState>):Void {
        if (editor.copy().setTime(time)) {
            edited(e -> e.setTime(time));
            cx.notify();
        }
    }

    /** The segment that keyboard editing applies to. */
    public function selectedSegment():TimeSegment {
        return editor.segment;
    }

    public function focus(window:Window, cx:App):Void {
        focusHandle.focus(window, cx);
    }

    function edit(cx:Context<TimeFieldState>, edit:(SegmentEditor) -> Bool):Void {
        if (edited(edit)) {
            cx.emit(TimeFieldEvent.Change(editor.time));
        }
        cx.notify();
    }

    function onIncrement(_:Increment, window:Window, cx:Context<TimeFieldState>):Void {
        edit(cx, editor -> editor.step(1));
    }

    function onDecrement(_:Decrement, window:Window, cx:Context<TimeFieldState>):Void {
        edit(cx, editor -> editor.step(-1));
    }

    function onDelete(_:Delete, window:Window, cx:Context<TimeFieldState>):Void {
        edit(cx, editor -> editor.clearSegment());
    }

    function onSelectLeft(_:SelectLeft, window:Window, cx:Context<TimeFieldState>):Void {
        edited(editor -> editor.moveSegment(-1));
        cx.notify();
    }

    function onSelectRight(_:SelectRight, window:Window, cx:Context<TimeFieldState>):Void {
        edited(editor -> editor.moveSegment(1));
        cx.notify();
    }

    // Tab walks the segments first and leaves the field only from the last one.
    function onNextColumn(_:SelectNextColumn, window:Window, cx:Context<TimeFieldState>):Void {
        if (editor.copy().moveSegment(1)) {
            edited(editor -> editor.moveSegment(1));
            cx.notify();
        } else {
            cx.propagate();
        }
    }

    function onPrevColumn(_:SelectPrevColumn, window:Window, cx:Context<TimeFieldState>):Void {
        if (editor.copy().moveSegment(-1)) {
            edited(editor -> editor.moveSegment(-1));
            cx.notify();
        } else {
            cx.propagate();
        }
    }

    function onKeyDown(event:KeyDownEvent, window:Window, cx:Context<TimeFieldState>):Void {
        final keystroke = event.keystroke;
        if (keystroke.modifiers.modified()) {
            return;
        }
        final chars = [for (c in new haxe.iterators.StringIteratorUnicode(keystroke.key)) c];
        if (chars.length != 1) {
            return;
        }
        final ch = chars[0];
        final edit:(SegmentEditor) -> Bool = if (ch >= '0'.code && ch <= '9'.code) {
            editor -> editor.inputDigit(ch - '0'.code);
        } else if (ch == 'a'.code || ch == 'A'.code) {
            editor -> editor.inputPeriod(false);
        } else if (ch == 'p'.code || ch == 'P'.code) {
            editor -> editor.inputPeriod(true);
        } else {
            return;
        }
        window.preventDefault();
        cx.stopPropagation();
        this.edit(cx, edit);
    }

    function selectSegment(segment:TimeSegment, cx:Context<TimeFieldState>):Void {
        edited(editor -> editor.selectSegment(segment));
        cx.notify();
    }

    @:allow(glaze.kit.base)
    function editorSnapshot():SegmentEditor {
        return editor;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new Empty();
    }

}

/**
 * State exposed to a `TimeField` segment slot for decoration.
 */
class TimeFieldSegmentState {

    final segmentValue:TimeSegment;
    final valueValue:Int;
    final selectedValue:Bool;
    final disabledValue:Bool;

    @:allow(glaze.kit.base)
    function new(segment:TimeSegment, value:Int, selected:Bool, disabled:Bool) {
        segmentValue = segment;
        valueValue = value;
        selectedValue = selected;
        disabledValue = disabled;
    }

    public inline function segment():TimeSegment {
        return segmentValue;
    }

    /**
     * The displayed value: the hour on the configured clock, the minute or
     * second, or `0` for AM and `1` for PM.
     */
    public inline function value():Int {
        return valueValue;
    }

    /**
     * Whether keyboard editing applies to this segment: it is the selected
     * segment and the field has focus.
     */
    public inline function isSelected():Bool {
        return selectedValue;
    }

    public inline function isDisabled():Bool {
        return disabledValue;
    }

}

/**
 * An unstyled, pre-wired segment passed to the `TimeField` segment slot.
 *
 * Listeners go to `base`.
 */
class TimeFieldSegment implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the segment renders. */
    public final base:Div;

    final segmentStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    @:allow(glaze.kit.base)
    function new(base:Div) {
        this.base = base;
    }

    /** Remove the default label so a styled facade can provide custom content. */
    public function clearChildren():TimeFieldSegment {
        childElements.resize(0);
        return this;
    }

    public inline function style():StyleRefinement {
        return segmentStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):TimeFieldSegment {
        base.onMouseDown(button, listener);
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):TimeFieldSegment {
        base.hover(f);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        base.extend(childElements);
        return base.refineStyle(segmentStyle);
    }

}

/**
 * Unstyled segmented time editor.
 *
 * Base owns focus, the keyboard model and pointer segment selection; the
 * presentation lays out and decorates the field with `Styled` and each
 * segment through `renderSegment`. A `:` separates the numeric segments;
 * the AM/PM segment follows without one.
 */
class TimeField implements RenderOnce implements Styled {

    final id:ElementIdArg;

    final state:Entity<TimeFieldState>;

    var disabledValue:Bool = false;

    final fieldStyle:StyleRefinement = new StyleRefinement();

    var segmentRenderer:(TimeFieldSegment, TimeFieldSegmentState, Window, App) -> AnyElement = (segment, _, _, _) -> (segment : IntoElement).intoAnyElement();

    /** The accessibility properties the field exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.TimeInput);

    public function new(id:ElementIdArg, state:Entity<TimeFieldState>) {
        this.id = id;
        this.state = state;
    }

    public function disabled(disabled:Bool):TimeField {
        disabledValue = disabled;
        return this;
    }

    /**
     * Decorate each segment. The segment already carries its label: two
     * digits, or `AM`/`PM`.
     */
    public function renderSegment(render:(TimeFieldSegment, TimeFieldSegmentState, Window, App) -> AnyElement):TimeField {
        segmentRenderer = render;
        return this;
    }

    public inline function style():StyleRefinement {
        return fieldStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final disabled = disabledValue;
        final state = this.state;
        final s = state.read(cx);
        final focusHandle = s.focusHandle;
        final focused = focusHandle.isFocused(window);
        final editor = s.editorSnapshot();
        final format = editor.precision.format(editor.hourCycle);

        a11y.value = editor.time.format(format);
        final root = div().id(id).trackFocus(focusHandle.clone().tabStop(!disabled));
        if (!disabled) {
            root.keyContext(TimeFieldState.CONTEXT)
                .onAction(Increment, (e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onIncrement(e, window, cx)))
                .onAction(Decrement, (e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onDecrement(e, window, cx)))
                .onAction(Delete, (e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onDelete(e, window, cx)))
                .onAction(SelectLeft, (e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onSelectLeft(e, window, cx)))
                .onAction(SelectRight, (e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onSelectRight(e, window, cx)))
                .onAction(SelectNextColumn, (e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onNextColumn(e, window, cx)))
                .onAction(SelectPrevColumn, (e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onPrevColumn(e, window, cx)))
                .onKeyDown((e, window, cx) -> state.update(cx, (s, cx) -> @:privateAccess s.onKeyDown(e, window, cx)))
                // A press on the field outside any segment focuses it and selects the
                // first segment; a press on a segment stops here and selects that one.
                .onMouseDown(Left, (_, window, cx) -> {
                    focusHandle.focus(window, cx);
                    state.update(cx, (s, cx) -> {
                        final first = s.editorSnapshot().segments()[0];
                        @:privateAccess s.selectSegment(first, cx);
                    });
                });
        }

        final segments = editor.segments();
        for (ix in 0...segments.length) {
            final segment = segments[ix];
            if (ix > 0 && segment != Period) {
                root.child(div().child(':'));
            }
            final segmentState = new TimeFieldSegmentState(segment, editor.value(segment), focused && segment == editor.segment, disabled);
            final item = new TimeFieldSegment(div().id(segment.name())).child(editor.label(segment));
            if (!disabled) {
                item.onMouseDown(Left, (_, window, cx) -> {
                    cx.stopPropagation();
                    focusHandle.focus(window, cx);
                    state.update(cx, (s, cx) -> @:privateAccess s.selectSegment(segment, cx));
                });
            }
            root.child(segmentRenderer(item, segmentState, window, cx));
        }

        a11y.disabled = disabled;
        return root.refineStyle(fieldStyle);
    }

}
