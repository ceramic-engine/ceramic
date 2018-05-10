package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.crypto.Md5;

import haxe.io.Path;

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

        // TODO append data for real, dont re-read everything

        var _key = Md5.encode('data ~ ' + key);
        var storageDir = ceramic.App.app.backend.info.storageDirectory();
        var filePath = Path.join([storageDir, 'data_' + _key]);

        var str0 = null;
        if (FileSystem.exists(filePath)) {
            str0 = File.getContent(filePath);
        }
        if (str0 == null) {
            str0 = '';
        }

        File.saveContent(filePath, str0 + str);

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

#else

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
