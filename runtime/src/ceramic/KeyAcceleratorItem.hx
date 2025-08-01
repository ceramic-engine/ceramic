package ceramic;

import ceramic.ScanCode;
import ceramic.KeyCode;

/**
 * Represents a component of a keyboard shortcut combination.
 * 
 * KeyAcceleratorItem is used to build keyboard shortcuts by combining
 * modifier keys (Shift, Cmd/Ctrl) with regular keys. This allows for
 * cross-platform keyboard shortcuts that adapt to the operating system
 * (Cmd on macOS, Ctrl on Windows/Linux).
 * 
 * Example combinations:
 * - Ctrl+S: [CMD_OR_CTRL, KEY(KeyCode.KEY_S)]
 * - Shift+Tab: [SHIFT, KEY(KeyCode.TAB)]
 * - Ctrl+Shift+Z: [CMD_OR_CTRL, SHIFT, KEY(KeyCode.KEY_Z)]
 * 
 * @see KeyBinding
 * @see KeyBindings
 */
enum KeyAcceleratorItem {

    /**
     * Represents the Shift modifier key.
     * Used for uppercase letters and secondary key functions.
     */
    SHIFT;

    /**
     * Represents Command key on macOS or Control key on other platforms.
     * Automatically adapts to the current operating system for consistent shortcuts.
     */
    CMD_OR_CTRL;

    /**
     * Represents a regular key identified by its scan code.
     * Scan codes are layout-independent (physical key position).
     * @param scanCode The scan code of the key
     */
    SCAN(scanCode:ScanCode);

    /**
     * Represents a regular key identified by its key code.
     * Key codes are layout-dependent (varies with keyboard layout).
     * @param keyCode The key code of the key
     */
    KEY(keyCode:KeyCode);

}
