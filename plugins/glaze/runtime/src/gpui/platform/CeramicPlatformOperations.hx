// New code for the Haxe port of GPUI: the application operations of GPUI's
// `Platform` (gpui-pre 0.3.10, src/platform.rs, Zed Industries, Apache-2.0)
// implemented with Ceramic. The web behavior follows gpui-pre-web 0.3.10
// src/platform.rs, except the path prompts (deliberate deviation DEV-019).
// See NOTICE.md and DEVIATIONS.md.
package gpui.platform;

import gpui.AnyTask;
import gpui.Keymap;
import gpui.Menu;
import gpui.Menu.OwnedMenu;
import gpui.PathPromptOptions;
import gpui.PlatformOperations;
import gpui.Task;

/**
 * `PlatformOperations` through Ceramic:
 *
 * - `quit` runs the `onQuit` callback (`App.shutdown`), then quits the
 *   Ceramic app (`ceramic.App.quit`) once its task completes. In a browser it only logs a warning,
 *   like GPUI's web platform (a page cannot quit); in Electron it closes
 *   the window.
 * - `activate` activates the app window (`ceramic.Screen.activateWindow`:
 *   SDL's raise window on native targets, which activates the app on macOS;
 *   nothing on the web, like GPUI's web platform, and in headless builds).
 * - The path prompts use the `dialogs` plugin (`ceramic.Dialogs`: SDL's
 *   native file dialogs on desktop, Electron's dialogs). In a browser
 *   (deliberate deviation DEV-019; GPUI's web platform fails them as "not
 *   supported"), `promptForNewPath` gives a download path at once
 *   (`download:<suggested name>`: writing it with `ceramic.Files` starts a
 *   browser download, the browser chooses the folder) and `promptForPaths`
 *   opens the browser's file chooser, which browsers allow only during a
 *   user gesture: from a click or key handler (GPUI dispatches the DOM event
 *   in the next frame, within the browser's activation window) it opens;
 *   otherwise the task fails with an error, like a platform without dialog.
 *   The chosen files are read into memory and returned as picked paths
 *   (`picked:<n>/<name>`) that `ceramic.Files` reads (`ceramic.BrowserFiles`).
 *   Without the plugin, and where it has no dialog (mobile, headless), the
 *   prompts fail like GPUI's web platform ("not supported").
 * - `setMenus` keeps the menus for `getMenus` and installs them as
 *   Ceramic's menu bar (`ceramic.Screen.setMenuBar`), like GPUI's macOS
 *   platform (gpui-pre-macos 0.3.10 src/platform.rs: set_menus,
 *   create_menu_bar, create_menu_item, handle_menu_item,
 *   validate_menu_item, menu_will_open): a native `NSMenu` on macOS (clay
 *   native builds), nothing elsewhere (apps draw their menus in the window
 *   there, gpui-kit's `AppMenuBar`). Items show the first key binding of
 *   their action as their shortcut; choosing one runs the `onAppMenuAction`
 *   callback, validation asks `onValidateAppMenuCommand`, and opening a
 *   menu runs `onWillOpenAppMenu`. A shortcut first goes to the window as a
 *   key down and only runs the item when the window did not handle it.
 */
class CeramicPlatformOperations implements PlatformOperations {

    var quitCallback:Null<() -> Null<AnyTask>> = null;

    var menus:Null<Array<OwnedMenu>> = null;

    public function new() {}

    public function quit():Void {
        #if web
        #if ceramic_use_electron
        final canQuit = ceramic.Platform.electronRemote() != null;
        #else
        final canQuit = false;
        #end
        if (!canQuit) {
            ceramic.Shortcuts.log.warning('quit called, but quitting is not supported in the browser');
            return;
        }
        #end
        final shutdown = quitCallback != null ? quitCallback() : null;
        if (shutdown == null)
            ceramic.App.app.quit();
        else
            shutdown.onComplete(() -> ceramic.App.app.quit());
    }

    public function onQuit(callback:() -> Null<AnyTask>):Void {
        quitCallback = callback;
    }

    public function activate(ignoringOtherApps:Bool):Void {
        final app = ceramic.App.app;
        if (app != null && app.screen != null)
            app.screen.activateWindow();
    }

    public function promptForPaths(options:PathPromptOptions):Task<Null<Array<String>>> {
        #if plugin_dialogs
        final task = new Task<Null<Array<String>>>();
        ceramic.Dialogs.choosePaths({
            prompt: options.prompt,
            files: options.files,
            directories: options.directories,
            multiple: options.multiple
        }, (paths, error) -> {
            if (error != null)
                task.reject(error);
            else
                task.resolve(paths);
        });
        return task;
        #else
        return Task.failed('prompt_for_paths needs the Ceramic dialogs plugin');
        #end
    }

    public function promptForNewPath(directory:String, suggestedName:Null<String>):Task<Null<String>> {
        #if plugin_dialogs
        final task = new Task<Null<String>>();
        ceramic.Dialogs.chooseNewPath({
            directory: directory,
            defaultName: suggestedName
        }, (path, error) -> {
            if (error != null)
                task.reject(error);
            else
                task.resolve(path);
        });
        return task;
        #else
        return Task.failed('prompt_for_new_path needs the Ceramic dialogs plugin');
        #end
    }

    public function canSelectMixedFilesAndDirs():Bool {
        #if plugin_dialogs
        return ceramic.Dialogs.canSelectMixedFilesAndDirectories();
        #else
        return false;
        #end
    }

    public function setMenus(menus:Array<Menu>, keymap:Keymap):Void {
        final app = ceramic.App.app;
        if (app != null && app.screen != null) {
            final menuBar = menuBarItems(menus, keymap);
            menuBarOwner = this;
            final screen = app.screen;
            if (!menuBarBound) {
                menuBarBound = true;
                screen.onMenuAction(null, item -> {
                    if (menuBarOwner != null)
                        menuBarOwner.handleMenuItem(item);
                });
                screen.onMenuWillOpen(null, () -> {
                    if (menuBarOwner != null)
                        menuBarOwner.menuWillOpen();
                });
            }
            screen.menuItemValidator = item -> menuBarOwner != null && menuBarOwner.validateMenuItem(item);
            screen.setMenuBar(menuBar);
        }
        this.menus = [for (menu in menus) menu.owned()];
    }

    public function getMenus():Null<Array<OwnedMenu>> {
        return menus;
    }

    var menuCommand:Null<(gpui.Action) -> Void> = null;

    var validateMenuCommand:Null<(gpui.Action) -> Bool> = null;

    var willOpenMenu:Null<() -> Void> = null;

    /** The operations that installed the current Ceramic menu bar (one per Ceramic app). */
    static var menuBarOwner:Null<CeramicPlatformOperations> = null;

    static var menuBarBound:Bool = false;

    public function onAppMenuAction(callback:(gpui.Action) -> Void):Void {
        menuCommand = callback;
    }

    public function onWillOpenAppMenu(callback:() -> Void):Void {
        willOpenMenu = callback;
    }

    public function onValidateAppMenuCommand(callback:(gpui.Action) -> Bool):Void {
        validateMenuCommand = callback;
    }

    /** Rust `handle_menu_item`: the action of the item goes to the menu command callback. */
    function handleMenuItem(item:ceramic.MenuItem):Void {
        final action:Null<gpui.Action> = Std.isOfType(item.data, gpui.Action) ? cast item.data : null;
        if (action != null && menuCommand != null) {
            menuCommand(action.boxedClone());
        }
    }

    /** Rust `validate_menu_item`: false without a callback or an action. */
    function validateMenuItem(item:ceramic.MenuItem):Bool {
        final action:Null<gpui.Action> = Std.isOfType(item.data, gpui.Action) ? cast item.data : null;
        if (action != null && validateMenuCommand != null) {
            return validateMenuCommand(action.boxedClone());
        }
        return false;
    }

    /** Rust `menu_will_open`. */
    function menuWillOpen():Void {
        if (willOpenMenu != null) {
            willOpenMenu();
        }
    }

    /**
     * The Ceramic menu bar for GPUI's menus (Rust `create_menu_bar`): one
     * submenu per menu (the one named "Window" is the Window menu), whose
     * items carry their action in `data`.
     */
    public static function menuBarItems(menus:Array<Menu>, keymap:Keymap):Array<ceramic.MenuItem> {
        final result:Array<ceramic.MenuItem> = [];
        for (menu in menus) {
            final submenu = ceramic.MenuItem.submenu(menu.name, [for (item in menu.items) menuItem(item, keymap)]);
            if (menu.name == 'Window') {
                submenu.role = WINDOW;
            }
            result.push(submenu);
        }
        return result;
    }

    static var defaultContext:Null<Array<gpui.KeyContext>> = null;

    /**
     * Rust `create_menu_item`: the shortcut is the first binding of the
     * action (earlier bindings, unlike the usual display precedence) whose
     * predicate matches a Workspace > Pane > Editor context on macOS, or the
     * first binding; only single keystrokes are shown.
     */
    static function menuItem(item:MenuItem, keymap:Keymap):ceramic.MenuItem {
        return switch item {
            case Separator:
                ceramic.MenuItem.separator();
            case Action(name, action, osAction, checked, disabled):
                final result = ceramic.MenuItem.action(name);
                final keystrokes = menuKeystrokes(action, keymap);
                if (keystrokes != null && keystrokes.length == 1) {
                    final keystroke = keystrokes[0];
                    final modifiers = keystroke.modifiers();
                    var mask:Int = 0;
                    if (modifiers.platform) mask |= ceramic.KeyModifiers.META;
                    if (modifiers.control) mask |= ceramic.KeyModifiers.CTRL;
                    if (modifiers.alt) mask |= ceramic.KeyModifiers.ALT;
                    if (modifiers.shift) mask |= ceramic.KeyModifiers.SHIFT;
                    result.key = keystroke.key();
                    result.modifiers = mask;
                }
                result.role = osAction == null ? ceramic.MenuItemRole.NONE : switch osAction {
                    case Cut: ceramic.MenuItemRole.CUT;
                    case Copy: ceramic.MenuItemRole.COPY;
                    case Paste: ceramic.MenuItemRole.PASTE;
                    case SelectAll: ceramic.MenuItemRole.SELECT_ALL;
                    case Undo: ceramic.MenuItemRole.UNDO;
                    case Redo: ceramic.MenuItemRole.REDO;
                };
                result.checked = checked;
                result.enabled = !disabled;
                result.data = action;
                result;
            case Submenu(menu):
                final result = ceramic.MenuItem.submenu(menu.name, [for (child in menu.items) menuItem(child, keymap)]);
                result.enabled = !menu.disabled;
                result;
            case SystemMenu(osMenu):
                switch osMenu.menuType {
                    case Services: ceramic.MenuItem.services(osMenu.name);
                }
        }
    }

    static function menuKeystrokes(action:gpui.Action, keymap:Keymap):Null<Array<gpui.KeybindingKeystroke>> {
        final bindings = keymap.bindingsForAction(action);
        if (bindings.length == 0) {
            return null;
        }
        if (defaultContext == null) {
            final workspaceContext = gpui.KeyContext.newWithDefaults(Mac);
            workspaceContext.add('Workspace');
            final paneContext = gpui.KeyContext.newWithDefaults(Mac);
            paneContext.add('Pane');
            final editorContext = gpui.KeyContext.newWithDefaults(Mac);
            editorContext.add('Editor');
            paneContext.extend(editorContext);
            workspaceContext.extend(paneContext);
            defaultContext = [workspaceContext];
        }
        for (binding in bindings) {
            final predicate = binding.predicate();
            if (predicate == null || gpui.KeyBindingContextPredicateTools.eval(predicate, defaultContext)) {
                return binding.keystrokes;
            }
        }
        return bindings[0].keystrokes;
    }

}
