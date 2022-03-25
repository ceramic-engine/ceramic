package elements;

import ceramic.Flags;

abstract EditTextStatus(Int) from Int to Int {

    inline public function new(value:Int) {
        this = value;
    }

    @:to inline public function toBool():Bool {
        return changed;
    }

    public var changed(get,never):Bool;
    inline function get_changed():Bool {
        return Flags.fromInt(this).bool(0);
    }

    public var submitted(get,never):Bool;
    inline function get_submitted():Bool {
        return Flags.fromInt(this).bool(1);
    }

}