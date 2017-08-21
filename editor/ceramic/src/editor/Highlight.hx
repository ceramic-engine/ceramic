package editor;

import ceramic.Visual;
import ceramic.Quad;
import ceramic.Color;
import ceramic.Point;
import ceramic.TouchInfo;
import ceramic.Shortcuts.*;

enum HighlightCorner {
    TOP_LEFT;
    TOP_RIGHT;
    BOTTOM_LEFT;
    BOTTOM_RIGHT;
}

class Highlight extends Visual {

/// Events

    @event function cornerDown(corner:HighlightCorner, info:TouchInfo);

    @event function cornerOver(corner:HighlightCorner, info:TouchInfo);

    @event function cornerOut(corner:HighlightCorner, info:TouchInfo);

/// Properties

    public var cornerTopLeft = new Quad();

    public var cornerTopRight = new Quad();

    public var cornerBottomLeft = new Quad();

    public var cornerBottomRight = new Quad();

    public var anchorCrossVBar = new Quad();

    public var anchorCrossHBar = new Quad();

    public var topDistance(default,null):Float;

    public var rightDistance(default,null):Float;

    public var bottomDistance(default,null):Float;

    public var leftDistance(default,null):Float;

    var borderTop = new Quad();

    var borderRight = new Quad();

    var borderBottom = new Quad();

    var borderLeft = new Quad();

    public var pointTopLeft(default,null) = new Point();

    public var pointTopRight(default,null) = new Point();

    public var pointBottomLeft(default,null) = new Point();

    public var pointBottomRight(default,null) = new Point();

    public var pointAnchor(default,null) = new Point();

    public var cornerSize(default,set):Float = 8;
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

    public var crossWidth(default,set):Float = 2;
    function set_crossWidth(crossWidth:Float):Float {
        if (this.crossWidth == crossWidth) return crossWidth;
        this.crossWidth = crossWidth;
        updateCornersAndBorders();
        return crossWidth;
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
        anchorCrossVBar.color = color;
        anchorCrossHBar.color = color;
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
        anchorCrossVBar.depth = 1.75;
        anchorCrossHBar.depth = 1.75;

        add(cornerTopLeft);
        add(cornerTopRight);
        add(cornerBottomLeft);
        add(cornerBottomRight);
        add(borderTop);
        add(borderRight);
        add(borderBottom);
        add(borderLeft);
        add(anchorCrossVBar);
        add(anchorCrossHBar);

        cornerTopLeft.onDown(this, function(info) {
            emitCornerDown(TOP_LEFT, info);
        });
        cornerTopRight.onDown(this, function(info) {
            emitCornerDown(TOP_RIGHT, info);
        });
        cornerBottomLeft.onDown(this, function(info) {
            emitCornerDown(BOTTOM_LEFT, info);
        });
        cornerBottomRight.onDown(this, function(info) {
            emitCornerDown(BOTTOM_RIGHT, info);
        });

        cornerTopLeft.onOver(this, function(info) {
            emitCornerOver(TOP_LEFT, info);
        });
        cornerTopRight.onOver(this, function(info) {
            emitCornerOver(TOP_RIGHT, info);
        });
        cornerBottomLeft.onOver(this, function(info) {
            emitCornerOver(BOTTOM_LEFT, info);
        });
        cornerBottomRight.onOver(this, function(info) {
            emitCornerOver(BOTTOM_RIGHT, info);
        });

        cornerTopLeft.onOut(this, function(info) {
            emitCornerOut(TOP_LEFT, info);
        });
        cornerTopRight.onOut(this, function(info) {
            emitCornerOut(TOP_RIGHT, info);
        });
        cornerBottomLeft.onOut(this, function(info) {
            emitCornerOut(BOTTOM_LEFT, info);
        });
        cornerBottomRight.onOut(this, function(info) {
            emitCornerOut(BOTTOM_RIGHT, info);
        });

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
        visual.visualToScreen(visual.width * visual.anchorX, visual.height * visual.anchorY, pointAnchor);

        updateCornersAndBorders();

    } //wrapVisual

/// Internal

    function updateCornersAndBorders() {

        anchorCrossVBar.anchor(0.5, 0.5);
        anchorCrossVBar.pos(pointAnchor.x, pointAnchor.y);
        anchorCrossVBar.size(8, crossWidth);

        anchorCrossHBar.anchor(0.5, 0.5);
        anchorCrossHBar.pos(pointAnchor.x, pointAnchor.y);
        anchorCrossHBar.size(crossWidth, 8);

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

        topDistance = Math.sqrt(a * a + b * b);
        borderTop.size(topDistance, borderSize);
        borderTop.anchor(0, 0.5);
        borderTop.pos(pointTopLeft.x, pointTopLeft.y);
        borderTop.rotation = r;

        a = pointBottomRight.x - pointTopRight.x;
        b = pointBottomRight.y - pointTopRight.y;
        r = Math.atan2(pointBottomRight.y - pointTopRight.y, pointBottomRight.x - pointTopRight.x) * 180.0 / Math.PI;

        rightDistance = Math.sqrt(a * a + b * b);
        borderRight.size(rightDistance, borderSize);
        borderRight.anchor(0, 0.5);
        borderRight.pos(pointTopRight.x, pointTopRight.y);
        borderRight.rotation = r;

        a = pointBottomLeft.x - pointBottomRight.x;
        b = pointBottomLeft.y - pointBottomRight.y;
        r = Math.atan2(pointBottomLeft.y - pointBottomRight.y, pointBottomLeft.x - pointBottomRight.x) * 180.0 / Math.PI;

        bottomDistance = Math.sqrt(a * a + b * b);
        borderBottom.size(bottomDistance, borderSize);
        borderBottom.anchor(0, 0.5);
        borderBottom.pos(pointBottomRight.x, pointBottomRight.y);
        borderBottom.rotation = r;

        a = pointTopLeft.x - pointBottomLeft.x;
        b = pointTopLeft.y - pointBottomLeft.y;
        r = Math.atan2(pointTopLeft.y - pointBottomLeft.y, pointTopLeft.x - pointBottomLeft.x) * 180.0 / Math.PI;

        leftDistance = Math.sqrt(a * a + b * b);
        borderLeft.size(leftDistance, borderSize);
        borderLeft.anchor(0, 0.5);
        borderLeft.pos(pointBottomLeft.x, pointBottomLeft.y);
        borderLeft.rotation = r;

    } //updateCornersPosition

} //Highlight
