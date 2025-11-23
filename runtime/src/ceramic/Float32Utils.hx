package ceramic;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;
#end

class Float32Utils {

    #if !macro

    public inline static function min32(a:Float32, b:Float32):Float32 {
        return (a < b) ? a : b;
    }

    public inline static function max32(a:Float32, b:Float32):Float32 {
        return (a > b) ? a : b;
    }

    public inline static function floor32(a:Float32):Int {
        #if cpp
        return Math.floor(a); // TODO
        #else
        return Math.floor(a);
        #end
    }

    public inline static function ceil32(a:Float32):Int {
        #if cpp
        return Math.ceil(a); // TODO
        #else
        return Math.ceil(a);
        #end
    }

    public inline static function round32(a:Float32):Int {
        #if cpp
        return Math.round(a); // TODO
        #else
        return Math.round(a);
        #end
    }

    public inline static function abs32(a:Float32):Float32 {
        #if cpp
        return untyped __cpp__('({0} < 0.0f ? -{1} : {2})', a, a, a);
        #else
        return Math.abs(a);
        #end
    }

    /**
     * Linear interpolation between two values.
     *
     * @param a Start value (returned when t=0)
     * @param b End value (returned when t=1)
     * @param t Interpolation factor (0 to 1)
     * @return The interpolated value
     */
    public inline static function lerp32(a:Float32, b:Float32, t:Float32):Float32 {
        return a + (b - a) * t;
    }

    #end

    macro public static function f32(expr:Expr):ExprOf<Float32> {
        if (Context.defined('cpp')) {
            var exprStr = new Printer().printExpr(expr);
            if (exprStr.indexOf('.') == -1) {
                exprStr += '.0';
            }
            return Context.parse("(untyped __cpp__('" + exprStr + "f'):ceramic.Float32)", Context.currentPos());
        }
        else {
            return expr;
        }
    }

}
