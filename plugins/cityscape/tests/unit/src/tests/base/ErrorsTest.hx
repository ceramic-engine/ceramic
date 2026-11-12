package tests.base;

import cityscape.base.common.Errors;
import testing.TestCase;

/**
 * `Errors`' default handler (Cityscape tests, not ported): it reports the
 * error with `haxe.Log.trace(message, null)`. Ceramic's Unity trace read
 * the file name of the missing position and threw, so an unexpected error
 * caught by the editor (a cursor state computer) escaped as a
 * NullReferenceException instead of being reported.
 */
class ErrorsTest extends TestCase {

    function testDefaultHandlerReportsWithoutThrowing() {
        final previous = Errors.unexpectedErrorHandler;
        // The default handler, whatever a previous test left
        Errors.unexpectedErrorHandler = @:privateAccess Errors.defaultHandler;
        var threw = false;
        try {
            Errors.onUnexpectedError('ErrorsTest: an expected report, not a failure');
            haxe.Log.trace('ErrorsTest: a trace without position', null);
        }
        catch (e:Dynamic) {
            threw = true;
        }
        Errors.unexpectedErrorHandler = previous;
        assertFalse(threw);
    }

}
