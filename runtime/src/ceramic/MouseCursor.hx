package ceramic;

/**
 * Shape of the mouse cursor while it is over the app.
 *
 * ```haxe
 * screen.cursor = MouseCursor.POINTING_HAND;
 * ```
 *
 * Backend support:
 * - Clay native (SDL): system cursors (`SDL_CreateSystemCursor`). When the OS
 *   doesn't have a shape, SDL falls back to a close one, or the arrow.
 * - Clay web: CSS `cursor` on the canvas.
 * - Unity: no-op (Unity only supports custom cursor textures), except `NONE`
 *   which hides the cursor.
 * - Headless: no-op.
 *
 * @see Screen.cursor
 */
enum abstract MouseCursor(Int) from Int to Int {

    /** Default arrow cursor */
    var ARROW = 0;

    /** Text selection cursor (I-beam) */
    var IBEAM = 1;

    /** Crosshair */
    var CROSSHAIR = 2;

    /** Closed hand, while dragging something */
    var CLOSED_HAND = 3;

    /** Open hand, something can be dragged */
    var OPEN_HAND = 4;

    /** Pointing hand, for links and buttons */
    var POINTING_HAND = 5;

    /** Resize the left edge */
    var RESIZE_LEFT = 6;

    /** Resize the right edge */
    var RESIZE_RIGHT = 7;

    /** Resize horizontally */
    var RESIZE_LEFT_RIGHT = 8;

    /** Resize the top edge */
    var RESIZE_UP = 9;

    /** Resize the bottom edge */
    var RESIZE_DOWN = 10;

    /** Resize vertically */
    var RESIZE_UP_DOWN = 11;

    /** Resize diagonally, from top-left to bottom-right */
    var RESIZE_UP_LEFT_DOWN_RIGHT = 12;

    /** Resize diagonally, from top-right to bottom-left */
    var RESIZE_UP_RIGHT_DOWN_LEFT = 13;

    /** Resize a column */
    var RESIZE_COLUMN = 14;

    /** Resize a row */
    var RESIZE_ROW = 15;

    /** Text selection cursor for vertical text */
    var IBEAM_VERTICAL = 16;

    /** The action is not allowed */
    var OPERATION_NOT_ALLOWED = 17;

    /** Dragging will create a link (alias) */
    var DRAG_LINK = 18;

    /** Dragging will copy */
    var DRAG_COPY = 19;

    /** A contextual menu is available */
    var CONTEXTUAL_MENU = 20;

    /** Hidden cursor */
    var NONE = 21;

    /**
     * CSS `cursor` value matching this cursor shape.
     */
    public function toCss():String {

        return switch abstract {
            case ARROW: 'default';
            case IBEAM: 'text';
            case CROSSHAIR: 'crosshair';
            case CLOSED_HAND: 'grabbing';
            case OPEN_HAND: 'grab';
            case POINTING_HAND: 'pointer';
            case RESIZE_LEFT: 'w-resize';
            case RESIZE_RIGHT: 'e-resize';
            case RESIZE_LEFT_RIGHT: 'ew-resize';
            case RESIZE_UP: 'n-resize';
            case RESIZE_DOWN: 's-resize';
            case RESIZE_UP_DOWN: 'ns-resize';
            case RESIZE_UP_LEFT_DOWN_RIGHT: 'nwse-resize';
            case RESIZE_UP_RIGHT_DOWN_LEFT: 'nesw-resize';
            case RESIZE_COLUMN: 'col-resize';
            case RESIZE_ROW: 'row-resize';
            case IBEAM_VERTICAL: 'vertical-text';
            case OPERATION_NOT_ALLOWED: 'not-allowed';
            case DRAG_LINK: 'alias';
            case DRAG_COPY: 'copy';
            case CONTEXTUAL_MENU: 'context-menu';
            case NONE: 'none';
            case _: 'default';
        }

    }

    public function toString():String {

        return switch abstract {
            case ARROW: 'ARROW';
            case IBEAM: 'IBEAM';
            case CROSSHAIR: 'CROSSHAIR';
            case CLOSED_HAND: 'CLOSED_HAND';
            case OPEN_HAND: 'OPEN_HAND';
            case POINTING_HAND: 'POINTING_HAND';
            case RESIZE_LEFT: 'RESIZE_LEFT';
            case RESIZE_RIGHT: 'RESIZE_RIGHT';
            case RESIZE_LEFT_RIGHT: 'RESIZE_LEFT_RIGHT';
            case RESIZE_UP: 'RESIZE_UP';
            case RESIZE_DOWN: 'RESIZE_DOWN';
            case RESIZE_UP_DOWN: 'RESIZE_UP_DOWN';
            case RESIZE_UP_LEFT_DOWN_RIGHT: 'RESIZE_UP_LEFT_DOWN_RIGHT';
            case RESIZE_UP_RIGHT_DOWN_LEFT: 'RESIZE_UP_RIGHT_DOWN_LEFT';
            case RESIZE_COLUMN: 'RESIZE_COLUMN';
            case RESIZE_ROW: 'RESIZE_ROW';
            case IBEAM_VERTICAL: 'IBEAM_VERTICAL';
            case OPERATION_NOT_ALLOWED: 'OPERATION_NOT_ALLOWED';
            case DRAG_LINK: 'DRAG_LINK';
            case DRAG_COPY: 'DRAG_COPY';
            case CONTEXTUAL_MENU: 'CONTEXTUAL_MENU';
            case NONE: 'NONE';
            case _: Std.string(this);
        }

    }

}
