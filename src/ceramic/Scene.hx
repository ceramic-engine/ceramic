package ceramic;

import ceramic.Shortcuts.*;

typedef SceneData = {

    /** Name to identify the scene. */
    public var name:String;

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

    /** Entity name. */
    public var name:String;

    /** Properties assigned after creating entity. */
    public var props:Dynamic<Dynamic>;

    /** Arbitrary data hold by this item. */
    public var data:Dynamic<Dynamic>;

} //SceneEntities

/** A scene is a group of visuals rendered from data (.scene file) */
class Scene extends Quad {

    public var entities(default,null):Array<Entity>;

/// Lifecycle

    public function new() {

        super();

        entities = [];

    } //new

/// Overrides

    override function set_width(width:Float):Float {
        if (realWidth == width) return width;
        realWidth = width;
        matrixDirty = true;
        return width;
    }

    override function set_height(height:Float):Float {
        if (realHeight == height) return height;
        realHeight = height;
        matrixDirty = true;
        return width;
    }

/// Data

    public function putData(sceneData:SceneData):SceneData {

        if (sceneData != null) {

            name = sceneData.name;
            data = sceneData.data;
            width = sceneData.width;
            height = sceneData.height;

            var usedNames = new Map<String,Bool>();
            if (sceneData.items != null) {
                // Add/Update items
                for (item in sceneData.items) {
                    putItem(item);
                    usedNames.set(item.name, true);
                }

                // Remove unused items
                var toRemove = [];
                for (entity in entities) {
                    if (!usedNames.exists(entity.name)) {
                        toRemove.push(entity.name);
                    }
                }
                for (name in toRemove) {
                    removeItem(name);
                }
            }

        }

        return sceneData;

    } //putData

/// Public API

    public function putItem(item:SceneItem):Entity {

        trace('ADD ITEM');
        var existing = getItem(item.name);
        var existingWasVisual = false;
        
        // Remove previous object if entity class is different
        if (existing != null) {
            existingWasVisual = Std.is(existing, Visual);
            if (item.entity != existing.className()) {
                removeItem(item.name);
                existing = null;
                trace('REMOVE : not same class');
            } else {
                trace('ARE EQUAL: ' + item.entity);
            }
        } else {
            trace('(new item)');
        }

        var entityClass = Type.resolveClass(item.entity);
        var instance:Entity = existing != null ? existing : cast Type.createInstance(entityClass, []);
        instance.name = item.name;

        // Copy item data
        if (item.data != null) {
            if (instance.data != null) instance.data = {};
            for (key in Reflect.fields(item.data)) {
                Reflect.setField(instance.data, key, Reflect.field(item.data, key));
            }
        }

        // Copy item properties
        if (item.props != null) {
            for (field in Reflect.fields(item.props)) {
                if (#if flash untyped (instance).hasOwnProperty ("set_" + field) #elseif js untyped (instance).__properties__ && untyped (instance).__properties__["set_" + field] #else false #end) {
                    Reflect.setProperty(instance, field, Reflect.field(item.props, field));
                }
                else if (Reflect.hasField(instance, field)) {
                    Reflect.setField(instance, field, Reflect.field(item.props, field));
                } else {
                    warning('Entity class ' + item.entity + ' doesn\'t have a property named: $field');
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

    public function getItem(itemName:String):Entity {

        for (entity in entities) {
            if (entity.name == itemName) {
                
                return entity;
            }
        }

        return null;

    } //getItem

    public function removeItem(itemName:String):Void {

        for (entity in entities) {
            if (entity.name == itemName) {
                
                entities.remove(entity);
                entity.destroy();

                break;
            }
        }

    } //removeItem

} //Scene
