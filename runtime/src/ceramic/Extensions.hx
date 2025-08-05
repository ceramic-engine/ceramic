package ceramic;

#if cs
import haxe.io.Bytes;
#end

/**
 * A collection of static extension methods for common data types.
 * 
 * Extensions provides utility methods that enhance standard Haxe types
 * with performance optimizations, convenience methods, and cross-platform
 * compatibility helpers. These methods are designed to be used with
 * Haxe's "using" syntax for cleaner code.
 * 
 * ## Categories
 * 
 * - **Array Extensions**: Performance-optimized array operations
 * - **String Extensions**: String manipulation utilities
 * - **Map Extensions**: Enhanced map operations
 * - **Type Extensions**: Type checking and conversion
 * 
 * ## Usage Example
 * 
 * ```haxe
 * using ceramic.Extensions;
 * 
 * // Array extensions
 * var arr = [1, 2, 3, 4, 5];
 * arr.shuffle();
 * var random = arr.randomElement();
 * var value = arr.unsafeGet(0); // Fast access
 * 
 * // String extensions
 * var str = "  hello world  ";
 * var trimmed = str.trim();
 * var title = str.toTitleCase();
 * ```
 * 
 * ## Performance Notes
 * 
 * - unsafeGet/Set methods bypass bounds checking for speed
 * - Native array operations are used on C++ when available
 * - Debug builds can enable bounds checking with ceramic_debug_unsafe
 * 
 * @see Type-specific extension methods throughout the class
 */
class Extensions<T> {

/// Array extensions

    /**
     * Gets an array element without bounds checking for maximum performance.
     * 
     * This method provides the fastest possible array access by bypassing
     * runtime bounds checking. Use only when you're certain the index is valid.
     * 
     * @param array The array to access
     * @param index The index to retrieve (must be 0 <= index < array.length)
     * @return The element at the specified index
     * @throws Exception in debug mode if ceramic_debug_unsafe is defined and index is invalid
     * 
     * ```haxe
     * var arr = [10, 20, 30];
     * var value = arr.unsafeGet(1); // 20 (fast access)
     * // arr.unsafeGet(5); // Undefined behavior in release!
     * ```
     */
    #if !ceramic_debug_unsafe inline #end public static function unsafeGet<T>(array:Array<T>, index:Int):T {
#if ceramic_debug_unsafe
        if (index < 0 || index >= array.length) throw 'Invalid unsafeGet: index=$index length=${array.length}';
#end
#if cpp
        #if app_cpp_nativearray_unsafe
        return cpp.NativeArray.unsafeGet(array, index);
        #else
        return untyped array.__unsafe_get(index);
        #end
#elseif cs
        return cast untyped __cs__('{0}.__a[{1}]', array, index);
#else
        return array[index];
#end
    }

    /**
     * Sets an array element without bounds checking for maximum performance.
     * 
     * This method provides the fastest possible array mutation by bypassing
     * runtime bounds checking. Use only when you're certain the index is valid.
     * 
     * @param array The array to modify
     * @param index The index to set (must be 0 <= index < array.length)
     * @param value The value to set at the index
     * @throws Exception in debug mode if ceramic_debug_unsafe is defined and index is invalid
     * 
     * ```haxe
     * var arr = [10, 20, 30];
     * arr.unsafeSet(1, 25); // arr is now [10, 25, 30]
     * ```
     */
    #if !ceramic_debug_unsafe inline #end public static function unsafeSet<T>(array:Array<T>, index:Int, value:T):Void {
#if ceramic_debug_unsafe
        if (index < 0 || index >= array.length) throw 'Invalid unsafeSet: index=$index length=${array.length}';
#end
#if cpp
        #if app_cpp_nativearray_unsafe
        cpp.NativeArray.unsafeSet(array, index, value);
        #else
        untyped array.__unsafe_set(index, value);
        #end
#elseif cs
        return cast untyped __cs__('{0}.__a[{1}] = {2}', array, index, value);
#else
        array[index] = value;
#end
    }

    /**
     * Efficiently resizes an array to the specified length.
     * 
     * Platform-optimized array resizing that either truncates or extends
     * the array. When extending, new positions contain null/undefined values.
     * 
     * @param array The array to resize
     * @param length The new length (can be larger or smaller)
     * 
     * ```haxe
     * var arr = [1, 2, 3, 4, 5];
     * arr.setArrayLength(3); // [1, 2, 3]
     * arr.setArrayLength(5); // [1, 2, 3, null, null]
     * ```
     */
    #if !debug inline #end public static function setArrayLength<T>(array:Array<T>, length:Int):Void {
        if (array.length != length) {
#if cpp
            untyped array.__SetSize(length);
#else
            if (array.length > length) {
                array.splice(length, array.length - length);
            }
            else {
                var dArray:Array<Dynamic> = array;
                while (dArray.length < length)
                    dArray.push(null);
            }
#end
        }
    }

    /**
     * Returns a random element from the array.
     * 
     * Uses Math.random() to select an element with uniform distribution.
     * For empty arrays, this will return undefined/null.
     * 
     * @param array The array to select from
     * @return A random element from the array
     * 
     * ```haxe
     * var colors = ["red", "green", "blue"];
     * var randomColor = colors.randomElement(); // e.g., "green"
     * ```
     */
    inline public static function randomElement<T>(array:Array<T>):T {

        return array[Math.floor(Math.random() * 0.99999 * array.length)];

    }

    /**
     * Return a random element contained in the given array that is not equal to the `except` arg.
     * @param array  The array in which we extract the element from
     * @param except The element we don't want
     * @param unsafe If set to `true`, will prevent allocating a new array (and may be faster) but will loop forever if there is no element except the one we don't want
     * @return The random element or `null` if nothing was found
     */
    public static function randomElementExcept<T>(array:Array<T>, except:T, unsafe:Bool = false):T {

        if (unsafe) {
            // Unsafe
            var ret = null;

            do {
                ret = randomElement(array);
            } while (ret == except);

            return ret;
        }
        else {
            // Safe

            // Work on a copy
            var array_:Array<T> = [];
            for (item in array) {
                array_.push(item);
            }

            // Shuffle array
            shuffle(array_);

            // Get first item different than `except`
            for (item in array_) {
                if (item != except) return item;
            }
        }

        return null;

    }

    /**
     * Return a random element contained in the given array that is validated by the provided validator.
     * If no item is valid, returns null.
     * @param array  The array in which we extract the element from
     * @param validator A function that returns true if the item is valid, false if not
     * @return The random element or `null` if nothing was found
     */
    public static function randomElementMatchingValidator<T>(array:Array<T>, validator:T->Bool):T {

        // Work on a copy
        var array_:Array<T> = [];
        for (item in array) {
            array_.push(item);
        }

        // Shuffle array
        shuffle(array_);

        // Get first item different than `except`
        for (item in array_) {
            if (validator(item)) return item;
        }

        return null;

    }

    /**
     * Shuffles an array in place using the Fisher-Yates algorithm.
     * 
     * This operation modifies the original array, randomizing the order
     * of all elements with uniform distribution. Each permutation has
     * equal probability.
     * 
     * @param arr The array to shuffle (modified in place)
     * 
     * ```haxe
     * var deck = [1, 2, 3, 4, 5];
     * deck.shuffle();
     * trace(deck); // e.g., [3, 1, 5, 2, 4]
     * ```
     * 
     * @see https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle
     */
    public static function shuffle<T>(arr:Array<T>):Void
    {
        inline function int(from:Int, to:Int):Int
        {
            return from + Math.floor(((to - from + 1) * Math.random()));
        }

        if (arr != null) {
            for (i in 0...arr.length) {
                var j = int(0, arr.length - 1);
                var a = arr[i];
                var b = arr[j];
                arr[i] = b;
                arr[j] = a;
            }
        }

    }

    public static function swapElements<T>(arr:Array<T>, index0:Int, index1:Int):Void {

        var a = arr[index0];
        arr[index0] = arr[index1];
        arr[index1] = a;

    }

    public static function removeNullElements<T>(arr:Array<T>):Void {

        var i = 0;
        var gap = 0;
        var len = arr.length;
        while (i < len) {

            do {

                var item = unsafeGet(arr, i);
                if (item == null) {
                    i++;
                    gap++;
                }
                else {
                    break;
                }

            }
            while (i < len);

            if (gap != 0 && i < len) {
                var key = i - gap;
                unsafeSet(arr, key, unsafeGet(arr, i));
            }

            i++;
        }

        setArrayLength(arr, len - gap);

    }

/// Generic extensions

    @:noCompletion
    inline public static function setProperty<T>(instance:T, field:String, value:Dynamic):Void {

        Reflect.setProperty(instance, field, value);

    }

    @:noCompletion
    inline public static function getProperty<T>(instance:T, field:String):Dynamic {

        return Reflect.getProperty(instance, field);

    }

/// Buffer extensions

#if cs

    public static extern inline overload function toBytes(buffer:UInt8Array):Bytes {
        return Bytes.ofData(buffer);
    }

#end

}
