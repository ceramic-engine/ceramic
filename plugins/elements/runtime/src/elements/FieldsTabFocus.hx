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
class FieldsTabFocus extends Entity implements Component {

    var entity:Visual;

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
        if (screen.focusedVisual != null && hasIndirectParent(screen.focusedVisual, entity)) {
            if (key.scanCode == ScanCode.TAB) {
                if (leftShiftPressed || rightShiftPressed) {
                    focusPrevField();
                }
                else {
                    focusNextField();
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
        var field:FieldView = findNextField(entity);
        if (field != null) {
            field.focus();
        }
        else if (screen.focusedVisual != null) {
            // Nothing found, walk from beginning
            findingWithFocused = null;
            field = findNextField(entity);
            if (field != null) {
                field.focus();
            }
        }
        findingWithFocused = null;

    }

    function focusPrevField() {

        // Look before currently focused field
        findingWithFocused = screen.focusedVisual;
        var field:FieldView = findPrevField(entity);
        if (field != null) {
            field.focus();
        }
        else if (screen.focusedVisual != null) {
            // Nothing found, walk from end
            findingWithFocused = null;
            field = findPrevField(entity);
            if (field != null) {
                field.focus();
            }
        }
        findingWithFocused = null;

    }

    function findNextField(walkVisual:Visual):FieldView {

        if (walkVisual == null) return null;
        if (walkVisual.children == null) return null;

        for (i in 0...walkVisual.children.length) {
            var child = walkVisual.children[i];
            if (findingWithFocused != null) {
                if (child == findingWithFocused) {
                    findingWithFocused = null;
                }
                else {
                    var inside = findNextField(child);
                    if (inside != null) {
                        if (!inside.getProperty('disabled'))
                            return inside;
                    }
                }
            }
            else {
                if (Std.isOfType(child, FieldView)) {
                    return cast child;
                }
                else {
                    var inside = findNextField(child);
                    if (inside != null) {
                        if (!inside.getProperty('disabled'))
                            return inside;
                    }
                }
            }
        }

        return null;

    }

    function findPrevField(walkVisual:Visual):FieldView {

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
                    var inside = findPrevField(child);
                    if (inside != null) {
                        if (!inside.getProperty('disabled'))
                            return inside;
                    }
                }
            }
            else {
                if (Std.isOfType(child, FieldView)) {
                    return cast child;
                }
                else {
                    var inside = findPrevField(child);
                    if (inside != null) {
                        if (!inside.getProperty('disabled'))
                            return inside;
                    }
                }
            }
            i--;
        }

        return null;

    }

    function hasIndirectParent(visual:Visual, targetParent:Visual):Bool {

        var parent = visual.parent;
        do {
            if (parent == targetParent) return true;
            parent = parent.parent;
        }
        while (parent != null);

        return false;

    }

}
