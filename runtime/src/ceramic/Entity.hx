package ceramic;

import haxe.rtti.Meta;

#if !macro
@:autoBuild(ceramic.macros.EntityMacro.build())
#end
class Entity implements Events implements Lazy {

/// Properties

    @lazy public var data:Dynamic<Dynamic> = {};

    public var id:String = null;

    public var destroyed:Bool = false;

/// Events

    @event function destroy();

/// Lifecycle

    public function destroy():Void {

        if (destroyed) return;
        destroyed = true;

        emitDestroy();

        // Destroy each linked component
        if (components != null) {
            for (name in components.keys()) {
                removeComponent(name);
            }
        }

    } //destroy

/// Print

    public function className():String {

        var className = Type.getClassName(Type.getClass(this));
        var dotIndex = className.lastIndexOf('.');
        if (dotIndex != -1) className = className.substr(dotIndex + 1);
        return className;

    } //className

    function toString():String {

        var className = className();

        if (id != null) {
            return '$className($id)';
        } else {
            return '$className';
        }

    } //toString

/// Components

    var components:Map<String,Component> = null;

    public function component(name:String, ?component:Component):Component {

        if (component != null) {
            if (components == null) {
                components = new Map();
            }
            else {
                var existing = components.get(name);
                if (existing != null) {
                    existing.destroy();
                }
            }
            components.set(name, component);
            Reflect.setField(component, 'entity', this);
            component.onceDestroy(this, function() {
                if (Reflect.field(component, 'entity') == this) {
                    Reflect.setField(component, 'entity', null);
                }
            });
            @:privateAccess component.init();
            return component;

        } else {
            if (components == null) return null;
            return components.get(name);
        }

    } //component

    public function hasComponent(name:String):Bool {

        return component(name) != null;

    } //hasComponent

    public function removeComponent(name:String):Void {

        var existing = components.get(name);
        if (existing != null) {
            components.remove(name);
            existing.destroy();
        }

    } //removeComponent

/// Helpers

    static var entityFieldInfoMap:Map<String,Map<String,String>> = new Map();

    static var editableFieldInfoMap:Map<String,Map<String,{type:String, meta:Dynamic}>> = new Map();

    public static function entityFieldTypes(entityClass:String):Map<String,String> {

        var info = entityFieldInfoMap.get(entityClass);

        if (info == null) {
            info = new Map();
            entityFieldInfoMap.set(entityClass, info);

            var clazz = Type.resolveClass(entityClass);
            var usedFields = new Map();

            while (clazz != null) {

                var meta = Meta.getFields(clazz);
                for (k in Reflect.fields(meta)) {
                    var v = Reflect.field(meta, k);
                    if (Reflect.hasField(v, 'type') && !usedFields.exists(k)) {
                        usedFields.set(k, true);
                        info.set(k, v.type);
                    }
                }

                clazz = Type.getSuperClass(clazz);

            }
        }

        return info;

    } //entityFieldTypes

#if editor

    public static function editableFieldInfo(entityClass:String):Map<String,{type:String, meta:Dynamic}> {

        var info = editableFieldInfoMap.get(entityClass);

        if (info == null) {
            info = new Map();
            editableFieldInfoMap.set(entityClass, info);

            var clazz = Type.resolveClass(entityClass);
            var usedFields = new Map();

            while (clazz != null) {

                var meta = Meta.getFields(clazz);
                for (k in Reflect.fields(meta)) {
                    var v = Reflect.field(meta, k);
                    if (Reflect.hasField(v, 'editable') && !usedFields.exists(k)) {
                        usedFields.set(k, true);
                        info.set(k, {
                            type: v.type,
                            meta: v
                        });
                    }
                }

                clazz = Type.getSuperClass(clazz);

            }
        }

        return info;

    } //editableFieldTypes

#end

    public static function typeOfEntityField(entityClass:String, field:String):String {

        return entityFieldTypes(entityClass).get(field);

    } //typeOfField

/// Field converters

    static var converters:Map<String,ConvertField<Dynamic,Dynamic>> = new Map();

} //Entity
