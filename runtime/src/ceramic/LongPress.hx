package ceramic;

import ceramic.Shortcuts.*;

/**
 * Component that detects long press/hold gestures on visuals.
 * 
 * This component tracks when the user presses and holds on a visual
 * for a specified duration without moving beyond the threshold.
 */
class LongPress extends Entity implements Component {

/// Events

    /**
     * Event fired when a long press is detected.
     * 
     * @param info Touch information for the long press
     */
    @event function longPress(info:TouchInfo);

/// Properties

    /**
     * Maximum pointer movement allowed during the press.
     * If the pointer moves more than this distance, the long press is canceled.
     */
    public var threshold = 4.0;

    /**
     * Required duration in seconds to trigger a long press.
     * The user must hold for at least this long.
     */
    public var requiredDuration = 1.0;

    /**
     * The visual entity this component is attached to.
     */
    public var entity:Visual;

    /**
     * Optional Click component to cancel when long press is detected.
     * This prevents both click and long press from firing.
     */
    public var click:Click;

/// Lifecycle

    /**
     * Create a new LongPress component.
     * 
     * @param handleLongPress Optional callback for long press events
     * @param click Optional Click component to coordinate with
     */
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
