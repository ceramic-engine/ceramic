package ceramic;

import ceramic.Shortcuts.*;
import ceramic.Assert.*;

class SaveModel {

    static var BACKUP_NUM_STEPS:Int = 20000;

    static var NUM_BACKUPS:Int = 4;

    static var BACKUP_STEPS:Array<Int> = null;

    static var backupStepByKey:Map<String,Int> = null;

    static var busyKeys:Array<String> = [];

    static var backgroundQueue:BackgroundQueue = null;

/// Public API

    public static function getSavedOrCreate<T:Model>(modelClass:Class<T>, key:String, ?args:Array<Dynamic>):T {

        // Create new instance
        var instance = Type.createInstance(modelClass, args != null ? args : []);

        // Load saved data
        loadFromKey(instance, key);

        return instance;

    } //modelClass

    /** Load data from the given key. */
    public static function loadFromKey(model:Model, key:String):Bool {

        if (busyKeys.indexOf(key) != -1) {
            throw 'Cannot load data from key $key because some work is being done on it';
        }

        initBackupLogicIfNeeded(key);

        var rawId = app.backend.io.readString('save_id_1_' + key);
        var id = rawId != null ? Std.parseInt(rawId) : -1;
        if (id != 1 && id != 2) {
            rawId = app.backend.io.readString('save_id_2_' + key);
            id = rawId != null ? Std.parseInt(rawId) : -1;
        }

        var data:String = null;

        if (id != 1 && id != 2) {
            log.warning('Failed to load save from key: $key (no existing save?)');
        }
        else {
            data = app.backend.io.readString('save_data_' + id + '_' + key);
            if (data == null) {
                log.warning('Failed to load save from key: $key/$id (corrupted save, try backups?)');
            }
        }

        if (data == null) {
            data = fetchMostRecentBackup(key);
            if (data == null) {
                log.warning('No backup available for key $key, that is probably a new save slot.');
            }
            else {
                log.success('Recovered from backup!');
            }
        }

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

        // Init backup logic if needed
        initBackupLogicIfNeeded(key);

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

            // Mark this key as busy
            busyKeys.push(key);

            if (changeset.append) {

                // Append
                //
                #if ceramic_debug_save
                trace('Save $key (append ${changeset.data.length})');//: ' + changeset.data);
                #end

                (function(data:String, key:String) {
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

                        Runner.runInMain(function() {
                            // Pop busy key
                            var busyIndex = busyKeys.indexOf(key);
                            if (busyIndex != -1) {
                                busyKeys.splice(busyIndex, 1);
                            }
                            else {
                                log.error('Failed to remove busy key: $key (none in list)');
                            }
                        });

                    });
                })(changeset.data, key);

            } else {

                // Compact
                //
                #if ceramic_debug_save
                trace('Save $key (full ${changeset.data.length})');//: ' + changeset.data);
                #end

                var backupStep = backupStepByKey.get(key);
                var backupId = BACKUP_STEPS[backupStep];
                
                (function(data:String, key:String, backupStep:Int, backupId:Int) {
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

                        // Save a backup on compact
                        // That file will be used at load if we fail to load the regular one
                        app.backend.io.saveString('backup_data_' + backupId + '_' + key, Math.round(Date.now().getTime()) + ':' + data.length + ':' + data);

                        // Increment backup step
                        backupStep = (backupStep + 1) % BACKUP_NUM_STEPS;

                        // Update backup step on disk
                        app.backend.io.saveString('backup_step_1_' + key, '' + backupStep);
                        app.backend.io.saveString('backup_step_2_' + key, '' + backupStep);

                        Runner.runInMain(function() {

                            // Update backup step in map
                            backupStepByKey.set(key, backupStep);

                            // Pop busy key
                            var busyIndex = busyKeys.indexOf(key);
                            if (busyIndex != -1) {
                                busyKeys.splice(busyIndex, 1);
                            }
                            else {
                                log.error('Failed to remove busy key: $key (none in list)');
                            }
                        });
                        

                    });
                })(changeset.data, key, backupStep, backupId);
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

    static function initBackupLogicIfNeeded(key:String):Void {

        if (backupStepByKey == null) {
            backupStepByKey = new Map();

            BACKUP_STEPS = Utils.uniformFrequencyList(
                [1, 2, 3, 4],
                [
                    0.5 - 20.0 / BACKUP_NUM_STEPS - 2.0 / BACKUP_NUM_STEPS,
                    0.5 - 20.0 / BACKUP_NUM_STEPS - 2.0 / BACKUP_NUM_STEPS,
                    20.0 / BACKUP_NUM_STEPS,
                    2.0 / BACKUP_NUM_STEPS
                ],
                BACKUP_NUM_STEPS
            );
        }
        
        if (!backupStepByKey.exists(key)) {

            var rawStep = app.backend.io.readString('backup_step_1_' + key);
            var step = rawStep != null ? Std.parseInt(rawStep) : -1;
            if (step == null || Math.isNaN(step) || step < 0 || step >= BACKUP_NUM_STEPS) {
                rawStep = app.backend.io.readString('backup_step_2_' + key);
                step = rawStep != null ? Std.parseInt(rawStep) : -1;
            }

            if (step == null || Math.isNaN(step) || step < 0 || step >= BACKUP_NUM_STEPS) {
                log.warning('No backup step saved, start with zero');
                step = 0;
            }

            backupStepByKey.set(key, step);
        }

    } //initBackupLogicIfNeeded

    static function fetchMostRecentBackup(key:String):String {

        var backups:Array<String> = [];
        var times:Array<Float> = []; 

        for (backupId in 0...4) {
            var backup = app.backend.io.readString('backup_data_' + backupId + '_' + key);

            if (backup != null) {
                // Extract time and data
                var colonIndex = backup.indexOf(':');
                if (colonIndex != -1) {
                    var rawTime = backup.substring(0, colonIndex);
                    var time:Null<Float> = Std.parseFloat(rawTime);
                    if (time != null && !Math.isNaN(time) && time > 0) {
                        backups.push(backup.substring(colonIndex + 1));
                        times.push(time);
                    }
                }
            } 
        }

        var bestTime:Float = -1;
        var bestIndex:Int = -1;

        // Find most rencent backup among every loaded backup
        for (i in 0...times.length) {
            var time = times[i];
            if (time > bestTime) {
                bestTime = time;
                bestIndex = i;
            }
        }

        if (bestIndex != -1) {
            // Found one!
            return backups[bestIndex];
        }
        else {
            // No backup available
            return null;
        }

    } //fetchMostRecentBackup

} //SaveModel
