package testing;

import haxe.PosInfos;

/**
 * Base class of unit test cases.
 *
 * Every instance method whose name starts with `test` is run by `TestRunner`.
 * Optional `setup()` and `teardown()` are called around each test method.
 */
@:keepSub
class TestCase {

    @:allow(testing.TestRunner)
    var failures:Array<String> = [];

    @:allow(testing.TestRunner)
    var assertions:Int = 0;

    public function new() {}

    public function setup():Void {}

    public function teardown():Void {}

    /**
     * Called first by a test that counts renders or checks what the view
     * cache reuses: turns off the cache check of `glaze_verify_cache` for
     * this test (the check renders every cached view for real, and reports
     * the staleness some of these tests leave on purpose).
     */
    function countsRenders():Void {
        #if glaze_verify_cache
        glaze.Window.verifyCache = false;
        #end
    }

    function fail(message:String, ?pos:PosInfos):Void {
        failures.push('${pos.fileName}:${pos.lineNumber}: $message');
    }

    function assertTrue(value:Bool, ?message:String, ?pos:PosInfos):Void {
        assertions++;
        if (!value) {
            fail(message != null ? message : 'expected true', pos);
        }
    }

    function assertFalse(value:Bool, ?message:String, ?pos:PosInfos):Void {
        assertions++;
        if (value) {
            fail(message != null ? message : 'expected false', pos);
        }
    }

    function assertEquals<T>(expected:T, actual:T, ?message:String, ?pos:PosInfos):Void {
        assertions++;
        if (expected != actual) {
            fail((message != null ? message + ': ' : '') + 'expected $expected but got $actual', pos);
        }
    }

    function assertFloatEquals(expected:Float, actual:Float, epsilon:Float = 0.00001, ?message:String, ?pos:PosInfos):Void {
        assertions++;
        if (Math.isNaN(expected) != Math.isNaN(actual) || Math.abs(expected - actual) > epsilon) {
            fail((message != null ? message + ': ' : '') + 'expected $expected but got $actual (epsilon $epsilon)', pos);
        }
    }

    function assertNull(value:Dynamic, ?message:String, ?pos:PosInfos):Void {
        assertions++;
        if (value != null) {
            fail((message != null ? message + ': ' : '') + 'expected null but got $value', pos);
        }
    }

    function assertNotNull(value:Dynamic, ?message:String, ?pos:PosInfos):Void {
        assertions++;
        if (value == null) {
            fail(message != null ? message : 'expected a non-null value', pos);
        }
    }

    function assertRaises(fn:() -> Void, ?message:String, ?pos:PosInfos):Void {
        assertions++;
        var raised = false;
        try {
            fn();
        }
        catch (e:Dynamic) {
            raised = true;
        }
        if (!raised) {
            fail(message != null ? message : 'expected an exception', pos);
        }
    }

}
