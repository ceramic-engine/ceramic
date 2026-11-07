package testing;

import haxe.CallStack;

using StringTools;

/**
 * Minimal test runner: runs every `test*` method of the registered test cases,
 * prints a report and exits the process with a non-zero code on failure.
 *
 * Asynchronous tests are methods whose name starts with `asyncTest`: they
 * receive a `done` callback to call once finished, and run one after the
 * other, after the synchronous tests, while the Ceramic app loop runs (they
 * fail if `done` is not called within `ASYNC_TIMEOUT` seconds).
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

    /** Seconds an asynchronous test has to call `done` */
    public static inline final ASYNC_TIMEOUT:Float = 30.0;

    var numTests = 0;
    var numFailed = 0;
    var numAssertions = 0;

    public function runAndExit():Void {
        #if unity
        // One line per message in the Unity log, without a stack trace each
        untyped __cs__('UnityEngine.Application.SetStackTraceLogType(UnityEngine.LogType.Log, UnityEngine.StackTraceLogType.None)');
        #end
        runSync();
        runAsync(() -> exit(report() ? 0 : 1));
    }

    public function run():Bool {
        runSync();
        return report();
    }

    function report():Bool {
        print('');
        print('$numTests tests, $numAssertions assertions, $numFailed failed');
        return numFailed == 0;
    }

    function asyncTests():Array<{testCase:TestCase, method:String, fullName:String}> {
        final filter = env('GPUI_TEST_FILTER');
        final result = [];
        for (testCase in cases) {
            final className = Type.getClassName(Type.getClass(testCase));
            final methods = Type.getInstanceFields(Type.getClass(testCase)).filter(name -> name.startsWith('asyncTest'));
            methods.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
            for (method in methods) {
                final fullName = '$className.$method';
                if (filter != null && filter.length > 0 && fullName.indexOf(filter) == -1)
                    continue;
                result.push({testCase: testCase, method: method, fullName: fullName});
            }
        }
        return result;
    }

    function runAsync(finished:() -> Void):Void {
        final tests = asyncTests();
        var index = 0;
        function next():Void {
            if (index >= tests.length) {
                finished();
                return;
            }
            final test = tests[index++];
            final testCase = test.testCase;
            numTests++;
            testCase.failures = [];
            testCase.assertions = 0;
            var completed = false;
            function complete(?timedOut:Bool):Void {
                if (completed)
                    return;
                completed = true;
                if (timedOut == true)
                    testCase.failures.push('timed out after $ASYNC_TIMEOUT seconds');
                try {
                    testCase.teardown();
                }
                catch (e:Dynamic) {
                    testCase.failures.push('uncaught exception in teardown: $e');
                }
                numAssertions += testCase.assertions;
                if (testCase.failures.length > 0) {
                    numFailed++;
                    print('FAIL ${test.fullName}');
                    for (failure in testCase.failures) {
                        print('    $failure');
                    }
                }
                else {
                    print('ok   ${test.fullName}');
                }
                // Continue from a fresh frame
                ceramic.App.app.onceImmediate(next);
            }
            ceramic.Timer.delay(null, ASYNC_TIMEOUT, () -> complete(true));
            try {
                testCase.setup();
                Reflect.callMethod(testCase, Reflect.field(testCase, test.method), [() -> complete()]);
            }
            catch (e:Dynamic) {
                testCase.failures.push('uncaught exception: $e' + CallStack.toString(CallStack.exceptionStack()));
                complete();
            }
        }
        next();
    }

    function runSync():Bool {

        final filter = env('GPUI_TEST_FILTER');

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

        return numFailed == 0;

    }

    static function print(message:String):Void {
        #if js
        js.Syntax.code('console.log({0})', message);
        #elseif unity
        untyped __cs__('UnityEngine.Debug.Log({0})', message);
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
        #elseif unity
        // Sys.exit would end the Unity process without writing its log: in the
        // editor (batch play mode, see CeramicBatchMode.cs of the Unity template)
        // EditorApplication.Exit returns the code, in a player Application.Quit does
        untyped __cs__('\n#if UNITY_EDITOR\nUnityEditor.EditorApplication.Exit({0});\n#else\nUnityEngine.Application.Quit({0});\n#endif\n', code);
        #elseif sys
        Sys.exit(code);
        #end
    }

}
