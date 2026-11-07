package gpui.util;

/**
 * Stack and queue operations on arrays of Int, Float or Bool that do not
 * box: on hxcpp `pop()` and `shift()` return `Null<T>` as `Dynamic`, so the
 * value is boxed (every Float, and every Int outside -1...255, allocates),
 * even when the caller drops it.
 */
class Stacks {

    /** `a.pop()` with the value dropped: removes the last value, if any */
    public static inline function drop<T>(a:Array<T>):Void {
        if (a.length > 0) a.resize(a.length - 1);
    }

    /** `a.pop()` on an array that is not empty */
    public static inline function popInt(a:Array<Int>):Int {
        final last = a.length - 1;
        final value = a[last];
        a.resize(last);
        return value;
    }

    /** `a.shift()` with the value dropped: removes the first value, if any */
    public static function dropFirstFloat(a:Array<Float>):Void {
        final length = a.length;
        if (length == 0) return;
        for (i in 1...length) {
            a[i - 1] = a[i];
        }
        a.resize(length - 1);
    }

}
