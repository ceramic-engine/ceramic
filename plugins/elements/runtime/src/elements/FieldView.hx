package elements;

import ceramic.KeyCode;
import ceramic.LinearLayout;
import ceramic.Point;
import ceramic.ScanCode;
import ceramic.Shortcuts.*;
import ceramic.View;
import elements.FieldSystem;
import tracker.Observable;

using ceramic.Extensions;

/**
 * Base class for interactive field views in the Elements UI framework.
 * 
 * FieldView provides a foundation for creating focusable input fields that integrate
 * with the field focus system. It handles:
 * - Focus management and visual feedback
 * - Tab navigation support
 * - Automatic scrolling to ensure visibility when focused
 * - Integration with the global FieldSystem
 * 
 * Subclasses should override `didLostFocus()` to handle cleanup when focus is lost.
 * 
 * @see FieldSystem
 * @see TabFocusable
 */
class FieldView extends LinearLayout implements Observable implements TabFocusable {

    /**
     * Shared point instance used for coordinate calculations.
     */
    static var _point = new Point();

/// Public properties

    /**
     * Whether this field currently has focus.
     * 
     * This is a computed property that checks with the global FieldSystem
     * to determine if this field is the currently focused field.
     * 
     * @return `true` if this field has focus, `false` otherwise
     */
    @compute public function focused():Bool {

        FieldSystem.shared.updateFocusedField();
        return FieldSystem.shared.focusedField == this;

    }

    /**
     * If this field is managed by a WindowItem, this is the WindowItem.
     * Used for window-specific field management and coordination.
     */
    public var windowItem:WindowItem = null;

/// Internal

    /**
     * Tracks whether this field had focus during the current frame.
     * Used for keyboard input handling to prevent key conflicts.
     */
    var focusedThisFrame:Bool = false;

/// Lifecycle

    /**
     * Creates a new FieldView instance.
     * 
     * Initializes the field with:
     * - Transparent background
     * - Horizontal layout direction
     * - Pointer event handling for focus
     * - Focus change tracking
     */
    public function new() {

        super();

        transparent = true;
        direction = HORIZONTAL;

        bindPointerEvents();

        focusedThisFrame = focused;
        onFocusedChange(this, handleFocusedChange);

    }

    /**
     * Handles focus state changes.
     * Updates the focusedThisFrame flag immediately when gaining focus,
     * and defers the update until end of frame when losing focus.
     * 
     * @param focused The new focus state
     * @param prevFocused The previous focus state
     */
    function handleFocusedChange(focused:Bool, prevFocused:Bool) {

        if (focused) {
            focusedThisFrame = true;
        }
        else {
            ceramic.App.app.onceFinishDraw(this, updateFocusedThisFrame);
        }

    }

    /**
     * Updates the focusedThisFrame flag at the end of the frame.
     * Called when the field loses focus to ensure proper state tracking.
     */
    function updateFocusedThisFrame() {

        focusedThisFrame = focused;

    }

/// Public API

    /**
     * Gives focus to this field.
     * 
     * Sets this field as the screen's focused visual and ensures
     * it's visible within any containing scrollable area.
     */
    public function focus():Void {

        screen.focusedVisual = this;

        makeVisibleInForm();

    }

    /**
     * Ensures this field is visible within its containing scrollable form.
     * 
     * If the field is inside a ScrollingLayout, this method will automatically
     * scroll the container to make the field fully visible. The method adds
     * 8 pixels of padding above and below the field for better visual appearance.
     * 
     * If the field is not inside a scrollable container, this method does nothing.
     */
    public function makeVisibleInForm():Void {

        var scrollingLayout = getScrollingLayout();
        if (scrollingLayout == null) {
            // Nothing to do if there is no scrolling layout
            return;
        }

        var scroller = scrollingLayout.scroller;

        scroller.content.visualToScreen(0, 0, _point);
        var formY = _point.y;

        this.visualToScreen(0, 0, _point);
        var fieldStart = _point.y;
        this.visualToScreen(0, height, _point);
        var fieldEnd = _point.y;

        var targetStart = fieldStart - formY;
        var targetEnd = fieldEnd - formY;

        // Tweak values a bit to make it look nicer
        targetStart -= 8;
        targetEnd += 8;

        var startVisible = scroller.isContentPositionInBounds(0, targetStart);
        var endVisible = scroller.isContentPositionInBounds(0, targetEnd);

        scroller.ensureContentPositionIsInBounds(0, targetStart);
        scroller.ensureContentPositionIsInBounds(0, targetEnd);

    }

/// Internal

    /**
     * Finds the containing ScrollingLayout by traversing up the visual hierarchy.
     * 
     * @return The parent ScrollingLayout if found, null otherwise
     */
    function getScrollingLayout():ScrollingLayout<View> {

        var parent = this.parent;

        while (parent != null) {
            if (Std.isOfType(parent, ScrollingLayout)) {
                var scrollingLayout:ScrollingLayout<View> = cast parent;
                return scrollingLayout;
            }
            parent = parent.parent;
        }

        return null;

    }

    /**
     * Called when this field loses focus.
     * 
     * This method is called by the FieldSystem when focus moves to another field
     * or when focus is cleared. Subclasses should override this method to perform
     * any necessary cleanup, such as:
     * - Hiding virtual keyboards
     * - Committing pending changes
     * - Updating visual state
     * 
     * @allow elements.FieldSystem
     */
    @:allow(elements.FieldSystem)
    function didLostFocus():Void {

        // Override in subclasses

    }

    /**
     * Sets up pointer event handling to make this field focusable.
     * 
     * By binding to the pointer down event, this field becomes eligible
     * to receive focus when clicked or tapped.
     */
    function bindPointerEvents() {

        // To make it focusable
        onPointerDown(this, function(_) {});

    }

/// Tab focusable

    /**
     * Whether this field can receive focus through tab navigation.
     * 
     * Fields are focusable by tab unless they have a 'disabled' property set to true.
     * 
     * @return `true` if the field can be focused via tab, `false` if disabled
     */
    public function allowsTabFocus():Bool {

        return !this.getProperty('disabled');

    }

    /**
     * Gives focus to this field via tab navigation.
     * 
     * Called by the tab focus system when this field is selected
     * through keyboard navigation.
     */
    public function tabFocus():Void {

        focus();

    }

    /**
     * Removes focus from this field when escaping tab navigation.
     * 
     * Called when the user presses Escape to exit tab navigation mode.
     * Only clears focus if this field currently has focus.
     */
    public function escapeTabFocus():Void {

        if (focused) {
            screen.focusedVisual = null;
        }

    }

    /**
     * Tests if the given coordinates hit this field.
     * 
     * Used by the tab focus system to determine if a pointer event
     * occurred within this field's bounds.
     * 
     * @param x The x coordinate to test
     * @param y The y coordinate to test
     * @return `true` if the coordinates are within this field's bounds
     */
    public function hitsSelfOrDerived(x:Float, y:Float):Bool {

        return hits(x, y);

    }

    /**
     * Checks if this field uses the specified scan code.
     * 
     * Fields consume ESCAPE and ENTER keys when focused to handle
     * field-specific actions like canceling or confirming input.
     * 
     * @param scanCode The scan code to check
     * @return `true` if this field uses the scan code when focused
     */
    public function usesScanCode(scanCode:ScanCode):Bool {

        return focusedThisFrame && (scanCode == ESCAPE || scanCode == ENTER);

    }

    /**
     * Checks if this field uses the specified key code.
     * 
     * Fields consume ESCAPE and ENTER keys when focused to handle
     * field-specific actions like canceling or confirming input.
     * 
     * @param keyCode The key code to check
     * @return `true` if this field uses the key code when focused
     */
    public function usesKeyCode(keyCode:KeyCode):Bool {

        return focusedThisFrame && (keyCode == ESCAPE || keyCode == ENTER);

    }

}
