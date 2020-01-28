package ceramic;

import haxe.DynamicAccess;
import ceramic.Shortcuts.*;

class PersistentData {

    var internalData:DynamicAccess<Dynamic>;

    public var id(default,null):String;

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

    inline public function get(key:String):Dynamic {

        return internalData.get(key);

    }

    inline public function set(key:String, value:Dynamic):Void {

        internalData.set(key, value);

    }

    inline public function remove(key:String):Void {

        internalData.remove(key);

    }

    inline public function exists(key:String):Bool {

        return internalData.exists(key);

    }

    inline public function keys():Array<String> {

        return internalData.keys();

    }

    public function save() {

        var serializer = new haxe.Serializer();
        serializer.serialize(internalData);
        var rawData = serializer.toString();

        app.backend.io.saveString('persistent_' + id, rawData);

    }

}
