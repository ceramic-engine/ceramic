package ceramic;

import ceramic.Shortcuts.*;
import ceramic.System;
import ceramic.View;

/**
 * System responsible for managing and updating the UI view layout.
 * 
 * ViewSystem is automatically created and bound when the first View is instantiated.
 * It handles the layout computation phase during the engine's update cycle,
 * ensuring all views are properly sized and positioned before rendering.
 * 
 * Key responsibilities:
 * - Triggers layout computation for all dirty views
 * - Ensures layout updates happen at the right time in the frame
 * - Manages the global view layout update cycle
 * 
 * The system runs in the late update phase (order 7000) to ensure:
 * - All game logic has completed
 * - Views can be properly positioned before rendering
 * - Layout changes are batched efficiently
 * 
 * @see View The base view class that uses this system
 * @see System The base system class
 */
class ViewSystem extends System {

    /**
     * Shared singleton instance of the ViewSystem.
     * Created lazily when first accessed (typically when the first View is created).
     * This ensures the system is only created when UI functionality is actually used.
     */
    @lazy public static var shared = new ViewSystem();

    /**
     * Create a new ViewSystem.
     * Sets the late update order to 7000 to ensure layout happens
     * after most game logic but before rendering.
     */
    public function new() {

        super();

        lateUpdateOrder = 7000;

    }

    /**
     * Called by View class to ensure the system is created and active.
     * This method exists to trigger the lazy initialization of the shared instance
     * without exposing system internals.
     * 
     * @private Only accessible by ceramic.View
     */
    @:allow(ceramic.View)
    @:keep function bind():Void {

        // Nothing to do specifically

    }

    /**
     * Called during the late update phase of each frame.
     * Triggers the layout computation for all views that need updating.
     * This ensures all view layouts are computed and applied before rendering.
     * 
     * @param delta Time elapsed since last frame in seconds
     */
    override function lateUpdate(delta:Float):Void {

        View._updateViewsLayout(delta);

    }

}