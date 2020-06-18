package ceramic;

import haxe.ds.ReadOnlyArray;
import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * A group of entities, which is itself an entity.
 */
class Group<T:Entity> extends Entity #if ceramic_arcade_physics implements arcade.Collidable #end {

#if ceramic_arcade_physics

    /**
     * The order items are sorted before using the group to overlap or collide with over collidables.
     * Only relevant on groups of visuals, when using arcade physics.
     */
    public var sortDirection:arcade.SortDirection;

#end

    public var items:ReadOnlyArray<T> = [];

    public function new(?id:String) {

        super();

        if (id != null) {
            this.id = id;
        }

        ceramic.App.app.groups.push(cast this);

    }

    public function add(item:T):Void {

        var items:Array<T> = cast this.items;

        var index = items.indexOf(item);
        if (index != -1) {
            log.warning('Cannot add item $item to group, already inside group');
        }
        else {
            items.push(item);
            item.onDestroy(this, itemDestroyed);
        }

    }

    public function remove(item:T):Void {

        var items:Array<T> = cast this.items;

        var index = items.indexOf(item);
        if (index != -1) {
            items.splice(index, 1);
            item.offDestroy(itemDestroyed);
        }
        else {
            log.warning('Cannot remove item $item from group, index is -1');
        }

    }

    inline public function contains(item:T):Bool {

        return items.indexOf(item) != -1;

    }

    function itemDestroyed(item:Entity) {

        remove(cast item);

    }

    public function clear() {

        var items:Array<T> = cast this.items;

        if (items.length > 0) {
            var len = items.length;
            var pool = ArrayPool.pool(len);
            var tmp = pool.get();
            for (i in 0...len) {
                tmp.set(i, items.unsafeGet(i));
            }
            for (i in 0...len) {
                var item:T = tmp.get(i);
                item.offDestroy(itemDestroyed);
                item.destroy();
            }
            items.setArrayLength(0);
            pool.release(tmp);
        }

    }

    override function destroy() {

        super.destroy();

        ceramic.App.app.groups.remove(cast this);

        clear();

    }

}
