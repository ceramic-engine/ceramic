package ceramic;

@:autoBuild(ceramic.macros.StateMachineMacro.buildFields())
class StateMachineImpl<T> extends Entity implements Observable implements Component {

    /** The current state */
    @observe public var state(default,set):T = null;

    /** When transitioning from one state to another,
        this will be set to the next incoming state */
    public var nextState(default,null):T = null;

    /** When set to `true`, the state machine will stop calling `update()` on current state and related. */
    public var paused:Bool = false;

    var stateInstances:Map<String, State> = null;

    var currentStateInstance:State = null;

    function set_state(state:T):T {
        if (this.state == state) return state;

        // Assign next state value
        nextState = state;

        // Exit previous state
        if (this.state != null) {
            _exitState();
        }

        // Update state value
        this.state = state;

        // Enter new state
        if (this.state != null) {
            _enterState();
        }

        // Remove next state value
        nextState = null;

        return state;
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
            stateInstance.machine = this;

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

    /// Lifecycle

    public function new() {

        super();

        ceramic.App.app.onUpdate(this, _updateState);

    }

    function _enterState():Void {

        // Enter new state object (if any)
        currentStateInstance = get(state);
        if (currentStateInstance != null) {
            currentStateInstance.enter();
        }
        
    }

    function _updateState(delta:Float):Void {

        if (paused || state == null) return;

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
