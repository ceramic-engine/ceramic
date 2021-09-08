package ceramic;

import ceramic.Shortcuts.*;

class LongPress extends Entity implements Component {

/// Events

    @event function longPress(info:TouchInfo);

/// Properties

    public var threshold = 4.0;

    public var requiredDuration = 1.0;

    public var entity:Visual;

    public var click:Click;

/// Lifecycle

    public function new(?handleLongPress:TouchInfo->Void, ?click:Click) {

        super();

        this.click = click;

        if (handleLongPress != null) {
            onLongPress(null, handleLongPress);
        }

    }

    function bindAsComponent():Void {

        // Bind pointer events
        bindPointerEvents();

    }

/// Internal

    var pointerStartX = 0.0;

    var pointerStartY = 0.0;

    var didLongPress = false;

    var cancelLongPress:Void->Void = null;

    function bindPointerEvents() {

        entity.onPointerDown(this, handlePointerDown);
        entity.onPointerUp(this, handlePointerUp);

    }

    function handlePointerDown(info:TouchInfo) {

        didLongPress = false;

        pointerStartX = screen.pointerX;
        pointerStartY = screen.pointerY;

        screen.onPointerMove(this, handlePointerMove);

        cancelLongPress = Timer.delay(this, requiredDuration, function() {
            cancelLongPress = null;
            didLongPress = true;

            if (click != null) {
                click.cancel();
            }

            emitLongPress(info);
        });

    }

    function handlePointerMove(info:TouchInfo) {

        if (Math.abs(screen.pointerX - pointerStartX) > threshold || Math.abs(screen.pointerY - pointerStartY) > threshold) {
            screen.offPointerMove(handlePointerMove);
            if (cancelLongPress != null) {
                cancelLongPress();
                cancelLongPress = null;
            }
        }

    }

    function handlePointerUp(info:TouchInfo) {

        if (cancelLongPress != null) {
            cancelLongPress();
            cancelLongPress = null;
        }
        screen.offPointerMove(handlePointerMove);

    }

}
