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


}