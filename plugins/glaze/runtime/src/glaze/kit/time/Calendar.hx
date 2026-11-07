// Ported from gpui-kit 0.8.1: crates/component/src/time/calendar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.time;

import gpui.App;
import gpui.ElementId;
import gpui.Entity;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.Calendar.CalendarItemKind;
import gpui.base.Calendar.CalendarState;
import gpui.base.chrono.Weekday;
import gpui.component.I18n;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * Styled facade for the complete behavior and structure in `gpui-base`.
 *
 * `CalendarEvent`, `CalendarState`, `CalendarDate` (Rust `Date`) and
 * `Matcher` are the Base ones (`gpui.base.Calendar`).
 */
class Calendar implements RenderOnce implements Styled implements Sizable {

    final id:ElementId;

    var size:Size = Medium;

    final state:Entity<CalendarState>;

    final calendarStyle:StyleRefinement = new StyleRefinement();

    var numberOfMonthsValue:Int = 1;

    var firstDayOfWeekValue:Weekday = gpui.base.chrono.Weekday.Sun;

    public function new(state:Entity<CalendarState>) {
        this.id = ElementId.NamedInteger('calendar', state.entityId());
        this.state = state;
    }

    public function numberOfMonths(count:Int):Calendar {
        numberOfMonthsValue = count;
        return this;
    }

    /** Set the first day of the week for the calendar. */
    public function firstDayOfWeek(day:Weekday):Calendar {
        firstDayOfWeekValue = day;
        return this;
    }

    public function withSize(size:IntoSize):Calendar {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public inline function style():StyleRefinement {
        return calendarStyle;
    }

    static function monthName(month:Int):String {
        return switch month {
            case 1: I18n.t('Calendar.month.January');
            case 2: I18n.t('Calendar.month.February');
            case 3: I18n.t('Calendar.month.March');
            case 4: I18n.t('Calendar.month.April');
            case 5: I18n.t('Calendar.month.May');
            case 6: I18n.t('Calendar.month.June');
            case 7: I18n.t('Calendar.month.July');
            case 8: I18n.t('Calendar.month.August');
            case 9: I18n.t('Calendar.month.September');
            case 10: I18n.t('Calendar.month.October');
            case 11: I18n.t('Calendar.month.November');
            case 12: I18n.t('Calendar.month.December');
            case _: '';
        }
    }

    @:allow(tests)
    static function usesCompactText(kind:CalendarItemKind):Bool {
        return kind == CalendarItemKind.Month;
    }

    public function render(window:Window, cx:App):IntoElement {
        final size = this.size;
        final monthCount = numberOfMonthsValue < 1 ? 1 : numberOfMonthsValue;
        final theme = Theme.global(cx);
        final calendar = new gpui.base.Calendar(id, state)
            .numberOfMonths(numberOfMonthsValue)
            .firstDayOfWeek(firstDayOfWeekValue)
            .label((kind, value) -> switch kind {
                case CalendarItemKind.Previous: '‹';
                case CalendarItemKind.Next: '›';
                case CalendarItemKind.MonthToggle | CalendarItemKind.Month: monthName(value);
                case CalendarItemKind.Weekday: switch value {
                        case 0: I18n.t('Calendar.week.0');
                        case 1: I18n.t('Calendar.week.1');
                        case 2: I18n.t('Calendar.week.2');
                        case 3: I18n.t('Calendar.week.3');
                        case 4: I18n.t('Calendar.week.4');
                        case 5: I18n.t('Calendar.week.5');
                        case _: I18n.t('Calendar.week.6');
                    }
                case _: Std.string(value);
            })
            .item((item, state, _, cx) -> {
                final theme = Theme.global(cx);
                final kind = state.kind();
                switch kind {
                    case CalendarItemKind.Previous:
                        item.clearChildren().child(new Icon(IconName.ChevronLeft).size4());
                    case CalendarItemKind.Next:
                        item.clearChildren().child(new Icon(IconName.ChevronRight).size4());
                    case _:
                }
                switch size {
                    case Small: item.size7().rounded(theme.radius / 2.);
                    case Large: item.size10().rounded(theme.radius * 2.);
                    case _: item.size8().rounded(theme.radius);
                }
                item.flex().itemsCenter().justifyCenter();
                if (kind != CalendarItemKind.Weekday) {
                    switch size {
                        case Small: item.textXs();
                        case _: item.textSm();
                    }
                }
                if (kind == CalendarItemKind.Weekday) {
                    item.textXs().fontNormal().textColor(theme.mutedForeground);
                }
                if (usesCompactText(kind)) item.textXs();
                if (kind == CalendarItemKind.MonthToggle || kind == CalendarItemKind.YearToggle) {
                    item.textSm().fontMedium();
                }
                if (kind == CalendarItemKind.Month || kind == CalendarItemKind.MonthToggle) {
                    if (kind == CalendarItemKind.Month) item.wFull().my1();
                    if (kind == CalendarItemKind.MonthToggle) item.wAuto().px2();
                }
                if (kind == CalendarItemKind.Year || kind == CalendarItemKind.YearToggle) {
                    if (kind == CalendarItemKind.Year) item.wFull().my1();
                    if (kind == CalendarItemKind.YearToggle) item.wAuto().px2();
                }
                if (state.isMuted()) {
                    item.textColor(theme.mutedForeground);
                    if (state.isDisabled()) item.opacity(0.5);
                }
                if (state.isInRange()) {
                    item.bg(theme.accent).textColor(theme.accentForeground);
                }
                if (!state.isActive() && !state.isDisabled() && kind != CalendarItemKind.Weekday) {
                    item.hover(s -> s.bg(theme.tokens.secondaryHover.background).textColor(theme.foreground));
                }
                if (state.isActive()) {
                    item.bg(theme.tokens.primary.background).textColor(theme.primaryForeground);
                }
                if (state.isToday() && !state.isActive()) {
                    item.bg(theme.accent).textColor(theme.accentForeground);
                }
                return (item : IntoElement).intoAnyElement();
            })
            .border1()
            .borderColor(theme.border)
            .rounded(theme.radiusLg)
            .p3()
            .gap0p5();
        switch size {
            case Small: calendar.w(gpui.Prelude.px(220. * monthCount));
            case Large: calendar.w(gpui.Prelude.px(304. * monthCount));
            case _: calendar.w(gpui.Prelude.px(248. * monthCount));
        }
        return calendar.refineStyle(calendarStyle);
    }

}
