package elements;

import ceramic.Click;
import ceramic.Color;
import ceramic.LongPress;
import ceramic.Transform;
import elements.Context.context;

class ClickableIconView extends EntypoIconView {

    @observe public var theme:Theme = null;

    @observe var hover:Bool = false;

    @observe public var disabled:Bool = false;

    @observe public var hoverStyle:Bool = true;

    @event function click();

    @event function longPress();

    public function new() {

        super();

        transform = new Transform();

        var click = new Click();
        component('click', click);
        click.onClick(this, () -> {
            emitClick();
        });

        var longPress = new LongPress(info -> {
            emitLongPress();
        }, click);
        component('longPress', longPress);

        onPointerDown(this, _ -> {
            transform.ty = 1;
            transform.changedDirty = true;
        });
        onPointerUp(this, _ -> {
            transform.ty = 0;
            transform.changedDirty = true;
        });

        onPointerOver(this, _ -> {
            hover = true;
        });

        onPointerOut(this, _ -> {
            hover = false;
        });

        autorun(() -> {
            touchable = !disabled;
        });
        autorun(updateStyle);

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        var textColor = hover || !hoverStyle ? theme.iconColor : Color.interpolate(theme.mediumBackgroundColor, theme.iconColor, 0.7);

        if (disabled) {
            textColor = Color.interpolate(textColor, theme.darkBackgroundColor, 0.5);
        }

        this.textColor = textColor;

    }

}