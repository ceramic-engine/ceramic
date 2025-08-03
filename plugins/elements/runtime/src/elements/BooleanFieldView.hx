package elements;

import ceramic.Click;
import ceramic.Key;
import ceramic.Shortcuts.*;
import ceramic.View;
import elements.Context.context;
import tracker.Observable;

/**
 * A toggle switch UI element for boolean (true/false) values.
 *
 * Displays as a sliding switch that can be toggled between on and off states.
 * Supports keyboard navigation (Space to toggle, Enter for on, Backspace/Delete for off)
 * and mouse/touch interaction.
 *
 * The visual style adapts based on the `inputStyle` property:
 * - DEFAULT: Standard switch with background
 * - OVERLAY: Transparent background, suitable for overlays
 * - MINIMAL: Minimal style with just borders
 *
 * @see FieldView
 * @see InputStyle
 */
class BooleanFieldView extends FieldView {

    /** Custom theme override for this field */
    @observe public var theme:Theme = null;

    /** Container view for the switch background */
    var switchContainer:View;

    /** The sliding square indicator within the switch */
    var switchSquare:View;

/// Hooks

    /**
     * Hook called when the boolean value changes.
     * Override this to handle value updates.
     *
     * @param field The field instance (this)
     * @param value The new boolean value
     */
    public dynamic function setValue(field:BooleanFieldView, value:Bool):Void {

        // Default implementation does nothing

    }

/// Public properties

    /** The current boolean value (true = on, false = off) */
    @observe public var value:Bool = false;

    /** Visual style of the switch (DEFAULT, OVERLAY, or MINIMAL) */
    @observe public var inputStyle:InputStyle = DEFAULT;

    /** Whether the switch is disabled (non-interactive) */
    @observe public var disabled(default, set):Bool = false;
    function set_disabled(disabled:Bool):Bool {
        if (this.disabled != disabled) {
            this.disabled = disabled;
            touchable = !disabled;
            if (disabled && unobservedFocused) {
                screen.focusedVisual = null;
            }
        }
        return disabled;
    }

/// Internal properties

    /**
     * Creates a new BooleanFieldView with a toggle switch.
     * Sets up the visual components and interaction handlers.
     */
    public function new() {

        super();

        direction = HORIZONTAL;
        align = RIGHT;

        var pad = 7;
        var w = 27;

        switchContainer = new View();
        switchContainer.padding(pad);
        switchContainer.viewSize(w, w);
        switchContainer.borderPosition = INSIDE;
        add(switchContainer);

        switchSquare = new View();
        switchSquare.transparent = false;
        switchSquare.size(w - pad * 2, w - pad * 2);
        switchContainer.add(switchSquare);

        switchContainer.onLayout(this, () -> {
            app.oncePostFlushImmediate(layoutSwitchContainer);
        });

        autorun(updateStyle);
        onValueChange(this, function(_, _) {
            switchContainer.layoutDirty = true;
        });

        #if !(ios || android)
        switchContainer.onPointerDown(this, function(_) {
            toggleValue();
        });
        #else
        var click = new Click();
        switchContainer.component('click', click);
        click.onClick(this, function() {
            toggleValue();
        });
        #end

        input.onKeyDown(this, handleKeyDown);

    }

/// Layout

    /**
     * Positions the switch indicator based on the current value.
     * Slides to the right when true, left when false.
     */
    function layoutSwitchContainer() {

        if (destroyed)
            return;

        if (value) {
            switchSquare.pos(
                switchContainer.width - switchSquare.width - switchContainer.paddingRight,
                switchContainer.paddingTop
            );
        }
        else {
            switchSquare.pos(
                switchContainer.paddingLeft,
                switchContainer.paddingTop
            );
        }

    }

/// Internal

    /**
     * Handles keyboard input for the switch.
     * - Space: Toggle value
     * - Enter: Set to true
     * - Backspace/Delete: Set to false
     *
     * @param key The key event
     */
    function handleKeyDown(key:Key) {

        if (FieldSystem.shared.focusedField != this) return;

        if (key.scanCode == SPACE) {
            toggleValue();
        }
        else if (key.scanCode == ENTER) {
            if (!this.value) {
                this.value = true;
                setValue(this, true);
            }
        }
        else if (key.scanCode == BACKSPACE || key.scanCode == DELETE) {
            if (this.value) {
                this.value = false;
                setValue(this, false);
            }
        }

    }

    /**
     * Toggles the boolean value between true and false.
     * Calls the setValue hook with the new value.
     */
    function toggleValue() {

        this.value = !value;
        setValue(this, this.value);

    }

    /**
     * Updates the visual style of the switch based on theme and state.
     * Applies different colors and borders for focused, disabled, and value states.
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (inputStyle == OVERLAY || inputStyle == MINIMAL) {
            switchContainer.transparent = true;
        }
        else {
            switchContainer.transparent = false;
            switchContainer.color = theme.darkBackgroundColor;
        }

        if (value) {
            switchSquare.transparent = false;
            switchSquare.color = disabled ? theme.darkTextColor : theme.mediumTextColor;
        }
        else {
            switchSquare.transparent = (inputStyle == OVERLAY);
            switchSquare.color = theme.darkBackgroundColor;
        }

        if (inputStyle == MINIMAL) {
            switchContainer.borderSize = 0;
            switchContainer.transparent = true;

            switchSquare.borderSize = 1;
            switchSquare.borderPosition = OUTSIDE;
            switchSquare.borderColor = theme.darkBorderColor;
        }
        else {
            switchContainer.borderSize = 1;
            switchContainer.transparent = false;

            switchSquare.borderSize = 0;

            if (focused) {
                switchContainer.borderColor = theme.focusedFieldBorderColor;
            }
            else if (disabled) {
                switchContainer.borderColor = theme.mediumBorderColor;
            }
            else {
                switchContainer.borderColor = theme.lightBorderColor;
            }
        }

    }

}
