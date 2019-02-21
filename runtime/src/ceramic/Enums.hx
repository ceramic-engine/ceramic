package ceramic;

import haxe.macro.Context;
import haxe.macro.Expr;

class Enums {

    /** Returns true if the given enum value has its name equal to the given name */
    macro public static function isEnumWithName<T>(valueExpr:ExprOf<Enum<T>>, nameExpr:Expr) {

        //var valueStr = haxe.macro.ExprTools.toString(valueExpr);
        var nameStr = haxe.macro.ExprTools.toString(nameExpr);

        return macro @:pos(Context.currentPos()) {
            var value = $valueExpr;
            value != null && value.getName() == $v{nameStr};
        }

    } //assert

} //Enums
