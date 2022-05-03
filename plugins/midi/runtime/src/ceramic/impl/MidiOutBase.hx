package ceramic.impl;

class MidiOutBase extends Entity {

    public var index(default, null):Int;

    static var _nextIndex:Int = 1;

    public function new() {

        super();

        this.index = _nextIndex++;

    }

    public function numPorts():Int {

        return 0;

    }

    public function portName(port:Int):String {

        return null;

    }

    public function openPort(port:Int):Bool {

        return false;

    }

    public function openVirtualPort(name:String):Bool {

        return false;

    }

    public function send(a:Int, b:Int, c:Int):Void {

        // Not implemented

    }

}
