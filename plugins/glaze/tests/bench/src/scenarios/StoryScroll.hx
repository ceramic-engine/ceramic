package scenarios;

import Scenario;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Modifiers;
import gpui.Point;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.Window;
import story.StoryContainer;
import story.StoryMeta;

import gpui.Prelude.*;

/**
 * One story page of the gallery (`StoryContainer.panel`, the scrollable
 * container the gallery shows) filling the standard window, scrolled with
 * the mouse wheel: `step` dispatches a `ScrollEvent` of 30 pixels at the
 * window center. The direction flips every `framesPerDirection` frames, and
 * earlier when a scroll changes nothing (the end of the content is reached),
 * so every measured frame scrolls. With `galleryStory`, the whole gallery
 * is shown (sidebar, header, story area) with that story selected, as in
 * the gallery app.
 */
class StoryScroll extends BaseScenario {

    public static inline final PIXELS_PER_FRAME:Float = 30;

    var app:App;

    var window:Window;

    var center:Point;

    var down:Bool = true;

    var framesInDirection:Int = 0;

    final framesPerDirection:Int;

    final page:() -> StoryMeta;

    /** The story name shown in the full gallery (sidebar, header), or null for the page alone. */
    final galleryStory:Null<String>;

    public function new(page:() -> StoryMeta, name:String, framesPerDirection:Int = 40, ?galleryStory:String) {
        super(name);
        this.page = page;
        this.framesPerDirection = framesPerDirection;
        this.galleryStory = galleryStory;
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        down = true;
        framesInDirection = 0;
        KitBench.initStory(app);
        if (galleryStory != null) {
            // The whole gallery, the story picked in the sidebar like a click
            // does (`Gallery.selectStory`); the wheel goes to the center of
            // the story area (right of the 255 px sidebar, below the header)
            var gallery:Null<gpui.Entity<story.Gallery>> = null;
            window = KitBench.openWindow(app, caching, (window, cx) -> {
                gallery = story.Gallery.view(null, window, cx);
                return gallery;
            });
            final name = galleryStory;
            app.update(cx -> gallery.update(cx, (g, gcx) -> {
                g.selectStory(name, window, gcx);
            }));
            KitBench.runUntilParked(app);
            window.draw();
            center = new Point(255 + (KitBench.WIDTH - 255) / 2, KitBench.HEIGHT / 2 + 50);
        }
        else {
            window = KitBench.openWindow(app, caching, (window, cx) -> {
                final panel:AnyView = StoryContainer.panel(page(), window, cx);
                return cx.newEntity((_:Context<BenchView>) -> new BenchView((_, _) -> div().sizeFull().child(panel)));
            });
            center = new Point(KitBench.WIDTH / 2, KitBench.HEIGHT / 2);
        }
        return window;
    }

    override function step(frame:Int):Void {
        if (framesInDirection >= framesPerDirection) {
            down = !down;
            framesInDirection = 0;
        }
        if (!scroll() && framesInDirection > 0) {
            // The end of the content: go back the other way this same frame
            down = !down;
            framesInDirection = 0;
            scroll();
        }
        framesInDirection++;
    }

    /** One wheel step in the current direction; true when it moved the content (the window needs a draw). */
    function scroll():Bool {
        final delta = new Point(0, down ? -PIXELS_PER_FRAME : PIXELS_PER_FRAME);
        KitBench.dispatch(app, window, new ScrollEvent(center, ScrollDelta.Pixels(delta), Modifiers.none()));
        return window.dirty;
    }

}
