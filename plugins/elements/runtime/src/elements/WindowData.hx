package elements;

import ceramic.ReadOnlyArray;
import ceramic.TextAlign;
import ceramic.View;
import ceramic.ViewSize;
import elements.Context.context;
import tracker.Model;

using ceramic.Extensions;

/**
 * Persistent data model for window state and configuration.
 * 
 * This class manages the persistent state of a window including its position, size,
 * visibility settings, and contained items. It handles the lifecycle of window items
 * and provides frame-based management for efficient UI updates.
 * 
 * ## Features
 * 
 * - Position and size persistence
 * - Expandable/collapsible state management
 * - Scrollbar configuration
 * - Window item lifecycle management
 * - Frame-based usage tracking
 * - Overlay and dialog support
 * 
 * ## Frame Management
 * 
 * The window data uses a frame-based system where:
 * 1. `beginFrame()` marks the start of a new frame and resets usage tracking
 * 2. Items are added/accessed during the frame
 * 3. `endFrame()` cleans up unused items and updates persistent data
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Create window data
 * var windowData = new WindowData();
 * windowData.x = 100;
 * windowData.y = 50;
 * windowData.width = 300;
 * windowData.height = 400;
 * 
 * // Frame lifecycle
 * windowData.beginFrame();
 * // ... add items during frame
 * windowData.addItem(someWindowItem);
 * windowData.endFrame();
 * ```
 * 
 * @see WindowItem
 * @see Window
 * @see ScrollbarVisibility
 */
class WindowData extends Model {

    /**
     * Default width for new windows when no specific width is set.
     */
    public inline static final DEFAULT_WIDTH:Float = 200;

    /**
     * Default height for new windows, using ViewSize.auto() for automatic sizing.
     * The negative value represents ViewSize.auto() which allows the window
     * to size itself based on its content.
     */
    public inline static final DEFAULT_HEIGHT:Float = -60001.0; // ViewSize.auto();

    /**
     * The X position of the window on screen.
     * This value is automatically updated when the window is moved.
     * 
     * @default 50
     */
    @serialize public var x:Float = 50;

    /**
     * The Y position of the window on screen.
     * This value is automatically updated when the window is moved.
     * 
     * @default 50
     */
    @serialize public var y:Float = 50;

    /**
     * The width of the window.
     * This value is automatically updated when the window is resized.
     * 
     * @default 50
     */
    @serialize public var width:Float = 50;

    /**
     * The height of the window.
     * This value is automatically updated when the window is resized.
     * 
     * @default 50
     */
    @serialize public var height:Float = 50;

    /**
     * Whether the window is currently expanded (visible) or collapsed.
     * When false, the window content is hidden but the title bar may remain visible.
     * 
     * @default true
     */
    @serialize public var expanded:Bool = true;

    /**
     * Whether the window should display a header/title bar.
     * When false, the window appears without a title bar.
     * 
     * @default true
     */
    @serialize public var header:Bool = true;

    /**
     * The scrollbar visibility mode for the window content.
     * Controls when and how scrollbars are displayed.
     * 
     * @default AUTO_ADD
     * @see ScrollbarVisibility
     */
    @serialize public var scrollbar:ScrollbarVisibility = AUTO_ADD;

    /**
     * The computed height of the window content area.
     * This is calculated based on the contained items and layout.
     */
    public var computedContentHeight:Float = 0;

    /**
     * Current index for item management during frame processing.
     * @private
     */
    var itemIndex:Int = 0;

    /**
     * Array of window items contained in this window.
     * Items are managed through the frame lifecycle system.
     * 
     * @see WindowItem
     * @see addItem
     */
    public var items(default, null):ReadOnlyArray<WindowItem> = [];

    /**
     * The number of items currently in the window.
     * This reflects the number of items added during the current frame.
     */
    public var numItems(get, never):Int;
    inline function get_numItems():Int return itemIndex;

    /**
     * The theme used for styling this window.
     * If null, a default theme will be used.
     */
    public var theme:Theme = null;

    /**
     * The form layout used to organize window items.
     * This handles the vertical arrangement of items within the window.
     */
    public var form:FormLayout = null;

    /**
     * A filler view used for spacing or layout purposes.
     */
    public var filler:View = null;

    /**
     * Whether the window content is scrollable.
     * When true, the window can display scrollbars if needed.
     */
    public var scrollable:Bool = false;

    /**
     * The height value when scrolling was last detected.
     * Used for scroll state management.
     * @private
     */
    public var didScrollWithHeight:Int = -1;

    /**
     * Whether this window data is currently being used.
     * Windows marked as unused are cleaned up during endFrame().
     */
    public var used:Bool = true;

    /**
     * Whether this window was just closed.
     * Used for tracking recent closure events.
     */
    public var justClosed:Bool = false;

    /**
     * Whether the window can be closed by the user.
     * When true, a close button is typically displayed.
     */
    public var closable:Bool = false;

    /**
     * Whether the window can be moved by dragging.
     * When true, the user can drag the window around the screen.
     */
    public var movable:Bool = false;

    /**
     * Whether the window can be collapsed/expanded.
     * When true, the user can toggle the window's expanded state.
     */
    public var collapsible:Bool = true;

    /**
     * Whether this window is displayed as an overlay.
     * Overlay windows typically appear above other content with special styling.
     */
    public var overlay:Bool = false;

    /**
     * Special theme used when the window is in overlay mode.
     * If null, the regular theme is used even for overlays.
     */
    public var overlayTheme:Theme = null;

    /**
     * Whether the overlay background was clicked.
     * Used for handling overlay dismissal interactions.
     */
    public var overlayClicked:Bool = false;

    /**
     * Text alignment for the window title.
     * Controls how the title text is aligned in the title bar.
     */
    public var titleAlign:TextAlign = LEFT;

    /**
     * Target X position for window positioning.
     * Used for animated positioning or special placement logic.
     */
    public var targetX:Float = -999999999;

    /**
     * Target Y position for window positioning.
     * Used for animated positioning or special placement logic.
     */
    public var targetY:Float = -999999999;

    /**
     * Target anchor X value for window positioning.
     * Used for special alignment and positioning calculations.
     */
    public var targetAnchorX:Float = -999999999;

    /**
     * Target anchor Y value for window positioning.
     * Used for special alignment and positioning calculations.
     */
    public var targetAnchorY:Float = -999999999;

    /**
     * Reference to the actual Window visual that displays this data.
     * This links the data model to its visual representation.
     */
    public var window:Window = null;

    /**
     * Creates a new WindowData instance with default values.
     */
    public function new() {

        super();

    }

    /**
     * Begins a new frame for window processing.
     * 
     * Marks the window as unused and resets the item index for the new frame.
     * This should be called at the start of each frame before adding items.
     * Windows that remain unused after endFrame() will be cleaned up.
     */
    public function beginFrame():Void {

        // Mark window as not used at the beginning of the frame
        used = false;

        var len = itemIndex;
        itemIndex = 0;

    }

    /**
     * Ends the current frame and performs cleanup.
     * 
     * If the window was not used during this frame, it will be destroyed.
     * Otherwise, the current position is saved to persist window location.
     * Any unused items beyond the current itemIndex are recycled.
     */
    public function endFrame():Void {

        // If window still marked as not used,
        // destroy view and recycle items
        if (!used) {
            if (window != null) {
                var w = window;
                window = null;
                w.destroy();
            }
        }
        else {
            if (window != null) {
                // Save position
                x = window.x;
                y = window.y;
            }
        }

        // In any case, check remaining items that are not used and recycle them
        for (i in itemIndex...items.length) {
            var item = items[i];
            if (item != null) {
                if (item.hasManagedVisual()) {
                    item.visual.destroy();
                    item.visual = null;
                }
                items.original[i] = null;
                item.recycle();
            }
        }

    }

    /**
     * Adds an item to the window at the current item index.
     * 
     * The item is placed at the current itemIndex position, and any existing
     * item at that position has its previous item recycled. The itemIndex is
     * then incremented for the next item.
     * 
     * @param item The WindowItem to add to the window
     * 
     * @see WindowItem
     */
    public function addItem(item:WindowItem):Void {

        var previous = items[itemIndex];

        if (previous != null) {
            if (previous.previous != null) {
                previous.previous.recycle();
                previous.previous = null;
            }
        }

        item.previous = previous;
        items.original[itemIndex] = item;

        itemIndex++;

    }

}