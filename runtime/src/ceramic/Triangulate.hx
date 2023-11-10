package ceramic;

import ceramic.Shortcuts.*;
import earcut.Earcut;
import poly2tri.Point as Poly2TriPoint;
import poly2tri.Sweep;
import poly2tri.SweepContext;

using ceramic.Extensions;

/**
 * An utility to triangulate indices from a set of vertices
 */
class Triangulate {

    static var poly2triPointsPool:Array<Poly2TriPoint> = [];
    static var poly2triPoints:Array<Poly2TriPoint> = [];
    static var poly2triSweepContext:SweepContext;
    static var poly2triSweep:Sweep;

    static var tmpVertices:Array<Float> = null;
    static var tmpIndices:Array<Int> = null;

    /**
     * Triangulate the given vertices and fills the indices array accordingly
     */
    public extern inline static overload function triangulate(vertices:Array<Float>, indices:Array<Int>, ?holes:Array<Int>, method:TriangulateMethod = POLY2TRI):Void {
        _triangulate(vertices, indices, holes, method);
    }

    /**
     * Triangulate the given vertices and fills the indices array accordingly.
     * Variant method that takes a range to operate only on a subset of vertices.
     * Indices will be added to the given array.
     */
    public extern inline static overload function triangulate(vertices:Array<Float>, index:Int, length:Int, indices:Array<Int>, ?holes:Array<Int>, method:TriangulateMethod = POLY2TRI):Void {
        _triangulateWithRange(vertices, index, length, indices, holes, method);
    }

    static function _triangulateWithRange(vertices:Array<Float>, index:Int, length:Int, indices:Array<Int>, holes:Array<Int>, method:TriangulateMethod):Void {

        if (tmpVertices == null) {
            tmpVertices = [];
        }
        if (tmpIndices == null) {
            tmpIndices = [];
        }

        tmpVertices.setArrayLength(0);
        tmpIndices.setArrayLength(0);

        for (i in index...index+length) {
            tmpVertices.push(vertices[i*2]);
            tmpVertices.push(vertices[i*2+1]);
        }

        _triangulate(tmpVertices, tmpIndices, holes, method);

        for (i in 0...tmpIndices.length) {
            indices.push(index + tmpIndices[i]);
        }

        tmpVertices.setArrayLength(0);
        tmpIndices.setArrayLength(0);

    }

    static function _triangulate(vertices:Array<Float>, indices:Array<Int>, holes:Array<Int>, method:TriangulateMethod):Void {

        // Empty indices data
        if (indices.length > 0) {
            indices.setArrayLength(0);
        }

        switch method {
            case EARCUT:
                // Perform triangulation with earcut (approximative but fast)
                Earcut.earcut(vertices, holes, 2, indices);

            case POLY2TRI: try {
                // Perform triangulation with poly2tri (precise but maybe slightly slower)
                if (poly2triSweepContext == null) {
                    poly2triSweepContext = new SweepContext();
                    poly2triSweep = new Sweep(poly2triSweepContext);
                }
                else {
                    poly2triSweepContext.reset();
                }

                var poolIndex = 0;
                var pId = 0;
                inline function toPoly2TriPoints(rawPoints:Array<Float>) {
                    var i = 0;
                    var len = rawPoints.length;
                    var prevX = 0.0;
                    var prevY = 0.0;
                    var skip = false;
                    var firstP:Poly2TriPoint = null;
                    while (i < len) {
                        var p = poly2triPointsPool[poolIndex];
                        if (p == null) {
                            p = new Poly2TriPoint(rawPoints[i], rawPoints[i+1]);
                        }
                        else {
                            p.x = rawPoints[i];
                            p.y = rawPoints[i+1];
                        }
                        p.id = pId++;
                        if (i == 0) {
                            firstP = p;
                        }
                        if (i > 0 && prevX == p.x && prevY == p.y) {
                            // Skip identical point
                        }
                        else if (i == len - 2 && firstP.x == p.x && firstP.y == p.y) {
                            // Skip identical start & end points
                        }
                        else {
                            prevX = p.x;
                            prevY = p.y;
                            poly2triPoints[poolIndex] = p;
                            poolIndex++;
                        }
                        i += 2;
                    }
                    if (!skip) {
                        var numPoints = Std.int(len / 2);
                        if (poly2triPoints.length > numPoints)
                            poly2triPoints.setArrayLength(numPoints);
                    }
                    return !skip;
                }

                // Shape
                toPoly2TriPoints(vertices);
                poly2triSweepContext.addPolyline(poly2triPoints);

                // Holes
                if (holes != null) {
                    var numVertices = Std.int(vertices.length / 2);
                    var numHoles = holes.length;
                    for (h in 0...numHoles) {
                        var start = holes[h];
                        var end = h < numHoles - 1 ? holes[h + 1] : numVertices;
                        var numIndices = 0;
                        for (indice in start...end) {
                            poly2triPoints[numIndices] = poly2triPointsPool[indice];
                            numIndices++;
                        }
                        if (poly2triPoints.length > numIndices)
                            poly2triPoints.setArrayLength(numIndices);
                        poly2triSweepContext.addPolyline(poly2triPoints);
                    }
                }

                poly2triSweep.triangulate();

                var triangles = poly2triSweepContext.triangles;
                for (t in 0...triangles.length)
                {
                    var points = triangles[t].points;
                    for (i in 0...3)
                    {
                        indices.push(points[i].id);
                    }
                }
            }
            catch (e:Dynamic) {
                log.warning('Failed to triangulate with poly2tri: $e');
            }

            poly2tri.Pool.recycleAll();
        }

    }

}
