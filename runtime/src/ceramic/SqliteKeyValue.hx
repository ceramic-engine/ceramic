package ceramic;

#if (sys && ceramic_sqlite)

import haxe.io.Bytes;
import haxe.crypto.Base64;

import sys.db.Sqlite;
import sys.db.Connection;
import sys.thread.Mutex;
import sys.FileSystem;

/** A string-based key value store using Sqlite as backend.
    This is expected to be thread safe. */
class SqliteKeyValue extends Entity {

    var path:String;

    var table:String;

    var escapedTable:String;

    var connection:Connection;

    var mutex:Mutex;

    public function new(path:String, table:String = 'KeyValue') {

        super();

        mutex = new Mutex();

        this.path = path;
        this.table = table;

        var fileExists = FileSystem.exists(path);

        connection = Sqlite.open(path);
        escapedTable = escape(table);

        if (!fileExists) {
            createDb();
        }

    } //new

    public function set(key:String, value:String):Void {

        if (value == null) {
            remove(key);
            return;
        }

        var escapedKey = escape(key);

        var valueBytes = Bytes.ofString(value, UTF8);
        var escapedValue = "'" + Base64.encode(valueBytes) + "'";
        
        mutex.acquire();

        connection.request('BEGIN TRANSACTION');

        connection.request('DELETE FROM $escapedTable WHERE k = $escapedKey');

        connection.request('INSERT INTO $escapedTable (k,v) VALUES ($escapedKey,$escapedValue)');

        connection.request('COMMIT');

        mutex.release();

    } //set

    public function remove(key:String):Void {

        var escapedKey = escape(key);

        mutex.acquire();

        connection.request('DELETE FROM $escapedTable WHERE k = $escapedKey');

        mutex.release();

    } //remove

    public function append(key:String, value:String):Void {

        var escapedKey = escape(key);

        var valueBytes = Bytes.ofString(value);
        var escapedValue = "'" + Base64.encode(valueBytes) + "'";

        mutex.acquire();

        connection.request('INSERT INTO $escapedTable (k, v) VALUES ($escapedKey, $escapedValue)');

        mutex.release();

    } //append

    public function get(key:String):String {

        var escapedKey = escape(key);

        mutex.acquire();

        var result = connection.request('SELECT v FROM $escapedTable WHERE k = $escapedKey ORDER BY i ASC');

        var value:StringBuf = null;

        for (entry in result) {
            if (value == null) {
                value = new StringBuf();
            }
            var rawValue:String = entry.v;
            var rawBytes = Base64.decode(rawValue);
            value.add(rawBytes.toString());
        }
        
        mutex.release();

        return value != null ? value.toString() : null;

    } //get

    /// Internal

    inline function escape(token:String):String {

        return "'" + StringTools.replace(token, "'", "''") + "'";

    } //escape

    function createDb():Void {

        mutex.acquire();

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

    } //createDb

} //SqliteKeyValue

#end
