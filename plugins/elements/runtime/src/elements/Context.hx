package elements;

import ceramic.Assert.assert;
import ceramic.Assets;
import ceramic.Entity;
import ceramic.ReadOnlyMap;
import ceramic.View;
import tracker.Model;
import tracker.Observable;

using tracker.SaveModel;

/**
 * Global context singleton for the elements UI system.
 * 
 * Provides centralized access to:
 * - Theme configuration
 * - User preferences and window states
 * - Root view container
 * - Focused window tracking
 * - Shared assets management
 * 
 * The context automatically persists user data (window positions, sizes, etc.)
 * to local storage and restores it on startup.
 * 
 * Access the singleton instance via `Context.context`.
 * 
 * @see Theme
 * @see UserData
 * @see Window
 */
@:allow(elements.Im)
@:allow(elements.ImSystem)
class Context extends Entity implements Observable {

    /** Global singleton instance of the UI context */
    @lazy public static var context = new Context();

    /** The current UI theme controlling visual appearance */
    @observe public var theme = new Theme();

    /** User preferences and persistent data storage */
    public var user = new UserData();

    /** Read-only map of window data by window ID */
    public var windowsData(get,never):ReadOnlyMap<String,WindowData>;
    inline function get_windowsData():ReadOnlyMap<String,WindowData> {
        return user.windowsData;
    }

    /** The root view container for all UI elements */
    public var view(default, null):View = null;

    /** The currently focused window (receives keyboard input) */
    public var focusedWindow(default, null):Window = null;

    /** Shared assets instance for loading UI resources */
    public var assets(get, default):Assets = null;
    function get_assets():Assets {
        if (this.assets == null) {
            this.assets = new Assets();
        }
        return this.assets;
    }

    /**
     * Private constructor for singleton pattern.
     * Loads persisted user data and sets up auto-save.
     */
    private function new() {

        super();

        user.loadFromKey('elements-context', true);
        user.autoSaveAsKey('elements-context');

    }

/// Helpers

    /**
     * Adds or updates window data in the persistent storage.
     * Window data includes position, size, and other state information.
     * 
     * @param windowData The window data to store (must have non-null id)
     * @throws AssertionError if windowData or windowData.id is null
     */
    public function addWindowData(windowData:WindowData):Void {

        assert(windowData != null, 'Cannot add null window data');
        assert(windowData.id != null, 'Cannot add window data with null id');

        windowsData.original.set(windowData.id, windowData);
        user.dirty = true;

    }

}