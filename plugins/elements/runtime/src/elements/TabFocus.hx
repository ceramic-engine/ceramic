package elements;

import ceramic.Component;
import ceramic.Entity;
import ceramic.Key;
import ceramic.ScanCode;
import ceramic.Shortcuts.*;
import ceramic.Visual;
import elements.FieldView;

using ceramic.Extensions;

/**
 * Component for managing keyboard-based focus navigation using Tab key.
 * 
 * TabFocus provides automatic Tab/Shift+Tab navigation between TabFocusable elements
 * within a visual hierarchy. It handles focus traversal in both forward and backward
 * directions, and supports Escape key handling for focus escape behavior.
 * 
 * The component automatically finds focusable elements and manages focus transitions
 * based on their position in the visual hierarchy. It respects the focusRoot boundary
 * when specified, limiting focus navigation to a specific visual subtree.
 * 
 * Key features:
 * - Tab key navigation (forward focus)
 * - Shift+Tab navigation (backward focus)
 * - Escape key handling for focus escape
 * - Configurable focus root for bounded navigation
 * - Automatic detection of TabFocusable elements
 * - Circular navigation (wraps to beginning/end)
 * 
 * Usage example:
 * ```haxe
 * var tabFocus = new TabFocus();
 * tabFocus.focusRoot = myFormContainer; // Optional: limit to this subtree
 * myWindow.component('tabFocus', tabFocus);
 * ```
 */
class TabFocus extends Entity implements Component {

    /** The visual entity this component is attached to */
    var entity:Visual;

    /** 
     * Optional root visual that limits the scope of focus navigation.
     * 
     * When set, tab navigation will only consider TabFocusable elements within
     * this visual's hierarchy. If null, the entire entity hierarchy is considered.
     */
    public var focusRoot:Visual = null;

/// Internal properties

    /** Whether the left Shift key is currently pressed */
    var leftShiftPressed:Bool = false;
    
    /** Whether the right Shift key is currently pressed */
    var rightShiftPressed:Bool = false;

    /** 
     * Reference to the currently focused visual during navigation search.
     * 
     * Used internally to track position in the hierarchy when finding the next/previous
     * focusable element.
     */
    var findingWithFocused:Visual = null;

/// Lifecycle

    /**
     * Called when the component is bound to its entity.
     * 
     * Sets up keyboard event listeners for Tab navigation and Escape handling.
     */
    function bindAsComponent() {

        input.onKeyDown(this, handleKeyDown);
        input.onKeyUp(this, handleKeyUp);

    }

/// Internal

    /**
     * Handles key down events for focus navigation.
     * 
     * Processes Tab (forward), Shift+Tab (backward), and Escape key events
     * when the current focus is within the managed visual hierarchy.
     * 
     * @param key The key event information
     */
    function handleKeyDown(key:Key) {

        // Handle tab key to switch focus to next field
        if (screen.focusedVisual != null
            && (
                screen.focusedVisual == entity
                || screen.focusedVisual.hasIndirectParent(entity)
                || (
                    focusRoot != null
                    && (screen.focusedVisual == focusRoot || screen.focusedVisual.hasIndirectParent(focusRoot))
                )
            )) {
            if (key.scanCode == ScanCode.TAB) {
                if (leftShiftPressed || rightShiftPressed) {
                    focusPrevField();
                }
                else {
                    focusNextField();
                }
            }
            else if (key.scanCode == ScanCode.ESCAPE) {
                var currentFocusable = findCurrentFocusable();
                if (currentFocusable != null) {
                    currentFocusable.escapeTabFocus();
                    if (focusRoot != null && currentFocusable != findCurrentFocusable()) {
                        screen.focusedVisual = focusRoot;
                    }
                }
            }
        }

        // Use shift pressed state to invert order of tab focus selection
        if (key.scanCode == ScanCode.LSHIFT) {
            leftShiftPressed = true;
        }
        else if (key.scanCode == ScanCode.RSHIFT) {
            rightShiftPressed = true;
        }

    }

    /**
     * Handles key up events to track Shift key state.
     * 
     * Updates the shift key pressed state which determines navigation direction.
     * 
     * @param key The key event information
     */
    function handleKeyUp(key:Key) {

        // Use shift pressed state to invert order of tab focus selection
        if (key.scanCode == ScanCode.LSHIFT) {
            leftShiftPressed = false;
        }
        else if (key.scanCode == ScanCode.RSHIFT) {
            rightShiftPressed = false;
        }

    }

    /**
     * Moves focus to the next focusable element in the hierarchy.
     * 
     * Searches forward from the currently focused element. If no focusable element
     * is found after the current one, wraps around to search from the beginning.
     */
    function focusNextField() {

        // Look after currently focused field
        findingWithFocused = screen.focusedVisual;
        var focusable = findNextFocusable(entity);

        if (focusable != null) {
            focusable.tabFocus();
        }
        else if (screen.focusedVisual != null) {
            // Nothing found, walk from beginning
            findingWithFocused = null;
            focusable = findNextFocusable(entity);
            if (focusable != null) {
                focusable.tabFocus();
            }
        }
        findingWithFocused = null;

    }

    /**
     * Moves focus to the previous focusable element in the hierarchy.
     * 
     * Searches backward from the currently focused element. If no focusable element
     * is found before the current one, wraps around to search from the end.
     */
    function focusPrevField() {

        // Look before currently focused field
        findingWithFocused = screen.focusedVisual;
        var focusable = findPrevFocusable(entity);
        if (focusable != null) {
            focusable.tabFocus();
        }
        else if (screen.focusedVisual != null) {
            // Nothing found, walk from end
            findingWithFocused = null;
            focusable = findPrevFocusable(entity);
            if (focusable != null) {
                focusable.tabFocus();
            }
        }
        findingWithFocused = null;

    }

    /**
     * Recursively searches for the next TabFocusable element in the visual hierarchy.
     * 
     * Performs a depth-first search starting from the given visual. When findingWithFocused
     * is set, skips elements until that visual is found, then returns the next focusable element.
     * 
     * @param walkVisual The visual to start searching from
     * @return The next TabFocusable element, or null if none found
     */
    function findNextFocusable(walkVisual:Visual):TabFocusable {

        if (walkVisual == null) return null;
        if (walkVisual.children == null) return null;

        for (i in 0...walkVisual.children.length) {
            var child = walkVisual.children[i];
            if (findingWithFocused != null) {
                if (child == findingWithFocused) {
                    findingWithFocused = null;
                }
                else {
                    var inside = findNextFocusable(child);
                    if (inside != null) {
                        if (inside.allowsTabFocus())
                            return inside;
                    }
                }
            }
            else {
                if (child is TabFocusable) {
                    return cast child;
                }
                else {
                    var inside = findNextFocusable(child);
                    if (inside != null) {
                        if (inside.allowsTabFocus())
                            return inside;
                    }
                }
            }
        }

        return null;

    }

    /**
     * Recursively searches for the previous TabFocusable element in the visual hierarchy.
     * 
     * Performs a reverse depth-first search starting from the given visual. When findingWithFocused
     * is set, skips elements until that visual is found, then returns the previous focusable element.
     * 
     * @param walkVisual The visual to start searching from
     * @return The previous TabFocusable element, or null if none found
     */
    function findPrevFocusable(walkVisual:Visual):TabFocusable {

        if (walkVisual == null) return null;
        if (walkVisual.children == null) return null;

        var i = walkVisual.children.length - 1;
        while (i >= 0) {
            var child = walkVisual.children[i];
            if (findingWithFocused != null) {
                if (child == findingWithFocused) {
                    findingWithFocused = null;
                }
                else {
                    var inside = findPrevFocusable(child);
                    if (inside != null) {
                        if (inside.allowsTabFocus())
                            return inside;
                    }
                }
            }
            else {
                if (child is TabFocusable) {
                    return cast child;
                }
                else {
                    var inside = findPrevFocusable(child);
                    if (inside != null) {
                        if (inside.allowsTabFocus())
                            return inside;
                    }
                }
            }
            i--;
        }

        return null;

    }

    /**
     * Finds the currently focused TabFocusable element.
     * 
     * Checks if the currently focused visual implements TabFocusable, or searches
     * up the parent hierarchy to find a TabFocusable ancestor.
     * 
     * @return The currently focused TabFocusable element, or null if none
     */
    function findCurrentFocusable():TabFocusable {

        var focusedVisual = screen.focusedVisual;
        if (focusedVisual != null) {
            var visual = focusedVisual;
            if (visual is TabFocusable) {
                return cast visual;
            }
            return visual.firstParentWithClass(TabFocusable);
        }

        return null;

    }

}
