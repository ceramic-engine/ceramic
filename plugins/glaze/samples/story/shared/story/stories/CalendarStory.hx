// Ported from gpui-kit 0.8.1: crates/story/src/stories/calendar_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.base.Calendar.CalendarState;
import glaze.kit.base.Calendar.Matcher;
import glaze.kit.time.Calendar;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

class CalendarStory extends Model implements Story {

    final focusHandle:FocusHandle;

    final calendar:Entity<CalendarState>;

    final calendarWide:Entity<CalendarState>;

    final calendarWithDisabledMatcher:Entity<CalendarState>;

    public static function title():String {
        return 'Calendar';
    }

    public static function description():String {
        return 'A calendar to select a date or date range.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<CalendarStory> {
        return cx.newEntity((cx:Context<CalendarStory>) -> new CalendarStory(window, cx));
    }

    function new(window:Window, cx:Context<CalendarStory>) {
        super();
        calendar = cx.newEntity((cx:Context<CalendarState>) -> new CalendarState(window, cx));
        calendarWide = cx.newEntity((cx:Context<CalendarState>) -> new CalendarState(window, cx));
        // Rust `Matcher::from(vec![0, 3, 6])`: days of the week
        calendarWithDisabledMatcher = cx.newEntity((cx:Context<CalendarState>) -> new CalendarState(window, cx).disabledMatcher(DayOfWeek([0, 3, 6])));
        focusHandle = cx.focusHandle();
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return vFlex()
            .gap3()
            .child(section('Single month')
                .description('Single-date selection.')
                .w128()
                .child(new Calendar(calendar)))
            .child(section('Multiple months')
                .description('Three months shown together.')
                .w128()
                .child(new Calendar(calendarWide).numberOfMonths(3)))
            .child(section('Disabled dates')
                .description('Recurring unavailable weekdays.')
                .w128()
                .child(new Calendar(calendarWithDisabledMatcher)));
    }

}
