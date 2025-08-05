package ceramic;

using ceramic.Extensions;

/**
 * A mesh that creates regular polygons with a configurable number of sides.
 *
 * Ngon (N-gon) can create any regular polygon from triangles to circles.
 * The shape is centered at its anchor point (default 0.5, 0.5) with
 * vertices evenly distributed around the perimeter.
 *
 * Common shapes by side count:
 * - 3: Triangle
 * - 4: Square (rotated 45°)
 * - 5: Pentagon
 * - 6: Hexagon
 * - 8: Octagon
 * - 32+: Circle approximation
 *
 * The first vertex is positioned at (radius, 0) relative to center,
 * with subsequent vertices placed counter-clockwise.
 *
 * ```haxe
 * // Create a hexagon
 * var hexagon = new Ngon();
 * hexagon.sides = 6;
 * hexagon.radius = 40;
 * hexagon.color = Color.YELLOW;
 *
 * // Create a smooth circle
 * var circle = new Ngon();
 * circle.sides = 64;
 * circle.radius = 50;
 * circle.color = Color.WHITE;
 *
 * // Animated shape morphing
 * var morph = new Ngon();
 * morph.radius = 30;
 * morph.color = Color.PINK;
 * app.onUpdate(this, delta -> {
 *     morph.sides = Math.round(3 + Math.sin(Timer.now) * 3);
 * });
 * ```
 *
 * @see Mesh
 * @see Arc
 */
class Ngon extends Mesh {

    /**
     * Number of sides for the polygon.
     *
     * Minimum 3 for a triangle. Higher values create
     * smoother shapes that approximate a circle.
     *
     * Default: 32 (smooth circle approximation)
     */
    public var sides(default,set):Int = 32;
    inline function set_sides(sides:Int):Int {
        if (this.sides == sides) return sides;
        this.sides = sides;
        contentDirty = true;
        return sides;
    }

    /**
     * Radius of the polygon in pixels.
     *
     * Distance from center to vertices. The total size
     * will be radius * 2 in both width and height.
     *
     * Default: 50
     */
    public var radius(default,set):Float = 50;
    function set_radius(radius:Float):Float {
        if (this.radius == radius) return radius;
        this.radius = radius;
        contentDirty = true;
        return radius;
    }

    /**
     * Creates a new N-gon polygon.
     *
     * The shape is anchored at its center (0.5, 0.5) by default,
     * making rotation and scaling behave naturally.
     */
    public function new() {

        super();

        anchor(0.5, 0.5);

    }

    /**
     * Generates the polygon mesh geometry.
     *
     * Creates a fan of triangles from the center point to
     * vertices distributed evenly around the perimeter.
     * The first perimeter vertex is at angle 0 (right side).
     */
    override function computeContent() {

        var count:Int = sides;

        width = radius * 2;
        height = radius * 2;

        vertices.setArrayLength(0);
        indices.setArrayLength(0);

        vertices.push(radius);
        vertices.push(radius);

        var sidesOverTwoPi:Float = Math.PI * 2 / count;

        for (i in 0...count) {

            var _x = radius * Math.cos(sidesOverTwoPi * i);
            var _y = radius * Math.sin(sidesOverTwoPi * i);

            vertices.push(radius + _x);
            vertices.push(radius + _y);

            indices.push(0);
            indices.push(i + 1);
            if (i < count - 1) indices.push(i + 2);
            else indices.push(1);

        }

        contentDirty = false;

    }

}
