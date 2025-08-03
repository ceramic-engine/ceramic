package ceramic;

import ceramic.App;
import ceramic.Entity;
import ceramic.Assets;
import ceramic.AssetOptions;
import ceramic.AssetId;
import ceramic.Asset;
import ceramic.Either;

import ceramic.Shortcuts.*;

using StringTools;

/**
 * Plugin initialization for native file dialogs support.
 * 
 * This plugin enables native file dialog functionality in Ceramic applications.
 * It automatically initializes when included in a project, providing access to
 * the Dialogs API for file operations.
 * 
 * The plugin supports:
 * - Native file open dialogs
 * - Native directory selection dialogs
 * - Native file save dialogs
 * - Platform-specific implementations (desktop via linc_dialogs, Electron via IPC)
 * 
 * To use this plugin, add it to your project's ceramic.yml:
 * ```yaml
 * plugins:
 *   - dialogs
 * ```
 * 
 * @see Dialogs For the main dialog API
 * @see DialogsFileFilter For file type filtering
 */
@:access(ceramic.App)
class DialogsPlugin {

/// Init plugin

    /**
     * Static initializer called when the plugin loads.
     * Uses a separate init method for compatibility with modular bundlers.
     */
    static function __init__():Void {

        // Calling a static method inside __init__ makes this snippet
        // compatible with haxe-modular or similar bundling tools
        DialogsPlugin.pluginInit();

    }
    
    /**
     * Plugin initialization logic.
     * Currently empty as the dialogs functionality is self-contained
     * and doesn't require special initialization.
     */
    static function pluginInit() {

        //

    }

}
