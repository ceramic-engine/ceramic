package ceramic.impl;

import ceramic.Bridge;

class MidiOutWebNativeBridge extends MidiOutBase {

    var ports:Array<String> = [];

    public function new() {

        super();

        Bridge.shared.send('midiOutInit', '$index');

        bindBridgeReceive();

    }

    function bindBridgeReceive() {

        Bridge.shared.onReceive(this, (event, data) -> {

            switch event {
                case 'midiOutPorts':
                    var spaceIndex = data.indexOf(' ');
                    var index = Std.parseInt(data.substring(0, spaceIndex));
                    if (index == this.index) {
                        ports = haxe.Json.parse(data.substring(spaceIndex + 1));
                    }
            }

        });

    }

    override function numPorts():Int {

        return ports.length;

    }

    override function portName(port:Int):String {

        return ports[port];

    }

    override function openPort(port:Int):Bool {

        Bridge.shared.send('midiOutOpenPort', '$index $port');
        return true;

    }

    override function openVirtualPort(name:String):Bool {

        Bridge.shared.send('midiOutOpenVirtualPort','$index $name');
        return true;

    }

    override function send(a:Int, b:Int, c:Int):Void {

        Bridge.shared.send('midiOutSend', '$index $a $b $c');

    }

    override function destroy() {

        Bridge.shared.send('midiOutDestroy', '$index');

        super.destroy();

    }

}
