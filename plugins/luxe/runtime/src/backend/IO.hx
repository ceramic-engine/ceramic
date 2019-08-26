package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.crypto.Md5;
import ceramic.Path;
import ceramic.Shortcuts.*;

class IO implements spec.IO {

    public function new() {}

#if sys

    public function saveString(key:String, str:String):Bool {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        if (str == null) {
            if (FileSystem.exists(filePath)) {
                FileSystem.deleteFile(filePath);
            }
        } else {
            File.saveContent(filePath, str);
        }

        return true;

    } //saveString

    public function appendString(key:String, str:String):Bool {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        if (FileSystem.exists(filePath)) {
            var output = File.append(filePath, false);
            output.writeString(str);
            output.close();
        }
        else {
            File.saveContent(filePath, str);
        }

        return true;

    } //appendString

    public function readString(key:String):String {

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        var str = null;
        if (FileSystem.exists(filePath)) {
            str = File.getContent(filePath);
        }

        return str;

    } //readString

#elseif web

    public function saveString(key:String, str:String):Bool {

        var storage = js.Browser.window.localStorage;
        if (storage == null) {
            error('Cannot save string: localStorage not supported on this browser');
            return false;
        }

        try {
            storage.setItem(key, str);
        }
        catch (e:Dynamic) {
            error('Failed to save string (key=$key): ' + e);
            return false;
        }

        return true;

    } //saveString

    public function appendString(key:String, str:String):Bool {

        var storage = js.Browser.window.localStorage;
        if (storage == null) {
            error('Cannot append string: localStorage not supported on this browser');
            return false;
        }

        try {
            var existing = storage.getItem(key);
            if (existing == null) {
                storage.setItem(key, str);
            }
            else {
                storage.setItem(key, existing + str);
            }
        }
        catch (e:Dynamic) {
            error('Failed to append string (key=$key): ' + e);
            return false;
        }

        return true;

    } //appendString

    public function readString(key:String):String {

        var storage = js.Browser.window.localStorage;
        if (storage == null) {
            error('Cannot read string: localStorage not supported on this browser');
            return null;
        }

        try {
            return storage.getItem(key);
        }
        catch (e:Dynamic) {
            error('Failed to read string (key=$key): ' + e);
            return null;
        }

    } //readString

#else

    // Default luxe implementation is not optimal as it does
    // re-encode a whole map slot everytime we change a key.
    // As we are only using cpp and web targets in practice,
    // this code is actually not used but we keep it for reference.

    public function saveString(key:String, str:String):Bool {

        return Luxe.io.string_save(key, str, 0);

    } //saveString

    public function appendString(key:String, str:String):Bool {

        var str0 = Luxe.io.string_load(key, 0);
        if (str0 == null) {
            str0 = '';
        }
        
        return Luxe.io.string_save(key, str0 + str, 0);

    } //appendString

    public function readString(key:String):String {

        return Luxe.io.string_load(key, 0);

    } //readString

#end

} //IO
