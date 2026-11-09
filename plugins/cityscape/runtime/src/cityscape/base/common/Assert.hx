// Ported from vscode src/vs/base/common/assert.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Errors.BugIndicatingError;

/**
 * Module functions of assert.ts. Only what the ported code needs so far.
 */
class Assert {

    /**
     * Throws a `BugIndicatingError` when `condition` does not hold.
     */
    public static function assert(condition:Bool, message:String = 'unexpected state'):Void {
        if (!condition) {
            throw new BugIndicatingError('Assertion Failed: ' + message);
        }
    }

    /**
     * Reports an unexpected error (without throwing) when `condition` does not hold.
     */
    public static function softAssert(condition:Bool):Void {
        if (!condition) {
            Errors.onUnexpectedError(new BugIndicatingError('Soft Assertion Failed'));
        }
    }

    /**
     * Reports an unexpected error (without throwing) when `condition()` returns false.
     */
    public static function assertFn(condition:() -> Bool):Void {
        if (!condition()) {
            Errors.onUnexpectedError(new BugIndicatingError('Assertion Failed'));
        }
    }

    /**
     * Whether `predicate` holds for every pair of adjacent items.
     */
    public static function checkAdjacentItems<T>(items:Array<T>, predicate:(item1:T, item2:T) -> Bool):Bool {
        var i = 0;
        while (i < items.length - 1) {
            final a = items[i];
            final b = items[i + 1];
            if (!predicate(a, b)) {
                return false;
            }
            i++;
        }
        return true;
    }

}
