package tools;

class Equal {

    /**
     * Equality check (deep equality only working on arrays for now)
     * @param a
     * @param b
     * @return Bool
     */
    public static function equal(a:Dynamic, b:Dynamic):Bool {

        if (a == b)
            return true;

        if (Std.isOfType(a, Array)) {
            if (Std.isOfType(b, Array)) {
                return _arrayEqual(a, b);
            }
            return false;
        }
        else if (Std.isOfType(a, haxe.ds.StringMap)) {
            if (Std.isOfType(b, haxe.ds.StringMap)) {
                return stringMapEqual(a, b);
            }
            return false;
        }
        else if (Std.isOfType(a, haxe.ds.IntMap)) {
            if (Std.isOfType(b, haxe.ds.IntMap)) {
                return intMapEqual(a, b);
            }
            return false;
        }
        else if (Reflect.isObject(a) && Type.getClass(a) == null) {
            if (Reflect.isObject(b) && Type.getClass(b) == null) {
                return objectFieldsEqual(a, b);
            }
            return false;
        }

        return false;

    }

    public static function objectFieldsEqual(a:Any, b:Any):Bool {
        for (field in Reflect.fields(a)) {
            if (!Reflect.hasField(b, field) || !equal(Reflect.field(a, field), Reflect.field(b, field))) {
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
    public extern inline static overload function arrayEqual(a:Array<String>, b:Array<String>):Bool {
        var aDyn:Any = a;
        var bDyn:Any = b;
        return _arrayEqual(cast aDyn, cast bDyn);
    }
    #end

    public extern inline static overload function arrayEqual(a:Array<Any>, b:Array<Any>):Bool {
        return _arrayEqual(a, b);
    }

    public static function _arrayEqual(a:Array<Any>, b:Array<Any>):Bool {

        var lenA = a.length;
        var lenB = b.length;
        if (lenA != lenB)
            return false;
        for (i in 0...lenA) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;

    }

    public static function stringMapEqual(a:haxe.ds.StringMap<Any>, b:haxe.ds.StringMap<Any>):Bool {

        for (key => val in a) {
            if (!b.exists(key))
                return false;
            if (b.get(key) != val)
                return false;
        }

        for (key in b.keys()) {
            if (!a.exists(key))
                return false;
        }

        return true;

    }

    public static function intMapEqual(a:haxe.ds.IntMap<Any>, b:haxe.ds.IntMap<Any>):Bool {

        for (key => val in a) {
            if (!b.exists(key))
                return false;
            if (b.get(key) != val)
                return false;
        }

        for (key in b.keys()) {
            if (!a.exists(key))
                return false;
        }

        return true;

    }

}