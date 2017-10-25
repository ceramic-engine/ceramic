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

    public var assets:Assets;

} //FragmentContext

/** A fragment is a group of visuals rendered from data (.fragment file) */
class Fragment extends Quad {

    public var entities(default,null):Array<Entity>;

    public var items(default,null):Array<FragmentItem>;

    public var context:FragmentContext;

/// Converters

    public static var converters:Map<String,FragmentFieldConverter> = new Map();

    static var didAssignDefaultConverters = false;

#if editor

    @event function editableItemUpdate(item:FragmentItem);

    var updatedEditableItems:Map<String,FragmentItem> = null;

#end

/// Internal

    static var basicTypes:Map<String,Bool> = [
        'Bool' => true,
        'Int' => true,
        'Float' => true,
        'String' => true
    ];

/// Lifecycle

    public function new(context:FragmentContext) {

        super();

        this.context = context;
        entities = [];
        items = [];

        // Assign default converters
        if (!didAssignDefaultConverters) {
            if (!converters.exists('ceramic.Texture')) {
                converters.set('ceramic.Texture', {
                    fromFragmentItem: FragmentItemFieldDefaultConverters.textureFromFragmentItemField,
                    toFragmentItem: FragmentItemFieldDefaultConverters.textureToFragmentItemField
                });
            }
            if (!converters.exists('ceramic.BitmapFont')) {
                converters.set('ceramic.BitmapFont', {
                    fromFragmentItem: FragmentItemFieldDefaultConverters.fontFromFragmentItemField,
                    toFragmentItem: FragmentItemFieldDefaultConverters.fontToFragmentItemField
                });
            }
        }

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

        // Copy item data
        if (item.data != null) {
            for (key in Reflect.fields(item.data)) {
                Reflect.setField(instance.data, key, Reflect.field(item.data, key));
            }
        }

        // Copy item properties
        if (item.props != null) {
            for (field in Reflect.fields(item.props)) {
                var fieldType = Entity.typeOfEntityField(item.entity, field);
                var converter = fieldType != null ? converters.get(fieldType) : null;
                if (converter != null) {
                    function(field) {
                        converter.fromFragmentItem(
                            context,
                            item,
                            field,
                            function(value:Dynamic) {
                                if (!instance.destroyed) {

                                    instance.setProperty(field, value);

#if editor
                                    // Update editable fields from instance
                                    updateEditableFieldsFromInstance(item);
#end
                                }
                            }
                        );
                    }(field);
                }
                else {
                    var value:Dynamic = Reflect.field(item.props, field);
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

        // Add instance (if new)
        if (existing == null) {
            entities.push(instance);
        }
        // Add it to display tree if it is a visual
        if (Std.is(instance, Visual) && !existingWasVisual) {
            add(cast instance);
        }

#if editor
        // Update editable fields from instance
        updateEditableFieldsFromInstance(item);
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

    public function updateEditableFieldsFromInstance(item:FragmentItem):Void {

        // Get instance
        var instance = getItemInstance(item.id);
        if (instance == null) return;

        // Compute missing data (if any)
        var entityFields = Entity.editableFieldInfo(item.entity);
        var hasChanged = false;
        for (field in entityFields.keys()) {
            if (!Reflect.hasField(item.props, field)) {
                var fieldType = Entity.typeOfEntityField(item.entity, field);
                var converter = fieldType != null ? converters.get(fieldType) : null;
                var value:Dynamic = null;
                if (converter != null) {
                    value = converter.toFragmentItem(
                        context,
                        instance,
                        field
                    );
                } else {
                    value = instance.getProperty(field);
                    switch (Type.typeof(value)) {
                        case TEnum(e):
                            value = Std.string(value);
                            var fieldInfo = entityFields.get(field);
                            if (fieldInfo.meta.editable[0].options != null) {
                                var opts:Array<String> = fieldInfo.meta.editable[0].options;
                                for (opt in opts) {
                                    if (value.toLowerCase() == opt.toLowerCase()) {
                                        value = opt;
                                        break;
                                    }
                                }
                            }
                        default:
                    }
                }
                if (Reflect.field(item.props, field) != value || !Reflect.hasField(item.props, field)) {
                    hasChanged = true;
                    Reflect.setField(item.props, field, value);
                }
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

class FragmentItemFieldDefaultConverters {

/// Texture

    public static function textureToFragmentItemField(context:FragmentContext, entity:Entity, field:String):String {

        var texture:Texture = entity.getProperty(field);

        if (texture == null || texture.asset == null) {
            return null;
        }
        else {
            return texture.asset.name;
        }

    } //textureToFragmentItemField

    public static function textureFromFragmentItemField(context:FragmentContext, item:FragmentItem, field:String, done:Texture->Void):Void {

        var assetName:String = Reflect.field(item.props, field);
        var assets = context.assets;

        untyped console.error('TEXTURE assetName=$assetName field=$field');

        if (assetName != null) {
            var existing:ImageAsset = cast assets.asset(assetName, 'image');
            var asset:ImageAsset = existing != null ? existing : new ImageAsset(assetName);
            if (existing == null) {
                if (asset != null) {
                    // Create and load asset
                    assets.addAsset(asset);
                    asset.onceComplete(function(success) {
                        if (success) {
                            done(assets.texture(assetName));
                        }
                        else {
                            warning('Failed to load texture for fragment item: ' + item);
                            done(null);
                        }
                    });
                    assets.load();
                }
                else {
                    // Nothing to do
                    done(null);
                }
            }
            else {
                if (asset.status == READY) {
                    // Asset already available
                    done(assets.texture(assetName));
                }
                else if (asset.status == LOADING) {
                    // Asset loading
                    asset.onceComplete(function(success) {
                        if (success) {
                            done(assets.texture(assetName));
                        }
                        else {
                            warning('Failed to load texture for fragment item: ' + item);
                            done(null);
                        }
                    });
                }
                else {
                    // Asset broken?
                    done(null);
                }
            }
        }
        else {
            done(null);
        }

    } //textureFromFragmentItemField

/// BitmapFont

    public static function fontToFragmentItemField(context:FragmentContext, entity:Entity, field:String):String {

        var font:BitmapFont = entity.getProperty(field);

        if (font == null || font.asset == null) {
            return null;
        }
        else {
            return font.asset.name;
        }

    } //fontToFragmentItemField

    public static function fontFromFragmentItemField(context:FragmentContext, item:FragmentItem, field:String, done:BitmapFont->Void):Void {

        var assetName:String = Reflect.field(item.props, field);

        if (assetName == null || assetName == app.defaultFont.asset.name) {
            done(app.defaultFont);
            return;
        }
        var assets = context.assets;

        untyped console.error('FONT assetName=$assetName field=$field');

        if (assetName != null) {
            var existing:FontAsset = cast assets.asset(assetName, 'font');
            var asset:FontAsset = existing != null ? existing : new FontAsset(assetName);
            if (existing == null) {
                if (asset != null) {
                    // Create and load asset
                    assets.addAsset(asset);
                    asset.onceComplete(function(success) {
                        if (success) {
                            done(assets.font(assetName));
                        }
                        else {
                            warning('Failed to load font for fragment item: ' + item);
                            done(null);
                        }
                    });
                    assets.load();
                }
                else {
                    // Nothing to do
                    done(null);
                }
            }
            else {
                if (asset.status == READY) {
                    // Asset already available
                    done(assets.font(assetName));
                }
                else if (asset.status == LOADING) {
                    // Asset loading
                    asset.onceComplete(function(success) {
                        if (success) {
                            done(assets.font(assetName));
                        }
                        else {
                            warning('Failed to load font for fragment item: ' + item);
                            done(null);
                        }
                    });
                }
                else {
                    // Asset broken?
                    done(null);
                }
            }
        }
        else {
            done(null);
        }

    } //fontFromFragmentItemField

} //FragmentItemFieldDefaultConverters
