package ceramic;

using ceramic.Extensions;

class MeshUtils {

    /**
     * Create vertices to form a grid with the given options
     * @param vertices (optional) The existing vertices. If provided, will be used as result instead of creating a new array
     * @param columns The number of columns in the grid
     * @param rows The number of rows in the grid
     * @param width The total width of the grid
     * @param height The total height of the grid
     * @param staggerX (optional, default 0) A stagger value to offset rows by this value
     * @param staggerY (optional, default 0) A stagger value to offset columns by this value
     * @param attrLength (optional, default 0) The number of attribute values per vertex
     * @param attrValues (optional) The attributes buffer that will be added to vertex data
     * @return The generated vertices
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
     * Create indices to form a grid with the given options
     * @param indices (optional) The existing indices. If provided, will be used as result instead of creating a new array
     * @param columns The number of columns in the grid
     * @param rows The number of rows in the grid
     * @param mirrorX (optional, default false) Mirror triangles horizontally in odd columns
     * @param mirrorY (optional, default false) Mirror triangles vertically in odd rows
     * @param mirrorFlip (optional, default false) Invert the mirroring described by `mirrorX` and `mirrorY`
     * @return The generated indices
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
     * Create uvs to match a grid with the given options.
     * The uvs will be distributed linearly across the mesh so that
     * when displaying a texture it would be stretched to the grid.
     * @param uvs (optional) The existing uvs. If provided, will be used as result instead of creating a new array
     * @param columns The number of columns in the grid
     * @param rows The number of rows in the grid
     * @return The generated uvs
     */
    public static function createUVsGrid(?uvs:Array<Float>, columns:Int, rows:Int):Array<Float> {

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

                var uvX:Float = x / columns;
                var uvY:Float = y / rows;

                uvs[index++] = uvX;
                uvs[index++] = uvY;
            }
        }

        return uvs;

    }

}
