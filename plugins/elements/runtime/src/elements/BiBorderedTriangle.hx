package elements;

import ceramic.AlphaColor;
import ceramic.Color;
import ceramic.Mesh;

using ceramic.Extensions;

/**
 * A triangular shape with customizable border rendering.
 * 
 * This specialized mesh creates an upward-pointing triangle with a border that can have
 * different colors and alpha values than the inner triangle. The triangle is rendered
 * as a composite of two triangles - an inner filled triangle and an outer border triangle.
 * 
 * The vertex layout creates a larger outer triangle for the border and a smaller inner
 * triangle for the fill, allowing for independent color control of each region.
 * 
 * Example usage:
 * ```haxe
 * var triangle = new BiBorderedTriangle();
 * triangle.size(100, 100);
 * triangle.innerColor = Color.BLUE;
 * triangle.borderColor = Color.WHITE;
 * triangle.borderSize = 2;
 * ```
 */
class BiBorderedTriangle extends Mesh {

/// Overrides

    override function set_width(width:Float):Float {
        super.set_width(width);
        contentDirty = true;
        return width;

    }

    override function set_height(height:Float):Float {
        super.set_height(height);
        contentDirty = true;
        return height;

    }

/// Properties

    /**
     * The color of the inner triangle fill.
     * Defaults to Color.WHITE.
     */
    public var innerColor(default,set):Color = Color.WHITE;
    inline function set_innerColor(innerColor:Color):Color {
        if (this.innerColor != innerColor) {
            for (i in 0...3) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(innerColor, existing.alpha));
            }
        }
        return innerColor;
    }

    /**
     * The alpha transparency of the inner triangle fill.
     * Values range from 0.0 (fully transparent) to 1.0 (fully opaque).
     * Defaults to 1.0.
     */
    public var innerAlpha(default,set):Float = 1;
    inline function set_innerAlpha(innerAlpha:Float):Float {
        if (this.innerAlpha != innerAlpha) {
            var alphaInt = Math.round(innerAlpha * 255);
            for (i in 0...3) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(existing.rgb,alphaInt));
            }
        }
        return innerAlpha;
    }

    /**
     * The width of the border in pixels.
     * The border extends outward from the triangle edges.
     * Defaults to 1.0.
     */
    public var borderSize(default,set):Float = 1;
    inline function set_borderSize(borderSize:Float):Float {
        if (this.borderSize != borderSize) {
            this.borderSize = borderSize;
            contentDirty = true;
        }
        return borderSize;
    }

    /**
     * The color of the triangle border.
     * Defaults to Color.BLACK.
     */
    public var borderColor(default,set):Color = Color.BLACK;
    inline function set_borderColor(borderColor:Color):Color {
        if (this.borderColor != borderColor) {
            this.borderColor = borderColor;
            for (i in 3...15) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(borderColor, existing.alpha));
            }
        }
        return borderColor;
    }

    /**
     * The alpha transparency of the triangle border.
     * Values range from 0.0 (fully transparent) to 1.0 (fully opaque).
     * Defaults to 1.0.
     */
    public var borderAlpha(default,set):Float = 1.0;
    inline function set_borderAlpha(borderAlpha:Float):Float {
        if (this.borderAlpha != borderAlpha) {
            this.borderAlpha = borderAlpha;
            var alphaInt = Math.round(borderAlpha * 255);
            for (i in 3...15) {
                var existing = colors.unsafeGet(i);
                colors.unsafeSet(i, new AlphaColor(existing.rgb, alphaInt));
            }
        }
        return borderAlpha;
    }

/// Lifecycle

    /**
     * Creates a new BiBorderedTriangle instance.
     * 
     * The triangle is initialized with:
     * - 6 vertices (3 for inner triangle, 3 for outer border triangle)
     * - 5 triangle indices to form the border and fill regions
     * - White inner color and gray border color
     * - Color mapping set to INDICES for per-triangle coloring
     */
    public function new() {

        super();

        vertices = [
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0
        ];
        indices = [
            0, 1, 2,
            0, 3, 4,
            0, 4, 1,
            1, 4, 2,
            4, 5, 2
        ];

        colorMapping = INDICES;
        colors = [];
        for (i in 0...15)
            colors.push(new AlphaColor(Color.WHITE));

        innerColor = Color.WHITE;
        borderColor = Color.GRAY;

    }

    /**
     * Recomputes the triangle mesh when properties change.
     * Called automatically when width, height, or borderSize are modified.
     */
    override function computeContent() {

        super.computeContent();

        updateVertices();

    }

    /**
     * Updates the vertex positions based on the current width, height, and borderSize.
     * 
     * The vertex layout is:
     * - Vertices 0-2: Inner triangle (bottom-left, top-center, bottom-right)
     * - Vertices 3-5: Outer border triangle (extended by borderSize)
     * 
     * The triangle points upward with its apex at the top center.
     */
    inline function updateVertices() {

        // Triangle
        //
        vertices.unsafeSet(0, 0.0);
        vertices.unsafeSet(1, height);

        vertices.unsafeSet(2, width * 0.5);
        vertices.unsafeSet(3, 0.0);

        vertices.unsafeSet(4, width);
        vertices.unsafeSet(5, height);

        // Border
        //
        vertices.unsafeSet(6, -borderSize);
        vertices.unsafeSet(7, height);

        vertices.unsafeSet(8, width * 0.5);
        vertices.unsafeSet(9, -borderSize);

        vertices.unsafeSet(10, width + borderSize);
        vertices.unsafeSet(11, height);

    }

}
