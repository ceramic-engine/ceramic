// Ported from chrono 0.4.45: src/offset/local/mod.rs (`Local::now`, as used by gpui-kit 0.8.1:
// `Local::now().date_naive()` in crates/base/src/calendar.rs)
// Original code Copyright (c) 2014--2026, Kang Seonghoon and contributors, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic, with an injectable clock. See NOTICE.md.
package glaze.kit.base.chrono;

/**
 * The local wall clock (chrono's `Local`).
 *
 * gpui-kit reads it for the calendar's "today". The clock is injectable so
 * tests and golden scenes can fix the date: `Local.setClock(() -> ...)`,
 * `Local.setClock(null)` restores the wall clock (Haxe's `Date.now()`, in the
 * local time zone).
 */
class Local {

    static var clock:Null<() -> NaiveDateTime> = null;

    /** Replaces the clock (null for the wall clock). */
    public static function setClock(clock:Null<() -> NaiveDateTime>):Void {
        Local.clock = clock;
    }

    /** Fixes the clock at `value` (tests and golden scenes). */
    public static function fixAt(value:NaiveDateTime):Void {
        Local.clock = () -> value;
    }

    /** The current local date and time (`Local::now().naive_local()`). */
    public static function now():NaiveDateTime {
        if (clock != null) return clock();
        final d = Date.now();
        final date = NaiveDate.fromYmd(d.getFullYear(), d.getMonth() + 1, d.getDate());
        return date.andTime(NaiveTime.fromHms(d.getHours(), d.getMinutes(), d.getSeconds()));
    }

    /** The current local date (`Local::now().date_naive()`). */
    public static function today():NaiveDate {
        return now().date();
    }

}
