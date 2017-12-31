package;

import ceramic.InitSettings;
import ceramic.Entity;
import ceramic.Quad;
import ceramic.RenderTexture;
import ceramic.Mesh;
import ceramic.Color;
import ceramic.AlphaColor;
import ceramic.Assets;
import ceramic.Blending;
import ceramic.Text;
import ceramic.Images;
import ceramic.Fonts;
import ceramic.Texts;
import ceramic.Sounds;
import ceramic.Shortcuts.*;

class Project extends Entity {

    var assets:Assets = new Assets();

    function new(settings:InitSettings) {

#if editor

        new editor.Editor(settings);
        app.onceReady(editor, editor.start);

#else

        settings.antialiasing = true;
        settings.background = 0x444444;
        settings.resizable = true;
        settings.scaling = FIT;
        settings.targetWidth = 800;
        settings.targetHeight = 600;

        app.onceReady(this, ready);

#end

    } //new

    function ready() {

        log("READY");

        //assets.add(Images.PANORAMA);

        assets.onceComplete(this, function(success) {
            if (!success) return;
            assetsLoaded();
        });

        assets.load();

    } //ready
    
    function assetsLoaded() {

        log("ASSETS LOADED");

        //var panorama = assets.texture(Images.PANORAMA);
        //log(panorama);
        var buff = new RenderTexture(800, 600, 1);

        var scale = 1.0;
        
        var quad1 = new Quad();
        quad1.color = Color.RED;
        quad1.depth = 2;
        quad1.size(50, 50);
        quad1.anchor(0.5, 0.5);
        quad1.pos(100 * scale, 200 * scale);
        quad1.rotation = 30;
        quad1.scale(2.0 * scale, 0.5 * scale);
        quad1.id = 'quad1';
        quad1.renderTarget = buff;

        var quad2 = new Quad();
        quad2.depth = 1;
        quad2.color = Color.YELLOW;
        quad2.size(50, 50);
        quad2.anchor(0.5, 0.5);
        quad2.pos(100 * scale, 200 * scale + 20 * scale);
        quad2.rotation = 30;
        quad2.scale(2.0 * scale, 0.5 * scale);
        quad2.id = 'quad2';
        quad2.renderTarget = buff;

        app.onUpdate(this, function(delta) {

            quad1.rotation = (quad1.rotation + delta * 100) % 360;
            quad2.rotation = (quad2.rotation + delta * 100) % 360;

            //text.skewX = (text.skewX + delta * 100) % 360;

        });

        var quad3 = new Quad();
        quad3.size(800, 600);
        quad3.texture = buff;

/*
        var mesh = new Mesh();
        mesh.scale(2.0);

        mesh.texture = buff;
        mesh.pos(screen.width * 0.5, screen.height * 0.5);

        mesh.colors = [0xFFFFFFFF];
        mesh.vertices = [
            -100, -100,
            100, -100,
            100, 100,
            -100, 100,
            
            100, -100,
            200, -100, // 110
            200, 100, // 130
            100, 100,
            
            -200, -150,
            -100, -100,
            -100, 100,
            -200, 150,
            -150, 0 // center
        ];
        mesh.uvs = [
            0.25, 0,
            0.75, 0,
            0.75, 1,
            0.25, 1,

            0.75, 0,
            1, 0,
            1, 1,
            0.75, 1,

            0, 0,
            0.25, 0,
            0.25, 1,
            0, 1,
            0.125, 0.5
        ];
        mesh.indices = [
            0, 1, 2, 3, 0, 2,
            4 + 0, 4 + 1, 4 + 2, 4 + 3, 4 + 0, 4 + 2,

            4 * 2 + 0,
            4 * 2 + 1,
            4 * 2 + 4,

            4 * 2 + 1,
            4 * 2 + 2,
            4 * 2 + 4,

            4 * 2 + 3,
            4 * 2 + 0,
            4 * 2 + 4,

            4 * 2 + 4,
            4 * 2 + 2,
            4 * 2 + 3
        ];
*/
    } //assetsLoaded

    function ready_() {

        var quad1 = new Quad();
        quad1.color = Color.RED;
        quad1.depth = 2;
        quad1.size(50, 50);
        quad1.anchor(0.5, 0.5);
        quad1.pos(320 * 0.5, 568 * 0.5);
        quad1.rotation = 30;
        quad1.scale(2.0, 0.5);
        quad1.id = 'quad1';

        var quad2 = new Quad();
        quad2.depth = 1;
        quad2.color = Color.YELLOW;
        quad2.size(50, 50);
        quad2.anchor(0.5, 0.5);
        quad2.pos(320 * 0.5, 568 * 0.5 + 20);
        quad2.rotation = 30;
        quad2.scale(2.0, 0.5);
        quad2.id = 'quad2';

        var text = new Text();
        text.content = "Jérémy.\nligne.";
        //text.rotation = 45;
        text.pointSize = 20;
        text.color = Color.YELLOW;
        text.pos(40, 40);

        trace('text width=${text.width} height=${text.height}');

        screen.onDown(this, function(info) {
            //Luxe.audio.suspend();
            if (settings.targetDensity == 2) {
                settings.targetDensity = 1;
            } else {
                settings.targetDensity = 2;
            }
            /*app.onceUpdate(function(delta) {
                app.onceUpdate(function(delta) {
                    Luxe.audio.resume();
                });
            });*/
        });

        /*app.onKeyDown(this, function(key) {
            trace('KEY DOWN: $key');
        });
        app.onKeyUp(this, function(key) {
            trace('KEY UP: $key');
        });

        screen.onMouseDown(this, function(buttonId, x, y) {
            trace('MOUSE DOWN $buttonId $x,$y');
        });

        screen.onMouseMove(this, function(x, y) {
            trace('      MOVE $x,$y');
        });

        screen.onMouseUp(this, function(buttonId, x, y) {
            trace('MOUSE UP $buttonId $x,$y');
        });

        screen.onTouchDown(this, function(touchIndex, x, y) {
            trace('TOUCH DOWN $touchIndex $x,$y');
        });

        screen.onTouchMove(this, function(touchIndex, x, y) {
            trace('TOUCH MOVE $touchIndex $x,$y');
        });

        screen.onTouchUp(this, function(touchIndex, x, y) {
            trace('TOUCH UP $touchIndex $x,$y');
        });*/

        var itemStartX = 0.0;
        var itemStartY = 0.0;
        var dragStartX = 0.0;
        var dragStartY = 0.0;
        var dragging = false;
        function onMove(x:Float, y:Float) {
            if (dragging) {
                quad1.pos(itemStartX + x - dragStartX, itemStartY + y - dragStartY);
            } else {
                trace('NOT DRAGGING');
            }
        }
        quad1.onDown(this, function(info) {
            trace('quad1 DOWN ' + info.x + ',' + info.y);
            itemStartX = quad1.x;
            itemStartY = quad1.y;
            dragStartX = info.x;
            dragStartY = info.y;
            dragging = true;

            screen.onMouseMove(onMove);
        });

        quad1.onUp(this, function(info) {
            dragging = false;
            screen.offMouseMove(onMove);
        });

        var mesh = new Mesh();
        mesh.vertices = [
            10, 10,
            100, 20,
            25, 150
        ];
        //mesh.indices = [0,1,2,2,3,0];
        mesh.indices = [0,1,2];
        var color = new AlphaColor(Color.WHITE);
        for (i in 0...mesh.vertices.length) {
            mesh.colors.push(color);
            mesh.uvs.push(mesh.vertices[i*2] / screen.width);
            mesh.uvs.push(mesh.vertices[i*2+1] / screen.height);
        }

        /*
        // Just an idea
        var tween = new Tween(easeInOut, 0.3, 3, 4);
        tween.onUpdate(this, function(v) {
            this.alpha = v;
        });
        */

        //assets.addFont(te);
        //assets.addFont(Fonts.BALOO_20);

        assets.add(Fonts.BALOO_20);
        assets.add(Images.TILESHEET);
        assets.add(Sounds.LASER_4);
        assets.add(Sounds.MISCHIEF_STROLL);

        assets.onceComplete(this, function(success) {
            log('success? ' + success);
            if (!success) return;

            var font = assets.font(Fonts.BALOO_20);
            trace('font = $font');
            /*ceramic.Timer.delay(1.0, function() {
                text.font = font;
            });*/

            mesh.texture = assets.texture(Images.TILESHEET);

            trace('text width=${text.width} height=${text.height}');

            var tilesheet = new Quad();
            tilesheet.pos(150, 200);
            tilesheet.texture = assets.texture(Images.TILESHEET);

            var laser = assets.sound(Sounds.LASER_4);
            var music = assets.sound(Sounds.MISCHIEF_STROLL);

            quad2.onDown(this, function(info) {
                trace('PLAY laser');
                laser.play();
            });

            music.play(0, true);

        });

        assets.load();

        screen.onResize(this, function() {

            log('RESIZE width='+screen.width+' height='+screen.height+' density='+screen.density);

        });

        app.onUpdate(this, function(delta) {

            quad1.rotation = (quad1.rotation + delta * 100) % 360;
            quad2.rotation = (quad2.rotation + delta * 100) % 360;

            //text.skewX = (text.skewX + delta * 100) % 360;

        });

    } //ready

} //Project
