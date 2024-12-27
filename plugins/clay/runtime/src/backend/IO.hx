package backend;

#if (sys && ceramic_sqlite && !ceramic_no_sqlite_save_string)
import ceramic.SqliteKeyValue;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import ceramic.HashedString;
import ceramic.Path;
import ceramic.Shortcuts.*;
import haxe.crypto.Md5;

class IO implements spec.IO {

    public function new() {}

    @:allow(backend.Main)
    function initKeyValueIfNeeded() {

        #if (sys && ceramic_sqlite && !ceramic_no_sqlite_save_string && !ceramic_no_sqlite_key_value_init)
        initKeyValue();
        #end

    }

#if (sys && ceramic_sqlite && !ceramic_no_sqlite_save_string)

    var keyValue:SqliteKeyValue = null;

    function initKeyValue():Void {

        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        if (storageDir == null) {
            throw 'Failed to init sqlite key value because storage directory is null';
        }
        var dbPath = Path.join([storageDir, 'data.db']);

        log.info('Initialize sqlite (path: $dbPath)');
        keyValue = new SqliteKeyValue(dbPath, 'KeyValue');

        #if ceramic_import_assets_sqlite_db
        var testKey:String = ceramic.macros.DefinesMacro.getDefine('ceramic_import_assets_sqlite_db');
        var didImport = keyValue.get(testKey);
        if (didImport == null) {
            log.debug('Import custom db from assets');
            // Need to import db from assets
            keyValue.destroy();

            // Try to locate a file in assets
            var assetsFilePath = ceramic.Platform.getAssetsPath();
            if (assetsFilePath != null) {
                var dbInAssets = ceramic.Path.join([assetsFilePath, 'data.db']);
                if (!FileSystem.exists(dbInAssets)) {
                    throw 'Missing assets data.db file (path: $dbInAssets)';
                }
                if (FileSystem.isDirectory(dbInAssets)) {
                    throw 'Directory data.db is not a file, expected an sqlite db (path: $dbInAssets)';
                }
                File.copy(
                    dbInAssets,
                    dbPath
                );
            }
            else {
                // No assets file path on this platform. Try to get bytes directly
                var bytes = ceramic.Platform.readBytesFromAsset('data.db');
                if (bytes == null) {
                    throw 'Failed to extract bytes from data.db asset';
                }
                if (FileSystem.exists(dbPath)) {
                    ceramic.Files.deleteRecursive(dbPath);
                }
                File.saveBytes(dbPath, bytes);
            }

            // Initialize updated key value store
            keyValue = new SqliteKeyValue(dbPath, 'KeyValue');
            // Mark it as imported
            keyValue.set(testKey, '1');
        }
        #end

    }

    #if ceramic_import_assets_sqlite_db
    public function unmarkDbImportedFromAssets() {

        var testKey:String = ceramic.macros.DefinesMacro.getDefine('ceramic_import_assets_sqlite_db');
        keyValue.set(testKey, null);

    }
    #end

    public function saveString(key:String, str:String):Bool {

        if (keyValue == null) {
            initKeyValue();
        }

        var _key = Md5.encode('data ~ ' + key);
        return keyValue.set(_key, str);

    }

    public function appendString(key:String, str:String):Bool {

        if (keyValue == null) {
            initKeyValue();
        }

        var _key = Md5.encode('data ~ ' + key);
        return keyValue.append(_key, str);

    }

    public function readString(key:String):String {

        if (keyValue == null) {
            initKeyValue();
        }

        var _key = Md5.encode('data ~ ' + key);
        return keyValue.get(_key);

    }

#elseif sys

    public function saveString(key:String, str:String):Bool {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        if (str == null) {
            if (FileSystem.exists(filePath)) {
                FileSystem.deleteFile(filePath);
            }
        } else {
            File.saveContent(filePath, HashedString.encode(str));
        }

        return true;

    }

    public function appendString(key:String, str:String):Bool {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        if (FileSystem.exists(filePath)) {
            var output = File.append(filePath, false);
            output.writeString(HashedString.encode(str));
            output.close();
        }
        else {
            File.saveContent(filePath, HashedString.encode(str));
        }

        return true;

    }

    public function readString(key:String):String {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        var str = null;
        if (FileSystem.exists(filePath)) {
            str = File.getContent(filePath);
        }

        if (str != null) {
            try {
                return HashedString.decode(str);
            }
            catch (e:Dynamic) {
                log.error('Failed to decode hashed string: $e');
            }
        }
        return null;

    }

#elseif web

    public function saveString(key:String, str:String):Bool {

        try {
            var storage = js.Browser.window.localStorage;
            if (storage == null) {
                log.error('Cannot save string: localStorage not supported on this browser');
                return false;
            }

            storage.setItem(key, HashedString.encode(str));
        }
        catch (e:Dynamic) {
            log.error('Failed to save string (key=$key): ' + e);
            return false;
        }

        return true;

    }

    public function appendString(key:String, str:String):Bool {

        try {
            var storage = js.Browser.window.localStorage;
            if (storage == null) {
                log.error('Cannot append string: localStorage not supported on this browser');
                return false;
            }

            var existing = storage.getItem(key);
            if (existing == null) {
                storage.setItem(key, HashedString.encode(str));
            }
            else {
                storage.setItem(key, existing + HashedString.encode(str));
            }
        }
        catch (e:Dynamic) {
            log.error('Failed to append string (key=$key): ' + e);
            return false;
        }

        return true;

    }

    public function readString(key:String):String {

        try {
            var storage = js.Browser.window.localStorage;
            if (storage == null) {
                log.error('Cannot read string: localStorage not supported on this browser');
                return null;
            }

            var str = storage.getItem(key);
            return str != null ? HashedString.decode(str) : null;
        }
        catch (e:Dynamic) {
            log.error('Failed to read string (key=$key): ' + e);
            return null;
        }

    }

#end

}
