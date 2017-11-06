package editor;

import ceramic.Entity;
import ceramic.Settings;
import ceramic.Fragment;
import ceramic.Timer;
import ceramic.Quad;
import ceramic.Text;
import ceramic.Collections;
import ceramic.Visual;
import ceramic.RuntimeAssets;
import ceramic.Texture;
import ceramic.Screen;
import ceramic.FieldInfo;
import ceramic.Key;
import ceramic.Assets;
import ceramic.Shortcuts.*;

import editor.Message;
import editor.Editable;

import haxe.rtti.Meta;
import haxe.rtti.Rtti;

import haxe.Json;
#if web
import js.Browser.*;
#end

using StringTools;
using ceramic.Extensions;

/** Turns the app into an editor. */
class Editor extends Entity {

    public static var editor(default,null):Editor = null;

/// Public properties

    public var leftShiftPressed:Bool = false;
    public var rightShiftPressed:Bool = false;
    public var shiftPressed:Bool = false;

    public var aKeyPressed:Bool = false;
    public var rKeyPressed:Bool = false;
    public var xKeyPressed:Bool = false;
    public var yKeyPressed:Bool = false;
    public var wKeyPressed:Bool = false;
    public var hKeyPressed:Bool = false;

/// Properties

    var parentOrigin:String = null;

    var fragment:Fragment = null;

    var selectedItemId:String = null;

    var outsideTop:Quad = null;

    var outsideRight:Quad = null;

    var outsideBottom:Quad = null;

    var outsideLeft:Quad = null;

    var outsideTopClick:Quad = null;

    var outsideRightClick:Quad = null;

    var outsideBottomClick:Quad = null;

    var outsideLeftClick:Quad = null;

    var renders:Int = 0;

    var runtimeAssets:RuntimeAssets = null;

    var assets:Assets = new Assets();

    var fragmentItems:Map<String,FragmentItem> = new Map();

    var editableTypes:Array<EditableType> = [];

    var collectionsInfo:Array<CollectionInfo> = [];

/// Internal

    static var basicTypes:Map<String,Bool> = [
        'Bool' => true,
        'Int' => true,
        'Float' => true,
        'String' => true
    ];

/// Lifecycle

    public function new(settings:InitSettings) {

        if (editor != null) throw 'Only one single editor can be created.';
        editor = this;

        settings.antialiasing = true;
        settings.background = 0x282828;
        settings.scaling = FIT;

#if web
        settings.assetsPath = untyped window._ceramicBaseUrl + '/ceramic/assets';
        settings.backend = {
            webParent: js.Browser.document.getElementById('ceramic-editor-view'),
            allowDefaultKeys: true
        };
#end

        settings.targetDensity = 1;

    } //new

    /** Render is called explicitly. If not called on change, nothing will display.
        This is intended to save CPU/GPU when nothing is being edited. */
    public function render() {

        renders++;
        if (!Luxe.core.auto_render) {
            Luxe.core.auto_render = true;
        }

        Timer.delay(0.5, function() {
            renders--;
            if (renders == 0) {
                Luxe.core.auto_render = false;
            }
        });

    } //render

/// Start

    public function start() {

        // Render when assets get updated
        assets.onUpdate(this, function(_) render());
        app.assets.onUpdate(this, function(_) render());

        //Luxe.core.update_rate = 0.1;
        Luxe.core.auto_render = false;

        // Compute editable types
        for (key in Reflect.fields(app.info.editable)) {
            var classPath = Reflect.field(app.info.editable, key);
            var clazz = Type.resolveClass(classPath);
            var usedFields = new Map();
            var fields = [];
            var rtti = Rtti.getRtti(clazz);

            editableTypes.push({
                meta: Meta.getType(clazz),
                entity: classPath,
                fields: fields,
                isVisual: true // TODO handle non-visuals
            });

            while (clazz != null) {

                var meta = Meta.getFields(clazz);
                for (field in rtti.fields) {
                    var k = field.name;
                    var v = Reflect.field(meta, k);

                    if (v != null && Reflect.hasField(v, 'editable') && !usedFields.exists(k)) {
                        usedFields.set(k, true);

                        var fieldMeta:Dynamic = {};
                        var origMeta = v;
                        for (mk in Reflect.fields(origMeta)) {
                            Reflect.setField(fieldMeta, mk, Reflect.field(origMeta, mk));
                        }

                        var fieldType = FieldInfo.stringFromCType(field.type);

                        var editable:Array<Dynamic> = fieldMeta.editable;
                        if (editable == null) {
                            fieldMeta.editable = [{}];
                            editable = fieldMeta.editable;
                        }
                        else if (editable.length == 0) editable.push({});

                        if (!basicTypes.exists(fieldType)) {
                            var resolvedEnum = Type.resolveEnum(fieldType);
                            if (resolvedEnum != null && editable[0].options == null) {
                                var rawOptions = Type.getEnumConstructs(resolvedEnum);
                                var options = [];
                                for (item in rawOptions) {
                                    options.push(item.toLowerCase());
                                }
                                editable[0].options = options;
                            }
                        }

                        fields.push({
                            name: k,
                            meta: fieldMeta,
                            type: fieldType
                        });
                    }
                }

                clazz = Type.getSuperClass(clazz);
                if (clazz != null) rtti = Rtti.getRtti(clazz);

            }
        }

        // Compute collection types
        for (key in Reflect.fields(app.info.collections)) {
            var collectionName = '';
            for (k in Reflect.fields(Reflect.field(app.info.collections, key))) {
                collectionName = k;
                break;
            }
            var info:{data:String, type:String} = Reflect.field(Reflect.field(app.info.collections, key), collectionName);
            var classPath = info.type;
            var clazz = Type.resolveClass(classPath);
            var usedFields = new Map();
            var fields = [];
            var collectionData = [];
            var rtti = Rtti.getRtti(clazz);

            collectionsInfo.push({
                meta: Meta.getType(clazz),
                name: collectionName,
                type: classPath,
                data: collectionData,
                fields: fields
            });

            // Fill data
            var collection:Collection<CollectionEntry> = Reflect.field(collections, collectionName);
            if (collection != null) {
                for (entry in collection) {
                    collectionData.push(entry.getEditableData());
                }
            }

            while (clazz != null) {

                var meta = Meta.getFields(clazz);
                for (field in rtti.fields) {
                    var k = field.name;
                    var v = Reflect.field(meta, k);

                    if (v != null && Reflect.hasField(v, 'editable') && !usedFields.exists(k)) {
                        usedFields.set(k, true);

                        var fieldMeta:Dynamic = {};
                        var origMeta = v;
                        for (mk in Reflect.fields(origMeta)) {
                            Reflect.setField(fieldMeta, mk, Reflect.field(origMeta, mk));
                        }

                        var fieldType = FieldInfo.stringFromCType(field.type);

                        var editable:Array<Dynamic> = fieldMeta.editable;
                        if (editable == null) {
                            fieldMeta.editable = [{}];
                            editable = fieldMeta.editable;
                        }
                        else if (editable.length == 0) editable.push({});

                        if (!basicTypes.exists(fieldType)) {
                            var resolvedEnum = Type.resolveEnum(fieldType);
                            if (resolvedEnum != null && editable[0].options == null) {
                                var rawOptions = Type.getEnumConstructs(resolvedEnum);
                                var options = [];
                                for (item in rawOptions) {
                                    options.push(item.toLowerCase());
                                }
                                editable[0].options = options;
                            }
                        }

                        fields.push({
                            name: k,
                            meta: fieldMeta,
                            type: fieldType
                        });
                    }
                }

                clazz = Type.getSuperClass(clazz);
                if (clazz != null) rtti = Rtti.getRtti(clazz);

            }
        }

        // Setup
#if web
        var containerEl = document.getElementById('ceramic-editor-view');
        var containerWidth = containerEl.offsetWidth;
        var containerHeight = containerEl.offsetHeight;
        app.onUpdate(this, function(delta) {
            var containerEl = document.getElementById('ceramic-editor-view');
            var width = containerEl.offsetWidth;
            var height = containerEl.offsetHeight;

            if (width != containerWidth || height != containerHeight) {
                containerWidth = width;
                containerHeight = height;
                updateCanvas();
            }
        });
#end
        screen.onResize(this, function() {

            // Fit fragment
            fitFragment();

            // Render
            render();
        });
        screen.onDown(this, function(info) {

            // Render
            render();
        });
        updateCanvas();

#if web
        // Receive messages
        var _ceramicEditor = {
            send: function(event:{data:String, origin:String, source:js.html.Window}) {
                app.onceUpdate(function(_) {
                    receiveRawMessage(event);
                });
            }
        };
        untyped window._ceramicEditor = _ceramicEditor;
#end

        // Keyboard events
        app.onKeyDown(this, function(key) {

            if (key.keyCode == KeyCode.LSHIFT) {
                leftShiftPressed = true;
            }
            else if (key.keyCode == KeyCode.RSHIFT) {
                rightShiftPressed = true;
            }
            else if (key.keyCode == KeyCode.KEY_R) {
                rKeyPressed = true;
            }
            else if (key.keyCode == KeyCode.KEY_A) {
                aKeyPressed = true;
            }
            else if (key.keyCode == KeyCode.KEY_X) {
                xKeyPressed = true;
            }
            else if (key.keyCode == KeyCode.KEY_Y) {
                yKeyPressed = true;
            }
            else if (key.keyCode == KeyCode.KEY_W) {
                wKeyPressed = true;
            }
            else if (key.keyCode == KeyCode.KEY_H) {
                hKeyPressed = true;
            }

            shiftPressed = leftShiftPressed || rightShiftPressed;

        });
        app.onKeyUp(this, function(key) {

            if (key.keyCode == KeyCode.LSHIFT) {
                leftShiftPressed = false;
            }
            else if (key.keyCode == KeyCode.RSHIFT) {
                rightShiftPressed = false;
            }
            else if (key.keyCode == KeyCode.KEY_R) {
                rKeyPressed = false;
            }
            else if (key.keyCode == KeyCode.KEY_A) {
                aKeyPressed = false;
            }
            else if (key.keyCode == KeyCode.KEY_X) {
                xKeyPressed = false;
            }
            else if (key.keyCode == KeyCode.KEY_Y) {
                yKeyPressed = false;
            }
            else if (key.keyCode == KeyCode.KEY_W) {
                wKeyPressed = false;
            }
            else if (key.keyCode == KeyCode.KEY_H) {
                hKeyPressed = false;
            }

            shiftPressed = leftShiftPressed || rightShiftPressed;

        });

        // Update canvas
        updateCanvas();

        // Render once
        render();

    } //start

    function updateCanvas() {

#if web
        var containerEl = document.getElementById('ceramic-editor-view');
        var width = containerEl.offsetWidth;
        var height = containerEl.offsetHeight;

        var appEl:js.html.CanvasElement = cast document.getElementById('app');
        appEl.style.margin = '0 0 0 0';
        appEl.style.width = width + 'px';
        appEl.style.height = height + 'px';
        appEl.width = Math.round(width * window.devicePixelRatio);
        appEl.height = Math.round(height * window.devicePixelRatio);
#end

    } //updateCanvas

    function fitFragment() {

        if (fragment == null) return;

        // Fit fragment
        var scale = Math.min(
            screen.width / fragment.width,
            screen.height / fragment.height
        );
        fragment.scale(scale, scale);
        fragment.pos(screen.width * 0.5, screen.height * 0.5);

        // Fit outsides
        //
        if (outsideTop == null) {
            outsideTop = new Quad();
            outsideTop.color = settings.background;
            outsideTop.alpha = 0.95;
            outsideTop.depth = 99998;

            outsideRight = new Quad();
            outsideRight.color = settings.background;
            outsideRight.alpha = 0.95;
            outsideRight.depth = 99998;

            outsideBottom = new Quad();
            outsideBottom.color = settings.background;
            outsideBottom.alpha = 0.95;
            outsideBottom.depth = 99998;

            outsideLeft = new Quad();
            outsideLeft.color = settings.background;
            outsideLeft.alpha = 0.95;
            outsideLeft.depth = 99998;

            outsideTopClick = new Quad();
            outsideTopClick.alpha = 0;
            outsideTopClick.depth = 0;

            outsideRightClick = new Quad();
            outsideRightClick.alpha = 0;
            outsideRightClick.depth = 0;

            outsideBottomClick = new Quad();
            outsideBottomClick.alpha = 0;
            outsideBottomClick.depth = 0;

            outsideLeftClick = new Quad();
            outsideLeftClick.alpha = 0;
            outsideLeftClick.depth = 0;

            for (area in [outsideTopClick, outsideRightClick, outsideBottomClick, outsideLeftClick]) {
                area.onDown(area, function(info) {
                    if (Editable.highlight != null) {
                        Editable.highlight.destroy();
                    }
                });
            }
        }

        var pad = 1;

        outsideTop.pos(-pad, -pad);
        outsideTop.size(screen.width + pad * 2, (screen.height - fragment.height * fragment.scaleY) * 0.5 + pad);

        outsideBottom.pos(-pad, fragment.height * fragment.scaleY + (screen.height - fragment.height * fragment.scaleY) * 0.5);
        outsideBottom.size(screen.width + pad * 2, (screen.height - fragment.height * fragment.scaleY) * 0.5 + pad);

        outsideLeft.pos(-pad, -pad);
        outsideLeft.size((screen.width - fragment.width * fragment.scaleX) * 0.5 + pad, screen.height + pad * 2);

        outsideRight.pos(fragment.width * fragment.scaleX + (screen.width - fragment.width * fragment.scaleX) * 0.5, -pad);
        outsideRight.size((screen.width - fragment.width * fragment.scaleX) * 0.5 + pad, screen.height + pad * 2);

        outsideTopClick.pos(outsideTop.x, outsideTop.y);
        outsideTopClick.size(outsideTop.width, outsideTop.height);

        outsideBottomClick.pos(outsideBottom.x, outsideBottom.y);
        outsideBottomClick.size(outsideBottom.width, outsideBottom.height);

        outsideLeftClick.pos(outsideLeft.x, outsideLeft.y);
        outsideLeftClick.size(outsideLeft.width, outsideLeft.height);

        outsideRightClick.pos(outsideRight.x, outsideRight.y);
        outsideRightClick.size(outsideRight.width, outsideRight.height);

        // Update density
        settings.targetDensity = 2; //Math.ceil(screen.density * fragment.scaleX);

    } //fitFragment

/// Messages

    function receiveRawMessage(event:{data:String, origin:String, source:Dynamic}) {

        // Parse message
        var message:Message = null;
        try {
            message = Json.parse(event.data);

            // Ping?
            if (message.type == 'ping') {
                parentOrigin = event.origin;
                var _send:Dynamic = untyped window._ceramicComponentSend;
                _send({
                    data: Json.stringify({type: 'pong'}),
                    origin: parentOrigin,
                    source: untyped window
                });
                return;
            }

        } catch (e:Dynamic) {
            error('Failed to decode message: ' + event.data);
            return;
        }

        if (message != null) {
            // Handle message
            receiveMessage(message);
        }

        // Render to reflect changes
        render();

    } //receiveRawMessage

    function receiveMessage(message:Message) {

        var parts = message.type.split('/');
        var service = parts[0];
        var action = parts[1];
        var value = message.value;

        switch (service) {

            case 'assets':
                if (action == 'lists') {

                    // Update asset list
                    var rawList:Array<String> = value.list;
                    runtimeAssets = new RuntimeAssets(rawList);
                    var lists = runtimeAssets.getEncodableLists();

                    // Reset assets
                    assets.destroy();
                    assets = new Assets();
                    assets.onUpdate(this, function(_) render());

                    // Reset fragment to get updated assets
                    if (fragment != null) {
                        fragment.context.assets = assets;
                        fragment.removeAllItems();
                        for (key in fragmentItems.keys()) {
                            var item = fragmentItems.get(key);
                            var entity = fragment.putItem(item);
                            if (Std.is(entity, Visual)) {
                                var visual:Visual = cast entity;
                                visual.touchable = !(value.data != null && value.data.locked);
                                if (!visual.hasComponent('editable')) {
                                    visual.component('editable', new Editable(fragment));
                                }
                                if (selectedItemId == item.id) {
                                    cast(visual.component('editable'), Editable).select();
                                }
                            }
                        }
                    }

                    send({
                        type: 'assets/lists',
                        value: {
                            images: runtimeAssets.getNames('image'),
                            texts: runtimeAssets.getNames('text'),
                            sounds: runtimeAssets.getNames('sound'),
                            fonts: runtimeAssets.getNames('font'),
                            databases: runtimeAssets.getNames('database'),
                            all: lists.all,
                            allDirs: lists.allDirs,
                            allByName: lists.allByName,
                            allDirsByName: lists.allDirsByName
                        }
                    });
                }
            
            case 'editables':
                if (action == 'list') {
                    send({
                        type: 'editables/list',
                        value: editableTypes
                    });
                }
            
            case 'collections':
                if (action == 'list') {
                    send({
                        type: 'collections/list',
                        value: collectionsInfo
                    });
                }

            case 'fragment':
                if (fragment != null && value.id != fragment.id) {
                    fragment.destroy();
                    fragment = null;
                    selectedItemId = null;
                }
                if (action == 'put') {
                    if (fragment == null) {
                        fragment = new Fragment({
                            assets: assets
                        });
                        fragment.id = value.id;
                        fragment.depthRange = 10000;
                        fragment.color = 0x2f2f2f;
                        fragment.anchor(0.5, 0.5);
                        fragment.onDown(fragment, function(info) {
                            if (Editable.highlight != null) {
                                Editable.highlight.destroy();
                            }
                        });
                        fragment.onEditableItemUpdate(fragment, function(item) {
                            //untyped console.log('SEND');
                            //untyped console.log(item);
                            send({
                                type: 'set/fragment.item.${item.id}',
                                value: item.props
                            });
                        });

                        /*
                        fragment.deserializers.set('ceramic.Quad', function(fragment:Fragment, instance:Entity, item:FragmentItem) {
                            if (instance.destroyed) return;
                            if (item.props != null) {

                                var quad:Quad = cast instance;

                                function updateSize() {
                                    if (quad.texture != null) {
                                        send({
                                            type: 'set/fragment.item.${item.id}',
                                            value: {
                                                width: quad.width,
                                                height: quad.height
                                            }
                                        });
                                    }
                                    else {
                                        quad.width = item.props.width;
                                        quad.height = item.props.height;
                                    }
                                }

                                for (field in Reflect.fields(item.props)) {

                                    if (field == 'texture') {
                                        if (runtimeAssets == null) {
                                            return;
                                        }
                                        var assetName:String = Reflect.field(item.props, field);
                                        if (assetName != null) {
                                            var existing:ImageAsset = cast assets.asset(assetName, 'image');
                                            var asset:ImageAsset = existing != null ? existing : new ImageAsset(assetName);
                                            if (existing == null) {
                                                if (asset != null) {
                                                    // Create and load asset
                                                    asset.runtimeAssets = runtimeAssets;
                                                    assets.addAsset(asset);
                                                    asset.onceComplete(function(success) {
                                                        if (success && !instance.destroyed) {
                                                            quad.texture = assets.texture(assetName);
                                                            updateSize();
                                                            render();
                                                        }
                                                        else if (!instance.destroyed) {
                                                            warning('Failed to load texture for visual: ' + instance);
                                                        }
                                                    });
                                                    assets.load();
                                                }
                                                else {
                                                    // Nothing to do
                                                }
                                            }
                                            else {
                                                if (asset.status == READY) {
                                                    // Asset already available
                                                    quad.texture = assets.texture(assetName);
                                                    updateSize();
                                                }
                                                else if (asset.status == LOADING) {
                                                    // Asset loading
                                                    asset.onceComplete(function(success) {
                                                        if (success && !instance.destroyed) {
                                                            quad.texture = assets.texture(assetName);
                                                            updateSize();
                                                            render();
                                                        }
                                                        else if (!instance.destroyed) {
                                                            warning('Failed to load texture for visual: ' + instance);
                                                        }
                                                    });
                                                }
                                                else {
                                                    // Asset broken?
                                                    quad.texture = null;
                                                    updateSize();
                                                }
                                            }
                                        }
                                        else {
                                            quad.texture = null;
                                            updateSize();
                                        }
                                    }
                                    else {
                                        instance.setProperty(field, Reflect.field(item.props, field));
                                    }
                                }
                            }
                        });*/

                        /*fragment.deserializers.set('ceramic.Text', function(fragment:Fragment, instance:Entity, item:FragmentItem) {
                            if (instance.destroyed) return;
                            if (item.props != null) {

                                var text:Text = cast instance;

                                function updateSize() {
                                    send({
                                        type: 'set/fragment.item.${item.id}',
                                        value: {
                                            width: text.width,
                                            height: text.height
                                        }
                                    });
                                }

                                for (field in Reflect.fields(item.props)) {

                                    if (field == 'font') {
                                        if (runtimeAssets == null) {
                                            return;
                                        }
                                        var assetName:String = Reflect.field(item.props, field);
                                        if (assetName != null) {
                                            var existing:FontAsset = cast assets.asset(assetName, 'font');
                                            var asset:FontAsset = existing != null ? existing : new FontAsset(assetName);
                                            if (existing == null) {
                                                if (asset != null) {
                                                    // Create and load asset
                                                    asset.runtimeAssets = runtimeAssets;
                                                    assets.addAsset(asset);
                                                    asset.onceComplete(function(success) {

                                                        if (success && !instance.destroyed) {
                                                            text.font = assets.font(assetName);
                                                            updateSize();
                                                            render();
                                                        }
                                                    });
                                                    assets.load();
                                                }
                                                else {
                                                    // Nothing to do
                                                }
                                            }
                                            else {
                                                if (asset.status == READY) {
                                                    // Asset already available
                                                    text.font = assets.font(assetName);
                                                }
                                                else if (asset.status == LOADING) {
                                                    // Asset loading
                                                    asset.onceComplete(function(success) {
                                                        if (success && !instance.destroyed) {
                                                            text.font = assets.font(assetName);
                                                            updateSize();
                                                            render();
                                                        }
                                                    });
                                                }
                                                else {
                                                    // Asset broken?
                                                    text.font = app.assets.font(Fonts.ARIAL_20);
                                                }
                                            }
                                        }
                                        else {
                                            text.font = app.assets.font(Fonts.ARIAL_20);
                                        }
                                    }
                                    else if (field == 'align') {
                                        text.align = switch(item.props.align) {
                                            case 'right': RIGHT;
                                            case 'center': CENTER;
                                            default: LEFT;
                                        }
                                    }
                                    else if (field == 'pointSize') {
                                        text.pointSize = item.props.pointSize;
                                    }
                                    else if (field == 'lineHeight') {
                                        text.lineHeight = item.props.lineHeight;
                                    }
                                    else if (field == 'letterSpacing') {
                                        text.letterSpacing = item.props.letterSpacing;
                                    }
                                    else {
                                        instance.setProperty(field, Reflect.field(item.props, field));
                                    }
                                }

                                updateSize();
                            }
                        });*/
                    }
                    fragment.putData(value);
                    fitFragment();
                }
                else if (action == 'delete') {
                    if (fragment != null && value.id == fragment.id) {
                        fragment.destroy();
                        fragment = null;
                        selectedItemId = null;
                    }
                }

            case 'fragment-item':
                if (action == 'put') {
                    //untyped console.log('PUT');
                    //untyped console.log(value);
                    fragmentItems.set(value.id, value);
                    var entity = fragment.putItem(value);
                    if (Std.is(entity, Visual)) {
                        var visual:Visual = cast entity;
                        visual.touchable = !(value.data != null && value.data.locked);
                        if (!visual.hasComponent('editable')) {
                            visual.component('editable', new Editable(fragment));
                        }
                    }
                }
                else if (action == 'select') {
                    var entity = value != null && value.id != null ? fragment.getItemInstance(value.id) : null;
                    if (entity != null && entity.hasComponent('editable')) {
                        cast(entity.component('editable'), Editable).select();
                        selectedItemId = value.id;
                    }
                    else {
                        selectedItemId = null;
                        if (Editable.highlight != null) {
                            Editable.highlight.destroy();
                        }
                    }
                }
                else if (action == 'delete') {
                    fragmentItems.remove(value.id);
                    fragment.removeItem(value.id);
                }

            default:

        } //switch

    } //receiveMessage

    public function send(message:Message):Void {

#if web
        // Send message
        var _send:Dynamic = untyped window._ceramicComponentSend;
        _send({
            data: Json.stringify(message),
            origin: parentOrigin,
            source: untyped window
        });
#end

    } //send

} //Editor

typedef EditableType = {

    var meta:Dynamic;

    var entity:String;

    var isVisual:Bool;

    var fields:Array<EditableTypeField>;

} //EditableType

typedef EditableTypeField = {

    var name:String;

    var meta:Dynamic;

    var type:String;

} //EditableTypeField

typedef CollectionInfo = {

    var meta:Dynamic;

    var name:String;

    var type:String;

    var data:Array<CollectionEntryData>;

    var fields:Array<CollectionEntryField>;

} //CollectionInfo

typedef CollectionEntryField = {

    var name:String;

    var meta:Dynamic;

    var type:String;

} //CollectionEntryField

typedef CollectionEntryData = {

    var name:String;

    var id:String;

    var props:Dynamic;

} //CollectionEntryData
