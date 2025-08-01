package ceramic;

/**
 * Represents a single touch point in a multi-touch interaction.
 * 
 * Touch contains information about a finger or stylus touching the screen,
 * including its position and movement. Each touch has a unique index that
 * persists throughout the touch lifetime (from touchdown to touchup).
 * 
 * Touch instances are managed by the Screen class and accessed through
 * screen.touches or multi-touch events.
 * 
 * @see Screen
 * @see Touches
 */
@:structInit
@:allow(ceramic.Screen)
class Touch {

    /**
     * Unique identifier for this touch point.
     * The index remains constant throughout the touch lifetime.
     */
    public var index(default,null):Int;

    /**
     * Current X coordinate of the touch in screen space.
     */
    public var x(default,null):Float;

    /**
     * Current Y coordinate of the touch in screen space.
     */
    public var y(default,null):Float;

    /**
     * Change in X position since the last frame.
     */
    public var deltaX(default,null):Float;

    /**
     * Change in Y position since the last frame.
     */
    public var deltaY(default,null):Float;

/// Print

    /**
     * Returns a string representation of this touch.
     * @return String showing all touch properties
     */
    function toString():String {

        return '' + {
            index: index,
            x: x,
            y: y,
            deltaX: deltaX,
            deltaY: deltaY
        };

    }

}
