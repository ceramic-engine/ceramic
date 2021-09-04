package elements;

import ceramic.Click;
import ceramic.Color;
import ceramic.TextView;
import ceramic.Transform;
import elements.Context.context;
import tracker.Observable;

class Button extends TextView implements Observable {

/// Components

    @component var click:Click;

/// Events

    @event function click();

/// Properties

    public var pressed(get,never):Bool;
    inline function get_pressed():Bool {
        return click.pressed;
    }

    @observe public var inputStyle:InputStyle = DEFAULT;

    @observe public var enabled:Bool = true;

/// Internal

    @observe var hover:Bool = false;

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

        autorun(updateStyle);

    }

/// Internal

    function updateStyle() {

        var theme = context.theme;

        var enabled = this.enabled;

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
            borderSize = 1;
            borderPosition = INSIDE;
        }
        else {
            borderSize = 1;
            borderPosition = INSIDE;
            transparent = false;
            border.alpha = 1;
        }

        if (inputStyle == OVERLAY) {
            borderColor = theme.lightTextColor;
            if (enabled) {
                border.alpha = 0.2;
                text.alpha = 1;
                if (pressed) {
                    transparent = false;
                    color = Color.WHITE;
                    alpha = 0.05;
                    border.alpha = 0.33;
                }
                else if (hover) {
                    transparent = false;
                    color = Color.WHITE;
                    alpha = 0.025;
                    border.alpha = 0.25;
                }
                else {
                    transparent = true;
                }
            }
            else {
                border.alpha = 0.1;
                text.alpha = 0.5;
                transparent = true;
            }
        }
        else {
            if (enabled) {
                alpha = 1;
                if (pressed) {
                    color = theme.buttonPressedBackgroundColor;
                    borderColor = theme.buttonPressedBackgroundColor;
                }
                else if (hover) {
                    color = theme.buttonOverBackgroundColor;
                    borderColor = theme.lightBorderColor;
                }
                else {
                    color = theme.buttonBackgroundColor;
                    borderColor = theme.lightBorderColor;
                }
            }
            else {
                alpha = 0.6;
                color = theme.buttonBackgroundColor;
                borderColor = theme.lightBorderColor;
            }
        }

    }

}
