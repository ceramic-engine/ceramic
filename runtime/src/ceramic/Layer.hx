package ceramic;

import ceramic.Shortcuts.*;

/**
 * A specialized container for organizing and grouping visuals.
 *
 * Layer extends Quad but is transparent by default, making it ideal for:
 * - Grouping related visuals together
 * - Creating scrollable areas
 * - Implementing UI panels and containers
 * - Managing z-ordering of visual groups
 * - Applying transforms to multiple visuals at once
 *
 * Key features:
 * - Transparent by default (doesn't render itself)
 * - Resize event for responsive layouts
 * - Efficient batched resize notifications
 * - Can still be made visible with texture/color if needed
 *
 * Layers are commonly used to organize your scene hierarchy and apply
 * transformations to groups of objects together.
 *
 * ```haxe
 * // Create a game layer that can be scrolled
 * var gameLayer = new Layer();
 * gameLayer.size(screen.width, screen.height);
 *
 * // Add game objects to the layer
 * var player = new Quad();
 * gameLayer.add(player);
 *
 * // Scroll the entire game world
 * gameLayer.x = camera.contentTranslateX;
 * gameLayer.y = camera.contentTranslateY;
 *
 * // Create a UI layer that stays fixed
 * var uiLayer = new Layer();
 * uiLayer.size(screen.width, screen.height);
 * uiLayer.depth = 100; // Render on top
 * ```
 *
 * @see Quad
 * @see Visual
 */
class Layer extends Quad {

    /**
     * Emitted when the layer's size changes.
     * Useful for implementing responsive layouts and updating child positions.
     * The event is batched - multiple size changes in the same frame emit only once.
     * @param width New width of the layer
     * @param height New height of the layer
     */
    @event function resize(width:Float, height:Float);

    var sizeDirty:Bool = false;

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        transparent = true;

    }

    function emitResizeIfNeeded() {

        if (destroyed || !sizeDirty)
            return;

        sizeDirty = false;

        emitResize(width, height);

    }

    /**
     * Called before emitting the resize event.
     * Override in subclasses to prepare for size changes.
     * @param width New width that will be emitted
     * @param height New height that will be emitted
     */
    function willEmitResize(width:Float, height:Float):Void {

        // Implemented to allow subclass overrides

    }

    /**
     * Called after emitting the resize event.
     * Override in subclasses to perform post-resize updates.
     * @param width New width that was emitted
     * @param height New height that was emitted
     */
    function didEmitResize(width:Float, height:Float):Void {

        // Implemented to allow subclass overrides

    }

    override function set_width(width:Float):Float {
        if (_width == width) return width;
        super.set_width(width);
        if (!sizeDirty) {
            sizeDirty = true;
            app.onceImmediate(emitResizeIfNeeded);
        }
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        super.set_height(height);
        if (!sizeDirty) {
            sizeDirty = true;
            app.onceImmediate(emitResizeIfNeeded);
        }
        return height;
    }

}
