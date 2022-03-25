package elements;

import ceramic.Flags;

abstract PromptStatus(Int) from Int to Int {

    inline public function new(value:Int) {
        this = value;
    }

    @:to inline public function toBool():Bool {
        return this >= 0;
    }

    public var canceled(get,never):Bool;
    inline function get_canceled():Bool {
        return this == -2;
    }

    public var complete(get,never):Bool;
    inline function get_complete():Bool {
        return this != -1;
    }

}