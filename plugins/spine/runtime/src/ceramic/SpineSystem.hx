package ceramic;

using ceramic.Extensions;

@:allow(ceramic.Spine)
class SpineSystem extends System {

    /**
     * Shared spine system
     */
    @lazy static var shared = new SpineSystem();

    var spines:Array<Spine> = [];

    var _updatingSpines:Array<Spine> = [];

    override function new() {

        super();

        lateUpdateOrder = 3000;

    }

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
