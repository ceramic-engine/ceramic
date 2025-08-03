package elements;

import ceramic.Entity;
import ceramic.Shortcuts.*;
import ceramic.System;
import ceramic.Visual;
import elements.FieldView;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

/**
 * Central system for managing field focus in the Elements UI framework.
 * 
 * FieldSystem tracks which field view currently has focus, handling focus transitions
 * and notifications. It integrates with Ceramic's visual focus system to determine
 * when a FieldView or related component gains or loses focus.
 * 
 * The system automatically updates every frame during the early update phase,
 * checking the currently focused visual and walking up its parent hierarchy to
 * find any FieldView instances. It also handles RelatedToFieldView components
 * that should transfer focus to their related field.
 * 
 * Features:
 * - Automatic focus tracking based on Ceramic's screen focus
 * - Support for nested field views and related components
 * - Focus change notifications to field views
 * - Frame-delayed focus updates for smooth transitions
 * 
 * Usage:
 * ```haxe
 * // Access the shared instance
 * var focusedField = FieldSystem.shared.focusedField;
 * 
 * // Listen for focus changes
 * FieldSystem.shared.onFocusedFieldChange(this, (field, prevField) -> {
 *     trace('Focus changed from $prevField to $field');
 * });
 * ```
 * 
 * @see FieldView for the base field view implementation
 * @see RelatedToFieldView for components that delegate focus
 */
class FieldSystem extends System implements Observable {

/// Statics

    /**
     * Shared singleton instance of the FieldSystem.
     * 
     * This instance is lazily created on first access and manages
     * field focus across the entire application.
     */
    @lazy public static var shared = new FieldSystem();

/// Public properties

    /**
     * The currently focused field view.
     * 
     * This property is observable and will trigger change events when
     * focus moves between fields. It will be null when no field has focus.
     */
    @observe public var focusedField:FieldView = null;

    /**
     * The field that has focus for the current frame.
     * 
     * This property provides a stable reference to the focused field during
     * a single frame, even if focus changes are pending. It's useful for
     * avoiding focus flicker during transitions.
     * 
     * @readonly
     */
    @observe public var focusedFieldThisFrame(default, null):FieldView = null;

/// Lifecycle

    /**
     * Creates a new FieldSystem instance.
     * 
     * The system is configured to run early in the update cycle (order 50)
     * to ensure focus state is updated before field views process input.
     */
    public function new() {

        super();

        earlyUpdateOrder = 50;

        focusedFieldThisFrame = focusedField;
        onFocusedFieldChange(this, handleFocusedFieldChange);

    }

    /**
     * Handles focus field changes, managing frame-delayed updates.
     * 
     * When focus is gained, the update is immediate. When focus is lost,
     * the update is delayed until the end of the frame to prevent flicker.
     * 
     * @param focusedField The newly focused field (may be null)
     * @param prevFocusedField The previously focused field (may be null)
     */
    function handleFocusedFieldChange(focusedField:FieldView, prevFocusedField:FieldView) {

        if (focusedField != null) {
            focusedFieldThisFrame = focusedField;
        }
        else {
            ceramic.App.app.onceFinishDraw(this, updateFocusedFieldThisFrame);
        }

    }

    /**
     * Updates the focused field reference for the current frame.
     * 
     * This method is called at the end of the frame when focus is lost,
     * ensuring smooth transitions without visual artifacts.
     */
    function updateFocusedFieldThisFrame() {

        focusedFieldThisFrame = focusedField;

    }

    /**
     * Early update callback that checks for focus changes.
     * 
     * Called every frame before regular updates to ensure focus state
     * is current when field views process their logic.
     * 
     * @param delta Time elapsed since last update in seconds
     */
    override function earlyUpdate(delta:Float):Void {

        updateFocusedField();

    }

    /**
     * Updates the currently focused field based on screen focus.
     * 
     * This method:
     * 1. Gets the currently focused visual from the screen
     * 2. Walks up the parent hierarchy looking for FieldView instances
     * 3. Handles RelatedToFieldView components that delegate focus
     * 4. Updates the focused field and notifies any previous field of focus loss
     * 
     * The method temporarily disables observation during the update to prevent
     * infinite loops from reactive updates.
     */
    public function updateFocusedField():Void {

        var focusedVisual = screen.focusedVisual;

        unobserve();

        var focusedField:FieldView = null;

        var testedVisual:Visual = focusedVisual;
        while (testedVisual != null) {
            if (testedVisual is FieldView) {
                focusedField = cast testedVisual;
                break;
            }
            else if (testedVisual is RelatedToFieldView) {
                var relatedToFieldView:RelatedToFieldView = cast testedVisual;
                var fieldView = relatedToFieldView.relatedFieldView();
                if (fieldView != null) {
                    focusedField = fieldView;
                    break;
                }
            }
            testedVisual = testedVisual.parent;
        }

        var prevFocusedField = this.focusedField;

        this.focusedField = focusedField;

        if (prevFocusedField != focusedField && Std.isOfType(prevFocusedField, FieldView)) {
            var prevFieldView:FieldView = cast prevFocusedField;
            prevFieldView.didLostFocus();
        }

        reobserve();

    }

}
