package ceramic;

/** A bunch of static extensions to make life easier. */
class Extensions {

/// Array extensions

    inline public static function unsafeGet<T>(array:Array<T>, index:Int):T {
#if debug
        if (index < 0 || index >= array.length) throw 'Invalid unsafeGet: index=$index length=${array.length}';
#end
#if cpp
        return cpp.NativeArray.unsafeGet(array, index);
#else
        return array[index];
#end
    } //unsafeGet

    inline public static function unsafeSet<T>(array:Array<T>, index:Int, value:T):Void {
#if debug
        if (index < 0 || index >= array.length) throw 'Invalid unsafeSet: index=$index length=${array.length}';
#end
#if cpp
        cpp.NativeArray.unsafeSet(array, index, value);
#else
        array[index] = value;
#end
    } //unsafeSet

    /** Return a random element contained in the given array */
    inline public static function randomElement<T>(array:Array<T>):T {

        return array[Math.floor(Math.random() * 0.99999 * array.length)];

    } //randomElement

    /** Return a random element contained in the given array that is not equal to the `except` arg.
        @param array  The array in which we extract the element from
        @param except The element we don't want
        @param unsafe If set to `true`, will prevent allocating a new array (and may be faster) but will loop forever if there is no element except the one we don't want
        @return The random element or `null` if nothing was found */
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
            var array = array.copy();

            // Shuffle array
            shuffle(array);

            // Get first item different than `except`
            for (item in array) {
                if (item != except) return item;
            }
        }

        return null;

    } //randomElement

    /** Shuffle an Array. This operation affects the array in place.
        The shuffle algorithm used is a variation of the [Fisher Yates Shuffle](http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle) */
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

	} //shuffle

/// Generic extensions

    @:noCompletion
    inline public static function setProperty<T>(instance:T, field:String, value:Dynamic):Void {

        // @see https://github.com/openfl/actuate/blob/4547a5a6d2e95dbb3f6b8eacb719532b4c1650d2/motion/actuators/SimpleActuator.hx#L327-L345
		if (Reflect.hasField(instance, field) #if flash && !untyped (instance).hasOwnProperty("set_" + field) #elseif js && !(untyped (instance).__properties__ && untyped (instance).__properties__["set_" + field]) #end) {
			#if flash
			untyped target[field] = value;
			#else
			Reflect.setField(instance, field, value);
			#end
		}
        else {
			Reflect.setProperty(instance, field, value);
		}

    } //setProperty

    @:noCompletion
    inline public static function getProperty<T>(instance:T, field:String):Dynamic {

        if (#if flash untyped (instance).hasOwnProperty ("get_" + field) #elseif js untyped (instance).__properties__ && untyped (instance).__properties__["get_" + field] #else false #end) {
            return Reflect.getProperty(instance, field);
        }
        else {
            return Reflect.field(instance, field);
        }

    } //getProperty

} //Extensions
