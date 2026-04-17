package ceramic.macros;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;

class InfiniteLoop {

    public static function build():Array<Field> {

        final fields = Context.getBuildFields();

        #if !(display || completion)

        // Loop through all fields
        for (field in fields) {
            switch field.kind {
                case FVar(t, e):
                    if (e != null) {
                        field.kind = FVar(t, processWhileLoops(e));
                    }
                case FProp(get, set, t, e):
                    if (e != null) {
                        field.kind = FProp(get, set, t, processWhileLoops(e));
                    }
                case FFun(f):
                    if (f.expr != null) {
                        f.expr = processWhileLoops(f.expr);
                    }
            }
        }

        #end

        return fields;

    }

    static function processWhileLoops(e:Expr):Expr {

        return switch e.expr {

            case EWhile(cond, body, normalWhile):
                // Transform while loops by adding infinite loop detection
                var loopCounter = macro var __loopCounter = 0;
                var posStr = ""+e.pos;
                var checkCounter = macro {
                    __loopCounter++;
                    if (__loopCounter > 1000000) {
                        throw 'Infinite loop ' + $v{posStr};
                    }
                };
                // Prepend the counter check to the loop body
                var newBody = macro {
                    $checkCounter;
                    ${processWhileLoops(body)};
                };

                // Create a block with loop counter initialization and the transformed while loop
                {
                    expr: EBlock([
                        loopCounter,
                        {
                            expr: EWhile(cond, newBody, normalWhile),
                            pos: e.pos
                        }
                    ]),
                    pos: e.pos
                };

            case _:
                ExprTools.map(e, e -> {
                    try {
                        return processWhileLoops(e);
                    }
                    catch (err:Any) {
                        // Why is this happening when using haxe completion server?
                        trace('Exception of type: ' + Type.getClass(err));
                        if (Std.string(err) != 'Stack overflow') {
                            throw err;
                        }
                    }
                    return e;
                });
        }

    }

}

#end
