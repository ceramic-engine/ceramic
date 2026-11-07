package glaze.util;

/**
 * Copies of `Iterable` arguments without an iterator when the argument is an
 * array, which it nearly always is: on hxcpp a `for` over an `Iterable` calls
 * `iterator()`, `hasNext()` and `next()` through `Dynamic` (an iterator
 * object per loop, a field lookup per call, and `next()` boxes numbers).
 * Other iterables (a `List`, a custom one) are still iterated.
 */
class Iterables {

    /**
     * `values` itself when it is an array, else a copy: for loops that only
     * read (`for (v in Iterables.asArray(values))` is an indexed loop)
     */
    public static function asArray<T>(values:Iterable<T>):Array<T> {
        #if (cpp || js)
        if (Std.isOfType(values, Array))
            return cast values;
        #end
        return [for (v in values) v];
    }

    /** `[for (v in values) v]` */
    public static function toArray<T>(values:Iterable<T>):Array<T> {
        #if (cpp || js)
        if (Std.isOfType(values, Array)) {
            final array:Array<T> = cast values;
            return array.copy();
        }
        #end
        return [for (v in values) v];
    }

    /** `[for (v in values) if (v != null) v]` */
    public static function toArrayNonNull<T>(values:Iterable<T>):Array<T> {
        final result:Array<T> = [];
        appendNonNull(result, values);
        return result;
    }

    /** `for (v in values) target.push(v)` */
    public static function append<T>(target:Array<T>, values:Iterable<T>):Void {
        #if (cpp || js)
        if (Std.isOfType(values, Array)) {
            final array:Array<T> = cast values;
            for (i in 0...array.length)
                target.push(array[i]);
            return;
        }
        #end
        for (v in values)
            target.push(v);
    }

    /** `for (v in values) if (v != null) target.push(v)` */
    public static function appendNonNull<T>(target:Array<T>, values:Iterable<T>):Void {
        #if (cpp || js)
        if (Std.isOfType(values, Array)) {
            final array:Array<T> = cast values;
            for (i in 0...array.length) {
                final v = array[i];
                if (v != null)
                    target.push(v);
            }
            return;
        }
        #end
        for (v in values)
            if (v != null)
                target.push(v);
    }

}
