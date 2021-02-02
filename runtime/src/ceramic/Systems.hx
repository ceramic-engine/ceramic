package ceramic;

import ceramic.ReadOnlyArray;
import ceramic.System;
import haxe.ds.ArraySort;

using ceramic.Extensions;

@:allow(ceramic.App)
class Systems extends Entity {

    /**
     * If `true`, `preUpdateOrdered` list needs to be sorted
     */
    var preUpdateOrderDirty:Bool = false;

    /**
     * If `true`, `postUpdateOrdered` list needs to be sorted
     */
    var postUpdateOrderDirty:Bool = false;

    /**
     * List of systems, ordered ascending according to their `preUpdateOrder` property
     */
    var preUpdateOrdered:ReadOnlyArray<System> = [];

    /**
     * List of systems, ordered ascending according to their `postUpdateOrder` property
     */
    var postUpdateOrdered:ReadOnlyArray<System> = [];

    /**
     * Internal pre-allocated array used for iteration
     */
    var _udpatingSystems:Array<System> = [];

    private function new() {

        super();

    }

    function addSystem(system:System):Void {

        preUpdateOrdered.original.push(system);
        preUpdateOrderDirty = true;

        postUpdateOrdered.original.push(system);
        postUpdateOrderDirty = true;

    }

    function removeSystem(system:System):Void {

        preUpdateOrdered.original.remove(system);
        preUpdateOrderDirty = true;

        postUpdateOrdered.original.remove(system);
        postUpdateOrderDirty = true;

    }

    function preUpdate(delta:Float):Void {

        // Sort if needed
        if (preUpdateOrderDirty) {
            ArraySort.sort(preUpdateOrdered.original, sortSystemsByPreUpdateOrder);
            preUpdateOrderDirty = false;
        }

        // Work on a copy of systems list, to ensure nothing bad happens
        // if a new system is created or destroyed during iteration
        var len = preUpdateOrdered.length;
        for (i in 0...len) {
            _udpatingSystems[i] = preUpdateOrdered.unsafeGet(i);
        }

        // Call
        for (i in 0...len) {
            var system = _udpatingSystems.unsafeGet(i);
            system.preUpdate(delta);

            // Flush immediate
            ceramic.App.app.flushImmediate();
        }

        // Cleanup array
        for (i in 0...len) {
            _udpatingSystems.unsafeSet(i, null);
        }
        
    }

    function postUpdate(delta:Float):Void {

        // Sort if needed
        if (postUpdateOrderDirty) {
            ArraySort.sort(postUpdateOrdered.original, sortSystemsByPostUpdateOrder);
            postUpdateOrderDirty = false;
        }

        // Work on a copy of systems list, to ensure nothing bad happens
        // if a new system is created or destroyed during iteration
        var len = postUpdateOrdered.length;
        for (i in 0...len) {
            _udpatingSystems[i] = postUpdateOrdered.unsafeGet(i);
        }

        // Call
        for (i in 0...len) {
            var system = _udpatingSystems.unsafeGet(i);
            system.postUpdate(delta);

            // Flush immediate
            ceramic.App.app.flushImmediate();
        }

        // Cleanup array
        for (i in 0...len) {
            _udpatingSystems.unsafeSet(i, null);
        }
        
    }

/// Helpers

    public function get(name:String):System {

        for (i in 0...preUpdateOrdered.length) {
            var system = preUpdateOrdered.unsafeGet(i);
            if (system.name == name) {
                return system;
            }
        }

        return null;

    }

/// Sorting

    static function sortSystemsByPreUpdateOrder(a:System, b:System):Int {

        if (a.preUpdateOrder > b.preUpdateOrder)
            return 1;
        else if (a.preUpdateOrder < b.preUpdateOrder)
            return -1;
        else
            return 0;

    }

    static function sortSystemsByPostUpdateOrder(a:System, b:System):Int {

        if (a.postUpdateOrder > b.postUpdateOrder)
            return 1;
        else if (a.postUpdateOrder < b.postUpdateOrder)
            return -1;
        else
            return 0;

    }

}
