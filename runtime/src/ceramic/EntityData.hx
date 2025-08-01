package ceramic;

/**
 * Static utilities for managing dynamic data on entities.
 * 
 * EntityData provides a convenient API for attaching and retrieving
 * arbitrary data on any entity using the DynamicData component system.
 * This is useful for storing metadata, game state, or configuration
 * without modifying entity classes.
 * 
 * ## Features
 * 
 * - **Automatic Component Management**: Creates DynamicData component as needed
 * - **Fluent API**: Get or set data in a single call
 * - **Type Flexible**: Store any data structure
 * - **Memory Efficient**: Removes component when data is cleared
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Set data on an entity
 * var sprite = new Quad();
 * EntityData.data(sprite, {
 *     health: 100,
 *     speed: 5.0,
 *     inventory: ["sword", "potion"]
 * });
 * 
 * // Get data from entity
 * var data = EntityData.data(sprite);
 * trace(data.health); // 100
 * 
 * // Update existing data
 * data.health = 80;
 * data.powerUp = true;
 * 
 * // Remove all data
 * EntityData.removeData(sprite);
 * ```
 * 
 * ## Design Pattern
 * 
 * This utility follows the extension method pattern, providing
 * functionality that could conceptually be part of Entity but is
 * kept separate to avoid bloating the core class.
 * 
 * @see ceramic.DynamicData For the underlying component
 * @see ceramic.Entity#component For direct component access
 */
class EntityData {

    /**
     * Removes the dynamic data component from an entity.
     * 
     * This completely removes the 'data' component if it exists and
     * is a DynamicData instance. After calling this, the entity will
     * have no associated dynamic data.
     * 
     * @param entity The entity to remove data from
     * 
     * @example
     * ```haxe
     * // Clean up entity data
     * EntityData.removeData(myEntity);
     * 
     * // Now returns empty object on next access
     * var data = EntityData.data(myEntity); // {}
     * ```
     */
    public static function removeData(entity:Entity):Void {

        var dynData = entity.component('data');
        if (dynData != null && dynData is DynamicData) {
            entity.removeComponent('data',);
        }

    }

    /**
     * Gets or sets dynamic data on an entity.
     * 
     * This method serves dual purposes:
     * - When called with just an entity, returns existing data (creating if needed)
     * - When called with entity and data, sets/replaces the data
     * 
     * The data is stored in a DynamicData component with key 'data'.
     * If no component exists, one is created automatically.
     * 
     * @param entity The entity to get/set data on
     * @param data Optional data to set. If provided, replaces existing data.
     *             If not provided and no data exists, an empty object {} is created.
     * @return The entity's dynamic data object
     * 
     * @example
     * ```haxe
     * // First access creates empty data
     * var data = EntityData.data(player);
     * data.score = 0;
     * data.name = "Player 1";
     * 
     * // Set complete data object
     * EntityData.data(enemy, {
     *     type: "goblin",
     *     health: 50,
     *     damage: 10
     * });
     * 
     * // Get existing data
     * var enemyData = EntityData.data(enemy);
     * trace(enemyData.type); // "goblin"
     * ```
     */
    public static function data(entity:Entity, ?data:Any):Dynamic {

        var dynData:DynamicData = entity.component('data');
        if (dynData == null) {
            dynData = new DynamicData(data ?? {});
            entity.component('data', dynData);
        }
        else if (data != null) {
            dynData.data = data;
        }

        return dynData.data;

    }

}