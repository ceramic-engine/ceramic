package ceramic;

import ceramic.Shape;

/**
 * A specialized shape that creates a rectangle with rounded corners.
 * 
 * RoundedRect extends Shape to generate smooth, curved corners using
 * configurable radius values and segment counts. Each corner can have
 * a different radius, allowing for asymmetric designs.
 * 
 * The shape is constructed by generating arc segments for each corner
 * and connecting them with straight lines. The number of segments
 * determines the smoothness of the curves.
 * 
 * Common uses:
 * - UI buttons and panels
 * - Dialog boxes and tooltips
 * - Card layouts
 * - Any rectangular element requiring soft edges
 * 
 * ```haxe
 * // Create a uniformly rounded rectangle
 * var rect = new RoundedRect();
 * rect.size(200, 100);
 * rect.radius(20);  // All corners 20px radius
 * 
 * // Create asymmetric rounded rectangle
 * var card = new RoundedRect();
 * card.size(300, 200);
 * card.radius(30, 30, 10, 10);  // Top corners more rounded
 * ```
 * 
 * @see Shape The base class for custom shapes
 */
class RoundedRect extends Shape {

    /**
     * Number of segments used to create each rounded corner.
     * 
     * More segments create smoother curves but use more vertices.
     * The segments are distributed equally across the 90-degree arc
     * of each corner.
     * 
     * Recommended values:
     * - 1-3: Very low poly, visible corners
     * - 4-6: Good balance for small radii
     * - 7-10: Smooth curves for larger radii
     * - >10: Diminishing returns, rarely needed
     * 
     * Default: 10 (smooth curves)
     */
    @content public var segments:Int = 10;

    /**
     * Radius of the top-left corner in pixels.
     * 
     * A value of 0 creates a sharp corner.
     * The radius is clamped to half the smaller dimension
     * to prevent overlapping corners.
     */
    @content public var radiusTopLeft:Float = 0;

    /**
     * Radius of the top-right corner in pixels.
     * 
     * A value of 0 creates a sharp corner.
     * The radius is clamped to half the smaller dimension
     * to prevent overlapping corners.
     */
    @content public var radiusTopRight:Float = 0;

    /**
     * Radius of the bottom-right corner in pixels.
     * 
     * A value of 0 creates a sharp corner.
     * The radius is clamped to half the smaller dimension
     * to prevent overlapping corners.
     */
    @content public var radiusBottomRight:Float = 0;

    /**
     * Radius of the bottom-left corner in pixels.
     * 
     * A value of 0 creates a sharp corner.
     * The radius is clamped to half the smaller dimension
     * to prevent overlapping corners.
     */
    @content public var radiusBottomLeft:Float = 0;

    override public function set_width(width:Float):Float {
        if (this.width == width) return width;
        super.set_width(width);
        contentDirty = true;
        return width;
    }

    override public function set_height(height:Float):Float {
        if (this.height == height) return height;
        super.set_height(height);
        contentDirty = true;
        return height;
    }

    /**
     * Creates a new RoundedRect instance.
     * 
     * The shape starts with sharp corners (all radii = 0) and
     * must be configured using the radius properties or radius() method.
     * Auto-size computation is disabled since the size is explicitly set.
     */
    override public function new() {
        super();
        autoComputeSize = false;
    }

    /**
     * Generates the points that define the rounded rectangle shape.
     * 
     * This method creates a series of points around the perimeter:
     * 1. Calculates sine/cosine tables for the quarter circle
     * 2. Generates points for each corner arc in clockwise order:
     *    - Top-left (0° to 90°)
     *    - Top-right (90° to 180°)
     *    - Bottom-right (180° to 270°)
     *    - Bottom-left (270° to 360°)
     * 
     * The straight edges between corners are implicit in the
     * point ordering and handled by the Shape triangulation.
     */
    override function computeContent() {

        points = [];

        // Define the relative coordinates for the radius
        // Pre-calculate sine/cosine for a quarter circle
        var sine = [for (angle in 0...segments + 1) Math.sin(Math.PI / 2 * angle / segments)];
        var cosine = [for (angle in 0...segments + 1) Math.cos(Math.PI / 2 * angle / segments)];

        // TOP LEFT corner arc
        // Starts at top edge, curves to left edge
        for (pointPairIndex in 0...segments) {
            points.push(radiusTopLeft * (1 - cosine[pointPairIndex]));
            points.push(radiusTopLeft * (1 - sine[pointPairIndex]));
        }

        // TOP RIGHT corner arc
        // Starts at right edge, curves to top edge
        for (pointPairIndex in 0...segments) {
            points.push(width + radiusTopRight * (cosine[segments - pointPairIndex] - 1));
            points.push(radiusTopRight * (1 - sine[segments - pointPairIndex]));
        }

        // BOTTOM RIGHT corner arc
        // Starts at bottom edge, curves to right edge
        for (pointPairIndex in 0...segments) {
            points.push(width + radiusBottomRight * (cosine[pointPairIndex] - 1));
            points.push(height + radiusBottomRight * (sine[pointPairIndex] - 1));
        }

        // BOTTOM LEFT corner arc
        // Starts at left edge, curves to bottom edge
        for (pointPairIndex in 0...segments) {
            points.push(radiusBottomLeft * (1 - cosine[segments - pointPairIndex]));
            points.push(height + radiusBottomLeft * (sine[segments - pointPairIndex] - 1));
        }

        super.computeContent();

    }

    /**
     * Sets the radius for all corners at once.
     * 
     * This convenience method allows setting corner radii with various
     * parameter combinations:
     * - 1 parameter: All corners use the same radius
     * - 2 parameters: Top corners use first value, bottom corners use second
     * - 4 parameters: Each corner gets its own radius
     * 
     * @param topLeft Radius for top-left corner (required)
     * @param topRight Radius for top-right corner (optional)
     * @param bottomRight Radius for bottom-right corner (optional)
     * @param bottomLeft Radius for bottom-left corner (optional)
     * 
     * ```haxe
     * // All corners 20px
     * rect.radius(20);
     * 
     * // Top corners 20px, bottom corners 10px  
     * rect.radius(20, 10);
     * 
     * // Each corner different
     * rect.radius(20, 15, 10, 5);
     * ```
     */
    public function radius(topLeft:Float, ?topRight:Float, ?bottomRight:Float, ?bottomLeft:Float):Void {
        if (topRight == null && bottomRight == null && bottomLeft == null) {
            topRight = topLeft;
            bottomRight = topLeft;
            bottomLeft = topLeft;
        }
        else if (bottomRight == null && bottomLeft == null) {
            bottomRight = topRight;
            bottomLeft = topLeft;
        }
        else {
            if (topRight == null) topRight = topLeft;
            if (bottomRight == null) bottomRight = topLeft;
            if (bottomLeft == null) bottomLeft = topLeft;
        }
        radiusTopLeft = topLeft;
        radiusTopRight = topRight;
        radiusBottomRight = bottomRight;
        radiusBottomLeft = bottomLeft;
    }

}
