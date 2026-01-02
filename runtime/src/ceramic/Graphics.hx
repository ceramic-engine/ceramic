package ceramic;

import ceramic.Color;
import ceramic.Visual;

using ceramic.Extensions;

/**
 * Immediate-mode graphics API for Ceramic, similar to Canvas 2D or Flash Graphics.
 *
 * Graphics provides a familiar drawing API while efficiently managing memory through
 * Ceramic's pooling system. It internally uses Mesh, Quad, Line, and Arc objects
 * which are recycled between frames to minimize garbage collection.
 *
 * Features:
 * - Basic shape drawing (rectangles, circles, polygons)
 * - Line and path drawing with configurable styles
 * - Bezier and quadratic curves
 * - Fill and stroke operations
 * - Efficient object pooling for all visuals
 *
 * Example usage:
 * ```haxe
 * var graphics = new Graphics();
 *
 * // Draw a filled rectangle
 * graphics.beginFill(Color.RED);
 * graphics.drawRect(10, 10, 100, 50);
 * graphics.endFill();
 *
 * // Draw a stroked circle
 * graphics.lineStyle(2, Color.BLUE);
 * graphics.drawCircle(100, 100, 30);
 *
 * // Draw a path
 * graphics.moveTo(10, 10);
 * graphics.lineTo(50, 30);
 * graphics.quadraticCurveTo(100, 20, 150, 50);
 *
 * // Clear and reuse next frame
 * graphics.clear();
 * ```
 */
class Graphics extends Visual {

    /**
     * Active meshes currently being displayed
     */
    var activeMeshes:Array<Mesh> = [];

    /**
     * Active quads currently being displayed
     */
    var activeQuads:Array<Quad> = [];

    /**
     * Active lines currently being displayed
     */
    var activeLines:Array<Line> = [];

    /**
     * Active arcs currently being displayed
     */
    var activeArcs:Array<Arc> = [];

    /**
     * Pooled meshes ready for reuse
     */
    var pooledMeshes:Array<Mesh> = [];

    /**
     * Pooled quads ready for reuse
     */
    var pooledQuads:Array<Quad> = [];

    /**
     * Pooled lines ready for reuse
     */
    var pooledLines:Array<Line> = [];

    /**
     * Pooled arcs ready for reuse
     */
    var pooledArcs:Array<Arc> = [];

    /**
     * Current fill color
     */
    var fillColor:Color = Color.WHITE;

    /**
     * Current fill alpha
     */
    var fillAlpha:Float = 1.0;

    /**
     * Whether we're currently filling
     */
    var filling:Bool = false;

    /**
     * Current line thickness
     */
    var lineThickness:Float = 1.0;

    /**
     * Current line color
     */
    var lineColor:Color = Color.WHITE;

    /**
     * Current line alpha
     */
    var lineAlpha:Float = 1.0;

    /**
     * Current line join style
     */
    var lineJoin:LineJoin = MITER;

    /**
     * Current line cap style
     */
    var lineCap:LineCap = BUTT;

    /**
     * Whether we have an active line style for stroking
     */
    var stroking:Bool = false;

    /**
     * Current path being built
     */
    var currentPath:Array<Float> = null;

    /**
     * Current X position for path operations
     */
    var currentX:Float = 0;

    /**
     * Current Y position for path operations
     */
    var currentY:Float = 0;

    /**
     * Path segments for complex shapes
     */
    var pathSegments:Array<Array<Float>> = [];

    /**
     * Tracks which path segments have been closed via closePath()
     */
    var pathSegmentsClosed:Array<Bool> = [];

    /**
     * Current depth value for ordering visuals.
     * Incremented for each visual added to ensure proper render order.
     * Strokes are given higher depth than fills to render on top.
     */
    var currentDepth:Float = 0;

    public function new() {
        super();
    }

    /**
     * Get a mesh from the pool or create a new one
     */
    function getMesh():Mesh {
        var mesh:Mesh;
        if (pooledMeshes.length > 0) {
            mesh = pooledMeshes.pop();
            mesh.active = true;
        } else {
            mesh = MeshPool.get();
        }
        mesh.depth = currentDepth++;
        activeMeshes.push(mesh);
        add(mesh);
        return mesh;
    }

    /**
     * Get a quad from the pool or create a new one
     */
    function getQuad():Quad {
        var quad:Quad;
        if (pooledQuads.length > 0) {
            quad = pooledQuads.pop();
            quad.active = true;
        } else {
            quad = new Quad();
        }
        quad.depth = currentDepth++;
        activeQuads.push(quad);
        add(quad);
        return quad;
    }

    /**
     * Get a line from the pool or create a new one
     */
    function getLine():Line {
        var line:Line;
        if (pooledLines.length > 0) {
            line = pooledLines.pop();
            line.active = true;
            line.contentDirty = true;
            line.loop = false;
            // Ensure points array exists
            if (line.points == null) {
                line.points = [];
            }
        } else {
            line = new Line();
            line.points = [];
        }
        line.join = lineJoin;
        line.cap = lineCap;
        line.depth = currentDepth++;
        activeLines.push(line);
        add(line);
        return line;
    }

    /**
     * Get an arc from the pool or create a new one
     */
    function getArc():Arc {
        var arc:Arc;
        if (pooledArcs.length > 0) {
            arc = pooledArcs.pop();
            arc.active = true;
        } else {
            arc = new Arc();
        }
        arc.depth = currentDepth++;
        activeArcs.push(arc);
        add(arc);
        return arc;
    }

    /**
     * Clear all graphics and recycle visuals to pools
     */
    override function clear():Void {
        // Recycle meshes
        for (mesh in activeMeshes) {
            mesh.active = false;
            mesh.depth = 0;
            remove(mesh);
            // Clear mesh data
            if (mesh.vertices != null) mesh.vertices.resize(0);
            if (mesh.indices != null) mesh.indices.resize(0);
            if (mesh.colors != null) mesh.colors.resize(0);
            if (mesh.uvs != null) mesh.uvs.resize(0);
            pooledMeshes.push(mesh);
        }
        activeMeshes.resize(0);

        // Recycle quads
        for (quad in activeQuads) {
            quad.active = false;
            quad.depth = 0;
            remove(quad);
            pooledQuads.push(quad);
        }
        activeQuads.resize(0);

        // Recycle lines
        for (line in activeLines) {
            line.active = false;
            line.depth = 0;
            remove(line);
            if (line.points != null) line.points.resize(0);
            pooledLines.push(line);
        }
        activeLines.resize(0);

        // Recycle arcs
        for (arc in activeArcs) {
            arc.active = false;
            arc.depth = 0;
            remove(arc);
            pooledArcs.push(arc);
        }
        activeArcs.resize(0);

        // Clear path data
        currentPath = null;
        pathSegments.resize(0);
        pathSegmentsClosed.resize(0);
        currentX = 0;
        currentY = 0;

        // Reset depth counter
        currentDepth = 0;

        // Reset all style settings to defaults (matches Flash/Pixi behavior)
        stroking = false;
        filling = false;
        lineThickness = 1.0;
        lineColor = Color.WHITE;
        lineAlpha = 1.0;
        fillColor = Color.WHITE;
        fillAlpha = 1.0;
        // Note: We don't call super.clear() because Visual.clear() destroys children,
        // but we've already removed and pooled them above.
    }

    /**
     * Set the line style for subsequent drawing operations.
     * Call with no arguments or thickness <= 0 to disable stroking.
     *
     * @param thickness Line width in pixels. <= 0 disables stroking.
     * @param color Line color. Defaults to WHITE.
     * @param alpha Line opacity (0-1). Defaults to 1.0.
     * @param join Corner join style (MITER, BEVEL, ROUND). Defaults to MITER.
     * @param cap End cap style (BUTT, SQUARE, ROUND). Defaults to BUTT.
     */
    public function lineStyle(thickness:Float = 0, color:Color = null, alpha:Float = 1.0, join:LineJoin = null, cap:LineCap = null):Void {
        if (thickness <= 0) {
            stroking = false;
            return;
        }
        lineThickness = thickness;
        lineColor = color != null ? color : Color.WHITE;
        lineAlpha = alpha;
        lineJoin = join != null ? join : MITER;
        lineCap = cap != null ? cap : BUTT;
        stroking = true;
    }

    /**
     * Begin a fill for subsequent shape operations
     */
    public function beginFill(color:Color = null, alpha:Float = 1.0):Void {
        fillColor = color != null ? color : Color.WHITE;
        fillAlpha = alpha;
        filling = true;
        currentPath = [];
    }

    /**
     * End the current fill operation
     */
    public function endFill():Void {
        if (filling && currentPath != null && currentPath.length >= 6) {
            // Create a filled mesh from the path
            var mesh = getMesh();

            // Convert path to triangulated mesh
            var vertices = mesh.vertices;
            var indices = mesh.indices;

            // Copy path points as vertices
            for (i in 0...currentPath.length) {
                vertices.push(currentPath[i]);
            }

            // Triangulate polygon (handles both convex and concave shapes)
            Triangulate.triangulate(vertices, indices);

            mesh.color = fillColor;
            mesh.alpha = fillAlpha;
            mesh.computeSize();

            // If stroking is active, also draw the stroke outline
            if (stroking && currentPath.length >= 4) {
                var line = getLine();
                for (i in 0...currentPath.length) {
                    line.points.push(currentPath[i]);
                }
                // Close the path
                line.points.push(currentPath[0]);
                line.points.push(currentPath[1]);
                line.loop = true;
                line.thickness = lineThickness;
                line.color = lineColor;
                line.alpha = lineAlpha;
            }
        }

        filling = false;
        currentPath = null;
    }

    /**
     * Draw a rectangle
     */
    public function drawRect(x:Float, y:Float, width:Float, height:Float):Void {
        if (filling) {
            // Add rectangle points to current path for fill
            if (currentPath.length == 0) {
                currentPath.push(x);
                currentPath.push(y);
                currentPath.push(x + width);
                currentPath.push(y);
                currentPath.push(x + width);
                currentPath.push(y + height);
                currentPath.push(x);
                currentPath.push(y + height);
            }
            // Stroke will be handled by endFill() if stroking is active
        } else if (stroking) {
            // Draw stroked rectangle outline using mesh (8 vertices, 8 triangles)
            strokeRect(x, y, width, height);
        }
    }

    /**
     * Draw a filled rectangle using a mesh with 4 vertices.
     */
    function fillRect(x:Float, y:Float, width:Float, height:Float):Void {
        var mesh = getMesh();
        mesh.vertices.push(x); mesh.vertices.push(y);
        mesh.vertices.push(x + width); mesh.vertices.push(y);
        mesh.vertices.push(x + width); mesh.vertices.push(y + height);
        mesh.vertices.push(x); mesh.vertices.push(y + height);
        mesh.indices.push(0); mesh.indices.push(1); mesh.indices.push(2);
        mesh.indices.push(0); mesh.indices.push(2); mesh.indices.push(3);
        mesh.color = fillColor;
        mesh.alpha = fillAlpha;
        mesh.computeSize();
    }

    /**
     * Draw a stroked rectangle outline using a mesh with 8 vertices.
     * More efficient than using 4 Line objects.
     */
    function strokeRect(x:Float, y:Float, width:Float, height:Float):Void {
        var mesh = getMesh();
        var halfThick = lineThickness * 0.5;

        // Outer rectangle corners (0,1,2,3)
        var ox0 = x - halfThick;
        var oy0 = y - halfThick;
        var ox1 = x + width + halfThick;
        var oy1 = y - halfThick;
        var ox2 = x + width + halfThick;
        var oy2 = y + height + halfThick;
        var ox3 = x - halfThick;
        var oy3 = y + height + halfThick;

        // Inner rectangle corners (4,5,6,7)
        var ix0 = x + halfThick;
        var iy0 = y + halfThick;
        var ix1 = x + width - halfThick;
        var iy1 = y + halfThick;
        var ix2 = x + width - halfThick;
        var iy2 = y + height - halfThick;
        var ix3 = x + halfThick;
        var iy3 = y + height - halfThick;

        // Push vertices: outer corners 0-3, inner corners 4-7
        mesh.vertices.push(ox0); mesh.vertices.push(oy0); // 0
        mesh.vertices.push(ox1); mesh.vertices.push(oy1); // 1
        mesh.vertices.push(ox2); mesh.vertices.push(oy2); // 2
        mesh.vertices.push(ox3); mesh.vertices.push(oy3); // 3
        mesh.vertices.push(ix0); mesh.vertices.push(iy0); // 4
        mesh.vertices.push(ix1); mesh.vertices.push(iy1); // 5
        mesh.vertices.push(ix2); mesh.vertices.push(iy2); // 6
        mesh.vertices.push(ix3); mesh.vertices.push(iy3); // 7

        // 8 triangles forming the border
        // Top edge: 0,1,5 and 0,5,4
        mesh.indices.push(0); mesh.indices.push(1); mesh.indices.push(5);
        mesh.indices.push(0); mesh.indices.push(5); mesh.indices.push(4);
        // Right edge: 1,2,6 and 1,6,5
        mesh.indices.push(1); mesh.indices.push(2); mesh.indices.push(6);
        mesh.indices.push(1); mesh.indices.push(6); mesh.indices.push(5);
        // Bottom edge: 2,3,7 and 2,7,6
        mesh.indices.push(2); mesh.indices.push(3); mesh.indices.push(7);
        mesh.indices.push(2); mesh.indices.push(7); mesh.indices.push(6);
        // Left edge: 3,0,4 and 3,4,7
        mesh.indices.push(3); mesh.indices.push(0); mesh.indices.push(4);
        mesh.indices.push(3); mesh.indices.push(4); mesh.indices.push(7);

        mesh.color = lineColor;
        mesh.alpha = lineAlpha;
        mesh.computeSize();
    }

    /**
     * Draw a circle
     */
    public function drawCircle(x:Float, y:Float, radius:Float, sides:Int = -1):Void {

        if (sides == -1) {
            sides = Math.ceil(Math.max(64, radius));
        }

        if (filling) {
            var arc = getArc();
            arc.pos(x, y);
            arc.radius = radius;
            arc.angle = 360;
            arc.sides = sides;
            arc.thickness = radius;
            arc.borderPosition = INSIDE;
            arc.color = fillColor;
            arc.alpha = fillAlpha;
        }
        if (stroking) {
            var arc = getArc();
            arc.pos(x, y);
            arc.radius = radius;
            arc.angle = 360;
            arc.sides = sides;
            arc.thickness = lineThickness;
            arc.borderPosition = MIDDLE;
            arc.color = lineColor;
            arc.alpha = lineAlpha;
        }
    }

    /**
     * Draw an arc
     */
    public function drawArc(x:Float, y:Float, radius:Float, startAngle:Float, endAngle:Float, sides:Int = -1):Void {
        var angle = Math.abs(endAngle - startAngle);

        if (sides == -1) {
            sides = Math.ceil(Math.max(64, radius));
        }

        if (filling) {
            var arc = getArc();
            arc.pos(x, y);
            arc.radius = radius;
            arc.angle = angle;
            arc.rotation = startAngle;
            arc.sides = sides;
            arc.thickness = radius;
            arc.borderPosition = INSIDE;
            arc.color = fillColor;
            arc.alpha = fillAlpha;
        }
        if (stroking) {
            var arc = getArc();
            arc.pos(x, y);
            arc.radius = radius;
            arc.angle = angle;
            arc.rotation = startAngle;
            arc.sides = sides;
            arc.thickness = lineThickness;
            arc.borderPosition = MIDDLE;
            arc.color = lineColor;
            arc.alpha = lineAlpha;
        }
    }

    /**
     * Draw a triangle
     */
    public function drawTriangle(x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float):Void {
        if (filling) {
            // Create filled triangle
            var mesh = getMesh();
            mesh.vertices.push(x1); mesh.vertices.push(y1);
            mesh.vertices.push(x2); mesh.vertices.push(y2);
            mesh.vertices.push(x3); mesh.vertices.push(y3);
            mesh.indices.push(0); mesh.indices.push(1); mesh.indices.push(2);
            mesh.color = fillColor;
            mesh.alpha = fillAlpha;
            mesh.computeSize();
        }
        if (stroking) {
            // Create stroked triangle
            var line = getLine();
            line.points.push(x1); line.points.push(y1);
            line.points.push(x2); line.points.push(y2);
            line.points.push(x3); line.points.push(y3);
            line.points.push(x1); line.points.push(y1);
            line.loop = true;
            line.thickness = lineThickness;
            line.color = lineColor;
            line.alpha = lineAlpha;
        }
    }

    /**
     * Draw a polygon from an array of points
     */
    public function drawPolygon(points:Array<Float>):Void {
        if (points.length < 6) return; // Need at least 3 points

        if (filling) {
            // Create filled polygon
            var mesh = getMesh();

            // Copy points as vertices
            for (point in points) {
                mesh.vertices.push(point);
            }

            // Triangulate polygon (handles both convex and concave shapes)
            Triangulate.triangulate(mesh.vertices, mesh.indices);

            mesh.color = fillColor;
            mesh.alpha = fillAlpha;
            mesh.computeSize();
        }
        if (stroking) {
            // Create stroked polygon
            var line = getLine();
            // Copy points to the existing array
            for (point in points) {
                line.points.push(point);
            }
            // Close the polygon
            line.points.push(points[0]);
            line.points.push(points[1]);
            line.loop = true;
            line.thickness = lineThickness;
            line.color = lineColor;
            line.alpha = lineAlpha;
        }
    }

    /**
     * Move the drawing position to a new point
     */
    public function moveTo(x:Float, y:Float):Void {
        currentX = x;
        currentY = y;

        // Start a new path segment
        if (pathSegments.length > 0 && pathSegments[pathSegments.length - 1].length >= 2) {
            pathSegments.push([]);
            pathSegmentsClosed.push(false);
        }

        if (pathSegments.length == 0) {
            pathSegments.push([]);
            pathSegmentsClosed.push(false);
        }

        var segment = pathSegments[pathSegments.length - 1];
        segment.push(x);
        segment.push(y);

        if (filling && currentPath != null) {
            currentPath.push(x);
            currentPath.push(y);
        }
    }

    /**
     * Draw a line from the current position to a new point
     */
    public function lineTo(x:Float, y:Float):Void {
        if (pathSegments.length == 0) {
            moveTo(0, 0);
        }

        var segment = pathSegments[pathSegments.length - 1];
        segment.push(x);
        segment.push(y);

        currentX = x;
        currentY = y;

        if (filling && currentPath != null) {
            currentPath.push(x);
            currentPath.push(y);
        }
    }

    /**
     * Draw a line between two points
     */
    public function drawLine(x1:Float, y1:Float, x2:Float, y2:Float):Void {
        var line = getLine();
        line.points.push(x1); line.points.push(y1);
        line.points.push(x2); line.points.push(y2);
        line.thickness = lineThickness;
        line.color = lineColor;
        line.alpha = lineAlpha;
    }

    /**
     * Draw a quadratic Bezier curve
     */
    public function quadraticCurveTo(cpx:Float, cpy:Float, x:Float, y:Float):Void {
        // Calculate curve points
        var points:Array<Float> = [];
        var steps = 20; // Number of segments for the curve

        // Get the current path segment for adding curve points
        var segment:Array<Float> = null;
        if (pathSegments.length > 0) {
            segment = pathSegments[pathSegments.length - 1];
        }

        for (i in 0...steps + 1) {
            var t = i / steps;
            var mt = 1 - t;

            // Quadratic Bezier formula
            var px = mt * mt * currentX + 2 * mt * t * cpx + t * t * x;
            var py = mt * mt * currentY + 2 * mt * t * cpy + t * t * y;

            points.push(px);
            points.push(py);

            if (filling && currentPath != null) {
                currentPath.push(px);
                currentPath.push(py);
            }

            // Also add to pathSegments for drawPath() support
            if (segment != null) {
                segment.push(px);
                segment.push(py);
            }
        }

        if (stroking && !filling) {
            // Draw the curve as a line immediately when not filling
            var line = getLine();
            for (p in points) {
                line.points.push(p);
            }
            line.thickness = lineThickness;
            line.color = lineColor;
            line.alpha = lineAlpha;
        }

        currentX = x;
        currentY = y;
    }

    /**
     * Draw a cubic Bezier curve
     */
    public function bezierCurveTo(cp1x:Float, cp1y:Float, cp2x:Float, cp2y:Float, x:Float, y:Float):Void {
        // Calculate curve points
        var points:Array<Float> = [];
        var steps = 30; // Number of segments for the curve

        // Get the current path segment for adding curve points
        var segment:Array<Float> = null;
        if (pathSegments.length > 0) {
            segment = pathSegments[pathSegments.length - 1];
        }

        for (i in 0...steps + 1) {
            var t = i / steps;
            var mt = 1 - t;

            // Cubic Bezier formula
            var px = mt * mt * mt * currentX +
                     3 * mt * mt * t * cp1x +
                     3 * mt * t * t * cp2x +
                     t * t * t * x;
            var py = mt * mt * mt * currentY +
                     3 * mt * mt * t * cp1y +
                     3 * mt * t * t * cp2y +
                     t * t * t * y;

            points.push(px);
            points.push(py);

            if (filling && currentPath != null) {
                currentPath.push(px);
                currentPath.push(py);
            }

            // Also add to pathSegments for drawPath() support
            if (segment != null) {
                segment.push(px);
                segment.push(py);
            }
        }

        if (stroking && !filling) {
            // Draw the curve as a line immediately when not filling
            var line = getLine();
            for (p in points) {
                line.points.push(p);
            }
            line.thickness = lineThickness;
            line.color = lineColor;
            line.alpha = lineAlpha;
        }

        currentX = x;
        currentY = y;
    }

    /**
     * Draw all accumulated path segments
     */
    public function drawPath():Void {
        for (i in 0...pathSegments.length) {
            var segment = pathSegments[i];
            if (segment.length >= 4) {
                var line = getLine();
                // Copy segment points to the line's points array
                for (p in segment) {
                    line.points.push(p);
                }
                line.thickness = lineThickness;
                line.color = lineColor;
                line.alpha = lineAlpha;
                // Set loop if this segment was closed via closePath()
                if (pathSegmentsClosed[i]) {
                    line.loop = true;
                }

                // Update current position to end of this segment
                currentX = segment[segment.length - 2];
                currentY = segment[segment.length - 1];
            }
        }
        pathSegments.resize(0);
        pathSegmentsClosed.resize(0);
    }

    /**
     * Close the current path
     */
    public function closePath():Void {
        if (pathSegments.length > 0) {
            var segmentIndex = pathSegments.length - 1;
            var segment = pathSegments[segmentIndex];
            if (segment.length >= 4) {
                // Add line back to the start
                segment.push(segment[0]);
                segment.push(segment[1]);
                // Mark this segment as closed for loop rendering
                pathSegmentsClosed[segmentIndex] = true;
            }
        }

        if (filling && currentPath != null && currentPath.length >= 4) {
            currentPath.push(currentPath[0]);
            currentPath.push(currentPath[1]);
        }
    }

    override function destroy():Void {
        clear();

        // Clean up pooled objects
        for (mesh in pooledMeshes) {
            MeshPool.recycle(mesh);
        }
        pooledMeshes = null;

        for (quad in pooledQuads) {
            quad.destroy();
        }
        pooledQuads = null;

        for (line in pooledLines) {
            line.destroy();
        }
        pooledLines = null;

        for (arc in pooledArcs) {
            arc.destroy();
        }
        pooledArcs = null;

        super.destroy();
    }
}