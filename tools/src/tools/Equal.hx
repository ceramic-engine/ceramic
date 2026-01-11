package tools;

class Equal {

    /**
     * Equality check (deep or shallow)
     * @param a First value to compare
     * @param b Second value to compare
     * @param deepEquality If true, recursively compare nested objects/arrays (default: false)
     * @return Bool
     */
    public static function equal(a:Dynamic, b:Dynamic, deepEquality:Bool = false):Bool {

        if (a == b)
            return true;

        if (Std.isOfType(a, Array)) {
            if (Std.isOfType(b, Array)) {
                return _arrayEqual(a, b, deepEquality);
            }
            return false;
        }
        else if (Std.isOfType(a, haxe.ds.StringMap)) {
            if (Std.isOfType(b, haxe.ds.StringMap)) {
                return stringMapEqual(a, b, deepEquality);
            }
            return false;
        }
        else if (Std.isOfType(a, haxe.ds.IntMap)) {
            if (Std.isOfType(b, haxe.ds.IntMap)) {
                return intMapEqual(a, b, deepEquality);
            }
            return false;
        }
        else if (Reflect.isObject(a) && Type.getClass(a) == null) {
            if (Reflect.isObject(b) && Type.getClass(b) == null) {
                return objectFieldsEqual(a, b, deepEquality);
            }
            return false;
        }

        return false;

    }

    public static function objectFieldsEqual(a:Any, b:Any, deepEquality:Bool = false):Bool {
        for (field in Reflect.fields(a)) {
            if (!Reflect.hasField(b, field) || !equal(Reflect.field(a, field), Reflect.field(b, field), deepEquality)) {
                return false;
            }
        }
        for (field in Reflect.fields(b)) {
            if (!Reflect.hasField(a, field)) {
                return false;
            }
        }
        return true;
    }

    #if cs
    public extern inline static overload function arrayEqual(a:Array<String>, b:Array<String>, deepEquality:Bool = false):Bool {
        var aDyn:Any = a;
        var bDyn:Any = b;
        return _arrayEqual(cast aDyn, cast bDyn, deepEquality);
    }
    #end

    public extern inline static overload function arrayEqual(a:Array<Any>, b:Array<Any>, deepEquality:Bool = false):Bool {
        return _arrayEqual(a, b, deepEquality);
    }

    public static function _arrayEqual(a:Array<Any>, b:Array<Any>, deepEquality:Bool = false):Bool {

        var lenA = a.length;
        var lenB = b.length;
        if (lenA != lenB)
            return false;
        for (i in 0...lenA) {
            if (!deepEquality) {
                if (a[i] != b[i]) {
                    return false;
                }
            } else {
                if (!equal(a[i], b[i], true)) {
                    return false;
                }
            }
        }
        return true;

    }

    public static function stringMapEqual(a:haxe.ds.StringMap<Any>, b:haxe.ds.StringMap<Any>, deepEquality:Bool = false):Bool {

        for (key => val in a) {
            if (!b.exists(key))
                return false;
            if (!deepEquality) {
                if (b.get(key) != val)
                    return false;
            } else {
                if (!equal(b.get(key), val, true))
                    return false;
            }
        }

        for (key in b.keys()) {
            if (!a.exists(key))
                return false;
        }

        return true;

    }

    public static function intMapEqual(a:haxe.ds.IntMap<Any>, b:haxe.ds.IntMap<Any>, deepEquality:Bool = false):Bool {

        for (key => val in a) {
            if (!b.exists(key))
                return false;
            if (!deepEquality) {
                if (b.get(key) != val)
                    return false;
            } else {
                if (!equal(b.get(key), val, true))
                    return false;
            }
        }

        for (key in b.keys()) {
            if (!a.exists(key))
                return false;
        }

        return true;

    }

}
