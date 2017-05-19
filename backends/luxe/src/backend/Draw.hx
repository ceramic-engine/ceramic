package backend;

#if cpp
using cpp.NativeArray;
#end

enum VisualItem {
    None;
    Quad;
    Mesh;
    Graphics;
}

@:allow(backend.Backend)
class Draw implements spec.Draw {

/// Internal

    var quadPool:Array<phoenix.geometry.QuadGeometry> = [];
    var quadPoolLength:Int = 0;
    var prevQuadBatchIndex:Int = 0;
    var quadBatchIndex:Int = 0;

    inline function begin():Void {

        prevQuadBatchIndex = quadBatchIndex;
        quadBatchIndex = 0;

    } //begin

    inline function end():Void {

        // Remove unused geometries (if needed)
        //
        var i = quadBatchIndex;
        while (i < quadPool.length) {

            var geom = #if cpp quadPool.unsafeGet(i) #else quadPool[i] #end;
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
            return Quad;
        }
        else if (Std.is(visual, ceramic.Graphics)) {
            return Graphics;
        }
        else if (Std.is(visual, ceramic.Mesh)) {
            return Mesh;
        }
        else {
            return None;
        }

    } //getItem

    public function draw(visuals:Array<ceramic.Visual>):Void {

        var quad:ceramic.Quad;
        var quadGeom:phoenix.geometry.QuadGeometry;
        var rect = new luxe.Rectangle();

        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;

        var w:Float;
        var h:Float;

        var depth:Float = 1;

        var m:phoenix.Matrix;

        var v:Array<phoenix.geometry.Vertex>;

        // Draw visuals
        for (visual in visuals) {

            if (!visual.computedVisible) continue;

            switch (visual.backendItem) {
                
                case Quad:
                    quad = cast visual;

                    // Get or create quad geometry
                    //
                    if (quadBatchIndex < quadPoolLength) {

                        quadGeom = #if cpp quadPool.unsafeGet(quadBatchIndex) #else quadPool[quadBatchIndex] #end;

                    }
                    else {

                        quadGeom = new phoenix.geometry.QuadGeometry({});
                        quadPool.push(quadGeom);
                        quadPoolLength++;

                        Luxe.renderer.batcher.add(quadGeom);

                    }
                    quadBatchIndex++;

                    // Update geometry values
                    //
                    w = quad.width / quad.scaleX;
                    h = quad.height / quad.scaleY;
                    
                    v = quadGeom.vertices;

                    //tl
                    v[0].pos.set_xy(0.0, 0.0);
                    //tr
                    v[1].pos.set_xy(w  , 0.0);
                    //br
                    v[2].pos.set_xy(w  , h  );
                    //bl
                    v[3].pos.set_xy(0.0, h  );
                    //tl
                    v[4].pos.set_xy(0.0, 0.0);
                    //br
                    v[5].pos.set_xy(w  , h  );
                    

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
                        rect.set(
                            quad.frameX * quad.texture.density,
                            quad.frameY * quad.texture.density,
                            quad.frameWidth * quad.texture.density,
                            quad.frameHeight * quad.texture.density
                        );
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
                    

                default:
            }

        }

    }

} //Draw
