package ceramic;

using ceramic.Extensions;

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

        return false;

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
            if (a.unsafeGet(i) != b.unsafeGet(i)) {
                return false;
            }
        }
        return true;

    }

}