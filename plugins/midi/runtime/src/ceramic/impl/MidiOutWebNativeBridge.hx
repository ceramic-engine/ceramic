package ceramic.impl;

class MidiOutWebNativeBridge extends MidiOutBase {

    public function new(name:String) {

        super(name);

        Main.nativeBridgeSend('midiOutInit $index $name');

    }

    override function send(a:Int, b:Int, c:Int):Void {

        Main.nativeBridgeSend('midiOutSend $index $a $b $c');

    }

    override function destroy() {

        Main.nativeBridgeSend('midiOutDestroy $index');

        super.destroy();

    }

}
