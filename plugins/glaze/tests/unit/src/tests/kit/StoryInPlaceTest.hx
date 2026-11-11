package tests.kit;

import glaze.App;
import glaze.TestClipboard;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import glaze.scene.SceneDump;
import story.StoryContainer;
import story.StoryMeta;
import testing.TestCase;

/**
 * Story pages checked like the golden's cache equivalence
 * (`test/golden/src/CacheEquivalence.hx`): each view notified alone, twice
 * over, must give the frame of a full redraw without view caching. Most of
 * these frames are drawn in place (see `InPlaceRenderingTest`); the frames
 * are compared as drawn (the in place check of `glaze_verify_cache` is
 * turned off: it would draw a full frame after each of them).
 */
class StoryInPlaceTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    final verifyCacheWas = Window.verifyCache;

    /** `TitleBar.isWeb` before the test: true on Unity and the web, restored by `teardown` */
    final isWebWas = glaze.kit.TitleBar.isWeb;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.platformClipboard = new TestClipboard();
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        glaze.kit.TitleBar.isWeb = false;
        app.update(cx -> {
            story.Lib.init(cx);
            story.AppState.global(cx).showAppMenuBar = false;
            cx.setReduceMotion(true);
            Theme.setMode(ThemeMode.Light, cx);
            Theme.setScrollbarMode(Always, cx);
            Theme.syncBase(cx);
        });
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        Window.verifyCache = verifyCacheWas;
        glaze.kit.TitleBar.isWeb = isWebWas;
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    function open(meta:() -> StoryMeta):Window {
        window = Window.open(app, {width: 512, height: 512, scaleFactor: 2, autoDraw: false, active: false, bindInput: false}, (window, cx) -> {
            return Root.component().child(StoryContainer.panel(meta(), window, cx));
        });
        window.draw();
        app.update(_ -> window.setActive(true));
        dispatcher.runUntilParked();
        window.drawIfDirty();
        return window;
    }

    /** The scene and the frame summary (view ids numbered in order: the tooltip overlay makes new ones) */
    static function frame(window:Window):String {
        final ids = new Map<String, Int>();
        final summary = ~/view=([0-9]+)/g.map(window.debugFrameSummary(), re -> {
            final id = re.matched(1);
            if (!ids.exists(id)) ids.set(id, Lambda.count(ids));
            return 'view=#' + ids.get(id);
        });
        return SceneDump.toJson(window.renderedScene(), 1024, 1024) + '\n' + summary;
    }

    function check(window:Window, ?pos:haxe.PosInfos):Void {
        Window.verifyCache = false;
        window.viewCachingDisabled = true;
        window.refresh();
        window.draw();
        final reference = frame(window);
        window.viewCachingDisabled = false;
        window.refresh();
        window.draw();
        assertEquals(reference, frame(window), 'refresh with caching', pos);
        final views = [for (id in @:privateAccess window.trackers.keys()) id];
        views.sort((a, b) -> a - b);
        final inPlaceBefore = window.inPlaceFrameCount;
        for (round in 0...2) {
            for (id in views) {
                final before = window.inPlaceFrameCount;
                window.app.update(cx -> cx.notify(id));
                window.drawIfDirty();
                final inPlace = window.inPlaceFrameCount > before;
                final problem = window.debugCheckViewRanges(0);
                if (problem != null) {
                    fail('notify view $id (round $round, in place $inPlace): $problem', pos);
                    return;
                }
                final now = frame(window);
                if (now != reference) {
                    final a = now.split('\n');
                    final b = reference.split('\n');
                    var line = 0;
                    while (line < a.length && line < b.length && a[line] == b[line]) line++;
                    final context = [for (i in Std.int(Math.max(0, line - 3))...line + 3) '$i: now=${a[i]} | reference=${b[i]}'].join('\n');
                    fail('notify view $id (round $round, in place $inPlace): differs at line $line\n$context', pos);
                    return;
                }
            }
        }
        window.draw();
        assertEquals(reference, frame(window), 'clean draw', pos);
        assertTrue(window.inPlaceFrameCount > inPlaceBefore, 'views rendered in place', pos);
    }

    /** A view whose render is handed to a full frame keeps the element states of the views it drew */
    function testTextareaStory() {
        check(open(() -> StoryMeta.of(story.stories.TextareaStory)));
    }

    function testInputStory() {
        check(open(() -> StoryMeta.of(story.stories.InputStory)));
    }

    /** A view rendered in place resolves key bindings in the last frame whole */
    function testCommandStory() {
        check(open(() -> StoryMeta.of(story.stories.CommandStory)));
    }

    function testTableStory() {
        check(open(() -> StoryMeta.of(story.stories.TableStory)));
    }

    function testDataTableStory() {
        check(open(() -> StoryMeta.of(story.stories.DataTableStory)));
    }

}
