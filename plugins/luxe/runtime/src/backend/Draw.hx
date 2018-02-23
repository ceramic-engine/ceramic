package backend;

import ceramic.RotateFrame;
import backend.Images.BatchedRenderTexture;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

/// Internal

    var quadPool:Array<phoenix.geometry.QuadGeometry> = [];
    var batchedQuadPoolLength:Int = 0;
    var quadPoolLength:Int = 0;
    var prevQuadPoolIndex:Int = 0;
    var quadPoolIndex:Int = 0;

    var meshPool:Array<phoenix.geometry.Geometry> = [];
    var batchedMeshPoolLength:Int = 0;
    var meshPoolLength:Int = 0;
    var prevMeshPoolIndex:Int = 0;
    var meshPoolIndex:Int = 0;

    var vertexPool:Array<phoenix.geometry.Vertex> = [];
    var vertexPoolLength:Int = 0;
    var vertexPoolIndex:Int = 0;

    #if !debug inline #end function begin():Void {

        prevQuadPoolIndex = quadPoolIndex;
        quadPoolIndex = 0;

        prevMeshPoolIndex = meshPoolIndex;
        meshPoolIndex = 0;

        vertexPoolIndex = 0;


    } //begin

    #if !debug inline #end function end():Void {

        // Remove unused geometries (if needed)
        //
        var i = quadPoolIndex;
        batchedQuadPoolLength = quadPoolIndex;
        while (i < quadPoolLength) {

            var geom = quadPool.unsafeGet(i);
            i++;

            if (geom.batchers.length > 0) {
                geom.batchers.unsafeGet(0).remove(geom);
            }

        }

        // Remove unused meshes (if needed)
        //
        var i = meshPoolIndex;
        batchedMeshPoolLength = meshPoolIndex;
        while (i < meshPoolLength) {

            var geom = meshPool.unsafeGet(i);
            i++;

            if (geom.batchers.length > 0) {
                geom.batchers.unsafeGet(0).remove(geom);
            }

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

        if (!Luxe.core.auto_render) return;

        var quad:ceramic.Quad;
        var quadGeom:phoenix.geometry.QuadGeometry;
        var rect = new luxe.Rectangle();
        var clippingVisual:ceramic.Visual;
        var clipRect:phoenix.Rectangle;
        var divideNativeDensity = 1.0 / ceramic.App.app.screen.nativeDensity;
        var isClipping:Bool = false;
        var clipX:Float = 0;
        var clipY:Float = 0;
        var clipW:Float = 0;
        var clipH:Float = 0;
        var clipX2:Float = 0;
        var clipY2:Float = 0;
        var clipW2:Float = 0;
        var clipH2:Float = 0;
        var intersectLeft:Float = 0;
        var intersectRight:Float = 0;
        var intersectTop:Float = 0;
        var intersectBottom:Float = 0;

        var mesh:ceramic.Mesh;
        var color:ceramic.AlphaColor = 0xFFFFFFFF;
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

        var meshGeom:phoenix.geometry.Geometry;

        // Draw visuals
        for (visual in visuals) {

            if (!visual.computedVisible) {
                continue;
            }

            switch (visual.backendItem) {
                
                case QUAD:
                    quad = cast visual;

                    if (quad.transparent) {
                        // Skip drawing
                        continue;
                    }

                    // Update geometry values
                    //
                    if (quad.rotateFrame == RotateFrame.ROTATE_90) {
                        w = quad.height;
                        h = quad.width;
                    } else {
                        w = quad.width;
                        h = quad.height;
                    }

                    // Update clipping and check if this should even be drawn
                    //
                    isClipping = false;
                    if (quad.computedClipToBounds) {
                        clippingVisual = quad.parent;
                        while (true) {
                            if (clippingVisual == null) break;
                            if (clippingVisual.clipToBounds) {
                                if (!isClipping) {
                                    // Simple clipping
                                    isClipping = true;
                                    clipX = clippingVisual.tx;
                                    clipY = clippingVisual.ty;
                                    clipW = clippingVisual.width * clippingVisual.a;
                                    clipH = clippingVisual.height * clippingVisual.d;
                                }
                                else {
                                    // Nested clipping
                                    clipX2 = clippingVisual.tx;
                                    clipY2 = clippingVisual.ty;
                                    clipW2 = clippingVisual.width * clippingVisual.a;
                                    clipH2 = clippingVisual.height * clippingVisual.d;
                                    intersectLeft = Math.max(clipX, clipX2);
                                    intersectRight = Math.min(clipX + clipW, clipX2 + clipW2);
                                    intersectTop = Math.max(clipY, clipY2);
                                    intersectBottom = Math.min(clipY + clipH, clipY2 + clipH2);
                                    if (intersectLeft <= intersectRight || intersectTop < intersectBottom) {
                                        clipX = intersectLeft;
                                        clipY = intersectTop;
                                        clipW = intersectRight - intersectLeft;
                                        clipH = intersectBottom - intersectTop;
                                    } else {
                                        clipX = 0;
                                        clipY = 0;
                                        clipW = 0;
                                        clipH = 0;
                                        break;
                                    }
                                }
                            }
                            else if (!clippingVisual.computedClipToBounds) break;
                            clippingVisual = clippingVisual.parent;
                        }
                    }

                    if (isClipping && (clipW == 0 || clipH == 0)) {
                        // Skip drawing of out of bounds clipped quad
                        continue;
                    }

                    // Get or create quad geometry
                    //
                    if (quadPoolIndex < quadPoolLength) {

                        quadGeom = quadPool.unsafeGet(quadPoolIndex);

                        // Assign custom shader (if any)
                        if (quad.shader != null) {
                            if (quadGeom.shader != quad.shader.backendItem) {
                                quadGeom.shader = quad.shader.backendItem;
                            }
                        } else if (quadGeom.shader != null) {
                            quadGeom.shader = null;
                        }

                        // Add to correct batcher
                        if (quadPoolIndex >= batchedQuadPoolLength) {
                            if (quad.computedRenderTarget != null) {
                                var renderTexture:BatchedRenderTexture = cast quad.computedRenderTarget.backendItem;
                                renderTexture.targetBatcher.add(quadGeom, true);
                            }
                            else {
                                Luxe.renderer.batcher.add(quadGeom, true);
                            }
                        }
                        // Or if already added, change the batcher if needed
                        else if (quad.computedRenderTarget != null) {
                            var renderTexture:BatchedRenderTexture = cast quad.computedRenderTarget.backendItem;
                            var prevBatcher = quadGeom.batchers.unsafeGet(0);
                            if (prevBatcher != renderTexture.targetBatcher) {
                                prevBatcher.remove(quadGeom);
                                renderTexture.targetBatcher.add(quadGeom, true);
                            }
                        }
                        else {
                            var prevBatcher = quadGeom.batchers.unsafeGet(0);
                            if (prevBatcher != Luxe.renderer.batcher) {
                                prevBatcher.remove(quadGeom);
                                Luxe.renderer.batcher.add(quadGeom, true);
                            }
                        }

                    }
                    else {

                        quadGeom = new phoenix.geometry.QuadGeometry({});
                        quadPool.push(quadGeom);
                        quadPoolLength++;

                        // Assign custom shader (if any)
                        if (quad.shader != null) {
                            quadGeom.shader = quad.shader.backendItem;
                        }

                        // Add to correct batcher
                        if (quad.computedRenderTarget != null) {
                            var renderTexture:BatchedRenderTexture = cast quad.computedRenderTarget.backendItem;
                            renderTexture.targetBatcher.add(quadGeom, true);
                        }
                        else {
                            Luxe.renderer.batcher.add(quadGeom, true);
                        }

                    }
                    quadPoolIndex++;
                    
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

                    // Update geometry clipping
                    if (isClipping) {
                        clipRect = quadGeom.clip_rect;
                        if (clipRect == null) {
                            clipRect = new phoenix.Rectangle(
                                clipX * divideNativeDensity,
                                clipY * divideNativeDensity,
                                clipW * divideNativeDensity,
                                clipH * divideNativeDensity
                            );
                        }
                        else {
                            clipRect.set(
                                clipX * divideNativeDensity,
                                clipY * divideNativeDensity,
                                clipW * divideNativeDensity,
                                clipH * divideNativeDensity
                            );
                        }
                        quadGeom.clip_rect = clipRect;
                    }
                    else {
                        quadGeom.clip = false;
                    }
                
                case MESH:
                    mesh = cast visual;

                    // Update clipping and check if this should even be drawn
                    //
                    isClipping = false;
                    if (mesh.computedClipToBounds) {
                        clippingVisual = mesh.parent;
                        while (true) {
                            if (clippingVisual == null) break;
                            if (clippingVisual.clipToBounds) {
                                if (!isClipping) {
                                    // Simple clipping
                                    isClipping = true;
                                    clipX = clippingVisual.tx;
                                    clipY = clippingVisual.ty;
                                    clipW = clippingVisual.width * clippingVisual.a;
                                    clipH = clippingVisual.height * clippingVisual.d;
                                }
                                else {
                                    // Nested clipping
                                    clipX2 = clippingVisual.tx;
                                    clipY2 = clippingVisual.ty;
                                    clipW2 = clippingVisual.width * clippingVisual.a;
                                    clipH2 = clippingVisual.height * clippingVisual.d;
                                    intersectLeft = Math.max(clipX, clipX2);
                                    intersectRight = Math.min(clipX + clipW, clipX2 + clipW2);
                                    intersectTop = Math.max(clipY, clipY2);
                                    intersectBottom = Math.min(clipY + clipH, clipY2 + clipH2);
                                    if (intersectLeft <= intersectRight || intersectTop < intersectBottom) {
                                        clipX = intersectLeft;
                                        clipY = intersectTop;
                                        clipW = intersectRight - intersectLeft;
                                        clipH = intersectBottom - intersectTop;
                                    } else {
                                        clipX = 0;
                                        clipY = 0;
                                        clipW = 0;
                                        clipH = 0;
                                        break;
                                    }
                                }
                            }
                            else if (!clippingVisual.computedClipToBounds) break;
                            clippingVisual = clippingVisual.parent;
                        }
                    }

                    if (isClipping && (clipW == 0 || clipH == 0)) {
                        // Skip drawing of out of bounds clipped mesh
                        continue;
                    }

                    // Get or create mesh geometry
                    //
                    if (meshPoolIndex < meshPoolLength) {

                        meshGeom = meshPool.unsafeGet(meshPoolIndex);
                        
                        // Add to correct batcher
                        if (meshPoolIndex >= batchedMeshPoolLength) {
                            if (mesh.computedRenderTarget != null) {
                                var renderTexture:BatchedRenderTexture = cast mesh.computedRenderTarget.backendItem;
                                renderTexture.targetBatcher.add(meshGeom, true);
                            }
                            else {
                                Luxe.renderer.batcher.add(meshGeom, true);
                            }
                        }
                        // Or if already added, change the batcher if needed
                        else if (mesh.computedRenderTarget != null) {
                            var renderTexture:BatchedRenderTexture = cast mesh.computedRenderTarget.backendItem;
                            var prevBatcher = meshGeom.batchers.unsafeGet(0);
                            if (prevBatcher != renderTexture.targetBatcher) {
                                prevBatcher.remove(meshGeom);
                                renderTexture.targetBatcher.add(meshGeom, true);
                            }
                        }
                        else {
                            var prevBatcher = meshGeom.batchers.unsafeGet(0);
                            if (prevBatcher != Luxe.renderer.batcher) {
                                prevBatcher.remove(meshGeom);
                                Luxe.renderer.batcher.add(meshGeom, true);
                            }
                        }

                    }
                    else {

                        meshGeom = new phoenix.geometry.Geometry({
                            primitive_type: phoenix.Batcher.PrimitiveType.triangles
                        });
                        meshPool.push(meshGeom);
                        meshPoolLength++;

                        // Add to correct batcher
                        if (mesh.computedRenderTarget != null) {
                            var renderTexture:BatchedRenderTexture = cast mesh.computedRenderTarget.backendItem;
                            renderTexture.targetBatcher.add(meshGeom, true);
                        }
                        else {
                            Luxe.renderer.batcher.add(meshGeom, true);
                        }

                    }
                    meshPoolIndex++;

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
                    var geomLen = meshGeom.vertices.length;
                    var geomVertices = meshGeom.vertices;

                    // Set texture
                    if (texture != null) {
                        meshGeom.texture = texture.backendItem;

                        // Ensure uv takes in account real texture size
                        uvFactorX = meshGeom.texture.width / meshGeom.texture.width_actual;
                        uvFactorY = meshGeom.texture.height / meshGeom.texture.height_actual;
                    }

                    len = indices.length;
                    i = 0;

                    // Update vertices array size if needed
                    if (geomLen > len) {
                        geomVertices.splice(len, geomLen - len);
                    } else if (geomLen < len) {
                        for (n in geomLen...len) {
                            geomVertices[n] = null;
                        }
                    }

                    var singleColor = mesh.colorMapping == MESH;
                    var indicesColor = mesh.colorMapping == INDICES;
                    if (singleColor) {
                        color = colors.unsafeGet(0);
                    }

                    while (i < len) {

                        j = indices.unsafeGet(i);
                        x = vertices.unsafeGet(j * 2);
                        y = vertices.unsafeGet(j * 2 + 1);
                        if (!singleColor) {
                            color = indicesColor ? colors.unsafeGet(j) : colors.unsafeGet(i);
                        }

                        // Update color
                        r = color.redFloat;
                        g = color.greenFloat;
                        b = color.blueFloat;
                        a = mesh.computedAlpha * color.alphaFloat;

                        // Multiply alpha because we render premultiplied
                        r *= a;
                        g *= a;
                        b *= a;

                        // Get or create vertex
                        //
                        if (vertexPoolIndex < vertexPoolLength) {

                            vertex = vertexPool.unsafeGet(vertexPoolIndex);

                        }
                        else {

                            vertex = new phoenix.geometry.Vertex(new phoenix.Vector(0,0,0));
                            vertexPool.push(vertex);
                            vertexPoolLength++;

                        }
                        vertexPoolIndex++;

                        vertex.pos.set_xy(x, y);
                        vertex.color.set(r, g, b, a);
                        
                        if (texture != null) {
                            uvx = uvs.unsafeGet(j * 2) * uvFactorX;
                            uvy = uvs.unsafeGet(j * 2 + 1) * uvFactorY;
                        } else {
                            uvx = 0;
                            uvy = 0;
                        }
                        
                        vertex.uv.uv0.set_uv(uvx, uvy);

                        // Add vertex
                        geomVertices.unsafeSet(i, vertex);

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

                    // Update geometry clipping
                    if (isClipping) {
                        clipRect = meshGeom.clip_rect;
                        if (clipRect == null) {
                            clipRect = new phoenix.Rectangle(
                                clipX * divideNativeDensity,
                                clipY * divideNativeDensity,
                                clipW * divideNativeDensity,
                                clipH * divideNativeDensity
                            );
                        }
                        else {
                            clipRect.set(
                                clipX * divideNativeDensity,
                                clipY * divideNativeDensity,
                                clipW * divideNativeDensity,
                                clipH * divideNativeDensity
                            );
                        }
                        meshGeom.clip_rect = clipRect;
                    }
                    else {
                        meshGeom.clip = false;
                    }

                default:
            }

        }

    }

} //Draw
