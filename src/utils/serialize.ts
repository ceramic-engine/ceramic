import Model from './Model';
import { isObservableArray, isObservableMap } from 'mobx';

export type Serialized = any;

export interface Entry {

    serialized:Serialized|null;

    instance:Model|null;

}

export interface SerializeOptions {

    recursive?:boolean;

    entries?:{ [key: string]: Entry };

    exclude?:Array<string>;

}

export interface DeserializeOptions {

    recursive?:boolean;

    entries?:{ [key: string]: Entry };

}

export const modelTypes:Map<string, any> = new Map();

export function registerModel(modelType:any) {

    modelTypes.set(modelType.name, modelType);

} //registerModel

/** An utility to serialize a value */
export function serializeValue(value:any, options?:SerializeOptions):any {

    if (value == null) {
        return null;
    }
    else if (Array.isArray(value)) {
        let result = [];
        for (let val of value) {
            result.push(serializeValue(val, options));
        }
        return result;
    }
    else if (isObservableArray(value)) {
        let result = [];
        for (let val of value.slice()) {
            result.push(serializeValue(val, options));
        }
        return result;
    }
    else if (value instanceof Model) {
        if (options != null && options.recursive) {

            if (options.entries != null) {
                let entry = options.entries[value.id];
                if (entry == null) {
                    entry = { serialized: null, instance: value };
                    options.entries[value.id] = entry;
                }
                else if (entry.instance !== value) {
                    entry.instance = value;
                }
            }

            let serialized = serializeModel(value, options);
            if (options.entries != null) {
                let entry = options.entries[value.id];
                entry.serialized = serialized;
                return value.id;
            } else {
                return serialized;
            }

        } else {
            return value.id;
        }
    }
    else if (value instanceof Map || isObservableMap(value)) {
        let result:any = {};
        (value as Map<string, any>).forEach((val, key) => {
            result[key] = serializeValue(val, options);
        });
        return result;
    }
    else if (typeof(value) === 'object') {
        let result:any = {};
        for (let key in value) {
            if (value.hasOwnProperty(key)) {
                result[key] = serializeValue(value[key], options);
            }
        }
        return result;
    }
    else {
        return value;
    }

} //serializeValue

export function serializeModel<T extends Model>(instance:T, options?:SerializeOptions):any {

    let serialized:any = {};
    let exclude:Map<string, boolean> = null;
    if (options != null && options.exclude != null) {
        exclude = new Map();
        for (let excludeItem of options.exclude) {
            exclude.set(excludeItem, true);
        }
    }

    for (let propertyName in instance) { // TODO use decorator info
        if (instance.hasOwnProperty(propertyName) && (exclude == null || !exclude.has(propertyName))) {

            if (Reflect.hasMetadata('serialize:type', instance.constructor.prototype, propertyName)) {
                serialized[propertyName] = serializeValue(instance[propertyName], options);
            }
        }
    }

    if ((exclude == null || !exclude.has('_model'))
        && modelTypes.has(instance.constructor.name)
        && modelTypes.get(instance.constructor.name) === instance.constructor) {
        serialized._model = instance.constructor.name;
    }

    return serialized;

} //serializeModel

export function deserializeValue(value:any, type:any, options?:DeserializeOptions):any {

    let typeParam;
    if (Array.isArray(type) && type.length === 2) {
        typeParam = type[1];
        type = type[0];
    }

    if (type == null) {
        if (typeof(value) === 'string') {
            return value;
        } else if (typeof(value) === 'number') {
            return value;
        } else if (typeof(value) === 'boolean') {
            return value;
        } else {
            return null;
        }
    }
    else if (value == null) {
        return null;
    }
    else if (type === String) {
        return value;
    }
    else if (type === Number) {
        return value;
    }
    else if (type === Boolean) {
        return value;
    }
    else if (type === Array) {
        let result = [];
        let list:Array<any> = value;
        for (let val of list) {
            result.push(deserializeValue(val, typeParam, options));
        }
        return result;
    }
    else if (type === Model || type.prototype instanceof Model) {

        if (options != null && options.recursive) {
            let id:string;
            let serialized:any = null;
            if (typeof(value) === 'object' && value.id != null) {
                // Serialized model nested in object tree
                id = value.id;
                serialized = value;
            } else {
                // Serialized model provided in options.entries
                id = value;
                if (options.entries != null) {
                    let entry = options.entries[id];
                    if (entry != null) {
                        serialized = entry.serialized;
                    }
                }
            }

            if (id != null) {
                if (options.entries != null) {
                    let entry = options.entries[id];
                    if (entry != null && entry.instance != null) {
                        return entry.instance;
                    }
                }
                if (serialized != null) {

                    // Override type, if provided by serialized object
                    if (typeof(serialized._model) === 'string' && modelTypes.has(serialized._model)) {
                        type = modelTypes.get(serialized._model);
                    }

                    let instance = new type(id);
                    deserializeModelInto(serialized, instance, options);
                    if (options.entries != null) {
                        options.entries[id] = {
                            instance: instance,
                            serialized: serialized
                        };
                    }
                    return instance;
                }
            }
            return undefined;
        }
        else {
            return undefined;
        }
    }
    else if (type === Map) {
        let result:Map<string, any> = new Map();
        for (let key in value) {
            if (value.hasOwnProperty(key)) {
                result.set(key, deserializeValue(value[key], typeParam, options));
            }
        }
        return result;
    }
    else if (type === Object) {
        let result:any = {};
        for (let key in value) {
            if (value.hasOwnProperty(key)) {
                result[key] = deserializeValue(value[key], typeParam, options);
            }
        }
        return result;
    }

    return undefined;

} //deserializeValue

export function deserializeModel<T extends Model>(
    serialized:any, type:new(id:string) => T, options?:DeserializeOptions):T|null {

    if (serialized == null || serialized.id == null) return null;

    let instance = new type(serialized.id);
    deserializeModelInto(serialized, instance, options);

    return instance;

} //deserializeModel

export function deserializeModelInto<T extends Model>(serialized:any, instance:T, options?:DeserializeOptions):void {

    const recursive = (options != null && options.recursive);

    for (let propertyName in serialized) {
        if (serialized.hasOwnProperty(propertyName)) {

            // Get property type
            const type = Reflect.getMetadata('serialize:type', instance.constructor.prototype, propertyName);
            if (type != null) {
                if (!recursive && (type === Model || type.prototype instanceof Model)) {
                    // When deserialize is not recursive,
                    // still try to keep existing sub-models referenced
                    let existing:Model = instance[propertyName];
                    if (existing != null) {
                        let value = serialized[propertyName];
                        let id:string = (typeof(value) === 'object' && value.id != null) ? value.id : value;
                        if (id !== existing.id) {
                            instance[propertyName] = undefined;
                        }
                    } else {
                        instance[propertyName] = null;
                    }
                } else {
                    instance[propertyName] = deserializeValue(serialized[propertyName], type, options);
                }
            }

        }
    }

} //deserializeModelInto
