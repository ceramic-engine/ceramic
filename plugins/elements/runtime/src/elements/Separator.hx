package elements;

import ceramic.Quad;
import ceramic.View;
import elements.Context.context;

class Separator extends View {

    public var thickness(default, set):Float = 1;
    function set_thickness(thickness:Float):Float {
        if (this.thickness != thickness) {
            this.thickness = thickness;
            layoutDirty = true;
        }
        return thickness;
    }

    var quad:Quad;

    public function new() {

        super();

        transparent = true;

        quad = new Quad();
        add(quad);

        autorun(updateStyle);

    }

    override function layout() {

        quad.pos(0, height * 0.5);
        quad.size(width, thickness);

    }

    function updateStyle() {

        var theme = context.theme;

        quad.color = theme.mediumBorderColor;

    }

}
