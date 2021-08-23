package elements;

import ceramic.Click;
import ceramic.Component;
import ceramic.Entity;
import ceramic.Point;
import ceramic.Shortcuts.*;
import ceramic.TouchInfo;
import ceramic.Visual;
import tracker.Observable;

class DragDrop extends Entity implements Component implements Observable {

    static var _point = new Point(0, 0);

    @observe public var dragging:Bool = false;

    @observe public var dragX(default, null):Float = 0;

    @observe public var dragY(default, null):Float = 0;

    public var click:Click;

    public var getDraggingVisual:Void->Visual = null;

    public var releaseDraggingVisual:Visual->Void = null;

    public var threshold:Float;

    public var draggingVisual(default, null):Visual = null;

    var entity:Visual;

    var visualDragStartX:Float = 0;

    var visualDragStartY:Float = 0;

    var pointerDownX:Float = 0;

    var pointerDownY:Float = 0;

    var pointerDragStartX:Float = 0;

    var pointerDragStartY:Float = 0;

    var isPointerDown:Bool = false;

    public function new(threshold:Float = 4.0, ?click:Click, getDraggingVisual:Void->Visual, releaseDraggingVisual:Visual->Void) {

        super();

        this.click = click;
        this.threshold = threshold;
        this.getDraggingVisual = getDraggingVisual;
        this.releaseDraggingVisual = releaseDraggingVisual;

    }

    function bindAsComponent() {

        entity.onPointerDown(this, handlePointerDown);

    }

    public function drag(?pointerX:Float, ?pointerY:Float) {

        if (pointerX == null)
            pointerX = screen.pointerX;
        if (pointerY == null)
            pointerY = screen.pointerY;

        if (dragging) {
            log.warning('Already dragging!');
            return;
        }

        dragging = true;

        if (click != null) {
            click.cancel();
        }

        if (!isPointerDown) {
            var focusedVisual = screen.focusedVisual;
            if (focusedVisual != null) {
                focusedVisual.oncePointerUp(this, handlePointerUp);
            }
            else {
                screen.oncePointerUp(this, handlePointerUp);
            }
        }

        draggingVisual = getDraggingVisual();

        visualDragStartX = _point.x;
        visualDragStartY = _point.y;

        pointerDragStartX = pointerX;
        pointerDragStartY = pointerY;

        dragX = 0;
        dragY = 0;

    }

    function handlePointerDown(info:TouchInfo) {

        isPointerDown = true;

        pointerDownX = info.x;
        pointerDownY = info.y;

        screen.onPointerMove(this, handlePointerMove);
        entity.oncePointerUp(this, handlePointerUp);

    }

    function handlePointerMove(info:TouchInfo) {

        if (dragging) {
            updateDrag(info.x, info.y);
        }
        else {
            if (Math.abs(info.x - pointerDownX) > threshold || Math.abs(info.y - pointerDownY) > threshold) {
                drag(pointerDownX, pointerDownY);
                updateDrag(info.x, info.y);
            }
        }

    }

    function handlePointerUp(info:TouchInfo) {

        screen.offPointerMove(handlePointerMove);

        if (dragging) {
            dragging = false;
        }

        if (draggingVisual != null) {
            if (releaseDraggingVisual != null) {
                releaseDraggingVisual(draggingVisual);
            }
            else {
                draggingVisual = null;
            }
        }

    }

    function updateDrag(pointerX:Float, pointerY:Float) {

        if (draggingVisual.parent != null) {
            draggingVisual.parent.screenToVisual(
                pointerDragStartX,
                pointerDragStartY,
                _point
            );
            var startX = _point.x;
            var startY = _point.y;
            draggingVisual.parent.screenToVisual(
                pointerX,
                pointerY,
                _point
            );
            dragX = _point.x - startX;
            dragY = _point.y - startY;
        }
        else {
            dragX = pointerX - pointerDragStartX;
            dragY = pointerY - pointerDragStartY;
        }

    }

}
