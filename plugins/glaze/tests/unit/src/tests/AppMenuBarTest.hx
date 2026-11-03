// New tests for the Haxe port of GPUI: the application menu bar over Ceramic.
// Expected behaviors follow gpui-pre 0.3.10 src/platform/app_menu.rs
// (init_app_menus), src/app.rs (is_action_available, dispatch_action,
// clear_pending_keystrokes) and gpui-pre-macos 0.3.10 src/platform.rs
// (create_menu_bar, create_menu_item, handle_menu_item, validate_menu_item,
// menu_will_open) and src/window.rs (handle_key_event: the window gets a key
// equivalent before the menu) (Zed Industries, Apache-2.0). See NOTICE.md.
package tests;

import gpui.Action;
import gpui.App;
import gpui.Context;
import gpui.FocusHandle;
import gpui.GpuiInput;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Menu;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.TestPlatformOperations;
import gpui.Window;
import gpui.platform.CeramicPlatformOperations;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.Menu.MenuItemTools;

/**
 * `App.setMenus` builds Ceramic's menu bar like GPUI's macOS platform builds
 * its `NSMenu` (shortcuts from the keymap, standard edit roles, the Window
 * and Services menus), menu items dispatch their action to the active
 * window, validation asks whether the action is available, opening a menu
 * clears the pending keystrokes, and a shortcut goes to the window first:
 * the menu item only runs when the window did not handle the key.
 *
 * The Ceramic side is driven like a backend does: `menuAction`,
 * `menuKeyEquivalent` (right after the key down of the same keystroke) and
 * `menuWillOpen` emitted on the backend screen, then Ceramic's queued input
 * callbacks run. Natively (clay on macOS), the real `NSMenu` is checked too.
 */
class AppMenuBarTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    final menuActions:Array<String> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        menuActions.resize(0);
        ceramic.App.app.screen.onMenuAction(null, recordMenuAction);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        final screen = ceramic.App.app.screen;
        screen.offMenuAction(recordMenuAction);
        for (cx in contexts) {
            GpuiInput.unbind(cx.window);
            cx.destroy();
        }
        contexts.resize(0);
        @:privateAccess CeramicPlatformOperations.menuBarOwner = null;
        screen.menuItemValidator = null;
        screen.setMenuBar([]);
        ceramic.App.app.flushImmediate();
    }

    function recordMenuAction(item:ceramic.MenuItem):Void {
        menuActions.push(item.title);
    }

/// Menu bar model (create_menu_bar, create_menu_item)

    function testMenuBarFromMenus() {
        app.bindKeys([
            new KeyBinding('cmd-q', new Quit(), null),
            new KeyBinding('cmd-c', new CopyText(), null),
            new KeyBinding('cmd-shift-z', new RedoEdit(), null),
            new KeyBinding('ctrl-alt-f5', new Export(), null),
        ]);
        final items = CeramicPlatformOperations.menuBarItems([
            new Menu('Story').withItems([
                MenuItemTools.action('Quit', new Quit()),
                MenuItemTools.separator(),
                MenuItemTools.osSubmenu('Services', Services),
            ]),
            new Menu('Edit').withItems([
                MenuItemTools.osAction('Copy', new CopyText(), Copy),
                MenuItemTools.osAction('Redo', new RedoEdit(), Redo),
                MenuItemTools.action('Export', new Export()).checked(true).disabled(true),
                MenuItemTools.submenu(new Menu('More').withItems([MenuItemTools.action('Save', new Save())]).withDisabled(true)),
            ]),
            new Menu('Window').withDisabled(true),
        ], app.keyBindings());

        assertEquals('Story,Edit,Window', [for (item in items) item.title].join(','));
        for (item in items) {
            assertEquals(ceramic.MenuItemKind.SUBMENU, item.kind);
            // GPUI ignores `disabled` on top level menus
            assertTrue(item.enabled);
        }
        assertEquals(ceramic.MenuItemRole.NONE, items[0].role);
        assertEquals(ceramic.MenuItemRole.WINDOW, items[2].role);

        final story = items[0].items;
        assertEquals(3, story.length);
        assertEquals('Quit', story[0].title);
        assertEquals('q', story[0].key);
        assertEquals((ceramic.KeyModifiers.META:Int), (story[0].modifiers:Int));
        assertTrue(Std.isOfType(story[0].data, Quit));
        assertEquals(ceramic.MenuItemKind.SEPARATOR, story[1].kind);
        assertEquals(ceramic.MenuItemKind.SERVICES, story[2].kind);
        assertEquals('Services', story[2].title);

        final edit = items[1].items;
        assertEquals(ceramic.MenuItemRole.COPY, edit[0].role);
        assertEquals('c', edit[0].key);
        assertEquals(ceramic.MenuItemRole.REDO, edit[1].role);
        assertEquals('z', edit[1].key);
        assertEquals((ceramic.KeyModifiers.META | ceramic.KeyModifiers.SHIFT:Int), (edit[1].modifiers:Int));
        assertEquals('f5', edit[2].key);
        assertEquals((ceramic.KeyModifiers.CTRL | ceramic.KeyModifiers.ALT:Int), (edit[2].modifiers:Int));
        assertTrue(edit[2].checked);
        assertFalse(edit[2].enabled);
        assertEquals(ceramic.MenuItemKind.SUBMENU, edit[3].kind);
        assertFalse(edit[3].enabled);
        assertEquals('Save', edit[3].items[0].title);
        assertNull(edit[3].items[0].key);
        assertEquals(ceramic.MenuItemRole.NONE, edit[3].items[0].role);
    }

    function testShortcutIsTheEarliestBindingMatchingTheDefaultContext() {
        app.bindKeys([
            new KeyBinding('cmd-1', new Save(), 'Terminal'),
            new KeyBinding('cmd-2', new Save(), 'Editor'),
            new KeyBinding('cmd-3', new Save(), null),
            new KeyBinding('cmd-4', new Export(), 'Terminal'),
            new KeyBinding('cmd-5', new Export(), 'Terminal'),
            new KeyBinding('cmd-k cmd-s', new Quit(), null),
        ]);
        final items = CeramicPlatformOperations.menuBarItems([
            new Menu('File').withItems([
                MenuItemTools.action('Save', new Save()),
                MenuItemTools.action('Export', new Export()),
                MenuItemTools.action('Quit', new Quit()),
                MenuItemTools.action('Copy', new CopyText()),
            ])
        ], app.keyBindings());
        final file = items[0].items;
        // Workspace > Pane > Editor on macOS: "Editor" matches, "Terminal" does not
        assertEquals('2', file[0].key);
        // No binding matches the context: the first one
        assertEquals('4', file[1].key);
        // Several keystrokes: no shortcut
        assertNull(file[2].key);
        assertEquals((ceramic.KeyModifiers.NONE:Int), (file[2].modifiers:Int));
        // No binding
        assertNull(file[3].key);
    }

    function testSetMenusInstallsTheCeramicMenuBar() {
        app.bindKeys([new KeyBinding('cmd-s', new Save(), null)]);
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Save', new Save())])]);
        final menuBar = ceramic.App.app.screen.menuBar;
        assertEquals(1, menuBar.length);
        assertEquals('File', menuBar[0].title);
        assertEquals('Save', menuBar[0].items[0].title);
        assertEquals('s', menuBar[0].items[0].key);
        assertTrue(menuBar[0].items[0].id > 0);
        // Still kept for getMenus
        assertEquals('File', app.getMenus()[0].name);
    }

/// Menu actions and validation (init_app_menus)

    function testChoosingAnItemDispatchesItsActionToTheActiveWindow() {
        final log:Array<String> = [];
        openMenuView(log);
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Save', new Save())])]);

        emitMenuAction(findItem('Save'));
        assertEquals('Save', menuActions.join(','));
        assertEquals('Editor Save', log.join(','));
    }

    function testChoosingAnItemWithoutWindowDispatchesAGlobalAction() {
        final log:Array<String> = [];
        app.onAction(Export, (_, _) -> log.push('global Export'));
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Export', new Export())])]);
        emitMenuAction(findItem('Export'));
        assertEquals('global Export', log.join(','));
    }

    function testValidationAsksWhetherTheActionIsAvailable() {
        final log:Array<String> = [];
        openMenuView(log);
        app.setMenus([new Menu('File').withItems([
            MenuItemTools.action('Save', new Save()),
            MenuItemTools.action('Export', new Export()),
            // Disabled is ignored by GPUI's macOS validation: only the action counts
            MenuItemTools.action('Save Disabled', new Save()).disabled(true),
            MenuItemTools.action('Quit', new Quit()),
        ])]);
        assertTrue(isEnabled(findItem('Save')));
        assertFalse(isEnabled(findItem('Export')));
        assertTrue(isEnabled(findItem('Save Disabled')));
        assertFalse(isEnabled(findItem('Quit')));

        // Global listeners make an action available
        app.onAction(Quit, (_, _) -> {});
        assertTrue(isEnabled(findItem('Quit')));
    }

    function testTestPlatformCallbacks() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        final log:Array<String> = [];
        assertFalse(platform.simulateValidateMenuCommand(new Export()));
        app.onAction(Export, (_, _) -> log.push('Export'));
        assertTrue(platform.simulateValidateMenuCommand(new Export()));
        platform.simulateMenuAction(new Export());
        assertEquals('Export', log.join(','));
    }

    function testOpeningAMenuClearsThePendingKeystrokes() {
        app.bindKeys([new KeyBinding('ctrl-k ctrl-c', new Save(), 'Editor')]);
        final log:Array<String> = [];
        final window = openMenuView(log);
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Save', new Save())])]);

        keyDown(KEY_K, KEY_K, CTRL);
        assertEquals(1, window.pendingInputKeystrokes().length);

        @:privateAccess ceramic.App.app.backend.screen.emitMenuWillOpen();
        flushInput();
        assertNull(window.pendingInputKeystrokes());
    }

/// Shortcuts: the window first, then the menu

    function testHandledShortcutDoesNotRunTheMenuItem() {
        app.bindKeys([new KeyBinding('cmd-s', new Save(), 'Editor')]);
        final log:Array<String> = [];
        openMenuView(log);
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Save', new Save())])]);
        final save = findItem('Save');
        assertEquals('s', save.key);

        keyDown(KEY_S, KEY_S, META, save);
        assertEquals('Editor Save', log.join(','));
        assertEquals('', menuActions.join(','));
        assertTrue(ceramic.App.app.input.keyDownHandled);
    }

    function testUnhandledShortcutRunsTheMenuItem() {
        // Bound in a context the focused element is not in: the window does not handle it
        app.bindKeys([new KeyBinding('cmd-e', new Export(), 'Terminal')]);
        final log:Array<String> = [];
        app.onAction(Export, (_, _) -> log.push('global Export'));
        openMenuView(log);
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Export', new Export())])]);
        final export = findItem('Export');
        assertEquals('e', export.key);

        keyDown(KEY_E, KEY_E, META, export);
        assertFalse(ceramic.App.app.input.keyDownHandled);
        assertEquals('Export', menuActions.join(','));
        assertEquals('global Export', log.join(','));
    }

    function testUnhandledShortcutOfAnUnavailableActionDoesNothing() {
        app.bindKeys([new KeyBinding('cmd-q', new Quit(), 'Terminal')]);
        final log:Array<String> = [];
        openMenuView(log);
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Quit', new Quit())])]);

        keyDown(KEY_Q, KEY_Q, META, findItem('Quit'));
        assertEquals('', menuActions.join(','));
        assertEquals('', log.join(','));
    }

    function testShortcutOfAStaleMenuBarIsIgnored() {
        final log:Array<String> = [];
        app.onAction(Export, (_, _) -> log.push('global Export'));
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Export', new Export())])]);
        final stale = findItem('Export');
        app.setMenus([new Menu('File').withItems([MenuItemTools.action('Export', new Export())])]);
        emitMenuAction(stale);
        assertEquals('', log.join(','));
        emitMenuAction(findItem('Export'));
        assertEquals('global Export', log.join(','));
    }

    #if (clay_sdl && mac && !ios)

/// Native menu bar (macOS, hidden test app: nothing is shown)

    function testNativeMenuBar() {
        app.bindKeys([
            new KeyBinding('cmd-s', new Save(), null),
            new KeyBinding('cmd-shift-e', new Export(), null),
            new KeyBinding('cmd-c', new CopyText(), null),
            new KeyBinding('f5', new Quit(), null),
        ]);
        final log:Array<String> = [];
        openMenuView(log);
        app.setMenus([
            new Menu('Story').withItems([
                MenuItemTools.osSubmenu('Services', Services),
                MenuItemTools.separator(),
                MenuItemTools.action('Quit', new Quit()),
            ]),
            new Menu('File').withItems([
                MenuItemTools.action('Save', new Save()).checked(true),
                MenuItemTools.action('Export', new Export()),
                MenuItemTools.osAction('Copy', new CopyText(), Copy),
            ]),
            new Menu('Window'),
        ]);
        final description = clay.sdl.SDL.menuBarDescribe();
        final save = findItem('Save');
        final export = findItem('Export');
        final quit = findItem('Quit');
        final lines = description.split('\n');
        assertEquals('root clay delegate=1 services=Services', lines[0]);
        assertTrue(description.indexOf('Save key=s mods=cmd- action=clayMenuItem: tag=${save.id} state=1') != -1);
        assertTrue(description.indexOf('Export key=e mods=cmd-shift- action=clayMenuItem: tag=${export.id} state=0') != -1);
        assertTrue(description.indexOf('Copy key=c mods=cmd- action=copy:') != -1);
        assertTrue(description.indexOf('Quit key=U+F708 mods= action=clayMenuItem:') != -1);
        assertTrue(description.indexOf('target=chain') != -1);
        assertTrue(description.indexOf('  Window key= ') != -1 && description.indexOf('windowsMenu') != -1);

        // Validation by the system: the available actions are enabled
        assertEquals(1 | 2, clay.sdl.SDL.menuBarItemState(save.id));
        assertEquals(0, clay.sdl.SDL.menuBarItemState(export.id));

        // A click on an item (performActionForItemAtIndex:)
        assertTrue(clay.sdl.SDL.menuBarPerformItem(save.id));
        flushInput();
        assertEquals('Save', menuActions.join(','));
        assertEquals('Editor Save', log.join(','));

        // A shortcut: the menu matches it but leaves it to the app
        assertEquals(save.id, clay.sdl.SDL.menuBarTestKeyEquivalent('s', 8, 123456));
        assertEquals(export.id, clay.sdl.SDL.menuBarTestKeyEquivalent('e', 8 | 1, 123457));
        assertEquals(quit.id, clay.sdl.SDL.menuBarTestKeyEquivalent('f5', 0, 123458));
        assertEquals(-1, clay.sdl.SDL.menuBarTestKeyEquivalent('y', 8, 123459));
        // Nothing ran
        assertEquals('Save', menuActions.join(','));
        assertEquals('Editor Save', log.join(','));
    }

    #end

/// Helpers

    function openMenuView(log:Array<String>):Window {
        final editor = app.focusHandle();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<MenuView>) -> new MenuView(editor, log), 200, 100, 1);
        contexts.push(opened.cx);
        final window = opened.cx.window;
        GpuiInput.bind(window);
        window.activateWindow();
        opened.cx.update((window, cx) -> window.focus(editor, cx));
        opened.cx.runUntilParked();
        return window;
    }

    function findItem(title:String):ceramic.MenuItem {
        final found = findIn(ceramic.App.app.screen.menuBar, title);
        assertNotNull(found);
        return found;
    }

    static function findIn(items:Array<ceramic.MenuItem>, title:String):Null<ceramic.MenuItem> {
        if (items == null)
            return null;
        for (item in items) {
            if (item.title == title)
                return item;
            final found = findIn(item.items, title);
            if (found != null)
                return found;
        }
        return null;
    }

    static function isEnabled(item:ceramic.MenuItem):Bool {
        return @:privateAccess ceramic.App.app.backend.screen.isMenuItemEnabled(item.id);
    }

    /** A click on a native menu item, as the backend reports it. */
    static function emitMenuAction(item:ceramic.MenuItem):Void {
        @:privateAccess ceramic.App.app.backend.screen.emitMenuAction(item.id);
        flushInput();
    }

    /**
     * A key down as the backend emits it; with `menuItem`, followed by the
     * backend's `menuKeyEquivalent` for that item (the native menu matched
     * the shortcut and left it to the app).
     */
    static function keyDown(keyCode:ceramic.KeyCode, scanCode:ceramic.ScanCode, modifiers:ceramic.KeyModifiers, ?menuItem:ceramic.MenuItem):Void {
        final backend = ceramic.App.app.backend;
        @:privateAccess backend.input.emitKeyDown(new ceramic.Key(keyCode, scanCode, modifiers, null));
        if (menuItem != null) {
            @:privateAccess backend.screen.emitMenuKeyEquivalent(menuItem.id);
        }
        flushInput();
    }

    /** Runs Ceramic's queued input callbacks, like the start of an update. */
    static function flushInput():Void {
        final ceramicApp = ceramic.App.app;
        final callbacks:Array<Void->Void> = @:privateAccess ceramicApp.beginUpdateCallbacks;
        @:privateAccess ceramicApp.beginUpdateCallbacks = [];
        for (callback in callbacks) {
            callback();
        }
        ceramicApp.flushImmediate();
    }

}

@:action(namespace = app_menu_test) private class Save implements Action {}

@:action(namespace = app_menu_test) private class Export implements Action {}

@:action(namespace = app_menu_test) private class Quit implements Action {}

@:action(namespace = app_menu_test) private class CopyText implements Action {}

@:action(namespace = app_menu_test) private class RedoEdit implements Action {}

private class MenuView extends Model implements Render {

    final editor:FocusHandle;

    final log:Array<String>;

    public function new(editor:FocusHandle, log:Array<String>) {
        super();
        this.editor = editor;
        this.log = log;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().keyContext('Workspace').size(px(200)).child(
            div().keyContext('Editor').trackFocus(editor).size(px(100))
                .onAction(Save, (_, _, _) -> log.push('Editor Save'))
        );
    }

}
