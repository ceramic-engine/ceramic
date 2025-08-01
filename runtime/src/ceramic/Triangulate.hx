package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * Utility class for triangulating polygons into triangles.
 * 
 * Triangulate converts complex polygons (defined by vertices) into a set of triangles
 * by generating appropriate indices. This is essential for rendering filled shapes
 * on the GPU, which typically only supports triangle primitives.
 * 
 * The triangulation uses the ear-clipping algorithm, which:
 * - Works with both convex and concave polygons
 * - Handles clockwise and counter-clockwise winding
 * - Produces a valid triangulation for simple polygons (no self-intersections)
 * 
 * Common uses:
 * - Converting Shape paths to renderable triangles
 * - Filling complex polygons
 * - Creating meshes from outline data
 * - Processing vector graphics
 * 
 * @example
 * ```haxe
 * // Triangulate a square
 * var vertices = [
 *     0, 0,    // Top-left
 *     100, 0,  // Top-right
 *     100, 100, // Bottom-right
 *     0, 100   // Bottom-left
 * ];
 * var indices = [];
 * Triangulate.triangulate(vertices, indices);
 * // indices now contains [0, 1, 2, 0, 2, 3]
 * ```
 * 
 * @see Shape For automatic triangulation of visual shapes
 * @see EarClippingTriangulator The underlying triangulation implementation
 */
class Triangulate {

    static var tmpVertices:Array<Float> = null;
    static var tmpIndices:Array<Int> = null;
    static var triangulator:EarClippingTriangulator = null;

    /**
     * Triangulates a polygon defined by vertices and fills the indices array.
     * 
     * Takes a list of 2D vertices (as x,y pairs) and generates triangle indices
     * that define how to connect those vertices into triangles. The polygon
     * should be simple (no self-intersections) for best results.
     * 
     * @param vertices Array of vertex coordinates as [x0,y0, x1,y1, x2,y2, ...]
     *                 Must contain at least 6 values (3 vertices).
     * @param indices Output array to fill with triangle indices.
     *                Will be cleared before adding new indices.
     *                Result length will be 3 × (numVertices - 2).
     * 
     * @example
     * ```haxe
     * var vertices = [0,0, 100,0, 50,100]; // Triangle
     * var indices = [];
     * Triangulate.triangulate(vertices, indices);
     * // indices = [0, 1, 2]
     * ```
     */
    public extern inline static overload function triangulate(vertices:Array<Float>, indices:Array<Int>):Void {
        _triangulate(vertices, indices);
    }

    /**
     * Triangulates a subset of vertices within the given array.
     * 
     * This variant allows triangulating only a portion of a larger vertex array,
     * useful when working with multiple polygons in a single buffer. The indices
     * generated will be offset to match the original vertex positions.
     * 
     * @param vertices Array containing vertex coordinates as [x,y] pairs
     * @param index Starting vertex index (not array index).
     *              Array index = index × 2.
     * @param length Number of vertices to process (not array length).
     *               Array elements used = length × 2.
     * @param indices Output array to append triangle indices.
     *                Indices are offset by 'index' parameter.
     *                Does NOT clear existing content.
     * 
     * @example
     * ```haxe
     * // Triangulate second polygon in a multi-polygon buffer
     * var vertices = [
     *     // First polygon (4 vertices)
     *     0,0, 50,0, 50,50, 0,50,
     *     // Second polygon (3 vertices) 
     *     100,0, 150,0, 125,50
     * ];
     * var indices = [];
     * Triangulate.triangulate(vertices, 4, 3, indices);
     * // indices = [4, 5, 6] (referencing second polygon)
     * ```
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
 * Implementation of the ear-clipping algorithm for polygon triangulation.
 * 
 * A simple implementation of the ear cutting algorithm to triangulate simple polygons without holes. 
 * The algorithm works by:
 * 1. Finding "ear" vertices (vertices that form triangles with no other vertices inside)
 * 2. Clipping these ears one by one
 * 3. Repeating until only one triangle remains
 * 
 * For more information:
 * - http://cgm.cs.mcgill.ca/~godfried/teaching/cg-projects/97/Ian/algorithm2.html
 * - http://www.geometrictools.com/Documentation/TriangulationByEarClipping.pdf
 * 
 * Performance characteristics:
 * - Time complexity: O(n²) for n vertices
 * - Works with both convex and concave polygons
 * - Handles degenerate cases (nearly collinear vertices)
 * 
 * Limitations:
 * - If the input polygon is not simple (self-intersects), there will be output 
 *   but it is of unspecified quality (garbage in, garbage out).
 * - If the polygon vertices are very large or very close together then 
 *   GeometryUtils.isClockwise() may not be able to properly assess the winding 
 *   (because it uses floats). In that case the vertices should be adjusted, 
 *   eg by finding the smallest X and Y values and subtracting that from each vertex.
 * 
 * @author badlogicgames@gmail.com
 * @author Nicolas Gramlich (optimizations, collinear edge support)
 * @author Eric Spitz
 * @author Thomas ten Cate (bugfixes, optimizations)
 * @author Nathan Sweet (rewrite, return indices, no allocation, optimizations)
 * @author Jérémy Faivre (ported to Haxe)
 */
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
     * Triangulates the given (convex or concave) simple polygon to a list of triangle vertices.
     * 
     * The algorithm automatically detects and handles the winding order of the input,
     * always producing triangles in clockwise order. The triangulation is performed
     * in-place with minimal allocations.
     * 
     * @param vertices Pairs describing vertices of the polygon [x0,y0, x1,y1, ...], 
     *                 in either clockwise or counterclockwise order.
     * @param offset The offset into the vertices array (in array elements, not vertices).
     *               Default: 0
     * @param count The number of array elements to use (not vertex count).
     *              Use -1 to process all remaining elements. Default: -1
     * @param outputTriangles Optional array to fill with triangle indices.
     *                        Will be cleared before use. If not provided, a new array is created.
     * @return Array of triangle indices in clockwise order.
     *         Each group of 3 indices forms one triangle.
     * 
     * @example
     * ```haxe
     * var triangulator = new EarClippingTriangulator();
     * var vertices = [0,0, 100,0, 100,100, 0,100]; // Square
     * var indices = triangulator.computeTriangles(vertices);
     * // indices = [0,1,2, 0,2,3] (two triangles)
     * ```
     */
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

    /**
     * Determines if a vertex is convex or concave based on the sign of the area
     * spanned by it and its adjacent vertices.
     * 
     * @param index The vertex index to classify
     * @return CONVEX (1) if the vertex forms a convex angle,
     *         CONCAVE (-1) if it forms a concave angle,
     *         or 0 if the vertices are collinear
     */
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

    /**
     * Finds a vertex that can be safely removed as an ear tip.
     * 
     * An ear tip is a vertex that:
     * 1. Is convex (or tangential)
     * 2. Forms a triangle with its neighbors that contains no other vertices
     * 
     * If no valid ear is found (degenerate polygon), falls back to:
     * 1. Any convex vertex
     * 2. The first vertex (if all are concave - shouldn't happen in valid polygons)
     * 
     * @return Index of the ear tip vertex to remove
     */
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

    /**
     * Tests whether a vertex is a valid ear tip that can be clipped.
     * 
     * A vertex is an ear tip if:
     * 1. It's convex (not concave)
     * 2. The triangle formed with its neighbors contains no other polygon vertices
     * 
     * The test uses the sign of computed areas to determine if points are inside
     * the triangle. Points exactly on edges are considered inside.
     * 
     * @param earTipIndex The vertex index to test
     * @return true if the vertex is a valid ear tip
     */
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

    /**
     * Removes an ear tip vertex and adds the resulting triangle to the output.
     * 
     * Creates a triangle from the ear tip and its two neighbors, then removes
     * the ear tip vertex from further consideration.
     * 
     * @param earTipIndex The index of the ear tip vertex to remove
     */
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

    /**
     * Computes the sign of the area of the triangle formed by three points.
     * 
     * Uses the cross product to determine orientation:
     * - Positive: Counter-clockwise winding (convex in a clockwise polygon)
     * - Negative: Clockwise winding (concave in a clockwise polygon)
     * - Zero: Collinear points
     * 
     * @param p1x X coordinate of first point
     * @param p1y Y coordinate of first point
     * @param p2x X coordinate of second point
     * @param p2y Y coordinate of second point
     * @param p3x X coordinate of third point
     * @param p3y Y coordinate of third point
     * @return 1 for positive area, -1 for negative area, 0 for collinear
     */
    private static function computeSpannedAreaSign(p1x:Float, p1y:Float, p2x:Float, p2y:Float, p3x:Float, p3y:Float):Int {
        var area:Float = p1x * (p3y - p2y);
        area += p2x * (p1y - p3y);
        area += p3x * (p2y - p1y);
        return Std.int(area > 0 ? 1 : (area < 0 ? -1 : 0));
    }

}
