// New tests for the Haxe port of GPUI: the window appearance, the scrollbar
// preference and the dock menu over Ceramic. Expected behaviors follow
// gpui-pre 0.3.10 src/window.rs (appearance, observe_window_appearance,
// appearance_changed, test_appearance_change_runs_after_app_update),
// src/app.rs (open_window, window_appearance, should_auto_hide_scrollbars,
// set_dock_menu, perform_dock_menu_action), src/app/context.rs
// (observe_window_appearance), src/platform/test/platform.rs,
// gpui-pre-macos 0.3.10 src/platform.rs (create_dock_menu, handle_dock_menu,
// should_auto_hide_scrollbars) (Zed Industries, Apache-2.0) and gpui-kit
// 0.8.1 crates/component/src/theme/mod.rs (init, sync_system_appearance,
// sync_scrollbar_appearance) (Longbridge, Apache-2.0). See NOTICE.md.
package tests;

import glaze.Action;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Model;
import glaze.Render;
import glaze.Subscription;
import glaze.TestDispatcher;
import glaze.TestPlatformOperations;
import glaze.Window;
import glaze.WindowAppearance;
import glaze.kit.base.theme.ScrollbarMode;
import glaze.kit.Component;
import glaze.kit.theme.Theme;
import glaze.platform.CeramicPlatformOperations;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.Menu.MenuItemTools;

/**
 * The appearance of the windows follows Ceramic's system appearance (read
 * when a window opens, read again after the platform reports a change, the
 * observers running after the update that saw the change), the scrollbar
 * preference is what gpui-kit's opt-in sync reads (`Theme.init` itself sets
 * `Hover`, initial port deviation DEV-020), and the dock menu is Ceramic's
 * dock menu whose items dispatch their action.
 *
 * The Ceramic side is driven like a backend does: `systemAppearanceChange`,
 * `autoHideScrollbarsChange` and `menuAction` emitted on the headless
 * backend screen, then Ceramic's queued callbacks run. Natively (clay on
 * macOS), the real system theme, scroller style and dock `NSMenu` are read
 * too, in the hidden test app.
 */
class PlatformAppearanceTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    var initialAppearance:ceramic.SystemAppearance;

    var initialAutoHide:Bool;

    override function setup() {
        final screen = ceramic.App.app.screen;
        initialAppearance = screen.systemAppearance;
        initialAutoHide = screen.autoHideScrollbars;
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) {
            cx.destroy();
        }
        contexts.resize(0);
        // Back to the real values (native) or the headless defaults
        emitSystemAppearance(initialAppearance);
        emitAutoHideScrollbars(initialAutoHide);
        @:privateAccess CeramicPlatformOperations.dockMenuOwner = null;
        @:privateAccess CeramicPlatformOperations.menuBarOwner = null;
        final screen = ceramic.App.app.screen;
        screen.menuItemValidator = null;
        screen.setDockMenu([]);
        ceramic.App.app.flushImmediate();
    }

/// Ceramic

    #if !clay_sdl
    function testHeadlessDefaults() {
        // GPUI's test platform: light, scrollbars not auto hidden
        final backend = @:privateAccess ceramic.App.app.backend.screen;
        assertEquals(ceramic.SystemAppearance.LIGHT, backend.getSystemAppearance());
        assertFalse(backend.getAutoHideScrollbars());
    }
    #end

    function testCeramicScreenFollowsTheBackend() {
        final screen = ceramic.App.app.screen;
        final events:Array<String> = [];
        final onAppearance = (appearance:ceramic.SystemAppearance) -> events.push('appearance ' + appearance.toString());
        final onAutoHide = (autoHide:Bool) -> events.push('autoHide ' + autoHide);
        screen.onSystemAppearanceChange(null, onAppearance);
        screen.onAutoHideScrollbarsChange(null, onAutoHide);

        emitSystemAppearance(DARK);
        assertEquals(ceramic.SystemAppearance.DARK, screen.systemAppearance);
        assertTrue(screen.systemAppearance.isDark());
        // The same value again emits nothing
        emitSystemAppearance(DARK);
        emitSystemAppearance(LIGHT);
        emitAutoHideScrollbars(!initialAutoHide);
        assertEquals(!initialAutoHide, screen.autoHideScrollbars);

        screen.offSystemAppearanceChange(onAppearance);
        screen.offAutoHideScrollbarsChange(onAutoHide);
        final expected = ['appearance DARK', 'appearance LIGHT', 'autoHide ${!initialAutoHide}'];
        if (initialAppearance == DARK) expected.shift();
        assertEquals(expected.join(','), events.join(','));
    }

/// Window appearance (window.rs)

    function testWindowAppearanceIsReadWhenTheWindowOpens() {
        emitSystemAppearance(DARK);
        final window = openWindow();
        assertEquals(WindowAppearance.Dark, window.appearance());
        assertEquals(WindowAppearance.Dark, app.windowAppearance());

        emitSystemAppearance(LIGHT);
        assertEquals(WindowAppearance.Light, app.windowAppearance());
        assertEquals(WindowAppearance.Light, openWindow().appearance());
    }

    /** Rust `test_appearance_change_runs_after_app_update`. */
    function testAppearanceChangeRunsAfterAppUpdate() {
        emitSystemAppearance(LIGHT);
        final opened = open();
        final observed:Array<WindowAppearance> = [];
        final subscription = opened.cx.update((window, _) -> window.observeWindowAppearance((window, _) -> observed.push(window.appearance())));

        app.update(_ -> {
            emitSystemAppearance(DARK);
            assertEquals(0, observed.length);
            return null;
        });
        assertEquals(0, observed.length);
        opened.cx.runUntilParked();

        assertEquals('Dark', [for (appearance in observed) appearance.toString()].join(','));
        assertEquals(WindowAppearance.Dark, opened.cx.window.appearance());
        subscription.dispose();
    }

    function testContextObservesTheWindowAppearance() {
        emitSystemAppearance(LIGHT);
        final opened = open();
        final view = opened.view;
        opened.cx.update((window, cx) -> {
            view.update(cx, (view:AppearanceView, cx:Context<AppearanceView>) -> {
                view.subscription = cx.observeWindowAppearance(window, (view:AppearanceView, window, cx) -> {
                    view.log.push('view ' + window.appearance().toString());
                });
            });
        });
        emitSystemAppearance(DARK);
        opened.cx.runUntilParked();
        emitSystemAppearance(LIGHT);
        opened.cx.runUntilParked();
        assertEquals('view Dark,view Light', view.read(app).log.join(','));
    }

    function testObserversRegisteredWhileOpeningRunOnce() {
        // Rust `open_window` defers `appearance_changed` after building the root
        emitSystemAppearance(DARK);
        final log:Array<String> = [];
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<AppearanceView>) -> {
            final view = new AppearanceView();
            view.subscription = cx.observeWindowAppearance(window, (view:AppearanceView, window, cx) -> log.push('opened ' + window.appearance().toString()));
            return view;
        }, 200, 100, 1);
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        assertEquals('opened Dark', log.join(','));
    }

    function testDestroyedWindowIgnoresAppearanceChanges() {
        final opened = open();
        final window = opened.cx.window;
        final log:Array<String> = [];
        final subscription = window.observeWindowAppearance((window, _) -> log.push('changed'));
        opened.cx.destroy();
        contexts.remove(opened.cx);
        emitSystemAppearance(initialAppearance == DARK ? LIGHT : DARK);
        dispatcher.runUntilParked();
        assertEquals('', log.join(','));
        subscription.dispose();
    }

    function testTestPlatformAppearanceAndScrollbars() {
        final operations = new TestPlatformOperations();
        app.platformOperations = operations;
        emitSystemAppearance(DARK);
        emitAutoHideScrollbars(true);
        // GPUI's test platform: light, scrollbars not auto hidden
        assertEquals(WindowAppearance.Light, app.windowAppearance());
        assertFalse(app.shouldAutoHideScrollbars());
        operations.appearance = VibrantDark;
        assertEquals(WindowAppearance.VibrantDark, app.windowAppearance());
        assertTrue(app.windowAppearance().isDark());
    }

/// gpui-kit theme sync (theme/mod.rs)

    /**
     * Initial port deviation DEV-020: `Theme.init` sets `Hover` whatever the
     * platform says (gpui-kit syncs with the platform there).
     */
    function testInitUsesHoverWhateverThePlatformSays() {
        for (autoHide in [true, false]) {
            emitAutoHideScrollbars(autoHide);
            final app = new App(new TestDispatcher());
            assertEquals(autoHide, app.shouldAutoHideScrollbars());
            app.update(cx -> Component.init(cx));
            assertEquals(ScrollbarMode.Hover, Theme.global(app).scrollbarMode, 'auto hide $autoHide');
            // The platform still answers what the system says
            assertEquals(autoHide, app.shouldAutoHideScrollbars());
        }
    }

    /**
     * The opt-in: `syncScrollbarAppearance` after `init` is gpui-kit's sync,
     * read when it is called (a later change is not followed).
     */
    function testSyncScrollbarAppearanceIsTheOptIn() {
        app.update(cx -> Component.init(cx));
        assertEquals(ScrollbarMode.Hover, Theme.global(app).scrollbarMode);

        emitAutoHideScrollbars(true);
        assertTrue(app.shouldAutoHideScrollbars());
        app.update(cx -> Theme.syncScrollbarAppearance(cx));
        assertEquals(ScrollbarMode.Scrolling, Theme.global(app).scrollbarMode);

        emitAutoHideScrollbars(false);
        assertFalse(app.shouldAutoHideScrollbars());
        // Not followed until the app syncs again
        assertEquals(ScrollbarMode.Scrolling, Theme.global(app).scrollbarMode);
        app.update(cx -> Theme.syncScrollbarAppearance(cx));
        assertEquals(ScrollbarMode.Hover, Theme.global(app).scrollbarMode);

        emitAutoHideScrollbars(true);
        assertEquals(ScrollbarMode.Hover, Theme.global(app).scrollbarMode);
    }

    function testInitOnTheTestPlatformUsesHover() {
        // Like gpui-kit's own tests (TestPlatform: false), whatever the screen says
        emitAutoHideScrollbars(true);
        app.platformOperations = new TestPlatformOperations();
        app.update(cx -> Component.init(cx));
        assertEquals(ScrollbarMode.Hover, Theme.global(app).scrollbarMode);
        app.update(cx -> Theme.syncScrollbarAppearance(cx));
        assertEquals(ScrollbarMode.Hover, Theme.global(app).scrollbarMode);
    }

    function testAModeChosenByTheAppIsKept() {
        app.update(cx -> {
            Component.init(cx);
            Theme.setScrollbarMode(Always, cx);
        });
        assertEquals(ScrollbarMode.Always, Theme.global(app).scrollbarMode);
        for (autoHide in [true, false]) {
            emitAutoHideScrollbars(autoHide);
            dispatcher.runUntilParked();
            assertEquals(ScrollbarMode.Always, Theme.global(app).scrollbarMode, 'auto hide $autoHide');
        }
        // Projected onto the Base scrollbar theme too
        assertEquals(ScrollbarMode.Always, glaze.kit.base.theme.Theme.global(app).scrollbar.mode());
    }

    function testSyncSystemAppearance() {
        app.update(cx -> Component.init(cx));
        emitSystemAppearance(DARK);
        final window = openWindow();
        app.update(cx -> Theme.syncSystemAppearance(window, cx));
        assertTrue(Theme.global(app).isDark());

        // Without a window: the appearance of the application's windows
        emitSystemAppearance(LIGHT);
        app.update(cx -> Theme.syncSystemAppearance(null, cx));
        assertFalse(Theme.global(app).isDark());

        // The window's appearance wins over the application's
        final operations = new TestPlatformOperations();
        app.platformOperations = operations;
        operations.appearance = Light;
        emitSystemAppearance(DARK);
        final dark = openWindow();
        app.update(cx -> Theme.syncSystemAppearance(dark, cx));
        assertTrue(Theme.global(app).isDark());
    }

/// Dock menu (set_dock_menu, perform_dock_menu_action)

    function testDockMenuInstallsTheCeramicDockMenu() {
        app.bindKeys([new KeyBinding('cmd-n', new NewWindow(), null)]);
        app.setDockMenu([
            MenuItemTools.action('New Window', new NewWindow()),
            MenuItemTools.separator(),
            MenuItemTools.action('Open Recent', new OpenRecent()),
        ]);
        final dockMenu = ceramic.App.app.screen.dockMenu;
        assertEquals(3, dockMenu.length);
        assertEquals('New Window', dockMenu[0].title);
        assertEquals('n', dockMenu[0].key);
        assertEquals((ceramic.KeyModifiers.META:Int), (dockMenu[0].modifiers:Int));
        assertEquals(ceramic.MenuItemKind.SEPARATOR, dockMenu[1].kind);
        assertTrue(dockMenu[0].id > 0);
        assertTrue(dockMenu[2].id > dockMenu[0].id);
    }

    function testChoosingADockMenuItemDispatchesItsAction() {
        final log:Array<String> = [];
        app.onAction(NewWindow, (_, _) -> log.push('global NewWindow'));
        app.setDockMenu([MenuItemTools.action('New Window', new NewWindow()), MenuItemTools.action('Open Recent', new OpenRecent())]);
        final item = ceramic.App.app.screen.dockMenu[0];
        // Validated like a menu bar item: available actions are enabled
        assertTrue(@:privateAccess ceramic.App.app.backend.screen.isMenuItemEnabled(item.id));
        assertFalse(@:privateAccess ceramic.App.app.backend.screen.isMenuItemEnabled(ceramic.App.app.screen.dockMenu[1].id));

        @:privateAccess ceramic.App.app.backend.screen.emitMenuAction(item.id);
        flushInput();
        assertEquals('global NewWindow', log.join(','));
    }

    function testDockMenuAndMenuBarLiveTogether() {
        final log:Array<String> = [];
        app.onAction(NewWindow, (_, _) -> log.push('NewWindow'));
        app.onAction(OpenRecent, (_, _) -> log.push('OpenRecent'));
        app.setDockMenu([MenuItemTools.action('New Window', new NewWindow())]);
        app.setMenus([new glaze.Menu('File').withItems([MenuItemTools.action('Open Recent', new OpenRecent())])]);
        final dockItem = ceramic.App.app.screen.dockMenu[0];
        final barItem = ceramic.App.app.screen.menuBar[0].items[0];
        @:privateAccess ceramic.App.app.backend.screen.emitMenuAction(dockItem.id);
        @:privateAccess ceramic.App.app.backend.screen.emitMenuAction(barItem.id);
        flushInput();
        assertEquals('NewWindow,OpenRecent', log.join(','));
        ceramic.App.app.screen.setMenuBar([]);
    }

    function testTestPlatformDockMenu() {
        final operations = new TestPlatformOperations();
        app.platformOperations = operations;
        app.setDockMenu([MenuItemTools.action('New Window', new NewWindow())]);
        app.performDockMenuAction(0);
        assertEquals(1, operations.dockMenus.length);
        assertEquals('0', operations.dockMenuActions.join(','));
        // GPUI's macOS platform: nothing to perform
        app.platformOperations = new CeramicPlatformOperations();
        app.performDockMenuAction(0);
    }

    #if (clay_sdl && mac && !ios)

/// Native (macOS, hidden test app: nothing is shown)

    function testNativeSystemThemeAndScrollerStyle() {
        final screen = ceramic.App.app.screen;
        // What SDL and AppKit say right now is what Ceramic reported
        final dark = clay.sdl.SDL.getSystemTheme() == clay.sdl.SDL.SYSTEM_THEME_DARK;
        assertEquals(dark, initialAppearance == DARK);
        assertEquals(clay.sdl.SDL.autoHideScrollbars(), initialAutoHide);

        // The change notification is observed
        final before = clay.sdl.SDL.autoHideScrollbarsChangeCount();
        clay.sdl.SDL.postScrollerStyleChange();
        assertEquals(before + 1, clay.sdl.SDL.autoHideScrollbarsChangeCount());
        // The style did not change: the runtime emits nothing
        @:privateAccess (clay.Clay.app.runtime : clay.sdl.SDLRuntime).pollAutoHideScrollbars();
        flushInput();
        assertEquals(initialAutoHide, screen.autoHideScrollbars);
    }

    function testNativeInitUsesHoverAndTheSyncFollowsTheScrollerStyle() {
        final overlay = clay.sdl.SDL.autoHideScrollbars();
        assertEquals(overlay, app.shouldAutoHideScrollbars());
        app.update(cx -> Component.init(cx));
        assertEquals(ScrollbarMode.Hover, Theme.global(app).scrollbarMode);
        app.update(cx -> Theme.syncScrollbarAppearance(cx));
        assertEquals(overlay ? ScrollbarMode.Scrolling : ScrollbarMode.Hover, Theme.global(app).scrollbarMode);
    }

    function testNativeDockMenu() {
        app.bindKeys([new KeyBinding('cmd-n', new NewWindow(), null)]);
        final log:Array<String> = [];
        app.onAction(NewWindow, (_, _) -> log.push('NewWindow'));
        app.setDockMenu([
            MenuItemTools.action('New Window', new NewWindow()),
            MenuItemTools.separator(),
            MenuItemTools.action('Open Recent', new OpenRecent()),
        ]);
        final dockMenu = ceramic.App.app.screen.dockMenu;
        final description = clay.sdl.SDL.dockMenuDescribe();
        final lines = description.split('\n');
        assertEquals('dock installed=1 provided=1 delegate=1', lines[0]);
        assertTrue(lines[1].indexOf('New Window key=n mods=cmd- action=clayMenuItem: tag=${dockMenu[0].id} ') != -1);
        assertTrue(lines[1].indexOf('target=chain') != -1);
        assertEquals('  ---', lines[2]);
        // No key: AppKit keeps its default modifier mask, as in the menu bar
        assertTrue(lines[3].indexOf('Open Recent key= mods=') != -1);
        assertTrue(lines[3].indexOf('action=clayMenuItem: tag=${dockMenu[2].id} ') != -1);

        // A click on an item
        assertTrue(clay.sdl.SDL.dockMenuPerformItem(dockMenu[0].id));
        flushInput();
        assertEquals('NewWindow', log.join(','));

        // An empty dock menu removes it
        app.setDockMenu([]);
        assertEquals('dock installed=0 provided=0 delegate=0', clay.sdl.SDL.dockMenuDescribe().split('\n')[0]);
    }

    #end

/// Helpers

    function open():{view:glaze.Entity<AppearanceView>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<AppearanceView>) -> new AppearanceView(), 200, 100, 1);
        contexts.push(opened.cx);
        return opened;
    }

    function openWindow():Window {
        return open().cx.window;
    }

    static function emitSystemAppearance(appearance:ceramic.SystemAppearance):Void {
        @:privateAccess ceramic.App.app.backend.screen.emitSystemAppearanceChange(appearance);
        flushInput();
    }

    static function emitAutoHideScrollbars(autoHide:Bool):Void {
        @:privateAccess ceramic.App.app.backend.screen.emitAutoHideScrollbarsChange(autoHide);
        flushInput();
    }

    /** Runs Ceramic's queued callbacks, like the start of an update. */
    static function flushInput():Void {
        final ceramicApp = ceramic.App.app;
        final callbacks:Array<() -> Void> = @:privateAccess ceramicApp.beginUpdateCallbacks;
        @:privateAccess ceramicApp.beginUpdateCallbacks = [];
        for (callback in callbacks) {
            callback();
        }
        ceramicApp.flushImmediate();
    }

}

@:action(namespace = platform_appearance_test) private class NewWindow implements Action {}

@:action(namespace = platform_appearance_test) private class OpenRecent implements Action {}

private class AppearanceView extends Model implements Render {

    public final log:Array<String> = [];

    public var subscription:Null<Subscription> = null;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(100));
    }

}
