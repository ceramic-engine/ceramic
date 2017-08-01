package;

import ceramic.Entity;
import ceramic.Settings;
import ceramic.Scene;
import ceramic.Timer;
import ceramic.Quad;
import ceramic.Visual;
import ceramic.RuntimeAssets;
import ceramic.Texture;
import ceramic.Assets;
import ceramic.Shortcuts.*;

import editor.Message;
import editor.Editable;

import js.Browser.*;
import haxe.Json;

using StringTools;
using ceramic.Extensions;

class Project extends Entity {

    var parentOrigin:String = null;

    var scene:Scene = null;

    var outsideTop:Quad = null;

    var outsideRight:Quad = null;

    var outsideBottom:Quad = null;

    var outsideLeft:Quad = null;

    var renders:Int = 0;

    var runtimeAssets:RuntimeAssets = null;

    var assets:Assets = new Assets();

    function new(settings:InitSettings) {

        settings.antialiasing = true;
        settings.background = 0x282828;
        settings.scaling = FIT;

        app.onceReady(ready);

    } //new

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

    function ready() {

        //Luxe.core.update_rate = 0.1;
        Luxe.core.auto_render = false;

        // Setup
        //layout();
        window.addEventListener('resize', function() updateCanvas());
        screen.onResize(this, function() {

            // Fit scene
            fitScene();

            // Render
            render();
        });
        screen.onDown(this, function(info) {

            // Render
            render();
        });
        updateCanvas();

        // Receive messages
        window.addEventListener('message', function(event:{data:String, origin:String, source:js.html.Window}) {
            app.onceUpdate(function(_) {
                receiveRawMessage(event);
            });
        });

        // Keyboard events
        app.onKeyDown(this, function(key) {

            trace('KEY DOWN: ' + key);

        });
        app.onKeyUp(this, function(key) {

            trace('KEY UP: ' + key);

        });

        // Render once
        render();

    } //ready

    function updateCanvas() {

        var appEl:js.html.CanvasElement = cast document.getElementById('app');
        appEl.style.margin = '0 0 0 0';
        appEl.style.width = window.innerWidth + 'px';
        appEl.style.height = window.innerHeight + 'px';
        appEl.width = Math.round(window.innerWidth * window.devicePixelRatio);
        appEl.height = Math.round(window.innerHeight * window.devicePixelRatio);

    } //updateCanvas

    function fitScene() {

        if (scene == null) return;

        // Fit scene
        var scale = Math.min(
            screen.width / scene.width,
            screen.height / scene.height
        );
        scene.scale(scale, scale);
        scene.pos(screen.width * 0.5, screen.height * 0.5);

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
        }

        var pad = 1;

        outsideTop.pos(-pad, -pad);
        outsideTop.size(screen.width + pad * 2, (screen.height - scene.height * scene.scaleY) * 0.5 + pad);

        outsideBottom.pos(-pad, scene.height * scene.scaleY + (screen.height - scene.height * scene.scaleY) * 0.5);
        outsideBottom.size(screen.width + pad * 2, (screen.height - scene.height * scene.scaleY) * 0.5 + pad);

        outsideLeft.pos(-pad, -pad);
        outsideLeft.size((screen.width - scene.width * scene.scaleX) * 0.5 + pad, screen.height + pad * 2);

        outsideRight.pos(scene.width * scene.scaleX + (screen.width - scene.width * scene.scaleX) * 0.5, -pad);
        outsideRight.size((screen.width - scene.width * scene.scaleX) * 0.5 + pad, screen.height + pad * 2);

    } //fitScene

/// Messages

    function receiveRawMessage(event:{data:String, origin:String, source:js.html.Window}) {

        // Ensure message comes from parent
        if (event.source != window.parent) {
            return;
        }

        // Parse message
        var message:Message = null;
        try {
            message = Json.parse(event.data);

            // Ping?
            if (message.type == 'ping') {
                parentOrigin = event.origin;
                window.parent.postMessage(Json.stringify({type: 'pong'}), parentOrigin);
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

        console.log(message);

        var parts = message.type.split('/');
        var service = parts[0];
        var action = parts[1];
        var value = message.value;

        switch (service) {

            case 'assets':
                if (action == 'lists') {
                    var rawList:Array<String> = value.list;
                    runtimeAssets = new RuntimeAssets(rawList);
                    var lists = runtimeAssets.getEncodableLists();
                    send({
                        type: 'assets/lists',
                        value: {
                            images: runtimeAssets.getNames('image'),
                            texts: runtimeAssets.getNames('text'),
                            sounds: runtimeAssets.getNames('sound'),
                            fonts: runtimeAssets.getNames('font'),
                            all: lists.all,
                            allDirs: lists.allDirs,
                            allByName: lists.allByName,
                            allDirsByName: lists.allDirsByName
                        }
                    });
                }

            case 'scene':
                if (value.name != 'scene') return;
                if (action == 'put') {
                    if (scene == null) {
                        scene = new Scene();
                        scene.color = 0x2f2f2f;
                        scene.anchor(0.5, 0.5);
                        scene.onDown(scene, function(info) {
                            if (Editable.highlight != null) {
                                Editable.highlight.destroy();
                            }
                        });
                        scene.deserializers.set('ceramic.Quad', function(scene:Scene, instance:Entity, item:SceneItem) {
                            if (item.props != null) {

                                var quad:Quad = cast instance;

                                function updateSize() {
                                    if (quad.texture != null) {
                                        if (item.props.width != quad.width || item.props.height != quad.height) {
                                            send({
                                                type: 'set/scene.item.${item.name}',
                                                value: {
                                                    width: quad.width,
                                                    height: quad.height
                                                }
                                            });
                                        }
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
                                            var asset:ImageAsset = existing != null ? existing : new ImageAsset(assetName, { premultiplyAlpha: true /* TODO REMOVE */ });
                                            if (existing == null) {
                                                // Create and load asset
                                                asset.runtimeAssets = runtimeAssets;
                                                assets.addAsset(asset);
                                                    asset.onceComplete(function(success) {
                                                        if (success && !instance.destroyed) {
                                                            quad.texture = assets.texture(assetName);
                                                            updateSize();
                                                        }
                                                    });
                                                assets.load();
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
                        });
                    }
                    scene.putData(value);
                    fitScene();
                }

            case 'scene-item':
                if (action == 'put') {
                    var entity = scene.putItem(value);
                    if (Std.is(entity, Visual)) {
                        if (!entity.hasComponent('editable')) {
                            entity.component('editable', new Editable(scene));
                        }
                    }
                }
                else if (action == 'select') {
                    var item = scene.getItem(value.name);
                    if (item != null && item.hasComponent('editable')) {
                        cast(item.component('editable'), Editable).select();
                    }
                }
                else if (action == 'delete') {
                    scene.removeItem(value.name);
                }

            default:

        } //switch

    } //receiveMessage

    public function send(message:Message):Void {

        // Send message to parent
        window.parent.postMessage(
            Json.stringify(message),
            parentOrigin
        );

    } //send

}
