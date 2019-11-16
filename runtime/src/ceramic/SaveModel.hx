package ceramic;

import ceramic.Shortcuts.*;
import ceramic.Assert.*;

class SaveModel {

    inline static var NUM_BACKUPS = 5;

    static var saveStepByKey:Map<String,Int> = new Map();

    static var backgroundQueue:BackgroundQueue = null;

/// Public API

    public static function getSavedOrCreate<T:Model>(modelClass:Class<T>, key:String, ?args:Array<Dynamic>):T {

        // Create new instance
        var instance = Type.createInstance(modelClass, args != null ? args : []);

        // Load saved data
        loadFromKey(instance, key);

        return instance;

    } //modelClass

    public static function loadFromKey(model:Model, key:String):Bool {

        var id = Std.parseInt(app.backend.io.readString('save_id_1_' + key));
        if (id != 1 && id != 2) {
            id = Std.parseInt(app.backend.io.readString('save_id_2_' + key));
        }

        if (id != 1 && id != 2) {
            warning('Failed to load save from key: $key (no existing save)');
            return false;
        }

        var data = app.backend.io.readString('save_data_' + id + '_' + key);

        return loadFromData(model, data);

    } //loadFromKey

    public static function loadFromData(model:Model, data:String):Bool {

        if (data == null) {
            // No data, stop here
            return false;
        }

        // Serialize previous data to compare it with new one
        Serialize._serializedMap = new Map();
        Serialize._deserializedMap = new Map();

        Serialize.serializeValue(model);

        var prevDeserializedMap:Map<String, Serializable> = Serialize._deserializedMap;
        Serialize._serializedMap = null;
        Serialize._deserializedMap = null;

        // Decode new data
        var decoded = decodeData(data);

        // Then deserialize it
        Serialize._serializedMap = decoded.serializedMap;
        Serialize._deserializedMap = new Map();

        Serialize.deserializeValue(decoded.serialized, model);

        var deserializedMap:Map<String, Serializable> = Serialize._deserializedMap;
        Serialize._deserializedMap = null;
        Serialize._serializedMap = null;

        // Destroy previous model objects not used anymore (if any)
        // Use previous serialized map to perform the change
        for (k in prevDeserializedMap.keys()) {
            if (!deserializedMap.exists(k)) {
                var item = prevDeserializedMap.get(k);
                if (Std.is(item, Model)) {
                    var _model:Model = cast item;
                    if (_model != model) {
                        _model.destroy();
                    }
                }
            }
        }

        return true;

    } //loadFromData

    public static function autoSaveAsKey(model:Model, key:String, appendInterval:Float = 1.0, compactInterval:Float = 60.0) {

        // Init background queue if needed
        if (backgroundQueue == null) backgroundQueue = new BackgroundQueue();

        if (model.serializer != null) {
            model.serializer.destroy();
            model.serializer = null;
        }

        var serializer = new SerializeModel();
        serializer.checkInterval = appendInterval;
        serializer.compactInterval = compactInterval;

        var saveDataKey1 = 'save_data_1_' + key;
        var saveDataKey2 = 'save_data_2_' + key;
        var saveIdKey1 = 'save_id_1_' + key;
        var saveIdKey2 = 'save_id_2_' + key;

        // Start listening for changes to save them
        serializer.onChangeset(model, function(changeset) {

            if (changeset.append) {
                #if ceramic_debug_save
                trace('Save $key (append ${changeset.data.length})');//: ' + changeset.data);
                #end

                (function(data:String) {
                    backgroundQueue.schedule(function() {

                        // We use and update multiple files to ensure that, in case of crash or any other issue
                        // when writing a file, it will fall back to the other one safely. If anything goes
                        // wrong, there should always be a save file to fall back on.
                        
                        // Append first file
                        app.backend.io.appendString(saveDataKey1, data.length + ':' + data);
                        // Mark this first file as the valid one on first id key
                        app.backend.io.saveString(saveIdKey1, '1');
                        // Mark this first file as the valid one on second id key
                        app.backend.io.saveString(saveIdKey2, '1');

                        // Append second file
                        app.backend.io.appendString(saveDataKey2, data.length + ':' + data);
                        // Mark this second file as the valid one on first id key
                        app.backend.io.saveString(saveIdKey1, '2');
                        // Mark this second file as the valid one on second id key
                        app.backend.io.saveString(saveIdKey2, '2');

                    });
                })(changeset.data);

            } else {
                #if ceramic_debug_save
                trace('Save $key (full ${changeset.data.length})');//: ' + changeset.data);
                #end
                
                (function(data:String) {
                    backgroundQueue.schedule(function() {

                        // We use and update multiple files to ensure that, in case of crash or any other issue
                        // when writing a file, it will fall back to the other one safely. If anything goes
                        // wrong, there should always be a save file to fall back on.

                        // Save first file
                        app.backend.io.saveString(saveDataKey1, data.length + ':' + data);
                        // Mark this first file as the valid one on first id key
                        app.backend.io.saveString(saveIdKey1, '1');
                        // Mark this first file as the valid one on second id key
                        app.backend.io.saveString(saveIdKey2, '1');

                        // Save second file
                        app.backend.io.saveString(saveDataKey2, data.length + ':' + data);
                        // Mark this second file as the valid one on first id key
                        app.backend.io.saveString(saveIdKey1, '2');
                        // Mark this second file as the valid one on second id key
                        app.backend.io.saveString(saveIdKey2, '2');


                    });
                })(changeset.data);
            }

        });

        // Assign component
        model.serializer = serializer;

    } //autoSaveAsKey

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
            var dataPart:String = rawData.substr(colonIndex + 1, len);
            changesetData.push(dataPart);

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
