// Ported from gpui-pre 0.3.10: src/text_system/line.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A line of text that has been shaped, decorated, and wrapped by the text layout system.
 *
 * Rust derefs `WrappedLine` to its `WrappedLineLayout`: use the `layout`
 * field (or the forwarding methods) here.
 */
class WrappedLine {

    public var layout:WrappedLineLayout;

    /** The text that was shaped for this line. */
    public var text:String;

    public var decorationRuns:Array<DecorationRun>;

    public function new(layout:WrappedLineLayout, text:String, ?decorationRuns:Array<DecorationRun>) {
        this.layout = layout;
        this.text = text;
        this.decorationRuns = decorationRuns != null ? decorationRuns : [];
    }

    /** The length of the underlying, unwrapped layout, in utf-8 bytes. */
    public inline function len():Int {
        return layout.len();
    }

    public inline function width():Pixels {
        return layout.width();
    }

    public inline function size(lineHeight:Pixels):Size {
        return layout.size(lineHeight);
    }

    /** `size(lineHeight).height` without the `Size` */
    public inline function sizeHeight(lineHeight:Pixels):Pixels {
        return layout.sizeHeight(lineHeight);
    }

    public inline function wrapBoundaries():Array<WrapBoundary> {
        return layout.wrapBoundaries;
    }

    public inline function unwrappedLayout():LineLayout {
        return layout.unwrappedLayout;
    }

    public inline function indexForPosition(position:Point, lineHeight:Pixels):IndexResult {
        return layout.indexForPosition(position, lineHeight);
    }

    public inline function closestIndexForPosition(position:Point, lineHeight:Pixels):IndexResult {
        return layout.closestIndexForPosition(position, lineHeight);
    }

    public inline function positionForIndex(index:Int, lineHeight:Pixels):Null<Point> {
        return layout.positionForIndex(index, lineHeight);
    }

    /**
     * Paint this line of text. When `bounds` is null, the wrap width is
     * used to align the text.
     */
    /**
     * The width the line is aligned in: the bounds' width, the wrap width,
     * else the line's own width (as a value: `Null<Float>` boxes on hxcpp)
     */
    inline function alignWidthOf(bounds:Null<Bounds>):Float {
        if (bounds != null)
            return bounds.size.width;
        final wrapWidth = layout.wrapWidth;
        return wrapWidth != null ? (wrapWidth : Float) : layout.unwrappedLayout.width;
    }

    public function paint(origin:Point, lineHeight:Pixels, align:TextAlign, bounds:Null<Bounds>, painter:TextPainter):Void {
        LinePaint.paintLineAligned(origin, layout.unwrappedLayout, lineHeight, align, alignWidthOf(bounds), decorationRuns, layout.wrapBoundaries, painter, null);
    }

    /**
     * Paint the background of line of text.
     */
    public function paintBackground(origin:Point, lineHeight:Pixels, align:TextAlign, bounds:Null<Bounds>, painter:TextPainter):Void {
        LinePaint.paintLineBackgroundAligned(origin, layout.unwrappedLayout, lineHeight, align, alignWidthOf(bounds), decorationRuns, layout.wrapBoundaries, painter);
    }

}
