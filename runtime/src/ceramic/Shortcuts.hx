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
 * Shortcuts adds convenience identifiers to access ceramic app, screen, ...
 * Use it by adding `import ceramic.Shortcuts.*;` in your files.
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
     * Ensures current `autorun` won't be affected by the code after this call.
     * `reobserve()` should be called to restore previous state.
     */
    inline public static function unobserve():Void { tracker.Autorun.unobserve(); }

    /**
     * Resume observing values and resume affecting current `autorun` scope.
     * This should be called after an `unobserve()` call.
     */
    inline public static function reobserve():Void { tracker.Autorun.reobserve(); }

    /**
     * Unbinds and destroys current `autorun`. The name `cease()` has been chosed there
     * so that it is unlikely to collide with other more common names suchs as `stop`, `unbind` etc...
     * and should make it more recognizable, along with `observe()` and `unobserve()`.
     */
    inline public static function cease():Void { tracker.Autorun.cease(); }

    #end

    /**
     * Wait until the observable condition becomes true to execute the callback once (and only once). Creates an `Autorun` instance and returns it.
     * Usage:
     * ```haxe
     * // Resulting autorun attached to "this" if available and a valid entity
     * until(something == true, callback);
     * // Add "null" if you don't want it to be attached to anything
     * until(null, something == true, callback);
     * // Attach to another entity
     * until(entity, something == true, callback);
     * ```
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
     * Assert the expression evaluates to `true`.
     * This check is only done in `debug` builds and doesn't affect `release` builds.
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
