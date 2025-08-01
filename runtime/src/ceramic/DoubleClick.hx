package ceramic;

import ceramic.Shortcuts.*;

/**
 * Component that detects double-click/double-tap events on visuals.
 * 
 * This component tracks consecutive clicks and emits a doubleClick event
 * when two clicks occur within the specified time and movement thresholds.
 */
class DoubleClick extends Entity implements Component {

/// Events

    /**
     * Event fired when the visual is double-clicked/double-tapped.
     */
    @event function doubleClick();

/// Public properties

    /**
     * Maximum pointer movement allowed between clicks.
     * If the pointer moves more than this distance, the double-click is canceled.
     */
    public var threshold = 4.0;

    /**
     * Maximum time delay between clicks in seconds.
     * Clicks must occur within this time to count as a double-click.
     */
    public var maxDelay = 0.4;

    /**
     * The visual entity this component is attached to.
     */
    public var entity:Visual;

/// Internal properties

    var pressed:Bool = false;

    var firstClickTime:Float = -1;

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
     * Cancel the current double-click detection.
     * Resets the state and stops tracking clicks.
     */
    public function cancel():Void {

        screen.offPointerMove(handlePointerMove);
        pressed = false;
        firstClickTime = -1;

    }

/// Internal

    function handlePointerDown(info:TouchInfo) {

        pointerStartX = screen.pointerX;
        pointerStartY = screen.pointerY;

        pressed = true;

        if (firstClickTime >= 0) {
            if (Timer.now - firstClickTime <= maxDelay) {
                emitDoubleClick();
            }
            else {
                firstClickTime = -1;
            }
        }

        screen.onPointerMove(this, handlePointerMove);

    }

    function handlePointerUp(info:TouchInfo) {

        if (pressed) {
            pressed = false;
            if (firstClickTime < 0) {
                firstClickTime = Timer.now;
                return;
            }
        }

        if (firstClickTime >= 0) {
            firstClickTime = -1;
        }

    }

    function handlePointerMove(info:TouchInfo) {

        if (Math.abs(screen.pointerX - pointerStartX) > threshold || Math.abs(screen.pointerY - pointerStartY) > threshold) {
            screen.offPointerMove(handlePointerMove);
            pressed = false;
            firstClickTime = -1;
        }

    }

    function handleBlur() {

        pressed = false;

    }

}
