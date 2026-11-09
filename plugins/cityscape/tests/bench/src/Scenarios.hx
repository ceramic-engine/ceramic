package;

/**
 * The single registry of benchmark scenarios.
 *
 * To add a scenario: implement `Scenario`, put the class under
 * `src/scenarios/` (package `scenarios`), and add one line to `all()` below.
 * The order here is the order of execution when `CITYSCAPE_BENCH_SCENARIOS`
 * is not set.
 */
class Scenarios {

    public static function all():Array<Scenario> {
        return [
            new scenarios.RangeSort(),
            // Not typed in the macro context of `BenchRunner.benchDir()`
            // (the model reaches Glaze and Ceramic through `Platform`)
            #if !macro
            new scenarios.ModelOpen(),
            new scenarios.ModelEdit(),
            new scenarios.ModelType(),
            new scenarios.ModelReadLines(),
            new scenarios.Tokenize('tokenize-js-full', 0, false),
            new scenarios.Tokenize('tokenize-js-edit', 0, true),
            new scenarios.Tokenize('tokenize-10k-full', 10000, false),
            new scenarios.Tokenize('tokenize-10k-edit', 10000, true),
            new scenarios.ViewScenarios.ViewOpen(),
            new scenarios.ViewScenarios.ViewScroll('view-scroll-line', false),
            new scenarios.ViewScenarios.ViewScroll('view-scroll-page', true),
            new scenarios.ViewScenarios.ViewScroll('view-scroll-wrap', false, null, {wordWrap: 'on'}),
            new scenarios.ViewScenarios.ViewType('view-type'),
            new scenarios.ViewScenarios.ViewType('view-type-suggest', null, 1, 1, false, true),
            new scenarios.ViewScenarios.ViewType('view-type-nosuggest', {quickSuggestions: false, suggestOnTriggerCharacters: false}),
            new scenarios.ViewScenarios.ViewType('view-type-multi', null, 10),
            new scenarios.ViewScenarios.ViewType('view-type-two', null, 1, 2),
            new scenarios.ViewScenarios.ViewType('view-type-wrap', {wordWrap: 'on'}),
            new scenarios.ViewScenarios.ViewType('view-type-long', null, 1, 1, true),
            new scenarios.ViewScenarios.ViewType('view-type-long-wrap', {wordWrap: 'on'}, 1, 1, true),
            new scenarios.ViewScenarios.ViewDecorated(),
            new scenarios.ViewScenarios.ViewScroll('view-scroll-cjk', false, scenarios.ViewScenarios.ViewTexts.cjkEmoji),
            #end
        ];
    }

}
