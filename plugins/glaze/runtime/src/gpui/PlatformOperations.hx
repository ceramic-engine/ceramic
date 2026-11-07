// Ported from gpui-pre 0.3.10: src/platform.rs (the application part of the
// `Platform` trait: quit, activate, path prompts, menus and their callbacks,
// the dock menu, the window appearance, the scrollbar preference, the app
// identity and system notifications)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.Menu.MenuItem;
import gpui.Menu.OwnedMenu;

/**
 * The application operations of GPUI's `Platform` (`App.platformOperations`):
 * quitting, activating the app, the native path prompts, the application
 * and dock menus, the system appearance and scrollbar preference, the app
 * identity and the system notifications.
 *
 * `gpui.platform.CeramicPlatformOperations` by default (through Ceramic: the
 * app, the screen and the `dialogs` and `notifications` plugins),
 * `TestPlatformOperations` (like
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
    function onQuit(callback:() -> Null<AnyTask>):Void;

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

    /** The callback run when an application menu item is chosen (`Platform::on_app_menu_action`). */
    function onAppMenuAction(callback:(Action) -> Void):Void;

    /** The callback run when an application menu opens (`Platform::on_will_open_app_menu`). */
    function onWillOpenAppMenu(callback:() -> Void):Void;

    /**
     * The callback telling whether the action of an application menu item
     * can run, asked when the platform validates the item
     * (`Platform::on_validate_app_menu_command`).
     */
    function onValidateAppMenuCommand(callback:(Action) -> Bool):Void;

    /**
     * Sets the menu shown when the app icon in the dock is right clicked
     * (`Platform::set_dock_menu`). Its items run the `onAppMenuAction`
     * callback, like the application menu items.
     */
    function setDockMenu(menu:Array<MenuItem>, keymap:Keymap):Void;

    /**
     * Performs the action of the dock menu item at the given index
     * (`Platform::perform_dock_menu_action`, only used on Windows by GPUI).
     */
    function performDockMenuAction(action:Int):Void;

    /** The appearance of the application's windows (`Platform::window_appearance`). */
    function windowAppearance():WindowAppearance;

    /**
     * Whether the user has configured scrollbars to auto-hide at the
     * platform level (`Platform::should_auto_hide_scrollbars`).
     */
    function shouldAutoHideScrollbars():Bool;

    /**
     * Sets the application's process-wide identity and user-visible name
     * (`Platform::set_app_identity`): the Windows AppUserModelID, the name
     * shown with its notifications. Called once, early in startup.
     */
    function setAppIdentity(identifier:String, name:String):Void;

    /**
     * Posts a notification to the operating system's notification center
     * (`Platform::show_system_notification`). A notification whose tag matches
     * an earlier one replaces it where the platform supports it. Nothing
     * happens where notifications are unsupported or not authorized.
     */
    function showSystemNotification(notification:SystemNotification):Void;

    /**
     * Removes the delivered or pending notification with this tag, where the
     * platform can (`Platform::dismiss_system_notification`).
     */
    function dismissSystemNotification(tag:String):Void;

    /**
     * Registers the callback run on the main thread when the user activates a
     * system notification, its body or one of its buttons
     * (`Platform::on_system_notification_response`). A later registration
     * replaces it.
     */
    function onSystemNotificationResponse(callback:(SystemNotificationResponse) -> Void):Void;

}
