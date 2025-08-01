package spec;

/**
 * Backend interface for file input/output operations.
 * 
 * This interface provides simple key-value file storage in the platform's
 * storage directory. It's primarily used for saving game data, preferences,
 * and other persistent information.
 * 
 * The 'key' parameter is typically a relative file path within the storage
 * directory. Backends handle the actual file system operations and ensure
 * data is written to the appropriate platform-specific location.
 * 
 * @see spec.Info.storageDirectory() for the storage location
 */
interface IO {

    /**
     * Saves a string to persistent storage, overwriting any existing content.
     * The key is used as a relative file path within the storage directory.
     * 
     * @param key The storage key/path (e.g., "saves/game1.json")
     * @param str The string content to save
     * @return True if the save was successful, false on error
     */
    function saveString(key:String, str:String):Bool;

    /**
     * Appends a string to an existing file in persistent storage.
     * If the file doesn't exist, it will be created.
     * 
     * @param key The storage key/path (e.g., "logs/debug.txt")
     * @param str The string content to append
     * @return True if the append was successful, false on error
     */
    function appendString(key:String, str:String):Bool;

    /**
     * Reads a string from persistent storage.
     * 
     * @param key The storage key/path (e.g., "saves/game1.json")
     * @return The file contents as a string, or null if the file doesn't exist or can't be read
     */
    function readString(key:String):String;

}
