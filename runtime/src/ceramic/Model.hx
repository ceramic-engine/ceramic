package ceramic;

import ceramic.Autorun;

using StringTools;

class Model extends Entity implements Observable implements Serializable {

/// Components

    @component var serializer:SerializeModel;

/// Lifecycle

    public function new() {

    } //new

/// Print

    function toString():String {

        var prevAutorun = Autorun.current;
        Autorun.current = null;

        var result:Dynamic = {};

        for (key in Reflect.fields(this)) {

            if (key.startsWith('__')) continue;

            var displayKey = key;
            if (displayKey.startsWith('unobserved')) {
                displayKey = displayKey.charAt(10).toLowerCase() + displayKey.substring(11);
            }

            Reflect.setField(result, displayKey, Reflect.field(this, key));

        }

        Autorun.current = prevAutorun;
        return '' + result;

    } //toString

/// Haxe built in serializer extension

    @:keep
    function hxSerialize(s:haxe.Serializer) {
        s.serialize(@:privateAccess Serialize.serializeValue(this));
    }

    @:keep
    function hxUnserialize(u:haxe.Unserializer) {
        @:privateAccess Serialize.deserializeValue(u.unserialize(), this);
    }

} //Model
