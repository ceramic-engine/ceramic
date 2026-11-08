// Ported from gpui-kit 0.8.1: crates/base/src/{calendar,time_field,date_picker}.rs (tests),
// crates/component/src/time/{calendar,time_field,utils}.rs (tests), and the flows of
// crates/kit/tests/integration/date_picker.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Calendar;
import glaze.kit.base.Calendar.CalendarDate;
import glaze.kit.base.Calendar.CalendarEvent;
import glaze.kit.base.Calendar.CalendarItemKind;
import glaze.kit.base.Calendar.CalendarState;
import glaze.kit.base.Calendar.CalendarView;
import glaze.kit.base.Calendar.Matcher;
import glaze.kit.base.TimeField.HourCycle;
import glaze.kit.base.TimeField.SegmentEditor;
import glaze.kit.base.TimeField.TimeFieldState;
import glaze.kit.base.TimeField.TimePrecision;
import glaze.kit.base.TimeField.TimeSegment;
import glaze.kit.base.chrono.Local;
import glaze.kit.base.chrono.NaiveDate;
import glaze.kit.base.chrono.NaiveDateTime;
import glaze.kit.base.chrono.NaiveTime;
import glaze.kit.base.chrono.Weekday;
import glaze.kit.time.DatePicker.DatePickerEvent;
import glaze.kit.time.DatePicker.DatePickerState;
import glaze.kit.time.DatePicker.DateRangePreset;
import glaze.kit.time.DatePicker.DateTime;
import glaze.kit.time.TimeField;
import glaze.kit.time.TimeUtils;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.Calendar.CalendarDateTools;
using glaze.kit.base.Calendar.MatcherTools;
using glaze.kit.time.DatePicker.DateTimeTools;

/**
 * The `#[cfg(test)]` tests of the time components (calendar, time field,
 * date picker) and the flows of gpui-kit's date picker integration tests,
 * driven here through the same state calls their clicks reach (the port
 * has no UI queries by element id; the clicks themselves are replayed by
 * the `kit-date-picker-*` golden scripts against the original).
 *
 * The calendar's "today" comes from `glaze.kit.base.chrono.Local`, fixed at
 * 2026-10-30 12:00 for every test.
 *
 * Not ported: `calendar_items_expose_names_in_every_view` checks accesskit
 * labels, read here on the items' `A11y` records instead.
 */
class TimeComponentsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        Local.fixAt(NaiveDateTime.of(NaiveDate.fromYmd(2026, 10, 30), NaiveTime.fromHms(12, 0, 0)));
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        Local.setClock(null);
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement, width:Float = 1920, height:Float = 1080):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), width, height);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    static function ymd(y:Int, m:Int, d:Int):NaiveDate {
        return NaiveDate.fromYmd(y, m, d);
    }

    static function hms(h:Int, m:Int, s:Int):NaiveTime {
        return NaiveTime.fromHms(h, m, s);
    }

    static function at(value:String):NaiveDateTime {
        return NaiveDateTime.parseFromStr(value, '%Y-%m-%d %H:%M:%S');
    }

    /** A calendar state in its own window (Rust `state(cx, date)`). */
    function calendarState(date:CalendarDate):Entity<CalendarState> {
        var state:Entity<CalendarState> = null;
        final cx = open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<CalendarState>) -> new CalendarState(window, c));
            return div();
        });
        state.update(app, (s, _) -> @:privateAccess s.setRawDate(date));
        return state;
    }

    /// chrono subset

    function testNaiveDateArithmeticAndFormat() {
        final d = ymd(2024, 2, 29);
        assertEquals('2024-02-29', d.toString());
        assertEquals(glaze.kit.base.chrono.Weekday.Thu, d.weekday());
        assertEquals('2024-03-01', d.addDays(1).toString());
        assertEquals(366, ymd(2025, 1, 1).numDaysSince(ymd(2024, 1, 1)));
        assertNull(NaiveDate.fromYmdOpt(2023, 2, 29));
        assertEquals('1970-01-01', NaiveDate.fromDaysSinceEpoch(0).toString());
        assertEquals(glaze.kit.base.chrono.Weekday.Wed, ymd(1969, 12, 31).weekday());
        assertEquals('2026/09/15', ymd(2026, 9, 15).format('%Y/%m/%d'));
        assertEquals('Tue Sep 15 2026, day 258', ymd(2026, 9, 15).format('%a %b %d %Y, day %j'));
        assertTrue(ymd(2026, 9, 15) == NaiveDate.parse('2026-09-15'));
        assertTrue(ymd(2026, 9, 15) < ymd(2026, 9, 16));
    }

    function testNaiveTimeFormats() {
        assertEquals('12:00 AM', hms(0, 0, 0).format('%I:%M %p'));
        assertEquals('09:30 PM', hms(21, 30, 0).format('%I:%M %p'));
        assertEquals('08:45:01', hms(8, 45, 1).format('%H:%M:%S'));
        assertEquals('2026/09/16 08:45:01', at('2026-09-16 08:45:01').format('%Y/%m/%d %H:%M:%S'));
        assertTrue(at('2026-09-16 08:45:01') == ymd(2026, 9, 16).andTime(hms(8, 45, 1)));
        assertNull(hms(23, 0, 0).withHour(24));
    }

    /// base calendar

    function testCalendarItemsExposeNamesInEveryView() {
        final labels:Array<{kind:CalendarItemKind, label:Null<String>}> = [];
        var calendar:Entity<CalendarState> = null;
        final cx = open((window, cx) -> {
            if (calendar == null) calendar = cx.newEntity((c:Context<CalendarState>) -> new CalendarState(window, c));
            labels.resize(0);
            return Calendar.component('named-calendar', calendar).item((item, state, _, _) -> {
                labels.push({kind: state.kind(), label: item.a11y.label});
                return (item : IntoElement).intoAnyElement();
            });
        });
        for (mode in [CalendarView.Day, CalendarView.Month, CalendarView.Year]) {
            calendar.update(app, (state, cx) -> {
                state.applyDate(CalendarDate.Single(ymd(2026, 9, 7)));
                state.setView(mode);
                cx.notify();
            });
            cx.update((window, _) -> {
                window.refresh();
                window.draw();
            });
            assertTrue(labels.length > 0);
            for (entry in labels) {
                assertTrue(entry.label != null && entry.label.length > 0, 'missing name for ${entry.kind}');
            }
            if (mode.isDay()) {
                assertTrue(Lambda.exists(labels, e -> e.kind == CalendarItemKind.Day && e.label == '2026-09-07'));
            }
        }
    }

    function testRangeSelectionRestartsAndCompletes() {
        final s = calendarState(CalendarDate.Range(null, null));
        final a = ymd(2025, 2, 10);
        final b = ymd(2025, 2, 12);
        s.update(app, (s, _) -> {
            assertFalse(s.selectDate(a));
            assertTrue(s.selectDate(b));
        });
        assertTrue(s.read(app).date().equals(CalendarDate.Range(a, b)));
        s.update(app, (s, _) -> assertFalse(s.selectDate(a)));
        assertTrue(s.read(app).date().equals(CalendarDate.Range(a, null)));
    }

    function testDisabledDateIsRejected() {
        final s = calendarState(CalendarDate.Single(null));
        s.update(app, (s, _) -> s.setDisabledMatcherShared(MatcherTools.range(ymd(2025, 1, 1), ymd(2025, 1, 31))));
        s.update(app, (s, _) -> assertFalse(s.selectDate(ymd(2025, 1, 2))));
    }

    function testMonthNavigationCrossesYear() {
        final s = calendarState(CalendarDate.Single(ymd(2025, 1, 1)));
        s.update(app, (s, _) -> {
            s.applyDate(CalendarDate.Single(ymd(2025, 1, 1)));
            s.prevMonth();
        });
        assertEquals(2024, s.read(app).currentYear());
        assertEquals(12, s.read(app).currentMonth());
        s.update(app, (s, _) -> s.nextMonth());
        assertEquals(2025, s.read(app).currentYear());
        assertEquals(1, s.read(app).currentMonth());
    }

    function testSixWeekMonthIsNotTruncated() {
        final s = calendarState(CalendarDate.Single(ymd(2025, 8, 1)));
        s.update(app, (s, _) -> {
            s.applyDate(CalendarDate.Single(ymd(2025, 8, 1)));
            assertEquals(1, s.monthDays().length);
            assertEquals(6, s.monthDays()[0].length);
            assertEquals(6, s.days().length);
            assertEquals(31, s.monthDays()[0][5][0].day());
        });
    }

    function testDayMonthAndYearViewsHaveCompleteTransitions() {
        final s = calendarState(CalendarDate.Single(null));
        s.update(app, (s, _) -> {
            assertEquals(CalendarView.Day, s.view());
            s.setView(CalendarView.Month);
            s.selectMonth(11);
            assertEquals(CalendarView.Day, s.view());
            assertEquals(11, s.currentMonth());
            s.setView(CalendarView.Year);
            s.selectYear(2032);
            assertEquals(CalendarView.Day, s.view());
            assertEquals(2032, s.currentYear());
        });
    }

    function testPickerViewsUseStableGridLayouts() {
        final month = @:privateAccess Calendar.pickerGridLayout(CalendarView.Month);
        assertEquals(3, month.columns);
        assertEquals(4., month.horizontalGap);
        final year = @:privateAccess Calendar.pickerGridLayout(CalendarView.Year);
        assertEquals(5, year.columns);
        assertEquals(4., year.horizontalGap);
        assertNull(@:privateAccess Calendar.pickerGridLayout(CalendarView.Day));
    }

    function testYearPageNavigationRespectsBothBounds() {
        final s = calendarState(CalendarDate.Single(null));
        s.update(app, (s, _) -> {
            @:privateAccess s.applyYearRange(2000, 2041);
            while (s.prevYearPage()) {}
            assertFalse(s.hasPrevYearPage());
            assertFalse(s.prevYearPage());
            assertTrue(s.nextYearPage());
            while (s.nextYearPage()) {}
            assertFalse(s.hasNextYearPage());
            assertFalse(s.nextYearPage());
        });
    }

    function testActivationEmitsOnlyForCompleteEnabledValues() {
        final s = calendarState(CalendarDate.Single(null));
        final events:Array<CalendarDate> = [];
        final subscription = app.subscribe(s, CalendarEvent, (_, event, _) -> {
            switch event {
                case Selected(date): events.push(date);
            }
        });
        s.update(app, (s, _) -> @:privateAccess s.setRawDate(CalendarDate.Range(null, null)));
        final start = ymd(2025, 4, 4);
        final end = ymd(2025, 4, 8);
        s.update(app, (s, cx) -> {
            assertFalse(s.activateDate(start, cx));
            assertTrue(s.activateDate(end, cx));
            assertTrue(s.date().equals(CalendarDate.Range(start, end)));
            s.setDisabledMatcherShared(MatcherTools.custom(d -> d == start));
            assertFalse(s.activateDate(start, cx));
            assertTrue(s.date().equals(CalendarDate.Range(start, end)));
        });
        dispatcher.runUntilParked();
        assertEquals(1, events.length);
        assertTrue(events[0].equals(CalendarDate.Range(start, end)));

        s.update(app, (s, cx) -> {
            @:privateAccess s.setRawDate(CalendarDate.Single(null));
            assertTrue(s.activateDate(end, cx));
            assertTrue(s.date().equals(CalendarDate.Single(end)));
        });
        dispatcher.runUntilParked();
        assertEquals(2, events.length);
        assertTrue(events[1].equals(CalendarDate.Single(end)));
        subscription.dispose();
    }

    function testTodayComesFromTheInjectedClock() {
        final s = calendarState(CalendarDate.Single(null));
        assertTrue(s.read(app).today() == ymd(2026, 10, 30));
        assertEquals(2026, s.read(app).currentYear());
        assertEquals(10, s.read(app).currentMonth());
    }

    /// component calendar

    function testDateDisplayIsStable() {
        assertEquals('2024-08-03', CalendarDate.Single(ymd(2024, 8, 3)).toDisplayString());
        assertEquals('nil', CalendarDate.Single(null).toDisplayString());
    }

    function testOnlyMonthOptionsUseCompactText() {
        assertTrue(@:privateAccess glaze.kit.time.Calendar.usesCompactText(CalendarItemKind.Month));
        assertFalse(@:privateAccess glaze.kit.time.Calendar.usesCompactText(CalendarItemKind.MonthToggle));
        assertFalse(@:privateAccess glaze.kit.time.Calendar.usesCompactText(CalendarItemKind.Day));
    }

    /// component time utils

    function testDaysInMonth() {
        assertEquals(29, @:privateAccess TimeUtils.daysInMonthOfDate(ymd(2024, 2, 1)));
        assertEquals(28, @:privateAccess TimeUtils.daysInMonthOfDate(ymd(2023, 2, 1)));
        assertEquals(31, @:privateAccess TimeUtils.daysInMonthOfDate(ymd(2023, 1, 1)));
        assertEquals(30, @:privateAccess TimeUtils.daysInMonthOfDate(ymd(2023, 4, 1)));
    }

    function testDays() {
        function assertCase(date:NaiveDate, firstDay:Weekday, expected:Array<String>, ?pos:haxe.PosInfos) {
            final out = [for (week in @:privateAccess TimeUtils.daysInMonth(date.year(), date.month(), firstDay)) [for (d in week) {
                if (d.year() == date.year() && d.month() == date.month()) {
                    StringTools.lpad(Std.string(d.day()), ' ', 2);
                } else if (d.year() == date.year()) {
                    '${d.month()}-${d.day()}';
                } else {
                    '${d.year()}-${d.month()}-${d.day()}';
                }
            }].join('|')];
            assertEquals(expected.join('\n'), out.join('\n'), null, pos);
        }

        assertCase(ymd(2024, 8, 1), glaze.kit.base.chrono.Weekday.Sun, [
            "7-28|7-29|7-30|7-31| 1| 2| 3",
            " 4| 5| 6| 7| 8| 9|10",
            "11|12|13|14|15|16|17",
            "18|19|20|21|22|23|24",
            "25|26|27|28|29|30|31",
        ]);
        assertCase(ymd(2025, 1, 1), glaze.kit.base.chrono.Weekday.Sun, [
            "2024-12-29|2024-12-30|2024-12-31| 1| 2| 3| 4",
            " 5| 6| 7| 8| 9|10|11",
            "12|13|14|15|16|17|18",
            "19|20|21|22|23|24|25",
            "26|27|28|29|30|31|2-1",
        ]);
        assertCase(ymd(2024, 2, 1), glaze.kit.base.chrono.Weekday.Sun, [
            "1-28|1-29|1-30|1-31| 1| 2| 3",
            " 4| 5| 6| 7| 8| 9|10",
            "11|12|13|14|15|16|17",
            "18|19|20|21|22|23|24",
            "25|26|27|28|29|3-1|3-2",
        ]);
        assertCase(ymd(2023, 2, 20), glaze.kit.base.chrono.Weekday.Sun, [
            "1-29|1-30|1-31| 1| 2| 3| 4",
            " 5| 6| 7| 8| 9|10|11",
            "12|13|14|15|16|17|18",
            "19|20|21|22|23|24|25",
            "26|27|28|3-1|3-2|3-3|3-4",
        ]);
        // Monday-first week: Feb 2023 starts on a Wednesday, so the grid
        // shifts to start on Monday (column 0 = Mon 30 Jan).
        assertCase(ymd(2023, 2, 1), glaze.kit.base.chrono.Weekday.Mon, [
            "1-30|1-31| 1| 2| 3| 4| 5",
            " 6| 7| 8| 9|10|11|12",
            "13|14|15|16|17|18|19",
            "20|21|22|23|24|25|26",
            "27|28|3-1|3-2|3-3|3-4|3-5",
        ]);
    }

    /// base time field (SegmentEditor)

    static function editor(precision:TimePrecision, hourCycle:HourCycle):SegmentEditor {
        final editor = @:privateAccess new SegmentEditor();
        @:privateAccess editor.setPrecision(precision);
        @:privateAccess editor.setHourCycle(hourCycle);
        return editor;
    }

    static function typeKeys(editor:SegmentEditor, keys:String):Void {
        for (i in 0...keys.length) {
            final ch = keys.charAt(i);
            switch ch {
                case 'a': @:privateAccess editor.inputPeriod(false);
                case 'p': @:privateAccess editor.inputPeriod(true);
                case _: @:privateAccess editor.inputDigit(Std.parseInt(ch));
            }
        }
    }

    function testTypingFillsSegmentsAndAdvances() {
        final editor = editor(TimePrecision.Second, H23);
        typeKeys(editor, '093015');
        assertTrue(@:privateAccess editor.time == hms(9, 30, 15));
        // The last segment stays selected once it is complete.
        assertEquals(TimeSegment.Second, @:privateAccess editor.segment);
    }

    function testADigitThatCannotStartTwoDigitsCompletesTheSegment() {
        final editor = editor(TimePrecision.Minute, H23);
        typeKeys(editor, '7');
        assertTrue(@:privateAccess editor.time == hms(7, 0, 0));
        assertEquals(TimeSegment.Minute, @:privateAccess editor.segment);
        typeKeys(editor, '8');
        assertTrue(@:privateAccess editor.time == hms(7, 8, 0));
    }

    function testAnOutOfRangePairRestartsFromTheSecondDigit() {
        final editor = editor(TimePrecision.Minute, H23);
        // 2 then 5 cannot form 25 hours, so 5 starts a new entry and completes it.
        typeKeys(editor, '25');
        assertTrue(@:privateAccess editor.time == hms(5, 0, 0));
        assertEquals(TimeSegment.Minute, @:privateAccess editor.segment);
    }

    function testSteppingWrapsWithoutCarry() {
        final editor = editor(TimePrecision.Minute, H23);
        @:privateAccess editor.setTime(hms(23, 59, 0));
        @:privateAccess editor.step(1);
        assertTrue(@:privateAccess editor.time == hms(0, 59, 0));
        @:privateAccess editor.selectSegment(TimeSegment.Minute);
        @:privateAccess editor.step(1);
        assertTrue(@:privateAccess editor.time == hms(0, 0, 0));
        @:privateAccess editor.step(-1);
        assertTrue(@:privateAccess editor.time == hms(0, 59, 0));
    }

    function testSegmentMovementStopsAtTheEnds() {
        final editor = editor(TimePrecision.Minute, H23);
        assertFalse(@:privateAccess editor.moveSegment(-1));
        assertTrue(@:privateAccess editor.moveSegment(1));
        assertFalse(@:privateAccess editor.moveSegment(1));
        assertFalse(@:privateAccess editor.selectSegment(TimeSegment.Second));
        assertFalse(@:privateAccess editor.selectSegment(TimeSegment.Period));
    }

    function testPrecisionTruncatesSeconds() {
        final editor = editor(TimePrecision.Second, H23);
        @:privateAccess editor.setTime(hms(9, 30, 15));
        @:privateAccess editor.selectSegment(TimeSegment.Second);
        @:privateAccess editor.setPrecision(TimePrecision.Minute);
        assertTrue(@:privateAccess editor.time == hms(9, 30, 0));
        assertEquals(TimeSegment.Hour, @:privateAccess editor.segment);
    }

    function testClearingResetsOnlyTheSelectedSegment() {
        final editor = editor(TimePrecision.Minute, H23);
        @:privateAccess editor.setTime(hms(9, 30, 0));
        @:privateAccess editor.selectSegment(TimeSegment.Minute);
        assertTrue(@:privateAccess editor.clearSegment());
        assertTrue(@:privateAccess editor.time == hms(9, 0, 0));
    }

    function testTwelveHourLabelsMapMidnightAndNoonToTwelve() {
        final editor = editor(TimePrecision.Minute, H12);
        for (entry in [
            {hour: 0, label: '12', period: 'AM'},
            {hour: 9, label: '09', period: 'AM'},
            {hour: 12, label: '12', period: 'PM'},
            {hour: 23, label: '11', period: 'PM'},
        ]) {
            @:privateAccess editor.setTime(hms(entry.hour, 0, 0));
            assertEquals(entry.label, @:privateAccess editor.label(TimeSegment.Hour));
            assertEquals(entry.period, @:privateAccess editor.label(TimeSegment.Period));
        }
    }

    function testTwelveHourTypingKeepsThePeriodUntilItIsTyped() {
        final editor = editor(TimePrecision.Minute, H12);
        // "1" may start 10 to 12, so it waits; "2" makes 12, which is midnight in AM.
        typeKeys(editor, '12');
        assertTrue(@:privateAccess editor.time == hms(0, 0, 0));
        typeKeys(editor, '30p');
        assertTrue(@:privateAccess editor.time == hms(12, 30, 0));
        assertEquals(TimeSegment.Period, @:privateAccess editor.segment);
        @:privateAccess editor.selectSegment(TimeSegment.Hour);
        typeKeys(editor, '9');
        assertTrue(@:privateAccess editor.time == hms(21, 30, 0));
        // "00" is not an hour on a 12-hour clock.
        @:privateAccess editor.selectSegment(TimeSegment.Hour);
        typeKeys(editor, '00');
        assertEquals(TimeSegment.Hour, @:privateAccess editor.segment);
    }

    function testTwelveHourSteppingWrapsWithinThePeriod() {
        final editor = editor(TimePrecision.Minute, H12);
        @:privateAccess editor.setTime(hms(11, 0, 0));
        @:privateAccess editor.step(1);
        assertTrue(@:privateAccess editor.time == hms(0, 0, 0), '11 AM steps to 12 AM');
        @:privateAccess editor.selectSegment(TimeSegment.Period);
        @:privateAccess editor.step(1);
        assertTrue(@:privateAccess editor.time == hms(12, 0, 0));
        @:privateAccess editor.step(1);
        assertTrue(@:privateAccess editor.time == hms(0, 0, 0));
        assertFalse(@:privateAccess editor.inputDigit(1), 'digits do not edit the period');
    }

    /// component time field

    function testTimeFieldBuilder() {
        var state:Entity<TimeFieldState> = null;
        open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<TimeFieldState>) -> new TimeFieldState(window, c).precision(TimePrecision.Second).hourCycle(H12));
            return div();
        });
        final field = @:privateAccess TimeField.component(state).withId('start').large().disabled(true).invalid(true).w(px(120.));
        assertTrue(Type.enumEq((field.id : glaze.ElementId), glaze.ElementId.Name('start')));
        assertTrue(field.size.match(Large));
        assertTrue(field.disabledValue);
        assertTrue(field.invalidValue);
    }

    function testPressingOutsideTheSegmentsFocusesTheFirstSegment() {
        var state:Entity<TimeFieldState> = null;
        final segments:Array<glaze.Bounds> = [];
        final cx = open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<TimeFieldState>) -> new TimeFieldState(window, c));
            return div().child(TimeField.component(state).withId('time').w(px(200.)));
        });
        // The hour segment starts after the frame's border (1) and the
        // field's padding (4); the minute one follows the hour (2 + 2
        // digits + 2) and the `:`.
        final y = 16.;
        final blank = new Point(180., y);
        cx.simulateClick(blank);
        cx.update((window, app) -> assertTrue(state.read(app).focusHandle.isFocused(window)));
        assertEquals(TimeSegment.Hour, state.read(app).selectedSegment());

        // A press on a segment still selects that segment, not the first one.
        cx.simulateClick(new Point(42., y));
        assertEquals(TimeSegment.Minute, state.read(app).selectedSegment());

        cx.simulateClick(blank);
        assertEquals(TimeSegment.Hour, state.read(app).selectedSegment());
    }

    /// date picker (integration flows, through the state calls)

    function datePicker(build:(Window, Context<DatePickerState>) -> DatePickerState, changes:Array<DateTime>):Entity<DatePickerState> {
        var state:Entity<DatePickerState> = null;
        open((window, cx) -> {
            if (state == null) {
                state = cx.newEntity((c:Context<DatePickerState>) -> build(window, c));
                app.subscribe(state, DatePickerEvent, (_, event, _) -> switch event {
                    case Change(value): changes.push(value);
                });
            }
            return div().sizeFull().p4().child(glaze.kit.time.DatePicker.component(state).numberOfMonths(2));
        }, 800, 600);
        return state;
    }

    function testDateTimePickerReportsEachEditAndStaysOpen() {
        final changes:Array<DateTime> = [];
        var window:Window = null;
        final state = datePicker((w, cx) -> {
            window = w;
            final state = new DatePickerState(w, cx).timePrecision(TimePrecision.Second);
            state.setDateTime(DateTime.Single(at('2026-09-15 08:00:00')), w, cx);
            return state;
        }, changes);
        final s = state.read(app);
        assertEquals('2026/09/15 08:00:00', s.dateTime().format(@:privateAccess s.displayFormat()));
        state.update(app, (s, cx) -> @:privateAccess s.setOpen(true, window, cx));
        final calendar = @:privateAccess state.read(app).calendar;
        calendar.update(app, (c, cx) -> c.activateDate(ymd(2026, 9, 16), cx));
        dispatcher.runUntilParked();
        // Picking a date keeps the popup open so the time can be edited next.
        assertTrue(state.read(app).isOpen());
        final field = @:privateAccess state.read(app).timeField;
        field.update(app, (f, cx) -> {
            @:privateAccess f.selectSegment(TimeSegment.Minute, cx);
            @:privateAccess f.edit(cx, e -> e.inputDigit(4));
            @:privateAccess f.edit(cx, e -> e.inputDigit(5));
            // The minute is complete, so the seconds segment is selected next.
            @:privateAccess f.edit(cx, e -> e.step(1));
        });
        dispatcher.runUntilParked();
        final s = state.read(app);
        assertEquals('2026/09/16 08:45:01', s.dateTime().format(@:privateAccess s.displayFormat()));
        // Clicking the selected day again confirms it and closes the popup.
        calendar.update(app, (c, cx) -> c.activateDate(ymd(2026, 9, 16), cx));
        dispatcher.runUntilParked();
        assertFalse(state.read(app).isOpen());
        final expected = ['2026-09-16 08:00:00', '2026-09-16 08:04:00', '2026-09-16 08:45:00', '2026-09-16 08:45:01'];
        assertEquals(expected.length, changes.length);
        for (i in 0...expected.length) {
            assertTrue(changes[i].equals(DateTime.Single(at(expected[i]))), 'change $i');
        }
    }

    function testTwelveHourPickerTypesThePeriod() {
        final changes:Array<DateTime> = [];
        final state = datePicker((w, cx) -> {
            final state = new DatePickerState(w, cx).timePrecision(TimePrecision.Minute).hourCycle(H12);
            state.setDateTime(DateTime.Single(at('2026-09-15 00:00:00')), w, cx);
            return state;
        }, changes);
        final s = state.read(app);
        // Midnight reads as 12 AM.
        assertEquals('2026/09/15 12:00 AM', s.dateTime().format(@:privateAccess s.displayFormat()));
        final field = @:privateAccess state.read(app).timeField;
        field.update(app, (f, cx) -> {
            @:privateAccess f.selectSegment(TimeSegment.Hour, cx);
            for (key in ['0', '9', '3', '0']) @:privateAccess f.edit(cx, e -> e.inputDigit(Std.parseInt(key)));
            @:privateAccess f.edit(cx, e -> e.inputPeriod(true));
        });
        dispatcher.runUntilParked();
        final s = state.read(app);
        assertEquals('2026/09/15 09:30 PM', s.dateTime().format(@:privateAccess s.displayFormat()));
        assertTrue(changes[changes.length - 1].equals(DateTime.Single(at('2026-09-15 21:30:00'))));
    }

    function testRangePickerEditsDatesOnly() {
        final changes:Array<DateTime> = [];
        final state = datePicker((w, cx) -> {
            final state = DatePickerState.range(w, cx).timePrecision(TimePrecision.Minute);
            state.setDateTime(DateTime.Range(at('2026-09-15 09:00:00'), at('2026-09-15 18:00:00')), w, cx);
            return state;
        }, changes);
        final s = state.read(app);
        assertEquals('2026/09/15 - 2026/09/15', s.dateTime().format(@:privateAccess s.displayFormat()));
        assertNull(@:privateAccess s.editedTimePrecision());
        final calendar = @:privateAccess state.read(app).calendar;
        calendar.update(app, (c, cx) -> c.activateDate(ymd(2026, 9, 16), cx));
        calendar.update(app, (c, cx) -> c.activateDate(ymd(2026, 9, 18), cx));
        dispatcher.runUntilParked();
        // A complete range closes the popup, as in any date-only picker.
        assertFalse(state.read(app).isOpen());
        // The times set by the owner are kept.
        assertEquals(1, changes.length);
        assertTrue(changes[0].equals(DateTime.Range(at('2026-09-16 09:00:00'), at('2026-09-18 18:00:00'))));
    }

    function testDisabledDatePickerDoesNotOpen() {
        var state:Entity<DatePickerState> = null;
        final cx = open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<DatePickerState>) -> new DatePickerState(window, c));
            return div().sizeFull().p4().child(glaze.kit.time.DatePicker.component(state)
                .cleanable(true)
                .disabled(true)
                .presets([DateRangePreset.single('Release day', NaiveDate.parse('2026-09-15'))]));
        }, 640, 600);
        // The field spans the 608 px row below the 16 px padding.
        cx.simulateClick(new Point(100., 32.));
        assertFalse(state.read(app).isOpen());
        cx.simulateKeystrokes('enter');
        assertFalse(state.read(app).isOpen());
    }

    function testEnabledDatePickerOpensOnClick() {
        var state:Entity<DatePickerState> = null;
        final cx = open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<DatePickerState>) -> new DatePickerState(window, c));
            return div().sizeFull().p4().child(glaze.kit.time.DatePicker.component(state).cleanable(true));
        }, 640, 600);
        cx.simulateClick(new Point(100., 32.));
        assertTrue(state.read(app).isOpen());
        cx.simulateKeystrokes('escape');
        assertFalse(state.read(app).isOpen());
    }

    function testDatePickerPresetSelectsAndCleanClears() {
        final changes:Array<DateTime> = [];
        var window:Window = null;
        final state = datePicker((w, cx) -> {
            window = w;
            return new DatePickerState(w, cx);
        }, changes);
        state.update(app, (s, cx) -> @:privateAccess s.selectPreset(DateRangePreset.single('Release day', NaiveDate.parse('2026-09-15')), window, cx));
        dispatcher.runUntilParked();
        final s = state.read(app);
        assertFalse(s.isOpen());
        assertEquals('2026/09/15', s.dateTime().format(@:privateAccess s.displayFormat()));
        state.update(app, (s, cx) -> @:privateAccess s.clean(null, window, cx));
        dispatcher.runUntilParked();
        assertFalse(state.read(app).date().isSome());
        assertEquals(2, changes.length);
    }

}
