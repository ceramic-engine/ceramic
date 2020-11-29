package backend;

import cs.system.text.Encoding;
import cs.system.io.File;

import haxe.crypto.Md5;

import ceramic.Path;
import ceramic.HashedString;
import ceramic.Shortcuts.*;

class IO implements spec.IO {

    public function new() {}

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
