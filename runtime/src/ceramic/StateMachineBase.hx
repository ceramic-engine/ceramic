package ceramic;

import tracker.Observable;

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

    var stateInstances:Map<String, State> = null;

    var currentStateInstance:State = null;

/// Lifecycle

    public function new() {

        super();

        StateMachineSystem.shared.stateMachines.push(this);

    }

    public function update(delta:Float):Void {

        // Override in subclasses

    }

    function bindAsComponent():Void {

        // Nothing to do

    }

    override function destroy():Void {

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
