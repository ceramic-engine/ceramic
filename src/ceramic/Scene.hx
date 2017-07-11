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

    /** Scene x */
    public var x:Float;

    /** Scene y */
    public var y:Float;

    /** Scene anchorX */
    public var anchorX:Float;

    /** Scene anchorY */
    public var anchorY:Float;

    /** Scene items (visuals or other entities) */
    public var items:Array<SceneItem>;

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

    public var sceneData(default,set):SceneData;

    public var entities(default,null):Array<Entity>;

/// Lifecycle

    public function new() {

        super();

        entities = [];

    } //new

    override function clear():Void {

        super.clear();

        for (entity in entities) {
            entity.destroy();
        }
        entities = [];

    } //clear

/// Data

    function set_sceneData(sceneData:SceneData):SceneData {

        clear();
        this.sceneData = sceneData;

        if (sceneData != null) {

            name = sceneData.name;
            data = sceneData.data;
            width = sceneData.width;
            height = sceneData.height;
            x = sceneData.x;
            y = sceneData.y;
            anchorX = sceneData.anchorX;
            anchorY = sceneData.anchorY;

            if (sceneData.items != null) {
                for (item in sceneData.items) {

                    addItem(item);

                }
            }

        }

        return sceneData;

    } //set_sceneData

/// Public API

    public function addItem(item:SceneItem):Void {

        trace('ADD ITEM');
        trace(item);

        var entityClass = Type.resolveClass(item.entity);
        var instance:Entity = cast Type.createInstance(entityClass, []);
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

        // Add instance
        entities.push(instance);
        if (Std.is(instance, Visual)) {
            add(cast instance);
        }

    } //addItem

    public function removeItem(itemName:String):Void {

        for (entity in entities) {
            if (entity.name == itemName) {
                
                entities.remove(entity);

                if (Std.is(entity, Visual)) {
                    remove(cast entity);
                }

                break;
            }
        }

    } //removeItem

} //Scene
