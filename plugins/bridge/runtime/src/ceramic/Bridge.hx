package ceramic;

#if (clay && web && ceramic_native_bridge)
import backend.ElectronRunner;
#end

/**
 * Bridge for communication between web and native code in Electron-based applications.
 *
 * This class provides a messaging bridge that allows Ceramic web applications running
 * in Electron to communicate with native code through IPC (Inter-Process Communication).
 * It enables sending and receiving string-based messages between the web renderer
 * process and the Electron main process.
 *
 * The bridge uses a simple protocol where messages consist of an event name
 * optionally followed by a space and data payload.
 *
 * This functionality is only available when:
 * - Using the Clay backend
 * - Running on web platform
 * - The ceramic_native_bridge define is set
 * - Running inside an Electron environment
 *
 * Example usage:
 * ```haxe
 * // Listen for messages from native
 * Bridge.shared.onReceive(this, (event, data) -> {
 *     if (event == "gamepadGyro") {
 *         trace('Gamepad gyro data: $data');
 *     }
 * });
 *
 * // Send message to native
 * Bridge.shared.send("midiOutOpenPort", '$index $port');
 * ```
 *
 * @see ElectronRunner for the Electron integration
 */
class Bridge extends Entity {

    /**
     * Singleton instance of the Bridge.
     * Lazy-initialized on first access.
     */
    @lazy public static var shared = new Bridge();

    /**
     * Event emitted when a message is received from native code.
     * @param event The event name/type of the message
     * @param data Optional data payload as a string
     */
    @event function receive(event:String, ?data:String);

    /**
     * Private constructor - use Bridge.shared to access the singleton instance.
     */
    private function new() {

        super();

        bindReceive();

    }

    /**
     * Sets up the IPC listener to receive messages from the Electron main process.
     * Only functional when running in an Electron environment.
     */
    function bindReceive() {

        #if (clay && web && ceramic_native_bridge)
        if (ElectronRunner.electronRunner != null) {
            var electron:Dynamic = untyped js.Syntax.code("require('electron')");

            electron.ipcRenderer.on('ceramic-native-bridge', function(e, message:String) {

                if (message != null) {
                    var index = message.indexOf(' ');
                    if (index != -1) {
                        var event = message.substring(0, index);
                        var data = message.substring(index + 1);
                        emitReceive(event, data);
                    }
                    else {
                        emitReceive(message);
                    }
                }

            });
        }
        #end

    }

    /**
     * Sends a message to native code through the Electron IPC bridge.
     *
     * Messages are formatted as "event" or "event data" if data is provided.
     * This method only functions when running in an Electron environment.
     *
     * @param event The event name/type to send
     * @param data Optional data payload to send with the event
     */
    public function send(event:String, ?data:String):Void {

        #if (clay && web && ceramic_native_bridge)
        if (ElectronRunner.electronRunner != null) {
            var message = event;
            if (data != null) {
                message += ' ' + data;
            }
            ElectronRunner.electronRunner.ceramicNativeBridgeSend(message);
        }
        #end

    }

}
