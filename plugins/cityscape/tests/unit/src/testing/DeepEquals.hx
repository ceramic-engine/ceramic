package testing;

/**
 * Deep comparison of test values, like Node's `assert.deepStrictEqual` on
 * JSON-like data: numbers by value (an Int equals the same Float), strings
 * by content, arrays element by element, anonymous structures with the same
 * set of fields (a field set to null is present).
 *
 * `diffJson` compares a value parsed from JSON written by JavaScript with a
 * Haxe value: JSON drops the fields set to `undefined`, so a field missing
 * from the JSON side equals a null field on the Haxe side.
 */
class DeepEquals {

    public static function equals(a:Any, b:Any):Bool {
        return diff(a, b, '') == null;
    }

    /**
     * Null when equal, otherwise a description of the first difference.
     */
    public static function diff(a:Any, b:Any, path:String):Null<String> {
        return compare(a, b, path, false);
    }

    public static function diffJson(json:Any, value:Any, path:String):Null<String> {
        return compare(json, value, path, true);
    }

    static function compare(a:Any, b:Any, path:String, json:Bool):Null<String> {
        switch [Type.typeof(a), Type.typeof(b)] {
            case [TNull, TNull]:
                return null;
            case [TInt | TFloat, TInt | TFloat]:
                final fa:Float = a;
                final fb:Float = b;
                if (fa == fb || (Math.isNaN(fa) && Math.isNaN(fb)))
                    return null;
                return '$path: $fa != $fb';
            case [TBool, TBool]:
                return (a : Bool) == (b : Bool) ? null : '$path: $a != $b';
            case [TFunction, TFunction]:
                return Reflect.compareMethods(a, b) ? null : '$path: different functions';
            case [TClass(ca), TClass(cb)] if (ca == String && cb == String):
                return (a : String) == (b : String) ? null : '$path: "$a" != "$b"';
            case [TClass(ca), TClass(cb)] if (ca == Array && cb == Array):
                final aa:Array<Any> = a;
                final ba:Array<Any> = b;
                if (aa.length != ba.length)
                    return '$path: array length ${aa.length} != ${ba.length}';
                for (i in 0...aa.length) {
                    final d = compare(aa[i], ba[i], '$path[$i]', json);
                    if (d != null)
                        return d;
                }
                return null;
            case [TObject, TObject]:
                final fa = Reflect.fields(a);
                var fb = Reflect.fields(b);
                fa.sort(Reflect.compare);
                fb.sort(Reflect.compare);
                if (json) {
                    // Fields missing from the JSON side must be null on the other
                    for (key in fb) {
                        if (fa.indexOf(key) == -1 && Reflect.field(b, key) != null)
                            return '$path.$key: missing, ${Std.string(Reflect.field(b, key))}';
                    }
                    fb = [for (key in fb) if (fa.indexOf(key) != -1) key];
                }
                if (fa.join(',') != fb.join(','))
                    return '$path: fields [${fa.join(', ')}] != [${fb.join(', ')}]';
                for (key in fa) {
                    final d = compare(Reflect.field(a, key), Reflect.field(b, key), '$path.$key', json);
                    if (d != null)
                        return d;
                }
                return null;
            case _:
                return '$path: ${Std.string(a)} != ${Std.string(b)} (different types)';
        }
    }

}
