package ceramic.impl;

class MidiOutBase extends Entity {

    public var name(default, null):String;

    public var index(default, null):Int;

    static var _nextIndex:Int = 1;

    public function new(name:String) {

        super();

        this.name = name;
        this.index = _nextIndex++;

    }

    public function send(a:Int, b:Int, c:Int):Void {

        // Not implemented

    }

}
