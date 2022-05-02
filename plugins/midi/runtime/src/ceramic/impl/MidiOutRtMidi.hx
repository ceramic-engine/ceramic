package ceramic.impl;

import rtmidi.RtMidiOut;

class MidiOutRtMidi extends MidiOutBase {

    var rtMidiOut:RtMidiOut;

    var midiMessage:haxe.io.Bytes = haxe.io.Bytes.alloc(2);

    public function new(name:String) {

        super(name);

        rtMidiOut = new RtMidiOut();
        rtMidiOut.openVirtualPort(name);

    }

    override function send(a:Int, b:Int, c:Int):Void {

        midiMessage.set(0, a);
        midiMessage.set(1, b);
        midiMessage.set(2, c);

        rtMidiOut.sendMessage(midiMessage.getData());

    }

    override function destroy() {

        rtMidiOut.destroy();
        rtMidiOut = null;

        super.destroy();

    }

}
