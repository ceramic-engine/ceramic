package ceramic;

#if (!completion && !display && !documentation && !ceramic_no_statemachine_generic && (cpp || cs)) @:generic #end
class StateMachineImpl<T> extends StateMachineBase {

    /**
     * The current state
     */
    @observe public var state(default,set):T = StateMachineBase.NO_STATE;

    /**
     * When transitioning from one state to another,
     * this will be set to the next incoming state
     */
    public var nextState(default,null):T = StateMachineBase.NO_STATE;

    function set_state(state:T):T {
        if (stateDefined && this.state == state) return state;

        // Check that the state is not locked
        if (locked) {
            throw 'Changing state is forbidden because `locked` is `true`.';
        }

        // Assign next state value
        nextState = state;

        // Compute nextStateDefined
        nextStateDefined = computeStateDefined(nextState);

        // Exit previous state
        if (stateDefined) {
            _exitState();
            stateDefined = false;
        }

        // Update state value
        this.state = state;

        // Compute stateDefined
        stateDefined = nextStateDefined;

        // Enter new state
        if (stateDefined) {
            _enterState();
        }

        // Remove next state value
        nextState = StateMachineBase.NO_STATE;

        return state;
    }

    function computeStateDefined(state:T):Bool {

        return (state != StateMachineBase.NO_STATE);

    }

    function keyToString(key:T):String {

        var name:Dynamic = key;
        return name.toString();

    }

    public function set(key:T, stateInstance:State):Void {

        if (stateInstances == null) {
            stateInstances = new Map();
        }

        var name = keyToString(key);

        if (stateInstances.exists(name)) {
            var existing = stateInstances.get(name);
            if (existing == currentStateInstance) {
                currentStateInstance = null;
            }
            if (existing != stateInstance) {
                existing.destroy();
            }
        }

        stateInstances.set(name, stateInstance);

        if (stateInstance != null) {
            stateInstance.machine = cast this;

            if (key == state) {
                // We changed state instance for the current state,
                // so we need to update `currentStateInstance` accordingly
                if (currentStateInstance == null) {
                    currentStateInstance = stateInstance;
                    currentStateInstance.enter();
                }
            }
        }

    }

    public function get(key:T):State {

        if (stateInstances == null) {
            return null;
        }

        var name = keyToString(key);

        return stateInstances.get(name);

    }

    override function update(delta:Float):Void {

        _updateState(delta);

    }

    function _enterState():Void {

        // Enter new state object (if any)
        currentStateInstance = get(state);
        if (currentStateInstance != null) {
            currentStateInstance.enter();
        }

    }

    function _updateState(delta:Float):Void {

        if (paused || !stateDefined) return;

        if (currentStateInstance != null) {
            currentStateInstance.update(delta);
        }

    }

    function _exitState():Void {

        // Exit previous state object (if any)
        if (currentStateInstance != null) {
            currentStateInstance.exit();
            currentStateInstance = null;
        }

    }

}
