package scenarios;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Keystroke;
import glaze.PlatformInput;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.Component;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import glaze.util.AllocationCounters;
import story.Lib;

/**
 * Shared helpers of the gpui-kit scenarios: the app initialization (once per
 * `App`, like the golden scenes: component plugin, reduced motion, light
 * theme, scrollbars always shown, JetBrains Mono as the monospace family),
 * the standard 1280x1024 window at scale 2 with a gpui-base `Root`, and
 * input dispatch through the same path as the golden scripts
 * (`Window.dispatchEvent` / `dispatchKeystroke` inside `app.update`, then
 * the test dispatcher runs until parked).
 */
class KitBench {

    public static inline final WIDTH:Float = 1280;

    public static inline final HEIGHT:Float = 1024;

    public static inline final SCALE_FACTOR:Float = 2;

    static var kitApp:Null<App> = null;

    static var storyApp:Null<App> = null;

    /** `Component.init` and the golden theme settings, once per app. */
    public static function initKit(app:App):Void {
        if (kitApp == app)
            return;
        kitApp = app;
        app.update(cx -> {
            Component.init(cx);
            applyTheme(cx);
        });
    }

    /** The story crate's `init` (includes `Component.init`) and the golden theme settings, once per app. */
    public static function initStory(app:App):Void {
        if (storyApp == app)
            return;
        storyApp = app;
        app.update(cx -> {
            if (kitApp == app) {
                // The component plugin is already there: only the story parts.
                Lib.extendComponentTranslations();
                story.AppState.init(cx);
                story.Themes.init(cx);
                story.stories.Stories.init(cx);
            }
            else {
                Lib.init(cx);
            }
            applyTheme(cx);
        });
        kitApp = app;
    }

    static function applyTheme(cx:App):Void {
        cx.setReduceMotion(true);
        Theme.change(ThemeMode.Light, null, cx);
        Theme.setScrollbarMode(Always, cx);
        Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
        Theme.syncBase(cx);
    }

    /**
     * The standard bench window (1280x1024, scale 2, no auto draw, no bound
     * input, caching per `caching`) with a `Root` around the view `build`
     * returns, drawn once and activated so it takes keyboard input.
     */
    public static function openWindow(app:App, caching:Bool, build:(Window, App) -> AnyView):Window {
        final window = Window.open(app, {
            width: WIDTH, height: HEIGHT, scaleFactor: SCALE_FACTOR,
            autoDraw: false, bindInput: false, active: false, viewCaching: caching
        }, (window, cx) -> {
            final view = build(window, cx);
            return cx.newEntity((rootCx:Context<Root>) -> new Root(view, window, rootCx));
        });
        window.viewCachingDisabled = !caching;
        window.draw();
        app.update(_ -> window.setActive(true));
        runUntilParked(app);
        return window;
    }

    /**
     * The number of elements (divs, texts, svgs, view elements) created by a
     * full draw of `window`. Needs the `glaze_count_allocations` define, 0
     * without it.
     */
    public static function countElements(window:Window):Int {
        AllocationCounters.reset();
        window.refresh();
        window.draw();
        final count = AllocationCounters.divs + AllocationCounters.texts + AllocationCounters.svgs + AllocationCounters.viewElements;
        AllocationCounters.reset();
        return count;
    }

    public static function runUntilParked(app:App):Void {
        final dispatcher = Std.downcast(app.dispatcher, TestDispatcher);
        if (dispatcher != null)
            dispatcher.runUntilParked();
    }

    /** One platform input (mouse move, scroll...) through the window, like the golden scripts. */
    public static function dispatch(app:App, window:Window, event:PlatformInput):Void {
        app.update(cx -> window.dispatchEvent(event, cx));
        runUntilParked(app);
    }

    /** One keystroke through the window, like the golden `key` / `type` steps. */
    public static function keystroke(app:App, window:Window, keystroke:Keystroke):Void {
        app.update(cx -> window.dispatchKeystroke(keystroke, cx));
        runUntilParked(app);
    }

}
