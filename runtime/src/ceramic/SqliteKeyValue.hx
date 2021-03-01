package ceramic;

#if (sys && ceramic_sqlite)

import haxe.io.Bytes;
import haxe.crypto.Base64;

import sys.db.Sqlite;
import sys.db.Connection;
import sys.thread.Mutex;
import sys.thread.Tls;
import sys.FileSystem;

import ceramic.Shortcuts.*;

/** A string-based key value store using Sqlite as backend.
    This is expected to be thread safe. */
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
            return false;
        }

        if (!mutexAcquiredInParent) {
            mutex.release();
        }

        return true;

    }

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
            return false;
        }

        if (!mutexAcquiredInParent) {
            mutex.release();
        }

        return true;

    }

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
            return false;
        }

        mutex.release();

        return true;

    }

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
