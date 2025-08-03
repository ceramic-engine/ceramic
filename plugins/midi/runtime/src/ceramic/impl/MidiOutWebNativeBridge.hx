package ceramic.impl;

import ceramic.Bridge;

/**
 * Web-to-native MIDI bridge implementation.
 * 
 * Enables MIDI access in web builds by communicating with the native Electron
 * container through IPC messages. The Electron process handles actual MIDI
 * operations and relays results back to the web context.
 * 
 * Communication protocol:
 * - Web → Native: Send MIDI commands via Bridge.send()
 * - Native → Web: Receive port lists and status via Bridge.onReceive()
 * 
 * This allows web builds to access hardware MIDI devices that would normally
 * be inaccessible due to browser security restrictions.
 */
class MidiOutWebNativeBridge extends MidiOutBase {

    /** Cached list of available MIDI port names */
    var ports:Array<String> = [];

    /**
     * Creates a new MIDI bridge instance.
     * Initializes the native MIDI handler and sets up message listeners.
     */
    public function new() {

        super();

        Bridge.shared.send('midiOutInit', '$index');

        bindBridgeReceive();

    }

    /**
     * Sets up bridge message handlers.
     * 
     * Listens for:
     * - 'midiOutPorts': Updates the cached port list when native side enumerates devices
     */
    function bindBridgeReceive() {

        Bridge.shared.onReceive(this, (event, data) -> {

            switch event {
                case 'midiOutPorts':
                    // Parse message format: "<index> <json_array>"
                    var spaceIndex = data.indexOf(' ');
                    var index = Std.parseInt(data.substring(0, spaceIndex));
                    if (index == this.index) {
                        ports = haxe.Json.parse(data.substring(spaceIndex + 1));
                    }
            }

        });

    }

    /**
     * Returns the number of available MIDI ports.
     * 
     * Note: Port list is populated asynchronously. May return 0 initially
     * until the native side responds with the port list.
     * 
     * @return Number of cached MIDI ports
     */
    override function numPorts():Int {

        return ports.length;

    }

    /**
     * Gets the name of a specific MIDI port.
     * 
     * @param port Port index (0-based)
     * @return Port name from cached list, or null if index out of bounds
     */
    override function portName(port:Int):String {

        return ports[port];

    }

    /**
     * Requests the native side to open a MIDI port.
     * 
     * @param port Port index to open (0-based)
     * @return Always returns true (actual success is determined native-side)
     */
    override function openPort(port:Int):Bool {

        Bridge.shared.send('midiOutOpenPort', '$index $port');
        return true;

    }

    /**
     * Requests the native side to create a virtual MIDI port.
     * 
     * @param name Display name for the virtual port
     * @return Always returns true (actual success is determined native-side)
     */
    override function openVirtualPort(name:String):Bool {

        Bridge.shared.send('midiOutOpenVirtualPort','$index $name');
        return true;

    }

    /**
     * Sends a MIDI message through the bridge.
     * 
     * Message is serialized and sent to the native side for transmission.
     * 
     * @param a Status byte
     * @param b Data byte 1  
     * @param c Data byte 2
     */
    override function send(a:Int, b:Int, c:Int):Void {

        Bridge.shared.send('midiOutSend', '$index $a $b $c');

    }

    /**
     * Destroys the MIDI bridge instance.
     * Notifies the native side to clean up resources.
     */
    override function destroy() {

        Bridge.shared.send('midiOutDestroy', '$index');

        super.destroy();

    }

}
