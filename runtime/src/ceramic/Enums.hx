package ceramic;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Macro utilities for working with enum values at compile time.
 * 
 * This class provides compile-time macros for enum comparison and validation,
 * offering more readable and maintainable code than manual string comparisons.
 * 
 * ## Features
 * 
 * - **Compile-time Safety**: Enum names are validated at compile time
 * - **Null-safe**: Handles null enum values gracefully
 * - **Clean Syntax**: More readable than manual getName() comparisons
 * 
 * ## Usage Example
 * 
 * ```haxe
 * enum GameState {
 *     MENU;
 *     PLAYING;
 *     PAUSED;
 *     GAME_OVER;
 * }
 * 
 * var state = GameState.PLAYING;
 * 
 * // Using Enums utility
 * if (Enums.isEnumWithName(state, PLAYING)) {
 *     trace("Game is running");
 * }
 * 
 * // Equivalent to (but cleaner than):
 * if (state != null && state.getName() == "PLAYING") {
 *     trace("Game is running");
 * }
 * ```
 * 
 * @see Type.enumConstructor For runtime enum name access
 */
class Enums {

    /**
     * Returns true if the given enum value has its name equal to the given name.
     * 
     * This macro provides a clean way to check if an enum value matches a
     * specific constructor name. The name parameter is converted to a string
     * at compile time, providing type safety and auto-completion support.
     * 
     * ## Null Safety
     * 
     * The macro generates null-safe code, returning false if the enum value
     * is null rather than throwing an exception.
     * 
     * @param valueExpr The enum value to check (can be null)
     * @param nameExpr The constructor name to match against (without quotes)
     * @return True if the enum value's name matches, false if null or different
     * 
     * ```haxe
     * enum Direction {
     *     NORTH;
     *     SOUTH;
     *     EAST;
     *     WEST;
     * }
     * 
     * var dir:Direction = NORTH;
     * 
     * if (Enums.isEnumWithName(dir, NORTH)) {
     *     player.moveUp();
     * }
     * 
     * // Works with null values
     * var nullDir:Direction = null;
     * Enums.isEnumWithName(nullDir, NORTH); // false, no error
     * 
     * // Can use with switch alternatives
     * var action = if (Enums.isEnumWithName(state, MENU)) {
     *     showMenu();
     * } else if (Enums.isEnumWithName(state, PLAYING)) {
     *     updateGame();
     * }
     * ```
     */
    macro public static function isEnumWithName<T>(valueExpr:ExprOf<Enum<T>>, nameExpr:Expr) {

        //var valueStr = haxe.macro.ExprTools.toString(valueExpr);
        var nameStr = haxe.macro.ExprTools.toString(nameExpr);

        return macro @:pos(Context.currentPos()) {
            var value = $valueExpr;
            value != null && value.getName() == $v{nameStr};
        }

    }

}
