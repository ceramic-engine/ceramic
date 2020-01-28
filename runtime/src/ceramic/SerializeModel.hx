package ceramic;

import ceramic.Assert.*;
import ceramic.Shortcuts.*;

/** Utility to serialize a model object (and its children) continuously and efficiently */
class SerializeModel extends Entity implements Component {

/// Events

    /** Triggered when serialized data is updated.
        If `append` is true, the given string should be appended to the existing one. */
    @event function changeset(changeset:SerializeChangeset);

/// Settings

    public var checkInterval:Float = 1.0;

    public var compactInterval:Float = 60.0;

    public var destroyModelOnUntrack:Bool = true;

/// Properties

    public var serializedMap(default,null):Map<String,{ id:String, type:String, props:Dynamic }> = new Map();

    public var model(get,null):Model;
    inline function get_model():Model return entity;

    var entity:Model;

/// Lifecycle

    function bindAsComponent() {

        // Synchronize with real data at regular interval
        Timer.interval(this, checkInterval, synchronize);

        // Compact at regular interval
        Timer.interval(this, compactInterval, compactIfNeeded);

        // Track root model
        track(model);

        // Perform first compaction to get initial data
        compact();

    }

/// Public API

    /** Recompute the whole object tree instead of appending. This will untrack every object not on the model anymore
        and generate a new changeset with the whole serialized object tree. */
    public function compact(?done:String->Void):Void {

        var prevSerializedMap = serializedMap;

        Serialize._serializedMap = new Map();
        Serialize._onAddSerializable = function(serializable:Serializable) {

            if (Std.is(serializable, Model)) {
                var model:Model = cast serializable;
                model.observedDirty = false;
                track(model);
            }

        };

        var serialized = Serialize.serializeValue(model);

        serializedMap = Serialize._serializedMap;

        Serialize._onAddSerializable = null;
        Serialize._serializedMap = null;

        cleanTrackingFromPrevSerializedMap(prevSerializedMap);

        var s = new haxe.Serializer();
        s.serialize(serialized);
        s.serialize(serializedMap);
        var data = s.toString();

        // Emit full changeset
        emitChangeset({ data: data, append: false });

        // Call done() callback if provided
        if (done != null) done(data);

    }

/// Internal

    var trackedModels:Map<String,Model> = new Map();

    var willCleanDestroyedTrackedModels:Bool = false;

    var dirtyModels:Map<String,Model> = new Map();

    var canCompact = false;

    var dirty:Bool = true;

    inline function track(model:Model) {

        if (!model.destroyed && !trackedModels.exists(model._serializeId)) {
            trackedModels.set(model._serializeId, model);
            model.onModelDirty(this, explicitModelDirty);
            model.onObservedDirty(this, modelDirty);
            model.onceDestroy(this, trackedModelDestroyed);
        }

    }

    inline function untrack(model:Model) {

        if (trackedModels.exists(model._serializeId)) {
            trackedModels.remove(model._serializeId);
            model.offModelDirty(explicitModelDirty);
            model.offObservedDirty(modelDirty);
            model.offDestroy(trackedModelDestroyed);
            if (destroyModelOnUntrack) {
                model.destroy();
            }
        }

    }

    function trackedModelDestroyed(_) {

        if (willCleanDestroyedTrackedModels) return;
        willCleanDestroyedTrackedModels = true;
        
        app.onceImmediate(function() {

            var keys = [];
            for (key in trackedModels.keys()) {
                keys.push(key);
            }
            for (key in keys) {
                var model = trackedModels.get(key);
                if (model.destroyed) {
                    untrack(model);
                }
            }

            willCleanDestroyedTrackedModels = false;
        });

    }

    function cleanTrackingFromPrevSerializedMap(prevSerializedMap:Map<String,{ id:String, type:String, props:Dynamic }>) {

        var removedIds = [];

        for (key in prevSerializedMap.keys()) {
            if (!serializedMap.exists(key)) {
                removedIds.push(key);
            }
        }

        for (key in removedIds) {
            var model = trackedModels.get(key);
            if (model != null) {
                untrack(model);
            }
        }

    }

    function modelDirty(model:Model, fromSerializedField:Bool) {

        if (!fromSerializedField) {
            // If the observed object got dirty from a non-serialized field,
            // there is nothing to do. Just mark the model as `clean` and wait
            // for the next change.
            model.observedDirty = false;
            return;
        }

        dirtyModels.set(model._serializeId, model);
        dirty = true;

    }

    function explicitModelDirty(model:Model) {

        dirtyModels.set(model._serializeId, model);
        dirty = true;

    }

    /** Synchronize at regular interval */
    public function synchronize() {

        if (!dirty) return;
        dirty = false;

        var toAppend = [];
        for (id in dirtyModels.keys()) {
            var model = dirtyModels.get(id);
            if (!model.destroyed && trackedModels.exists(model._serializeId)) {
                model.dirty = false;
                serializeModel(model, toAppend);
            }
        }
        dirtyModels = new Map();

        if (toAppend.length > 0) {
            var s = new haxe.Serializer();
            s.serialize(toAppend);
            var data = s.toString();

            // Can compact
            canCompact = true;

            // Emit changeset
            emitChangeset({ data: data, append: true });
        }

    }

    function compactIfNeeded() {

        if (canCompact) {
            canCompact = false;
            compact();
        }

    }

    inline function serializeModel(model:Model, toAppend:Array<{ id:String, type:String, props:Dynamic }>) {

        // Remove model from map to ensure it is re-serialized
        serializedMap.remove(model._serializeId);
        
        Serialize._serializedMap = serializedMap;
        Serialize._onCheckSerializable = function(serializable:Serializable) {

            var id = serializable._serializeId;
            var model = trackedModels.get(id);

            if (model != null) {
                if (model != serializable) {
                    // Replacing object with same id
                    serializedMap.remove(id);
                }
            }

        };
        Serialize._onAddSerializable = function(serializable:Serializable) {

            if (Std.is(serializable, Model)) {

                var model:Model = cast serializable;
                model.observedDirty = false;
                toAppend.push(serializedMap.get(model._serializeId));

                track(model);
            }

        };

        Serialize.serializeValue(model);

        Serialize._onCheckSerializable = null;
        Serialize._onAddSerializable = null;
        Serialize._serializedMap = null;

    }

}
