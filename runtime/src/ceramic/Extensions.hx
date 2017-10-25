package ceramic;

import ceramic.Shortcuts.*;

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

    inline public static function setProperty<T>(instance:T, field:String, value:Dynamic):Void {

        if (#if flash untyped (instance).hasOwnProperty ("set_" + field) #elseif js untyped (instance).__properties__ && untyped (instance).__properties__["set_" + field] #else false #end) {
            Reflect.setProperty(instance, field, value);
        }
        else {
            Reflect.setField(instance, field, value);
        }

    } //setProperty

    inline public static function getProperty<T>(instance:T, field:String):Dynamic {

        if (#if flash untyped (instance).hasOwnProperty ("get_" + field) #elseif js untyped (instance).__properties__ && untyped (instance).__properties__["get_" + field] #else false #end) {
            return Reflect.getProperty(instance, field);
        }
        else {
            return Reflect.field(instance, field);
        }

    } //getProperty

} //Extensions
