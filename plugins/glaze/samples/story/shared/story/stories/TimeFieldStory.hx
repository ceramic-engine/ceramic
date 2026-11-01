// Ported from gpui-kit 0.8.1: crates/story/src/stories/time_field_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.Subscription;
import gpui.base.TimeField.HourCycle;
import gpui.base.TimeField.TimeFieldEvent;
import gpui.base.TimeField.TimeFieldState;
import gpui.base.TimeField.TimePrecision;
import gpui.base.chrono.NaiveTime;
import gpui.component.Size;
import gpui.component.theme.Theme;
import gpui.component.time.TimeField;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class TimeFieldStory extends Model implements Story {

    public static function title():String {
        return 'TimeField';
    }

    public static function description():String {
        return 'Edit a time of day segment by segment, on a 24-hour or 12-hour clock.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<TimeFieldStory> {
        return cx.newEntity((c:Context<TimeFieldStory>) -> new TimeFieldStory(window, c));
    }

    final minute:Entity<TimeFieldState>;

    final second:Entity<TimeFieldState>;

    final twelveHour:Entity<TimeFieldState>;

    final disabled:Entity<TimeFieldState>;

    final invalid:Entity<TimeFieldState>;

    @observe var value:NaiveTime;

    @observe var size:Size = gpui.component.Size.Medium;

    final subscriptions:Array<Subscription>;

    function new(window:Window, cx:Context<TimeFieldStory>) {
        super();
        final value = NaiveTime.fromHmsOpt(9, 30, 0);
        final field = (precision:TimePrecision, hourCycle:HourCycle, window:Window, cx:Context<TimeFieldStory>) -> cx.newEntity((cx:Context<TimeFieldState>) -> {
            final state = new TimeFieldState(window, cx).precision(precision).hourCycle(hourCycle);
            state.setTime(value, window, cx);
            return state;
        });
        minute = field(TimePrecision.Minute, HourCycle.H23, window, cx);
        second = field(TimePrecision.Second, HourCycle.H23, window, cx);
        twelveHour = field(TimePrecision.Minute, HourCycle.H12, window, cx);
        disabled = field(TimePrecision.Minute, HourCycle.H23, window, cx);
        invalid = field(TimePrecision.Minute, HourCycle.H23, window, cx);
        subscriptions = [cx.subscribe(minute, TimeFieldEvent, (this_, _, event, _) -> switch event {
            case Change(time):
                this_.value = time;
        })];
        this.value = value;
    }

    public function focusHandle(cx:App):FocusHandle {
        return minute.read(cx).focusHandle;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Up/Down change the selected segment; digits type it and move to the next.')
                .vFlex()
                .gap3()
                .child(new TimeField(minute).withSize(size))
                .child(div()
                    .textSm()
                    .textColor(theme.mutedForeground)
                    .child('Value: ${value.toString()}')))
            .child(section('With seconds')
                .description('Set the precision to edit seconds as well.')
                .child(new TimeField(second).withSize(size)))
            .child(section('12-hour clock')
                .description('An AM/PM segment follows the time; type a or p to set it.')
                .child(new TimeField(twelveHour).withSize(size)))
            .child(section('Disabled').child(new TimeField(disabled).withSize(size).disabled(true)))
            .child(section('Invalid')
                .description('Show a validation result from the owner.')
                .child(new TimeField(invalid).withSize(size).invalid(true)));
    }

}
