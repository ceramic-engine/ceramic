// Ported from gpui-kit 0.8.1: crates/base/src/calendar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-012 (the year page follows the current year). See docs/DEVIATIONS.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Context;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Empty;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.Render;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.chrono.Local;
import glaze.kit.base.chrono.NaiveDate;
import glaze.kit.base.chrono.Weekday;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A controlled calendar value (Rust `Date`, renamed: `Date` is Haxe's
 * standard date class).
 */
@:using(glaze.kit.base.Calendar.CalendarDateTools)
enum CalendarDate {
    Single(date:Null<NaiveDate>);
    Range(start:Null<NaiveDate>, end:Null<NaiveDate>);
}

/**
 * The methods of `CalendarDate` (Rust `impl Date`).
 */
class CalendarDateTools {

    /** `Date::from(NaiveDate)`. */
    public static inline function ofDate(value:NaiveDate):CalendarDate {
        return CalendarDate.Single(value);
    }

    /** `Date::from((NaiveDate, NaiveDate))`. */
    public static inline function ofRange(start:NaiveDate, end:NaiveDate):CalendarDate {
        return CalendarDate.Range(start, end);
    }

    /** Structural equality (Rust `PartialEq`). */
    public static function equals(self:CalendarDate, other:CalendarDate):Bool {
        return switch [self, other] {
            case [Single(a), Single(b)]: a == b;
            case [Range(a, b), Range(c, d)]: a == c && b == d;
            case _: false;
        }
    }

    public static function isSome(self:CalendarDate):Bool {
        return switch self {
            case Single(v): v != null;
            case Range(a, _): a != null;
        }
    }

    public static function isComplete(self:CalendarDate):Bool {
        return switch self {
            case Single(v): v != null;
            case Range(a, b): a != null && b != null;
        }
    }

    public static function start(self:CalendarDate):Null<NaiveDate> {
        return switch self {
            case Single(v): v;
            case Range(a, _): a;
        }
    }

    public static function end(self:CalendarDate):Null<NaiveDate> {
        return switch self {
            case Range(_, b): b;
            case _: null;
        }
    }

    public static function format(self:CalendarDate, format:String):Null<String> {
        return switch self {
            case Single(v) if (v != null): v.format(format);
            case Range(a, b) if (a != null && b != null): a.format(format) + ' - ' + b.format(format);
            case _: null;
        }
    }

    public static function isActive(self:CalendarDate, value:NaiveDate):Bool {
        return switch self {
            case Single(v): v != null && v == value;
            case Range(a, b): (a != null && a == value) || (b != null && b == value);
        }
    }

    public static function isSingle(self:CalendarDate):Bool {
        return self.match(Single(_));
    }

    public static function isInRange(self:CalendarDate, value:NaiveDate):Bool {
        return switch self {
            case Range(a, b) if (a != null && b != null): value >= a && value <= b;
            case _: false;
        }
    }

    /** Rust `Display`: `2024-08-03`, `nil`, `a - b`, `a - nil`, `nil - b`. */
    public static function toDisplayString(self:CalendarDate):String {
        return switch self {
            case Single(v) if (v != null): v.toString();
            case Single(_) | Range(null, null): 'nil';
            case Range(a, b) if (a != null && b != null): a.toString() + ' - ' + b.toString();
            case Range(a, _) if (a != null): a.toString() + ' - nil';
            case Range(_, b): 'nil - ' + b.toString();
        }
    }

}

/**
 * Which dates a calendar disables (Rust `Matcher`).
 *
 * `DayOfWeek` lists days from Sunday (0) to Saturday (6), `Interval`
 * matches the dates before `before` or after `after`, `Range` the dates
 * between `from` and `to` (both included, either side open when null).
 */
@:using(glaze.kit.base.Calendar.MatcherTools)
enum Matcher {
    DayOfWeek(days:Array<Int>);
    Interval(before:Null<NaiveDate>, after:Null<NaiveDate>);
    Range(from:Null<NaiveDate>, to:Null<NaiveDate>);
    Custom(f:(NaiveDate) -> Bool);
}

class MatcherTools {

    public static inline function interval(before:Null<NaiveDate>, after:Null<NaiveDate>):Matcher {
        return Matcher.Interval(before, after);
    }

    public static inline function range(from:Null<NaiveDate>, to:Null<NaiveDate>):Matcher {
        return Matcher.Range(from, to);
    }

    public static inline function custom(f:(NaiveDate) -> Bool):Matcher {
        return Matcher.Custom(f);
    }

    public static function isMatch(self:Matcher, date:CalendarDate):Bool {
        return switch date {
            case Single(v) if (v != null): matched(self, v);
            case Range(a, b) if (a != null && b != null): matched(self, a) || matched(self, b);
            case _: false;
        }
    }

    public static function matched(self:Matcher, date:NaiveDate):Bool {
        return switch self {
            case DayOfWeek(days): days.indexOf(date.weekday().numDaysFromSunday()) != -1;
            case Interval(before, after): (before != null && date < before) || (after != null && date > after);
            case Range(from, to): !(from != null && date < from) && !(to != null && date > to);
            case Custom(f): f(date);
        }
    }

}

enum abstract CalendarView(Int) {

    var Day;
    var Month;
    var Year;

    public inline function isDay():Bool {
        return (cast this : CalendarView) == CalendarView.Day;
    }

    public inline function isMonth():Bool {
        return (cast this : CalendarView) == CalendarView.Month;
    }

    public inline function isYear():Bool {
        return (cast this : CalendarView) == CalendarView.Year;
    }

}

enum CalendarEvent {
    Selected(date:CalendarDate);
}

/**
 * The calendar state: the controlled value, the visible month, the view
 * (days, months or years) and the disabled dates.
 *
 * "Today" is read once, from `glaze.kit.base.chrono.Local` (Rust
 * `Local::now().date_naive()`), whose clock tests and golden scenes fix.
 */
class CalendarState extends Model implements Render {

    public final focusHandle:FocusHandle;

    @observe var _view:CalendarView = CalendarView.Day;

    @observe var _date:CalendarDate = CalendarDate.Single(null);

    @observe var _currentYear:Int = 0;

    @observe var _currentMonth:Int = 0;

    @observe var years:Array<Array<Int>> = [];

    @observe var yearPage:Int = 0;

    final _today:NaiveDate;

    @observe var _numberOfMonths:Int = 1;

    @observe var disabledMatcherValue:Null<Matcher> = null;

    public function new(window:Window, cx:Context<CalendarState>) {
        super();
        final today = Local.today();
        focusHandle = cx.focusHandle();
        _today = today;
        _currentYear = today.year();
        _currentMonth = today.month();
        yearRange(today.year() - 50, today.year() + 50);
    }

    /** Builder: set the disabled dates. */
    public function disabledMatcher(matcher:Matcher):CalendarState {
        disabledMatcherValue = matcher;
        return this;
    }

    public function setDisabledMatcher(matcher:Matcher, window:Window, cx:Context<CalendarState>):Void {
        disabledMatcherValue = matcher;
    }

    public function setDisabledMatcherShared(matcher:Null<Matcher>):Void {
        disabledMatcherValue = matcher;
    }

    public function disabledMatcherRef():Null<Matcher> {
        return disabledMatcherValue;
    }

    public function setDate(date:CalendarDate, window:Window, cx:Context<CalendarState>):Void {
        if (applyDate(date)) {
            cx.notify();
        }
    }

    public function applyDate(date:CalendarDate):Bool {
        if (disabledMatcherValue != null && disabledMatcherValue.isMatch(date)) {
            return false;
        }
        _date = date;
        final v = date.start();
        if (v != null) {
            _currentMonth = v.month();
            _currentYear = v.year();
            syncYearPage(); // deviation DEV-012
        }
        return true;
    }

    public function selectDate(value:NaiveDate):Bool {
        if (disabledMatcherValue != null && disabledMatcherValue.matched(value)) {
            return false;
        }
        final next = switch _date {
            case Single(_): CalendarDate.Single(value);
            case Range(null, _): CalendarDate.Range(value, null);
            case Range(start, null) if (value >= start): CalendarDate.Range(start, value);
            case Range(_, _): CalendarDate.Range(value, null);
        }
        applyDate(next);
        return _date.isComplete();
    }

    /**
     * Activates a day item and emits `CalendarEvent.Selected` once the
     * controlled value is complete. This is the single pointer/keyboard
     * activation path used by the calendar root.
     */
    public function activateDate(value:NaiveDate, cx:Context<CalendarState>):Bool {
        final complete = selectDate(value);
        if (complete) {
            cx.emit(CalendarEvent.Selected(date()));
        }
        cx.notify();
        return complete;
    }

    public inline function date():CalendarDate {
        return _date;
    }

    /** Test access to the raw value (Rust tests write `state.date` directly). */
    @:allow(tests)
    function setRawDate(date:CalendarDate):Void {
        _date = date;
    }

    public function setNumberOfMonths(n:Int, window:Window, cx:Context<CalendarState>):Void {
        _numberOfMonths = n;
        cx.notify();
    }

    public inline function numberOfMonths():Int {
        return _numberOfMonths;
    }

    /** Builder: the half-open year range `start...end` of the year view. */
    public function yearRange(start:Int, end:Int):CalendarState {
        applyYearRange(start, end);
        return this;
    }

    public function setYearRange(start:Int, end:Int, cx:Context<CalendarState>):Void {
        applyYearRange(start, end);
        cx.notify();
    }

    @:allow(tests)
    function applyYearRange(start:Int, end:Int):Void {
        final all = [for (y in start...end) y];
        final chunks:Array<Array<Int>> = [];
        var i = 0;
        while (i < all.length) {
            chunks.push(all.slice(i, i + 20));
            i += 20;
        }
        years = chunks;
        syncYearPage(); // deviation DEV-012
    }

    /**
     * Deviation DEV-012: the year page is the one holding the current year,
     * kept in step wherever the current year changes (the original only
     * computed it when the year range was set).
     */
    function syncYearPage():Void {
        var page = 0;
        for (ix in 0...years.length) {
            if (years[ix].indexOf(_currentYear) != -1) {
                page = ix;
                break;
            }
        }
        yearPage = page;
    }

    /** The year and month `offset` months after the current one. */
    public function offsetYearMonth(offset:Int):{year:Int, month:Int} {
        final n = _currentMonth - 1 + offset;
        final div = Math.floor(n / 12);
        return {year: _currentYear + div, month: n - div * 12 + 1};
    }

    public function days():Array<Array<NaiveDate>> {
        final result = [];
        for (month in monthDays()) for (week in month) result.push(week);
        return result;
    }

    /**
     * Calendar weeks grouped by visible month. This preserves six-week
     * months and is the preferred rendering API.
     */
    public function monthDays():Array<Array<Array<NaiveDate>>> {
        return [for (n in 0..._numberOfMonths) Calendar.daysInMonth(_currentYear, _currentMonth + n, glaze.kit.base.chrono.Weekday.Sun)];
    }

    public function hasPrevYearPage():Bool {
        return yearPage > 0;
    }

    public function hasNextYearPage():Bool {
        return yearPage < years.length - 1;
    }

    public function prevYearPage():Bool {
        if (!hasPrevYearPage()) {
            return false;
        }
        yearPage -= 1;
        return true;
    }

    public function nextYearPage():Bool {
        if (!hasNextYearPage()) {
            return false;
        }
        yearPage += 1;
        return true;
    }

    public function prevMonth():Void {
        if (_currentMonth == 1) {
            _currentYear -= 1;
            _currentMonth = 12;
            syncYearPage(); // deviation DEV-012
        } else {
            _currentMonth -= 1;
        }
    }

    public function nextMonth():Void {
        if (_currentMonth == 12) {
            _currentYear += 1;
            _currentMonth = 1;
            syncYearPage(); // deviation DEV-012
        } else {
            _currentMonth += 1;
        }
    }

    public inline function view():CalendarView {
        return _view;
    }

    public function setView(view:CalendarView):Void {
        _view = view;
    }

    public inline function currentYear():Int {
        return _currentYear;
    }

    public inline function currentMonth():Int {
        return _currentMonth;
    }

    public inline function today():NaiveDate {
        return _today;
    }

    public function yearsOnPage():Array<Int> {
        final page = years[yearPage];
        return page != null ? page : [];
    }

    public function selectMonth(month:Int):Void {
        _currentMonth = month;
        _view = CalendarView.Day;
    }

    public function selectYear(year:Int):Void {
        _currentYear = year;
        syncYearPage(); // deviation DEV-012
        _view = CalendarView.Day;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new Empty();
    }

}

/**
 * The semantic kind of a calendar control rendered by `Calendar`.
 */
enum abstract CalendarItemKind(Int) {

    var Previous;
    var MonthToggle;
    var YearToggle;
    var Next;
    var Weekday;
    var Day;
    var Month;
    var Year;

    /** The Rust `Debug` name. */
    public function toString():String {
        return switch (cast this : CalendarItemKind) {
            case Previous: 'Previous';
            case MonthToggle: 'MonthToggle';
            case YearToggle: 'YearToggle';
            case Next: 'Next';
            case Weekday: 'Weekday';
            case Day: 'Day';
            case Month: 'Month';
            case Year: 'Year';
        }
    }

}

/**
 * State exposed to a calendar item slot. Applications may use it solely to
 * decorate the unstyled primitive; all interaction remains owned by base.
 *
 * Immutable: every setter returns a new state, like the Rust `Copy` builder.
 */
class CalendarItemState {

    final kindValue:CalendarItemKind;
    final activeValue:Bool;
    final inRangeValue:Bool;
    final mutedValue:Bool;
    final disabledValue:Bool;
    final todayValue:Bool;

    /** Create a state for `kind`, with every flag off. */
    public function new(kind:CalendarItemKind, active:Bool = false, inRange:Bool = false, muted:Bool = false, disabled:Bool = false, today:Bool = false) {
        kindValue = kind;
        activeValue = active;
        inRangeValue = inRange;
        mutedValue = muted;
        disabledValue = disabled;
        todayValue = today;
    }

    public function active(active:Bool):CalendarItemState {
        return new CalendarItemState(kindValue, active, inRangeValue, mutedValue, disabledValue, todayValue);
    }

    /** Set whether the item is between the two ends of a range selection. */
    public function inRange(inRange:Bool):CalendarItemState {
        return new CalendarItemState(kindValue, activeValue, inRange, mutedValue, disabledValue, todayValue);
    }

    /**
     * Set whether the item is shown as secondary, e.g.: a weekday header or a
     * day that belongs to the neighboring month.
     */
    public function muted(muted:Bool):CalendarItemState {
        return new CalendarItemState(kindValue, activeValue, inRangeValue, muted, disabledValue, todayValue);
    }

    public function disabled(disabled:Bool):CalendarItemState {
        return new CalendarItemState(kindValue, activeValue, inRangeValue, mutedValue, disabled, todayValue);
    }

    public function today(today:Bool):CalendarItemState {
        return new CalendarItemState(kindValue, activeValue, inRangeValue, mutedValue, disabledValue, today);
    }

    public inline function kind():CalendarItemKind {
        return kindValue;
    }

    public inline function isActive():Bool {
        return activeValue;
    }

    public inline function isInRange():Bool {
        return inRangeValue;
    }

    public inline function isMuted():Bool {
        return mutedValue;
    }

    public inline function isDisabled():Bool {
        return disabledValue;
    }

    public inline function isToday():Bool {
        return todayValue;
    }

}

/**
 * An unstyled, pre-wired calendar item passed to the item slot.
 *
 * Interactive styles and listeners go to `base` (see `glaze.kit.base.Button`).
 */
class CalendarItem extends Component implements Styled implements ParentElement {

    /** The stateful element the item renders. */
    public final base:Div;

    final state:CalendarItemState;

    final itemStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the item exports. */
    public final a11y:A11y = new A11y();

    @:allow(glaze.kit.base)
    function new(id:ElementIdArg, state:CalendarItemState) {
        super();
        this.base = div().id(id);
        this.state = state;
    }

    // Keep the default visible label available to assistive technology even
    // when a presentation assigns a role that does not derive a name from children.
    @:allow(glaze.kit.base)
    function withLabel(label:String):CalendarItem {
        a11y.label = label;
        childElements.push((label : IntoElement).intoAnyElement());
        return this;
    }

    /** Sets the name exposed to accessibility clients. */
    public function ariaLabel(label:String):CalendarItem {
        a11y.label = label;
        return this;
    }

    public inline function itemState():CalendarItemState {
        return state;
    }

    /** Remove the default label so a styled facade can provide custom content. */
    public function clearChildren():CalendarItem {
        childElements.resize(0);
        return this;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** A click listener (on `base`). */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):CalendarItem {
        a11y.clickable = true;
        base.onClick(listener);
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):CalendarItem {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):CalendarItem {
        base.active(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):CalendarItem {
        base.onMouseDown(button, listener);
        return this;
    }

    public function trackFocus(handle:FocusHandle):CalendarItem {
        base.trackFocus(handle);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        base.extend(childElements);
        return base.refineStyle(itemStyle);
    }

}

/**
 * Complete unstyled calendar structure and behavior.
 *
 * Base owns navigation, view switching, grids, disabled/selection state and
 * click handling. The UI crate only decorates the pre-wired item slot.
 */
class Calendar extends Component implements Styled {

    final id:ElementIdArg;

    final state:Entity<CalendarState>;

    @prop var numberOfMonths:Int = 1;

    @prop var firstDayOfWeek:Weekday = glaze.kit.base.chrono.Weekday.Sun;

    final calendarStyle:StyleRefinement = new StyleRefinement();

    @prop var item:(CalendarItem, CalendarItemState, Window, App) -> AnyElement = (item, _, _, _) -> (item : IntoElement).intoAnyElement();

    @prop var label:(CalendarItemKind, Int) -> String = (kind, value) -> switch kind {
        case CalendarItemKind.Previous: '‹';
        case CalendarItemKind.Next: '›';
        case CalendarItemKind.Weekday: Std.string(value);
        case _: Std.string(value);
    }

    public function new(id:ElementIdArg, state:Entity<CalendarState>) {
        super();
        this.id = id;
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return calendarStyle;
    }

    public function numberOfMonths(count:Int):Calendar {
        this.numberOfMonths = count < 1 ? 1 : count;
        return this;
    }

    function renderItem(id:ElementIdArg, state:CalendarItemState, value:Int, window:Window, cx:App):AnyElement {
        final label = this.label(state.kind(), value);
        return this.item(new CalendarItem(id, state).withLabel(label), state, window, cx);
    }

    public function render(window:Window, cx:App):IntoElement {
        final count = this.numberOfMonths;
        final entity = this.state;
        entity.update(cx, (s, cx) -> s.setNumberOfMonths(count, window, cx));
        final view = entity.read(cx).view();
        final header = hFlex().itemsCenter().justifyBetween();
        {
            final st = new CalendarItemState(CalendarItemKind.Previous).disabled(view.isMonth() || (view.isYear() && !entity.read(cx).hasPrevYearPage()));
            final item = new CalendarItem('calendar-prev', st).withLabel(this.label(st.kind(), 0));
            if (!st.isDisabled()) {
                item.onClick((_, _, cx) -> {
                    entity.update(cx, (s, cx) -> {
                        if (s.view().isDay()) {
                            s.prevMonth();
                        } else {
                            s.prevYearPage();
                        }
                        cx.notify();
                    });
                });
            }
            header.child(this.item(item, st, window, cx));
        }
        if (count == 1) {
            final s = entity.read(cx);
            final month = s.currentMonth();
            final year = s.currentYear();
            for (entry in [
                {kind: CalendarItemKind.MonthToggle, value: month, active: view.isMonth()},
                {kind: CalendarItemKind.YearToggle, value: year, active: view.isYear()},
            ]) {
                final kind = entry.kind;
                final st = new CalendarItemState(kind).active(entry.active);
                final item = new CalendarItem('calendar-' + kind.toString(), st).withLabel(this.label(kind, entry.value));
                item.onClick((_, _, cx) -> {
                    entity.update(cx, (s, cx) -> {
                        final target = kind == CalendarItemKind.MonthToggle ? CalendarView.Month : CalendarView.Year;
                        s.setView(s.view() == target ? CalendarView.Day : target);
                        cx.notify();
                    });
                });
                header.child(this.item(item, st, window, cx));
            }
        } else {
            for (offset in 0...count) {
                final ym = entity.read(cx).offsetYearMonth(offset);
                header.child(div().textSm().fontMedium().child(vFlex().itemsCenter().child(this.label(CalendarItemKind.MonthToggle, ym.month)).child(Std.string(ym.year))));
            }
        }
        {
            final st = new CalendarItemState(CalendarItemKind.Next).disabled(view.isMonth() || (view.isYear() && !entity.read(cx).hasNextYearPage()));
            final item = new CalendarItem('calendar-next', st).withLabel(this.label(st.kind(), 0));
            if (!st.isDisabled()) {
                item.onClick((_, _, cx) -> {
                    entity.update(cx, (s, cx) -> {
                        if (s.view().isDay()) {
                            s.nextMonth();
                        } else {
                            s.nextYearPage();
                        }
                        cx.notify();
                    });
                });
            }
            header.child(this.item(item, st, window, cx));
        }

        final layout = pickerGridLayout(view);
        final body = layout == null ? hFlex().justifyAround() : div().grid().gridCols(layout.columns).gapX(glaze.Prelude.px(layout.horizontalGap));
        if (view.isDay()) {
            for (offset in 0...count) {
                final ym = entity.read(cx).offsetYearMonth(offset);
                final weeks = daysInMonth(ym.year, ym.month, this.firstDayOfWeek);
                final month = vFlex();
                final headerRow = hFlex();
                for (weekday in 0...7) {
                    final st = new CalendarItemState(CalendarItemKind.Weekday).muted(true).disabled(true);
                    headerRow.child(renderItem('weekday-$offset-$weekday', st, (weekday + this.firstDayOfWeek.numDaysFromSunday()) % 7, window, cx));
                }
                month.child(headerRow);
                for (weekIndex in 0...weeks.length) {
                    final week = weeks[weekIndex];
                    final weekRow = hFlex();
                    for (date in week) {
                        final s = entity.read(cx);
                        final m = s.offsetYearMonth(offset).month;
                        final matcher = s.disabledMatcherRef();
                        final disabled = matcher != null && matcher.matched(date);
                        final st = new CalendarItemState(CalendarItemKind.Day)
                            .active(s.date().isActive(date))
                            .inRange(s.date().isInRange(date))
                            .muted(date.month() != m || disabled)
                            .disabled(disabled)
                            .today(date == s.today());
                        final item = new CalendarItem('calendar-' + date.toString() + '-$offset-$weekIndex', st)
                            .withLabel(this.label(st.kind(), date.day()))
                            .ariaLabel(date.toString());
                        if (!st.isDisabled()) {
                            item.onClick((_, _, cx) -> {
                                entity.update(cx, (s, cx) -> {
                                    s.activateDate(date, cx);
                                });
                            });
                        }
                        weekRow.child(this.item(item, st, window, cx));
                    }
                    month.child(weekRow);
                }
                body.child(month);
            }
        } else if (view.isMonth()) {
            final current = entity.read(cx).currentMonth();
            for (month in 1...13) {
                final st = new CalendarItemState(CalendarItemKind.Month).active(month == current);
                final item = new CalendarItem('calendar-month-$month', st)
                    .withLabel(this.label(st.kind(), month))
                    .onClick((_, _, cx) -> {
                        entity.update(cx, (s, cx) -> {
                            s.selectMonth(month);
                            cx.notify();
                        });
                    });
                body.child(this.item(item, st, window, cx));
            }
        } else {
            final current = entity.read(cx).currentYear();
            final years = entity.read(cx).yearsOnPage().copy();
            for (year in years) {
                final st = new CalendarItemState(CalendarItemKind.Year).active(year == current);
                final item = new CalendarItem('calendar-year-$year', st)
                    .withLabel(this.label(st.kind(), year))
                    .onClick((_, _, cx) -> {
                        entity.update(cx, (s, cx) -> {
                            s.selectYear(year);
                            cx.notify();
                        });
                    });
                body.child(this.item(item, st, window, cx));
            }
        }
        return vFlex()
            .id(id)
            .trackFocus(entity.read(cx).focusHandle)
            .child(header)
            .child(body)
            .refineStyle(calendarStyle);
    }

    @:allow(tests)
    static function pickerGridLayout(view:CalendarView):Null<{columns:Int, horizontalGap:Float}> {
        return switch view {
            case CalendarView.Day: null;
            case CalendarView.Month: {columns: 3, horizontalGap: 4.};
            case CalendarView.Year: {columns: 5, horizontalGap: 4.};
        }
    }

    @:allow(glaze.kit.base)
    @:allow(tests)
    static function daysInMonth(year:Int, month:Int, firstDay:Weekday):Array<Array<NaiveDate>> {
        final total = year * 12 + month - 1;
        final y = Math.floor(total / 12);
        final m = total - y * 12 + 1;
        final first = NaiveDate.fromYmd(y, m, 1);
        final next = m == 12 ? NaiveDate.fromYmd(y + 1, 1, 1) : NaiveDate.fromYmd(y, m + 1, 1);
        final offset = (first.weekday().numDaysFromSunday() + 7 - firstDay.numDaysFromSunday()) % 7;
        final start = first.addDays(-offset);
        final count = Std.int((next.numDaysSince(start) + 6) / 7) * 7;
        final weeks:Array<Array<NaiveDate>> = [];
        for (n in 0...count) {
            if (n % 7 == 0) weeks.push([]);
            weeks[weeks.length - 1].push(start.addDays(n));
        }
        return weeks;
    }

}
