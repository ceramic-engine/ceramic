package ceramic;

import tracker.Observable;

/**
 * Base class for state machine implementations.
 * 
 * StateMachineBase provides the core functionality for state machines in Ceramic.
 * It manages state lifecycle, transitions, and integration with the entity system.
 * This class is typically not used directly - use StateMachine<T> instead.
 * 
 * Features:
 * - Automatic state updates via StateMachineSystem
 * - Pausable state execution
 * - State locking to prevent transitions
 * - Component interface for entity attachment
 * - Observable pattern for state change events
 * 
 * The state machine automatically calls:
 * - exit() on the previous state
 * - enter() on the new state
 * - update(delta) on the active state each frame
 * 
 * @see StateMachine
 * @see State
 * @see StateMachineSystem
 */
class StateMachineBase extends Entity implements Observable implements Component {

    /**
     * A way to assign null state to generic classes and let final target do what is best as a cast
     */
    static final NO_STATE:Dynamic = null;

    @:noCompletion @entity var rawEntity:ceramic.Entity;

    /**
     * When set to `true`, the state machine will stop calling `update()` on current state and related.
     */
    public var paused:Bool = false;

    /**
     * When set to `true` (default). This state machine will be updated automatically.
     * If `false`, you'll need to call `update()` manually.
     */
    public var autoUpdate:Bool = true;

    /**
     * Is `true` if a state has been assigned, `false` otherwise.
     */
    public var stateDefined(default,null):Bool = false;

    /**
     * Is `true` if a nextState has been assigned, `false` otherwise.
     */
    public var nextStateDefined(default,null):Bool = false;

    /**
     * If set to `true`, changing state will be forbidden and trigger an error.
     */
    public var locked:Bool = false;

    var stateInstances:Map<String, State> = null;

    var currentStateInstance:State = null;

/// Lifecycle

    public function new() {

        super();

        StateMachineSystem.shared.stateMachines.push(this);

    }

    /**
     * Updates the current state.
     * Called automatically each frame if autoUpdate is true and not paused.
     * @param delta Time elapsed since last update in seconds
     */
    public function update(delta:Float):Void {

        // Override in subclasses

    }

    function bindAsComponent():Void {

        // Nothing to do

    }

    override function destroy():Void {

        StateMachineSystem.shared.stateMachines.remove(this);

        if (stateInstances != null) {
            var _stateInstances = stateInstances;
            stateInstances = null;
            for (state in _stateInstances) {
                if (state != null) {
                    state.destroy();
                }
            }
        }

        super.destroy();

    }

}
