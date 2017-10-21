package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

typedef FragmentData = {

    /** Identifier of the fragment. */
    public var id:String;

    /** Arbitrary data hold by this fragment. */
    public var data:Dynamic<Dynamic>;

    /** Fragment width */
    public var width:Float;

    /** Fragment height */
    public var height:Float;

    /** Fragment items (visuals or other entities) */
    @:optional public var items:Array<FragmentItem>;

} //FragmentData

typedef FragmentItem = {

    /** Entity class (ex: ceramic.Visual, ceramic.Quad, ...). */
    public var entity:String;

    /** Entity identifier. */
    public var id:String;

    /** Properties assigned after creating entity. */
    public var props:Dynamic<Dynamic>;

    /** Arbitrary data hold by this item. */
    public var data:Dynamic<Dynamic>;

} //FragmentEntities

/** A fragment is a group of visuals rendered from data (.fragment file) */
class Fragment extends Quad {

    public var entities(default,null):Array<Entity>;

    public var deserializers:Map<String,Fragment->Entity->FragmentItem->Void> = new Map();

/// Lifecycle

    public function new() {

        super();

        entities = [];

    } //new

/// Data

    public function putData(fragmentData:FragmentData):FragmentData {

        if (fragmentData != null) {

            id = fragmentData.id;
            data = fragmentData.data;
            width = fragmentData.width;
            height = fragmentData.height;

            var usedIds = new Map<String,Bool>();
            if (fragmentData.items != null) {
                // Add/Update items
                for (item in fragmentData.items) {
                    putItem(item);
                    usedIds.set(item.id, true);
                }

                // Remove unused items
                var toRemove = [];
                for (entity in entities) {
                    if (!usedIds.exists(entity.id)) {
                        toRemove.push(entity.id);
                    }
                }
                for (id in toRemove) {
                    removeItem(id);
                }
            }

        }

        return fragmentData;

    } //putData

/// Public API

    public function putItem(item:FragmentItem):Entity {

        var existing = getItem(item.id);
        var existingWasVisual = false;
        
        // Remove previous object if entity class is different
        if (existing != null) {
            existingWasVisual = Std.is(existing, Visual);
            if (item.entity != Type.getClassName(Type.getClass(existing))) {
                removeItem(item.id);
                existing = null;
            }
        }

        var entityClass = Type.resolveClass(item.entity);
        var instance:Entity = existing != null ? existing : cast Type.createInstance(entityClass, []);
        instance.id = item.id;

        // Copy item data
        if (item.data != null) {
            for (key in Reflect.fields(item.data)) {
                Reflect.setField(instance.data, key, Reflect.field(item.data, key));
            }
        }

        // Copy item properties
        var deserialize = deserializers.get(item.entity);
        if (deserialize != null) {
            deserialize(this, instance, item);
        }
        else {
            if (item.props != null) {
                for (field in Reflect.fields(item.props)) {
                    instance.setProperty(field, Reflect.field(item.props, field));
                }
            }
        }

        // Add instance (if new)
        if (existing == null) {
            entities.push(instance);
        }
        // Add it to display tree if it is a visual
        if (Std.is(instance, Visual) && !existingWasVisual) {
            add(cast instance);
        }

        return instance;

    } //putItem

    public function getItem(itemId:String):Entity {

        for (entity in entities) {
            if (entity.id == itemId) {
                
                return entity;
            }
        }

        return null;

    } //getItem

    public function removeItem(itemId:String):Void {

        for (entity in entities) {
            if (entity.id == itemId) {
                
                entities.remove(entity);
                entity.destroy();

                break;
            }
        }

    } //removeItem

    public function removeAllItems():Void {

        for (entity in entities) {
                
            entities.remove(entity);
            entity.destroy();

        }

    } //removeAllItems

} //Fragment
