package editor;

import ceramic.Component;
import ceramic.Visual;
import ceramic.Scene;
import ceramic.Point;
import ceramic.Color;
import ceramic.Quad;
import ceramic.Transform;
import ceramic.TouchInfo;
import ceramic.Shortcuts.*;

import editor.Highlight;
import editor.MouseHint;

class Editable extends Component {

    public static var highlight:Highlight;

    public static var hint:MouseHint;

    static var active:Editable = null;

    var entity:Visual;

    var scene:Scene;

    var point:Point = { x: 0, y: 0 };

    function new(scene:Scene) {
        
        super();
        this.scene = scene;

    } //new

    function init() {

        entity.onDown(this, handleDown);

    } //init

    function destroy() {

        if (active == this && highlight != null) {
            highlight.destroy();
        }

        if (active == this && hint != null) {
            hint.destroy();
        }

    } //destroy

/// Public API

    public function select() {

        if (active == this) return;
        active = this;
        
        if (highlight != null) {
            highlight.destroy();
        }
        highlight = new Highlight();
        highlight.onceDestroy(function() {

            highlight.offCornerDown(handleCornerDown);
            highlight.offCornerOver(handleCornerOver);
            highlight.offCornerOut(handleCornerOut);

            if (active == this) {
                active = null;

                // Set selected item
                project.send({
                    type: 'set/ui.selectedItemId',
                    value: null
                });
            }
            app.offUpdate(update);
            highlight = null;
        });

        highlight.anchor(0, 0);
        highlight.pos(0, 0);
        highlight.depth = 99999;
        highlight.transform = new Transform();
        highlight.wrapVisual(entity);

        highlight.onCornerDown(this, handleCornerDown);
        highlight.onCornerOver(this, handleCornerOver);
        highlight.onCornerOut(this, handleCornerOut);

        app.onUpdate(this, update);

        // Set selected item
        project.send({
            type: 'set/ui.selectedItemId',
            value: entity.id
        });
        project.send({
            type: 'set/ui.sceneTab',
            value: 1 // Visuals tab
        });

    } //select

    function update(_) {

        if (active != this) return;

        highlight.wrapVisual(entity);

    } //update

/// Clicked

    function handleDown(info:TouchInfo) {

        // Ensure this item is selected
        select();

        // Start dragging
        var entityStartX = entity.x;
        var entityStartY = entity.y;
        scene.screenToVisual(screen.pointerX, screen.pointerY, point);
        var dragStartX = point.x;
        var dragStartY = point.y;

        function onMove(info:TouchInfo) {
            project.render();

            scene.screenToVisual(screen.pointerX, screen.pointerY, point);
            entity.x = entityStartX + point.x - dragStartX;
            entity.y = entityStartY + point.y - dragStartY;

        }
        screen.onMove(this, onMove);

        screen.onceUp(this, function(info) {
            project.render();

            screen.offMove(onMove);

            entity.x = Math.round(entity.x);
            entity.y = Math.round(entity.y);

            // Update pos on react side
            project.send({
                type: 'set/ui.selectedItem.x',
                value: entity.x
            });
            project.send({
                type: 'set/ui.selectedItem.y',
                value: entity.y
            });

        });

    } //handleDown

/// Corner clicked

    function handleCornerDown(corner:HighlightCorner, info:TouchInfo) {

        var cornerPoint = switch (corner) {
            case TOP_LEFT: highlight.pointTopLeft;
            case TOP_RIGHT: highlight.pointTopRight;
            case BOTTOM_LEFT: highlight.pointBottomLeft;
            case BOTTOM_RIGHT: highlight.pointBottomRight;
        }

        var scaleTests = [
            [1, -1],
            [1, 0],
            [1, 1],
            [0, 1],
            [0, -1],
            [-1, -1],
            [-1, 0],
            [-1, 1]
        ];
        var tests = [];
        for (scaleTest in scaleTests) {
            tests.push(scaleTest);
        }

        var anchorX = entity.anchorX;
        var anchorY = entity.anchorY;
        var tmpAnchorX = anchorX;
        var tmpAnchorY = anchorY;

        if (anchorX != 0.5) {
            tmpAnchorX = switch (corner) {
                case TOP_LEFT: 1;
                case TOP_RIGHT: 0;
                case BOTTOM_LEFT: 1;
                case BOTTOM_RIGHT: 0;
            }
        }

        if (anchorY != 0.5) {
            tmpAnchorY = switch (corner) {
                case TOP_LEFT: 1;
                case TOP_RIGHT: 1;
                case BOTTOM_LEFT: 0;
                case BOTTOM_RIGHT: 0;
            }
        }

        entity.anchorKeepPosition(tmpAnchorX, tmpAnchorY);

        inline function distanceMain() {
            var a = screen.pointerX - cornerPoint.x;
            var b = screen.pointerY - cornerPoint.y;
            return Math.sqrt(a * a + b * b);
        }

        function onMove(info:TouchInfo) {
            project.render();
            
            var scaleStep = 0.1;
            var n = 0;
            var best = -1;
            var matched = false;

            while (n++ < 100) {

                // Scale the visual to make the corner point closer
                best = -1;
                var scaleX = entity.scaleX;
                var scaleY = entity.scaleY;
                var bestScaleX = scaleX;
                var bestScaleY = scaleY;
                var bestDistance = distanceMain();

                for (i in 0...tests.length) {
                    var test = tests[i];

                    var newScaleX = scaleX + switch(test[0]) {
                        case 1: scaleStep;
                        case -1: -scaleStep;
                        default: 0;
                    }
                    var newScaleY = scaleY + switch(test[1]) {
                        case 1: scaleStep;
                        case -1: -scaleStep;
                        default: 0;
                    }

                    entity.scaleX = newScaleX;
                    entity.scaleY = newScaleY;
                    highlight.wrapVisual(entity);

                    // Is it better?
                    var dist = distanceMain();
                    if (dist < bestDistance) {
                        matched = true;
                        bestDistance = dist;
                        best = i;
                        bestScaleX = entity.scaleX;
                        bestScaleY = entity.scaleY;
                    }
                }

                // Apply best transform
                entity.scaleX = bestScaleX;
                entity.scaleY = bestScaleY;
                highlight.wrapVisual(entity);

                if (best == -1) {
                    scaleStep *= 0.9;
                }
            }
        }
        screen.onMove(this, onMove);

        screen.onceUp(this, function(info) {
            project.render();

            screen.offMove(onMove);

            entity.anchorKeepPosition(anchorX, anchorY);
            entity.x = Math.round(entity.x);
            entity.y = Math.round(entity.y);
            entity.scaleX = Math.round(entity.scaleX * 1000) / 1000.0;
            entity.scaleY = Math.round(entity.scaleY * 1000) / 1000.0;

            // Update pos & scale on react side
            project.send({
                type: 'set/ui.selectedItem.x',
                value: entity.x
            });
            project.send({
                type: 'set/ui.selectedItem.y',
                value: entity.y
            });
            project.send({
                type: 'set/ui.selectedItem.scaleX',
                value: entity.scaleX
            });
            project.send({
                type: 'set/ui.selectedItem.scaleY',
                value: entity.scaleY
            });

        });

    } //handleCornerDown

    function handleCornerOver(corner:HighlightCorner, info:TouchInfo) {

        /*untyped console.debug('CORNER OVER ' + corner);

        if (hint == null) {
            hint = new MouseHint();
        }

        var allCornerPoints = [
            highlight.pointTopLeft,
            highlight.pointTopRight,
            highlight.pointBottomLeft,
            highlight.pointBottomRight
        ];
        var cornerPoint = switch(corner) {
            case TOP_LEFT: highlight.pointTopLeft;
            case TOP_RIGHT: highlight.pointTopRight;
            case BOTTOM_LEFT: highlight.pointBottomLeft;
            case BOTTOM_RIGHT: highlight.pointBottomRight;
        }

        var isMostLeft = true;
        var isMostRight = true;
        for (point in allCornerPoints) {
            if (point != cornerPoint) {
                if (point.x < cornerPoint.x) {
                    isMostLeft = false;
                }
                else if (point.x > cornerPoint.x) {
                    isMostRight = false;
                }
            }
        }

        if (isMostLeft) {
            hint.text.anchor(1, 0.5);
            hint.y = cornerPoint.y - 13;
            hint.x = cornerPoint.x - 12;
        }
        else {
            hint.text.anchor(0, 0.5);
            hint.y = cornerPoint.y - 13;
            hint.x = cornerPoint.x + 10;
        }

        project.render();*/

    } //handleCornerOver

    function handleCornerOut(corner:HighlightCorner, info:TouchInfo) {

        /*untyped console.debug('CORNER OUT ' + corner);

        if (hint != null) {
            hint.destroy();
            hint = null;
        }


        project.render();*/

    } //handleCornerOut

} //Editable
