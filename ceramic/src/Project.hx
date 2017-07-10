package;

import ceramic.Entity;
import ceramic.Color;
import ceramic.Quad;
import ceramic.Settings;
import ceramic.Assets;
import ceramic.Scene;
import ceramic.Shortcuts.*;

import js.Browser.*;
import haxe.Json;

using StringTools;

class Project extends Entity {

    var parentOrigin:String = null;

    var scenes:Map<String, Scene> = new Map();

    function new(settings:InitSettings) {

        settings.antialiasing = true;
        settings.background = 0x282828;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FIT;

        app.onceReady(ready);

    } //new

    function ready() {

        // Setup
        //layout();
        window.addEventListener('resize', function() updateCanvas());
        screen.onResize(this, function() {
            trace("ON RESIZE (ceramic) nativeWidth=" + screen.nativeWidth + " nativeHeight=" + screen.nativeHeight);
        });
        updateCanvas();

        // Receive messages
        window.addEventListener('message', receiveRawMessage);

/*
        // TODO
        var quad1 = new Quad();
        quad1.color = Color.RED;
        quad1.depth = 2;
        quad1.size(50, 50);
        quad1.anchor(0.5, 0.5);
        quad1.pos(screen.width * 0.5, screen.height * 0.5);
        quad1.rotation = 30;
        quad1.scale(2.0, 0.5);

        var quad2 = new Quad();
        quad2.depth = 1;
        quad2.color = Color.YELLOW;
        quad2.size(50, 50);
        quad2.anchor(0.5, 0.5);
        quad2.pos(640 * 0.5, 480 * 0.5 + 20);
        quad2.rotation = 30;
        quad2.scale(2.0, 0.5);

        app.onUpdate(this, function(delta) {

            quad1.rotation = (quad1.rotation + delta * 100) % 360;
            quad2.rotation = (quad2.rotation + delta * 100) % 360;

        });

        trace("STARTED CERAMIC PART");
*/

    } //ready

    function updateCanvas() {

        var appEl:js.html.CanvasElement = cast document.getElementById('app');
        appEl.style.margin = '0 0 0 0';
        appEl.style.width = window.innerWidth + 'px';
        appEl.style.height = window.innerHeight + 'px';
        appEl.width = Math.round(window.innerWidth * window.devicePixelRatio);
        appEl.height = Math.round(window.innerHeight * window.devicePixelRatio);

        trace('screen width='+screen.width+' height='+screen.height);

    } //layout

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

    } //receiveRawMessage

    function receiveMessage(message:Message) {

        console.log(message);

        var parts = message.type.split('/');
        var collection = parts[0];
        var action = parts[1];
        var value = message.value;

        switch (collection) {

            case 'scene':
                var scene:Scene = scenes.get(value.name);
                if (action == 'put') {
                    if (scene == null) {
                        scene = new Scene();
                        scene.color = 0x2f2f2f;
                        scenes.set(value.name, scene);
                    }
                    scene.sceneData = value;
                }

            default:

        } //switch

    } //receiveMessage

}
