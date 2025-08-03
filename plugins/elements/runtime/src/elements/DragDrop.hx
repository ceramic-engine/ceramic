package elements;

import ceramic.Click;
import ceramic.Component;
import ceramic.Entity;
import ceramic.Point;
import ceramic.Shortcuts.*;
import ceramic.TouchInfo;
import ceramic.Visual;
import tracker.Observable;

/**
 * A component that enables drag-and-drop functionality for visuals.
 * 
 * This component handles the complete drag-and-drop lifecycle:
 * - Detecting drag initiation based on pointer movement threshold
 * - Creating and managing a dragging visual representation
 * - Tracking drag position updates
 * - Handling drag completion and visual cleanup
 * 
 * The component can work with custom visual factories to create drag representations
 * and provides observable properties for tracking drag state and position.
 * 
 * Example usage:
 * ```haxe
 * var dragDrop = new DragDrop(
 *     5.0, // threshold
 *     clickComponent,
 *     () -> createDragVisual(),
 *     (visual) -> recycleDragVisual(visual)
 * );
 * myVisual.component('dragDrop', dragDrop);
 * 
 * // Listen to drag events
 * dragDrop.onDraggingChange(this, dragging -> {
 *     if (dragging) trace('Started dragging');
 *     else trace('Stopped dragging');
 * });
 * ```
 * 
 * @see CellView For usage in draggable cells
 * @see Window For draggable window implementation
 */
class DragDrop extends Entity implements Component implements Observable {

    /**
     * Shared point instance for coordinate conversions.
     */
    static var _point = new Point(0, 0);

    /**
     * Whether a drag operation is currently active.
     * Observable property that changes when dragging starts/stops.
     */
    @observe public var dragging:Bool = false;

    /**
     * The current horizontal drag offset from the drag start position.
     * Updated continuously during drag operations.
     */
    @observe public var dragX(default, null):Float = 0;

    /**
     * The current vertical drag offset from the drag start position.
     * Updated continuously during drag operations.
     */
    @observe public var dragY(default, null):Float = 0;

    /**
     * Optional click component to cancel when drag starts.
     * Prevents click events from firing when the user drags.
     */
    public var click:Click;

    /**
     * Factory function to create the visual shown during dragging.
     * Called when drag operation starts.
     * Should return a Visual that represents the dragged content.
     */
    public var getDraggingVisual:Void->Visual = null;

    /**
     * Function to handle cleanup when dragging ends.
     * Called with the dragging visual to allow recycling or disposal.
     * If null, the dragging visual reference is simply cleared.
     */
    public var releaseDraggingVisual:Visual->Void = null;

    /**
     * Minimum pointer movement distance to initiate drag.
     * Prevents accidental drags from small movements.
     */
    public var threshold:Float;

    /**
     * The visual being displayed during drag operation.
     * Created by getDraggingVisual and cleaned up by releaseDraggingVisual.
     */
    public var draggingVisual(default, null):Visual = null;

    /**
     * The visual entity this component is attached to.
     */
    var entity:Visual;

    /**
     * Initial X position of the dragging visual.
     */
    var visualDragStartX:Float = 0;

    /**
     * Initial Y position of the dragging visual.
     */
    var visualDragStartY:Float = 0;

    /**
     * X position where pointer was initially pressed.
     */
    var pointerDownX:Float = 0;

    /**
     * Y position where pointer was initially pressed.
     */
    var pointerDownY:Float = 0;

    /**
     * X position where drag operation started.
     */
    var pointerDragStartX:Float = 0;

    /**
     * Y position where drag operation started.
     */
    var pointerDragStartY:Float = 0;

    /**
     * Whether pointer is currently pressed down.
     */
    var isPointerDown:Bool = false;

    /**
     * Creates a new DragDrop component.
     * @param threshold Minimum pointer movement to start drag (default: 4.0 pixels)
     * @param click Optional click component to cancel when dragging starts
     * @param getDraggingVisual Factory function to create the drag visual
     * @param releaseDraggingVisual Cleanup function for the drag visual
     */
    public function new(threshold:Float = 4.0, ?click:Click, getDraggingVisual:Void->Visual, releaseDraggingVisual:Visual->Void) {

        super();

        this.click = click;
        this.threshold = threshold;
        this.getDraggingVisual = getDraggingVisual;
        this.releaseDraggingVisual = releaseDraggingVisual;

    }

    /**
     * Called when this component is bound to an entity.
     * Sets up pointer down event listener on the target visual.
     */
    function bindAsComponent() {

        entity.onPointerDown(this, handlePointerDown);

    }

    /**
     * Programmatically starts a drag operation.
     * Can be called to initiate dragging without waiting for threshold.
     * @param pointerX X position to start drag from (defaults to current pointer position)
     * @param pointerY Y position to start drag from (defaults to current pointer position)
     */
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

    /**
     * Handles pointer down events on the target visual.
     * Initializes tracking for potential drag operation.
     */
    function handlePointerDown(info:TouchInfo) {

        isPointerDown = true;

        pointerDownX = info.x;
        pointerDownY = info.y;

        screen.onPointerMove(this, handlePointerMove);
        entity.oncePointerUp(this, handlePointerUp);

    }

    /**
     * Handles pointer move events during potential or active drag.
     * Checks threshold and updates drag position.
     */
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

    /**
     * Handles pointer up events to end drag operation.
     * Cleans up event listeners and releases dragging visual.
     */
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

    /**
     * Updates the drag position based on current pointer coordinates.
     * Converts screen coordinates to visual space if dragging visual has a parent.
     * @param pointerX Current pointer X position in screen space
     * @param pointerY Current pointer Y position in screen space
     */
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
