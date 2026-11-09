// Ported from gpui-kit 0.8.1: crates/component/src/time/date_picker.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.time;

import glaze.App;
import glaze.AppContext;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Context;
import glaze.ElementId;
import glaze.Empty;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Model;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Calendar.CalendarDate;
import glaze.kit.base.Calendar.CalendarEvent;
import glaze.kit.base.Calendar.CalendarState;
import glaze.kit.base.Calendar.Matcher;
import glaze.kit.base.ComponentTraits.Disableable;
import glaze.kit.base.ComponentTraits.FocusableExt;
import glaze.kit.base.TimeField.HourCycle;
import glaze.kit.base.TimeField.TimeFieldEvent;
import glaze.kit.base.TimeField.TimeFieldState;
import glaze.kit.base.TimeField.TimePrecision;
import glaze.kit.base.chrono.NaiveDate;
import glaze.kit.base.chrono.NaiveDateTime;
import glaze.kit.base.chrono.NaiveTime;
import glaze.kit.base.chrono.Weekday;
import glaze.kit.base.input.InputActions.Delete;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.input.ClearButton;
import glaze.kit.input.Input;
import glaze.kit.popover.Popover;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.Calendar.CalendarDateTools;
using glaze.kit.base.ElementExt;
using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;

/**
 * Events emitted by the DatePicker.
 */
enum DatePickerEvent {
    /**
     * The user changed the value. With a time precision set, this is emitted
     * on every edit while the popup stays open.
     */
    Change(value:DateTime);
}

/**
 * The value of a `DatePicker`: the selected date or dates combined with
 * their times of day.
 *
 * When the picker has no time precision, every time is the picker's
 * `DatePickerState.defaultTime`, `00:00` unless configured.
 */
@:using(glaze.kit.time.DatePicker.DateTimeTools)
enum DateTime {
    Single(value:Null<NaiveDateTime>);
    Range(start:Null<NaiveDateTime>, end:Null<NaiveDateTime>);
}

class DateTimeTools {

    /** `DateTime::from(NaiveDateTime)`. */
    public static inline function ofDateTime(value:NaiveDateTime):DateTime {
        return DateTime.Single(value);
    }

    /** `DateTime::from((NaiveDateTime, NaiveDateTime))`. */
    public static inline function ofRange(start:NaiveDateTime, end:NaiveDateTime):DateTime {
        return DateTime.Range(start, end);
    }

    /** Structural equality (Rust `PartialEq`). */
    public static function equals(self:DateTime, other:DateTime):Bool {
        return switch [self, other] {
            case [Single(a), Single(b)]: a == b;
            case [Range(a, b), Range(c, d)]: a == c && b == d;
            case _: false;
        }
    }

    public static function isSome(self:DateTime):Bool {
        return date(self).isSome();
    }

    public static function isComplete(self:DateTime):Bool {
        return date(self).isComplete();
    }

    public static function start(self:DateTime):Null<NaiveDateTime> {
        return switch self {
            case Single(v) | Range(v, _): v;
        }
    }

    public static function end(self:DateTime):Null<NaiveDateTime> {
        return switch self {
            case Range(_, v): v;
            case Single(_): null;
        }
    }

    /** The date part of this value. */
    public static function date(self:DateTime):CalendarDate {
        return switch self {
            case Single(v): CalendarDate.Single(v != null ? v.date() : null);
            case Range(a, b): CalendarDate.Range(a != null ? a.date() : null, b != null ? b.date() : null);
        }
    }

    /** Format a complete value, joining a range with ` - `. */
    public static function format(self:DateTime, format:String):Null<String> {
        return switch self {
            case Single(v) if (v != null): v.format(format);
            case Range(a, b) if (a != null && b != null): a.format(format) + ' - ' + b.format(format);
            case _: null;
        }
    }

}

/** Preset value for DateRangePreset. */
enum DateRangePresetValue {
    Single(date:NaiveDate);
    Range(start:NaiveDate, end:NaiveDate);
    DateTimeValue(value:DateTime);
}

/**
 * Preset for date range selection.
 */
class DateRangePreset {

    @:allow(glaze.kit.time)
    final label:String;

    @:allow(glaze.kit.time)
    final value:DateRangePresetValue;

    function new(label:String, value:DateRangePresetValue) {
        this.label = label;
        this.value = value;
    }

    /** Creates a new DateRangePreset with a date. */
    public static function single(label:String, date:NaiveDate):DateRangePreset {
        return new DateRangePreset(label, DateRangePresetValue.Single(date));
    }

    /** Creates a new DateRangePreset with a range of dates. */
    public static function range(label:String, start:NaiveDate, end:NaiveDate):DateRangePreset {
        return new DateRangePreset(label, DateRangePresetValue.Range(start, end));
    }

    /**
     * Creates a new DateRangePreset with a date and time, or a range of them.
     *
     * Times are kept as given, even though a range picker edits dates only.
     */
    public static function dateTime(label:String, value:DateTime):DateRangePreset {
        return new DateRangePreset(label, DateRangePresetValue.DateTimeValue(value));
    }

}

/**
 * Use to store the state of the date picker.
 */
class DatePickerState extends Model implements Render {

    static inline final CONTEXT:String = "DatePicker";

    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("enter", new Confirm(false), CONTEXT),
            new KeyBinding("escape", new Cancel(), CONTEXT),
            new KeyBinding("delete", new Delete(), CONTEXT),
            new KeyBinding("backspace", new Delete(), CONTEXT),
        ]);
    }

    public final focusHandle:FocusHandle;

    @observe var _date:CalendarDate;

    @observe var open:Bool = false;

    @:allow(glaze.kit.time)
    final calendar:Entity<CalendarState>;

    @observe var dateFormatValue:Null<String> = null;

    var numberOfMonthsValue:Int = 1;

    var disabledMatcherValue:Null<Matcher> = null;

    /** `null` edits dates only. */
    @observe var timePrecisionValue:Null<TimePrecision> = null;

    @observe var hourCycleValue:HourCycle = HourCycle.defaultValue();

    @observe var defaultTimeValue:NaiveTime = NaiveTime.MIN;

    @observe var startTime:NaiveTime = NaiveTime.MIN;

    /**
     * The time of a range's end. Only `setDateTime` sets it, since a range
     * picker edits dates only.
     */
    @observe var endTime:NaiveTime = NaiveTime.MIN;

    @:allow(glaze.kit.time)
    final timeField:Entity<TimeFieldState>;

    var timeFieldPushed:Bool = false;

    final _subscriptions:Array<Subscription>;

    /** The first day of the week. Defaults to Sunday. */
    @:allow(glaze.kit.time)
    var firstDayOfWeekValue:Weekday = Weekday.Sun;

    @:allow(glaze.kit.time)
    var bounds:Bounds = new Bounds();


    /**
     * Create a date state (Rust `DatePickerState::new`), or a range state
     * when `isRange` (Rust `new_with_range`; see also `range`).
     */
    public function new(window:Window, cx:Context<DatePickerState>, isRange:Bool = false) {
        super();
        final date = isRange ? CalendarDate.Range(null, null) : CalendarDate.Single(null);

        final calendar = cx.newEntity((cx:Context<CalendarState>) -> {
            final calendar = new CalendarState(window, cx);
            calendar.setDate(date, window, cx);
            return calendar;
        });
        final timeField = cx.newEntity((cx:Context<TimeFieldState>) -> new TimeFieldState(window, cx));

        _subscriptions = [
            cx.subscribeIn(calendar, CalendarEvent, window, (this_, _, ev, window, cx) -> {
                switch ev {
                    case Selected(date):
                        this_.selectDate(date, window, cx);
                }
            }),
            cx.subscribeIn(timeField, TimeFieldEvent, window, (this_, _, ev, _, cx) -> {
                switch ev {
                    case Change(time):
                        this_.startTime = time;
                        this_.emitChange(cx);
                }
            }),
        ];

        focusHandle = cx.focusHandle();
        _date = date;
        this.calendar = calendar;
        this.timeField = timeField;
    }

    /** Create a date state with range mode. */
    public static function range(window:Window, cx:Context<DatePickerState>):DatePickerState {
        return new DatePickerState(window, cx, true);
    }

    /**
     * Set the format of the value displayed in the picker.
     *
     * Default: `%Y/%m/%d`, followed by the time in the configured precision
     * and hour cycle when the picker edits times, e.g. `%H:%M` or `%I:%M %p`.
     */
    public function dateFormat(format:String):DatePickerState {
        dateFormatValue = format;
        return this;
    }

    /**
     * Edit the time of day as well as the date, down to `precision`.
     *
     * Selecting a date then keeps the popup open, and every change to the
     * date or time is reported as it happens. Clicking the selected date
     * again closes the popup.
     *
     * A range picker edits dates only; for a range with times, place two
     * single pickers side by side.
     */
    public function timePrecision(precision:TimePrecision):DatePickerState {
        timePrecisionValue = precision;
        defaultTimeValue = precision.truncate(defaultTimeValue);
        startTime = precision.truncate(startTime);
        endTime = precision.truncate(endTime);
        timeFieldPushed = false;
        return this;
    }

    /** Set how the time field counts hours, default: `HourCycle.H23`. */
    public function hourCycle(hourCycle:HourCycle):DatePickerState {
        hourCycleValue = hourCycle;
        timeFieldPushed = false;
        return this;
    }

    /** Set the time given to a date before the user edits it, default: `00:00`. */
    public function defaultTime(time:NaiveTime):DatePickerState {
        final time = truncateTime(time);
        defaultTimeValue = time;
        startTime = time;
        endTime = time;
        timeFieldPushed = false;
        return this;
    }

    /** Set the number of months calendar view to display, default is 1. */
    public function numberOfMonths(numberOfMonths:Int):DatePickerState {
        numberOfMonthsValue = numberOfMonths;
        return this;
    }

    /** Set the first day of the week. */
    public function firstDayOfWeek(day:Weekday):DatePickerState {
        firstDayOfWeekValue = day;
        return this;
    }

    /** Get the date part of the value. */
    public inline function date():CalendarDate {
        return _date;
    }

    /** Get the value, combining the date with its time of day. */
    public function dateTime():DateTime {
        return switch _date {
            case Single(date): DateTime.Single(date != null ? date.andTime(startTime) : null);
            case Range(start, end): DateTime.Range(start != null ? start.andTime(startTime) : null, end != null ? end.andTime(endTime) : null);
        }
    }

    /** Set the date, keeping the current time of day. */
    public function setDate(date:CalendarDate, window:Window, cx:Context<DatePickerState>):Void {
        updateDate(date, false, window, cx);
    }

    /** Set the date and the time of day. */
    public function setDateTime(value:DateTime, window:Window, cx:Context<DatePickerState>):Void {
        final startValue = value.start();
        final start = startValue != null ? startValue.time() : defaultTimeValue;
        final endValue = value.end();
        final end = endValue != null ? endValue.time() : start;
        setTimes(start, end, window, cx);
        updateDate(value.date(), false, window, cx);
    }

    /** Set the disabled match for the calendar. */
    public function disabledMatcher(disabled:Matcher):DatePickerState {
        disabledMatcherValue = disabled;
        return this;
    }

    /**
     * Set the year range for the internal calendar.
     *
     * Default is 50 years before and after the current year.
     * The range is half-open: `end` is exclusive.
     */
    public function setYearRange(start:Int, end:Int, cx:Context<DatePickerState>):Void {
        calendar.update(cx, (state, cx) -> {
            state.setYearRange(start, end, cx);
        });
    }

    /** The precision the popup edits times at, or `null` when it edits dates only. */
    @:allow(glaze.kit.time)
    function editedTimePrecision():Null<TimePrecision> {
        return _date.isSingle() ? timePrecisionValue : null;
    }

    function truncateTime(time:NaiveTime):NaiveTime {
        return timePrecisionValue != null ? timePrecisionValue.truncate(time) : time;
    }

    function setTimes(start:NaiveTime, end:NaiveTime, window:Window, cx:Context<DatePickerState>):Void {
        startTime = truncateTime(start);
        endTime = truncateTime(end);
        pushTimeField(window, cx);
    }

    /**
     * Push the configuration and the time into the time field.
     *
     * User edits flow the other way, through the field subscription, so this
     * runs only when the picker's own time changes. Pushing on every render
     * could overwrite an edit whose event has not been delivered yet.
     */
    function pushTimeField(window:Window, cx:Context<DatePickerState>):Void {
        final precision = timePrecisionValue != null ? timePrecisionValue : TimePrecision.defaultValue();
        final hourCycle = hourCycleValue;
        final time = startTime;
        timeField.update(cx, (field, cx) -> {
            field.setPrecision(precision, window, cx);
            field.setHourCycle(hourCycle, window, cx);
            field.setTime(time, window, cx);
        });
        timeFieldPushed = true;
    }

    function emitChange(cx:Context<DatePickerState>):Void {
        if (_date.isComplete()) {
            cx.emit(DatePickerEvent.Change(dateTime()));
        }
        cx.notify();
    }

    function selectDate(date:CalendarDate, window:Window, cx:Context<DatePickerState>):Void {
        if (editedTimePrecision() != null) {
            if (date.equals(_date)) {
                // Clicking the selected day again confirms it, so picking a
                // date and closing is a double-click.
                setOpen(false, window, cx);
                return;
            }
            // Keep the popup open so the time can be adjusted next.
            _date = date;
            emitChange(cx);
        } else {
            updateDate(date, true, window, cx);
            focusHandle.focus(window, cx.app);
        }
    }

    function updateDate(date:CalendarDate, emit:Bool, window:Window, cx:Context<DatePickerState>):Void {
        _date = date;
        calendar.update(cx, (view, cx) -> {
            view.setDate(date, window, cx);
        });
        open = false;
        if (emit) {
            cx.emit(DatePickerEvent.Change(dateTime()));
        }
        cx.notify();
    }

    /** Sync the builder configuration into the child states before they render. */
    @:allow(glaze.kit.time)
    function syncChildren(window:Window, cx:Context<DatePickerState>):Void {
        final matcher = disabledMatcherValue;
        calendar.update(cx, (state, _) -> {
            state.setDisabledMatcherShared(matcher);
        });
        // Builders cannot reach the field, so apply them before the first render.
        if (!timeFieldPushed) {
            pushTimeField(window, cx);
        }
    }

    @:allow(glaze.kit.time)
    function setOpen(open:Bool, window:Window, cx:Context<DatePickerState>):Void {
        if (!open) {
            focusBackIfNeed(window, cx);
        }
        this.open = open;
        cx.notify();
    }

    /** Whether the popup is open. */
    public inline function isOpen():Bool {
        return open;
    }

    @:allow(glaze.kit.time)
    function onEscape(_:Cancel, window:Window, cx:Context<DatePickerState>):Void {
        if (!open) {
            cx.propagate();
        }
        setOpen(false, window, cx);
    }

    @:allow(glaze.kit.time)
    function onDelete(_:Delete, window:Window, cx:Context<DatePickerState>):Void {
        clean(null, window, cx);
    }

    // To focus the Picker Input, if current focus in is on the container, or
    // inside the popup (e.g.: the time field).
    //
    // This is because mouse down out the Calendar, GPUI will move focus to the container.
    // So we need to move focus back to the Picker Input.
    //
    // But if mouse down target is some other focusable element (e.g.: `Input`), we should not move focus.
    function focusBackIfNeed(window:Window, cx:Context<DatePickerState>):Void {
        if (!open) {
            return;
        }

        final focused = window.focused(cx.app);
        if (focused != null) {
            if (focused.contains(focusHandle, window) || focusHandle.containsFocused(window, cx.app)) {
                focusHandle.focus(window, cx.app);
            }
        }
    }

    @:allow(glaze.kit.time)
    function clean(_:Null<ClickEvent>, window:Window, cx:Context<DatePickerState>):Void {
        cx.stopPropagation();
        final defaultTime = defaultTimeValue;
        setTimes(defaultTime, defaultTime, window, cx);
        switch _date {
            case Single(_):
                updateDate(CalendarDate.Single(null), true, window, cx);
            case Range(_, _):
                updateDate(CalendarDate.Range(null, null), true, window, cx);
        }
    }

    @:allow(glaze.kit.time)
    function toggleCalendar(_:ClickEvent, window:Window, cx:Context<DatePickerState>):Void {
        final open = !this.open;
        setOpen(open, window, cx);
    }

    @:allow(glaze.kit.time)
    function selectPreset(preset:DateRangePreset, window:Window, cx:Context<DatePickerState>):Void {
        switch preset.value {
            case Single(single):
                updateDate(CalendarDate.Single(single), true, window, cx);
            case Range(start, end):
                updateDate(CalendarDate.Range(start, end), true, window, cx);
            case DateTimeValue(value):
                setDateTime(value, window, cx);
                cx.emit(DatePickerEvent.Change(dateTime()));
        }
        focusHandle.focus(window, cx.app);
    }

    @:allow(glaze.kit.time)
    function displayFormat():String {
        if (dateFormatValue != null) {
            return dateFormatValue;
        }
        final precision = editedTimePrecision();
        return precision != null ? '%Y/%m/%d ' + precision.format(hourCycleValue) : '%Y/%m/%d';
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new Empty();
    }

}

/**
 * A DatePicker element.
 */
class DatePicker extends Component implements Styled implements Sizable implements Disableable implements FocusableExt {

    final id:ElementId;

    final pickerStyle:StyleRefinement = new StyleRefinement();

    final state:Entity<DatePickerState>;

    /** Set whether to show the clear button when the input field is not empty, default is false. */
    @prop var cleanable:Bool = false;

    /** Set the placeholder of the date picker, default: "". */
    @prop var placeholder:Null<String> = null;

    var size:Size = Medium;

    /** Set number of months to display in the calendar, default is 1. */
    @prop var numberOfMonths:Int = 1;

    /** Set preset ranges for the date picker. */
    @prop var presets:Null<Array<DateRangePreset>> = null;

    /** Set appearance of the date picker, if false, the date picker will be in a minimal style. */
    @prop var appearance:Bool = true;

    @prop var focusRing:Bool = true;

    @prop var disabled:Bool = false;

    static inline final CONTEXT:String = "DatePicker";

    /** Create a new DatePicker with the given `DatePickerState`. */
    public function new(state:Entity<DatePickerState>) {
        super();
        this.id = ElementId.NamedInteger('date-picker', state.entityId());
        this.state = state;
    }

    /** The picker's focus handle (Rust `Focusable`). */
    public function focusHandle(cx:App):FocusHandle {
        return state.read(cx).focusHandle;
    }

    public function withSize(size:IntoSize):DatePicker {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public function setDisabled(disabled:Bool):Void {
        this.disabled = disabled;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRing = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRing;
    }

    public inline function style():StyleRefinement {
        return pickerStyle;
    }

    static function renderTimeField(size:Size, state:DatePickerState, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final row = hFlex();
        switch size {
            case Small: row.mt2().pt2();
            case _: row.mt3().pt3();
        }
        final label = div();
        switch size {
            case Small: label.textXs();
            case _: label.textSm();
        }
        return row.gap3()
            .justifyBetween()
            .borderT1()
            .borderColor(theme.border)
            .child(label.textColor(theme.mutedForeground).child(I18n.t('DatePicker.time')))
            .child(TimeField.component(state.timeField).withId('time').withSize(size));
    }

    public function render(window:Window, cx:App):IntoElement {
        final pickerState = this.state;
        pickerState.update(cx, (state, cx) -> {
            state.syncChildren(window, cx);
        });
        final monthCount = numberOfMonths < 1 ? 1 : numberOfMonths;
        final theme = Theme.global(cx);

        // This for keep focus border style, when click on the popup.
        final isFocused = focusHandle(cx).containsFocused(window, cx);
        final state = pickerState.read(cx);
        final showClean = cleanable && state.date().isSome();
        final placeholder = this.placeholder != null ? this.placeholder : I18n.t('DatePicker.placeholder');
        final formatted = state.dateTime().format(state.displayFormat());
        final displayTitle = formatted != null ? formatted : placeholder;

        final colors = @:privateAccess Input.inputStyleColors(disabled, cx);

        final picker = glaze.kit.base.DatePicker.component(id, state.focusHandle).open(state.isOpen());
        if (state.date().isSome()) picker.ariaValue(displayTitle);
        picker.disabled(disabled)
            .onOpenChange((open, window, cx) -> {
                pickerState.update(cx, (state, cx) -> state.setOpen(open, window, cx));
            })
            .keyContext(CONTEXT)
            .onAction(Delete, (e, window, cx) -> pickerState.update(cx, (s, cx) -> s.onDelete(e, window, cx)))
            .flexNone()
            .wFull()
            .relative()
            .onPrepaint((bounds, _, cx) -> pickerState.update(cx, (state, _) -> state.bounds = bounds))
            .inputTextSize(size)
            .refineStyle(pickerStyle);

        final input = div()
            .id('date-picker-input')
            .relative()
            .flex()
            .itemsCenter()
            .justifyBetween();
        if (appearance) {
            input.bg(colors.background).textColor(colors.foreground);
            if (disabled) input.opacity(0.5);
            input.border1().borderColor(theme.input).rounded(theme.radius);
            if (isFocused) input.border1().borderColor(theme.ring);
        }
        if (isFocused && appearance && !disabled && focusRing) {
            input.focusRingStyle(window, cx);
        }
        input.inputTextSize(size).inputSize(size);
        if (!state.isOpen() && !disabled) {
            input.onClick((e, window, cx) -> pickerState.update(cx, (s, cx) -> s.toggleCalendar(e, window, cx)));
        }
        final title = div()
            .flex1()
            .minW0()
            .overflowHidden()
            .whitespaceNowrap()
            .truncate();
        // The value updates live while its time is typed.
        if (state.editedTimePrecision() != null) {
            @:privateAccess TimeField.fontFeatures(title, @:privateAccess TimeField.tabularFigures());
        }
        if (!state.date().isSome()) {
            title.textColor(theme.mutedForeground);
        }
        title.child(displayTitle);
        final row = hFlex()
            .wFull()
            .minW0()
            .overflowHidden()
            .whitespaceNowrap()
            .itemsCenter()
            .justifyBetween()
            .gap1()
            .child(title);
        if (!disabled) {
            if (showClean) {
                row.child(@:privateAccess ClearButton.clearButton(cx).onClick((e, window, cx) -> pickerState.update(cx, (s, cx) -> s.clean(e, window, cx))));
            }
            if (!showClean) {
                row.child(Icon.component(IconName.Calendar).xsmall().textColor(theme.mutedForeground));
            }
        }
        input.child(row);
        picker.child(input);

        if (state.isOpen()) {
            final content = hFlex()
                .gap3()
                .hFull()
                .itemsStart();
            if (this.presets != null) {
                final presets = this.presets;
                content.child(vFlex().my1().gap2().justifyEnd().children([
                    for (i in 0...presets.length) {
                        final preset = presets[i];
                        (Button.component(ElementId.NamedInteger('preset', i))
                            .small()
                            .ghost()
                            .tabStop(false)
                            .label(preset.label)
                            .onClick((_, window, cx) -> pickerState.update(cx, (this_, cx) -> {
                                this_.selectPreset(preset, window, cx);
                            })) : IntoElement);
                    }
                ]));
            }
            final calendar = Calendar.component(state.calendar)
                .numberOfMonths(numberOfMonths)
                .firstDayOfWeek(state.firstDayOfWeekValue)
                .border0()
                .roundedNone()
                .p0();
            switch size {
                case Small: calendar.w(glaze.Prelude.px(196. * monthCount));
                case Large: calendar.w(glaze.Prelude.px(280. * monthCount));
                case _: calendar.w(glaze.Prelude.px(224. * monthCount));
            }
            calendar.withSize(size);
            final column = vFlex().child(calendar);
            if (state.editedTimePrecision() != null) {
                column.child(renderTimeField(size, state, cx));
            }
            content.child(column);
            final surface = div()
                .occlude()
                .p3()
                .popoverStyle(cx)
                .onMouseUpOut(Left, (_, window, cx) -> pickerState.update(cx, (view, cx) -> {
                    view.onEscape(new Cancel(), window, cx);
                }))
                .child(content);
            picker.child(deferred(Popover.dropdownPopup(
                ElementId.NamedInteger('date-picker-popup', pickerState.entityId()),
                state.bounds,
                surface,
                cx
            )).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY));
        }
        return picker;
    }

}
