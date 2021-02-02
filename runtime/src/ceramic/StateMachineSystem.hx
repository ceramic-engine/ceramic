package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

@:allow(ceramic.StateMachineImpl)
class StateMachineSystem extends System {

    var stateMachines:Array<StateMachine<Any>> = [];

    var _updatingStateMachines:Array<StateMachine<Any>> = [];

    override function new() {

        super();

        preUpdateOrder = 2000;

    }

    override function preUpdate(delta:Float):Void {

        // Work on a copy of list, to ensure nothing bad happens
        // if a new item is created or destroyed during iteration
        var len = stateMachines.length;
        for (i in 0...len) {
            _updatingStateMachines[i] = stateMachines.unsafeGet(i);
        }

        // Call
        for (i in 0...len) {
            var machine = _updatingStateMachines.unsafeGet(i);
            machine._updateState(delta);
        }

        // Cleanup array
        for (i in 0...len) {
            _updatingStateMachines.unsafeSet(i, null);
        }

    }

}
