package ceramic;

/**
 * A collection entry that can hold any value.
 * 
 * This class extends CollectionEntry to provide a generic container that can be
 * stored in a Collection. It combines the ID/name functionality of CollectionEntry
 * with the ability to store any typed value.
 * 
 * ValueEntry is useful when you need to store heterogeneous data in collections
 * while maintaining type safety for individual entries.
 * 
 * Example usage:
 * ```haxe
 * // Create a collection of settings
 * var settings = new Collection<ValueEntry<Dynamic>>();
 * 
 * // Add different types of values
 * settings.add(new ValueEntry<Bool>(true, "enableSound", "Enable Sound"));
 * settings.add(new ValueEntry<Float>(0.8, "volume", "Volume Level"));
 * settings.add(new ValueEntry<String>("high", "quality", "Graphics Quality"));
 * 
 * // Retrieve values by ID
 * var soundEnabled = settings.get("enableSound").value; // true
 * var volume = settings.get("volume").value; // 0.8
 * ```
 * 
 * @param T The type of value this entry holds
 * @see ceramic.CollectionEntry
 * @see ceramic.Collection
 */
class ValueEntry<T> extends CollectionEntry {

    /**
     * The stored value of type T.
     * Can be read and written directly.
     */
    public var value:T;

    /**
     * Create a new ValueEntry.
     * 
     * @param value The value to store in this entry
     * @param id Optional unique identifier for this entry in a collection
     * @param name Optional human-readable name for this entry
     */
    public function new(value:T, ?id:String, ?name:String) {

        super(id, name);

        this.value = value;

    }

}
