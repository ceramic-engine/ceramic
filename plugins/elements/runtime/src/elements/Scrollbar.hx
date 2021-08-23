package elements;

import ceramic.Visual;
import ceramic.Quad;
import ceramic.Color;
import elements.Context.context;
import tracker.Observable;

class Scrollbar extends Visual implements Observable {

    @observe var hover:Bool = false;

    @observe var pressed:Bool = false;

    var quad:Quad;

    override function set_width(width:Float):Float {
        super.set_width(width);
        quad.width = width - 2;
        return width;
    }

    override function set_height(height:Float):Float {
        super.set_height(height);
        quad.height = height - 1;
        return height;
    }

    public function new() {

        super();

        quad = new Quad();
        quad.pos(1, 0);
        add(quad);

        onPointerDown(this, _ -> {
            pressed = true;
        });

        onPointerUp(this, _ -> {
            pressed = false;
        });

        onPointerOver(this, _ -> {
            hover = true;
        });

        onPointerOut(this, _ -> {
            hover = false;
        });

        autorun(updateStyle);

        size(12, 12);

    }

    function updateStyle() {

        var theme = context.theme;

        if (pressed) {
            quad.color = Color.interpolate(theme.lightBackgroundColor, theme.darkTextColor, 0.5);
        }
        else if (hover) {
            quad.color = Color.interpolate(theme.lightBackgroundColor, theme.darkTextColor, 0.25);
        }
        else {
            quad.color = theme.lightBackgroundColor;
        }

    }

}