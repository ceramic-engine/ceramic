package ceramic;

#if (sys && ceramic_sqlite)

import ceramic.Shortcuts.*;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.db.Connection;
import sys.db.Sqlite;
import sys.thread.Mutex;
import sys.thread.Tls;

/**
 * Thread-safe key-value storage backed by SQLite database.
 * 
 * SqliteKeyValue provides persistent string-based storage with support for
 * multi-threaded access. It's designed for applications that need reliable,
 * ACID-compliant data persistence with good performance characteristics.
 * 
 * Key features:
 * - Thread-safe operations using mutexes and thread-local connections
 * - Automatic database creation and schema management
 * - Support for append operations with automatic compaction
 * - Base64 encoding for safe storage of any string content
 * - Transaction support for data integrity
 * 
 * Special append functionality:
 * The class supports efficient append operations where multiple values can be
 * associated with a single key. When reading, these are automatically concatenated.
 * To prevent unbounded growth, the system automatically compacts entries when
 * they exceed APPEND_ENTRIES_LIMIT (128 entries).
 * 
 * Example usage:
 * ```haxe
 * // Create or open a database
 * var kv = new SqliteKeyValue("data.db", "settings");
 * 
 * // Store values
 * kv.set("username", "alice");
 * kv.set("highscore", "9500");
 * 
 * // Retrieve values
 * var username = kv.get("username"); // "alice"
 * 
 * // Append to values (useful for logs)
 * kv.set("log", "Application started\n");
 * kv.append("log", "User logged in\n");
 * kv.append("log", "Game started\n");
 * var fullLog = kv.get("log"); // All entries concatenated
 * 
 * // Remove values
 * kv.remove("temporary_data");
 * ```
 * 
 * Performance considerations:
 * - Each thread gets its own SQLite connection for better concurrency
 * - Transactions are used for atomic operations
 * - The append operation is optimized for write performance
 * - Automatic compaction prevents performance degradation
 * 
 * Available only on sys targets with ceramic_sqlite flag enabled.
 * 
 * @see ceramic.PersistentData For simpler key-value storage needs
 */
class SqliteKeyValue extends Entity {

    static final APPEND_ENTRIES_LIMIT:Int = 128;

    var path:String;

    var table:String;

    var escapedTable:String;

    var connections:Array<Connection>;

    var tlsConnection:Tls<Connection>;

    var mutex:Mutex;

    var mutexAcquiredInParent:Bool = false;

    function getConnection():Connection {
        var connection = tlsConnection.value;
        if (connection == null) {
            connection = Sqlite.open(path);
            connections.push(connection);
            tlsConnection.value = connection;
        }
        return connection;
    }

    /**
     * Creates a new SQLite-backed key-value store.
     * 
     * If the database file doesn't exist, it will be created automatically
     * with the appropriate schema. If it exists, the specified table will
     * be used (created if necessary).
     * 
     * @param path Path to the SQLite database file
     * @param table Name of the table to use for storage (default: "KeyValue")
     */
    public function new(path:String, table:String = 'KeyValue') {

        super();

        mutex = new Mutex();

        mutex.acquire();
        connections = [];
        tlsConnection = new Tls();
        mutex.release();

        this.path = path;
        this.table = table;

        var fileExists = FileSystem.exists(path);

        escapedTable = escape(table);

        if (!fileExists) {
            createDb();
        }

    }

    override function destroy() {

        mutex.acquire();
        for (connection in connections) {
            connection.close();
        }
        mutex.release();

        super.destroy();

    }

    /**
     * Sets a value for the given key, replacing any existing value.
     * 
     * This operation is atomic - it will either completely succeed or fail.
     * If the value is null, the key will be removed.
     * 
     * The value is Base64-encoded before storage to handle any string content
     * safely, including binary data or special characters.
     * 
     * @param key The key to store the value under
     * @param value The value to store. If null, removes the key.
     * @return true if the operation succeeded, false on error
     */
    public function set(key:String, value:String):Bool {

        if (value == null) {
            return remove(key);
        }

        var escapedKey = escape(key);

        var valueBytes = Bytes.ofString(value, UTF8);
        var escapedValue = "'" + Base64.encode(valueBytes) + "'";

        if (!mutexAcquiredInParent) {
            mutex.acquire();
        }

        try {
            var connection = getConnection();

            connection.request('BEGIN TRANSACTION');

            connection.request('DELETE FROM $escapedTable WHERE k = $escapedKey');

            connection.request('INSERT INTO $escapedTable (k,v) VALUES ($escapedKey,$escapedValue)');

            connection.request('COMMIT');
        }
        catch (e:Dynamic) {
            log.error('Failed to set value for key $key: $e');
            if (!mutexAcquiredInParent) {
                mutex.release();
            }
            return false;
        }

        if (!mutexAcquiredInParent) {
            mutex.release();
        }

        return true;

    }

    /**
     * Removes a key and all its associated values from storage.
     * 
     * This will delete all entries for the key, including any
     * appended values.
     * 
     * @param key The key to remove
     * @return true if the operation succeeded, false on error
     */
    public function remove(key:String):Bool {

        var escapedKey = escape(key);

        if (!mutexAcquiredInParent) {
            mutex.acquire();
        }

        try {
            var connection = getConnection();
            connection.request('DELETE FROM $escapedTable WHERE k = $escapedKey');
        }
        catch (e:Dynamic) {
            log.error('Failed to remove value for key $key: $e');
            if (!mutexAcquiredInParent) {
                mutex.release();
            }
            return false;
        }

        if (!mutexAcquiredInParent) {
            mutex.release();
        }

        return true;

    }

    /**
     * Appends a value to an existing key without replacing previous values.
     * 
     * This is useful for building up values over time, such as logs or
     * accumulating data. When the key is read with get(), all appended
     * values are concatenated together.
     * 
     * Note: To prevent unbounded growth, keys with more than 128 append
     * entries will be automatically compacted into a single entry on read.
     * 
     * @param key The key to append to
     * @param value The value to append
     * @return true if the operation succeeded, false on error
     */
    public function append(key:String, value:String):Bool {

        var escapedKey = escape(key);

        var valueBytes = Bytes.ofString(value);
        var escapedValue = "'" + Base64.encode(valueBytes) + "'";

        mutex.acquire();

        try {
            var connection = getConnection();
            connection.request('INSERT INTO $escapedTable (k, v) VALUES ($escapedKey, $escapedValue)');
        }
        catch (e:Dynamic) {
            log.error('Failed to append value for key $key: $e');
            mutex.release();
            return false;
        }

        mutex.release();

        return true;

    }

    /**
     * Retrieves the value associated with a key.
     * 
     * If multiple values have been appended to the key, they are
     * concatenated together in the order they were added.
     * 
     * Automatic compaction: If more than 128 entries exist for a key,
     * they will be automatically compacted into a single entry to
     * maintain performance.
     * 
     * @param key The key to retrieve
     * @return The stored value, or null if the key doesn't exist
     */
    public function get(key:String):String {

        var escapedKey = escape(key);

        mutex.acquire();

        var value:StringBuf = null;
        var numEntries:Int = 0;

        try {
            var connection = getConnection();
            var result = connection.request('SELECT v FROM $escapedTable WHERE k = $escapedKey ORDER BY i ASC');

            for (entry in result) {
                if (value == null) {
                    value = new StringBuf();
                }
                var rawValue:String = entry.v;
                var rawBytes = Base64.decode(rawValue);
                value.add(rawBytes.toString());
                numEntries++;
            }
        }
        catch (e:Dynamic) {
            log.error('Failed to get value for key $key: $e');
            mutex.release();
            return null;
        }

        // When reading a key, we check that we didn't reach a too high number of entries due
        // to subsequent calls of append(). If that happens, we compact the value as a single entry.
        if (numEntries > APPEND_ENTRIES_LIMIT) {
            mutexAcquiredInParent = true;
            set(key, value.toString());
            mutexAcquiredInParent = false;
        }

        mutex.release();

        return value != null ? value.toString() : null;

    }

    /// Internal

    inline function escape(token:String):String {

        return "'" + StringTools.replace(token, "'", "''") + "'";

    }

    function createDb():Void {

        mutex.acquire();

        var connection = getConnection();

        connection.request('BEGIN TRANSACTION');

        connection.request('PRAGMA encoding = "UTF-8"');

        connection.request('
            CREATE TABLE $escapedTable (
                i INTEGER PRIMARY KEY AUTOINCREMENT,
                k TEXT NOT NULL,
                v TEXT NOT NULL
            )
        ');

        connection.request('CREATE INDEX k_idx ON $escapedTable(k)');

        connection.request('COMMIT');

        mutex.release();

    }

}

#end
