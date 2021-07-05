package ceramic;

/**
 * A bunch of static extensions to make life easier.
 */
class Extensions<T> {

/// Array extensions

    #if !ceramic_debug_unsafe inline #end public static function unsafeGet<T>(array:Array<T>, index:Int):T {
#if ceramic_debug_unsafe
        if (index < 0 || index >= array.length) throw 'Invalid unsafeGet: index=$index length=${array.length}';
#end
#if cpp
        return cpp.NativeArray.unsafeGet(array, index);
#elseif cs
        return cast untyped __cs__('{0}.__a[{1}]', array, index);
#else
        return array[index];
#end
    }

    #if !ceramic_debug_unsafe inline #end public static function unsafeSet<T>(array:Array<T>, index:Int, value:T):Void {
#if ceramic_debug_unsafe
        if (index < 0 || index >= array.length) throw 'Invalid unsafeSet: index=$index length=${array.length}';
#end
#if cpp
        cpp.NativeArray.unsafeSet(array, index, value);
#elseif cs
        return cast untyped __cs__('{0}.__a[{1}] = {2}', array, index, value);
#else
        array[index] = value;
#end
    }

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
                dArray[length - 1] = null;
            }
#end
        }
    }

    /**
     * Return a random element contained in the given array
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
     * Shuffle an Array. This operation affects the array in place.
     * The shuffle algorithm used is a variation of the [Fisher Yates Shuffle](http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle)
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

/// Generic extensions

    @:noCompletion
    inline public static function setProperty<T>(instance:T, field:String, value:Dynamic):Void {

        Reflect.setProperty(instance, field, value);

    }

    @:noCompletion
    inline public static function getProperty<T>(instance:T, field:String):Dynamic {

        return Reflect.getProperty(instance, field);

    }

}
