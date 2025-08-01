package ceramic;

import ceramic.Shortcuts.*;
import tracker.Observable;

/**
 * Component that detects click/tap events on visuals.
 * 
 * This component handles pointer down/up events and emits a click event
 * when the user taps on the visual without moving beyond the threshold.
 */
class Click extends Entity implements Component implements Observable {

/// Events

    /**
     * Event fired when the visual is clicked/tapped.
     */
    @event function click();

/// Public properties

    /**
     * Maximum pointer movement allowed before canceling the click.
     * Set to -1 to disable movement cancellation.
     */
    public var threshold:Float = -1;

    /**
     * The visual entity this component is attached to.
     */
    public var entity:Visual;

    /**
     * Whether the pointer is currently pressed on this visual.
     */
    @observe public var pressed(default,null):Bool = false;

/// Internal properties

    var pointerStartX = 0.0;
    var pointerStartY = 0.0;

/// Lifecycle

    function bindAsComponent():Void {

        entity.onPointerDown(this, handlePointerDown);

        entity.onPointerUp(this, handlePointerUp);

        entity.onBlur(this, handleBlur);

    }

/// Public API

    /**
     * Cancel the current click operation.
     */
    public function cancel():Void {

        pressed = false;

    }

/// Internal

    function handlePointerDown(info:TouchInfo) {

        pointerStartX = screen.pointerX;
        pointerStartY = screen.pointerY;

        pressed = true;

        screen.onPointerMove(this, handlePointerMove);

    }

    function handlePointerUp(info:TouchInfo) {

        if (pressed) {
            pressed = false;
            if (entity.hits(info.x, info.y)) {
                emitClick();
            }
        }

    }

    function handlePointerMove(info:TouchInfo) {

        if (threshold != -1 && (Math.abs(screen.pointerX - pointerStartX) > threshold || Math.abs(screen.pointerY - pointerStartY) > threshold)) {
            screen.offPointerMove(handlePointerMove);
            pressed = false;
        }

    }

    function handleBlur() {

        pressed = false;

    }

}
