package ceramic;

import ceramic.Autorun;

using StringTools;

class Model extends Entity implements Observable implements Serializable {

/// Components

    @component public var serializer:SerializeModel;

/// Lifecycle

    public function new() {

    } //new

/// Print

    static var _toStringContext:Array<Dynamic> = null;

    override function toString():String {

        var newContext = (_toStringContext == null);
        if (newContext) {
            _toStringContext = [];
        }
        else {
            if (_toStringContext.indexOf(this) != -1) return '_';
        }
        _toStringContext.push(this);

        var prevAutorun = Autorun.current;
        Autorun.current = null;

        var result:Dynamic = {};

        for (key in Reflect.fields(this)) {

            if (key.startsWith('__')) continue;

            var displayKey = key;
            if (displayKey.startsWith('unobserved')) {
                displayKey = displayKey.charAt(10).toLowerCase() + displayKey.substring(11);
            }

            var value = Reflect.field(this, key);
            Reflect.setField(result, displayKey, value);

        }

        Autorun.current = prevAutorun;

        if (newContext) {
            _toStringContext = null;
        }

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
