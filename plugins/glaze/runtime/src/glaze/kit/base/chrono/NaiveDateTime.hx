// Ported from chrono 0.4.45: src/naive/datetime/mod.rs (the subset gpui-kit 0.8.1 uses)
// Original code Copyright (c) 2014--2026, Kang Seonghoon and contributors, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.chrono;

/**
 * A date and a time of day without time zone (chrono's `NaiveDateTime`).
 *
 * The value is the number of seconds since 1970-01-01 00:00:00 (exact in a
 * Float over chrono's whole range), so values compare with `==` and `<`.
 */
abstract NaiveDateTime(Float) {

    inline function new(seconds:Float) {
        this = seconds;
    }

    @:op(A == B) static function eq(a:NaiveDateTime, b:NaiveDateTime):Bool;

    @:op(A != B) static function neq(a:NaiveDateTime, b:NaiveDateTime):Bool;

    @:op(A < B) static function lt(a:NaiveDateTime, b:NaiveDateTime):Bool;

    @:op(A <= B) static function lte(a:NaiveDateTime, b:NaiveDateTime):Bool;

    @:op(A > B) static function gt(a:NaiveDateTime, b:NaiveDateTime):Bool;

    @:op(A >= B) static function gte(a:NaiveDateTime, b:NaiveDateTime):Bool;

    /** `date` at `time` (chrono's `NaiveDateTime::new`). */
    public static inline function of(date:NaiveDate, time:NaiveTime):NaiveDateTime {
        return new NaiveDateTime(date.daysSinceEpoch() * 86400.0 + time.secondsSinceMidnight());
    }

    /**
     * Parses `value` with a strftime-like `format` (chrono's
     * `parse_from_str`; the parser knows `%Y %m %d %H %M %S` and literals),
     * or returns null.
     */
    public static function tryParseFromStr(value:String, format:String):Null<NaiveDateTime> {
        final parsed = ChronoFormat.parse(value, format);
        if (parsed == null) return null;
        final date = NaiveDate.fromYmdOpt(parsed.year, parsed.month, parsed.day);
        final time = NaiveTime.fromHmsOpt(parsed.hour, parsed.minute, parsed.second);
        if (date == null || time == null) return null;
        return of(date, time);
    }

    /** Like `tryParseFromStr`, throwing on an invalid value (Rust `.unwrap()`). */
    public static function parseFromStr(value:String, format:String):NaiveDateTime {
        final result = tryParseFromStr(value, format);
        if (result == null) throw 'invalid date time "$value" for "$format"';
        return result;
    }

    public inline function date():NaiveDate {
        return NaiveDate.fromDaysSinceEpoch(Math.floor(this / 86400.0));
    }

    public inline function time():NaiveTime {
        return NaiveTime.fromSecondsSinceMidnight(Std.int(this - Math.floor(this / 86400.0) * 86400.0));
    }

    /** Formats with a strftime-like `format` (chrono's `format(..).to_string()`). */
    public function format(format:String):String {
        return ChronoFormat.format(format, date(), time());
    }

    /** `YYYY-MM-DDTHH:MM:SS` (chrono's `Debug`). */
    public function toString():String {
        return ChronoFormat.format('%Y-%m-%dT%H:%M:%S', date(), time());
    }

}
