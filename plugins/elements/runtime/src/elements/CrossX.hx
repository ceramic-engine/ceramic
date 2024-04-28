package elements;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Visual;

class CrossX extends Visual {

    var quad0:Quad;

    var quad1:Quad;

    @content public var thickness:Float = 2;

    @content public var internalScale:Float = 1;

    public var color(default, set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color != color) {
            this.color = color;
            quad0.color = color;
            quad1.color = color;
        }
        return color;
    }

    override function set_width(width:Float):Float {
        if (this.width != width) {
            super.set_width(width);
            contentDirty = true;
        }
        return width;
    }

    override function set_height(height:Float):Float {
        if (this.height != height) {
            super.set_height(height);
            contentDirty = true;
        }
        return height;
    }

    public function new() {

        super();

        quad0 = new Quad();
        quad0.color = this.color;
        quad0.anchor(0.5, 0.5);
        quad0.rotation = 45;
        add(quad0);

        quad1 = new Quad();
        quad1.color = this.color;
        quad1.anchor(0.5, 0.5);
        quad1.rotation = -45;
        add(quad1);

        size(16, 16);

        contentDirty = true;

    }

    override function computeContent() {

        contentDirty = false;

        quad0.pos(width * 0.5, height * 0.5);
        quad0.size(width * 0.7, thickness);
        quad0.scale(internalScale);

        quad1.pos(quad0.x, quad0.y);
        quad1.size(quad0.width, quad0.height);
        quad1.scale(internalScale);

    }

}