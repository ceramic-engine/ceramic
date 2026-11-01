package testing;

import haxe.CallStack;

using StringTools;

/**
 * Minimal test runner: runs every `test*` method of the registered test cases,
 * prints a report and exits the process with a non-zero code on failure.
 *
 * An optional filter can be given with the `GPUI_TEST_FILTER` environment
 * variable (matched against `ClassName.methodName`).
 */
class TestRunner {

    var cases:Array<TestCase> = [];

    public function new() {}

    public function add(testCase:TestCase):Void {
        cases.push(testCase);
    }

    public function runAndExit():Void {
        exit(run() ? 0 : 1);
    }

    public function run():Bool {

        final filter = env('GPUI_TEST_FILTER');

        var numTests = 0;
        var numFailed = 0;
        var numAssertions = 0;

        for (testCase in cases) {
            final className = Type.getClassName(Type.getClass(testCase));
            final methods = Type.getInstanceFields(Type.getClass(testCase)).filter(name -> name.startsWith('test'));
            methods.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

            for (method in methods) {
                final fullName = '$className.$method';
                if (filter != null && filter.length > 0 && fullName.indexOf(filter) == -1)
                    continue;

                numTests++;
                testCase.failures = [];
                testCase.assertions = 0;

                try {
                    testCase.setup();
                    Reflect.callMethod(testCase, Reflect.field(testCase, method), []);
                    testCase.teardown();
                }
                catch (e:Dynamic) {
                    testCase.failures.push('uncaught exception: $e' + CallStack.toString(CallStack.exceptionStack()));
                }

                numAssertions += testCase.assertions;

                if (testCase.failures.length > 0) {
                    numFailed++;
                    print('FAIL $fullName');
                    for (failure in testCase.failures) {
                        print('    $failure');
                    }
                }
                else {
                    print('ok   $fullName');
                }
            }
        }

        print('');
        print('$numTests tests, $numAssertions assertions, $numFailed failed');

        return numFailed == 0;

    }

    static function print(message:String):Void {
        #if js
        js.Syntax.code('console.log({0})', message);
        #else
        Sys.println(message);
        #end
    }

    static function env(name:String):Null<String> {
        #if js
        return js.Syntax.code('(typeof process !== "undefined" ? process.env[{0}] : null)', name);
        #elseif sys
        return Sys.getEnv(name);
        #else
        return null;
        #end
    }

    static function exit(code:Int):Void {
        #if js
        js.Syntax.code('process.exit({0})', code);
        #elseif sys
        Sys.exit(code);
        #end
    }

}
