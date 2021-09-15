package ceramic;

import ceramic.Shortcuts.*;

class DoubleClick extends Entity implements Component {

/// Events

    @event function doubleClick();

/// Public properties

    public var threshold = 4.0;

    public var maxDelay = 0.4;

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
