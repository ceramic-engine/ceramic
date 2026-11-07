// New code for the Haxe port of GPUI (no GPUI origin): the entities accessed
// by a view or a window while it draws. See NOTICE.md.
package glaze;

import haxe.ds.IntMap;

/**
 * A set of entity ids in insertion order, cheap to iterate and to clear
 * (the port's counterpart of the `FxHashSet<EntityId>` of accessed entities
 * GPUI keeps per cached view and per window, see
 * `Window.recordEntitiesAccessed`).
 */
class AccessedEntities {

    final seen:IntMap<Bool> = new IntMap();

    /** The ids, each once, in the order they were added. */
    public final ids:Array<Int> = [];

    public function new() {}

    public inline function add(entityId:Int):Void {
        if (!seen.exists(entityId)) {
            seen.set(entityId, true);
            ids.push(entityId);
        }
    }

    public inline function contains(entityId:Int):Bool {
        return seen.exists(entityId);
    }

    public function clear():Void {
        if (ids.length > 0) {
            seen.clear();
            ids.resize(0);
        }
    }

}
