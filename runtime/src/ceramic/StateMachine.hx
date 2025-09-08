package ceramic;

/**
 * A flexible state machine implementation for managing state transitions.
 * 
 * StateMachine provides a powerful way to manage complex state logic in your
 * application. It supports string-based or enum-based state identification,
 * automatic state lifecycle management, and type-safe state access.
 * 
 * Features:
 * - Type-safe state management using enums or strings
 * - Automatic enter/exit/update lifecycle calls
 * - State transition events
 * - Integration with Ceramic's entity system
 * - Support for pausing/resuming state updates
 * 
 * Example with enum states:
 * ```haxe
 * enum PlayerState {
 *     IDLE;
 *     WALKING;
 *     JUMPING;
 * }
 * 
 * var machine = new StateMachine<PlayerState>();
 * machine.set(IDLE, new IdleState());
 * machine.set(WALKING, new WalkingState());
 * machine.set(JUMPING, new JumpingState());
 * 
 * machine.state = IDLE; // Start in idle state
 * ```
 * 
 * Example with string states:
 * ```haxe
 * var machine = new StateMachine<String>();
 * machine.set("menu", new MenuState());
 * machine.set("game", new GameState());
 * machine.set("pause", new PauseState());
 * 
 * machine.state = "menu";
 * ```
 * 
 * @see State
 * @see StateMachineBase
 */
#if (completion || display || documentation)

// We avoid relying on generic build stuff when simply doing code completion
// because haxe compiler doesn't seem to like it

class StateMachine<T> extends StateMachineImpl<T> {

}

#else

/**
 * Generic state machine implementation for managing state transitions.
 * 
 * StateMachine provides a clean way to manage complex state logic with
 * support for enter/exit callbacks and state change events. The generic
 * type parameter T represents the state type (typically an enum).
 * 
 * @param T The type representing states (typically an enum)
 * @see StateMachineImpl
 * @see State
 */
#if !macro
@:genericBuild(ceramic.macros.StateMachineMacro.buildGeneric())
#end
class StateMachine<T> {

    // Implementation is in StateMachineImpl (bound by genericBuild macro)

}

#end
