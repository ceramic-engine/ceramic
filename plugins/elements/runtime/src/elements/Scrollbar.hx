package elements;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Visual;
import elements.Context.context;
import tracker.Observable;

class Scrollbar extends Visual implements Observable {

    @observe public var theme:Theme = null;

    @observe var hover:Bool = false;

    @observe var pressed:Bool = false;

    var insetLeft:Float = 1;

    var insetRight:Float = 1;

    var insetTop:Float = 1;

    var insetBottom:Float = 1;

    var quad:Quad;

    override function set_width(width:Float):Float {
        super.set_width(width);
        quad.width = width - insetLeft - insetRight;
        return width;
    }

    override function set_height(height:Float):Float {
        super.set_height(height);
        quad.height = height - insetTop - insetBottom;
        return height;
    }

    public function inset(insetTop:Float, insetRight:Float, insetBottom:Float, insetLeft:Float):Void {
        this.insetTop = insetTop;
        this.insetRight = insetRight;
        this.insetBottom = insetBottom;
        this.insetLeft = insetLeft;
        quad.width = width - insetLeft - insetRight;
        quad.height = height - insetTop - insetBottom;
    }

    public function new() {

        super();

        quad = new Quad();
        quad.pos(insetLeft, insetTop);
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

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

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