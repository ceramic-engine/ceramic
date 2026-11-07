// Ported from gpui-kit 0.8.1: crates/story/src/stories/date_picker_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.Calendar.CalendarDate;
import glaze.kit.base.Calendar.Matcher;
import glaze.kit.base.TimeField.HourCycle;
import glaze.kit.base.TimeField.TimePrecision;
import glaze.kit.base.chrono.Local;
import glaze.kit.base.chrono.NaiveDate;
import glaze.kit.base.chrono.NaiveTime;
import glaze.kit.Size;
import glaze.kit.theme.Theme;
import glaze.kit.time.DatePicker;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.time.DatePicker.DateTimeTools;

class DatePickerStory extends Model implements Story {

    final datePicker:Entity<DatePickerState>;
    final datePickerSmall:Entity<DatePickerState>;
    final datePickerLarge:Entity<DatePickerState>;
    final dataPickerCustom:Entity<DatePickerState>;
    var datePickerValue:Null<String>;
    final dateRangePicker:Entity<DatePickerState>;
    final defaultRangeModePicker:Entity<DatePickerState>;
    final birthdayPicker:Entity<DatePickerState>;
    final withoutAppearancePicker:Entity<DatePickerState>;
    final dateTimePicker:Entity<DatePickerState>;
    final dateTimeSecondPicker:Entity<DatePickerState>;
    final dateTime12hPicker:Entity<DatePickerState>;
    var dateTimeValue:Null<String>;
    var size:Size;
    final subscriptions:Array<Subscription>;

    public static function title():String {
        return 'DatePicker';
    }

    public static function description():String {
        return 'A date picker to select a date or date range.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<DatePickerStory> {
        return cx.newEntity((cx:Context<DatePickerStory>) -> new DatePickerStory(window, cx));
    }

    /** Rust `Utc::now().naive_local().date()`: today's date in UTC. */
    static function utcToday():NaiveDate {
        final d = Date.now();
        return NaiveDate.fromYmd(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate());
    }

    function new(window:Window, cx:Context<DatePickerStory>) {
        super();
        final now = Local.now().date();
        datePicker = cx.newEntity((cx:Context<DatePickerState>) -> {
            final picker = new DatePickerState(window, cx).disabledMatcher(DayOfWeek([0, 6]));
            picker.setDate(Single(now), window, cx);
            return picker;
        });
        datePickerLarge = cx.newEntity((cx:Context<DatePickerState>) -> {
            final picker = new DatePickerState(window, cx)
                .dateFormat('%Y-%m-%d')
                .disabledMatcher(Matcher.Range(now, now.checkedAddDays(7)));
            final yesterday = now.checkedAddDays(-1);
            picker.setDate(Single(yesterday != null ? yesterday : NaiveDate.fromYmd(1970, 1, 1)), window, cx);
            return picker;
        });
        datePickerSmall = cx.newEntity((cx:Context<DatePickerState>) -> {
            final picker = new DatePickerState(window, cx).disabledMatcher(Matcher.Interval(now, now.checkedAddDays(5)));
            picker.setDate(Single(now), window, cx);
            return picker;
        });
        dataPickerCustom = cx.newEntity((cx:Context<DatePickerState>) -> {
            final picker = new DatePickerState(window, cx).disabledMatcher(Matcher.Custom(date -> date.day() - 1 < 5));
            picker.setDate(Single(now), window, cx);
            return picker;
        });
        dateRangePicker = cx.newEntity((cx:Context<DatePickerState>) -> {
            final picker = new DatePickerState(window, cx);
            picker.setDate(CalendarDate.Range(now, now.checkedAddDays(4)), window, cx);
            return picker;
        });

        defaultRangeModePicker = cx.newEntity((cx:Context<DatePickerState>) -> DatePickerState.range(window, cx));

        birthdayPicker = cx.newEntity((cx:Context<DatePickerState>) -> {
            final picker = new DatePickerState(window, cx);
            picker.setYearRange(1927, now.year() + 1, cx);
            return picker;
        });

        withoutAppearancePicker = cx.newEntity((cx:Context<DatePickerState>) -> new DatePickerState(window, cx));

        dateTimePicker = cx.newEntity((cx:Context<DatePickerState>) -> {
            final picker = new DatePickerState(window, cx).timePrecision(TimePrecision.Minute);
            picker.setDateTime(DateTime.Single(Local.now()), window, cx);
            return picker;
        });
        dateTimeSecondPicker = cx.newEntity((cx:Context<DatePickerState>) -> new DatePickerState(window, cx)
            .timePrecision(TimePrecision.Second)
            .defaultTime(NaiveTime.fromHms(9, 0, 0)));
        dateTime12hPicker = cx.newEntity((cx:Context<DatePickerState>) -> new DatePickerState(window, cx)
            .timePrecision(TimePrecision.Minute)
            .hourCycle(HourCycle.H12)
            .defaultTime(NaiveTime.fromHms(9, 0, 0)));

        subscriptions = [
            cx.subscribe(datePicker, DatePickerEvent, (this_:DatePickerStory, _, ev, _) -> switch ev {
                case Change(date): this_.datePickerValue = date.format('%Y-%m-%d');
            }),
            cx.subscribe(dateRangePicker, DatePickerEvent, (this_:DatePickerStory, _, ev, _) -> switch ev {
                case Change(date): this_.datePickerValue = date.format('%Y-%m-%d');
            }),
            cx.subscribe(defaultRangeModePicker, DatePickerEvent, (this_:DatePickerStory, _, ev, _) -> switch ev {
                case Change(date): this_.datePickerValue = date.format('%Y-%m-%d');
            }),
            cx.subscribe(dateTimePicker, DatePickerEvent, (this_:DatePickerStory, _, ev, _) -> switch ev {
                case Change(value): this_.dateTimeValue = value.format('%Y-%m-%d %H:%M:%S');
            }),
            cx.subscribe(dateTimeSecondPicker, DatePickerEvent, (this_:DatePickerStory, _, ev, _) -> switch ev {
                case Change(value): this_.dateTimeValue = value.format('%Y-%m-%d %H:%M:%S');
            }),
            cx.subscribe(dateTime12hPicker, DatePickerEvent, (this_:DatePickerStory, _, ev, _) -> switch ev {
                case Change(value): this_.dateTimeValue = value.format('%Y-%m-%d %H:%M:%S');
            }),
        ];

        dateTimeValue = null;
        size = glaze.kit.Size.Medium;
        datePickerValue = null;
    }

    public function focusHandle(cx:App):FocusHandle {
        return datePicker.read(cx).focusHandle;
    }

    /** Rust `{:?}` of an `Option<String>`. */
    static function debugOption(value:Null<String>):String {
        return value == null ? 'None' : 'Some(' + haxe.Json.stringify(value) + ')';
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<DatePickerStory> = cast cx;
        final theme = Theme.global(cx.app);
        final today = utcToday();
        final presets = [
            DateRangePreset.single('Yesterday', today.addDays(-1)),
            DateRangePreset.single('Last Week', today.addDays(-7)),
            DateRangePreset.single('Last Month', today.addDays(-30)),
        ];
        final rangePresets = [
            DateRangePreset.range('Last 7 Days', today.addDays(-7), today),
            DateRangePreset.range('Last 14 Days', today.addDays(-14), today),
            DateRangePreset.range('Last 30 Days', today.addDays(-30), today),
            DateRangePreset.range('Last 90 Days', today.addDays(-90), today),
        ];

        return vFlex()
            .gap3()
            .onAction(ChangeStorySize, self.listener((this_:DatePickerStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Single-date selection with presets and clear action.')
                .w128()
                .vFlex()
                .gap3()
                .child(new DatePicker(datePicker)
                    .withSize(size)
                    .w(px(280.))
                    .cleanable(true)
                    .presets(presets))
                .child(div()
                    .textSm()
                    .textColor(theme.mutedForeground)
                    .child('Value: ' + debugOption(datePickerValue))))
            .child(section('Date and time')
                .description('Edit the time of day below the calendar; changes apply as you make them.')
                .w128()
                .vFlex()
                .gap3()
                .child(new DatePicker(dateTimePicker)
                    .withSize(size)
                    .w(px(280.)))
                .child(new DatePicker(dateTimeSecondPicker)
                    .withSize(size)
                    .w(px(280.))
                    .placeholder('With seconds')
                    .cleanable(true))
                .child(new DatePicker(dateTime12hPicker)
                    .withSize(size)
                    .w(px(280.))
                    .placeholder('12-hour clock')
                    .cleanable(true))
                .child(div()
                    .textSm()
                    .textColor(theme.mutedForeground)
                    .child('Value: ' + debugOption(dateTimeValue))))
            .child(section('Disabled dates')
                .description('Matchers can block intervals, ranges, or custom dates.')
                .w128()
                .vFlex()
                .gap3()
                .child(new DatePicker(datePickerSmall)
                    .withSize(size)
                    .w(px(280.)))
                .child(new DatePicker(datePickerLarge)
                    .withSize(size)
                    .w(px(280.)))
                .child(new DatePicker(dataPickerCustom)
                    .withSize(size)
                    .w(px(280.))))
            .child(section('Date range')
                .description('Two months with range presets.')
                .w128()
                .child(new DatePicker(dateRangePicker)
                    .withSize(size)
                    .w(px(280.))
                    .numberOfMonths(2)
                    .cleanable(true)
                    .presets(rangePresets.copy())))
            .child(section('Empty range')
                .description('Empty range with presets.')
                .w128()
                .child(new DatePicker(defaultRangeModePicker)
                    .withSize(size)
                    .w(px(280.))
                    .placeholder('Range mode picker')
                    .cleanable(true)
                    .presets(rangePresets.copy())))
            .child(section('Year range')
                .description('Custom year range.')
                .w128()
                .child(new DatePicker(birthdayPicker)
                    .withSize(size)
                    .w(px(280.))
                    .numberOfMonths(1)
                    .cleanable(true)
                    .placeholder('Select birthday')))
            .child(section('Custom style')
                .description('Appearance-free input.')
                .w128()
                .child(div().w(px(280.)).bg(theme.secondary).child(new DatePicker(withoutAppearancePicker)
                    .withSize(size)
                    .w(px(280.))
                    .appearance(false)
                    .placeholder('Without appearance'))));
    }

}
