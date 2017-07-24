package editor;

import ceramic.Visual;
import ceramic.Quad;
import ceramic.Color;
import ceramic.Shortcuts.*;

class Highlight extends Visual {

/// Properties

    var cornerTopLeft = new Quad();

    var cornerTopRight = new Quad();

    var cornerBottomLeft = new Quad();

    var cornerBottomRight = new Quad();

    var borderTop = new Quad();

    var borderRight = new Quad();

    var borderBottom = new Quad();

    var borderLeft = new Quad();

    public var cornerSize(default,set):Float = 5;
    function set_cornerSize(cornerSize:Float):Float {
        if (this.cornerSize == cornerSize) return cornerSize;
        this.cornerSize = cornerSize;
        updateCornersAndBorders();
        return cornerSize;
    }

    public var borderSize(default,set):Float = 1;
    function set_borderSize(borderSize:Float):Float {
        if (this.borderSize == borderSize) return borderSize;
        this.borderSize = borderSize;
        updateCornersAndBorders();
        return borderSize;
    }

    public var color(default,set):Color;
    function set_color(color:Int):Int {
        if (this.color == color) return color;
        this.color = color;
        cornerTopLeft.color = color;
        cornerTopRight.color = color;
        cornerBottomLeft.color = color;
        cornerBottomRight.color = color;
        borderTop.color = color;
        borderRight.color = color;
        borderBottom.color = color;
        borderLeft.color = color;
        return color;
    }

/// Lifecycle

    public function new() {

        super();

        childrenDepthRange = 1;

        cornerTopLeft.depth = 2;
        cornerTopRight.depth = 2;
        cornerBottomLeft.depth = 2;
        cornerBottomRight.depth = 2;
        borderTop.depth = 1.5;
        borderRight.depth = 1.5;
        borderBottom.depth = 1.5;
        borderLeft.depth = 1.5;

        add(cornerTopLeft);
        add(cornerTopRight);
        add(cornerBottomLeft);
        add(cornerBottomRight);
        add(borderTop);
        add(borderRight);
        add(borderBottom);
        add(borderLeft);

        color = 0xFF0000;

        updateCornersAndBorders();

    } //new

/// Overrides

    override function set_width(width:Float):Float {
        if (this.width == width) return width;
        super.set_width(width);

        updateCornersAndBorders();

        return width;
    }

    override function set_height(height:Float):Float {
        if (this.height == height) return height;
        super.set_height(height);

        updateCornersAndBorders();

        return height;
    }

/// Internal

    function updateCornersAndBorders() {

        cornerTopLeft.size(cornerSize, cornerSize);
        cornerTopLeft.anchor(0.5, 0.5);
        cornerTopLeft.pos(0, 0);

        cornerTopRight.size(cornerSize, cornerSize);
        cornerTopRight.anchor(0.5, 0.5);
        cornerTopRight.pos(width / scaleX, 0);

        cornerBottomLeft.size(cornerSize, cornerSize);
        cornerBottomLeft.anchor(0.5, 0.5);
        cornerBottomLeft.pos(0, height / scaleY);

        cornerBottomRight.size(cornerSize, cornerSize);
        cornerBottomRight.anchor(0.5, 0.5);
        cornerBottomRight.pos(width / scaleX, height / scaleY);

        borderTop.size(width / scaleX, borderSize);
        borderTop.anchor(0.5, 1);
        borderTop.pos(width * 0.5 / scaleX, 0);

        borderBottom.size(width / scaleX, borderSize);
        borderBottom.anchor(0.5, 0);
        borderBottom.pos(width * 0.5 / scaleX, height / scaleY);

        borderLeft.size(borderSize, height / scaleY);
        borderLeft.anchor(1, 0.5);
        borderLeft.pos(0, height * 0.5 / scaleY);

        borderRight.size(borderSize, height / scaleY);
        borderRight.anchor(0, 0.5);
        borderRight.pos(width / scaleX, height * 0.5 / scaleY);

    } //updateCornersPosition

} //Highlight
