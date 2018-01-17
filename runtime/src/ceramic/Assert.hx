package ceramic;

import haxe.macro.Context;
import haxe.macro.Expr;

class Assert {

    macro public static function assert(expr:Expr, ?reason:ExprOf<String>) {

#if debug
        var str = haxe.macro.ExprTools.toString(expr);

        reason = switch(reason) {
            case macro null: macro '';
            case _: macro ' ( ' + $reason + ' )';
        }

        return macro @:pos(Context.currentPos()) {
            if (!$expr) throw '$str' + $reason;
        }
#else
        return macro null;
#end

    } //assert

} //Assert
