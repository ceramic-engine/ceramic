package ceramic;

using ceramic.Extensions;

/**
 * A mesh subclass for drawing arcs, pies, rings, and disc geometry.
 *
 * Arc provides a convenient way to create circular and arc-shaped graphics
 * with configurable radius, angle, thickness, and smoothness. It can render
 * various circular shapes by adjusting its properties:
 *
 * Shape configurations:
 * - Arc: Partial circle outline (angle < 360°)
 * - Ring: Complete circle outline (angle = 360°)
 * - Disc/Circle: Filled circle (angle = 360°, borderPosition = INSIDE)
 * - Pie: Filled arc segment (thickness = radius, borderPosition = INSIDE)
 * - Ring segment: Thick arc outline
 *
 * The arc is centered at its anchor point (default 0.5, 0.5) and
 * renders from 0° (right) counter-clockwise.
 *
 * ```haxe
 * // Create a simple arc
 * var arc = new Arc();
 * arc.radius = 100;
 * arc.angle = 90; // Quarter circle
 * arc.thickness = 20;
 * arc.color = Color.BLUE;
 *
 * // Create a pie chart segment
 * var pie = new Arc();
 * pie.radius = 80;
 * pie.thickness = 80; // Same as radius
 * pie.borderPosition = INSIDE;
 * pie.angle = 120; // One third of circle
 * pie.color = Color.GREEN;
 *
 * // Create a smooth ring
 * var ring = new Arc();
 * ring.radius = 50;
 * ring.thickness = 10;
 * ring.angle = 360; // Full circle
 * ring.sides = 64; // Smoother circle
 * ring.color = Color.YELLOW;
 * ```
 *
 * @see Mesh
 * @see BorderPosition
 */
class Arc extends Mesh {

    /**
     * Number of sides used to approximate the arc.
     *
     * Higher values create smoother curves but use more vertices.
     * - 3: Triangle
     * - 6: Hexagon
     * - 32: Smooth arc (default)
     * - 64+: Very smooth, suitable for large arcs
     *
     * Performance consideration: vertex count = sides * 2 for rings
     */
    public var sides(default,set):Int = 32;
    inline function set_sides(sides:Int):Int {
        if (this.sides == sides) return sides;
        this.sides = sides;
        contentDirty = true;
        return sides;
    }

    /**
     * Radius of the arc in pixels.
     *
     * Defines the outer edge distance from the center.
     * The arc's total size will be radius * 2.
     *
     * Default: 64
     */
    public var radius(default,set):Float = 64;
    function set_radius(radius:Float):Float {
        if (this.radius == radius) return radius;
        this.radius = radius;
        contentDirty = true;
        return radius;
    }

    /**
     * Arc angle in degrees (0 to 360).
     *
     * Determines how much of the circle to draw:
     * - 0°: No arc
     * - 90°: Quarter circle
     * - 180°: Semicircle
     * - 270°: Three quarters (default)
     * - 360°: Full circle/ring
     *
     * The arc starts at 0° (right) and draws counter-clockwise.
     */
    public var angle(default,set):Float = 270;
    function set_angle(angle:Float):Float {
        if (this.angle == angle) return angle;
        this.angle = angle;
        contentDirty = true;
        return angle;
    }

    /**
     * Position of the arc border relative to the radius.
     *
     * - INSIDE: Border inside radius (fills toward center)
     * - MIDDLE: Border centered on radius line (default)
     * - OUTSIDE: Border outside radius (extends outward)
     *
     * Use INSIDE with thickness = radius to create filled shapes.
     */
    public var borderPosition(default,set):BorderPosition = MIDDLE;
    inline function set_borderPosition(borderPosition:BorderPosition):BorderPosition {
        if (this.borderPosition == borderPosition) return borderPosition;
        this.borderPosition = borderPosition;
        contentDirty = true;
        return borderPosition;
    }

    /**
     * Thickness of the arc stroke in pixels.
     *
     * Determines the width of the arc line:
     * - Small values: Thin outlines
     * - Large values: Thick rings
     * - Equal to radius with INSIDE border: Filled pie/disc
     *
     * Default: 16
     */
    public var thickness(default,set):Float = 16;
    function set_thickness(thickness:Float):Float {
        if (this.thickness == thickness) return thickness;
        this.thickness = thickness;
        contentDirty = true;
        return thickness;
    }

    public function new() {

        super();

        anchor(0.5, 0.5);

    }

    /**
     * Generates the arc mesh geometry.
     *
     * Creates vertices and indices to represent the arc shape
     * based on current properties. Called automatically when
     * properties change.
     */
    override function computeContent() {

        inline MeshExtensions.createArc(this, radius, angle, thickness, sides, borderPosition);

        this.width = radius * 2;
        this.height = radius * 2;

        contentDirty = false;

    }

}
