package ceramic;

import ceramic.GeometryUtils;
import ceramic.Assert.*;

using ceramic.Extensions;

/** Draw anything composed of triangles/vertices. */
@:allow(ceramic.MeshPool)
class Mesh extends Visual {

/// Internal

    static var _matrix:Transform = Visual._matrix;

/// Settings

    public var colorMapping:MeshColorMapping = MeshColorMapping.MESH;

    public var primitiveType:MeshPrimitiveType = MeshPrimitiveType.TRIANGLE;

    /** When set to `true` hit test on this mesh will be performed at vertices level instead
        of simply using bounds. This make the test substancially more expensive however.
        Use only when needed. */
    public var complexHit:Bool = false;

/// Lifecycle

    public function new() {

        super();

        mesh = this;

    } //new

    override function destroy() {

        // Will update texture asset retain count accordingly
        texture = null;

    } //destroy

/// Color

    /** Can be used instead of colors array when the mesh is only composed of a single color. */
    public var color(get,set):Color;
    inline function get_color():Color {
        if (colors == null || colors.length == 0) return 0;
        return colors[0].color;
    }
    inline function set_color(color:Color):Color {
        if (colors == null) colors = [];
        if (colors.length == 0) colors.push(new AlphaColor(color, 255));
        else colors[0] = new AlphaColor(color, 255);
        return color;
    }

/// Vertices

    /** An array of floats where each pair of numbers is treated as a coordinate location (x,y) */
    public var vertices:Array<Float> = [];

    /** An array of integers or indexes, where every three indexes define a triangle. */
    public var indices:Array<Int> = [];

    /** An array of colors for each vertex. */
    public var colors:Array<AlphaColor> = [];

/// Texture

    /** The texture used on the mesh (optional) */
    public var texture(default,set):Texture = null;
    #if !debug inline #end function set_texture(texture:Texture):Texture {
        if (this.texture == texture) return texture;

        assert(texture == null || !texture.destroyed, 'Cannot assign destroyed texture: ' + texture);

        // Unbind previous texture destroy event
        if (this.texture != null) {
            this.texture.offDestroy(textureDestroyed);
            if (this.texture.asset != null) this.texture.asset.release();
        }

        this.texture = texture;

        // Update frame
        if (this.texture != null) {
            // Ensure we remove the texture if it gets destroyed
            this.texture.onDestroy(this, textureDestroyed);
            if (this.texture.asset != null) this.texture.asset.retain();
        }

        return texture;
    }

    /** An array of normalized coordinates used to apply texture mapping.
        Required if the texture is set. */
    public var uvs:Array<Float> = [];

/// Texture destroyed

    function textureDestroyed() {

        // Remove texture because it has been destroyed
        this.texture = null;

    } //textureDestroyed

/// Overrides

    override function hits(x:Float, y:Float):Bool {

        if (complexHit) {

            // A visuals that renders to texture never hits
            if (renderTargetDirty) computeRenderTarget();
            if (computedRenderTarget != null) return false;

            if (matrixDirty) {
                computeMatrix();
            }

            _matrix.identity();
            // Apply whole visual transform
            _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
            // But remove screen transform from it
            _matrix.concat(ceramic.App.app.screen.reverseMatrix);
            _matrix.invert();

            // Convert x and y coordinate
            var testX = _matrix.transformX(x, y);
            var testY = _matrix.transformY(x, y);

            // Test every triangle to see if our point hits one of these
            var i = 0;
            var j = 0;
            var k:Int;
            var numTriangles = indices.length / 3;
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

                k = na * 2;
                ax = vertices.unsafeGet(k);
                k++;
                ay = vertices.unsafeGet(k);

                k = nb * 2;
                bx = vertices.unsafeGet(k);
                k++;
                by = vertices.unsafeGet(k);

                k = nc * 2;
                cx = vertices.unsafeGet(k);
                k++;
                cy = vertices.unsafeGet(k);
                
                if (GeometryUtils.pointInTriangle(
                    testX, testY,
                    ax, ay, bx, by, cx, cy
                )) {
                    // Yes, it does!
                    return true;
                }

                i++;
            }

            // Nope, it didn't
            return false;
        }
        else {

            // Perform regular bounds-based hit test
            return super.hits(x, y);
        }

    } //hits

} //Mesh
