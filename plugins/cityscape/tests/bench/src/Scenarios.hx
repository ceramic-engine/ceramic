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
        ];
    }

}
