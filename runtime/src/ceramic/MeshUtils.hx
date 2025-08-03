package ceramic;

using ceramic.Extensions;

/**
 * Low-level utility class for generating mesh data arrays.
 *
 * MeshUtils provides static methods for creating vertices, indices, and UV coordinates
 * for grid-based meshes. These utilities are the foundation for procedural mesh generation
 * and are used by MeshExtensions for higher-level operations.
 *
 * Key features:
 * - Grid vertex generation with staggering support
 * - Triangle index generation with mirroring options
 * - UV coordinate mapping for grid texturing
 * - Support for custom vertex attributes
 * - Efficient array reuse
 *
 * Grid coordinate system:
 * ```
 * 0,0 --- 1,0 --- 2,0
 *  |       |       |
 * 0,1 --- 1,1 --- 2,1
 *  |       |       |
 * 0,2 --- 1,2 --- 2,2
 * ```
 *
 * @example
 * ```haxe
 * // Create a 5x5 grid mesh
 * var vertices = MeshUtils.createVerticesGrid(null, 5, 5, 200, 200);
 * var indices = MeshUtils.createIndicesGrid(null, 5, 5);
 * var uvs = MeshUtils.createUVsGrid(null, 5, 5);
 *
 * var mesh = new Mesh();
 * mesh.color = Color.WHITE;
 * mesh.vertices = vertices;
 * mesh.indices = indices;
 * mesh.uvs = uvs;
 * ```
 *
 * @see MeshExtensions For higher-level mesh creation methods
 * @see Mesh The mesh class that uses these utilities
 */
class MeshUtils {

    /**
     * Creates a grid of vertices with optional staggering and custom attributes.
     *
     * Generates vertices arranged in a rectangular grid pattern. Each vertex consists
     * of x,y coordinates followed by optional custom attributes. The total number of
     * vertices is (columns+1) × (rows+1).
     *
     * Staggering creates offset patterns useful for:
     * - Hexagonal grids (staggerX with odd rows offset)
     * - Diamond/isometric grids (both staggerX and staggerY)
     * - Wave effects and deformations
     *
     * Vertex data layout: [x, y, ...customAttributes]
     *
     * @param vertices Existing array to reuse, or null to create new array.
     *                 If provided and larger than needed, will be truncated.
     * @param columns Number of columns in the grid (cells, not vertices)
     * @param rows Number of rows in the grid (cells, not vertices)
     * @param width Total width of the grid in pixels
     * @param height Total height of the grid in pixels
     * @param staggerX Horizontal offset applied to odd-numbered rows.
     *                 Use cellWidth*0.5 for hexagonal grids.
     * @param staggerY Vertical offset applied to odd-numbered columns.
     *                 Rarely used, but can create diamond patterns.
     * @param attrLength Number of custom float attributes per vertex.
     *                   Common values: 2 for UV, 4 for color, etc.
     * @param attrValues Array of attribute values to assign.
     *                   If null, attributes are initialized to 0.
     *                   Length must equal (columns+1)×(rows+1)×attrLength.
     * @return Array of vertex data with length (columns+1)×(rows+1)×(2+attrLength)
     *
     * @example
     * ```haxe
     * // Simple 10x10 grid
     * var vertices = MeshUtils.createVerticesGrid(null, 10, 10, 400, 400);
     *
     * // Hexagonal grid with horizontal stagger
     * var cellWidth = 40;
     * var vertices = MeshUtils.createVerticesGrid(
     *     null, 10, 10, 400, 400,
     *     cellWidth * 0.5, 0
     * );
     *
     * // Grid with per-vertex colors (4 floats: r,g,b,a)
     * var colors = [
     *     // color data
     * ];
     * var vertices = MeshUtils.createVerticesGrid(
     *     null, 10, 10, 400, 400,
     *     0, 0, 4, colors
     * );
     * ```
     */
    public static function createVerticesGrid(?vertices:Array<Float>, columns:Int, rows:Int, width:Float, height:Float, staggerX:Float = 0, staggerY:Float = 0, attrLength:Int = 0, ?attrValues:Array<Float>):Array<Float> {

        var vertexCount:Int = (columns + 1) * (rows + 1);
        if (vertices == null) {
            vertices = [];
        }
        if (vertices.length > vertexCount * 2) {
            vertices.setArrayLength(vertexCount * 2);
        }

        var columnWidth:Float = width / columns;
        var rowHeight:Float = height / rows;

        var index:Int = 0;
        var attrIndex:Int = 0;
        if (attrLength > 0 && attrValues == null) {
            if (staggerX == 0 && staggerY == 0) {
                for (y in 0...(rows + 1)) {
                    for (x in 0...(columns + 1)) {

                        var xPos:Float = x * columnWidth;
                        var yPos:Float = y * rowHeight;

                        vertices[index++] = xPos;
                        vertices[index++] = yPos;

                        // Custom attributes
                        for (i in 0...attrLength) {
                            vertices[index++] = 0;
                        }
                    }
                }
            }
            else {
                for (y in 0...(rows + 1)) {
                    var modY = (y % 2);
                    for (x in 0...(columns + 1)) {

                        var xPos:Float = x * columnWidth;
                        var yPos:Float = y * rowHeight;

                        vertices[index++] = xPos + staggerX * modY;
                        vertices[index++] = yPos + staggerY * (x % 2);

                        // Custom attributes
                        for (i in 0...attrLength) {
                            vertices[index++] = 0;
                        }
                    }
                }
            }
        }
        else {
            if (staggerX == 0 && staggerY == 0) {
                for (y in 0...(rows + 1)) {
                    for (x in 0...(columns + 1)) {

                        var xPos:Float = x * columnWidth;
                        var yPos:Float = y * rowHeight;

                        vertices[index++] = xPos;
                        vertices[index++] = yPos;

                        // Custom attributes
                        for (i in 0...attrLength) {
                            vertices[index++] = attrValues[attrIndex++];
                        }
                    }
                }
            }
            else {
                for (y in 0...(rows + 1)) {
                    var modY = (y % 2);
                    for (x in 0...(columns + 1)) {

                        var xPos:Float = x * columnWidth;
                        var yPos:Float = y * rowHeight;

                        vertices[index++] = xPos + staggerX * modY;
                        vertices[index++] = yPos + staggerY * (x % 2);

                        // Custom attributes
                        for (i in 0...attrLength) {
                            vertices[index++] = attrValues[attrIndex++];
                        }
                    }
                }
            }
        }

        return vertices;

    }

    /**
     * Creates triangle indices for a grid of vertices.
     *
     * Generates indices that connect grid vertices into triangles, with each grid cell
     * split into two triangles. The total number of triangles is columns×rows×2.
     *
     * Triangle winding order (default, no mirroring):
     * ```
     * TL --- TR
     * |\     |
     * | \    |  Cell split: TL-TR-BL and TR-BR-BL
     * |  \   |
     * |   \  |
     * |    \ |
     * BL --- BR
     * ```
     *
     * Mirroring options change the diagonal direction in alternating cells,
     * which helps:
     * - Reduce visual patterns in deformed meshes
     * - Create more natural-looking terrain
     * - Improve shading on curved surfaces
     *
     * @param indices Existing array to reuse, or null to create new array.
     *                If provided and larger than needed, will be truncated.
     * @param columns Number of columns in the grid (cells, not vertices)
     * @param rows Number of rows in the grid (cells, not vertices)
     * @param mirrorX Mirror triangle diagonal in odd-numbered columns.
     *                Creates horizontal alternation pattern.
     * @param mirrorY Mirror triangle diagonal in odd-numbered rows.
     *                Creates vertical alternation pattern.
     * @param mirrorFlip Inverts the mirroring pattern.
     *                   If true, mirrors even cells instead of odd.
     * @return Array of indices with length columns×rows×6
     *         (2 triangles × 3 vertices per cell)
     *
     * @example
     * ```haxe
     * // Standard grid triangulation
     * var indices = MeshUtils.createIndicesGrid(null, 10, 10);
     *
     * // Alternating pattern for natural terrain
     * var indices = MeshUtils.createIndicesGrid(
     *     null, 10, 10,
     *     true, true  // Mirror both X and Y
     * );
     *
     * // Custom pattern with flipped mirroring
     * var indices = MeshUtils.createIndicesGrid(
     *     null, 10, 10,
     *     true, false, true  // Mirror X on even columns
     * );
     * ```
     */
    public static function createIndicesGrid(?indices:Array<Int>, columns:Int, rows:Int, mirrorX:Bool = false, mirrorY:Bool = false, mirrorFlip:Bool = false):Array<Int> {

        var triangleCount:Int = columns * rows * 2;
        if (indices == null) {
            indices = [];
        }
        if (indices.length > triangleCount * 3) {
            indices.setArrayLength(triangleCount * 3);
        }

        var index:Int = 0;
        var baseFlip:Int = mirrorFlip ? -1 : 1;
        for (y in 0...rows) {
            var yAlt:Int = (y % 2 == 1) ? -1 : 1;
            for (x in 0...columns) {
                var topLeft:Int = y * (columns + 1) + x;
                var topRight:Int = topLeft + 1;
                var bottomLeft:Int = topLeft + (columns + 1);
                var bottomRight:Int = bottomLeft + 1;

                var flip:Int = baseFlip;
                if (mirrorX && x % 2 == 1)
                    flip *= -1;
                flip *= yAlt;

                if (flip == 1) {
                    // First triangle
                    indices[index++] = topLeft;
                    indices[index++] = topRight;
                    indices[index++] = bottomLeft;

                    // Second triangle
                    indices[index++] = topRight;
                    indices[index++] = bottomRight;
                    indices[index++] = bottomLeft;
                }
                else {
                    // First triangle
                    indices[index++] = topLeft;
                    indices[index++] = bottomRight;
                    indices[index++] = bottomLeft;

                    // Second triangle
                    indices[index++] = topLeft;
                    indices[index++] = topRight;
                    indices[index++] = bottomRight;
                }
            }
        }

        return indices;

    }

    /**
     * Creates UV coordinates for a grid of vertices.
     *
     * Generates UV coordinates that map linearly across the grid from 0 to 1,
     * stretching any applied texture across the entire mesh. Each vertex gets
     * a UV coordinate based on its grid position.
     *
     * UV mapping:
     * - Top-left vertex: (0, 0)
     * - Top-right vertex: (1, 0)
     * - Bottom-left vertex: (0, 1)
     * - Bottom-right vertex: (1, 1)
     *
     * Offsets allow texture scrolling and tiling effects.
     *
     * @param uvs Existing array to reuse, or null to create new array.
     *            If provided and larger than needed, will be truncated.
     * @param columns Number of columns in the grid (cells, not vertices)
     * @param rows Number of rows in the grid (cells, not vertices)
     * @param offsetX Horizontal UV offset for texture scrolling.
     *                Values > 1 create tiling if texture wrap is enabled.
     * @param offsetY Vertical UV offset for texture scrolling.
     *                Values > 1 create tiling if texture wrap is enabled.
     * @return Array of UV coordinates with length (columns+1)×(rows+1)×2
     *
     * @example
     * ```haxe
     * // Standard UV mapping (texture stretched across grid)
     * var uvs = MeshUtils.createUVsGrid(null, 10, 10);
     *
     * // Scrolling texture effect
     * var uvs = MeshUtils.createUVsGrid(
     *     null, 10, 10,
     *     time * 0.1, 0  // Scroll horizontally over time
     * );
     *
     * // Tiled texture (requires texture wrap mode)
     * var uvs = MeshUtils.createUVsGrid(
     *     null, 10, 10,
     *     0, 0  // UVs will go from 0 to 1
     * );
     * // Then scale UVs by tile count in shader or modify here
     * ```
     */
    public static function createUVsGrid(?uvs:Array<Float>, columns:Int, rows:Int, offsetX:Float = 0, offsetY:Float = 0):Array<Float> {

        var vertexCount:Int = (columns + 1) * (rows + 1);
        if (uvs == null) {
            uvs = [];
        }
        if (uvs.length > vertexCount * 2) {
            uvs.setArrayLength(vertexCount * 2);
        }

        var index:Int = 0;
        for (y in 0...(rows + 1)) {
            for (x in 0...(columns + 1)) {

                var uvX:Float = (x + offsetX) / columns;
                var uvY:Float = (y + offsetY) / rows;

                uvs[index++] = uvX;
                uvs[index++] = uvY;
            }
        }

        return uvs;

    }

}
