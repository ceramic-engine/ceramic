// New code for the Haxe port of gpui-kit (no gpui-kit origin): typed reads of
// parsed JSON values with serde's strictness, used by the theme file readers.
// See NOTICE.md.
package gpui.component.theme;

/**
 * Reads fields of a value parsed by `haxe.Json.parse`, failing on a wrong
 * type like serde does (absent and `null` both mean `None`).
 */
@:allow(gpui.component)
class JsonValue {

    public static function isObject(value:Dynamic):Bool {

        return value != null
            && Reflect.isObject(value)
            && !Std.isOfType(value, String)
            && !Std.isOfType(value, Array)
            && Type.typeof(value).match(TObject);

    }

    public static inline function has(json:Dynamic, key:String):Bool {

        return Reflect.hasField(json, key) && Reflect.field(json, key) != null;

    }

    public static function optString(json:Dynamic, key:String):Null<String> {

        final value:Dynamic = Reflect.field(json, key);
        if (value == null) return null;
        if (!Std.isOfType(value, String)) {
            throw 'invalid type for `$key`, expected a string';
        }
        return value;

    }

    public static function optBool(json:Dynamic, key:String):Null<Bool> {

        final value:Dynamic = Reflect.field(json, key);
        if (value == null) return null;
        if (!Std.isOfType(value, Bool)) {
            throw 'invalid type for `$key`, expected a boolean';
        }
        return value;

    }

    public static function optFloat(json:Dynamic, key:String):Null<Float> {

        final value:Dynamic = Reflect.field(json, key);
        if (value == null) return null;
        if (!Std.isOfType(value, Float) && !Std.isOfType(value, Int)) {
            throw 'invalid type for `$key`, expected a number';
        }
        return value;

    }

    /**
     * An unsigned integer (Rust `usize`): a negative or fractional number throws.
     */
    public static function optUInt(json:Dynamic, key:String):Null<Int> {

        final value = optFloat(json, key);
        if (value == null) return null;
        if (value < 0 || Math.ffloor(value) != value) {
            throw 'invalid value for `$key`, expected usize';
        }
        return Std.int(value);

    }

    public static function optArray(json:Dynamic, key:String):Null<Array<Dynamic>> {

        final value:Dynamic = Reflect.field(json, key);
        if (value == null) return null;
        if (!Std.isOfType(value, Array)) {
            throw 'invalid type for `$key`, expected a sequence';
        }
        return value;

    }

    public static function optObject(json:Dynamic, key:String):Null<Dynamic> {

        final value:Dynamic = Reflect.field(json, key);
        if (value == null) return null;
        if (!isObject(value)) {
            throw 'invalid type for `$key`, expected a map';
        }
        return value;

    }

}
