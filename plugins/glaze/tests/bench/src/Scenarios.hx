package;

/**
 * The single registry of benchmark scenarios.
 *
 * To add a scenario: implement `Scenario` (or extend `BaseScenario`), put the
 * class under `src/scenarios/` (package `scenarios`), and add one line to
 * `all()` below. The order here is the order of execution when
 * `GPUI_BENCH_SCENARIOS` is not set.
 */
class Scenarios {

    public static function all():Array<Scenario> {
        return [
            new CardsScenario(),
            new IdleCardsScenario(),
            new scenarios.StoryDense(),
            new scenarios.StoryDense(() -> story.StoryMeta.of(story.stories.ButtonStory), 'story-button'),
            new scenarios.EditorType(),
            new scenarios.EditorScroll(),
            new scenarios.ScrollTable(),
            new scenarios.Hover(),
        ];
    }

}
