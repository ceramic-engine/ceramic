package elements;

import ceramic.Click;
import ceramic.Color;
import ceramic.LongPress;
import ceramic.Shortcuts.*;
import ceramic.TouchInfo;
import ceramic.Transform;
import ceramic.View;
import ceramic.Visual;
import tracker.Observable;

/**
 * A single color swatch in a color picker palette.
 * This view represents an individual color that can be selected, dragged, and dropped
 * within a color palette interface.
 * 
 * Features:
 * - Click to select the color
 * - Long press for additional actions (e.g., delete, edit)
 * - Drag and drop to reorder colors in the palette
 * - Visual feedback for press and drag states
 * 
 * The view maintains a square aspect ratio and provides transform-based
 * visual feedback when pressed or dragged.
 * 
 * @event click Emitted when the color is clicked
 * @event drop Emitted when the color is dropped after dragging
 * @event longPress Emitted when the color is long-pressed
 */
class ColorPickerPaletteColorView extends View implements Observable {

/// Components

    /** Click detection component for color selection */
    @component var click:Click;

    /** Long press detection for context actions */
    @component var longPress:LongPress;

    /** Drag and drop component for palette reordering */
    @component public var dragDrop:DragDrop;

/// Events

    @event function click(instance:ColorPickerPaletteColorView);

    @event function drop(instance:ColorPickerPaletteColorView);

    @event function longPress(instance:ColorPickerPaletteColorView, info:TouchInfo);

/// Properties

    /** Whether this color swatch is currently being dragged */
    public var dragging(get, never):Bool;
    inline function get_dragging():Bool return dragDrop.dragging;

    /** Standard size for palette color swatches in pixels */
    @:allow(elements.ColorPickerView)
    static final PALETTE_COLOR_SIZE = 14.0;

    /**
     * The color value represented by this swatch.
     * Setting this updates the visual appearance.
     */
    public var colorValue(default, set):Color;
    function set_colorValue(colorValue:Color):Color {
        if (this.colorValue == colorValue)
            return colorValue;
        this.colorValue = colorValue;
        this.color = colorValue;
        return colorValue;
    }

/// Lifecycle

    /**
     * Creates a new palette color swatch.
     * @param colorValue The color to display (default: white)
     */
    public function new(colorValue:Color = Color.WHITE) {

        super();

        viewSize(PALETTE_COLOR_SIZE, PALETTE_COLOR_SIZE);

        this.colorValue = colorValue;

        click = new Click();
        click.onClick(this, () -> emitClick(this));

        longPress = new LongPress(click);
        longPress.onLongPress(this, (info) -> emitLongPress(this, info));

        dragDrop = new DragDrop(click, getDraggingVisual, releaseDraggingVisual);
        dragDrop.onDraggingChange(this, handleDraggingChange);

        transform = new Transform();

        autorun(updateStyle);

        bindDraggingDepth();

    }

    /**
     * Updates the visual transform based on interaction state.
     * - Dragging: follows drag position
     * - Pressed: slight downward offset
     * - Normal: no offset
     */
    function updateStyle() {

        if (dragging) {
            transform.tx = dragDrop.dragX;
            transform.ty = dragDrop.dragY;
            transform.changedDirty = true;
        }
        else if (click.pressed) {
            transform.tx = 0;
            transform.ty = 1;
            transform.changedDirty = true;
        }
        else {
            transform.tx = 0;
            transform.ty = 0;
            transform.changedDirty = true;
        }

    }

/// Drag & Drop

    /**
     * Ensures dragged colors appear above other elements.
     * Temporarily increases depth during drag operations.
     */
    function bindDraggingDepth() {

        var originalComputedDepth:Float = computedDepth;

        app.onBeginSortVisuals(this, () -> {
            originalComputedDepth = computedDepth;
            if (dragging) {
                computedDepth = 9999999;
            }
        });

        app.onFinishSortVisuals(this, () -> {
            computedDepth = originalComputedDepth;
        });

    }

    /**
     * Provides the visual to be dragged (the swatch itself).
     * @return This color swatch view
     */
    function getDraggingVisual() {

        return this;

    }

    /**
     * Called when drag operation ends.
     * No cleanup needed as the swatch drags itself.
     * @param visual The visual that was dragged
     */
    function releaseDraggingVisual(visual:Visual) {

        // Nothing to do

    }

    /**
     * Handles drag state changes and emits drop event when dragging ends.
     * @param dragging Current dragging state
     * @param wasDragging Previous dragging state
     */
    function handleDraggingChange(dragging:Bool, wasDragging:Bool) {

        if (wasDragging && !dragging) {
            emitDrop(this);
        }

    }

    /**
     * Returns a string representation of this color swatch.
     * @return String in format "ColorPickerPaletteColorView(#RRGGBB)"
     */
    override function toString() {

        return 'ColorPickerPaletteColorView(' + colorValue + ')';

    }

}
