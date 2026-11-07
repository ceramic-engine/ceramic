// New code for the Haxe port of gpui-kit: the serde (de)serialization rules
// the dock's persisted state (crates/base/src/dock/state.rs, Longbridge,
// Apache-2.0) gets from `#[derive(Serialize, Deserialize)]`. See NOTICE.md.
package gpui.base.dock;

import gpui.Pixels;
import gpui.SpringMath;
import gpui.base.dock.JsonValue;

/**
 * Field readers with serde's checks: a required field must be present,
 * `usize` takes a non negative integer only, `Pixels` (`f32`) takes any
 * number and rounds it to `f32`, unknown fields are ignored.
 */
class DockStateJson {

    public static function struct(value:Null<JsonValue>, expected:String):JsonObject {
        return switch value {
            case JObject(object): object;
            case _: throw new JsonError('invalid type, expected $expected');
        }
    }

    public static function field(object:JsonObject, name:String):JsonValue {
        final value = object.get(name);
        if (value == null) throw new JsonError('missing field `$name`');
        return value;
    }

    public static function array(value:JsonValue):Array<JsonValue> {
        return switch value {
            case JArray(values): values;
            case _: throw new JsonError('invalid type, expected a sequence');
        }
    }

    public static function usize(value:JsonValue):Int {
        return switch value {
            case JInt(v) if (v >= 0): Std.int(v);
            case JInt(v): throw new JsonError('invalid value: integer `${JsonValueTools.formatInteger(v)}`, expected usize');
            case JFloat(v) | JFloat32(v): throw new JsonError('invalid type: floating point `${JsonValueTools.formatF64(v)}`, expected usize');
            case _: throw new JsonError('invalid type, expected usize');
        }
    }

    public static function pixels(value:JsonValue):Pixels {
        return switch value {
            case JInt(v) | JFloat(v) | JFloat32(v): SpringMath.f32(v);
            case _: throw new JsonError('invalid type, expected f32');
        }
    }

    public static function bool(value:JsonValue):Bool {
        return switch value {
            case JBool(v): v;
            case _: throw new JsonError('invalid type, expected a boolean');
        }
    }

    public static function string(value:JsonValue):String {
        return switch value {
            case JString(v): v;
            case _: throw new JsonError('invalid type, expected a string');
        }
    }

}
