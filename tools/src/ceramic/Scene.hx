package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

typedef SceneData = {

    /** Identifier of the scene. */
    public var id:String;

    /** Arbitrary data hold by this scene. */
    public var data:Dynamic<Dynamic>;

    /** Scene width */
    public var width:Float;

    /** Scene height */
    public var height:Float;

    /** Scene items (visuals or other entities) */
    @:optional public var items:Array<SceneItem>;

} //SceneData

typedef SceneItem = {

    /** Entity class (ex: ceramic.Visual, ceramic.Quad, ...). */
    public var entity:String;

    /** Entity identifier. */
    public var id:String;

    /** Properties assigned after creating entity. */
    public var props:Dynamic<Dynamic>;

    /** Arbitrary data hold by this item. */
    public var data:Dynamic<Dynamic>;

} //SceneEntities

/** A scene is a group of visuals rendered from data (.scene file) */
class Scene extends Quad {

    public var entities(default,null):Array<Entity>;

    public var deserializers:Map<String,Scene->Entity->SceneItem->Void> = new Map();

/// Lifecycle

    public function new() {

        super();

        entities = [];

    } //new

/// Data

    public function putData(sceneData:SceneData):SceneData {

        if (sceneData != null) {

            id = sceneData.id;
            data = sceneData.data;
            width = sceneData.width;
            height = sceneData.height;

            var usedIds = new Map<String,Bool>();
            if (sceneData.items != null) {
                // Add/Update items
                for (item in sceneData.items) {
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

        return sceneData;

    } //putData

/// Public API

    public function putItem(item:SceneItem):Entity {

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

} //Scene
