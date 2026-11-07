// Ported from gpui-kit 0.8.1: crates/component/src/time/utils.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.time;

import gpui.base.chrono.NaiveDate;
import gpui.base.chrono.Weekday;

/**
 * Date helpers of the time components (Rust `utils.rs`: `NaiveDateExt` and
 * the five-week `days_in_month`). gpui-kit 0.8.1 keeps them crate-private
 * and only its tests call them; the calendar grids come from
 * `gpui.base.Calendar`.
 */
@:allow(gpui.component)
@:allow(tests)
class TimeUtils {

    static function daysInMonthOfDate(date:NaiveDate):Int {
        final month = date.month();
        return switch month {
            case 1 | 3 | 5 | 7 | 8 | 10 | 12: 31;
            case 4 | 6 | 9 | 11: 30;
            case 2: isLeapYear(date) ? 29 : 28;
            case _: throw 'Invalid month: $month';
        }
    }

    static function isLeapYear(date:NaiveDate):Bool {
        final year = date.year();
        return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    }

    static function daysInMonth(year:Int, month:Int, firstDay:Weekday):Array<Array<NaiveDate>> {
        var year = year;
        var month = month;
        if (month > 12) {
            year += 1;
            month = 1;
        }
        if (month < 1) {
            year -= 1;
            month = 12;
        }

        final date = NaiveDate.fromYmd(year, month, 1);
        final numDays = daysInMonthOfDate(date);
        final startWeekday = (date.weekday().numDaysFromSunday() + 7 - firstDay.numDaysFromSunday()) % 7;

        // Get the days in the month, 2023-02 will returns
        // "29|30|31| 1| 2| 3| 4",
        // " 5| 6| 7| 8| 9|10|11",
        // "12|13|14|15|16|17|18",
        // "19|20|21|22|23|24|25",
        // "26|27|28| 1| 2| 3| 4",
        final days:Array<Array<NaiveDate>> = [];
        for (n in 0...5) {
            final weekDays:Array<NaiveDate> = [];
            for (weekday in 0...7) {
                var y = year;
                var m = month;

                // If the day is less than the start weekday, we need to go back to the previous month.
                if (n == 0 && weekday < startWeekday) {
                    m = m == 1 ? 12 : m - 1;
                    y = m == 1 ? year - 1 : y;
                }

                // If start_weekday is 3, and n is 0 and weekday is 3, then day is 1.
                // If start_weekday is 3, and n is 1 and weekday is 4, then day is 9.
                final day = n * 7 + weekday - startWeekday;

                // If the day is greater than the number of days in the month, we need to go to the next month.
                if (day > numDays) {
                    m = m == 12 ? 1 : m + 1;
                    y = m == 1 ? year + 1 : y;
                }

                final result = date.checkedAddDays(day);
                if (result == null) throw 'invalid date $y-$m days $day';
                weekDays.push(result);
            }
            days.push(weekDays);
        }

        return days;
    }

}
