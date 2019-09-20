package ceramic;

import ceramic.Autorun;

using StringTools;

class Model extends Entity implements Observable implements Serializable {

/// Events

    @event function _modelDirty(model:Model);

/// Components

    @component public var serializer:SerializeModel;

/// Properties

    public var dirty(default,set):Bool = false;

    inline function set_dirty(dirty:Bool):Bool {
        if (dirty == this.dirty) return dirty;
        this.dirty = dirty;
        if (dirty) {
            emitModelDirty(this);
        }
        return dirty;
    }

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

    } //new

    /** Called right before the object will be serialized. */
    function willSerialize():Void {

    } //willSerialize

    /** Called right after the object has been deserialized. Could be useful to override it to check data integrity
        when running a newer model version etc... */
    function didDeserialize():Void {

    } //didDeserialize

/// Print

    override function toString():String {

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
