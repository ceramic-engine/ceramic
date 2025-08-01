package ceramic;

// Current implementation is functionnaly correct,
// but it will be better to use genericBuild to avoid using
// too much dynamic access and make it efficient.
// (just like what we did for StateMachine)

//#if (completion || display || documentation)

// We avoid relying on generic build stuff when simply doing code completion
// because haxe compiler doesn't seem to like it

/**
 * A flexible input mapping system that allows binding physical inputs to logical actions.
 * 
 * InputMap provides a unified interface for mapping various input types (keyboard keys,
 * gamepad buttons, mouse buttons, and analog axes) to game-specific actions defined
 * by the type parameter T (typically an enum).
 * 
 * Features:
 * - Bind multiple physical inputs to a single action
 * - Support for keyboard (key codes and scan codes), mouse, and gamepad inputs
 * - Convert digital inputs to analog axis values
 * - Convert analog inputs to digital button presses
 * - Track input states: pressed, just pressed, just released
 * - Handle analog axis values for smooth input
 * 
 * @param T The type representing your game's actions (typically an enum)
 * 
 * Example usage:
 * ```haxe
 * enum Action {
 *     JUMP;
 *     MOVE_LEFT;
 *     MOVE_RIGHT;
 *     SHOOT;
 *     MOVE_X; // For analog movement
 * }
 * 
 * var inputMap = new InputMap<Action>();
 * 
 * // Bind keyboard keys
 * inputMap.bindKeyCode(JUMP, KeyCode.SPACE);
 * inputMap.bindKeyCode(MOVE_LEFT, KeyCode.A);
 * inputMap.bindKeyCode(MOVE_RIGHT, KeyCode.D);
 * 
 * // Bind gamepad
 * inputMap.bindGamepadButton(JUMP, GamepadButton.A);
 * inputMap.bindGamepadAxis(MOVE_X, GamepadAxis.LEFT_X);
 * 
 * // Convert digital to analog
 * inputMap.bindKeyCodeToAxis(MOVE_X, KeyCode.A, -1.0);
 * inputMap.bindKeyCodeToAxis(MOVE_X, KeyCode.D, 1.0);
 * 
 * // In update loop
 * if (inputMap.justPressed(JUMP)) {
 *     player.jump();
 * }
 * var moveX = inputMap.axisValue(MOVE_X);
 * player.velocity.x = moveX * speed;
 * ```
 * 
 * @see InputMapImpl
 */
class InputMap<T> extends InputMapImpl<T> {

}

/*
#else

#if !macro
@:genericBuild(ceramic.macros.InputMapMacro.buildGeneric())
#end
class InputMap<T> {

    // Implementation is in InputMapImpl (bound by genericBuild macro)

}

#end
*/
