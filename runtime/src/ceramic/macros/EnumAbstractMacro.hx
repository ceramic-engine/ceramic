package ceramic.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.Tools;
#end

/**
 * Utility macros for working with enum abstracts at compile time.
 * Enum abstracts are Haxe's way of creating type-safe enumerations with
 * custom underlying types. This macro provides tools to:
 * - Get all values of an enum abstract as an array
 * - Convert enum abstract values to/from strings
 * 
 * These utilities are particularly useful for serialization, UI generation,
 * and validation where you need to work with all possible enum values.
 * 
 * Example usage:
 * ```haxe
 * var allStates = EnumAbstractMacro.getValues(MyState);
 * var stateStr = EnumAbstractMacro.toStringSwitch(MyState, currentState);
 * var state = EnumAbstractMacro.fromStringSwitch(MyState, "IDLE");
 * ```
 */
class EnumAbstractMacro {

    /**
     * Returns an array containing all values of an enum abstract.
     * This macro examines the enum abstract at compile time and generates
     * code that creates an array of all its values.
     * 
     * Example:
     * ```haxe
     * @:enum abstract Color(Int) {
     *     var RED = 0xFF0000;
     *     var GREEN = 0x00FF00;
     *     var BLUE = 0x0000FF;
     * }
     * 
     * var colors = EnumAbstractMacro.getValues(Color); // [RED, GREEN, BLUE]
     * ```
     * 
     * @param typePath Expression representing the enum abstract type
     * @return Expression that evaluates to an array of all enum values
     */
    public static macro function getValues(typePath:Expr):Expr {

        // From: https://code.haxe.org/category/macros/enum-abstract-values.html

        // Get the type from a given expression converted to string.
        // This will work for identifiers and field access which is what we need,
        // it will also consider local imports. If expression is not a valid type path or type is not found,
        // compiler will give a error here.
        var type = Context.getType(typePath.toString());

        // Switch on the type and check if it's an abstract with @:enum metadata
        switch (type.follow()) {
            case TAbstract(_.get() => ab, _) if (ab.meta.has(":enum")):
                // enum abstract values are actually static fields of the abstract implementation class,
                // marked with @:enum and @:impl metadata. We generate an array of expressions that access those fields.
                // Note that this is a bit of implementation detail, so it can change in future Haxe versions, but it's been
                // stable so far.
                var valueExprs = [];
                for (field in ab.impl.get().statics.get()) {
                    if (field.meta.has(":enum") && field.meta.has(":impl")) {
                        var fieldName = field.name;
                        valueExprs.push(macro $typePath.$fieldName);
                    }
                }
                // Return collected expressions as an array declaration.
                return macro $a{valueExprs};
            default:
                // The given type is not an abstract, or doesn't have @:enum metadata, show a nice error message.
                throw new Error(type.toString() + " should be enum abstract", typePath.pos);
        }
    }

    /**
     * Generates a switch expression that converts an enum abstract value to its string name.
     * Creates an exhaustive switch that maps each enum value to its identifier as a string.
     * 
     * Example:
     * ```haxe
     * var state = PLAYING;
     * var name = EnumAbstractMacro.toStringSwitch(GameState, state); // "PLAYING"
     * ```
     * 
     * This is useful for serialization, debugging, and displaying enum values in UIs.
     * 
     * @param typePath Expression representing the enum abstract type
     * @param e Expression of the enum value to convert
     * @return Switch expression that evaluates to the string name
     */
    public static macro function toStringSwitch(typePath:Expr, e:Expr):Expr {

        var type = Context.getType(typePath.toString());

        switch (type.follow()) {
            case TAbstract(_.get() => ab, _) if (ab.meta.has(":enum")):

                var cases:Array<Case> = [];
                for (field in ab.impl.get().statics.get()) {
                    if (field.meta.has(":enum") && field.meta.has(":impl")) {
                        var fieldName = field.name;
                        cases.push({
                            values: [macro $typePath.$fieldName],
                            expr: macro $v{fieldName}
                        });
                    }
                }

                return { pos: e.pos, expr: ESwitch(e, cases, null) };

            default:
                // The given type is not an abstract, or doesn't have @:enum metadata, show a nice error message.
                throw new Error(type.toString() + " should be enum abstract", typePath.pos);
        }
    }

    /**
     * Generates a switch expression that converts a string to an enum abstract value.
     * Creates an exhaustive switch that maps string names to their corresponding enum values.
     * Throws an exception if the string doesn't match any enum value.
     * 
     * Example:
     * ```haxe
     * var state = EnumAbstractMacro.fromStringSwitch(GameState, "PLAYING"); // GameState.PLAYING
     * // Throws: Cannot convert "INVALID" to GameState
     * ```
     * 
     * This is the inverse of toStringSwitch and is useful for deserialization
     * and parsing user input.
     * 
     * @param typePath Expression representing the enum abstract type
     * @param e Expression of the string to convert
     * @return Block expression that evaluates to the enum value or throws
     */
    public static macro function fromStringSwitch(typePath:Expr, e:Expr):Expr {

        var type = Context.getType(typePath.toString());

        switch (type.follow()) {
            case TAbstract(_.get() => ab, _) if (ab.meta.has(":enum")):

                var first:Expr = null;
                var cases:Array<Case> = [];
                for (field in ab.impl.get().statics.get()) {
                    if (field.meta.has(":enum") && field.meta.has(":impl")) {
                        var fieldName = field.name;
                        cases.push({
                            values: [macro $v{fieldName}],
                            expr: macro $typePath.$fieldName
                        });

                        if (first == null) {
                            first = macro {
                                throw "Cannot convert \"" + str_ + "\" to " + $v{ab.name};
                                $typePath.$fieldName;
                            }
                        }
                    }
                }

                var strAssign = macro var str_ = $e;
                var strRef = macro str_;

                return { pos: e.pos, expr: EBlock([
                    strAssign,
                    { pos: e.pos, expr: ESwitch(strRef, cases, first) }
                ])};

            default:
                // The given type is not an abstract, or doesn't have @:enum metadata, show a nice error message.
                throw new Error(type.toString() + " should be enum abstract", typePath.pos);
        }
    }

}
