package ceramic;

import ceramic.Assert.*;
import ceramic.GeometryUtils;

using ceramic.Extensions;

/**
 * Draw anything composed of triangles/vertices.
 */
@editable({
    highlight: {
        points: 'vertices'
    },
    helpers: [{
        name: 'Grid',
        method: 'grid',
        params: [{
            name: 'Columns',
            type: 'Int',
            value: 1,
            slider: [1, 64]
        }, {
            name: 'Rows',
            type: 'Int',
            value: 1,
            slider: [1, 64]
        }]
    },{
        name: 'Grid From Texture',
        method: 'gridFromTexture',
        params: [{
            name: 'Columns',
            type: 'Int',
            value: 1,
            slider: [1, 64]
        }, {
            name: 'Rows',
            type: 'Int',
            value: 1,
            slider: [1, 64]
        }]
    }]
})
@:allow(ceramic.MeshPool)
class Mesh extends Visual {

/// Internal

    static var _matrix:Transform = Visual._matrix;

/// Settings

    public var colorMapping:MeshColorMapping = MeshColorMapping.MESH;

    /**
     * The number of floats to add to fill float attributes in vertices array.
     * Default is zero: no custom attributes. Update this value when using shaders with custom attributes.
     */
    public var customFloatAttributesSize:Int = 0;

    /**
     * When set to `true` hit test on this mesh will be performed at vertices level instead
     * of simply using bounds. This make the test substancially more expensive however.
     * Use only when needed.
     */
    @editable
    public var complexHit:Bool = false;

/// Lifecycle

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
     * On `Mesh` instances, can be used instead of colors array when the mesh is only composed of a single color.
     */
    @editable
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
     * An array of floats where each pair of numbers is treated as a coordinate location (x,y)
     */
    @editable
    public var vertices:Array<Float> = [];

    /**
     * An array of integers or indexes, where every three indexes define a triangle.
     */
    @editable
    public var indices:Array<Int> = [];

    /**
     * An array of colors for each vertex.
     * Each color is stored in a single `AlphaColor`(`Int`) value.
     */
    public var colors:Array<AlphaColor> = [];

    /**
     * An array of colors for each vertex stored are four float32 values for each color.
     * Generally not needed unless you need extra precision for each color value.
     * If provided (not `null`), it will be used instead of `colors`.
     * When using `floatColors` instead of `colors`, no additional operation
     * related to premultiplied alpha will be done on the CPU.
     */
    public var floatColors:Float32Array = null;

/// Texture

    /**
     * The texture used on the mesh (optional)
     */
    @editable
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
     * An array of normalized coordinates used to apply texture mapping.
     * Required if the texture is set.
     */
    @editable
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

    override function hitTest(x:Float, y:Float, matrix:Transform):Bool {

        if (complexHit #if editor || edited #end) {
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
     * Compute width and height from vertices
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

#if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('width', 100);
        entityData.props.set('height', 100);
        entityData.props.set('vertices', [
            0.0, 0.0,
            100.0, 0.0,
            100.0, 100.0,
            0.0, 100.0
        ]);
        entityData.props.set('indices', [
            0, 1, 3,
            1, 2, 3
        ]);
        entityData.props.set('uvs', [
            0.0, 0.0,
            1.0, 0.0,
            1.0, 1.0,
            0.0, 1.0
        ]);

    }

#end

}
