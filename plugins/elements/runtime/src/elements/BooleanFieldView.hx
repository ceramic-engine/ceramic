package elements;

import ceramic.Click;
import ceramic.Key;
import ceramic.Shortcuts.*;
import ceramic.View;
import elements.Context.context;
import tracker.Observable;

class BooleanFieldView extends FieldView {

    @observe public var theme:Theme = null;

    var switchContainer:View;

    var switchSquare:View;

/// Hooks

    public dynamic function setValue(field:BooleanFieldView, value:Bool):Void {

        // Default implementation does nothing

    }

/// Public properties

    @observe public var value:Bool = false;

    @observe public var inputStyle:InputStyle = DEFAULT;

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

    function toggleValue() {

        this.value = !value;
        setValue(this, this.value);

    }

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
