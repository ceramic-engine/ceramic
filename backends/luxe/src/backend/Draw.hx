package backend;

#if cpp
using cpp.NativeArray;
#end

@:enum abstract DrawKind(Int) from Int to Int {
    var None = 0;
    var Quad = 1;
    var Mesh = 2;
    var Text = 3;
    var Graphics = 4;
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

    inline public function drawKind(visual:ceramic.Visual):DrawKind {

        // The backend decides how each visual should be drawn.
        // Instead of checking instance type at each draw iteration,
        // The backend provides/computes a DrawKind int value when
        // a visual is instanciated that it can later re-use
        // at each draw iteration.

        if (Std.is(visual, ceramic.Quad)) {
            return DrawKind.Quad;
        }
        else if (Std.is(visual, ceramic.Text)) {
            return DrawKind.Text;
        }
        else if (Std.is(visual, ceramic.Graphics)) {
            return DrawKind.Graphics;
        }
        else if (Std.is(visual, ceramic.Mesh)) {
            return DrawKind.Mesh;
        }
        else {
            return DrawKind.None;
        }

    } //drawKind

    public function draw(visuals:Array<ceramic.Visual>):Void {

        var quad:ceramic.Quad;
        var quadGeom:phoenix.geometry.QuadGeometry;

        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;

        var w:Float;
        var h:Float;

        var m:phoenix.Matrix;

        var v:Array<phoenix.geometry.Vertex>;

        // Draw visuals
        for (visual in visuals) {

            if (!visual.computedVisible) continue;

            switch (visual.drawKind) {
                
                case DrawKind.Quad:
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

                    r = quad.color.redFloat;
                    g = quad.color.greenFloat;
                    b = quad.color.blueFloat;
                    a = quad.computedAlpha;

                    quadGeom.color.r = r;
                    quadGeom.color.g = g;
                    quadGeom.color.b = b;
                    quadGeom.color.a = a;

                    quadGeom.depth = quad.z;

                    m = quadGeom.transform.world.matrix;

                    m.M11 = quad.a;
                    m.M12 = quad.c;
                    m.M14 = quad.tx;
                    m.M21 = quad.b;
                    m.M22 = quad.d;
                    m.M24 = quad.ty;

                    quadGeom.transform.dirty = false;


                case DrawKind.Text:

                case DrawKind.Graphics:

                case DrawKind.Mesh:

                default:
            }

        }

    }

} //Draw
