package ceramic;

/**
 * Base class for states in a state machine.
 * 
 * State represents a single state within a StateMachine. Each state has
 * lifecycle methods that are called when entering, updating, and exiting
 * the state. States can access their parent state machine to trigger
 * transitions or access shared data.
 * 
 * To create a state:
 * 1. Extend this class
 * 2. Override enter(), update(), and/or exit() methods
 * 3. Add the state to a StateMachine
 * 
 * Example usage:
 * ```haxe
 * class IdleState extends State {
 *     override function enter() {
 *         trace("Entering idle state");
 *     }
 *     
 *     override function update(delta:Float) {
 *         if (playerInput.isMoving) {
 *             machine.state = "walking";
 *         }
 *     }
 * }
 * ```
 * 
 * @see StateMachine
 * @see StateMachineBase
 */
@:allow(ceramic.StateMachineImpl)
class State extends Entity {

    /**
     * The state machine that owns this state.
     * Set automatically when the state is added to a machine.
     */
    public var machine(default,null):StateMachine<Any> = null;

    public function new() {

        super();

    }

    /**
     * Called when entering this state.
     * Override this method to perform initialization when the state becomes active.
     */
    public function enter():Void {

        //

    }

    /**
     * Called every frame while this state is active.
     * Override this method to implement state behavior and transitions.
     * @param delta Time elapsed since last update in seconds
     */
    public function update(delta:Float):Void {

        //

    }

    /**
     * Called when exiting this state.
     * Override this method to perform cleanup when transitioning to another state.
     */
    public function exit():Void {

        //

    }

}
