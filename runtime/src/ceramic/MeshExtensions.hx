package ceramic;

using ceramic.Extensions;

/**
 * Static extension with additional helpers for `ceramic.Mesh`
 */
class MeshExtensions {

    /**
     * Generate vertices, indices and uvs on the given mesh to make it form a quad
     * @param mesh The mesh to work with
     * @param width With of the quad to form
     * @param height Height of the quad to form
     * @param floatsPerVertex
     *          (optional) Number of floats per vertex
     *          Set to 2 for regular quad, 6 for quads with dark color, must be 2 or higher.
     *          If not provided, will resolve the value from `mesh.customFloatAttributesSize`
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
     * Assign a dark color to the given mesh.
     * The mesh is expected to have 6 floats per vertex
     * and 4 last vertices will be used for color values.
     * @param mesh The mesh to work with
     * @param darkColor The dark color to assign
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
     * Assign a dark color (with alpha included) to the given mesh.
     * The mesh is expected to have 6 floats per vertex
     * and 4 last vertices will be used for color values.
     * @param mesh The mesh to work with
     * @param darkColor The dark color to assign
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
     * Generate vertices and indices to draw arc, pie, ring or disc geometry
     * @param mesh The mesh to work with
     * @param radius Radius of the arc
     * @param angle Angle (from 0 to 360). 360 will make it draw a full circle/ring
     * @param thickness Thickness of the arc. If same value as radius and borderPosition is `INSIDE`, will draw a pie.
     * @param sides Number of sides. Higher is smoother but needs more vertices
     * @param borderPosition Position of the drawn border
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
     * Create vertices to form a grid with the given options
     * @param mesh The mesh to work with
     * @param columns The number of columns in the grid
     * @param rows The number of rows in the grid
     * @param width The total width of the grid
     * @param height The total height of the grid
     * @param staggerX (optional, default 0) A stagger value to offset rows by this value
     * @param staggerY (optional, default 0) A stagger value to offset columns by this value
     * @param attrLength (optional, default 0) The number of attribute values per vertex
     * @param attrValues (optional) The attributes buffer that will be added to vertex data
     */
    public static function createVerticesGrid(mesh:Mesh, columns:Int, rows:Int, width:Float, height:Float, staggerX:Float = 0, staggerY:Float = 0, attrLength:Int = 0, ?attrValues:Array<Float>):Void {
        mesh.vertices = MeshUtils.createVerticesGrid(mesh.vertices, columns, rows, width, height, staggerX, staggerY, attrLength, attrValues);
    }

    /**
     * Create indices to form a grid with the given options
     * @param mesh The mesh to work with
     * @param columns The number of columns in the grid
     * @param rows The number of rows in the grid
     * @param mirrorX (optional, default false) Mirror triangles horizontally in odd columns
     * @param mirrorY (optional, default false) Mirror triangles vertically in odd rows
     * @param mirrorFlip (optional, default false) Invert the mirroring described by `mirrorX` and `mirrorY`
     */
    public static function createIndicesGrid(mesh:Mesh, columns:Int, rows:Int, mirrorX:Bool = false, mirrorY:Bool = false, mirrorFlip:Bool = false):Void {
        mesh.indices = MeshUtils.createIndicesGrid(mesh.indices, columns, rows, mirrorX, mirrorY, mirrorFlip);
    }

    /**
     * Create uvs to match a grid with the given options.
     * The uvs will be distributed linearly across the mesh so that
     * when displaying a texture it would be stretched to the grid.
     * @param mesh The mesh to work with
     * @param columns The number of columns in the grid
     * @param rows The number of rows in the grid
     */
    public static function createUVsGrid(mesh:Mesh, columns:Int, rows:Int, offsetX:Float = 0, offsetY:Float = 0):Void {
        mesh.uvs = MeshUtils.createUVsGrid(mesh.uvs, columns, rows, offsetX, offsetY);
    }

}