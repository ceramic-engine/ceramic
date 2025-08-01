package ceramic;

using ceramic.Extensions;

/**
 * System that manages and updates all active state machines.
 * 
 * StateMachineSystem is responsible for automatically updating all state machines
 * that have autoUpdate enabled. It runs during the late update phase to ensure
 * state machines are updated after regular entity updates.
 * 
 * Features:
 * - Automatic registration of state machines
 * - Safe iteration during updates (handles additions/removals)
 * - Configurable update order via lateUpdateOrder
 * - Singleton pattern with shared instance
 * 
 * This system is automatically used by all StateMachine instances and typically
 * doesn't need to be interacted with directly.
 * 
 * @see StateMachine
 * @see StateMachineBase
 * @see System
 */
@:allow(ceramic.StateMachineBase)
class StateMachineSystem extends System {

    /**
     * Shared state machine system
     */
    @lazy public static var shared = new StateMachineSystem();

    var stateMachines:Array<StateMachineBase> = [];

    var _updatingStateMachines:Array<StateMachineBase> = [];

    override function new() {

        super();

        lateUpdateOrder = 1000;

    }

    override function lateUpdate(delta:Float):Void {

        // Work on a copy of list, to ensure nothing bad happens
        // if a new item is created or destroyed during iteration
        var len = stateMachines.length;
        for (i in 0...len) {
            _updatingStateMachines[i] = stateMachines.unsafeGet(i);
        }

        // Call
        for (i in 0...len) {
            var machine = _updatingStateMachines.unsafeGet(i);
            if (machine.autoUpdate) {
                machine.update(delta);
            }
        }

        // Cleanup array
        for (i in 0...len) {
            _updatingStateMachines.unsafeSet(i, null);
        }

    }

}
