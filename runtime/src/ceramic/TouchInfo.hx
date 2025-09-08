package ceramic;

/**
 * Information about a touch or mouse input event.
 * 
 * TouchInfo encapsulates details about touch and mouse input events,
 * including position, button/touch index, and delta movements. This class
 * is used throughout the input system to provide unified information for
 * both touch and mouse inputs.
 * 
 * @see Visual
 * @see Screen
 */
@:structInit
class TouchInfo {

    /**
     * If the input is a touch input, this is the index of the touch.
     * Otherwise it will be -1.
     */
    public var touchIndex(default,null):Int;

    /**
     * If the input is a mouse input, this is the id of the mouse button.
     * Otherwise it will be -1.
     */
    public var buttonId(default,null):Int;

    /**
     * X coordinate of the input (relative to screen).
     */
    public var x(default,null):Float;

    /**
     * Y coordinate of the input (relative to screen).
     */
    public var y(default, null):Float;

    /**
     * Whether these info do hit the related visual. This is usually `true`,
     * Except when we have touch/mouse up events outside of a visual that
     * initially received a down event.
     */
    public var hits(default, null):Bool;

/// Print

    function toString():String {

        return '' + {
            touchIndex: touchIndex,
            buttonId: buttonId,
            x: x,
            y: y,
            hits: hits
        };

    }

}
