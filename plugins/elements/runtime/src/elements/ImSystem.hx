package elements;

import ceramic.Filter;
import ceramic.Shortcuts.*;
import ceramic.System;
import ceramic.TouchInfo;
import ceramic.View;
import ceramic.Visual;

/**
 * The core system that manages the immediate mode UI rendering pipeline.
 * 
 * ImSystem extends Ceramic's System class to integrate with the engine's
 * update loop and provide:
 * - Render target management through filters
 * - Window focus tracking
 * - Frame lifecycle management
 * - Automatic layout updates
 * 
 * The system uses a Filter to render all Im UI to a separate texture,
 * allowing for proper layering and post-processing effects. It automatically
 * activates when windows are present and deactivates when no UI is shown.
 * 
 * @see Im
 * @see Window
 * @see System
 */
class ImSystem extends System {

    /**
     * The shared singleton instance of ImSystem.
     * Lazily initialized on first access.
     */
    @lazy public static var shared = new ImSystem();

    /**
     * Filter that renders all Im UI to a separate texture.
     */
    var filter:Filter = null;

    /**
     * Root view container for all Im windows and UI elements.
     */
    var view:View = null;

    /**
     * State counter for filter activation/deactivation.
     * Ranges from -2 (fully inactive) to 2 (fully active).
     */
    var makeFilterActive:Int = -2;

    /**
     * Creates a new ImSystem instance.
     * 
     * Sets up the system with:
     * - Early update order of 100 (runs before most systems)
     * - Late update order of 6000 (runs after most systems)
     * 
     * This ensures Im.beginFrame() runs early and Im.endFrame() runs late
     * in the frame lifecycle.
     */
    public function new() {

        super();

        earlyUpdateOrder = 100;
        lateUpdateOrder = 6000;

    }

    /**
     * Creates the root view and filter for Im UI rendering.
     * 
     * This method:
     * - Creates a filter bound to native screen size for crisp rendering
     * - Sets up a transparent root view at depth 1000 (above most content)
     * - Configures automatic layout updates
     * - Tracks focus changes for window management
     * 
     * @allow elements.Im
     */
    @:allow(elements.Im)
    function createView():Void {

        filter = new Filter();
        filter.textureFilter = NEAREST;
        filter.bindToNativeScreenSize();
        filter.depth = 1000;
        filter.density = screen.nativeDensity;
        filter.enabled = true;
        filter.autoRender = false;
        view = new View();
        view.transparent = true;
        view.depth = 1000;
        view.onLayout(this, _layoutWindows);
        Context.context.view = view;
        screen.onFocusedVisualChange(this, handleFocusedVisualChange);
        filter.content.add(view);

        view.size(filter.width, filter.height);
        filter.onResize(this, (width, height) -> {
            view.size(width, height);
        });

    }

    /**
     * Requests a render update for the Im UI.
     * 
     * Marks the filter's render texture as dirty, ensuring
     * the UI is re-rendered in the next frame.
     * 
     * @allow elements.Im
     */
    @:allow(elements.Im)
    function requestRender():Void {

        if (filter != null && filter.renderTexture != null) {
            filter.renderTexture.renderDirty = true;
        }

    }

    /**
     * Handles focus changes to track which Im window has focus.
     * 
     * This method:
     * - Determines if the focused visual is within an Im window
     * - Handles special cases like color picker popovers
     * - Updates the context's focused window reference
     * 
     * @param focusedVisual The visual that gained focus
     * @param prevFocusedVisual The visual that lost focus
     */
    function handleFocusedVisualChange(focusedVisual:Visual, prevFocusedVisual:Visual) {

        var focusedWindow:Window = null;
        if (focusedVisual != null) {
            if (focusedVisual is Window) {
                focusedWindow = cast focusedVisual;
            }
            else {
                var parentWindow = focusedVisual.firstParentWithClass(Window);
                if (parentWindow != null) {
                    focusedWindow = parentWindow;
                }
                else {
                    // Handle color picker popover case
                    var parentPickerView:ColorPickerView = null;
                    if (focusedVisual is ColorPickerView) {
                        parentPickerView = cast focusedVisual;
                    }
                    else {
                        parentPickerView = focusedVisual.firstParentWithClass(ColorPickerView);
                    }
                    if (parentPickerView != null && parentPickerView.colorFieldView != null) {
                        parentWindow = parentPickerView.colorFieldView.firstParentWithClass(Window);
                        if (parentWindow != null) {
                            focusedWindow = parentWindow;
                        }
                    }
                }
            }
        }
        Context.context.focusedWindow = focusedWindow;

    }

    /**
     * Early update called at the beginning of each frame.
     * 
     * Updates view size to match filter dimensions and
     * calls Im.beginFrame() to start the Im rendering cycle.
     * 
     * @param delta Time elapsed since last frame in seconds
     */
    override function earlyUpdate(delta:Float):Void {

        if (view != null) {
            view.size(filter.width, filter.height);

            filter.density = screen.nativeDensity;
        }

        Im.beginFrame();

    }

    /**
     * Late update called at the end of each frame.
     * 
     * Finalizes the Im frame and manages filter activation:
     * - Gradually activates filter when windows are present
     * - Gradually deactivates filter when no windows are shown
     * - Ensures smooth transitions to avoid visual glitches
     * 
     * The activation counter provides a 2-frame delay for stability.
     * 
     * @param delta Time elapsed since last frame in seconds
     */
    override function lateUpdate(delta:Float):Void {

        Im.endFrame();

        if (filter != null) {

            // This logic is basically ensuring we wait for a
            // full frame to re-display the filter when going
            // back from inactive

            if (Im._numUsedWindows > 0) {
                if (makeFilterActive < 2) {
                    makeFilterActive++;
                }
            }
            else {
                if (makeFilterActive > -2) {
                    makeFilterActive--;
                }
                if (makeFilterActive > -2 && filter.renderTexture != null) {
                    filter.renderTexture.renderDirty = true;
                }
            }

            if (makeFilterActive == -1) {
                filter.neverEmpty = false;
                filter.active = false;
            }
            else if (makeFilterActive == 2) {
                filter.neverEmpty = true;
                filter.active = true;
            }
        }

    }

/// Internal

    /**
     * Performs layout updates for all Im windows.
     * 
     * Called when the root view needs to layout its children.
     * Ensures all windows compute their size properly based
     * on their content.
     */
    function _layoutWindows():Void {

        var subviews = Context.context.view.subviews;
        if (subviews != null) {
            for (i in 0...subviews.length) {
                var view = subviews[i];
                if (view is Window) {
                    view.autoComputeSizeIfNeeded(true);
                }
            }
        }

    }

}