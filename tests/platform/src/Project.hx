package;

import ceramic.App;
import ceramic.Entity;
import ceramic.Files;
import ceramic.InitSettings;
import ceramic.Path;
import ceramic.Platform;
import ceramic.ScrollPhase;
import ceramic.ScrollUnit;
import ceramic.Settings;
import ceramic.TitleBarStyle;
import tracker.Model;
import tracker.SaveModel;

/**
 * Checks of the window and platform additions of the runtime (see
 * `check.sh`). Nothing is shown on screen: headless runs the settings
 * against the headless backend, macOS drives the real SDL window, hidden.
 */
#if (clay && cpp)
@:cppFileCode('#include <SDL3/SDL.h>')
#end
class Project extends Entity {

    static inline final SAVE_KEY = 'platformCheck';

    var checks = 0;

    var failures = 0;

    var steps:Array<() -> Bool> = [];

    var stepFrames = 0;

    var model:CheckModel = null;

    var changesets = 0;

    /** `mouseScroll` events seen: `phase deltaX,deltaY unit`. */
    var scrolls:Array<String> = [];

    /** Second native run: only reads back what the first one saved when it quit. */
    var readBackToken:String = null;

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 320;
        settings.targetHeight = 240;
        settings.resizable = true;

        // Everything below is given to the window when it is created
        settings.windowPosition(120, 140);
        settings.windowMinSize(200, 150);
        settings.titleBarStyle = TitleBarStyle.OVERLAY;
        settings.trafficLightPosition(12, 10);
        settings.windowStartsHidden = true;

        App.app.onceReady(this, ready);

    }

    function ready() {

        #if (clay && cpp && mac && !ios)
        final path = tokenPath();
        if (path != null && sys.FileSystem.exists(path)) {
            readBackToken = sys.io.File.getContent(path);
            sys.FileSystem.deleteFile(path);
            steps = readBackSteps();
            App.app.onUpdate(this, _ -> runSteps());
            return;
        }
        #end

        model = new CheckModel();
        SaveModel.autoSaveAsKey(model, SAVE_KEY);
        model.serializer.onChangeset(this, _ -> changesets++);

        commonChecks();
        App.app.screen.onMouseScroll(this, (deltaX, deltaY, unit) -> {
            scrolls.push(App.app.screen.mouseScrollPhase.toString() + ' ' + Math.round(deltaX) + ',' + Math.round(deltaY) + ' ' + (unit == ScrollUnit.LINES ? 'lines' : 'pixels'));
        });

        #if headless
        steps = headlessSteps();
        #elseif (clay && cpp && mac && !ios)
        steps = macSteps();
        #elseif (clay && web)
        webChecks();
        return;
        #else
        App.app.logger.info('platform: nothing more to run on this target (compile check)');
        return;
        #end

        App.app.onUpdate(this, _ -> runSteps());

    }

    function runSteps():Void {

        if (steps.length == 0) return;
        stepFrames++;
        if (stepFrames > 300) {
            fail('step timed out (${steps.length} left)');
            steps.shift();
            stepFrames = 0;
        }
        else if (steps[0]()) {
            steps.shift();
            stepFrames = 0;
        }
        if (steps.length == 0) finish();

    }

    function finish():Void {

        App.app.logger.info('platform: $checks checks, $failures failed');
        final code = failures == 0 ? 0 : 1;
        #if (headless && nodejs)
        js.Node.process.exit(code);
        #elseif (clay && cpp && mac && !ios)
        if (code == 0 && readBackToken == null) {
            // Change the model and quit in the same frame: nothing but the
            // save made when the app terminates can write this value
            final token = 'token-' + Std.int(Sys.time() * 1000);
            model.value = token;
            sys.io.File.saveContent(tokenPath(), token);
            App.app.quit();
        }
        else {
            Sys.exit(code);
        }
        #elseif sys
        Sys.exit(code);
        #end

    }

    function check(condition:Bool, what:String):Void {

        checks++;
        if (!condition) fail(what);

    }

    function equals(expected:Dynamic, actual:Dynamic, what:String):Void {

        checks++;
        if (Std.string(expected) != Std.string(actual)) fail('$what: expected <$expected>, got <$actual>');

    }

    function fail(what:String):Void {

        failures++;
        App.app.logger.error('FAILED: $what');

    }

/// Checks that do not need a window

    function commonChecks():Void {

        final app = App.app;

        // System locales: a list of BCP 47 tags
        final locales = app.systemLocales;
        check(locales != null, 'systemLocales is null');
        final tag = ~/^[A-Za-z]{2,3}(-[A-Za-z0-9]{1,8})*$/;
        for (locale in locales) {
            check(tag.match(locale), 'systemLocales: <$locale> is not a BCP 47 tag');
        }
        app.logger.info('platform: systemLocales=' + locales.join(','));

        // Commands of revealInFileManager
        equals('[[open,-R,/tmp/a b/c.txt]]', Platform.revealInFileManagerCommands('/tmp/a b/c.txt', 'mac'), 'reveal commands on mac');
        equals(
            '[[explorer.exe,/select,C:\\Users\\a b\\c.txt]]',
            Platform.revealInFileManagerCommands('C:/Users/a b/c.txt', 'windows'), 'reveal commands on windows'
        );
        final linux = Platform.revealInFileManagerCommands('/home/me/a b/c,d.txt', 'linux');
        equals(2, linux.length, 'reveal commands on linux');
        equals('dbus-send', linux[0][0], 'reveal on linux asks FileManager1 first');
        equals('org.freedesktop.FileManager1.ShowItems', linux[0][6], 'reveal on linux: method');
        equals('array:string:file:///home/me/a%20b/c%2Cd.txt', linux[0][7], 'reveal on linux: uri');
        equals('[xdg-open,/home/me/a b]', linux[1], 'reveal on linux: fallback opens the parent directory');
        equals('[]', Platform.revealInFileManagerCommands('/tmp/a', 'ios'), 'reveal commands elsewhere');

        #if ((sys || nodejs) && !web)
        // Files.rename: a file, then a directory
        final dir = Path.join([tempDir(), 'ceramic-platform-check-' + Std.int(haxe.Timer.stamp() * 1000000)]);
        sys.FileSystem.createDirectory(dir);
        final from = Path.join([dir, 'from.txt']);
        final to = Path.join([dir, 'to.txt']);
        Files.saveContent(from, 'hello');
        Files.rename(from, to);
        check(!sys.FileSystem.exists(from), 'rename: the old file is still there');
        equals('hello', Files.getContent(to), 'rename: content of the renamed file');
        final sub = Path.join([dir, 'sub']);
        final sub2 = Path.join([dir, 'sub2']);
        sys.FileSystem.createDirectory(sub);
        Files.rename(to, Path.join([sub, 'moved.txt']));
        Files.rename(sub, sub2);
        check(!sys.FileSystem.exists(sub), 'rename: the old directory is still there');
        equals('hello', Files.getContent(Path.join([sub2, 'moved.txt'])), 'rename: file of the renamed directory');
        var threw = false;
        try {
            Files.rename(Path.join([dir, 'missing.txt']), Path.join([dir, 'other.txt']));
        }
        catch (e:Dynamic) {
            threw = true;
        }
        check(threw, 'rename: a missing file should throw');
        Files.deleteRecursive(dir);
        #end

        // Scroll phases: none outside of a mouseScroll event, momentum on by default
        equals('NONE', app.screen.mouseScrollPhase.toString(), 'no scroll phase outside of a mouseScroll event');
        check(app.settings.scrollMomentum, 'scrollMomentum is true by default');
        check(@:privateAccess new Settings().scrollMomentum, 'scrollMomentum default of a new Settings');
        check(ScrollPhase.GESTURE_ENDED.isGesture() && !ScrollPhase.GESTURE_ENDED.isMomentum(), 'GESTURE_ENDED is a gesture phase');
        check(ScrollPhase.MOMENTUM.isMomentum() && !ScrollPhase.NONE.isGesture() && !ScrollPhase.NONE.isMomentum(), 'MOMENTUM is a momentum phase, NONE neither');

        // Tracker: the terminate event serializes the pending changes at once
        final before = changesets;
        model.value = 'changed';
        equals(before, changesets, 'the change is not serialized before the check interval');
        @:privateAccess app.emitTerminate();
        equals(before + 1, changesets, 'terminate serializes the pending change');

    }

    #if ((sys || nodejs) && !web)
    function tempDir():String {

        var dir = Sys.getEnv('TMPDIR');
        if (dir == null || dir == '') dir = Sys.getEnv('TEMP');
        if (dir == null || dir == '') dir = '/tmp';
        return dir;

    }
    #end

/// Headless: the backend keeps what it is given

    #if headless

    function headlessSteps():Array<() -> Bool> {

        final app = App.app;
        final settings = app.settings;
        final screen = app.backend.screen;

        return [
            () -> {
                // Values set before the app started
                equals(120, screen.getWindowX(), 'initial x given to the backend');
                equals(140, screen.getWindowY(), 'initial y given to the backend');
                equals(120, settings.windowX, 'settings.windowX after start');
                equals(140, settings.windowY, 'settings.windowY after start');
                equals(200, screen.windowMinWidth, 'initial minimum width');
                equals(150, screen.windowMinHeight, 'initial minimum height');
                equals('OVERLAY', screen.windowTitleBarStyle.toString(), 'initial title bar style');
                equals(12, screen.windowTitleBarButtonsX, 'initial buttons x');
                equals(10, screen.windowTitleBarButtonsY, 'initial buttons y');
                check(settings.windowStartsHidden, 'windowStartsHidden is kept');
                check(!screen.windowBorderless, 'not borderless by default');
                equals(0, app.screen.displayBounds().width, 'no display bounds on headless');
                equals(1, app.screen.windowDesktopScale, 'desktop scale on headless');
                equals(0, app.systemLocales.length, 'no system locale on headless');

                // Changed while running: applied once, after the frame code
                settings.windowPosition(300, 220);
                equals(120, screen.getWindowX(), 'the move is applied once both axes are set');
                return true;
            },
            () -> {
                if (screen.getWindowX() != 300) return false;
                equals(220, screen.getWindowY(), 'y moved');
                equals(300, settings.windowX, 'settings.windowX after a move');

                // One axis only
                settings.windowX = -40;
                return true;
            },
            () -> {
                if (screen.getWindowX() != -40) return false;
                equals(220, screen.getWindowY(), 'y kept when only x changes');

                // The window moved by the user: settings follow, nothing is sent back
                var changes = 0;
                var counting = true;
                settings.onWindowXChange(this, (_, _) -> if (counting) changes++);
                @:privateAccess screen.emitWindowMove(50, 60);
                equals(50, settings.windowX, 'settings.windowX follows the window');
                equals(60, settings.windowY, 'settings.windowY follows the window');
                equals(1, changes, 'windowX change observed once');
                counting = false;

                settings.windowMinSize(0, 90);
                settings.windowBorderless = true;
                check(screen.windowBorderless, 'borderless applied at once');
                settings.titleBarStyle = TitleBarStyle.DEFAULT;
                settings.trafficLightPosition(-1, -1);
                return true;
            },
            () -> {
                if (screen.windowMinHeight != 90) return false;
                equals(0, screen.windowMinWidth, 'minimum width removed');
                equals(50, screen.getWindowX(), 'a followed move is not sent back to the window');
                equals('DEFAULT', screen.windowTitleBarStyle.toString(), 'title bar style changed');
                equals(-1, screen.windowTitleBarButtonsX, 'buttons x changed');
                settings.windowBorderless = false;
                check(!screen.windowBorderless, 'borderless removed');

                // Scroll phases: none from a plain backend event, the phase
                // given by a backend that reports one, read while emitted
                equals('NONE', screen.getMouseScrollPhase().toString(), 'headless backend phase at rest');
                @:privateAccess screen.emitMouseScroll(0, 3, ScrollUnit.LINES);
                screen.emitMouseScrollWithPhase(0, 0, ScrollUnit.PIXELS, ScrollPhase.GESTURE_MAY_BEGIN);
                screen.emitMouseScrollWithPhase(1, -4, ScrollUnit.PIXELS, ScrollPhase.GESTURE_BEGAN);
                screen.emitMouseScrollWithPhase(0, 0, ScrollUnit.PIXELS, ScrollPhase.MOMENTUM_ENDED);
                equals('NONE', screen.getMouseScrollPhase().toString(), 'headless backend phase reset after the event');
                return true;
            },
            () -> {
                // Screen events are emitted at the start of the next update
                if (scrolls.length < 4) return false;
                equals('NONE 0,3 lines|GESTURE_MAY_BEGIN 0,0 pixels|GESTURE_BEGAN 1,-4 pixels|MOMENTUM_ENDED 0,0 pixels', scrolls.join('|'), 'headless scroll phases');
                equals('NONE', app.screen.mouseScrollPhase.toString(), 'no scroll phase after the events');
                return true;
            }
        ];

    }

    #end

/// macOS: the real window, hidden

    #if (clay && cpp && mac && !ios)

    function tokenPath():String {

        final dir = App.app.backend.info.storageDirectory();
        return dir != null ? Path.join([dir, 'platform-check-token.txt']) : null;

    }

    function describe():String {

        return clay.Clay.app.runtime.windowTitleBarDescribe();

    }

    function macSteps():Array<() -> Bool> {

        final app = App.app;
        final settings = app.settings;
        final screen = app.screen;
        final runtime = clay.Clay.app.runtime;
        var defaultClose:String = null;
        var scrollWaited = 0;

        return [
            () -> {
                // Scroll phases: events posted to this process only, with the
                // phase fields of CoreGraphics, handed to the hidden window
                check(clay.Clay.app.config.runtime.scrollMomentum, 'scrollMomentum given to clay');
                final hint:String = untyped __cpp__('::String(SDL_GetHint("SDL_MAC_SCROLL_MOMENTUM"))');
                equals('1', hint, 'momentum hint set from settings.scrollMomentum');
                final window = @:privateAccess runtime.window;
                final post = (phase:Int, momentum:Int, dy:Int, pixels:Bool) -> {
                    check(clay.sdl.SDL.scrollPhaseTestPost(window, phase, momentum, 0, dy, pixels), 'post scroll $phase $momentum $dy');
                };
                // A notched wheel (no phase), then a trackpad gesture and its momentum
                post(0, 0, 1, false);
                post(128, 0, 0, true); // kCGScrollPhaseMayBegin
                post(1, 0, 5, true);   // kCGScrollPhaseBegan
                post(2, 0, 7, true);   // kCGScrollPhaseChanged
                post(4, 0, 0, true);   // kCGScrollPhaseEnded
                post(0, 1, 3, true);   // kCGMomentumScrollPhaseBegin
                post(0, 2, 2, true);   // kCGMomentumScrollPhaseContinue
                post(0, 3, 0, true);   // kCGMomentumScrollPhaseEnd
                return true;
            },
            () -> {
                scrollWaited++;
                if (scrolls.length < 8 && scrollWaited < 120) return false;
                equals(8, clay.sdl.SDL.scrollPhaseTestDelivered(), 'posted scroll events reached the monitor');
                app.logger.info('platform: scrolls ' + scrolls.join('|'));
                equals(
                    'NONE 0,-1 lines|GESTURE_MAY_BEGIN 0,0 pixels|GESTURE_BEGAN 0,-5 pixels|GESTURE 0,-7 pixels|GESTURE_ENDED 0,0 pixels'
                    + '|MOMENTUM_BEGAN 0,-3 pixels|MOMENTUM 0,-2 pixels|MOMENTUM_ENDED 0,0 pixels',
                    scrolls.join('|'), 'scroll phases from posted events'
                );
                equals('NONE', screen.mouseScrollPhase.toString(), 'no scroll phase after the events');
                return true;
            },
            () -> {
                app.logger.info('platform: window at ${settings.windowX},${settings.windowY}, title bar: ' + describe());
                final bounds = screen.displayBounds();
                app.logger.info('platform: display bounds ${bounds.x},${bounds.y} ${bounds.width}x${bounds.height}, desktop scale ${screen.windowDesktopScale}');
                check(bounds.width > 0 && bounds.height > 0, 'display bounds are known');
                equals(1, screen.windowDesktopScale, 'desktop scale on macOS');
                check(app.systemLocales.length > 0, 'macOS gives at least one locale');

                // Position asked before the window was created
                equals(120, settings.windowX, 'initial settings.windowX');
                equals(140, settings.windowY, 'initial settings.windowY');
                equals(120, runtime.windowPositionX(), 'initial window x');
                equals(140, runtime.windowPositionY(), 'initial window y');

                // Overlay title bar asked before the window was created
                final text = describe();
                check(text.indexOf('style=1 fullSize=1 transparent=1 titleHidden=1') == 0, 'overlay title bar at creation: ' + text);
                check(text.indexOf(' close=12,10 ') != -1, 'buttons at 12,10 at creation: ' + text);

                // Hidden start: the window counts as shown once a frame was presented
                // (the hidden test window itself is never shown)
                return true;
            },
            () -> {
                if (@:privateAccess runtime.windowHidden) return false;
                check(!@:privateAccess runtime.showWindowAfterFrame, 'the show request is consumed');

                settings.windowPosition(300, 220);
                return true;
            },
            () -> {
                if (runtime.windowPositionX() != 300 || runtime.windowPositionY() != 220) return false;
                equals(300, settings.windowX, 'settings.windowX after a move');
                equals(220, settings.windowY, 'settings.windowY after a move');

                // Smaller than the minimum size (200x150): the system refuses
                settings.windowSize(100, 100);
                return true;
            },
            () -> {
                if (settings.windowWidth != 200 || settings.windowHeight != 150) return false;
                check(true, 'the window stops at its minimum size');
                final text = describe();
                check(text.indexOf(' close=12,10 ') != -1, 'buttons still at 12,10 after a resize: ' + text);

                settings.windowMinSize(0, 0);
                settings.trafficLightPosition(30, 4);
                return true;
            },
            () -> {
                final text = describe();
                if (text.indexOf(' close=30,4 ') == -1) return false;
                check(true, 'buttons moved while running');
                settings.windowSize(120, 110);
                return true;
            },
            () -> {
                if (settings.windowWidth != 120 || settings.windowHeight != 110) return false;
                check(true, 'the minimum size was removed');
                final text = describe();
                check(text.indexOf(' close=30,4 ') != -1, 'buttons still at 30,4 after a resize: ' + text);

                settings.titleBarStyle = TitleBarStyle.DEFAULT;
                return true;
            },
            () -> {
                final text = describe();
                if (text.indexOf('style=0 fullSize=0 transparent=0 titleHidden=0') != 0) return false;
                check(text.indexOf(' close=30,4 ') == -1, 'buttons back to the place of the system: ' + text);
                defaultClose = text.substring(text.indexOf(' close='));
                app.logger.info('platform: default title bar: ' + text);

                settings.windowBorderless = true;
                return true;
            },
            () -> {
                final flags:Int = untyped __cpp__('(int)(SDL_GetWindowFlags({0}) & SDL_WINDOW_BORDERLESS)', @:privateAccess runtime.window);
                if (flags == 0) return false;
                check(true, 'window borderless');
                settings.windowBorderless = false;
                return true;
            },
            () -> {
                final flags:Int = untyped __cpp__('(int)(SDL_GetWindowFlags({0}) & SDL_WINDOW_BORDERLESS)', @:privateAccess runtime.window);
                if (flags != 0) return false;
                final text = describe();
                check(text.substring(text.indexOf(' close=')) == defaultClose, 'buttons of the system back with the border: ' + text);

                settings.titleBarStyle = TitleBarStyle.OVERLAY;
                settings.trafficLightPosition(12, 10);
                return true;
            },
            () -> {
                final text = describe();
                if (stepFrames == 299) app.logger.info('platform: title bar: ' + text);
                if (text.indexOf('style=1 fullSize=1 transparent=1 titleHidden=1') != 0) return false;
                if (text.indexOf(' close=12,10 ') == -1) return false;
                check(true, 'overlay title bar set while running');
                return true;
            }
        ];

    }

    function readBackSteps():Array<() -> Bool> {

        return [
            () -> {
                final loaded = new CheckModel();
                check(SaveModel.loadFromKey(loaded, SAVE_KEY), 'the model saved by the first run is read');
                equals(readBackToken, loaded.value, 'value written when the first run quit');
                return true;
            }
        ];

    }

    #end

/// Web: nothing moves a page

    #if (clay && web)

    function webChecks():Void {

        final app = App.app;
        final settings = app.settings;
        equals(120, settings.windowX, 'settings keep the position asked on the web');
        equals(0, app.screen.displayBounds().width, 'no display bounds on the web');
        equals(1, app.screen.windowDesktopScale, 'desktop scale on the web');
        check(app.systemLocales.length > 0, 'navigator.languages gives at least one locale');
        app.logger.info('platform: $checks checks, $failures failed');

    }

    #end

}

class CheckModel extends Model {

    @serialize public var value:String = 'initial';

}
