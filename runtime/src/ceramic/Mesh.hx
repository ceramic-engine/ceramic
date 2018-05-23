package ceramic;

import ceramic.Assert.*;

/** Draw anything composed of triangles/vertices. */
class Mesh extends Visual {

/// Settings

    public var colorMapping:MeshColorMapping = MeshColorMapping.MESH;

    public var primitiveType:MeshPrimitiveType = MeshPrimitiveType.TRIANGLE;

/// Lifecycle

    public function new() {

        super();

        mesh = this;

    } //new

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

} //Mesh
