package ceramic;

using ceramic.Extensions;

/**
 * Static extension class providing utility methods for Mesh manipulation.
 *
 * This class contains helper methods for common mesh operations such as:
 * - Creating quad geometry
 * - Setting dark colors for special shaders
 * - Creating arc/ring/pie geometry
 * - Creating grid-based meshes
 *
 * These methods are available on any Mesh instance through Haxe's static extension feature.
 *
 * ```haxe
 * using ceramic.MeshExtensions;
 *
 * var mesh = new Mesh();
 * mesh.createQuad(100, 100); // Creates a 100x100 quad
 * mesh.createArc(50, 180, 10, 32, INSIDE); // Creates a semi-circle arc
 * ```
 *
 * @see Mesh The base mesh class these extensions apply to
 * @see MeshUtils For lower-level mesh manipulation utilities
 */
class MeshExtensions {

    /**
     * Generates vertices, indices and uvs to form a rectangular quad.
     *
     * Creates a quad with 4 vertices arranged as:
     * ```
     * 0 -- 1
     * |    |
     * 3 -- 2
     * ```
     *
     * The quad is positioned with its top-left corner at (0,0).
     * UV coordinates are mapped from 0 to 1 across the quad.
     *
     * @param mesh The mesh to configure as a quad
     * @param width Width of the quad in pixels
     * @param height Height of the quad in pixels
     * @param floatsPerVertex Number of floats per vertex in the vertex buffer.
     *                        - 2: Standard quad (x, y)
     *                        - 6: Quad with dark color support (x, y, r, g, b, a)
     *                        - -1: Auto-detect from mesh.customFloatAttributesSize
     *                        Must be at least 2.
     *
     * ```haxe
     * var mesh = new Mesh();
     * mesh.createQuad(200, 150); // Creates a 200x150 quad
     * mesh.texture = myTexture;  // Apply texture
     * ```
     */
    public static function createQuad(mesh:Mesh, width:Float, height:Float, floatsPerVertex:Int = -1):Void {

        if (floatsPerVertex < 2) {
            floatsPerVertex = 2 + mesh.customFloatAttributesSize;
        }

        var uvs = mesh.uvs;
        uvs[7] = 1;
        uvs.unsafeSet(0, 0);
        uvs.unsafeSet(1, 0);
        uvs.unsafeSet(2, 1);
        uvs.unsafeSet(3, 0);
        uvs.unsafeSet(4, 1);
        uvs.unsafeSet(5, 1);
        uvs.unsafeSet(6, 0);
        if (uvs.length > 8) {
            uvs.setArrayLength(8);
        }

        var indices = mesh.indices;
        indices[5] = 3;
        indices.unsafeSet(0, 0);
        indices.unsafeSet(1, 1);
        indices.unsafeSet(2, 2);
        indices.unsafeSet(3, 0);
        indices.unsafeSet(4, 2);
        if (indices.length > 6) {
            indices.setArrayLength(6);
        }

        var vertices = mesh.vertices;
        vertices[floatsPerVertex * 4] = 0;
        var n = 0;
        vertices.unsafeSet(n, 0);
        n++;
        vertices.unsafeSet(n, 0);
        n++;
        for (i in 2...floatsPerVertex) {
            vertices.unsafeSet(n, 0);
            n++;
        }
        vertices.unsafeSet(n, width);
        n++;
        vertices.unsafeSet(n, 0);
        n++;
        for (i in 2...floatsPerVertex) {
            vertices.unsafeSet(n, 0);
            n++;
        }
        vertices.unsafeSet(n, width);
        n++;
        vertices.unsafeSet(n, height);
        n++;
        for (i in 2...floatsPerVertex) {
            vertices.unsafeSet(n, 0);
            n++;
        }
        vertices.unsafeSet(n, 0);
        n++;
        vertices.unsafeSet(n, height);
        n++;
        for (i in 2...floatsPerVertex) {
            vertices.unsafeSet(n, 0);
            n++;
        }
        if (vertices.length > n) {
            vertices.setArrayLength(n);
        }

        mesh.width = width;
        mesh.height = height;

    }

    /**
     * Assigns a dark color to all vertices in the mesh.
     *
     * This method is used with special shaders that support a secondary "dark" color
     * for advanced rendering effects. The dark color is stored in vertex attributes
     * positions 2-5 (r, g, b, a) of each vertex.
     *
     * Requirements:
     * - Mesh must have 6 floats per vertex
     * - Vertex layout: [x, y, darkR, darkG, darkB, darkA]
     *
     * @param mesh The mesh to modify. Must have 6 floats per vertex.
     * @param darkColor The dark color to apply to all vertices.
     *                  Alpha is automatically set to 1.0.
     *
     * ```haxe
     * var mesh = new Mesh();
     * mesh.createQuad(100, 100, 6); // 6 floats per vertex
     * mesh.setDarkColor(Color.PURPLE); // Set dark color
     * mesh.shader = myDarkColorShader; // Use compatible shader
     * ```
     */
    public static function setDarkColor(mesh:Mesh, darkColor:Color):Void {

        var vertices = mesh.vertices;
        var len = Math.floor(vertices.length / 6) * 6;
        var i = 0;
        var r = darkColor.redFloat;
        var g = darkColor.greenFloat;
        var b = darkColor.blueFloat;
        while (i < len) {
            i += 2;
            vertices.unsafeSet(i, r);
            i++;
            vertices.unsafeSet(i, g);
            i++;
            vertices.unsafeSet(i, b);
            i++;
            vertices.unsafeSet(i, 1);
            i++;
        }

    }

    /**
     * Assigns a dark color with alpha to all vertices in the mesh.
     *
     * Similar to setDarkColor but preserves the alpha channel from the provided color.
     * Used with special shaders that support transparent dark colors for effects
     * like shadows or overlays.
     *
     * Requirements:
     * - Mesh must have 6 floats per vertex
     * - Vertex layout: [x, y, darkR, darkG, darkB, darkA]
     *
     * @param mesh The mesh to modify. Must have 6 floats per vertex.
     * @param darkAlphaColor The dark color with alpha to apply to all vertices.
     *
     * ```haxe
     * var mesh = new Mesh();
     * mesh.createQuad(100, 100, 6); // 6 floats per vertex
     * var shadowColor = AlphaColor.fromRGBA(0, 0, 0, 128); // 50% black
     * mesh.setDarkAlphaColor(shadowColor);
     * ```
     */
    public static function setDarkAlphaColor(mesh:Mesh, darkAlphaColor:AlphaColor):Void {

        var vertices = mesh.vertices;
        var len = Math.floor(vertices.length / 6) * 6;
        var i = 0;
        var r = darkAlphaColor.redFloat;
        var g = darkAlphaColor.greenFloat;
        var b = darkAlphaColor.blueFloat;
        var a = darkAlphaColor.alphaFloat;
        while (i < len) {
            i += 2;
            vertices.unsafeSet(i, r);
            i++;
            vertices.unsafeSet(i, g);
            i++;
            vertices.unsafeSet(i, b);
            i++;
            vertices.unsafeSet(i, a);
            i++;
        }

    }

    /**
     * Generates vertices and indices to create arc, pie, ring or disc geometry.
     *
     * This versatile method can create various circular shapes:
     * - Arc: Partial circle outline (angle < 360, thickness < radius)
     * - Ring: Full circle outline (angle = 360, thickness < radius)
     * - Pie: Filled partial circle (angle < 360, thickness = radius, borderPosition = INSIDE)
     * - Disc: Filled full circle (angle = 360, thickness = radius, borderPosition = INSIDE)
     *
     * The shape is centered at (radius, radius) to ensure all vertices are positive.
     *
     * @param mesh The mesh to configure with arc geometry
     * @param radius Outer radius of the arc in pixels
     * @param angle Arc angle in degrees (0-360). 360 creates a full circle.
     * @param thickness Width of the arc stroke. Set equal to radius with INSIDE position for filled shapes.
     * @param sides Number of segments. More sides = smoother curves but more vertices.
     *              Recommended: 32 for small arcs, 64+ for large arcs.
     * @param borderPosition Controls thickness direction:
     *                       - INSIDE: Thickness extends inward from radius
     *                       - OUTSIDE: Thickness extends outward from radius
     *                       - MIDDLE: Thickness extends equally in both directions
     *
     * ```haxe
     * // Create a 90-degree arc
     * mesh.createArc(50, 90, 10, 32, MIDDLE);
     *
     * // Create a filled semi-circle (pie)
     * mesh.createArc(50, 180, 50, 32, INSIDE);
     *
     * // Create a ring (donut)
     * mesh.createArc(50, 360, 20, 64, MIDDLE);
     * ```
     */
    public static function createArc(mesh:Mesh, radius:Float, angle:Float, thickness:Float, sides:Int, borderPosition:BorderPosition):Void {

        var count:Int = Math.ceil(sides * angle / 360);

        var vertices = mesh.vertices;
        var indices = mesh.indices;

        vertices.setArrayLength(0);
        indices.setArrayLength(0);

        var _x:Float;
        var _y:Float;

        var angleOffset:Float = Math.PI * 1.5;
        var sidesOverTwoPi:Float = Utils.degToRad(angle) / count;

        var borderStart:Float = switch borderPosition {
            case INSIDE: -thickness;
            case OUTSIDE: 0;
            case MIDDLE: -thickness * 0.5;
        }
        var borderEnd:Float = switch borderPosition {
            case INSIDE: 0;
            case OUTSIDE: thickness;
            case MIDDLE: thickness * 0.5;
        }

        for (i in 0...count+(angle != 360 ? 1 : 0)) {

            var rawX = Math.cos(angleOffset + sidesOverTwoPi * i);
            var rawY = Math.sin(angleOffset + sidesOverTwoPi * i);

            _x = (radius + borderStart) * rawX;
            _y = (radius + borderStart) * rawY;

            vertices.push(radius + _x);
            vertices.push(radius + _y);

            _x = (radius + borderEnd) * rawX;
            _y = (radius + borderEnd) * rawY;

            vertices.push(radius + _x);
            vertices.push(radius + _y);

            if (i > 0) {
                var n = (i - 1) * 2;
                indices.push(n);
                indices.push(n + 1);
                indices.push(n + 2);
                indices.push(n + 1);
                indices.push(n + 2);
                indices.push(n + 3);
            }

        }

        if (angle == 360) {
            var n = (count - 1) * 2;
            indices.push(n);
            indices.push(n + 1);
            indices.push(0);
            indices.push(n + 1);
            indices.push(0);
            indices.push(1);
        }

    }

    /**
     * Creates a grid of vertices with optional staggering and custom attributes.
     *
     * Generates a rectangular grid of vertices that can be used for:
     * - Terrain meshes
     * - Grid-based effects
     * - Deformable surfaces
     * - Tilemap rendering
     *
     * Vertices are arranged in row-major order (left to right, top to bottom).
     *
     * @param mesh The mesh to populate with grid vertices
     * @param columns Number of columns (vertices per row)
     * @param rows Number of rows
     * @param width Total width of the grid in pixels
     * @param height Total height of the grid in pixels
     * @param staggerX Horizontal offset applied to odd rows (for hexagonal grids)
     * @param staggerY Vertical offset applied to odd columns (for diamond grids)
     * @param attrLength Number of custom float attributes per vertex (beyond x,y)
     * @param attrValues Optional array of custom attribute values.
     *                   Length must equal (columns+1) * (rows+1) * attrLength
     *
     * ```haxe
     * // Create a 10x10 grid for terrain deformation
     * mesh.createVerticesGrid(10, 10, 400, 400);
     * mesh.createIndicesGrid(10, 10);
     *
     * // Create hexagonal grid
     * mesh.createVerticesGrid(10, 10, 400, 400, cellWidth * 0.5, 0);
     * ```
     *
     * @see createIndicesGrid To create matching triangle indices
     * @see createUVsGrid To create matching UV coordinates
     * @see MeshUtils.createVerticesGrid The underlying implementation
     */
    public static function createVerticesGrid(mesh:Mesh, columns:Int, rows:Int, width:Float, height:Float, staggerX:Float = 0, staggerY:Float = 0, attrLength:Int = 0, ?attrValues:Array<Float>):Void {
        mesh.vertices = MeshUtils.createVerticesGrid(mesh.vertices, columns, rows, width, height, staggerX, staggerY, attrLength, attrValues);
    }

    /**
     * Creates triangle indices for a grid of vertices.
     *
     * Generates indices that connect grid vertices into triangles.
     * Each grid cell is split into two triangles. The mirroring options
     * allow for alternating triangle orientations, useful for:
     * - Reducing visual patterns in deformed meshes
     * - Creating more natural-looking terrain
     * - Special tessellation patterns
     *
     * Default triangle pattern (no mirroring):
     * ```
     * 0---1
     * |\  |
     * | \ |
     * |  \|
     * 3---2
     * ```
     *
     * @param mesh The mesh to populate with indices
     * @param columns Number of columns in the vertex grid
     * @param rows Number of rows in the vertex grid
     * @param mirrorX Mirror triangle orientation in odd columns
     * @param mirrorY Mirror triangle orientation in odd rows
     * @param mirrorFlip Inverts the mirroring pattern (even instead of odd)
     *
     * ```haxe
     * // Standard grid
     * mesh.createIndicesGrid(10, 10);
     *
     * // Alternating pattern for better deformation
     * mesh.createIndicesGrid(10, 10, true, true);
     * ```
     *
     * @see createVerticesGrid Must be called first to create vertices
     * @see MeshUtils.createIndicesGrid The underlying implementation
     */
    public static function createIndicesGrid(mesh:Mesh, columns:Int, rows:Int, mirrorX:Bool = false, mirrorY:Bool = false, mirrorFlip:Bool = false):Void {
        mesh.indices = MeshUtils.createIndicesGrid(mesh.indices, columns, rows, mirrorX, mirrorY, mirrorFlip);
    }

    /**
     * Creates UV coordinates for a grid of vertices.
     *
     * Generates UV coordinates that map linearly across the grid,
     * stretching any applied texture across the entire mesh.
     * UVs range from (0+offsetX, 0+offsetY) to (1+offsetX, 1+offsetY).
     *
     * This is useful for:
     * - Applying textures to terrain meshes
     * - Creating texture-based deformation maps
     * - Mapping effects across grid surfaces
     *
     * @param mesh The mesh to populate with UV coordinates
     * @param columns Number of columns in the vertex grid
     * @param rows Number of rows in the vertex grid
     * @param offsetX UV offset in the X direction (texture scrolling)
     * @param offsetY UV offset in the Y direction (texture scrolling)
     *
     * ```haxe
     * // Standard UV mapping
     * mesh.createUVsGrid(10, 10);
     *
     * // Scrolling texture effect
     * mesh.createUVsGrid(10, 10, time * 0.1, 0);
     * ```
     *
     * @see createVerticesGrid Must be called first to create vertices
     * @see MeshUtils.createUVsGrid The underlying implementation
     */
    public static function createUVsGrid(mesh:Mesh, columns:Int, rows:Int, offsetX:Float = 0, offsetY:Float = 0):Void {
        mesh.uvs = MeshUtils.createUVsGrid(mesh.uvs, columns, rows, offsetX, offsetY);
    }

}