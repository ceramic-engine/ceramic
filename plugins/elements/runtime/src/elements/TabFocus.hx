package elements;

import ceramic.Component;
import ceramic.Entity;
import ceramic.Key;
import ceramic.ScanCode;
import ceramic.Shortcuts.*;
import ceramic.Visual;
import elements.FieldView;

using ceramic.Extensions;

/** Update field focus from tab key events */
class TabFocus extends Entity implements Component {

    var entity:Visual;

    public var focusRoot:Visual = null;

/// Internal properties

    var leftShiftPressed:Bool = false;
    var rightShiftPressed:Bool = false;

    var findingWithFocused:Visual = null;

/// Lifecycle

    function bindAsComponent() {

        input.onKeyDown(this, handleKeyDown);
        input.onKeyUp(this, handleKeyUp);

    }

/// Internal

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

    function handleKeyUp(key:Key) {

        // Use shift pressed state to invert order of tab focus selection
        if (key.scanCode == ScanCode.LSHIFT) {
            leftShiftPressed = false;
        }
        else if (key.scanCode == ScanCode.RSHIFT) {
            rightShiftPressed = false;
        }

    }

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
