// Ported from chrono 0.4.45: src/naive/time/mod.rs, src/traits.rs (Timelike)
// (the subset gpui-kit 0.8.1 uses)
// Original code Copyright (c) 2014--2026, Kang Seonghoon and contributors, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.chrono;

/**
 * A time of day without time zone (chrono's `NaiveTime`), to the second.
 *
 * The value is the number of seconds since midnight. gpui-kit never uses
 * fractional seconds or leap seconds, so they are not represented.
 */
abstract NaiveTime(Int) {

    /** Midnight, 00:00:00 (chrono's `NaiveTime::MIN`). */
    public static final MIN:NaiveTime = new NaiveTime(0);

    inline function new(seconds:Int) {
        this = seconds;
    }

    @:op(A == B) static function eq(a:NaiveTime, b:NaiveTime):Bool;

    @:op(A != B) static function neq(a:NaiveTime, b:NaiveTime):Bool;

    @:op(A < B) static function lt(a:NaiveTime, b:NaiveTime):Bool;

    @:op(A <= B) static function lte(a:NaiveTime, b:NaiveTime):Bool;

    @:op(A > B) static function gt(a:NaiveTime, b:NaiveTime):Bool;

    @:op(A >= B) static function gte(a:NaiveTime, b:NaiveTime):Bool;

    /** The time from seconds since midnight, 0 to 86399. */
    public static inline function fromSecondsSinceMidnight(seconds:Int):NaiveTime {
        return new NaiveTime(seconds);
    }

    public inline function secondsSinceMidnight():Int {
        return this;
    }

    /** `hour:min:sec`, or null when out of range (chrono's `from_hms_opt`). */
    public static function fromHmsOpt(hour:Int, min:Int, sec:Int):Null<NaiveTime> {
        if (hour < 0 || hour >= 24 || min < 0 || min >= 60 || sec < 0 || sec >= 60) return null;
        return new NaiveTime(hour * 3600 + min * 60 + sec);
    }

    /** Like `fromHmsOpt`, throwing when out of range (Rust `.unwrap()`). */
    public static function fromHms(hour:Int, min:Int, sec:Int):NaiveTime {
        final time = fromHmsOpt(hour, min, sec);
        if (time == null) throw 'invalid time $hour:$min:$sec';
        return time;
    }

    public inline function hour():Int {
        return Std.int(this / 3600);
    }

    public inline function minute():Int {
        return Std.int(this / 60) % 60;
    }

    public inline function second():Int {
        return this % 60;
    }

    /** This time with another hour, or null when out of range. */
    public function withHour(hour:Int):Null<NaiveTime> {
        if (hour < 0 || hour >= 24) return null;
        return new NaiveTime(hour * 3600 + this % 3600);
    }

    /** This time with another minute, or null when out of range. */
    public function withMinute(min:Int):Null<NaiveTime> {
        if (min < 0 || min >= 60) return null;
        return new NaiveTime(this - (Std.int(this / 60) % 60) * 60 + min * 60);
    }

    /** This time with another second, or null when out of range. */
    public function withSecond(sec:Int):Null<NaiveTime> {
        if (sec < 0 || sec >= 60) return null;
        return new NaiveTime(this - this % 60 + sec);
    }

    /** Formats with a strftime-like `format` (chrono's `format(..).to_string()`). */
    public function format(format:String):String {
        return ChronoFormat.format(format, null, new NaiveTime(this));
    }

    /** `HH:MM:SS` (chrono's `Display` and `Debug`). */
    public function toString():String {
        return ChronoFormat.format('%H:%M:%S', null, new NaiveTime(this));
    }

}
