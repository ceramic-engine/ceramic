package ceramic;

import haxe.rtti.Meta;
import ceramic.Assert.*;
import ceramic.Shortcuts.*;

using StringTools;

/**
 * Utility to track a tree of entity objects and perform specific actions when some entities get untracked
 */
class TrackEntities extends Entity implements Component {

/// Properties

    var entity:Entity;

    public var entityMap(default,null):Map<Entity,Bool> = new Map();

/// Lifecycle

    function bindAsComponent() {

        // Perform first scan to get initial data
        scan();

    }

/// Public API

    /**
     * Compute the whole object tree to see which entities are in it.
     * It will then be possible to compare the result with a previous scan and detect new and unused entities.
     */
    public function scan():Void {

        var prevEntityMap = entityMap;
        entityMap = new Map();

        scanValue(entity);

        cleanTrackingFromPrevEntityMap(prevEntityMap);

    }

    function scanValue(value:Dynamic):Void {

        if (value == null) return;

        if (Std.isOfType(value, Entity)) {
            var entity:Entity = cast value;
            if (entity.destroyed) return;

            if (entityMap.exists(entity)) {
                return; // Already tracked
            }

            // Add entity to map
            entityMap.set(entity, true);

            var clazz = Type.getClass(value);
            var fieldsMeta = Meta.getFields(clazz);

            // TODO scan entity fields in an efficient way

            return;

        }
        else if (Std.isOfType(value, Array)) {

            var array:Array<Dynamic> = value;
            for (i in 0...array.length) {
                scanValue(array[i]);
            }

            return;

        }
        else if (Std.isOfType(value, String) || Std.isOfType(value, Int) || Std.isOfType(value, Float) || Std.isOfType(value, Bool)) {

            return;

        }
        else {

            // TODO handle maps and object literals?

        }

    }

    function cleanTrackingFromPrevEntityMap(prevEntityMap:Map<Entity,Bool>) {

        // TODO

    }

}
