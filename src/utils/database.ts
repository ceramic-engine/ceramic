import { serializeModel, deserializeModelInto, typeForSerialized, Entry, Serialized } from './serialize';
import Model from './Model';
import uuid from './uuid';
import { spy, isObservableArray, isObservableMap } from 'mobx';
import autobind from 'autobind-decorator';
import { HistoryListener, HistoryItem, history } from './history';

export class Database implements HistoryListener {

    entries:{ [key: string]: Entry } = {};

    creating:boolean = false;

    create<T extends Model>(type:new(id?:string) => T, id?:string):T {

        this.creating = true;

        // Look for type overrides
        if (id != null) {
            let serialized = this.getSerialized(id);
            if (serialized != null) {
                let embeddedType = typeForSerialized(serialized);
                if (embeddedType != null) type = embeddedType;
            }
        }

        const instance = new type(id != null ? id : uuid());
        let entry = this.entries[instance.id];

        if (entry == null) {

            entry = {
                serialized: null,
                instance: null
            };

        }

        entry.instance = instance;

        this.creating = false;

        return instance;

    } //create

    get<T extends Model>(type:new(id?:string) => T, id:string, recursive:boolean = false):T|null {

        let instance = null;
        let entry = this.entries[id];

        if (entry != null) {

            if (entry.instance != null) {
                instance = entry.instance;
            }
            else if (entry.serialized != null) {
                instance = this.create(type, id);
                entry.instance = instance;
                this.extract(instance, recursive);
            }

        }

        return instance as T;

    } //get

    getSerialized(id:string):Serialized {

        let serialized = null;
        let entry = this.entries[id];

        if (entry != null) {

            if (entry.serialized != null) {
                serialized = entry.serialized;
            }

        }

        return serialized;

    } //getSerialized

    getOrCreate<T extends Model>(type:new(id?:string) => T, id:string, recursive:boolean = false):T {

        let existing = this.get(type, id, recursive);
        if (existing != null) {
            return existing;
        }

        return this.create(type, id);

    } //getOrCreate

    put<T extends Model>(instance:T, serialized?:Serialized, recursive:boolean = false):void {

        if (serialized == null) {

            let options = recursive ? {
                recursive: true,
                entries: this.entries
            } : undefined;

            serialized = serializeModel(instance, options);
        }

        if (serialized.id == null) {
            throw "Missing serialized object id";
        }

        let existing = this.entries[serialized.id];
        let entry = existing != null ? existing : {
            serialized: null,
            instance: null
        };

        entry.instance = instance;
        entry.serialized = serialized;

        if (existing == null) {
            this.entries[instance.id] = entry;
        }

    }

    putSerialized(serialized:Serialized, updateInstance:boolean = true):void {

        if (serialized.id == null) {
            throw "Missing serialized object id";
        }

        let existing = this.entries[serialized.id];
        let entry = existing != null ? existing : {
            serialized: null,
            instance: null
        };

        entry.serialized = serialized;

        if (existing == null) {
            this.entries[serialized.id] = entry;
        }
        
        if (entry.instance != null && updateInstance) {
            this.extract(entry.instance, true);
        }

    }

    extract<T extends Model>(instance:T, recursive:boolean = false):void {

        let existing = this.entries[instance.id];
        let serialized = undefined;
        if (existing != null) {
            serialized = existing.serialized;
        }

        let options = recursive ? {
            recursive: recursive,
            entries: this.entries
        } : undefined;

        deserializeModelInto(serialized, instance, options);

    } //extract

/// History

    @autobind onHistoryUndo(item:HistoryItem):void {

        let undoData:{ [key: string]: any } = item.undo;

        for (let key in undoData) {
            this.putSerialized(undoData[key], true);
        }

    } //onHistoryUndo

    @autobind onHistoryRedo(item:HistoryItem):void {

        let redoData:{ [key: string]: any } = item.do;

        for (let key in redoData) {
            this.putSerialized(redoData[key], true);
        }

    } //onHistoryRedo

/// Clean

    /** Clean unused objects */
    clean(deep:boolean = false) {
        
        // Add root entries, first
        let cleaned:{ [key: string]: Entry } = {};
        let toWalk:Array<Model> = [];
        for (let kept of Model.rootInstances) {
            let entry = this.entries[kept.id];
            if (entry) {
                cleaned[kept.id] = entry;
            }
            toWalk.push(kept);
        }

        // Then for each root instance, walk properties to find sub-models
        let walked:Map<string, boolean> = new Map();
        while (toWalk.length > 0) {
            let instance = toWalk.shift();
            walked.set(instance.id, true);

            // Walk instance properties
            for (let key in instance) {
                if (instance.hasOwnProperty(key)) {
                    let val = instance[key];
                    if (val != null) {

                        if (val instanceof Model) {
                            if (!walked.has(val.id)) {
                                walked.set(val.id, true);
                                let entry = this.entries[val.id];
                                if (entry) {
                                    cleaned[val.id] = entry;
                                }
                                toWalk.push(val);
                            }
                        }
                        else if (Array.isArray(val) || isObservableArray(val)) {
                            val.forEach((v, i) => {
                                if (v instanceof Model) {
                                    if (!walked.has(v.id)) {
                                        walked.set(v.id, true);
                                        let entry = this.entries[v.id];
                                        if (entry) {
                                            cleaned[v.id] = entry;
                                        }
                                        toWalk.push(v);
                                    }
                                }
                            });
                        }
                        else if (val instanceof Map || isObservableMap(val)) {
                            (val as Map<string, any>).forEach((v, k) => {
                                if (v instanceof Model) {
                                    if (!walked.has(v.id)) {
                                        walked.set(v.id, true);
                                        let entry = this.entries[v.id];
                                        if (entry) {
                                            cleaned[v.id] = entry;
                                        }
                                        toWalk.push(v);
                                    }
                                }
                            });
                        }
                    }
                }
            }
        }

        // Remove unused entries
        let allIds = [];
        for (let key in this.entries) {
            if (this.entries.hasOwnProperty(key)) {
                allIds.push(key);
            }
        }
        for (let key of allIds) {
            if (!cleaned[key]) {
                if (deep) {
                    delete this.entries[key];
                } else {
                    this.entries[key].instance = undefined;
                }
            }
        }

    } //clean

/// Storage

    save() {

        // Clean before save
        this.clean(false);

        // Create json string to save
        let saved:{ [key: string]: Entry } = {};
        for (let key in this.entries) {
            // Only save entries that still have an instance (still existing after clean)
            if (this.entries.hasOwnProperty(key) && this.entries[key].instance) {
                saved[key] = {
                    serialized: this.entries[key].serialized,
                    instance: null
                };
            }
        }
        localStorage.setItem('ceramic-editor-db', JSON.stringify(saved));

    } //save

    load() {

        let json = localStorage.getItem('ceramic-editor-db');
        if (json) {
            this.entries = JSON.parse(json);
            console.log(JSON.parse(json));
        } else {
            console.warn('Nothing to load in db.');
        }

    } //load

} //Database

// Shared database instance
export const db = new Database();

// Track actions and invalidate models from it
let handledEvents = {
    update: true,
    splice: true,
    add: true,
    delete: true,
    create: true
};
let dirty = new Set<Model>();
let willClean = false;
function addDirty(model:Model) {

    // Stack dirty objects and serialize everything at the end of the roadloop
    dirty.add(model);
    if (!willClean) {
        willClean = true;
        setImmediate(() => {

            willClean = false;

            // Fill array of items
            let items:Array<Model> = [];
            dirty.forEach((item:Model) => {
                items.push(item);
            });
            dirty.clear();

            // Serialize items and put them in db
            let newSerialized:{ [key: string]: any } = {};
            let prevSerialized:{ [key: string]: any } = {};
            for (let item of items) {
                let serialized = serializeModel(item);
                newSerialized[item.id] = serialized;
                prevSerialized[item.id] = db.getSerialized(item.id);
                db.put(item, serialized, false);
            }

            // Add history item
            if (!history.doing) {
                history.push({
                    do: newSerialized,
                    undo: prevSerialized
                });
            }

            // Save on change
            // TODO find another solution?
            db.save();
            
        });
    }
}
spy((event) => {

    if (!history.doing && history.pauses === 0 && handledEvents[event.type] && event.object != null) {
        if (event.object instanceof Model && event.name != null) {

            // Serialize only if the changed value is a serializable one
            if (Reflect.hasMetadata(
                'serialize:type',
                event.object.constructor.prototype,
                event.name)) {

                // Add parent model as property to observable array/map
                // in order to invalidate model when array/map changes
                if (event.newValue != null && (isObservableArray(event.newValue) || isObservableMap(event.newValue))) {
                    event.newValue['_parentModel'] = event.object;
                }

                addDirty(event.object);
            }
        }
        else if (event.object['_parentModel'] != null) {

            // Observable Map or Array in model changed
            addDirty(event.object['_parentModel']);

        }
    }

});
