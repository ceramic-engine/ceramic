package ceramic;

/**
 * Platform-specific MIDI output interface.
 * 
 * Provides a unified API for sending MIDI messages across different platforms:
 * - Native desktop (Mac, Windows, Linux): Uses RtMidi library for real hardware access
 * - Web with bridge: Uses Electron bridge to access native MIDI through IPC
 * - Other platforms: Falls back to no-op base implementation
 * 
 * ```haxe
 * var midi = new MidiOut();
 * 
 * // List available MIDI ports
 * for (i in 0...midi.numPorts()) {
 *     trace('Port $i: ${midi.portName(i)}');
 * }
 * 
 * // Open first available port
 * if (midi.openPort(0)) {
 *     // Send Note On (channel 1, middle C, velocity 64)
 *     midi.send(0x90, 60, 64);
 *     
 *     // Send Note Off after delay
 *     Timer.delay(null, 1.0, () -> {
 *         midi.send(0x80, 60, 0);
 *     });
 * }
 * ```
 */
#if (cpp && (mac || windows || linux))
typedef MidiOut = ceramic.impl.MidiOutRtMidi;
#elseif (clay && web && plugin_bridge)
typedef MidiOut = ceramic.impl.MidiOutWebNativeBridge;
#else
typedef MidiOut = ceramic.impl.MidiOutBase;
#end
