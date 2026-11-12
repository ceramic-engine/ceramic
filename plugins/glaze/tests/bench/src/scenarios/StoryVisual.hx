package scenarios;

import story.StoryMeta;

/**
 * The Ceramic Visual page of the story gallery (`visual()` elements: three
 * animated Ceramic visuals and a Ceramic quad), as `StoryDense` shows a page,
 * with no change of any view: each frame, only the visuals render again and
 * the window draws their rectangles of its texture. Run it on screen
 * (`GLAZE_BENCH_SCREEN=1`) to measure Ceramic's draw and the redrawn area.
 */
class StoryVisual extends StoryDense {

    public function new() {
        super(() -> StoryMeta.of(story.stories.CeramicVisualStory), 'story-visual');
    }

    override function step(frame:Int):Void {
        // Nothing changes in Glaze: the visuals animate on their own
    }

}
