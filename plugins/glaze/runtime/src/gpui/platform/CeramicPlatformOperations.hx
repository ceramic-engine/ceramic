// New code for the Haxe port of GPUI: the application operations of GPUI's
// `Platform` (gpui-pre 0.3.10, src/platform.rs, Zed Industries, Apache-2.0)
// implemented with Ceramic. The web behavior follows gpui-pre-web 0.3.10
// src/platform.rs, except the path prompts (deliberate deviation DEV-019).
// The system notifications follow gpui-pre-macos 0.3.10
// src/system_notifications.rs (request the authorization on the first post),
// gpui-pre-linux and gpui-pre-windows 0.3.10 (src/linux/system_notifications.rs,
// src/system_notifications.rs) through Ceramic's notifications plugin, also
// in a browser (deliberate deviation DEV-021, gpui-pre-web has none).
// See NOTICE.md and DEVIATIONS.md.
package gpui.platform;

import gpui.AnyTask;
import gpui.Keymap;
import gpui.Menu;
import gpui.Menu.OwnedMenu;
import gpui.PathPromptOptions;
import gpui.PlatformOperations;
import gpui.Task;
import gpui.WindowAppearance;

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
 * - `setDockMenu` installs Ceramic's dock menu (`ceramic.Screen.setDockMenu`),
 *   like GPUI's macOS platform (`set_dock_menu`, `create_dock_menu`,
 *   `handle_dock_menu`): a native `NSMenu` given by the application
 *   delegate on macOS, nothing elsewhere. Its items run the
 *   `onAppMenuAction` callback and are validated like the menu bar items.
 *   `performDockMenuAction` does nothing (GPUI only uses it on Windows).
 * - `windowAppearance` is Ceramic's system appearance
 *   (`ceramic.Screen.systemAppearance`: the effective appearance of the
 *   application on macOS like GPUI's, the system theme through SDL on
 *   Windows and Linux, `prefers-color-scheme` on the web like gpui-pre-web).
 * - `shouldAutoHideScrollbars` is Ceramic's scrollbar preference
 *   (`ceramic.Screen.autoHideScrollbars`: the preferred scroller style on
 *   macOS like GPUI's, true on the web like gpui-pre-web).
 * - The system notifications use the `notifications` plugin
 *   (`ceramic.Notifications`): `UNUserNotificationCenter` on macOS (the app
 *   must run from its signed bundle), the freedesktop notification service
 *   over DBus on Linux, toasts on Windows with the AppUserModelID given to
 *   `setAppIdentity` (posts are dropped until it is set, like GPUI's Windows
 *   platform), the recording backend in headless builds. Like GPUI's
 *   macOS platform, the first post asks the user for the authorization
 *   (once); the posts made while the answer is pending are posted when it
 *   comes. A response listener starts the notification
 *   center (GPUI's macOS platform initializes it on the first
 *   `on_system_notification_response` too); the responses go to the last
 *   operations that registered a callback (one platform per process in
 *   GPUI). Without the plugin and on Unity, the calls do nothing, like a
 *   GPUI platform without notifications.
 * - In a browser (deliberate deviation DEV-021; gpui-pre-web has no system
 *   notifications), the notifications are the browser's (Notification API,
 *   through the plugin). Browsers ask for the permission only during a user
 *   gesture: a first post made from a click or key handler (GPUI dispatches
 *   the DOM event in the next frame, within the browser's activation
 *   window) asks, and the posts made while the answer is pending are posted
 *   when it comes. A post made outside of a gesture while the permission is
 *   not determined asks nobody and is dropped (Ceramic answers
 *   `NOT_DETERMINED` without asking the browser). The question stays open
 *   while the answer is `NOT_DETERMINED` (outside of a gesture, or a prompt
 *   closed without a choice): the next post asks again. Action buttons need
 *   a service worker: a page shows the notification without them, and a
 *   click on it is the response with a null action id (the browser focuses
 *   the page). The same tag replaces the notification, `dismiss` closes it.
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
            bindMenuEvents(screen);
            screen.menuItemValidator = validateCeramicMenuItem;
            screen.setMenuBar(menuBar);
        }
        this.menus = [for (menu in menus) menu.owned()];
    }

    public function getMenus():Null<Array<OwnedMenu>> {
        return menus;
    }

    public function setDockMenu(menu:Array<MenuItem>, keymap:Keymap):Void {
        final app = ceramic.App.app;
        if (app != null && app.screen != null) {
            bindMenuEvents(app.screen);
            dockMenuOwner = this;
            app.screen.menuItemValidator = validateCeramicMenuItem;
            app.screen.setDockMenu([for (item in menu) menuItem(item, keymap)]);
        }
    }

    /** GPUI's default (`Platform::perform_dock_menu_action`): nothing outside Windows. */
    public function performDockMenuAction(action:Int):Void {}

    public function windowAppearance():WindowAppearance {
        final app = ceramic.App.app;
        if (app == null || app.screen == null)
            return Light;
        return WindowAppearance.fromCeramic(app.screen.systemAppearance);
    }

    public function shouldAutoHideScrollbars():Bool {
        final app = ceramic.App.app;
        return app != null && app.screen != null && app.screen.autoHideScrollbars;
    }

    var menuCommand:Null<(gpui.Action) -> Void> = null;

    var validateMenuCommand:Null<(gpui.Action) -> Bool> = null;

    var willOpenMenu:Null<() -> Void> = null;

    /** The operations that installed the current Ceramic menu bar (one per Ceramic app). */
    static var menuBarOwner:Null<CeramicPlatformOperations> = null;

    /** The operations that installed the current Ceramic dock menu. */
    static var dockMenuOwner:Null<CeramicPlatformOperations> = null;

    static var menuBarBound:Bool = false;

    /**
     * Listens to Ceramic's menu events once: an item goes to the operations
     * that installed its menu (Rust: the platform's `menu_command`, shared by
     * the menu bar and the dock menu), opening a menu to those of the menu
     * bar, or of the dock menu without menu bar.
     */
    static function bindMenuEvents(screen:ceramic.Screen):Void {
        if (menuBarBound)
            return;
        menuBarBound = true;
        screen.onMenuAction(null, item -> {
            final owner = ownerOf(item);
            if (owner != null)
                owner.handleMenuItem(item);
        });
        screen.onMenuWillOpen(null, () -> {
            final owner = menuBarOwner != null ? menuBarOwner : dockMenuOwner;
            if (owner != null)
                owner.menuWillOpen();
        });
    }

    static function ownerOf(item:ceramic.MenuItem):Null<CeramicPlatformOperations> {
        final screen = ceramic.App.app.screen;
        if (dockMenuOwner != null && screen.dockMenu != null && containsItem(screen.dockMenu, item))
            return dockMenuOwner;
        return menuBarOwner;
    }

    static function containsItem(items:Array<ceramic.MenuItem>, item:ceramic.MenuItem):Bool {
        for (candidate in items) {
            if (candidate == item)
                return true;
            if (candidate.items != null && containsItem(candidate.items, item))
                return true;
        }
        return false;
    }

    static function validateCeramicMenuItem(item:ceramic.MenuItem):Bool {
        final owner = ownerOf(item);
        return owner != null && owner.validateMenuItem(item);
    }

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

/// System notifications

    var systemNotificationResponseCallback:Null<(SystemNotificationResponse) -> Void> = null;

    #if plugin_notifications

    /** Whether the user was asked for the authorization (GPUI's `authorization_requested`). */
    static var authorizationRequested:Bool = false;

    /** Posts waiting for the answer of the user, null once answered. */
    static var postsAwaitingAuthorization:Null<Array<SystemNotification>> = null;

    /** The operations whose callback gets the responses (the last to register one: one platform per process in GPUI). */
    static var systemNotificationResponder:Null<CeramicPlatformOperations> = null;

    static var listeningSystemNotifications:Bool = false;

    /**
     * Whether a `NOT_DETERMINED` answer leaves the question open, so that the
     * next post asks again (DEV-021, in a browser: a request outside of a user
     * gesture asks nobody, and a prompt closed without a choice decides
     * nothing). Elsewhere the first post asks once, like GPUI's macOS
     * platform. Tests may change it.
     */
    static var askAgainWhileNotDetermined:Bool = #if web true #else false #end;

    #end

    /** The process identity (Windows AppUserModelID, name shown on Linux and Windows). */
    public function setAppIdentity(identifier:String, name:String):Void {
        #if plugin_notifications
        ceramic.Notifications.shared.setAppIdentity(identifier, name);
        #end
    }

    public function showSystemNotification(notification:SystemNotification):Void {
        #if plugin_notifications
        final notifications = ceramic.Notifications.shared;
        if (!notifications.isAvailable())
            return;
        if (!authorizationRequested) {
            // gpui-pre-macos `request_authorization` (once, on the first post)
            authorizationRequested = true;
            postsAwaitingAuthorization = [notification.clone()];
            notifications.requestAuthorization(authorization -> {
                final posts = postsAwaitingAuthorization;
                postsAwaitingAuthorization = null;
                if (askAgainWhileNotDetermined && authorization == ceramic.NotificationAuthorization.NOT_DETERMINED)
                    authorizationRequested = false;
                if (posts != null) {
                    for (post in posts)
                        postSystemNotification(post);
                }
            });
            return;
        }
        if (postsAwaitingAuthorization != null) {
            postsAwaitingAuthorization.push(notification.clone());
            return;
        }
        postSystemNotification(notification);
        #end
    }

    #if plugin_notifications
    static function postSystemNotification(notification:SystemNotification):Void {
        ceramic.Notifications.shared.show({
            tag: notification.tag,
            title: notification.title,
            body: notification.body,
            actions: [for (action in notification.actions) {id: action.id, label: action.label}]
        });
    }
    #end

    public function dismissSystemNotification(tag:String):Void {
        #if plugin_notifications
        if (postsAwaitingAuthorization != null) {
            var i = postsAwaitingAuthorization.length - 1;
            while (i >= 0) {
                if (postsAwaitingAuthorization[i].tag == tag)
                    postsAwaitingAuthorization.splice(i, 1);
                i--;
            }
        }
        ceramic.Notifications.shared.dismiss(tag);
        #end
    }

    public function onSystemNotificationResponse(callback:(SystemNotificationResponse) -> Void):Void {
        systemNotificationResponseCallback = callback;
        #if plugin_notifications
        systemNotificationResponder = this;
        if (!listeningSystemNotifications) {
            listeningSystemNotifications = true;
            ceramic.Notifications.shared.onResponse(null, (tag, actionId) -> {
                if (systemNotificationResponder != null)
                    systemNotificationResponder.handleSystemNotificationResponse(new SystemNotificationResponse(tag, actionId));
            });
        }
        #end
    }

    /**
     * Runs the response callback, taken out for the call like GPUI's
     * platforms do: it may re-enter the platform (dismiss the notification
     * it was told about) or replace itself.
     */
    function handleSystemNotificationResponse(response:SystemNotificationResponse):Void {
        final callback = systemNotificationResponseCallback;
        systemNotificationResponseCallback = null;
        if (callback != null) {
            callback(response);
            if (systemNotificationResponseCallback == null)
                systemNotificationResponseCallback = callback;
        }
    }

}
