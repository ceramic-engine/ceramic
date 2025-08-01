package ceramic;

/**
 * A flexible component for attaching arbitrary data to entities.
 * 
 * DynamicData provides a way to associate any type of data with an entity
 * without modifying the entity's class. This is useful for storing metadata,
 * configuration, or temporary state that doesn't warrant a dedicated component.
 * 
 * ## Features
 * 
 * - **Lazy Initialization**: Data object created only when accessed
 * - **Type Flexible**: Can store any Dynamic data structure
 * - **Component Pattern**: Can be attached to any entity
 * - **Memory Efficient**: No allocation until data is needed
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Attach custom data to an entity
 * var sprite = new Quad();
 * var data = new DynamicData({
 *     health: 100,
 *     speed: 5.0,
 *     name: "Player"
 * });
 * sprite.component("dynamicData", data);
 * 
 * // Access data later
 * var data = sprite.component("dynamicData", DynamicData);
 * trace(data.data.health); // 100
 * 
 * // Lazy initialization
 * var emptyData = new DynamicData();
 * emptyData.data.score = 0; // Creates {} automatically
 * ```
 * 
 * ## Common Use Cases
 * 
 * - Game object properties (health, score, inventory)
 * - UI element configuration
 * - Temporary animation state
 * - Debug information
 * - Plugin-specific data
 * 
 * @see ceramic.Component For the component system
 * @see ceramic.Entity#component For attaching components
 */
class DynamicData extends Entity implements Component {

    /**
     * Internal storage for the dynamic data.
     * Lazily initialized to save memory.
     */
    @:noCompletion var _data:Dynamic = null;

    /**
     * Whether this component currently has data assigned.
     * Returns true if data has been set or accessed (triggering lazy init).
     * 
     * @return True if data exists, false if still null
     */
    public var hasData(get,never):Bool;
    inline function get_hasData():Bool {
        return _data != null;
    }

    /**
     * The dynamic data stored in this component.
     * 
     * On first access, automatically initializes to an empty object {}
     * if no data was previously set. This allows for convenient property
     * assignment without null checks.
     * 
     * @return The data object (never null after first access)
     * 
     * @example
     * ```haxe
     * var dynData = new DynamicData();
     * dynData.data.score = 100; // Auto-creates {}
     * dynData.data.name = "Player";
     * 
     * // Or set entire object
     * dynData.data = {
     *     x: 100,
     *     y: 200,
     *     items: ["sword", "shield"]
     * };
     * ```
     */
    public var data(get,set):Dynamic;
    function get_data():Dynamic {
        if (_data == null) _data = {};
        return _data;
    }
    function set_data(data:Dynamic):Dynamic {
        return _data = data;
    }

    /**
     * Creates a new DynamicData component.
     * 
     * @param data Optional initial data to store. If not provided,
     *             data will be lazily initialized on first access.
     * 
     * @example
     * ```haxe
     * // With initial data
     * var data1 = new DynamicData({level: 1, xp: 0});
     * 
     * // Without initial data (lazy init)
     * var data2 = new DynamicData();
     * ```
     */
    public function new(?data:Dynamic) {
        super();
        if (data != null) this.data = data;
    }

    /**
     * Called when this component is bound to an entity.
     * Currently empty as DynamicData doesn't require special binding logic.
     */
    function bindAsComponent() {
        //
    }

}
