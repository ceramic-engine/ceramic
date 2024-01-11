package ceramic;

import ceramic.Shortcuts.*;

enum abstract PinchStatus(Int) {

    var NONE = 0;

    var TOUCHING = 1;

    var PINCHING = 2;

}

/**
 * A pinch gesture detector that can be used as is or
 * plugged as a component to any `Visual` instance.
 * Supports scale, translation and rotation.
 */
class Pinch extends Entity implements Component {

    private static final NO_INDEX = -999999999;

    @entity var visual:Visual;

/// Events

    @event function beginPinch(originX:Float, originY:Float);

    @event function pinch(originX:Float, originY:Float, scale:Float, translateX:Float, translateY:Float, rotation:Float);

    @event function endPinch();

/// Lifecycle

    var pinchStatusDirty:Bool = false;

    var pinchMoveDirty:Bool = false;

    var status:PinchStatus = NONE;

    var startDistance:Float = 0;

    var startRotation:Float = 0;

    var firstTouchIndex:Int = NO_INDEX;

    var firstTouchStartX:Float = -1;

    var firstTouchStartY:Float = -1;

    var firstTouchLastX:Float = -1;

    var firstTouchLastY:Float = -1;

    var secondTouchIndex:Int = NO_INDEX;

    var secondTouchStartX:Float = -1;

    var secondTouchStartY:Float = -1;

    var secondTouchLastX:Float = -1;

    var secondTouchLastY:Float = -1;

    public function new() {

        super();

        app.onUpdate(this, update);

        screen.onMultiTouchPointerDown(this, pointerDown);
        screen.onMultiTouchPointerUp(this, pointerUp);
        screen.onMultiTouchPointerMove(this, pointerMove);

    }

    function bindAsComponent():Void {

        // Nothing to do but that needs to be there

    }

    function pointerDown(info:TouchInfo) {

        if (visual != null && !visual.computedTouchable) {
            return;
        }

        pinchStatusDirty = true;

    }

    function pointerUp(info:TouchInfo) {

        pinchStatusDirty = true;

    }

    function pointerMove(info:TouchInfo) {

        if (status != NONE) {
            pinchMoveDirty = true;
        }

    }

    function update(delta:Float) {

        var justTouching = false;

        if (pinchStatusDirty) {
            pinchStatusDirty = false;
            var numTouches = 0;
            for (touch in screen.touches) {
                if (visual != null) {
                    visual.hits(touch.x, touch.y);
                    numTouches++;
                }
                else {
                    numTouches++;
                }
            }
            if (numTouches >= 2) {
                if (status == NONE) {
                    status = TOUCHING;
                    justTouching = true;
                }
            }
            else {
                if (status == PINCHING) {
                    status = NONE;
                    emitEndPinch();
                }
                else {
                    status = NONE;
                }
            }
        }

        if (status == NONE)
            return;

        // Resolve proper touch indexes
        if (justTouching) {
            firstTouchIndex = NO_INDEX;
            secondTouchIndex = NO_INDEX;
        }

        var first:Touch = firstTouchIndex != NO_INDEX ? screen.touches.get(firstTouchIndex) : null;
        var second:Touch = secondTouchIndex != NO_INDEX ? screen.touches.get(secondTouchIndex) : null;

        if (first == null || second == null) {

            // If somehow we don't find the touches we were using previously,
            // or if it's the first time we need them, we walk through
            // all touches and resolve new touch indexes, giving priority
            // to lower touch indexes

            if (first == null) {
                firstTouchIndex = NO_INDEX;
            }
            if (second == null) {
                secondTouchIndex = NO_INDEX;
            }

            for (n in 0...2) {
                for (touch in screen.touches) {

                    // Give priority to touches that hit with the target visual
                    if (n == 0 && visual != null && !visual.hits(touch.x, touch.y)) {
                        continue;
                    }

                    // Skip indexes already used
                    if (touch.index == firstTouchIndex || touch.index == secondTouchIndex) {
                        continue;
                    }

                    if (firstTouchIndex == NO_INDEX) {
                        firstTouchIndex = touch.index;
                    }
                    else if (secondTouchIndex == NO_INDEX) {
                        if (touch.index < firstTouchIndex) {
                            secondTouchIndex = firstTouchIndex;
                            firstTouchIndex = touch.index;
                        }
                        else {
                            secondTouchIndex = touch.index;
                        }
                    }
                    else {
                        // Allow to reorder indexes if we are resolving new indexes anyway
                        // (resolving new indexes if first/second is null)
                        if (touch.index < firstTouchIndex && first == null) {
                            final prevFirstTouchIndex = firstTouchIndex;
                            firstTouchIndex = touch.index;
                            secondTouchIndex = prevFirstTouchIndex;
                        }
                        else if (touch.index < secondTouchIndex && second == null) {
                            secondTouchIndex = touch.index;
                        }
                    }
                }
            }
        }

        first = screen.touches.get(firstTouchIndex);
        second = screen.touches.get(secondTouchIndex);

        if (justTouching) {
            pinchMoveDirty = false;

            firstTouchStartX = first.x;
            firstTouchStartY = first.y;
            secondTouchStartX = second.x;
            secondTouchStartY = second.y;

            startDistance = Math.max(0.01, GeometryUtils.distance(firstTouchStartX, firstTouchStartY, secondTouchStartX, secondTouchStartY));
            startRotation = GeometryUtils.angleTo(firstTouchStartX, firstTouchStartY, secondTouchStartX, secondTouchStartY);

            firstTouchLastX = firstTouchStartX;
            firstTouchLastY = firstTouchStartY;
            secondTouchLastX = secondTouchStartX;
            secondTouchLastY = secondTouchStartY;
        }

        if (pinchMoveDirty) {
            pinchMoveDirty = false;

            if (firstTouchLastX != first.x || firstTouchLastY != first.y || secondTouchLastX != second.x || secondTouchLastY != second.y) {

                firstTouchLastX = first.x;
                firstTouchLastY = first.y;
                secondTouchLastX = second.x;
                secondTouchLastY = second.y;

                final originX = (firstTouchStartX + secondTouchStartX) * 0.5;
                final originY = (firstTouchStartY + secondTouchStartY) * 0.5;

                if (status == TOUCHING) {
                    status = PINCHING;
                    emitBeginPinch(originX, originY);
                }

                final centerX = (firstTouchLastX + secondTouchLastX) * 0.5;
                final centerY = (firstTouchLastY + secondTouchLastY) * 0.5;

                trace('first #$firstTouchIndex ($firstTouchLastX,$firstTouchLastY)');
                trace('second #$secondTouchIndex ($secondTouchLastX,$secondTouchLastY)');

                final currentDistance = GeometryUtils.distance(firstTouchLastX, firstTouchLastY, secondTouchLastX, secondTouchLastY);
                final currentRotation = GeometryUtils.angleTo(firstTouchLastX, firstTouchLastY, secondTouchLastX, secondTouchLastY);

                final scale:Float = startDistance != 0 ? (currentDistance / startDistance) : 1.0;

                final translateX = centerX - originX;
                final translateY = centerY - originY;

                final rotation = GeometryUtils.angleDelta(startRotation, currentRotation);

                emitPinch(originX, originY, scale, translateX, translateY, rotation);
            }
        }

    }

    override function destroy() {

        if (status == PINCHING) {
            status = NONE;
            emitEndPinch();
        }
        else {
            status = NONE;
        }

        super.destroy();

    }

}
