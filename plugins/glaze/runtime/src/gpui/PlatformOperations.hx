// Ported from gpui-pre 0.3.10: src/platform.rs (the application part of the
// `Platform` trait: quit, activate, path prompts, menus)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.Menu.OwnedMenu;

/**
 * The application operations of GPUI's `Platform` (`App.platformOperations`):
 * quitting, activating the app, the native path prompts and the application
 * menus.
 *
 * `gpui.platform.CeramicPlatformOperations` by default (through Ceramic: the
 * app, the screen and the `dialogs` plugin), `TestPlatformOperations` (like
 * GPUI's test platform: prompts wait for the test to answer them) in tests.
 */
interface PlatformOperations {

    /**
     * Quits the application (`Platform::quit`). Where the platform quits, it
     * first calls the callback given to `onQuit` (GPUI's `on_quit`, which
     * runs `App.shutdown`).
     */
    function quit():Void;

    /**
     * The callback run when the platform is about to quit (`Platform::on_quit`):
     * the platform quits once the task it returns completes.
     */
    function onQuit(callback:Void->Null<AnyTask>):Void;

    /** Activates the application, bringing it to the foreground (`Platform::activate`). */
    function activate(ignoringOtherApps:Bool):Void;

    /**
     * Shows a modal to choose existing paths (`Platform::prompt_for_paths`):
     * the task resolves with the chosen paths, `null` when cancelled, and
     * fails when no prompt can be shown.
     */
    function promptForPaths(options:PathPromptOptions):Task<Null<Array<String>>>;

    /**
     * Shows a modal to choose a new path to save to, starting in `directory`
     * (`Platform::prompt_for_new_path`): the task resolves with the path,
     * `null` when cancelled, and fails when no prompt can be shown.
     */
    function promptForNewPath(directory:String, suggestedName:Null<String>):Task<Null<String>>;

    /** Whether one path prompt can offer files and directories (`Platform::can_select_mixed_files_and_dirs`). */
    function canSelectMixedFilesAndDirs():Bool;

    /** Sets the application menus (`Platform::set_menus`). */
    function setMenus(menus:Array<Menu>, keymap:Keymap):Void;

    /** The application menus last set, if the platform keeps them (`Platform::get_menus`). */
    function getMenus():Null<Array<OwnedMenu>>;

}
