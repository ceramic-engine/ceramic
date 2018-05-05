package ceramic;

class Serialize {

    public static function deserialize(serializable:Serializable, data:String):Void {

        // TODO

    } //deserialize

    public static function serialize(serializable:Serializable):String {

        return serializeValue(serializable);

    } //serialize

/// Internal

    static function serializeValue(value):Dynamic {

        if (Std.is(value, Serializable)) {

            var result:Dynamic = {
                __class: Type.getClassName(Type.getClass(value))
            };

            return result;

        }
        else if (Std.is(value, Array)) {

            //

        }
        else if (Std.is(value, String) || Std.is(value, Int) || Std.is(value, Float) || Std.is(value, Bool)) {

            //

        }
        else {

        }

        return null;

    } //serializeValue

} //Serialize
