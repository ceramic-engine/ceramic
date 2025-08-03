package ceramic.impl;

import rtmidi.RtMidiOut;

/**
 * Native MIDI output implementation using RtMidi library.
 * 
 * Provides real MIDI hardware access on desktop platforms (Windows, macOS, Linux).
 * Uses the cross-platform RtMidi C++ library for reliable MIDI communication.
 * 
 * Features:
 * - Hardware MIDI port enumeration and access
 * - Virtual MIDI port creation (platform-dependent)
 * - Low-latency message sending
 * - Comprehensive error handling
 * 
 * @see https://github.com/thestk/rtmidi
 */
class MidiOutRtMidi extends MidiOutBase {

    /** RtMidi output instance for native MIDI access */
    var rtMidiOut:RtMidiOut;

    /** Reusable buffer for 3-byte MIDI messages */
    var midiMessage:haxe.io.Bytes = haxe.io.Bytes.alloc(3);

    /** Global error flag for error callback handling */
    static var hasError = false;

    /**
     * Creates a new RtMidi output instance.
     * Sets up error handling to log MIDI errors.
     */
    public function new() {

        super();

        rtMidiOut = new RtMidiOut();

        rtMidiOut.setErrorCallback(function(type:rtmidi.RtMidi.ErrorType, message:String, data:cpp.Pointer<cpp.Void>):Void {
            hasError = true;
            ceramic.Shortcuts.log.error(getErrorString(type) + ': ' + message);
        });

    }

    /**
     * Converts RtMidi error type to human-readable string.
     * 
     * @param type RtMidi error type enum
     * @return String representation of the error type
     */
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

    /**
     * Returns the number of available MIDI output ports.
     * Queries the system for hardware and software MIDI devices.
     * 
     * @return Number of available MIDI output ports
     */
    override function numPorts():Int {

        return rtMidiOut.getPortCount();

    }

    /**
     * Gets the name of a specific MIDI port.
     * 
     * @param port Port index (0-based)
     * @return Port name (e.g., "USB MIDI Interface", "IAC Driver Bus 1")
     */
    override function portName(port:Int):String {

        return rtMidiOut.getPortName(port);

    }

    /**
     * Opens a hardware MIDI output port.
     * 
     * @param port Port index to open (0-based)
     * @return true if port opened successfully, false if error occurred
     */
    override function openPort(port:Int):Bool {

        hasError = false;
        rtMidiOut.openPort(port);
        if (hasError) {
            hasError = false;
            return false;
        }
        return true;

    }

    /**
     * Creates and opens a virtual MIDI port.
     * 
     * Virtual ports appear as MIDI inputs in other applications.
     * Supported on macOS (Core MIDI) and Linux (ALSA/JACK).
     * Not supported on Windows.
     * 
     * @param name Display name for the virtual port
     * @return true if port created successfully, false if error or unsupported
     */
    override function openVirtualPort(name:String):Bool {

        hasError = false;
        rtMidiOut.openVirtualPort(name);
        if (hasError) {
            hasError = false;
            return false;
        }
        return true;

    }

    /**
     * Sends a 3-byte MIDI message to the open port.
     * 
     * Message is sent immediately with minimal latency.
     * Port must be opened before sending messages.
     * 
     * @param a Status byte (includes message type and channel)
     * @param b Data byte 1
     * @param c Data byte 2
     */
    override function send(a:Int, b:Int, c:Int):Void {

        midiMessage.set(0, a);
        midiMessage.set(1, b);
        midiMessage.set(2, c);

        rtMidiOut.sendMessage(midiMessage.getData());

    }

    /**
     * Destroys the MIDI output and releases resources.
     * Closes any open ports and frees the RtMidi instance.
     */
    override function destroy() {

        rtMidiOut.destroy();
        rtMidiOut = null;

        super.destroy();

    }

}
