// Ported from vscode src/vs/base/common/errors.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of errors.ts. Only what the ported code needs so far.
 *
 * Monaco's `errorHandler` is a global with a settable handler; here the
 * handler is a static function that can be replaced (an application wide
 * setting, not editor state).
 */
class Errors {

    /**
     * Called with the errors that are caught and reported instead of being
     * thrown (errors in event listeners, in cursor state computers...).
     * The default prints the error with its stack.
     */
    public static var unexpectedErrorHandler:(e:Dynamic) -> Void = defaultHandler;

    static function defaultHandler(e:Dynamic):Void {
        final stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
        haxe.Log.trace('Unexpected error: ' + Std.string(e) + stack, null);
    }

    public static function onUnexpectedError(e:Dynamic):Void {
        unexpectedErrorHandler(e);
    }

}

/**
 * Monaco's `BugIndicatingError`: thrown when an internal invariant does not
 * hold (for example reading a disposed model).
 */
class BugIndicatingError extends haxe.Exception {

    public function new(?message:String) {
        super(message != null ? message : 'An unexpected bug occurred.');
    }

}
