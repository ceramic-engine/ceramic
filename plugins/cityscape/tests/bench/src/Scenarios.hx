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
            #end
        ];
    }

}
