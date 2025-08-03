package ceramic.impl;

/**
 * Base implementation for MIDI output interface.
 * 
 * Provides a no-op implementation that can be used on platforms without MIDI support.
 * All methods return safe defaults without performing any actual MIDI operations.
 * Concrete implementations override these methods to provide platform-specific functionality.
 */
class MidiOutBase extends Entity {

    /**
     * Unique identifier for this MIDI output instance.
     * Used to distinguish between multiple MIDI outputs in bridge communications.
     */
    public var index(default, null):Int;

    /** Next available index for MIDI output instances */
    static var _nextIndex:Int = 1;

    /**
     * Creates a new MIDI output instance.
     * Automatically assigns a unique index for identification.
     */
    public function new() {

        super();

        this.index = _nextIndex++;

    }

    /**
     * Returns the number of available MIDI output ports.
     * 
     * @return Number of MIDI ports (0 in base implementation)
     */
    public function numPorts():Int {

        return 0;

    }

    /**
     * Gets the name of a specific MIDI port.
     * 
     * @param port Port index (0-based)
     * @return Port name, or null if port doesn't exist
     */
    public function portName(port:Int):String {

        return null;

    }

    /**
     * Opens a MIDI output port for sending messages.
     * 
     * Only one port can be open at a time. Opening a new port closes any previously open port.
     * 
     * @param port Port index to open (0-based)
     * @return true if port opened successfully, false otherwise
     */
    public function openPort(port:Int):Bool {

        return false;

    }

    /**
     * Creates and opens a virtual MIDI port.
     * 
     * Virtual ports appear as MIDI inputs in other applications.
     * Only supported on some platforms (macOS, Linux with ALSA/JACK).
     * 
     * @param name Display name for the virtual port
     * @return true if virtual port created successfully, false otherwise
     */
    public function openVirtualPort(name:String):Bool {

        return false;

    }

    /**
     * Sends a 3-byte MIDI message.
     * 
     * Most MIDI messages are 3 bytes:
     * - Note On: 0x90-0x9F (status), note (0-127), velocity (0-127)
     * - Note Off: 0x80-0x8F (status), note (0-127), velocity (0-127)
     * - Control Change: 0xB0-0xBF (status), controller (0-127), value (0-127)
     * - Program Change: 0xC0-0xCF (status), program (0-127), unused (0)
     * - Pitch Bend: 0xE0-0xEF (status), LSB (0-127), MSB (0-127)
     * 
     * @param a First byte (status byte including channel)
     * @param b Second byte (data byte 1)
     * @param c Third byte (data byte 2)
     */
    public function send(a:Int, b:Int, c:Int):Void {

        // Not implemented

    }

}
