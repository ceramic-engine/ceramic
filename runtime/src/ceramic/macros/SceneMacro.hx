package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;

/**
 * Build macro that ensures proper scene lifecycle management for fade transitions.
 * 
 * This macro intercepts `fadeIn()` and `fadeOut()` method overrides in Scene
 * subclasses and renames them to `_fadeIn()` and `_fadeOut()`. This ensures
 * that the base Scene class's mandatory fade logic is always executed,
 * while still allowing subclasses to customize fade behavior.
 * 
 * ## Purpose
 * 
 * The Scene class has critical lifecycle code in its fadeIn() and fadeOut()
 * methods that must run regardless of subclass implementations. Rather than
 * requiring developers to remember to call super.fadeIn(), this macro
 * automatically handles the method interception.
 * 
 * ## How It Works
 * 
 * 1. Detects fadeIn/fadeOut overrides in Scene subclasses
 * 2. Renames them to _fadeIn/_fadeOut
 * 3. Transforms super.fadeIn() calls to super._fadeIn()
 * 4. The base Scene class calls these renamed methods at the appropriate time
 * 
 * ## Example
 * 
 * ```haxe
 * @:build(ceramic.macros.SceneMacro.build())
 * class MyScene extends Scene {
 *     // This gets renamed to _fadeIn() by the macro
 *     override function fadeIn(callback:Void->Void) {
 *         // Custom fade in logic
 *         super.fadeIn(callback); // Transformed to super._fadeIn(callback)
 *     }
 * }
 * ```
 * 
 * @see ceramic.Scene For the base scene implementation
 */
class SceneMacro {

    /**
     * Build macro entry point that processes scene fade method overrides.
     * 
     * Examines all fields in the class and renames fadeIn/fadeOut overrides
     * to ensure proper lifecycle management. Also transforms any super calls
     * within these methods.
     * 
     * @return Modified array of fields with renamed fade methods
     */
    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN SceneMacro.build()');
        #end

        var fields = Context.getBuildFields();

        // When we override fadeIn() and fadeOut() in scene subclasses, the macro
        // is renaming these overrides _fadeIn() and _fadeOut() on the fly to
        // ensure some mandatory code in original fadeIn() and fadeOut() is executed no matter what.
        for (field in fields) {

            if (field.name == 'fadeIn') {
                field.name = '_fadeIn';
                switch(field.kind) {
                    case FieldType.FFun(fn):
                        fn.expr = transformSuperFadeIn(fn.expr);
                    default:
                }
            }
            else if (field.name == 'fadeOut') {
                field.name = '_fadeOut';
                switch(field.kind) {
                    case FieldType.FFun(fn):
                        fn.expr = transformSuperFadeOut(fn.expr);
                    default:
                }
            }

        }

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END SceneMacro.build()');
        #end

        return fields;

    }

    /**
     * Recursively transforms super.fadeIn() calls to super._fadeIn().
     * 
     * This ensures that when a subclass calls super.fadeIn(), it correctly
     * calls the renamed _fadeIn() method in the parent class.
     * 
     * @param e The expression to transform
     * @return Transformed expression with renamed super calls
     */
    static function transformSuperFadeIn(e:Expr):Expr {

        switch (e.expr) {
            case ECall({expr: EField({expr: EConst(CIdent('super')), pos: pos1}, 'fadeIn'), pos: pos2}, params):
                return {
                    expr: ECall({expr: EField({expr: EConst(CIdent('super')), pos: pos1}, '_fadeIn'), pos: pos2}, params),
                    pos: e.pos
                };
            default:
                return ExprTools.map(e, transformSuperFadeIn);
        }

    }

    /**
     * Recursively transforms super.fadeOut() calls to super._fadeOut().
     * 
     * This ensures that when a subclass calls super.fadeOut(), it correctly
     * calls the renamed _fadeOut() method in the parent class.
     * 
     * @param e The expression to transform
     * @return Transformed expression with renamed super calls
     */
    static function transformSuperFadeOut(e:Expr):Expr {

        switch (e.expr) {
            case ECall({expr: EField({expr: EConst(CIdent('super')), pos: pos1}, 'fadeOut'), pos: pos2}, params):
                return {
                    expr: ECall({expr: EField({expr: EConst(CIdent('super')), pos: pos1}, '_fadeOut'), pos: pos2}, params),
                    pos: e.pos
                };
            default:
                return ExprTools.map(e, transformSuperFadeOut);
        }

    }

}