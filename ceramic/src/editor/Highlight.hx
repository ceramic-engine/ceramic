package editor;

import ceramic.Visual;
import ceramic.Quad;
import ceramic.Color;
import ceramic.Point;
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

    var pointTopLeft = new Point();

    var pointTopRight = new Point();

    var pointBottomLeft = new Point();

    var pointBottomRight = new Point();

    public var cornerSize(default,set):Float = 6;
    function set_cornerSize(cornerSize:Float):Float {
        if (this.cornerSize == cornerSize) return cornerSize;
        this.cornerSize = cornerSize;
        updateCornersAndBorders();
        return cornerSize;
    }

    public var borderSize(default,set):Float = 2;
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

        childrenDepthRange = 0.5;

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

/// Public API

    public function wrapVisual(visual:Visual):Void {

        visual.visualToScreen(0, 0, pointTopLeft);
        visual.visualToScreen(visual.width, 0, pointTopRight);
        visual.visualToScreen(0, visual.height, pointBottomLeft);
        visual.visualToScreen(visual.width, visual.height, pointBottomRight);

        updateCornersAndBorders();

    } //wrapVisual

/// Internal

    function updateCornersAndBorders() {

        cornerTopLeft.size(cornerSize, cornerSize);
        cornerTopLeft.anchor(0.5, 0.5);
        cornerTopLeft.pos(pointTopLeft.x, pointTopLeft.y);

        cornerTopRight.size(cornerSize, cornerSize);
        cornerTopRight.anchor(0.5, 0.5);
        cornerTopRight.pos(pointTopRight.x, pointTopRight.y);

        cornerBottomLeft.size(cornerSize, cornerSize);
        cornerBottomLeft.anchor(0.5, 0.5);
        cornerBottomLeft.pos(pointBottomLeft.x, pointBottomLeft.y);

        cornerBottomRight.size(cornerSize, cornerSize);
        cornerBottomRight.anchor(0.5, 0.5);
        cornerBottomRight.pos(pointBottomRight.x, pointBottomRight.y);

        var a = pointTopRight.x - pointTopLeft.x;
        var b = pointTopRight.y - pointTopLeft.y;
        var r = Math.atan2(pointTopRight.y - pointTopLeft.y, pointTopRight.x - pointTopLeft.x) * 180.0 / Math.PI;

        borderTop.size(Math.sqrt(a * a + b * b), borderSize);
        borderTop.anchor(0, 0.5);
        borderTop.pos(pointTopLeft.x, pointTopLeft.y);
        borderTop.rotation = r;

        a = pointBottomRight.x - pointTopRight.x;
        b = pointBottomRight.y - pointTopRight.y;
        r = Math.atan2(pointBottomRight.y - pointTopRight.y, pointBottomRight.x - pointTopRight.x) * 180.0 / Math.PI;

        borderRight.size(Math.sqrt(a * a + b * b), borderSize);
        borderRight.anchor(0, 0.5);
        borderRight.pos(pointTopRight.x, pointTopRight.y);
        borderRight.rotation = r;

        a = pointBottomLeft.x - pointBottomRight.x;
        b = pointBottomLeft.y - pointBottomRight.y;
        r = Math.atan2(pointBottomLeft.y - pointBottomRight.y, pointBottomLeft.x - pointBottomRight.x) * 180.0 / Math.PI;

        borderBottom.size(Math.sqrt(a * a + b * b), borderSize);
        borderBottom.anchor(0, 0.5);
        borderBottom.pos(pointBottomRight.x, pointBottomRight.y);
        borderBottom.rotation = r;

        a = pointTopLeft.x - pointBottomLeft.x;
        b = pointTopLeft.y - pointBottomLeft.y;
        r = Math.atan2(pointTopLeft.y - pointBottomLeft.y, pointTopLeft.x - pointBottomLeft.x) * 180.0 / Math.PI;

        borderLeft.size(Math.sqrt(a * a + b * b), borderSize);
        borderLeft.anchor(0, 0.5);
        borderLeft.pos(pointBottomLeft.x, pointBottomLeft.y);
        borderLeft.rotation = r;

    } //updateCornersPosition

} //Highlight
