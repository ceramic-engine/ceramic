// New tests for the Haxe port of GPUI: the application operations of the
// platform (quit, activate, path prompts, menus) and window activation over
// Ceramic. Expected behaviors follow gpui-pre 0.3.10 src/app.rs, src/platform.rs,
// src/platform/test/platform.rs and gpui-pre-macos / gpui-pre-web (Zed
// Industries, Apache-2.0). See NOTICE.md.
package tests;

import gpui.AnyTask;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.GpuiInput;
import gpui.IntoElement;
import gpui.Menu;
import gpui.Model;
import gpui.PathPromptOptions;
import gpui.Render;
import gpui.Task;
import gpui.TestDispatcher;
import gpui.TestPlatformOperations;
import gpui.Unit;
import gpui.Window;
import gpui.platform.CeramicPlatformOperations;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.Menu.MenuItemTools;

/**
 * `App.quit` / `onAppQuit` / `shutdown`, `App.activate`, the path prompts,
 * `setMenus` / `getMenus` (with GPUI's test platform double and with the
 * Ceramic implementation over `ceramic.Dialogs.handler`), and window
 * activation through `Window.activateWindow` and Ceramic's
 * `windowFocusChange` (emitted on the backend screen, like the clay backend
 * does on SDL focus events).
 */
class PlatformOperationsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        #if plugin_dialogs
        ceramic.Dialogs.handler = null;
        #end
        for (cx in contexts) {
            GpuiInput.unbind(cx.window);
            cx.destroy();
        }
        contexts.resize(0);
        setSystemFocus(true);
        ceramic.App.app.flushImmediate();
    }

/// Quit

    function testQuitAsksThePlatformWhichRunsTheQuitObservers() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        var quitObserverCalls = 0;
        app.onAppQuit(_ -> {
            quitObserverCalls++;
            return null;
        }).detach();

        app.quit();
        assertEquals(1, platform.quitCount);
        // GPUI's test platform does not quit: the observers wait for the platform
        assertEquals(0, quitObserverCalls);
        assertFalse(app.isQuitting());

        final shutdown = platform.simulateQuit();
        assertEquals(1, quitObserverCalls);
        assertTrue(app.isQuitting());
        assertTrue(shutdown != null && shutdown.isReady);

        // Rust `quit_observers.remove(&())`: observers run once
        platform.simulateQuit();
        assertEquals(1, quitObserverCalls);
    }

    function testShutdownWaitsForTheQuitObserverTasks() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        final pending = new Task<Unit>();
        app.onAppQuit(_ -> pending).detach();

        final shutdown:AnyTask = platform.simulateQuit();
        assertFalse(shutdown.isReady);
        pending.resolve(Unit.unit);
        assertTrue(shutdown.isReady);
    }

    function testShutdownGivesUpAfterTheTimeout() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        app.onAppQuit(_ -> new Task<Unit>()).detach();

        final shutdown:AnyTask = platform.simulateQuit();
        assertFalse(shutdown.isReady);
        dispatcher.advanceClock(App.SHUTDOWN_TIMEOUT * 0.5);
        assertFalse(shutdown.isReady);
        dispatcher.advanceClock(App.SHUTDOWN_TIMEOUT);
        assertTrue(shutdown.isReady);
    }

    function testDroppedQuitObserverIsNotCalled() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        var calls = 0;
        final subscription = app.onAppQuit(_ -> {
            calls++;
            return null;
        });
        subscription.dispose();
        platform.simulateQuit();
        assertEquals(0, calls);
    }

/// Activate

    function testActivateGoesToThePlatform() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        app.activate(true);
        app.activate(false);
        assertEquals('true,false', platform.activations.join(','));
    }

    function testCeramicActivateDoesNothingHeadless() {
        // Default operations: Ceramic's screen, a no-op on headless backends
        // and hidden test windows (clay_sdl_headless)
        assertTrue(Std.isOfType(app.platformOperations, CeramicPlatformOperations));
        app.activate(true);
    }

/// Path prompts (test platform)

    function testPromptForNewPathWaitsForTheTest() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;

        final task = app.promptForNewPath('/home/me/Downloads', 'export.csv');
        assertTrue(platform.didPromptForNewPath());
        assertFalse(task.isReady);

        var seen:Null<String> = null;
        platform.simulateNewPathSelection((directory, suggestedName) -> {
            seen = '$directory|$suggestedName';
            return directory + '/chosen.csv';
        });
        assertEquals('/home/me/Downloads|export.csv', seen);
        assertFalse(platform.didPromptForNewPath());
        assertEquals('/home/me/Downloads/chosen.csv', task.value);
    }

    function testPromptForPathsCanBeCancelled() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;

        final task = app.promptForPaths(new PathPromptOptions(true, false, true, 'Open'));
        assertTrue(platform.didPromptForPaths());
        var seen:Null<PathPromptOptions> = null;
        platform.simulatePathPromptResponse(options -> {
            seen = options;
            return null;
        });
        assertTrue(task.isReady);
        assertNull(task.value);
        assertTrue(seen.files && !seen.directories && seen.multiple);
        assertEquals('Open', seen.prompt);
        assertTrue(app.canSelectMixedFilesAndDirs());
    }

/// Path prompts (Ceramic dialogs)

    #if plugin_dialogs
    function testCeramicNewPathPromptUsesTheDialogsPlugin() {
        var request:Null<{save:Bool, options:ceramic.DialogsOptions}> = null;
        var answer:Null<(Null<Array<String>>, Null<String>)->Void> = null;
        ceramic.Dialogs.handler = (save, options, done) -> {
            request = {save: save, options: options};
            answer = done;
        };

        final task = app.promptForNewPath('/home/me/Downloads', 'export.csv');
        assertTrue(request.save);
        assertEquals('/home/me/Downloads', request.options.directory);
        assertEquals('export.csv', request.options.defaultName);

        answer(['/home/me/Downloads/export 2.csv'], null);
        // The answer always arrives asynchronously
        assertFalse(task.isReady);
        ceramic.App.app.flushImmediate();
        assertEquals('/home/me/Downloads/export 2.csv', task.value);
    }

    function testCeramicPathPromptOptionsCancelAndErrors() {
        var request:Null<ceramic.DialogsOptions> = null;
        var answer:Null<(Null<Array<String>>, Null<String>)->Void> = null;
        ceramic.Dialogs.handler = (save, options, done) -> {
            assertFalse(save);
            request = options;
            answer = done;
        };

        final cancelled = app.promptForPaths(new PathPromptOptions(false, true, true, 'Choose'));
        assertTrue(request.directories && !request.files && request.multiple);
        assertEquals('Choose', request.prompt);
        answer([], null);
        ceramic.App.app.flushImmediate();
        assertTrue(cancelled.isReady);
        assertNull(cancelled.value);

        final failed = app.promptForPaths(new PathPromptOptions(true, false, false));
        answer(null, 'not supported');
        ceramic.App.app.flushImmediate();
        assertTrue(failed.isFailed);

        final chosen = app.promptForPaths(new PathPromptOptions(true, false, true));
        answer(['/a', '/b'], null);
        ceramic.App.app.flushImmediate();
        assertEquals('/a,/b', chosen.value.join(','));

        assertFalse(app.canSelectMixedFilesAndDirs());
    }

    function testCeramicPromptFailsWhereNoDialogExists() {
        // The headless backend has no dialog: the prompt fails, like GPUI's
        // web platform ("not supported")
        #if (headless || (web && !ceramic_use_electron))
        assertFalse(ceramic.Dialogs.pathDialogsAvailable());
        final task = app.promptForNewPath('/tmp');
        ceramic.App.app.flushImmediate();
        assertTrue(task.isFailed);
        #end
    }
    #end

/// Menus

    function testSetMenusKeepsOwnedMenus() {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        assertEquals(0, app.getMenus().length);

        app.setMenus([new Menu('File').withItems([MenuItemTools.separator()]), new Menu('Edit')]);
        final menus = app.getMenus();
        assertEquals(2, menus.length);
        assertEquals('File', menus[0].name);
        assertEquals('Edit', menus[1].name);

        final ceramicApp = new App(dispatcher);
        assertNull(ceramicApp.getMenus());
        ceramicApp.setMenus([new Menu('Help')]);
        assertEquals('Help', ceramicApp.getMenus()[0].name);
    }

/// Window activation

    function testActivateWindowMovesTheKeyboardToIt() {
        final first = open();
        final second = open();
        GpuiInput.activateWindow(first);
        assertTrue(first.isWindowActive());

        final activations:Array<String> = [];
        @:privateAccess first.activationObservers.insert(0, (window, _) -> {
            activations.push('first ${window.isWindowActive()}');
            return true;
        }).activate();

        second.activateWindow();
        assertTrue(second.isWindowActive());
        assertFalse(first.isWindowActive());
        assertEquals('first false', activations.join(';'));
        assertEquals(second, @:privateAccess GpuiInput.instance.activeWindow);
    }

    function testSystemFocusDeactivatesAndReactivatesTheWindows() {
        final window = open();
        window.activateWindow();
        assertTrue(window.isWindowActive());

        setSystemFocus(false);
        assertFalse(ceramic.App.app.screen.windowFocused);
        assertFalse(window.isWindowActive());

        setSystemFocus(true);
        assertTrue(window.isWindowActive());
    }

    function testActivationWaitsForTheSystemFocus() {
        final first = open();
        final second = open();
        first.activateWindow();
        setSystemFocus(false);

        // Like a native window that only becomes key once the app is active
        second.activateWindow();
        assertFalse(second.isWindowActive());
        assertFalse(first.isWindowActive());

        setSystemFocus(true);
        assertTrue(second.isWindowActive());
        assertFalse(first.isWindowActive());
    }

/// Helpers

    function open():Window {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<Blank>) -> new Blank(), 200, 100, 1);
        contexts.push(opened.cx);
        GpuiInput.bind(opened.cx.window);
        return opened.cx.window;
    }

    /**
     * The app window gains or loses the system focus, as the clay backend
     * reports SDL focus events, then Ceramic's queued input callbacks run
     * (the start of an update).
     */
    static function setSystemFocus(focused:Bool):Void {
        final ceramicApp = ceramic.App.app;
        @:privateAccess ceramicApp.backend.screen.emitWindowFocusChange(focused);
        final callbacks:Array<Void->Void> = @:privateAccess ceramicApp.beginUpdateCallbacks;
        @:privateAccess ceramicApp.beginUpdateCallbacks = [];
        for (callback in callbacks) {
            callback();
        }
        ceramicApp.flushImmediate();
    }

}

private class Blank extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(10));
    }

}
