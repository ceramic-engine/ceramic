package;

import testing.TestRunner;

/**
 * List of all unit test cases. Add new test classes here.
 */
class Tests {

    public static function register(runner:TestRunner):Void {

        runner.add(new tests.PluginSetupTest());
        runner.add(new tests.HaxeStringTest());
        runner.add(new tests.InterfacesTest());
        runner.add(new tests.core.RangeTest());
        runner.add(new tests.config.EditorConfigurationTest());
        runner.add(new tests.config.MigrateOptionsTest());
        runner.add(new tests.config.EditorOptionsTruthTest());

    }

}
