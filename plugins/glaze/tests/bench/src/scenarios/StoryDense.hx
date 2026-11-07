package scenarios;

import Scenario;
import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.Model;
import glaze.Window;
import story.StoryContainer;
import story.StoryMeta;

import glaze.Prelude.*;

/**
 * One dense page of the story gallery (the theme colors story by default,
 * the densest page: about 900 elements against 600 for the buttons story,
 * as the gallery shows it: `StoryContainer.panel`) in the standard window,
 * under a one line header that displays a frame counter. `step` increments the counter (an
 * observable field), so the header re-renders every frame: with view
 * caching the story panel below is reused, without it the whole page
 * renders again.
 */
class StoryDense extends BaseScenario {

    /** Elements created by a full draw (needs `glaze_count_allocations`). */
    public var elementCount:Int = 0;

    var app:App;

    var window:Window;

    var counter:Entity<FrameCounter>;

    /** The story page (`() -> StoryMeta.of(story.stories.XStory)`), the theme colors story by default. */
    final page:() -> StoryMeta;

    public function new(?page:() -> StoryMeta, name:String = 'story-dense') {
        super(name);
        this.page = page != null ? page : () -> StoryMeta.of(story.stories.ThemeColorsStory);
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        KitBench.initStory(app);
        counter = app.newEntity(_ -> new FrameCounter());
        final counter = this.counter;
        window = KitBench.openWindow(app, caching, (window, cx) -> {
            final panel:AnyView = StoryContainer.panel(page(), window, cx);
            return cx.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> {
                final frame = counter.read(cx).frame;
                return div().sizeFull().flex().flexCol()
                    .child(div().h(px(24)).px2().textSm().child('frame $frame'))
                    .child(div().flex1().minH0().child(panel));
            }));
        });
        elementCount = KitBench.countElements(window);
        return window;
    }

    override function step(frame:Int):Void {
        final model = counter.read(app);
        model.frame = model.frame + 1;
    }

}

class FrameCounter extends Model {

    @observe public var frame:Int = 0;

    public function new() {
        super();
    }

}
