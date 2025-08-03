package backend;

import cs.system.text.Encoding;
import cs.system.io.File;

import haxe.crypto.Md5;

import ceramic.Path;
import ceramic.HashedString;
import ceramic.Shortcuts.*;

#if !no_backend_docs
/**
 * Unity implementation of the IO backend interface.
 * 
 * Provides persistent storage operations using the Unity persistent data path.
 * All data is stored as files with MD5-hashed names for security and to avoid
 * filesystem issues with special characters in keys.
 * 
 * Data integrity features:
 * - Keys are hashed with MD5 to create safe filenames
 * - Values are encoded with HashedString for integrity verification
 * - UTF-8 encoding ensures proper Unicode support
 * - Files are prefixed with 'data_' to distinguish from other files
 * 
 * The storage location varies by platform but is always writable and persists
 * between application launches. Files are stored in the directory returned by
 * Unity's Application.persistentDataPath.
 * 
 * @see spec.IO The interface this class implements
 * @see ceramic.HashedString Provides encoding/decoding with integrity checks
 * @see backend.Info Provides the storage directory path
 */
#end
class IO implements spec.IO {

    #if !no_backend_docs
    /**
     * Creates a new IO instance.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Saves a string value with the given key to persistent storage.
     * If the value is null, deletes the stored data for that key.
     * 
     * The key is hashed to create a safe filename, and the value is
     * encoded with integrity checking before being written to disk.
     * 
     * @param key The storage key (will be hashed)
     * @param str The string value to store, or null to delete
     * @return Always returns true (write errors would throw exceptions)
     */
    #end
    public function saveString(key:String, str:String):Bool {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        if (str == null) {
            if (File.Exists(filePath)) {
                File.Delete(filePath);
            }
        } else {
            File.WriteAllText(filePath, HashedString.encode(str), Encoding.UTF8);
        }

        return true;

    }

    #if !no_backend_docs
    /**
     * Appends a string value to existing data for the given key.
     * If no data exists for the key, creates a new file with the value.
     * 
     * Note: Each append operation encodes the string separately,
     * so reading back the data would need to decode multiple
     * HashedString blocks.
     * 
     * @param key The storage key (will be hashed)
     * @param str The string value to append
     * @return Always returns true (write errors would throw exceptions)
     */
    #end
    public function appendString(key:String, str:String):Bool {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        if (File.Exists(filePath)) {
            File.AppendAllText(filePath, HashedString.encode(str), Encoding.UTF8);
            /*
            var output = File.AppendText(filePath);
            output.Write(HashedString.encode(str));
            output.Close();
            */
        }
        else {
            File.WriteAllText(filePath, HashedString.encode(str), Encoding.UTF8);
        }

        return true;

    }

    #if !no_backend_docs
    /**
     * Reads a string value for the given key from persistent storage.
     * 
     * The stored data is decoded and verified for integrity.
     * If the data is corrupted or doesn't exist, returns null.
     * 
     * @param key The storage key (will be hashed)
     * @return The stored string value, or null if not found or corrupted
     */
    #end
    public function readString(key:String):String {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        var str = null;
        if (File.Exists(filePath)) {
            str = File.ReadAllText(filePath, Encoding.UTF8);
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

}
