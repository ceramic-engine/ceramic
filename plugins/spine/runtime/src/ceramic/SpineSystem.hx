package ceramic;

using ceramic.Extensions;

/**
 * System responsible for updating all active Spine instances in the application.
 * 
 * SpineSystem is automatically created as a singleton and manages the update
 * lifecycle of all Spine animations. It runs during the late update phase
 * to ensure animations are updated after game logic but before rendering.
 * 
 * The system maintains a list of all Spine instances and updates them each
 * frame based on their autoUpdate and paused/frozen states. This centralized
 * update approach ensures consistent animation timing and efficient batch
 * processing.
 * 
 * Features:
 * - Automatic registration/unregistration of Spine instances
 * - Safe iteration that handles additions/removals during updates
 * - Respects pause/freeze states and autoUpdate flags
 * - Runs at lateUpdateOrder 4000 for proper timing
 * 
 * This system is used internally by the Spine class and typically doesn't
 * need to be accessed directly by user code.
 */
@:allow(ceramic.Spine)
class SpineSystem extends System {

    /**
     * The shared singleton instance of the SpineSystem.
     * 
     * This instance is automatically created on first access and manages
     * all Spine instances in the application. The @lazy metadata ensures
     * it's only created when needed.
     */
    @lazy public static var shared = new SpineSystem();

    /**
     * Master list of all Spine instances registered with the system.
     * Spine instances are automatically added/removed when created/destroyed.
     */
    var spines:Array<Spine> = [];

    /**
     * Temporary array used during update iteration.
     * This allows safe modification of the main spines array during updates
     * without affecting the current iteration.
     */
    var _updatingSpines:Array<Spine> = [];

    /**
     * Creates a new SpineSystem instance.
     * 
     * Sets the lateUpdateOrder to 4000, ensuring Spine animations are
     * updated after most game logic but before rendering begins.
     */
    override function new() {

        super();

        lateUpdateOrder = 4000;

    }

    /**
     * Updates all active Spine animations with the given time delta.
     * 
     * This method is called automatically each frame during the late update phase.
     * It iterates through all registered Spine instances and updates those that:
     * - Are not paused or frozen
     * - Have autoUpdate enabled
     * 
     * The update process uses a temporary array to ensure safe iteration even
     * if Spine instances are added or removed during the update cycle.
     * 
     * @param delta Time elapsed since the last frame in seconds
     */
    override function lateUpdate(delta:Float):Void {

        // Work on a copy of list, to ensure nothing bad happens
        // if a new item is created or destroyed during iteration
        var len = spines.length;
        for (i in 0...len) {
            _updatingSpines[i] = spines.unsafeGet(i);
        }

        // Call
        for (i in 0...len) {
            var spine = _updatingSpines.unsafeGet(i);
            if (!spine.pausedOrFrozen && spine.autoUpdate) {
                spine.update(delta);
            }
        }

        // Cleanup array
        for (i in 0...len) {
            _updatingSpines.unsafeSet(i, null);
        }

    }

}
