package editor;

import ceramic.Component;
import ceramic.Visual;
import ceramic.Fragment;
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

    var fragment:Fragment;

    var point:Point = { x: 0, y: 0 };

    function new(fragment:Fragment) {
        
        super();
        this.fragment = fragment;

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

        editor.send({
            type: 'set/ui.fragmentTab',
            value: 'visuals'
        });

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
                editor.send({
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
        editor.send({
            type: 'set/ui.selectedItemId',
            value: entity.id
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
        fragment.screenToVisual(screen.pointerX, screen.pointerY, point);
        var dragStartX = point.x;
        var dragStartY = point.y;

        function onMove(info:TouchInfo) {
            editor.render();

            fragment.screenToVisual(screen.pointerX, screen.pointerY, point);
            entity.x = entityStartX + point.x - dragStartX;
            entity.y = entityStartY + point.y - dragStartY;

        }
        screen.onMove(this, onMove);

        screen.onceUp(this, function(info) {
            editor.render();

            screen.offMove(onMove);

            entity.x = Math.round(entity.x);
            entity.y = Math.round(entity.y);

            // Update pos on react side
            editor.send({
                type: 'set/ui.selectedItem.x',
                value: entity.x
            });
            editor.send({
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
        var rotateTests = [
            1,
            0,
            -1
        ];
        var skewTests = [
            1,
            0,
            -1
        ];
        var singleScaleTests = [
            1,
            -1
        ];

        var anchorX = entity.anchorX;
        var anchorY = entity.anchorY;
        var tmpAnchorX = anchorX;
        var tmpAnchorY = anchorY;

        if (anchorX < 0.01 || anchorX > 0.99) {
            tmpAnchorX = switch (corner) {
                case TOP_LEFT: 1;
                case TOP_RIGHT: 0;
                case BOTTOM_LEFT: 1;
                case BOTTOM_RIGHT: 0;
            }
        }

        if (anchorY < 0.01 || anchorY > 0.99) {
            tmpAnchorY = switch (corner) {
                case TOP_LEFT: 1;
                case TOP_RIGHT: 1;
                case BOTTOM_LEFT: 0;
                case BOTTOM_RIGHT: 0;
            }
        }

        var scaleRatio = entity.scaleY / entity.scaleX;
        var startRotation = entity.rotation;
        var startScaleX = entity.scaleX;
        var startScaleY = entity.scaleY;
        var startSkewX = entity.skewX;
        var startSkewY = entity.skewY;

        entity.anchorKeepPosition(tmpAnchorX, tmpAnchorY);

        inline function distanceMain() {
            var a = screen.pointerX - cornerPoint.x;
            var b = screen.pointerY - cornerPoint.y;
            return Math.sqrt(a * a + b * b);
        }

        function onMove(info:TouchInfo) {
            editor.render();
            
            if (editor.xKeyPressed) {
                // Skew
                var skewStep = 0.5;
                var n = 0;
                var best = -1;

                // Put other values as started
                entity.scaleX = startScaleX;
                entity.scaleY = startScaleY;
                entity.rotation = startRotation;
                entity.skewY = startSkewY;

                while (n++ < 100) {

                    // Skew the visual to make the corner point closer
                    var skewX = entity.skewX;
                    var bestSkewX = skewX;
                    var bestDistance = distanceMain();

                    for (i in 0...skewTests.length) {
                        var test = skewTests[i];

                        var newSkewX = skewX + switch(test) {
                            case 1: skewStep;
                            case -1: -skewStep;
                            default: 0;
                        }

                        entity.skewX = newSkewX;
                        highlight.wrapVisual(entity);

                        // Is it better?
                        var dist = distanceMain();
                        if (dist < bestDistance) {
                            bestDistance = dist;
                            best = i;
                            bestSkewX = entity.skewX;
                        }
                    }

                    // Apply best transform
                    entity.skewX = bestSkewX;
                    highlight.wrapVisual(entity);

                    if (best == -1) {
                        skewStep *= 0.6;
                    }
                }

                // Snap to `common` skews?
                if (editor.shiftPressed) {
                    entity.skewX = Math.round(entity.skewX / 22.5) * 22.5;
                    highlight.wrapVisual(entity);
                }
            }
            else if (editor.yKeyPressed) {
                // Skew
                var skewStep = 0.5;
                var n = 0;
                var best = -1;

                // Put other values as started
                entity.scaleX = startScaleX;
                entity.scaleY = startScaleY;
                entity.rotation = startRotation;
                entity.skewX = startSkewX;

                while (n++ < 100) {

                    // Skew the visual to make the corner point closer
                    var skewY = entity.skewY;
                    var bestSkewY = skewY;
                    var bestDistance = distanceMain();

                    for (i in 0...skewTests.length) {
                        var test = skewTests[i];

                        var newSkewY = skewY + switch(test) {
                            case 1: skewStep;
                            case -1: -skewStep;
                            default: 0;
                        }

                        entity.skewY = newSkewY;
                        highlight.wrapVisual(entity);

                        // Is it better?
                        var dist = distanceMain();
                        if (dist < bestDistance) {
                            bestDistance = dist;
                            best = i;
                            bestSkewY = entity.skewY;
                        }
                    }

                    // Apply best transform
                    entity.skewY = bestSkewY;
                    highlight.wrapVisual(entity);

                    if (best == -1) {
                        skewStep *= 0.6;
                    }
                }

                // Snap to `common` skews?
                if (editor.shiftPressed) {
                    entity.skewY = Math.round(entity.skewY / 22.5) * 22.5;
                    highlight.wrapVisual(entity);
                }
            }
            else if (editor.rKeyPressed) {
                // Rotate
                var rotateStep = 0.5;
                var n = 0;
                var best = -1;

                // Put other values as started
                entity.scaleX = startScaleX;
                entity.scaleY = startScaleY;
                entity.skewX = startSkewX;
                entity.skewY = startSkewY;

                while (n++ < 100) {

                    // Rotate the visual to make the corner point closer
                    var rotation = entity.rotation;
                    var bestRotation = rotation;
                    var bestDistance = distanceMain();

                    for (i in 0...rotateTests.length) {
                        var test = rotateTests[i];

                        var newRotation = rotation + switch(test) {
                            case 1: rotateStep;
                            case -1: -rotateStep;
                            default: 0;
                        }

                        entity.rotation = newRotation;
                        highlight.wrapVisual(entity);

                        // Is it better?
                        var dist = distanceMain();
                        if (dist < bestDistance) {
                            bestDistance = dist;
                            best = i;
                            bestRotation = entity.rotation;
                        }
                    }

                    // Apply best transform
                    entity.rotation = bestRotation;
                    highlight.wrapVisual(entity);

                    if (best == -1) {
                        rotateStep *= 0.6;
                    }
                }

                // Snap to `common` angles?
                if (editor.shiftPressed) {
                    entity.rotation = Math.round(entity.rotation / 22.5) * 22.5;
                    highlight.wrapVisual(entity);
                }
            }
            else if (editor.wKeyPressed) {
                // Scale
                var scaleStep = 0.1;
                var n = 0;
                var best = -1;

                // Put other values as started
                entity.rotation = startRotation;
                entity.skewX = startSkewX;
                entity.skewY = startSkewY;
                entity.scaleY = startScaleY;

                while (n++ < 100) {

                    // Scale the visual to make the corner point closer
                    best = -1;
                    var scaleX = entity.scaleX;
                    var bestScaleX = scaleX;
                    var bestDistance = distanceMain();

                    for (i in 0...singleScaleTests.length) {
                        var test = singleScaleTests[i];

                        var newScaleX = scaleX + switch(test) {
                            case 1: scaleStep;
                            case -1: -scaleStep;
                            default: 0;
                        }

                        entity.scaleX = newScaleX;
                        highlight.wrapVisual(entity);

                        // Is it better?
                        var dist = distanceMain();
                        if (dist < bestDistance) {
                            bestDistance = dist;
                            best = i;
                            bestScaleX = entity.scaleX;
                        }
                    }

                    // Apply best transform
                    entity.scaleX = bestScaleX;
                    highlight.wrapVisual(entity);

                    if (best == -1) {
                        scaleStep *= 0.9;
                    }
                }

                // Round scales?
                if (editor.shiftPressed) {
                    entity.scaleX = Math.round(entity.scaleX * 10) / 10;
                    highlight.wrapVisual(entity);
                }

            }
            else if (editor.hKeyPressed) {
                // Scale
                var scaleStep = 0.1;
                var n = 0;
                var best = -1;

                // Put other values as started
                entity.rotation = startRotation;
                entity.skewX = startSkewX;
                entity.skewY = startSkewY;
                entity.scaleX = startScaleX;

                while (n++ < 100) {

                    // Scale the visual to make the corner point closer
                    best = -1;
                    var scaleY = entity.scaleY;
                    var bestScaleY = scaleY;
                    var bestDistance = distanceMain();

                    for (i in 0...singleScaleTests.length) {
                        var test = singleScaleTests[i];

                        var newScaleY = scaleY + switch(test) {
                            case 1: scaleStep;
                            case -1: -scaleStep;
                            default: 0;
                        }

                        entity.scaleY = newScaleY;
                        highlight.wrapVisual(entity);

                        // Is it better?
                        var dist = distanceMain();
                        if (dist < bestDistance) {
                            bestDistance = dist;
                            best = i;
                            bestScaleY = entity.scaleY;
                        }
                    }

                    // Apply best transform
                    entity.scaleY = bestScaleY;
                    highlight.wrapVisual(entity);

                    if (best == -1) {
                        scaleStep *= 0.9;
                    }
                }

                // Round scales?
                if (editor.shiftPressed) {
                    entity.scaleY = Math.round(entity.scaleY * 10) / 10;
                    highlight.wrapVisual(entity);
                }

            }
            else {
                // Scale
                var scaleStep = 0.1;
                var n = 0;
                var best = -1;

                // Put other values as started
                entity.rotation = startRotation;
                entity.skewX = startSkewX;
                entity.skewY = startSkewY;

                while (n++ < 100) {

                    // Scale the visual to make the corner point closer
                    best = -1;
                    var scaleX = entity.scaleX;
                    var scaleY = entity.scaleY;
                    var bestScaleX = scaleX;
                    var bestScaleY = scaleY;
                    var bestDistance = distanceMain();

                    for (i in 0...scaleTests.length) {
                        var test = scaleTests[i];

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

                // Round scales?
                if (editor.shiftPressed) {
                    entity.scaleX = Math.round(entity.scaleX * 10) / 10;
                    entity.scaleY = Math.round(entity.scaleY * 10) / 10;
                    highlight.wrapVisual(entity);
                }

                // Keep aspect ratio?
                if (editor.aKeyPressed) {
                    var bestScaleX = entity.scaleX;
                    entity.scaleX = bestScaleX;
                    entity.scaleY = bestScaleX * scaleRatio;
                    highlight.wrapVisual(entity);
                }
            }
            
        }
        screen.onMove(this, onMove);

        screen.onceUp(this, function(info) {
            editor.render();

            screen.offMove(onMove);

            entity.anchorKeepPosition(anchorX, anchorY);
            entity.x = Math.round(entity.x);
            entity.y = Math.round(entity.y);
            entity.scaleX = Math.round(entity.scaleX * 1000) / 1000.0;
            entity.scaleY = Math.round(entity.scaleY * 1000) / 1000.0;
            var skewX = entity.skewX;
            while (skewX <= -360) skewX += 360;
            while (skewX >= 360) skewX -= 360;
            entity.skewX = Math.round(skewX * 100) / 100.0;
            var skewY = entity.skewY;
            while (skewY <= -360) skewY += 360;
            while (skewY >= 360) skewY -= 360;
            entity.skewY = Math.round(skewY * 100) / 100.0;
            var rotation = entity.rotation;
            while (rotation <= -360) rotation += 360;
            while (rotation >= 360) rotation -= 360;
            entity.rotation = Math.round(rotation * 100) / 100.0;

            // Update pos & scale on react side
            editor.send({
                type: 'set/ui.selectedItem.x',
                value: entity.x
            });
            editor.send({
                type: 'set/ui.selectedItem.y',
                value: entity.y
            });
            editor.send({
                type: 'set/ui.selectedItem.scaleX',
                value: entity.scaleX
            });
            editor.send({
                type: 'set/ui.selectedItem.scaleY',
                value: entity.scaleY
            });
            editor.send({
                type: 'set/ui.selectedItem.skewX',
                value: entity.skewX
            });
            editor.send({
                type: 'set/ui.selectedItem.skewY',
                value: entity.skewY
            });
            editor.send({
                type: 'set/ui.selectedItem.rotation',
                value: entity.rotation
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
