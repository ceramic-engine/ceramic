package;

import ceramic.Entity;
import ceramic.Settings;
import ceramic.Scene;
import ceramic.Timer;
import ceramic.Quad;
import ceramic.Visual;
import ceramic.RuntimeAssets;
import ceramic.Shortcuts.*;

import editor.Message;
import editor.Editable;

import js.Browser.*;
import haxe.Json;

using StringTools;

class Project extends Entity {

    var parentOrigin:String = null;

    var scene:Scene = null;

    var outsideTop:Quad = null;

    var outsideRight:Quad = null;

    var outsideBottom:Quad = null;

    var outsideLeft:Quad = null;

    var renders:Int = 0;

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
            screen.width / (scene.width / scene.scaleX),
            screen.height / (scene.height / scene.scaleY)
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
        outsideTop.size(screen.width + pad * 2, (screen.height - scene.height) * 0.5 + pad);

        outsideBottom.pos(-pad, scene.height + (screen.height - scene.height) * 0.5);
        outsideBottom.size(screen.width + pad * 2, (screen.height - scene.height) * 0.5 + pad);

        outsideLeft.pos(-pad, -pad);
        outsideLeft.size((screen.width - scene.width) * 0.5 + pad, screen.height + pad * 2);

        outsideRight.pos(scene.width + (screen.width - scene.width) * 0.5, -pad);
        outsideRight.size((screen.width - scene.width) * 0.5 + pad, screen.height + pad * 2);

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
                    var assets = new RuntimeAssets(rawList);
                    var lists = assets.getEncodableLists();
                    send({
                        type: 'assets/lists',
                        value: {
                            images: assets.getNames('image'),
                            texts: assets.getNames('text'),
                            sounds: assets.getNames('sound'),
                            fonts: assets.getNames('font'),
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
