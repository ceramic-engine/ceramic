package ceramic;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Assertion utility for runtime validation in debug builds.
 * 
 * This class provides compile-time macros for asserting conditions during development.
 * All assertions are automatically removed from release builds for zero runtime overhead.
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Basic assertion
 * Assert.assert(value > 0);
 * 
 * // Assertion with custom message
 * Assert.assert(array.length > 0, "Array must not be empty");
 * 
 * // Complex condition
 * Assert.assert(x >= 0 && x <= 100, "Value out of range");
 * ```
 * 
 * ## Build Configuration
 * 
 * - Assertions are active in debug builds by default
 * - Use `-D ceramic_assert` to enable assertions in release builds
 * - Use `-D ceramic_assert_print_stack` to print stack traces on assertion failures
 * 
 * @see ceramic.Utils.printStackTrace
 */
class Assert {

    /**
     * Assert the expression evaluates to `true`.
     * This check is only done in `debug` builds and doesn't affect `release` builds.
     * 
     * When an assertion fails, it logs an error and throws an exception with the
     * stringified expression and optional reason.
     * 
     * @param expr The expression to evaluate. Must resolve to a boolean value.
     * @param reason Optional custom error message to include when assertion fails.
     *               If not provided, defaults to "Assertion failure".
     * 
     * @throws String Exception containing the failed expression and reason
     * 
     * ```haxe
     * Assert.assert(player.health > 0);
     * Assert.assert(items.length == expectedCount, "Item count mismatch");
     * ```
     */
    macro public static function assert(expr:Expr, ?reason:ExprOf<String>) {

        #if (debug || ceramic_assert)
        var str = haxe.macro.ExprTools.toString(expr);

        reason = switch(reason) {
            case macro null: macro ' (Assertion failure)';
            case _: macro ' (' + $reason + ')';
        }

        return macro @:pos(Context.currentPos()) {
            if (!$expr) {
                #if ceramic_assert_print_stack
                ceramic.Utils.printStackTrace();
                #end
                ceramic.App.app.logger.error($v{str} + $reason);
                throw $v{str} + $reason;
            }
        }
        #else
        return macro null;
        #end

    }

}
