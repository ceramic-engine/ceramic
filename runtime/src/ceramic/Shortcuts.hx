package ceramic;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
#else
import ceramic.App;
import ceramic.Screen;
import ceramic.Settings;
import ceramic.System;
import haxe.PosInfos;
#end

/**
 * Convenience static accessors and utility methods for common Ceramic functionality.
 *
 * Shortcuts provides quick access to frequently used Ceramic singletons and utilities,
 * eliminating the need for repetitive code. By importing this class with `import ceramic.Shortcuts.*;`,
 * you gain direct access to app, screen, audio, input, and other core systems.
 * This import is done by default via `import.hx` in Ceramic projects.
 *
 * Key features:
 * - **Static accessors**: Direct access to app, screen, audio, input, settings, log, systems
 * - **Observation utilities**: Methods for managing autorun scopes (unobserve, reobserve, cease)
 * - **Conditional execution**: `until()` macro for reactive condition checking
 * - **Debug assertions**: `assert()` macro for development-time validation
 *
 * Usage examples:
 * ```haxe
 * import ceramic.Shortcuts.*;
 * ```
 *
 * ```haxe
 * // Direct access to singletons
 * app.onUpdate(this, update);
 * screen.onResize(this, handleResize);
 * audio.playSound(mySound);
 *
 * // Wait for condition on observable player health field
 * until(player.health <= 0, () -> {
 *     showGameOver();
 * });
 *
 * // Debug assertion
 * assert(player != null, "Player must exist");
 * ```
 *
 * @see App
 * @see Screen
 * @see Audio
 * @see Input
 */
class Shortcuts {

    #if !macro

    /**
     * Shared app instance
     */
    public static var app(get,never):App;
    #if !haxe_server inline #end static function get_app():App { return App.app; }

    /**
     * Shared screen instance
     */
    public static var screen(get,never):Screen;
    #if !haxe_server inline #end static function get_screen():Screen { return App.app.screen; }

    /**
     * Shared audio instance
     */
    public static var audio(get,never):Audio;
    #if !haxe_server inline #end static function get_audio():Audio { return App.app.audio; }

    /**
     * Shared input instance
     */
    public static var input(get,never):Input;
    #if !haxe_server inline #end static function get_input():Input { return App.app.input; }

    /**
     * Shared settings instance
     */
    public static var settings(get,never):Settings;
    #if !haxe_server inline #end static function get_settings():Settings { return App.app.settings; }

    /**
     * Shared logger instance
     */
    public static var log(get,never):Logger;
    #if !haxe_server inline #end static function get_log():Logger { return App.app.logger; }

    /**
     * Systems manager
     */
    public static var systems(get,never):Systems;
    #if !haxe_server inline #end static function get_systems():Systems { return App.app.systems; }

    /**
     * Temporarily stops observing property changes in the current autorun scope.
     *
     * Use this when you need to read observable properties without creating
     * dependencies in the current autorun. Must be paired with `reobserve()`
     * to restore observation.
     *
     * Example:
     * ```haxe
     * autorun(() -> {
     *     // This creates a dependency
     *     var x = observable.value;
     *
     *     unobserve();
     *     // This read doesn't create a dependency
     *     var y = observable.otherValue;
     *     reobserve();
     * });
     * ```
     *
     * @see reobserve
     * @see tracker.Autorun
     */
    inline public static function unobserve():Void { tracker.Autorun.unobserve(); }

    /**
     * Resumes observing property changes after a call to `unobserve()`.
     *
     * Restores the autorun's ability to track dependencies on observable
     * properties. Always pair this with a preceding `unobserve()` call.
     *
     * @see unobserve
     * @see tracker.Autorun
     */
    inline public static function reobserve():Void { tracker.Autorun.reobserve(); }

    /**
     * Stops and destroys the current autorun from within its own callback.
     *
     * Use this to create one-shot autoruns or to stop an autorun based on
     * internal conditions. The distinctive name 'cease' avoids conflicts
     * with common method names.
     *
     * Example:
     * ```haxe
     * autorun(() -> {
     *     if (condition.met) {
     *         doSomething();
     *         cease(); // This autorun won't run again
     *     }
     * });
     * ```
     *
     * @see tracker.Autorun
     */
    inline public static function cease():Void { tracker.Autorun.cease(); }

    #end

    /**
     * Creates an autorun that waits for a condition to become true, then executes a callback once.
     *
     * This macro provides a reactive way to wait for conditions without polling.
     * The condition is checked whenever any observed properties within it change.
     * Once true, the callback executes and the autorun is automatically destroyed.
     *
     * Syntax variations:
     * ```haxe
     * // Auto-attach to 'this' if available (common in Entity subclasses)
     * until(player.isReady, () -> startGame());
     *
     * // Explicitly attach to null (no owner)
     * until(null, player.isReady, () -> startGame());
     *
     * // Attach to specific entity (cleaned up when entity is destroyed)
     * until(myEntity, player.isReady, () -> startGame());
     * ```
     *
     * The autorun is automatically cleaned up:
     * - When the condition becomes true (after callback execution)
     * - When the owner entity is destroyed (if attached)
     *
     * @param exprs Variable arguments: [owner], condition, callback
     * @return The created Autorun instance (can be manually destroyed if needed)
     */
    macro public static function until(exprs:Array<Expr>):ExprOf<tracker.Autorun> {

        var condition;
        var callback;
        var instance;

        if (exprs.length > 2) {
            condition = exprs[1];
            callback = exprs[2];
            instance = exprs[0];
        }
        else {
            condition = exprs[0];
            callback = exprs[1];
            try {
                // We try to resolve `this` type.
                // If it succeeds, we can attach the autorun to it
                Context.typeExpr(macro this);
                instance = macro this;
            }
            catch (e) {
                // If `this` typing failed, it's likely because
                // it is not available and we are calling from
                // a static, class method, let's not use it then
                instance = macro null;
            }
        }

        return macro @:privateAccess tracker.Until._until($instance, function() {
            return $condition;
        }, $callback);

    }

    /**
     * Debug-time assertion that validates expressions evaluate to true.
     *
     * Assertions help catch logic errors during development. They are:
     * - Active in debug builds (or when -D ceramic_assert is set)
     * - Completely removed from release builds (zero runtime cost)
     * - Logged as errors with optional custom messages
     *
     * Examples:
     * ```haxe
     * assert(player != null);
     * assert(health > 0, "Player health must be positive");
     * assert(items.length < maxItems, 'Too many items: ${items.length}');
     * ```
     *
     * Failed assertions:
     * - Log an error with the expression and optional reason
     * - Throw an exception to halt execution
     * - Can print stack traces with -D ceramic_assert_print_stack
     *
     * @param expr The expression to validate (must evaluate to true)
     * @param reason Optional explanation shown when assertion fails
     */
    macro public static function assert(expr:Expr, ?reason:ExprOf<String>) {

        #if (debug || ceramic_assert)
        var str = ExprTools.toString(expr);

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
