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
