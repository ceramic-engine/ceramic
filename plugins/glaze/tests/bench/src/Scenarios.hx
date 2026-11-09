package;

import scenarios.Components.ComponentsKind;

/**
 * The single registry of benchmark scenarios.
 *
 * To add a scenario: implement `Scenario` (or extend `BaseScenario`), put the
 * class under `src/scenarios/` (package `scenarios`), and add one line to
 * `all()` below. The order here is the order of execution when
 * `GLAZE_BENCH_SCENARIOS` is not set.
 */
class Scenarios {

    public static function all():Array<Scenario> {
        return [
            new CardsScenario(),
            new IdleCardsScenario(),
            new scenarios.StoryDense(),
            new scenarios.StoryDense(() -> story.StoryMeta.of(story.stories.ButtonStory), 'story-button'),
            new scenarios.ScrollTable(),
            new scenarios.Hover(),
            new scenarios.StoryScroll(() -> story.StoryMeta.of(story.stories.ComboboxStory), 'story-combobox-scroll'),
            new scenarios.StoryScroll(() -> story.StoryMeta.of(story.stories.ButtonStory), 'story-button-scroll'),
            new scenarios.StoryScroll(() -> story.StoryMeta.of(story.stories.InputStory), 'story-input-scroll'),
            new scenarios.StoryScroll(null, 'gallery-combobox-scroll', 40, 'Combobox'),
            new scenarios.StoryScroll(null, 'gallery-button-scroll', 40, 'Button'),
            new scenarios.StoryScroll(null, 'gallery-input-scroll', 40, 'Input'),
            new scenarios.Components(Persistent),
            new scenarios.Components(Views),
            new scenarios.Components(Stateless),
            new scenarios.Components(RenderOnceRows),
        ];
    }

}
