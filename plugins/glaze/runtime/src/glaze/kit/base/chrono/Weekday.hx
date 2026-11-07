// Ported from chrono 0.4.45: src/weekday.rs (the subset gpui-kit 0.8.1 uses)
// Original code Copyright (c) 2014--2026, Kang Seonghoon and contributors, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.chrono;

/**
 * The day of week (chrono's `Weekday`). The underlying value is
 * `numDaysFromMonday()`, like chrono's `Weekday as u8`.
 */
enum abstract Weekday(Int) {

    var Mon = 0;
    var Tue = 1;
    var Wed = 2;
    var Thu = 3;
    var Fri = 4;
    var Sat = 5;
    var Sun = 6;

    /** The weekday from its number of days from Monday (wrapping). */
    public static function fromNumDaysFromMonday(n:Int):Weekday {
        return cast(((n % 7) + 7) % 7);
    }

    /** The next day (`Sun.succ()` is `Mon`). */
    public inline function succ():Weekday {
        return fromNumDaysFromMonday(this + 1);
    }

    /** The previous day (`Mon.pred()` is `Sun`). */
    public inline function pred():Weekday {
        return fromNumDaysFromMonday(this + 6);
    }

    /** Monday is 1, Sunday is 7. */
    public inline function numberFromMonday():Int {
        return this + 1;
    }

    /** Sunday is 1, Saturday is 7. */
    public inline function numberFromSunday():Int {
        return (this + 1) % 7 + 1;
    }

    /** Monday is 0, Sunday is 6. */
    public inline function numDaysFromMonday():Int {
        return this;
    }

    /** Sunday is 0, Saturday is 6. */
    public inline function numDaysFromSunday():Int {
        return (this + 1) % 7;
    }

    /** The English name, `Mon` ... `Sun` (chrono's `Debug` / `Display`). */
    public function toString():String {
        return SHORT_NAMES[this];
    }

    @:allow(glaze.kit.base.chrono)
    static final SHORT_NAMES:Array<String> = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    @:allow(glaze.kit.base.chrono)
    static final LONG_NAMES:Array<String> = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

}
