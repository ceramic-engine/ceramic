package backend;

import ceramic.RotateFrame;

using ceramic.Extensions;

enum VisualItem {
    NONE;
    QUAD;
    MESH;
}

@:allow(backend.Backend)
class Draw implements spec.Draw {

/// Internal

    var quadPool:Array<phoenix.geometry.QuadGeometry> = [];
    var quadPoolLength:Int = 0;
    var prevQuadPoolIndex:Int = 0;
    var quadPoolIndex:Int = 0;

    var meshPool:Array<phoenix.geometry.Geometry> = [];

    inline function begin():Void {

        prevQuadPoolIndex = quadPoolIndex;
        quadPoolIndex = 0;

        // TODO remove
        for (geom in meshPool) {
            Luxe.renderer.batcher.remove(geom);
        }
        meshPool = [];

    } //begin

    inline function end():Void {

        // Remove unused geometries (if needed)
        //
        var i = quadPoolIndex;
        while (i < quadPool.length) {

            var geom = quadPool.unsafeGet(i);
            i++;

            Luxe.renderer.batcher.remove(geom);

        }

    } //end

/// Public API

    public function new() {}

    inline public function getItem(visual:ceramic.Visual):VisualItem {

        // The backend decides how each visual should be drawn.
        // Instead of checking instance type at each draw iteration,
        // The backend provides/computes a VisualItem object when
        // a visual is instanciated that it can later re-use
        // at each draw iteration to read/store per visual data.

        if (Std.is(visual, ceramic.Quad)) {
            return QUAD;
        }
        else if (Std.is(visual, ceramic.Mesh)) {
            return MESH;
        }
        else {
            return NONE;
        }

    } //getItem

    public function draw(visuals:Array<ceramic.Visual>):Void {

        var quad:ceramic.Quad;
        var quadGeom:phoenix.geometry.QuadGeometry;
        var rect = new luxe.Rectangle();

        var mesh:ceramic.Mesh;
        var meshGeom:phoenix.geometry.Geometry;
        var color:ceramic.AlphaColor;
        var vertex:phoenix.geometry.Vertex;

        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;

        var x:Float;
        var y:Float;
        var uvx:Float;
        var uvy:Float;

        var w:Float;
        var h:Float;

        var len:Int;
        var i:Int;
        var j:Int;

        var depth:Float = 1;

        var m:phoenix.Matrix;

        var v:Array<phoenix.geometry.Vertex>;

        // Draw visuals
        for (visual in visuals) {

            if (!visual.computedVisible) continue;

            switch (visual.backendItem) {
                
                case QUAD:
                    quad = cast visual;

                    // Get or create quad geometry
                    //
                    if (quadPoolIndex < quadPoolLength) {

                        quadGeom = quadPool.unsafeGet(quadPoolIndex);

                    }
                    else {

                        quadGeom = new phoenix.geometry.QuadGeometry({});
                        quadPool.push(quadGeom);
                        quadPoolLength++;

                        Luxe.renderer.batcher.add(quadGeom);

                    }
                    quadPoolIndex++;

                    // Update geometry values
                    //
                    if (quad.rotateFrame == RotateFrame.ROTATE_90) {
                        w = quad.height / quad.scaleY;
                        h = quad.width / quad.scaleX;
                    } else {
                        w = quad.width / quad.scaleX;
                        h = quad.height / quad.scaleY;
                    }
                    
                    v = quadGeom.vertices;

                    //tl
                    v.unsafeGet(0).pos.set_xy(0.0, 0.0);
                    //tr
                    v.unsafeGet(1).pos.set_xy(w  , 0.0);
                    //br
                    v.unsafeGet(2).pos.set_xy(w  , h  );
                    //bl
                    v.unsafeGet(3).pos.set_xy(0.0, h  );
                    //tl
                    v.unsafeGet(4).pos.set_xy(0.0, 0.0);
                    //br
                    v.unsafeGet(5).pos.set_xy(w  , h  );
                    

                    // Update color
                    //
                    r = quad.color.redFloat;
                    g = quad.color.greenFloat;
                    b = quad.color.blueFloat;
                    a = quad.computedAlpha;

                    // Multiply alpha because we render premultiplied
                    r *= a;
                    g *= a;
                    b *= a;

                    quadGeom.color.r = r;
                    quadGeom.color.g = g;
                    quadGeom.color.b = b;
                    quadGeom.color.a = a;

                    quadGeom.depth = depth;
                    depth += 0.01;

                    // Update blending
                    //
                    if (quad.blending == ceramic.Blending.ADD) {
                        quadGeom.blend_src_alpha = phoenix.Batcher.BlendMode.one;
                        quadGeom.blend_src_rgb = phoenix.Batcher.BlendMode.one;
                        quadGeom.blend_dest_alpha = phoenix.Batcher.BlendMode.one;
                        quadGeom.blend_dest_rgb = phoenix.Batcher.BlendMode.one;
                    }
                    else {
                        quadGeom.blend_src_alpha = phoenix.Batcher.BlendMode.one;
                        quadGeom.blend_src_rgb = phoenix.Batcher.BlendMode.one;
                        quadGeom.blend_dest_alpha = phoenix.Batcher.BlendMode.one_minus_src_alpha;
                        quadGeom.blend_dest_rgb = phoenix.Batcher.BlendMode.one_minus_src_alpha;
                    }

                    // Update texture
                    //
                    if (quad.texture != null) {
                        quadGeom.texture = quad.texture.backendItem;
                        if (quad.rotateFrame == RotateFrame.ROTATE_90) {
                            rect.set(
                                quad.frameX * quad.texture.density,
                                quad.frameY * quad.texture.density,
                                quad.frameHeight * quad.texture.density,
                                quad.frameWidth * quad.texture.density
                            );
                        } else {
                            rect.set(
                                quad.frameX * quad.texture.density,
                                quad.frameY * quad.texture.density,
                                quad.frameWidth * quad.texture.density,
                                quad.frameHeight * quad.texture.density
                            );
                        }
                        quadGeom.uv(rect);
                    }
                    else {
                        quadGeom.texture = null;
                    }

                    // Update transform
                    //
                    quadGeom.transform.dirty = false;
                    quadGeom.transform.manual_update = true;
                    m = quadGeom.transform.world.matrix;

                    m.M11 = quad.a;
                    m.M12 = quad.c;
                    m.M14 = quad.tx;
                    m.M21 = quad.b;
                    m.M22 = quad.d;
                    m.M24 = quad.ty;
                
                case MESH:
                    mesh = cast visual;

                    meshGeom = new phoenix.geometry.Geometry({
                        primitive_type: phoenix.Batcher.PrimitiveType.triangles
                    });
                    meshPool.push(meshGeom);

                    Luxe.renderer.batcher.add(meshGeom);

                    meshGeom.depth = depth;
                    depth += 0.01;

                    // Update blending
                    //
                    if (mesh.blending == ceramic.Blending.ADD) {
                        meshGeom.blend_src_alpha = phoenix.Batcher.BlendMode.one;
                        meshGeom.blend_src_rgb = phoenix.Batcher.BlendMode.one;
                        meshGeom.blend_dest_alpha = phoenix.Batcher.BlendMode.one;
                        meshGeom.blend_dest_rgb = phoenix.Batcher.BlendMode.one;
                    }
                    else {
                        meshGeom.blend_src_alpha = phoenix.Batcher.BlendMode.one;
                        meshGeom.blend_src_rgb = phoenix.Batcher.BlendMode.one;
                        meshGeom.blend_dest_alpha = phoenix.Batcher.BlendMode.one_minus_src_alpha;
                        meshGeom.blend_dest_rgb = phoenix.Batcher.BlendMode.one_minus_src_alpha;
                    }

                    var indices = mesh.indices;
                    var vertices = mesh.vertices;
                    var colors = mesh.colors;
                    var texture = mesh.texture;
                    var uvs = mesh.uvs;
                    var uvFactorX:Float = 1;
                    var uvFactorY:Float = 1;

                    // Set texture
                    if (texture != null) {
                        meshGeom.texture = texture.backendItem;

                        // Ensure uv takes in account real texture size
                        uvFactorX = meshGeom.texture.width / meshGeom.texture.width_actual;
                        uvFactorY = meshGeom.texture.height / meshGeom.texture.height_actual;
                    }

                    len = indices.length;
                    i = 0;
                    while (i < len) {

                        j = indices.unsafeGet(i);
                        x = vertices.unsafeGet(j * 2);
                        y = vertices.unsafeGet(j * 2 + 1);
                        color = colors.unsafeGet(j);

                        // Update color
                        r = color.redFloat;
                        g = color.greenFloat;
                        b = color.blueFloat;
                        a = mesh.computedAlpha * color.alphaFloat;

                        // Multiply alpha because we render premultiplied
                        r *= a;
                        g *= a;
                        b *= a;

                        // Set vertex info
                        // TODO pool
                        vertex = new phoenix.geometry.Vertex(new phoenix.Vector());

                        vertex.pos.set_xy(x, y);
                        vertex.color.set(r, g, b, a);
                        
                        if (texture != null) {
                            uvx = uvs.unsafeGet(j) * uvFactorX;
                            uvy = uvs.unsafeGet(j * 2) * uvFactorY;
                        } else {
                            uvx = 0;
                            uvy = 0;
                        }
                        
                        vertex.uv.uv0.set_uv(uvx, uvy);

                        // Add vertex
                        meshGeom.vertices.push(vertex);

                        i++;
                    }

                    // Update transform
                    //
                    meshGeom.transform.dirty = false;
                    meshGeom.transform.manual_update = true;
                    m = meshGeom.transform.world.matrix;

                    m.M11 = mesh.a;
                    m.M12 = mesh.c;
                    m.M14 = mesh.tx;
                    m.M21 = mesh.b;
                    m.M22 = mesh.d;
                    m.M24 = mesh.ty;

                default:
            }

        }

    }

} //Draw
