package ceramic;

import ceramic.Shortcuts.*;
import ceramic.Entity;
import ceramic.Assets;

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

typedef FragmentFieldConverter = {

    var toFragmentItem:Dynamic;

    var fromFragmentItem:Dynamic;

} //FragmentFieldConverter

@:structInit
class FragmentContext {

    /** The assets registry used to load/unload assets in this fragment */
    public var assets:Assets;

    /** Whether the items are edited items or not */
    public var editedItems:Bool;

} //FragmentContext

/** A fragment is a group of visuals rendered from data (.fragment file) */
@editable
class Fragment extends Visual {

    public var entities(default,null):Array<Entity>;

    public var items(default,null):Array<FragmentItem>;

    public var context:FragmentContext;

    public var fragmentData(default,set):FragmentData;

#if editor

    @event function editableItemUpdate(item:FragmentItem);

    var updatedEditableItems:Map<String,FragmentItem> = null;

#end

/// Internal

    static var basicTypes:Map<String,Bool> = [
        'Bool' => true,
        'Int' => true,
        'Float' => true,
        'String' => true,
        'ceramic.Color' => true
    ];

/// Lifecycle

    public function new(context:FragmentContext) {

        super();

        this.context = context;
        entities = [];
        items = [];

    } //new

/// Data

    function set_fragmentData(fragmentData:FragmentData):FragmentData {

        this.fragmentData = fragmentData;
        var usedIds = new Map<String,Bool>();

        if (fragmentData != null) {

            id = fragmentData.id;
            data = fragmentData.data;
            width = fragmentData.width;
            height = fragmentData.height;

            if (fragmentData.items != null) {
                // Add/Update items
                for (item in fragmentData.items) {
                    putItem(item);
                    usedIds.set(item.id, true);
                }
            }

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

        return fragmentData;

    } //putData

/// Public API

    public function putItem(item:FragmentItem):Entity {

        var existing = getItemInstance(item.id);
        var existingWasVisual = false;
        
        // Remove previous object if entity class is different
        if (existing != null) {
            existingWasVisual = Std.is(existing, Visual);
            if (item.entity != Type.getClassName(Type.getClass(existing))) {
                removeItem(item.id);
                existing = null;
            }
        }
        else {
            items.push(item);
        }

        var entityClass = Type.resolveClass(item.entity);
        var instance:Entity = existing != null ? existing : cast Type.createInstance(entityClass, []);
        instance.id = item.id;

#if editor
        instance.edited = context.editedItems;
#end

        // Copy item data
        if (item.data != null) {
            for (key in Reflect.fields(item.data)) {
                Reflect.setField(instance.data, key, Reflect.field(item.data, key));
            }
        }

        // Copy item properties
        if (item.props != null) {
            for (field in Reflect.fields(item.props)) {
                var fieldType = FieldInfo.typeOf(item.entity, field);
                var value:Dynamic = Reflect.field(item.props, field);
                var converter = fieldType != null ? app.converters.get(fieldType) : null;
                if (converter != null) {
                    function(field) {
                        converter.basicToField(
                            context.assets,
                            value,
                            function(value:Dynamic) {
                                if (!instance.destroyed) {

                                    instance.setProperty(field, value);

#if editor
                                    // Update editable fields from instance
                                    updateEditableFieldsFromInstance(item.id);
#end
                                }
                            }
                        );
                    }(field);
                }
                else {
                    if (!basicTypes.exists(fieldType)) {
                        var resolvedEnum = Type.resolveEnum(fieldType);
                        if (resolvedEnum != null) {
                            for (name in Type.getEnumConstructs(resolvedEnum)) {
                                if (name.toLowerCase() == value.toLowerCase()) {
                                    value = Type.createEnum(resolvedEnum, name);
                                    break;
                                }
                            }
                        }
                    }
                    instance.setProperty(field, value);
                }
            }
        }

        // A few more stuff to do if item is new
        if (existing == null) {

            // If instance has an assets property, set it from our fragment context
            if (FieldInfo.typeOf(item.entity, 'assets') == 'ceramic.Assets') {
                instance.setProperty('assets', context.assets);
            }

            // Add instance (if new)
            entities.push(instance);
        }
        // Add it to display tree if it is a visual
        if (Std.is(instance, Visual) && !existingWasVisual) {
            add(cast instance);
        }

#if editor
        // Update editable fields from instance
        updateEditableFieldsFromInstance(item.id);
#end

        return instance;

    } //putItem

    public function getItemInstance(itemId:String):Entity {

        for (entity in entities) {
            if (entity.id == itemId) {
                
                return entity;
            }
        }

        return null;

    } //getItemInstance

    public function getItem(itemId:String):FragmentItem {

        for (item in items) {
            if (item.id == itemId) {
                
                return item;
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

        for (item in items) {
            if (item.id == itemId) {

                items.remove(item);

                break;
            }
        }

    } //removeItem

    public function removeAllItems():Void {

        for (entity in [].concat(entities)) {
                
            entities.remove(entity);
            entity.destroy();

        }

        for (item in [].concat(items)) {
            
            items.remove(item);

        }

    } //removeAllItems

#if editor

    public function updateEditableFieldsFromInstance(itemId:String):Void {

        // Get item
        var item = getItem(itemId);
        if (item == null) {
            return;
        }

        // Get instance
        var instance = getItemInstance(item.id);
        if (instance == null) {
            return;
        }

        // Compute missing data (if any)
        var editableFields = FieldInfo.editableFieldInfo(item.entity);
        var hasChanged = false;
        for (field in editableFields.keys()) {
            var fieldType = FieldInfo.typeOf(item.entity, field);
            var converter = fieldType != null ? app.converters.get(fieldType) : null;
            var value:Dynamic = null;
            if (converter != null) {
                value = converter.fieldToBasic(instance.getProperty(field));
            } else {
                value = instance.getProperty(field);
                switch (Type.typeof(value)) {
                    case TEnum(e):
                        value = Std.string(value);
                        var fieldInfo = editableFields.get(field);
                        var metaEditable = fieldInfo.meta.get('editable');
                        if (metaEditable != null && metaEditable.length > 0 && metaEditable[0].options != null) {
                            var opts:Array<String> = metaEditable[0].options;
                            for (opt in opts) {
                                if (value.toLowerCase() == opt.toLowerCase()) {
                                    value = opt;
                                    break;
                                }
                            }
                        }
                    default:
                        if (!basicTypes.exists(fieldType)) {
                            value = null;
                        }
                }
            }
            if (Reflect.field(item.props, field) != value || !Reflect.hasField(item.props, field)) {
                hasChanged = true;
                Reflect.setField(item.props, field, value);
            }
        }

        if (hasChanged) {
            if (updatedEditableItems == null) {
                updatedEditableItems = new Map();
                app.onceUpdate(this, function(delta) {
                    var prevUpdated = updatedEditableItems;
                    updatedEditableItems = null;
                    for (itemId in prevUpdated.keys()) {
                        var anItem = prevUpdated.get(itemId);
                        emitEditableItemUpdate(anItem);
                    }
                });
            }
            updatedEditableItems.set(item.id, item);
        }

    } //updateItemFromInstance

#end

} //Fragment
