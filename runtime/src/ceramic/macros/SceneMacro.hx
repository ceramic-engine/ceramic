package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;

class SceneMacro {

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
     * Replace `super.fadeIn();`
     * with `super._fadeIn();`
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
     * Replace `super.fadeOut();`
     * with `super._fadeOut();`
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