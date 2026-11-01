// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A struct for storing font metrics.
 * It is used to define the measurements of a typeface.
 *
 * Rust has fields and methods with the same names (`ascent` and
 * `ascent(font_size)`): the methods get an `At` suffix here (`ascentAt()`).
 */
class FontMetrics {

    /**
     * The number of font units that make up the "em square",
     * a scalable grid for determining the size of a typeface.
     */
    public var unitsPerEm:Int;

    /** The vertical distance from the baseline of the font to the top of the glyph covers. */
    public var ascent:Float;

    /** The vertical distance from the baseline of the font to the bottom of the glyph covers. */
    public var descent:Float;

    /** The recommended additional space to add between lines of type. */
    public var lineGap:Float;

    /** The suggested position of the underline. */
    public var underlinePosition:Float;

    /** The suggested thickness of the underline. */
    public var underlineThickness:Float;

    /** The height of a capital letter measured from the baseline of the font. */
    public var capHeight:Float;

    /** The height of a lowercase x. */
    public var xHeight:Float;

    /**
     * The outer limits of the area that the font covers.
     * Corresponds to the xMin / xMax / yMin / yMax values in the OpenType `head` table
     */
    public var boundingBox:Bounds;

    public function new(unitsPerEm:Int, ascent:Float, descent:Float, lineGap:Float, underlinePosition:Float, underlineThickness:Float, capHeight:Float, xHeight:Float, boundingBox:Bounds) {
        this.unitsPerEm = unitsPerEm;
        this.ascent = ascent;
        this.descent = descent;
        this.lineGap = lineGap;
        this.underlinePosition = underlinePosition;
        this.underlineThickness = underlineThickness;
        this.capHeight = capHeight;
        this.xHeight = xHeight;
        this.boundingBox = boundingBox;
    }

    /** Returns the vertical distance from the baseline of the font to the top of the glyph covers in pixels. */
    public inline function ascentAt(fontSize:Pixels):Pixels {
        return f32(f32(ascent / unitsPerEm) * (fontSize:Float));
    }

    /** Returns the vertical distance from the baseline of the font to the bottom of the glyph covers in pixels. */
    public inline function descentAt(fontSize:Pixels):Pixels {
        return f32(f32(descent / unitsPerEm) * (fontSize:Float));
    }

    /** Returns the recommended additional space to add between lines of type in pixels. */
    public inline function lineGapAt(fontSize:Pixels):Pixels {
        return f32(f32(lineGap / unitsPerEm) * (fontSize:Float));
    }

    /** Returns the suggested position of the underline in pixels. */
    public inline function underlinePositionAt(fontSize:Pixels):Pixels {
        return f32(f32(underlinePosition / unitsPerEm) * (fontSize:Float));
    }

    /** Returns the suggested thickness of the underline in pixels. */
    public inline function underlineThicknessAt(fontSize:Pixels):Pixels {
        return f32(f32(underlineThickness / unitsPerEm) * (fontSize:Float));
    }

    /** Returns the height of a capital letter measured from the baseline of the font in pixels. */
    public inline function capHeightAt(fontSize:Pixels):Pixels {
        return f32(f32(capHeight / unitsPerEm) * (fontSize:Float));
    }

    /** Returns the height of a lowercase x in pixels. */
    public inline function xHeightAt(fontSize:Pixels):Pixels {
        return f32(f32(xHeight / unitsPerEm) * (fontSize:Float));
    }

    /** Returns the outer limits of the area that the font covers in pixels. */
    public function boundingBoxAt(fontSize:Pixels):Bounds {
        return scaleBounds(boundingBox, unitsPerEm, fontSize);
    }

    /**
     * `bounds / units_per_em as f32 * font_size` in f32, like GPUI: each
     * component divided then multiplied, each operation rounded to f32.
     */
    public static function scaleBounds(bounds:Bounds, unitsPerEm:Int, fontSize:Pixels):Bounds {
        final size:Float = f32(fontSize);
        inline function scale(v:Float):Float
            return f32(f32(v / unitsPerEm) * size);
        return new Bounds(new Point(scale(bounds.origin.x), scale(bounds.origin.y)), new Size(scale(bounds.size.width), scale(bounds.size.height)));
    }

    /** GPUI computes these metrics in f32 */
    static inline function f32(value:Float):Float {
        return SpringMath.f32(value);
    }

    public function toString():String {
        return 'FontMetrics(unitsPerEm=$unitsPerEm ascent=$ascent descent=$descent lineGap=$lineGap underlinePosition=$underlinePosition underlineThickness=$underlineThickness capHeight=$capHeight xHeight=$xHeight boundingBox=$boundingBox)';
    }

}
