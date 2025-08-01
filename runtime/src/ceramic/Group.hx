package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * A container for managing collections of entities as a single unit.
 * 
 * Group provides a way to organize and manage multiple entities together, treating
 * them as a cohesive collection. The group itself is an entity, allowing it to be
 * part of the entity lifecycle and receive destroy events.
 * 
 * Key features:
 * - Automatic cleanup: When items are destroyed, they're automatically removed from the group
 * - Lifecycle management: Destroying the group destroys all contained items
 * - Type-safe: Generic type parameter ensures all items are of the same entity type
 * - Global registration: Groups are automatically registered with the app for management
 * - Arcade physics support: When the arcade plugin is enabled, groups can participate in collision detection
 * 
 * Common use cases:
 * - Managing collections of game objects (enemies, bullets, pickups)
 * - Organizing UI elements that should be treated as a unit
 * - Batch operations on multiple entities
 * - Collision detection between groups of objects (with arcade plugin)
 * 
 * Example usage:
 * ```haxe
 * // Create a group for enemies
 * var enemies = new Group<Enemy>("enemies");
 * 
 * // Add enemies to the group
 * var enemy = new Enemy();
 * enemies.add(enemy);
 * 
 * // Check if an enemy is in the group
 * if (enemies.contains(enemy)) {
 *     trace("Enemy is in group");
 * }
 * 
 * // Iterate through all enemies
 * for (enemy in enemies.items) {
 *     enemy.update(delta);
 * }
 * 
 * // Clear all enemies (destroys them)
 * enemies.clear();
 * ```
 * 
 * @param T The type of entities this group will contain (must extend Entity)
 */
class Group<T:Entity> extends Entity #if plugin_arcade implements arcade.Collidable #end {

#if plugin_arcade

    /**
     * The order items are sorted before using the group to overlap or collide with other collidables.
     * 
     * This property is only available when the arcade physics plugin is enabled and affects
     * how items within the group are ordered during collision detection. Sorting can improve
     * collision detection performance and ensure consistent behavior.
     * 
     * Only relevant on groups of visuals when using arcade physics for collision detection.
     * 
     * @see arcade.SortDirection For available sorting options
     */
    public var sortDirection:arcade.SortDirection;

#end

    /**
     * Read-only array of all items currently in this group.
     * 
     * This array provides safe read-only access to the group's contents. Use the
     * `add()` and `remove()` methods to modify the group's contents.
     * 
     * Example:
     * ```haxe
     * // Iterate through all items
     * for (item in group.items) {
     *     item.doSomething();
     * }
     * 
     * // Get the number of items
     * var count = group.items.length;
     * ```
     */
    public var items:ReadOnlyArray<T> = [];

    /**
     * Creates a new Group instance.
     * 
     * The group is automatically registered with the application's group management
     * system upon creation.
     * 
     * @param id Optional identifier for the group. Useful for debugging and finding specific groups.
     */
    public function new(?id:String) {

        super();

        if (id != null) {
            this.id = id;
        }

        ceramic.App.app.groups.push(cast this);

    }

    /**
     * Adds an item to this group.
     * 
     * The item will be automatically removed from the group if it gets destroyed.
     * Attempting to add an item that's already in the group will log a warning
     * and the item won't be added again.
     * 
     * @param item The entity to add to this group
     */
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

    /**
     * Removes an item from this group.
     * 
     * This method removes the item from the group's items array and unregisters
     * the destroy listener. The item itself is not destroyed. Attempting to remove
     * an item that's not in the group will log a warning.
     * 
     * @param item The entity to remove from this group
     */
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

    /**
     * Checks whether an item is currently in this group.
     * 
     * @param item The entity to check for
     * @return `true` if the item is in the group, `false` otherwise
     */
    inline public function contains(item:T):Bool {

        return items.indexOf(item) != -1;

    }

    /**
     * Internal callback triggered when an item in the group is destroyed.
     * Automatically removes the destroyed item from the group.
     * 
     * @param item The entity that was destroyed
     */
    function itemDestroyed(item:Entity) {

        remove(cast item);

    }

    /**
     * Removes and destroys all items in this group.
     * 
     * This method iterates through all items, removes their destroy listeners,
     * destroys each item, and then clears the items array. It uses a temporary
     * array from the pool to avoid issues with concurrent modification during
     * the destroy process.
     * 
     * After calling this method, the group will be empty and all previously
     * contained entities will be destroyed.
     */
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

    /**
     * Destroys this group and all items it contains.
     * 
     * This method:
     * 1. Calls the parent destroy method
     * 2. Removes the group from the app's group registry
     * 3. Destroys all items in the group via clear()
     * 
     * After destruction, the group should not be used.
     */
    override function destroy() {

        super.destroy();

        ceramic.App.app.groups.remove(cast this);

        clear();

    }

}
