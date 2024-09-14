package elements;

import ceramic.Click;
import ceramic.Color;
import ceramic.Key;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.Timer;
import ceramic.Transform;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

class Button extends TextView implements Observable implements TabFocusable {

    @observe public var theme:Theme = null;

/// Components

    @component var click:Click;

/// Events

    @event function click();

/// Properties

    /**
     * If this field is managed by a WindowItem, this is the WindowItem.
     */
    public var windowItem:WindowItem = null;

    public var pressed(get,never):Bool;
    inline function get_pressed():Bool {
        return click.pressed;
    }

    @observe public var inputStyle:InputStyle = DEFAULT;

    @observe public var enabled(default, set):Bool = true;
    function set_enabled(enabled:Bool):Bool {
        if (this.enabled != enabled) {
            this.enabled = enabled;
            touchable = enabled;
            if (!enabled && unobservedFocused) {
                screen.focusedVisual = null;
            }
        }
        return disabled;
    }

    @:noCompletion public var disabled(get, set):Bool;
    function get_disabled():Bool return !enabled;
    function set_disabled(disabled:Bool):Bool return enabled = !disabled;

    @compute public function focused():Bool {

        var focusedVisual = screen.focusedVisual;

        unobserve();

        var focused = focusedVisual == this || (focusedVisual != null && focusedVisual.hasIndirectParent(this));

        reobserve();

        return focused;

    }

/// Internal

    @observe var hover:Bool = false;

    @observe var enterPressed:Bool = false;

/// Lifecycle

    public function new() {

        super();

        click = new Click();
        click.onClick(this, emitClick);

        align = CENTER;
        verticalAlign = CENTER;
        pointSize = 12;
        preRenderedSize = 20;
        padding(5, 2);

        transform = new Transform();

        onPointerOver(this, function(_) hover = true);
        onPointerOut(this, function(_) hover = false);

        input.onKeyDown(this, handleKeyDown);
        input.onKeyUp(this, handleKeyUp);

        autorun(updateStyle);

    }

/// Internal

    function handleKeyDown(key:Key) {

        if (key.scanCode == ENTER && focused && !enterPressed) {
            enterPressed = true;
            emitClick();
        }

    }

    function handleKeyUp(key:Key) {

        if (key.scanCode == ENTER) {
            enterPressed = false;
        }

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        var enabled = this.enabled;
        var focused = this.focused;
        var pressed = (this.pressed || this.enterPressed);

        if (pressed && enabled) {
            transform.ty = 1;
            transform.changedDirty = true;
        }
        else {
            transform.ty = 0;
            transform.changedDirty = true;
        }

        font = theme.mediumFont;
        textColor = theme.lightTextColor;

        if (inputStyle == OVERLAY) {
            minHeight = 25;
            borderSize = 1;
            borderPosition = INSIDE;
        }
        else {
            minHeight = 27;
            borderSize = 1;
            borderPosition = INSIDE;
            transparent = false;
            borderAlpha = 1;
        }

        if (inputStyle == OVERLAY) {
            if (enabled) {
                text.alpha = 1;
                if (pressed) {
                    transparent = false;
                    color = Color.WHITE;
                    alpha = 0.05;
                    borderColor = theme.lightTextColor;
                    borderAlpha = 0.33;
                }
                else if (focused) {
                    transparent = true;
                    borderColor = theme.buttonFocusedBorderColor;
                    borderAlpha = 1;
                }
                else if (hover) {
                    transparent = false;
                    color = Color.WHITE;
                    alpha = 0.025;
                    borderColor = theme.lightTextColor;
                    borderAlpha = 0.25;
                }
                else {
                    borderColor = theme.lightTextColor;
                    borderAlpha = 0.2;
                    transparent = true;
                }
            }
            else {
                borderAlpha = 0.1;
                text.alpha = 0.5;
                transparent = true;
            }
        }
        else {
            if (enabled) {
                alpha = 1;
                text.alpha = 1;

                if (pressed) {
                    color = theme.buttonPressedBackgroundColor;
                }
                else if (hover) {
                    color = theme.buttonOverBackgroundColor;
                }
                else {
                    color = theme.buttonBackgroundColor;
                }

                if (pressed) {
                    borderColor = theme.buttonPressedBackgroundColor;
                }
                else if (focused) {
                    borderColor = theme.buttonFocusedBorderColor;
                }
                else if (hover) {
                    borderColor = theme.lightBorderColor;
                }
                else {
                    borderColor = theme.lightBorderColor;
                }
                borderAlpha = 1;
            }
            else {
                alpha = 0.6;
                text.alpha = 0.5;
                color = theme.buttonBackgroundColor;
                borderColor = theme.lightBorderColor;
                borderAlpha = 0.5;
            }
        }

    }

    public function focus():Void {

        screen.focusedVisual = this;

    }

/// Tab focusable

    public function allowsTabFocus():Bool {

        return enabled;

    }

    public function tabFocus():Void {

        focus();

    }

    public function escapeTabFocus():Void {

        screen.focusedVisual = null;

    }

}
