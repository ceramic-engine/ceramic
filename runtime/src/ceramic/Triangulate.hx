package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * An utility to triangulate indices from a set of vertices
 */
class Triangulate {

    static var tmpVertices:Array<Float> = null;
    static var tmpIndices:Array<Int> = null;
    static var triangulator:EarClippingTriangulator = null;

    /**
     * Triangulate the given vertices and fills the indices array accordingly
     */
    public extern inline static overload function triangulate(vertices:Array<Float>, indices:Array<Int>):Void {
        _triangulate(vertices, indices);
    }

    /**
     * Triangulate the given vertices and fills the indices array accordingly.
     * Variant method that takes a range to operate only on a subset of vertices.
     * Indices will be added to the given array.
     */
    public extern inline static overload function triangulate(vertices:Array<Float>, index:Int, length:Int, indices:Array<Int>):Void {
        _triangulateWithRange(vertices, index, length, indices);
    }

    static function _triangulateWithRange(vertices:Array<Float>, index:Int, length:Int, indices:Array<Int>):Void {

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

        _triangulate(tmpVertices, tmpIndices);

        for (i in 0...tmpIndices.length) {
            indices.push(index + tmpIndices[i]);
        }

        tmpVertices.setArrayLength(0);
        tmpIndices.setArrayLength(0);

    }

    static function _triangulate(vertices:Array<Float>, indices:Array<Int>):Void {

        // Empty indices data
        if (indices.length > 0) {
            indices.setArrayLength(0);
        }

        if (triangulator == null) {
            triangulator = new EarClippingTriangulator();
        }

        triangulator.computeTriangles(vertices, 0, -1, indices);

    }

}

// Ported from: libgdx's EarClippingTriangulator.java
// Look at the original code and license for reference:
// https://github.com/libgdx/libgdx/blob/5ca5b71b89c84ffe0c7b7b347a4697436694e34e/gdx/src/com/badlogic/gdx/math/EarClippingTriangulator.java
/**
    A simple implementation of the ear cutting algorithm to triangulate simple polygons without holes. For more information:
    * http://cgm.cs.mcgill.ca/~godfried/teaching/cg-projects/97/Ian/algorithm2.html
    * http://www.geometrictools.com/Documentation/TriangulationByEarClipping.pdf

    If the input polygon is not simple (self-intersects), there will be output but it is of unspecified quality (garbage in,
    garbage out).

    If the polygon vertices are very large or very close together then GeometryUtils.isClockwise() may not
    be able to properly assess the winding (because it uses floats). In that case the vertices should be adjusted, eg by finding
    the smallest X and Y values and subtracting that from each vertex.

    @author badlogicgames@gmail.com
    @author Nicolas Gramlich (optimizations, collinear edge support)
    @author Eric Spitz
    @author Thomas ten Cate (bugfixes, optimizations)
    @author Nathan Sweet (rewrite, return indices, no allocation, optimizations)
    @author Jérémy Faivre (ported to Haxe)
**/
@:allow(ceramic.Triangulate)
private class EarClippingTriangulator {
    private static inline var CONCAVE:Int = -1;
    private static inline var CONVEX:Int = 1;

    private final indices:Array<Int>;
    private final vertexTypes:Array<Int>;

    private var vertices:Array<Float> = null;
    private var vertexCount:Int = 0;
    private var triangles:Array<Int> = null;

    public function new() {
        indices = [];
        vertexTypes = [];
    }

    /**
        Triangulates the given (convex or concave) simple polygon to a list of triangle vertices.
        @param vertices pairs describing vertices of the polygon, in either clockwise or counterclockwise order.
        @param offset The offset into the vertices array
        @param count The number of vertices to use
        @param outputTriangles (optional) The array of triangles to fill. Will create a new one if not provided
        @return Array of triangle indices in clockwise order.
    **/
    public function computeTriangles(vertices:Array<Float>, offset:Int = 0, count:Int = -1, ?outputTriangles:Array<Int>):Array<Int> {
        if (count == -1) count = vertices.length;

        this.vertices = vertices;
        vertexCount = Std.int(count / 2);
        var vertexOffset:Int = Std.int(offset / 2);

        for (i in 0...vertexCount) {
            indices[i] = 0; // Initialize with zeroes
        }
        if (indices.length != vertexCount) {
            indices.setArrayLength(vertexCount);
        }

        if (GeometryUtils.isClockwise(vertices, offset, count)) {
            for (i in 0...vertexCount) {
                indices[i] = vertexOffset + i;
            }
        } else {
            for (i in 0...vertexCount) {
                indices[i] = vertexOffset + (vertexCount - 1 - i); // Reversed
            }
        }

        for (i in 0...vertexCount) {
            vertexTypes[i] = classifyVertex(i);
        }
        if (vertexTypes.length != vertexCount) {
            vertexTypes.setArrayLength(vertexCount);
        }

        // A polygon with n vertices has a triangulation of n-2 triangles
        this.triangles = outputTriangles ?? [];
        if (this.triangles.length > 0) {
            this.triangles.setArrayLength(0);
        }
        triangulate();
        return this.triangles;
    }

    private function triangulate():Void {
        while (vertexCount > 3) {
            var earTipIndex:Int = findEarTip();
            cutEarTip(earTipIndex);

            // The type of the two vertices adjacent to the clipped vertex may have changed
            var previousIndex:Int = getPreviousIndex(earTipIndex);
            var nextIndex:Int = (earTipIndex == vertexCount) ? 0 : earTipIndex;
            vertexTypes[previousIndex] = classifyVertex(previousIndex);
            vertexTypes[nextIndex] = classifyVertex(nextIndex);
        }

        if (vertexCount == 3) {
            triangles.push(indices[0]);
            triangles.push(indices[1]);
            triangles.push(indices[2]);
        }
    }

    /** @return CONCAVE or CONVEX **/
    private function classifyVertex(index:Int):Int {
        var previous:Int = indices[getPreviousIndex(index)] * 2;
        var current:Int = indices[index] * 2;
        var next:Int = indices[getNextIndex(index)] * 2;

        return computeSpannedAreaSign(
            vertices[previous], vertices[previous + 1],
            vertices[current], vertices[current + 1],
            vertices[next], vertices[next + 1]
        );
    }

    private function findEarTip():Int {
        for (i in 0...vertexCount) {
            if (isEarTip(i)) return i;
        }

        // Desperate mode: if no vertex is an ear tip, we are dealing with a degenerate polygon
        // (e.g. nearly collinear). Note that the input was not necessarily degenerate, but we
        // could have made it so by clipping some valid ears.

        // Return a convex or tangential vertex if one exists
        for (i in 0...vertexCount) {
            if (vertexTypes[i] != CONCAVE) return i;
        }
        return 0; // If all vertices are concave, just return the first one
    }

    private function isEarTip(earTipIndex:Int):Bool {
        if (vertexTypes[earTipIndex] == CONCAVE) return false;

        var previousIndex:Int = getPreviousIndex(earTipIndex);
        var nextIndex:Int = getNextIndex(earTipIndex);
        var p1:Int = indices[previousIndex] * 2;
        var p2:Int = indices[earTipIndex] * 2;
        var p3:Int = indices[nextIndex] * 2;

        var p1x:Float = vertices[p1], p1y:Float = vertices[p1 + 1];
        var p2x:Float = vertices[p2], p2y:Float = vertices[p2 + 1];
        var p3x:Float = vertices[p3], p3y:Float = vertices[p3 + 1];

        // Check if any point is inside the triangle formed by previous, current and next vertices.
        // Only consider vertices that are not part of this triangle, or else we'll always find one inside.
        var i:Int = getNextIndex(nextIndex);
        while (i != previousIndex) {
            if (vertexTypes[i] != CONVEX) {
                var v:Int = indices[i] * 2;
                var vx:Float = vertices[v];
                var vy:Float = vertices[v + 1];

                // Because the polygon has clockwise winding order, the area sign will be positive if the point is strictly inside.
                // It will be 0 on the edge, which we want to include as well.
                // note: check the edge defined by p1->p3 first since this fails _far_ more then the other 2 checks.
                if (computeSpannedAreaSign(p3x, p3y, p1x, p1y, vx, vy) >= 0) {
                    if (computeSpannedAreaSign(p1x, p1y, p2x, p2y, vx, vy) >= 0) {
                        if (computeSpannedAreaSign(p2x, p2y, p3x, p3y, vx, vy) >= 0) {
                            return false;
                        }
                    }
                }
            }
            i = getNextIndex(i);
        }
        return true;
    }

    private function cutEarTip(earTipIndex:Int):Void {
        triangles.push(indices[getPreviousIndex(earTipIndex)]);
        triangles.push(indices[earTipIndex]);
        triangles.push(indices[getNextIndex(earTipIndex)]);

        // Remove ear tip from indices
        indices.splice(earTipIndex, 1);
        vertexTypes.splice(earTipIndex, 1);
        vertexCount--;
    }

    private function getPreviousIndex(index:Int):Int {
        return (index == 0) ? vertexCount - 1 : index - 1;
    }

    private function getNextIndex(index:Int):Int {
        return (index + 1) % vertexCount;
    }

    private static function computeSpannedAreaSign(p1x:Float, p1y:Float, p2x:Float, p2y:Float, p3x:Float, p3y:Float):Int {
        var area:Float = p1x * (p3y - p2y);
        area += p2x * (p1y - p3y);
        area += p3x * (p2y - p1y);
        return Std.int(area > 0 ? 1 : (area < 0 ? -1 : 0));
    }

}
