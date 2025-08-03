package elements;

import ceramic.RowLayout;

/**
 * A specialized row layout for the immediate mode UI system.
 * 
 * ImRowLayout extends the standard RowLayout with pre-configured
 * settings optimized for immediate mode UI rendering. It provides
 * consistent spacing between UI elements when they are arranged
 * horizontally in a row.
 * 
 * This layout is automatically created and managed by the Im system
 * when using row-based layouts through Im.beginRow() and Im.endRow().
 * 
 * @see Im
 * @see RowLayout
 */
class ImRowLayout extends RowLayout {

    /**
     * Creates a new ImRowLayout instance.
     * 
     * Initializes the layout with:
     * - 6 pixels of spacing between items (optimized for UI elements)
     */
    public function new() {

        super();

        itemSpacing = 6;

    }

}