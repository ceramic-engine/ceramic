package ceramic;

import ceramic.Shortcuts.*;
import ceramic.Entity;
import ceramic.Assets;

import haxe.DynamicAccess;

using ceramic.Extensions;

/** A fragment is a group of visuals rendered from data (.fragment file) */
@editable({ implicitSize: true })
class Fragment extends Visual {

    public var entities(default,null):Array<Entity>;

    public var items(default,null):Array<FragmentItem>;

    public var context:FragmentContext;

    @editable
    public var fragmentData(default,set):FragmentData = null;

    public var pendingLoads(default,null):Int = 0;

    @event function ready();

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
        
        pendingLoads++;

        this.fragmentData = fragmentData;
        var usedIds = new Map<String,Bool>();

        if (fragmentData != null) {

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

        // Keep items if fragmentData is provided with no property 'items'
        if (fragmentData == null || Reflect.hasField(fragmentData, 'items')) {
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

        // Add fragment-level components
        if (fragmentData != null #if editor && edited #end) {
            pendingLoads++;
            var converter = app.converters.get('ceramic.ImmutableMap<String,ceramic.Component>');
            converter.basicToField(
                context.assets,
                fragmentData.components,
                function(value) {
                    if (destroyed) return;
                    pendingLoads--;

                    onceReady(this, function() {
                        this.fragmentComponents = value;
                    });
                    
                    if (pendingLoads == 0) emitReady();
                }
            );
        }

        pendingLoads--;
        if (pendingLoads == 0) emitReady();

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
        var instance:Entity = existing != null ? existing : null;
        var isFragment = item.entity == 'ceramic.Fragment';
        if (instance == null) {
            var newArgs = [];
            if (isFragment) {
                var subContext:FragmentContext = {
                    assets: context.assets,
                    editedItems: false
                };
                newArgs.push(subContext);
            }
            instance = cast Type.createInstance(entityClass, newArgs);
        }
        instance.id = item.id;

        if (isFragment) {
            var frag:ceramic.Fragment = cast instance;
            frag.depthRange = 1;
        }

#if editor
        instance.edited = context.editedItems;
#end

        // Set name
        if (instance.data.name == null && item.name != null) instance.data.name = item.name;

        // Copy item data
        if (item.data != null && instance.data != null) {
            for (key in Reflect.fields(item.data)) {
                Reflect.setField(instance.data, key, Reflect.field(item.data, key));
            }
        }

        // Copy item properties
        if (item.props != null) {
            var orderedProps = Reflect.fields(item.props);

            // TODO sort by order of properties in underlying class
            // For now we just ensure components is the last property being instanced
            haxe.ds.ArraySort.sort(orderedProps, function(a:String, b:String):Int {

                var nA = 0;
                var nB = 0;

                if (a == 'components') nA++;
                else if (b == 'components') nB++;

                return nA - nB;

            });
            
            for (field in orderedProps) {
                var fieldType = FieldInfo.typeOf(item.entity, field);
                var value:Dynamic = Reflect.field(item.props, field);
                var converter = fieldType != null ? app.converters.get(fieldType) : null;
                if (converter != null) {
                    function(field) {
                        pendingLoads++;
                        converter.basicToField(
                            context.assets,
                            value,
                            function(value:Dynamic) {

                                pendingLoads--;
                                if (destroyed) return;

                                if (!instance.destroyed) {

                                    if (isFragment && field == 'fragmentData') {
                                        var fragment:Fragment = cast instance;
                                        pendingLoads++;
                                        fragment.onceReady(this, function() {
                                            pendingLoads--;
                                            if (destroyed) return;
                                            if (pendingLoads == 0) emitReady();
                                        });
                                        fragment.fragmentData = value;
                                    }
                                    else if (field != 'components') {
                                        instance.setProperty(field, value);

#if editor
                                        updateEditableFieldsFromInstance(item.id);
#end
                                    }
                                    else {

                                        onceReady(this, function() {
                                            instance.setProperty(field, value);

#if editor
                                            updateEditableFieldsFromInstance(item.id);
#end
                                        });
                                    }
                                }

                                if (pendingLoads == 0) emitReady();
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

    public function getItemInstanceByName(name:String):Entity {

        for (entity in entities) {
            if (entity.data.name == name) {
                
                return entity;
            }
        }

        return null;

    } //getItemInstanceByName

    public function getItem(itemId:String):FragmentItem {

        for (item in items) {
            if (item.id == itemId) {
                
                return item;
            }
        }

        return null;

    } //getItem

    public function getItemByName(name:String):FragmentItem {

        for (item in items) {
            if (item.name == name) {
                
                return item;
            }
        }

        return null;

    } //getItemByName

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

    function destroy() {

        removeAllItems();

    } //destroy

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
                        // Keep the value as is
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

/// Fragment components

    /** Fragment components mapping. Does not contain components
        created separatelywith `component()` or macro-based components or components property. */
    public var fragmentComponents(default,set):ImmutableMap<String,Component> = null;
    function set_fragmentComponents(fragmentComponents:ImmutableMap<String,Component>):ImmutableMap<String,Component> {
        if (this.fragmentComponents == fragmentComponents) return fragmentComponents;

        // Remove older components
        if (this.fragmentComponents != null) {
            for (name in this.fragmentComponents.keys()) {
                if (fragmentComponents == null || !fragmentComponents.exists(name)) {
                    removeComponent(name);
                }
            }
        }

        // Add new components
        if (fragmentComponents != null) {
            for (name in fragmentComponents.keys()) {
                var newComponent = fragmentComponents.get(name);
                if (this.fragmentComponents != null) {
                    var existing = this.fragmentComponents.get(name);
                    if (existing != null) {
                        if (existing != newComponent) {
                            removeComponent(name);
                            component(name, newComponent);
                        }
                    } else {
                        component(name, newComponent);
                    }
                } else {
                    component(name, newComponent);
                }
            }
        }

        // Update mapping
        this.fragmentComponents = fragmentComponents;

        return fragmentComponents;
    }

} //Fragment
