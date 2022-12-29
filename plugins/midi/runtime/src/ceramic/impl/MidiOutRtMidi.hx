package ceramic.impl;

import rtmidi.RtMidiOut;

class MidiOutRtMidi extends MidiOutBase {

    var rtMidiOut:RtMidiOut;

    var midiMessage:haxe.io.Bytes = haxe.io.Bytes.alloc(3);

    static var hasError = false;

    public function new() {

        super();

        rtMidiOut = new RtMidiOut();

        rtMidiOut.setErrorCallback(function(type:rtmidi.RtMidi.ErrorType, message:String, data:cpp.Pointer<cpp.Void>):Void {
            hasError = true;
            ceramic.Shortcuts.log.error(getErrorString(type) + ': ' + message);
        });

    }

    static function getErrorString(type:rtmidi.RtMidi.ErrorType):String {
        switch type {
            case WARNING:
                return 'WARNING';
            case DEBUG_WARNING:
                return 'DEBUG_WARNING';
            case UNSPECIFIED:
                return 'UNSPECIFIED';
            case NO_DEVICES_FOUND:
                return 'NO_DEVICES_FOUND';
            case INVALID_DEVICE:
                return 'INVALID_DEVICE';
            case MEMORY_ERROR:
                return 'MEMORY_ERROR';
            case INVALID_PARAMETER:
                return 'INVALID_PARAMETER';
            case INVALID_USE:
                return 'INVALID_USE';
            case DRIVER_ERROR:
                return 'DRIVER_ERROR';
            case SYSTEM_ERROR:
                return 'SYSTEM_ERROR';
            case THREAD_ERROR:
                return 'THREAD_ERROR';
        }
    }

    override function numPorts():Int {

        return rtMidiOut.getPortCount();

    }

    override function portName(port:Int):String {

        return rtMidiOut.getPortName(port);

    }

    override function openPort(port:Int):Bool {

        hasError = false;
        rtMidiOut.openPort(port);
        if (hasError) {
            hasError = false;
            return false;
        }
        return true;

    }

    override function openVirtualPort(name:String):Bool {

        hasError = false;
        rtMidiOut.openVirtualPort(name);
        if (hasError) {
            hasError = false;
            return false;
        }
        return true;

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
