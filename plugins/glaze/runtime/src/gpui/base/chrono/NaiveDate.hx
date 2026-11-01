// Ported from chrono 0.4.45: src/naive/date/mod.rs, src/datetime/mod.rs, src/traits.rs (Datelike)
// (the subset gpui-kit 0.8.1 uses)
// Original code Copyright (c) 2014--2026, Kang Seonghoon and contributors, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.chrono;

/**
 * A calendar date in the proleptic Gregorian calendar, without time zone
 * (chrono's `NaiveDate`).
 *
 * The value is the number of days since 1970-01-01, so dates compare with
 * `==`, `<`, `>=`... and are plain values (no allocation). chrono's
 * `Duration` is only used by gpui-kit in whole days, so the arithmetic takes
 * day counts (`addDays`, `numDaysSince`).
 */
abstract NaiveDate(Int) {

    /** chrono's `NaiveDate::MIN` year. */
    public static inline final MIN_YEAR:Int = -262143;

    /** chrono's `NaiveDate::MAX` year. */
    public static inline final MAX_YEAR:Int = 262142;

    inline function new(days:Int) {
        this = days;
    }

    /** The date `days` days after 1970-01-01. */
    public static inline function fromDaysSinceEpoch(days:Int):NaiveDate {
        return new NaiveDate(days);
    }

    /** Days since 1970-01-01 (negative before it). */
    public inline function daysSinceEpoch():Int {
        return this;
    }

    @:op(A == B) static function eq(a:NaiveDate, b:NaiveDate):Bool;

    @:op(A != B) static function neq(a:NaiveDate, b:NaiveDate):Bool;

    @:op(A < B) static function lt(a:NaiveDate, b:NaiveDate):Bool;

    @:op(A <= B) static function lte(a:NaiveDate, b:NaiveDate):Bool;

    @:op(A > B) static function gt(a:NaiveDate, b:NaiveDate):Bool;

    @:op(A >= B) static function gte(a:NaiveDate, b:NaiveDate):Bool;

    /**
     * The date of `year`, `month` (1 to 12) and `day` (1 to 31), or null when
     * it does not exist (chrono's `from_ymd_opt`).
     */
    public static function fromYmdOpt(year:Int, month:Int, day:Int):Null<NaiveDate> {
        if (year < MIN_YEAR || year > MAX_YEAR) return null;
        if (month < 1 || month > 12) return null;
        if (day < 1 || day > daysInMonthOf(year, month)) return null;
        return new NaiveDate(daysFromCivil(year, month, day));
    }

    /** Like `fromYmdOpt`, throwing on an invalid date (Rust `.unwrap()`). */
    public static function fromYmd(year:Int, month:Int, day:Int):NaiveDate {
        final date = fromYmdOpt(year, month, day);
        if (date == null) throw 'invalid date $year-$month-$day';
        return date;
    }

    /**
     * Parses `YYYY-MM-DD` (chrono's `FromStr`, which accepts `%Y-%m-%d`),
     * or returns null.
     */
    public static function tryParse(value:String):Null<NaiveDate> {
        final parsed = ChronoFormat.parse(value, '%Y-%m-%d');
        if (parsed == null) return null;
        return fromYmdOpt(parsed.year, parsed.month, parsed.day);
    }

    /** Like `tryParse`, throwing on an invalid value (Rust `.parse().unwrap()`). */
    public static function parse(value:String):NaiveDate {
        final date = tryParse(value);
        if (date == null) throw 'invalid date "$value"';
        return date;
    }

    public static function isLeapYear(year:Int):Bool {
        return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    }

    /** The number of days of `month` in `year`. */
    public static function daysInMonthOf(year:Int, month:Int):Int {
        return switch month {
            case 1 | 3 | 5 | 7 | 8 | 10 | 12: 31;
            case 4 | 6 | 9 | 11: 30;
            case 2: isLeapYear(year) ? 29 : 28;
            case _: 0;
        }
    }

    // Howard Hinnant's days_from_civil / civil_from_days (public domain
    // algorithms), equivalent to chrono's ordinal arithmetic.

    static function daysFromCivil(year:Int, month:Int, day:Int):Int {
        final y = month <= 2 ? year - 1 : year;
        final era = Math.floor(y / 400);
        final yoe = y - era * 400;
        final mp = (month + 9) % 12;
        final doy = Std.int((153 * mp + 2) / 5) + day - 1;
        final doe = yoe * 365 + Std.int(yoe / 4) - Std.int(yoe / 100) + doy;
        return era * 146097 + doe - 719468;
    }

    function civil():{year:Int, month:Int, day:Int} {
        final z = this + 719468;
        final era = Math.floor(z / 146097);
        final doe = z - era * 146097;
        final yoe = Std.int((doe - Std.int(doe / 1460) + Std.int(doe / 36524) - Std.int(doe / 146096)) / 365);
        final doy = doe - (365 * yoe + Std.int(yoe / 4) - Std.int(yoe / 100));
        final mp = Std.int((5 * doy + 2) / 153);
        final day = doy - Std.int((153 * mp + 2) / 5) + 1;
        final month = mp < 10 ? mp + 3 : mp - 9;
        final year = yoe + era * 400 + (month <= 2 ? 1 : 0);
        return {year: year, month: month, day: day};
    }

    public function year():Int {
        return civil().year;
    }

    /** The month, 1 to 12. */
    public function month():Int {
        return civil().month;
    }

    /** The day of the month, 1 to 31. */
    public function day():Int {
        return civil().day;
    }

    /** The day of the year, 1 to 366. */
    public function ordinal():Int {
        final c = civil();
        return this - daysFromCivil(c.year, 1, 1) + 1;
    }

    public function weekday():Weekday {
        // 1970-01-01 was a Thursday.
        return Weekday.fromNumDaysFromMonday(this + 3);
    }

    /** The date `days` days later (earlier when negative): `self + Duration::days(days)`. */
    public inline function addDays(days:Int):NaiveDate {
        return new NaiveDate(this + days);
    }

    /**
     * `checked_add_signed(Duration::days(days))`: null when the result is out
     * of chrono's range.
     */
    public function checkedAddDays(days:Int):Null<NaiveDate> {
        final result = new NaiveDate(this + days);
        final y = result.year();
        if (y < MIN_YEAR || y > MAX_YEAR) return null;
        return result;
    }

    /** The whole days from `other` to this date: `(self - other).num_days()`. */
    public inline function numDaysSince(other:NaiveDate):Int {
        return this - other.daysSinceEpoch();
    }

    /** This date at `time` (chrono's `and_time`). */
    public inline function andTime(time:NaiveTime):NaiveDateTime {
        return NaiveDateTime.of(new NaiveDate(this), time);
    }

    /** This date with another year, or null when the day does not exist in it. */
    public function withYear(year:Int):Null<NaiveDate> {
        final c = civil();
        return fromYmdOpt(year, c.month, c.day);
    }

    /** This date with another month, or null when the day does not exist in it. */
    public function withMonth(month:Int):Null<NaiveDate> {
        final c = civil();
        return fromYmdOpt(c.year, month, c.day);
    }

    /** This date with another day of the month, or null when it does not exist. */
    public function withDay(day:Int):Null<NaiveDate> {
        final c = civil();
        return fromYmdOpt(c.year, c.month, day);
    }

    /** Formats with a strftime-like `format` (chrono's `format(..).to_string()`). */
    public function format(format:String):String {
        return ChronoFormat.format(format, new NaiveDate(this), null);
    }

    /** `YYYY-MM-DD` (chrono's `Display` and `Debug`). */
    public function toString():String {
        return ChronoFormat.format('%Y-%m-%d', new NaiveDate(this), null);
    }

}
