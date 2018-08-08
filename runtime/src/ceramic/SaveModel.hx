package ceramic;

import ceramic.Shortcuts.*;
import ceramic.Assert.*;

class SaveModel {

/// Public API

    public static function getSavedOrCreate<T:Model>(modelClass:Class<T>, key:String, ?args:Array<Dynamic>):T {

        // Create new instance
        var instance = Type.createInstance(modelClass, args != null ? args : []);

        // Load saved data
        loadSaved(instance, key);

        return instance;

    } //modelClass

    public static function loadSaved(model:Model, key:String):Bool {

        var data = app.backend.io.readString('save_' + key);

        if (data == null) {
            // No data, stop here
            return false;
        }

        // Serialize previous data to compare it with new one
        Serialize._serializedMap = new Map();
        Serialize._deserializedMap = new Map();

        Serialize.serializeValue(model);

        var prevDeserializedMap = Serialize._deserializedMap;
        Serialize._serializedMap = null;
        Serialize._deserializedMap = null;

        // Decode new data
        var decoded = decodeData(data);

        // Then deserialize it
        Serialize._serializedMap = decoded.serializedMap;
        Serialize._deserializedMap = new Map();

        Serialize.deserializeValue(decoded.serialized, model);

        var deserializedMap = Serialize._deserializedMap;
        Serialize._deserializedMap = null;
        Serialize._serializedMap = null;

        // Destroy previous model objects not used anymore (if any)
        // Use previous serialized map to perform the change
        for (key in prevDeserializedMap.keys()) {
            if (!deserializedMap.exists(key)) {
                var item = prevDeserializedMap.get(key);
                if (Std.is(item, Model)) {
                    var _model:Model = cast item;
                    if (_model != model) {
                        _model.destroy();
                    }
                }
            }
        }

        return true;

    } //loadSaved

    public static function autoSave(model:Model, key:String, interval:Float = #if debug 1.0 #else 60.0 #end) {

        if (model.serializer != null) {
            model.serializer.destroy();
            model.serializer = null;
        }

        var serializer = new SerializeModel();
        serializer.checkInterval = interval;

        // Start listening for changes to save them
        serializer.onChangeset(model, function(changeset) {

            if (changeset.append) {
                app.backend.io.appendString('save_' + key, changeset.data.length + ':' + changeset.data);
            } else {
                app.backend.io.saveString('save_' + key, changeset.data.length + ':' + changeset.data);
            }

        });

        // Assign component
        model.serializer = serializer;

    } //autoSave

/// Internal

    static function decodeData(rawData:String) {

        var serializedMap:Map<String,{ id:String, type:String, props:Dynamic }> = new Map();
        var rootInfo = null;

        // Reload an array of all changesets
        var changesetData:Array<String> = [];

        // TODO handle corrupted saves?

        while (true) {
            var colonIndex = rawData.indexOf(':');
            if (colonIndex == -1) break;

            var len = Std.parseInt(rawData.substr(0, colonIndex));
            changesetData.push(rawData.substr(colonIndex + 1, len));

            rawData = rawData.substr(colonIndex + 1 + len);
        }

        // Reconstruct the mapping
        var i = changesetData.length - 1;
        while (i >= 0) {
            var data = changesetData[i];

            if (i == 0) {
                var u = new haxe.Unserializer(data);

                // Get root object info
                rootInfo = u.unserialize();

                // Update serialized map
                var changesetSerializedMap:Map<String,{ id:String, type:String, props:Dynamic }> = u.unserialize();
                for (item in changesetSerializedMap) {
                    var id = item.id;
                    if (!serializedMap.exists(id)) {
                        serializedMap.set(id, item);
                    }
                }
            }
            else {
                var u = new haxe.Unserializer(data);

                // Update serialized map
                var toAppend:Array<{ id:String, type:String, props:Dynamic }> = u.unserialize();
                for (item in toAppend) {
                    var id = item.id;
                    if (!serializedMap.exists(id)) {
                        serializedMap.set(id, item);
                    }
                }
            }

            i--;
        }

        return {
            serialized: rootInfo,
            serializedMap: serializedMap
        };

    } //decodeData

} //SaveModel
