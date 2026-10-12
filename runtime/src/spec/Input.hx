package spec;

/**
 * Backend interface for input handling.
 * 
 * This interface is currently empty as input events are handled through
 * the backend's event system and Screen interface. Input events (mouse,
 * touch, keyboard, gamepad) are dispatched directly to the App instance.
 * 
 * The interface exists for potential future extensions and to maintain
 * consistency with the backend architecture where each subsystem has
 * its own interface.
 * 
 * @see ceramic.Input for the main input handling system
 * @see spec.Screen for input event dispatching
 */
interface Input {

    /**
     * Key code produced by the physical key `scanCode` with the current keyboard
     * layout (the letter printed on that key), or `KeyCode.UNKNOWN` when the
     * backend can't tell.
     */
    function keyCodeForScanCode(scanCode:ceramic.ScanCode):ceramic.KeyCode;

}
