package ceramic;

import ceramic.Assert.*;
import ceramic.GeometryUtils;

using ceramic.Extensions;

/**
 * A flexible visual for drawing custom shapes composed of triangles.
 *
 * Mesh allows you to create complex 2D geometry by defining vertices (points),
 * indices (triangles), and optional attributes like colors and texture coordinates.
 * This is the foundation for advanced visuals like deformable sprites, particle
 * systems, and custom shape rendering.
 *
 * Features:
 * - Custom vertex positions for any shape
 * - Per-vertex coloring with color interpolation
 * - Texture mapping with UV coordinates
 * - Custom shader attributes support
 * - Complex hit testing at triangle level
 * - Optimized rendering through batching
 *
 * The mesh is defined by:
 * - `vertices`: Array of x,y coordinates for each vertex
 * - `indices`: Array defining triangles (every 3 indices form a triangle)
 * - `colors`: Optional per-vertex colors
 * - `uvs`: Texture coordinates when using a texture
 *
 * ```haxe
 * // Create a colored triangle
 * var mesh = new Mesh();
 * mesh.vertices = [
 *     100, 100,  // Vertex 0
 *     200, 100,  // Vertex 1
 *     150, 200   // Vertex 2
 * ];
 * mesh.indices = [0, 1, 2];
 * mesh.colors = [
 *     Color.RED,
 *     Color.GREEN,
 *     Color.BLUE
 * ];
 *
 * // Create a textured quad
 * var mesh = new Mesh();
 * mesh.color = Color.WHITE; // Use fill color instead of explicit colors array
 * mesh.texture = assets.texture('image');
 * mesh.vertices = [
 *     0, 0,      // Top-left
 *     100, 0,    // Top-right
 *     100, 100,  // Bottom-right
 *     0, 100     // Bottom-left
 * ];
 * mesh.indices = [
 *     0, 1, 2,   // First triangle
 *     0, 2, 3    // Second triangle
 * ];
 * mesh.uvs = [
 *     0, 0,      // Top-left UV
 *     1, 0,      // Top-right UV
 *     1, 1,      // Bottom-right UV
 *     0, 1       // Bottom-left UV
 * ];
 * ```
 *
 * @see Visual
 * @see Quad
 * @see MeshPool
 */
@:allow(ceramic.MeshPool)
class Mesh extends Visual {

/// Internal

    static var _matrix:Transform = Visual._matrix;

/// Settings

    /**
     * Defines how colors are applied to the mesh.
     * - MESH: Use the mesh's color array
     * - TEXTURE: Use texture colors only
     * - VERTICES: Multiply vertex colors with texture
     */
    public var colorMapping:MeshColorMapping = MeshColorMapping.MESH;

    /**
     * The number of additional float values per vertex for custom shader attributes.
     * Default is 0 (only x,y coordinates). Set this when using shaders that require
     * extra per-vertex data like secondary UVs, vertex weights, etc.
     * The total floats per vertex becomes: 2 + customFloatAttributesSize
     */
    public var customFloatAttributesSize:Int = 0;

    /**
     * When set to `true`, hit testing checks individual triangles instead of just bounds.
     * This provides accurate hit detection for complex shapes but is more expensive.
     * Use only when you need precise interaction with non-rectangular meshes.
     * Default is false (uses bounding box).
     */
    public var complexHit:Bool = false;

/// Lifecycle

    /**
     * Create a new Mesh.
     * The mesh starts empty - you must set vertices, indices, and other
     * properties before it will render anything.
     */
    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        asMesh = this;

    }

    override function destroy() {

        // Will update texture asset retain count and render target dependencies accordingly
        texture = null;

        super.destroy();

    }

/// Color

    /**
     * Convenience property for setting a single color for the entire mesh.
     * When set, updates the colors array with this color for all vertices.
     * When getting, returns the first vertex color or WHITE if no colors are set.
     * For multi-colored meshes, use the colors array directly.
     */
    public var color(get,set):Color;
    function get_color():Color {
        return if (floatColors != null && floatColors.length >= 3) {
            Color.fromRGBFloat(floatColors[0], floatColors[1], floatColors[2]);
        }
        else if (colors != null && colors.length > 0) {
            colors[0].color;
        }
        else {
            Color.WHITE;
        }

    }
    function set_color(color:Color):Color {
        if (floatColors != null) {
            floatColors[0] = color.redFloat;
            floatColors[1] = color.greenFloat;
            floatColors[2] = color.blueFloat;
            floatColors[3] = 1.0;
        }
        else {
            if (colors == null) colors = [];
            colors[0] = new AlphaColor(color, 255);
        }
        return color;
    }

/// Vertices

    /**
     * An array of vertex positions as alternating x,y coordinates.
     * Each vertex requires 2 floats (or 2 + customFloatAttributesSize if using custom attributes).
     * Example: [x0, y0, x1, y1, x2, y2, ...]
     * These define the shape of your mesh.
     */
    public var vertices:Array<Float> = [];

    /**
     * An array of vertex indices defining triangles.
     * Every 3 consecutive indices form one triangle.
     * Indices refer to positions in the vertices array (0-based).
     * Example: [0, 1, 2, 0, 2, 3] defines two triangles sharing vertices 0 and 2.
     */
    public var indices:Array<Int> = [];

    /**
     * An array of colors for each vertex.
     * Colors are interpolated across triangles for smooth gradients.
     * Each color includes alpha channel for transparency.
     * Array length should match the number of vertices.
     */
    public var colors:Array<AlphaColor> = [];

    /**
     * High-precision color array using 4 floats per color (RGBA).
     * Use this instead of `colors` when you need:
     * - Extra color precision beyond 8-bit per channel
     * - To avoid CPU premultiplication of alpha
     * - HDR color values
     * Format: [r0, g0, b0, a0, r1, g1, b1, a1, ...]
     * If set, this is used instead of the `colors` array.
     */
    public var floatColors:Float32Array = null;

/// Texture

    /**
     * The texture to apply to this mesh.
     * When set, you must also provide UV coordinates in the `uvs` array.
     * The texture's asset reference count is automatically managed.
     * Set to null for untextured meshes.
     */
    public var texture(default,set):Texture = null;
    #if !debug inline #end function set_texture(texture:Texture):Texture {
        if (this.texture == texture) return texture;

        assert(texture == null || !texture.destroyed, 'Cannot assign destroyed texture: ' + texture);

        if (this.texture != null) {
            // Unbind previous texture destroy event
            this.texture.offDestroy(textureDestroyed);
            if (this.texture.asset != null) this.texture.asset.release();

            /*// Remove render target texture dependency, if any
            if (this.texture != null && this.texture.isRenderTexture) {
                if (renderTargetDirty) {
                    computeRenderTarget();
                }
                if (computedRenderTarget != null) {
                    computedRenderTarget.decrementDependingTextureCount(this.texture);
                }
            }*/
        }

        /*// Add new render target texture dependency, if needed
        if (texture != null && texture.isRenderTexture) {
            if (renderTargetDirty) {
                computeRenderTarget();
            }
            if (computeRenderTarget != null) {
                computedRenderTarget.incrementDependingTextureCount(texture);
            }
        }*/

        this.texture = texture;

        // Update frame
        if (this.texture != null) {
            // Ensure we remove the texture if it gets destroyed
            this.texture.onDestroy(this, textureDestroyed);
            if (this.texture.asset != null) this.texture.asset.retain();
        }

        return texture;
    }

    /**
     * Texture coordinates for each vertex, ranging from 0.0 to 1.0.
     * Required when using a texture. Array format: [u0, v0, u1, v1, ...]
     * - (0,0) = top-left of texture
     * - (1,1) = bottom-right of texture
     * Values outside 0-1 range will wrap or clamp based on texture settings.
     */
    public var uvs:Array<Float> = [];

    #if ceramic_wireframe
    @:noCompletion
    @:allow(ceramic.Renderer)
    private var wireframeIndices:Array<Int> = null;

    @:noCompletion
    @:allow(ceramic.Renderer)
    private var wireframeColors:Array<AlphaColor> = null;
    #end

/// Texture destroyed

    function textureDestroyed(_) {

        // Remove texture because it has been destroyed
        this.texture = null;

    }

/// Overrides

    /**
     * Test if a point hits this mesh.
     * If complexHit is true, tests against individual triangles for accuracy.
     * Otherwise uses the bounding box for performance.
     * @param x X coordinate to test
     * @param y Y coordinate to test
     * @param matrix Transform matrix for coordinate conversion
     * @return True if the point hits the mesh
     */
    override function hitTest(x:Float, y:Float, matrix:Transform):Bool {

        if (complexHit) {
            // Convert x and y coordinate
            var testX = matrix.transformX(x, y);
            var testY = matrix.transformY(x, y);
            var floatsPerVertex = 2 + customFloatAttributesSize;

            // Test every triangle to see if our point hits one of these
            var i = 0;
            var j = 0;
            var k:Int;
            var numTriangles = Std.int(indices.length / 3);
            var na:Int;
            var nb:Int;
            var nc:Int;
            var ax:Float;
            var ay:Float;
            var bx:Float;
            var by:Float;
            var cx:Float;
            var cy:Float;
            while (i < numTriangles) {

                na = indices.unsafeGet(j);
                j++;
                nb = indices.unsafeGet(j);
                j++;
                nc = indices.unsafeGet(j);
                j++;

                k = na * floatsPerVertex;
                ax = vertices.unsafeGet(k);
                k++;
                ay = vertices.unsafeGet(k);

                k = nb * floatsPerVertex;
                bx = vertices.unsafeGet(k);
                k++;
                by = vertices.unsafeGet(k);

                k = nc * floatsPerVertex;
                cx = vertices.unsafeGet(k);
                k++;
                cy = vertices.unsafeGet(k);

                if (inline GeometryUtils.pointInTriangle(
                    testX, testY,
                    ax, ay, bx, by, cx, cy
                )) {
                    // Yes, it does!
                    return true;
                }

                i++;
            }

            return false;
        }
        else {
            return super.hitTest(x, y, matrix);
        }

    }

    override function set_shader(shader:Shader):Shader {
        this.shader = shader;
        if (shader != null) {
            this.customFloatAttributesSize = shader.customFloatAttributesSize;
        }
        return shader;
    }

/// Helpers

    /**
     * Compute and set the mesh's width and height based on vertex positions.
     * Scans all vertices to find the maximum x and y coordinates.
     * Useful after modifying vertices to update the mesh bounds.
     */
    public function computeSize() {

        if (vertices != null && vertices.length >= 2) {
            var maxX:Float = 0;
            var maxY:Float = 0;
            var i = 0;
            var lenMinus1 = vertices.length - 1;
            if (customFloatAttributesSize > 0) {
                while (i < lenMinus1) {
                    var x = vertices.unsafeGet(i);
                    if (x > maxX)
                        maxX = x;
                    i++;
                    var y = vertices.unsafeGet(i);
                    if (y > maxY)
                        maxY = y;
                    i += 1 + customFloatAttributesSize;
                }
            }
            else {
                while (i < lenMinus1) {
                    var x = vertices.unsafeGet(i);
                    if (x > maxX)
                        maxX = x;
                    i++;
                    var y = vertices.unsafeGet(i);
                    if (y > maxY)
                        maxY = y;
                    i++;
                }
            }
            size(
                Math.round(maxX * 1000) / 1000,
                Math.round(maxY * 1000) / 1000
            );
        }
        else {
            size(0, 0);
        }

    }

    /**
     * Compute vertices and indices to obtain a grid with `cols` columns
     * and `rows` rows at the requested `width` and `height`.
     * @param cols The number of columnns in the grid
     * @param rows The number of rows in the grid
     * @param width The width of the grid
     * @param height The height of the grid
     */
    public function grid(cols:Int, rows:Int, width:Float = -1, height:Float = -1):Void {

        if (width == -1)
            width = _width;

        if (height == -1)
            height = _height;

        var stepX:Float = width / cols;
        var stepY:Float = height / rows;

        var v:Int = 0;
        var i:Int = 0;

        for (r in 0...rows+1) {

            var y = r * stepY;

            for (c in 0...cols+1) {

                vertices[v] = c * stepX;
                v++;
                vertices[v] = y;
                v++;

                if (r > 0 && c > 0) {

                    var n = (r - 1) * (cols + 1) + c - 1;

                    indices[i] = n;
                    i++;
                    indices[i] = n + 1;
                    i++;
                    indices[i] = n + (cols + 1);
                    i++;

                    indices[i] = n + 1;
                    i++;
                    indices[i] = n + (cols + 1);
                    i++;
                    indices[i] = n + (cols + 1) + 1;
                    i++;
                }

            }

        }

        if (vertices.length > v) {
            vertices.setArrayLength(v);
        }

        if (indices.length > i) {
            indices.setArrayLength(i);
        }

    }

    /**
     * Compute vertices, indices and uvs to obtain a grid with `cols` columns
     * and `rows` rows to fit the given texture or mesh's current texture.
     * @param cols The number of columnns in the grid
     * @param rows The number of rows in the grid
     * @param texture The texture used to generate the grid. If not provided, will use mesh's current texture
     */
    public function gridFromTexture(cols:Int, rows:Int, ?texture:Texture):Void {

        if (texture == null)
            texture = this.texture;

        grid(cols, rows, texture.width, texture.height);

        var u:Int = 0;
        var stepX:Float = 1.0 / cols;
        var stepY:Float = 1.0 / rows;

        for (r in 0...rows+1) {

            var y = r * stepY;

            uvs[u] = 0;
            u++;
            uvs[u] = y;
            u++;

            for (c in 1...cols+1) {

                uvs[u] = c * stepX;
                u++;
                uvs[u] = y;
                u++;

            }

        }

        if (uvs.length > u) {
            uvs.setArrayLength(u);
        }

    }

}
