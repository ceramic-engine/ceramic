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
        } else {
            line = new Line();
        }
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
            remove(quad);
            pooledQuads.push(quad);
        }
        activeQuads.resize(0);

        // Recycle lines
        for (line in activeLines) {
            line.active = false;
            remove(line);
            if (line.points != null) line.points.resize(0);
            pooledLines.push(line);
        }
        activeLines.resize(0);

        // Recycle arcs
        for (arc in activeArcs) {
            arc.active = false;
            remove(arc);
            pooledArcs.push(arc);
        }
        activeArcs.resize(0);

        // Clear path data
        currentPath = null;
        pathSegments.resize(0);
        currentX = 0;
        currentY = 0;

        super.clear();
    }

    /**
     * Set the line style for subsequent drawing operations
     */
    public function lineStyle(thickness:Float = 1.0, color:Color = null, alpha:Float = 1.0):Void {
        lineThickness = thickness;
        lineColor = color != null ? color : Color.WHITE;
        lineAlpha = alpha;
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

            // Simple triangulation for convex shapes
            // Copy path points as vertices
            for (i in 0...currentPath.length) {
                vertices.push(currentPath[i]);
            }

            // Create triangle fan from first vertex
            var numPoints = Std.int(currentPath.length / 2);
            if (numPoints >= 3) {
                for (i in 1...numPoints - 1) {
                    indices.push(0);
                    indices.push(i);
                    indices.push(i + 1);
                }
            }

            mesh.color = fillColor;
            mesh.alpha = fillAlpha;
            mesh.computeSize();
        }

        filling = false;
        currentPath = null;
    }

    /**
     * Draw a rectangle
     */
    public function drawRect(x:Float, y:Float, width:Float, height:Float):Void {
        if (filling) {
            // Add to current path
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
        } else {
            // Draw immediately
            var quad = getQuad();
            quad.pos(x, y);
            quad.size(width, height);
            quad.color = lineColor;
            quad.alpha = lineAlpha;
        }
    }

    /**
     * Draw a circle
     */
    public function drawCircle(x:Float, y:Float, radius:Float):Void {
        var arc = getArc();
        arc.pos(x, y);
        arc.radius = radius;
        arc.angle = 360;
        arc.sides = Math.ceil(Math.max(16, radius)); // More sides for larger circles

        if (filling) {
            arc.thickness = radius;
            arc.borderPosition = INSIDE;
            arc.color = fillColor;
            arc.alpha = fillAlpha;
        } else {
            arc.thickness = lineThickness;
            arc.borderPosition = MIDDLE;
            arc.color = lineColor;
            arc.alpha = lineAlpha;
        }
    }

    /**
     * Draw an arc
     */
    public function drawArc(x:Float, y:Float, radius:Float, startAngle:Float, endAngle:Float):Void {
        var arc = getArc();
        arc.pos(x, y);
        arc.radius = radius;
        arc.angle = Math.abs(endAngle - startAngle);
        arc.rotation = startAngle;
        arc.sides = Math.ceil(Math.max(16, radius * arc.angle / 360));

        if (filling) {
            arc.thickness = radius;
            arc.borderPosition = INSIDE;
            arc.color = fillColor;
            arc.alpha = fillAlpha;
        } else {
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
            mesh.vertices = [x1, y1, x2, y2, x3, y3];
            mesh.indices = [0, 1, 2];
            mesh.color = fillColor;
            mesh.alpha = fillAlpha;
            mesh.computeSize();
        } else {
            // Create stroked triangle
            var line = getLine();
            line.points = [x1, y1, x2, y2, x3, y3, x1, y1];
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

            // Simple triangulation (works for convex polygons)
            var numPoints = Std.int(points.length / 2);
            for (i in 1...numPoints - 1) {
                mesh.indices.push(0);
                mesh.indices.push(i);
                mesh.indices.push(i + 1);
            }

            mesh.color = fillColor;
            mesh.alpha = fillAlpha;
            mesh.computeSize();
        } else {
            // Create stroked polygon
            var line = getLine();
            line.points = points.copy();
            // Close the polygon
            line.points.push(points[0]);
            line.points.push(points[1]);
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
        }

        if (pathSegments.length == 0) {
            pathSegments.push([]);
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
        line.points = [x1, y1, x2, y2];
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
        }

        if (!filling) {
            // Draw the curve as a line
            var line = getLine();
            line.points = points;
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
        }

        if (!filling) {
            // Draw the curve as a line
            var line = getLine();
            line.points = points;
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
        for (segment in pathSegments) {
            if (segment.length >= 4) {
                var line = getLine();
                line.points = segment.copy();
                line.thickness = lineThickness;
                line.color = lineColor;
                line.alpha = lineAlpha;
            }
        }
        pathSegments.resize(0);
    }

    /**
     * Close the current path
     */
    public function closePath():Void {
        if (pathSegments.length > 0) {
            var segment = pathSegments[pathSegments.length - 1];
            if (segment.length >= 4) {
                // Add line back to the start
                segment.push(segment[0]);
                segment.push(segment[1]);
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