package ceramic;

import haxe.DynamicAccess;
import ceramic.Shortcuts.*;

/**
 * Provides a simple key-value storage system for persisting data between application sessions.
 * 
 * PersistentData automatically saves and loads data to platform-specific storage locations,
 * making it ideal for game saves, user preferences, and other data that needs to survive
 * app restarts. The data is serialized using Haxe's built-in serialization format.
 * 
 * Storage locations vary by platform:
 * - Desktop: Application data directory
 * - Mobile: App-specific storage
 * - Web: LocalStorage or similar
 * 
 * Example usage:
 * ```haxe
 * // Create or load persistent storage
 * var saveData = new PersistentData("game_save");
 * 
 * // Store various data types
 * saveData.set("playerLevel", 5);
 * saveData.set("playerName", "Hero");
 * saveData.set("inventory", ["sword", "shield", "potion"]);
 * saveData.set("position", {x: 100, y: 200});
 * 
 * // Save to disk
 * saveData.save();
 * 
 * // Later, retrieve the data
 * var level = saveData.get("playerLevel"); // 5
 * var items:Array<String> = saveData.get("inventory");
 * 
 * // Check if data exists
 * if (saveData.exists("playerName")) {
 *     trace("Welcome back, " + saveData.get("playerName"));
 * }
 * ```
 * 
 * Note: The data is stored in a platform-specific location with the prefix "persistent_"
 * followed by the provided ID. Be mindful of storage limitations on different platforms.
 * 
 * @see ceramic.Settings For application-wide settings
 * @see ceramic.Files For direct file system access
 */
class PersistentData {

    var internalData:DynamicAccess<Dynamic>;

    /**
     * The unique identifier for this persistent data storage.
     * This ID is used as part of the filename when saving/loading data.
     * Once created, the ID cannot be changed.
     */
    public var id(default,null):String;

    /**
     * Creates a new PersistentData instance with the specified ID.
     * 
     * If data with this ID was previously saved, it will be automatically
     * loaded from storage. If loading fails (due to corruption or format
     * changes), a warning is logged and empty storage is initialized.
     * 
     * @param id Unique identifier for this storage. Used as part of the
     *           filename (stored as "persistent_[id]"). Should contain
     *           only filename-safe characters.
     */
    public function new(id:String) {

        this.id = id;

        var rawData = app.backend.io.readString('persistent_' + id);
        if (rawData != null) {
            try {
                var unserializer = new haxe.Unserializer(rawData);
                internalData = unserializer.unserialize();
            } catch (e:Dynamic) {
                log.warning('Failed to read persistent data with id $id');
            }
        }

        if (internalData == null) internalData = {};

    }

    /**
     * Retrieves a value from persistent storage.
     * 
     * @param key The key to look up
     * @return The stored value, or null if the key doesn't exist
     */
    inline public function get(key:String):Dynamic {

        return internalData.get(key);

    }

    /**
     * Stores a value in persistent storage.
     * 
     * The value can be any serializable type including primitives,
     * arrays, anonymous objects, and class instances that support
     * Haxe serialization. Changes are only persisted when save() is called.
     * 
     * @param key The key to store the value under
     * @param value The value to store (must be serializable)
     */
    inline public function set(key:String, value:Dynamic):Void {

        internalData.set(key, value);

    }

    /**
     * Removes a key-value pair from persistent storage.
     * 
     * @param key The key to remove
     */
    inline public function remove(key:String):Void {

        internalData.remove(key);

    }

    /**
     * Removes all key-value pairs from persistent storage.
     * 
     * This clears the in-memory data but doesn't affect the saved
     * file until save() is called.
     */
    inline public function clear():Void {

        for (key in internalData.keys()) {
            internalData.remove(key);
        }

    }

    /**
     * Checks if a key exists in persistent storage.
     * 
     * @param key The key to check
     * @return True if the key exists, false otherwise
     */
    inline public function exists(key:String):Bool {

        return internalData.exists(key);

    }

    /**
     * Returns an array of all keys in persistent storage.
     * 
     * Useful for iterating over all stored data or checking
     * what data is available.
     * 
     * @return Array of all keys currently in storage
     */
    inline public function keys():Array<String> {

        return internalData.keys();

    }

    /**
     * Saves the current data to persistent storage.
     * 
     * This method must be called to persist any changes made with set(),
     * remove(), or clear(). The data is serialized and written to a
     * platform-specific storage location.
     * 
     * Note: Saving is not automatic - you must explicitly call this method
     * when you want to persist changes. Consider saving at appropriate
     * points like level completion, settings changes, or app pause/exit.
     * 
     * Example:
     * ```haxe
     * var save = new PersistentData("player");
     * save.set("score", 1000);
     * save.set("level", 5);
     * save.save(); // Don't forget to save!
     * ```
     */
    public function save() {

        var serializer = new haxe.Serializer();
        serializer.serialize(internalData);
        var rawData = serializer.toString();

        app.backend.io.saveString('persistent_' + id, rawData);

    }

}
