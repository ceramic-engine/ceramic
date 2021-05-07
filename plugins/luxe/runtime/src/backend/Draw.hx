package backend;

#if !ceramic_luxe_legacy

import backend.impl.CeramicBatcher;

#end

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw implements spec.Draw {

#if !ceramic_luxe_legacy

    var batcher:CeramicBatcher = null;

/// Internal

    #if !debug inline #end function begin():Void {

        initBatcherIfNeeded();

    }

    #if !debug inline #end function end():Void {

        //

    }

    inline function initBatcherIfNeeded():Void {

        if (batcher == null) {

            luxeRenderer = Luxe.renderer;
            view = luxeRenderer.camera;

            batcher = new CeramicBatcher(Luxe.renderer, 'ceramic_batcher', 16384);
            batcher.layer = 2;

            Luxe.renderer.add_batch(batcher);

        }

    }

/// Public API

    public function new() {}

    inline public function getItem(visual:ceramic.Visual):VisualItem {

        return null;

    }

    public function draw(visuals:Array<ceramic.Visual>):Void {

        batcher.isMainRender = true;
        batcher.ceramicVisuals = visuals;
        Luxe.core.render();

    }

    public function swap():Void {

        #if (linc_sdl && cpp)
        Luxe.snow.runtime.window_swap();
        #end

    }

    @:deprecated
    public function stamp(visuals:Array<ceramic.Visual>):Void {

        initBatcherIfNeeded();

        batcher.isMainRender = false;
        batcher.ceramicVisuals = visuals;
        var shouldClear = Luxe.core.renderer.should_clear;
        Luxe.core.renderer.should_clear = false;
        Luxe.core.render();
        #if (linc_sdl && cpp)
        Luxe.snow.runtime.window_swap();
        #end
        Luxe.core.renderer.should_clear = shouldClear;

    }

/// Render driver

    var luxeRenderer:phoenix.Renderer;

    var transparentColor = new phoenix.Color(1.0, 1.0, 1.0, 0.0);

    var blackTransparentColor = new phoenix.Color(0.0, 0.0, 0.0, 0.0);

    var view:phoenix.Camera;

    var defaultTransformScaleX:Float;

    var defaultTransformScaleY:Float;

    var defaultViewport:phoenix.Rectangle;

    var currentRenderTarget:ceramic.RenderTexture = null;

    var renderWireframe:Bool = false;

    var posList:Float32Array;

    var uvList:Float32Array;

    var colorList:Float32Array;

    var maxFloats:Int;

    var activeShader:backend.impl.CeramicShader;

    var customGLBuffers:Array<GLBuffer> = [];

    var primitiveType = phoenix.Batcher.PrimitiveType.triangles;

    var activeTextureSlot:Int = 0;

    var projectionMatrix = ceramic.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    var modelViewMatrix = ceramic.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    var modelViewTransform = new ceramic.Transform();
    
    var renderTargetTransform = new ceramic.Transform();

    var drawingInStencilBuffer = false;

    inline static var posAttribute:Int = 0;
    inline static var uvAttribute:Int = 1;
    inline static var colorAttribute:Int = 2;

#if cpp
    var viewPosBuffer = @:privateAccess new snow.api.buffers.ArrayBufferView(Float32);
    var viewUvsBuffer = @:privateAccess new snow.api.buffers.ArrayBufferView(Float32);
    var viewColorsBuffer = @:privateAccess new snow.api.buffers.ArrayBufferView(Float32);
#end

    inline function updateProjectionMatrix(width:Float, height:Float):Void {

        // Making orthographic projection
        //

        var left = 0.0;
        var top = 0.0;
        var right = width;
        var bottom = height;
        var near = 1000.0;
        var far = -1000.0;

        var w = right - left;
        var h = top - bottom;
        var p = far - near;

        var tx = (right + left)   / w;
        var ty = (top   + bottom) / h;
        var tz = (far   + near)   / p;

        var m = projectionMatrix;

        m[0] = 2 / w;  m[4] = 0;      m[8] = 0;       m[12] = -tx;
        m[1] = 0;      m[5] = 2 / h;  m[9] = 0;       m[13] = -ty;
        m[2] = 0;      m[6] = 0;      m[10] = -2 / p; m[14] = -tz;
        m[3] = 0;      m[7] = 0;      m[11] = 0;      m[15] = 1;

    }

    inline function updateViewMatrix(density:Float, width:Float, height:Float, ?transform:ceramic.Transform, flipY:Float = 1):Void {

        if (transform != null) {
            modelViewTransform.setToTransform(transform);
            modelViewTransform.invert();
        }
        else {
            modelViewTransform.identity();
        }
        var tx = modelViewTransform.tx;
        var ty = modelViewTransform.ty;
        modelViewTransform.translate(-tx, -ty);
        modelViewTransform.scale(density, density);
        modelViewTransform.translate(tx, ty);

        if (flipY == -1) {
            // Flip vertically (needed when we are rendering to texture)
            modelViewTransform.translate(
                -width * 0.5,
                -height * 0.5
            );
            modelViewTransform.scale(1, -1);
            modelViewTransform.translate(
                width * 0.5,
                height * 0.5
            );
        }

        modelViewTransform.invert();

        setMatrixToTransform(modelViewMatrix, modelViewTransform);

    }

    inline function matrixIdentity(m:ceramic.Float32Array):Void {

        m[0] = 1;        m[4] = 0;        m[8] = 0;       m[12] = 0;
        m[1] = 0;        m[5] = 1;        m[9] = 0;       m[13] = 0;
        m[2] = 0;        m[6] = 0;        m[10] = 1;      m[14] = 0;
        m[3] = 0;        m[7] = 0;        m[11] = 0;      m[15] = 1;

    }

    inline function setMatrixToTransform(m:ceramic.Float32Array, transform:ceramic.Transform):Void {

        m[0] = transform.a; m[4] = transform.c; m[8] = 0;   m[12] = transform.tx;
        m[1] = transform.b; m[5] = transform.d; m[9] = 0;   m[13] = transform.ty;
        m[2] = 0;           m[6] = 0;           m[10] = 1;  m[14] = 0;
        m[3] = 0;           m[7] = 0;           m[11] = 0;  m[15] = 1;

    }

    /*inline function invertMatrix(m:ceramic.Float32Array):Void {

        // based on http://www.euclideanspace.com/maths/algebra/matrix/functions/inverse/fourD/index.htm

        var n11 = m[0], n12 = m[4], n13 = m[8],  n14 = m[12];
        var n21 = m[1], n22 = m[5], n23 = m[9],  n24 = m[13];
        var n31 = m[2], n32 = m[6], n33 = m[10], n34 = m[14];
        var n41 = m[3], n42 = m[7], n43 = m[11], n44 = m[15];

        m[0]  = n23*n34*n42 - n24*n33*n42 + n24*n32*n43 - n22*n34*n43 - n23*n32*n44 + n22*n33*n44;
        m[4]  = n14*n33*n42 - n13*n34*n42 - n14*n32*n43 + n12*n34*n43 + n13*n32*n44 - n12*n33*n44;
        m[8]  = n13*n24*n42 - n14*n23*n42 + n14*n22*n43 - n12*n24*n43 - n13*n22*n44 + n12*n23*n44;
        m[12] = n14*n23*n32 - n13*n24*n32 - n14*n22*n33 + n12*n24*n33 + n13*n22*n34 - n12*n23*n34;
        m[1]  = n24*n33*n41 - n23*n34*n41 - n24*n31*n43 + n21*n34*n43 + n23*n31*n44 - n21*n33*n44;
        m[5]  = n13*n34*n41 - n14*n33*n41 + n14*n31*n43 - n11*n34*n43 - n13*n31*n44 + n11*n33*n44;
        m[9]  = n14*n23*n41 - n13*n24*n41 - n14*n21*n43 + n11*n24*n43 + n13*n21*n44 - n11*n23*n44;
        m[13] = n13*n24*n31 - n14*n23*n31 + n14*n21*n33 - n11*n24*n33 - n13*n21*n34 + n11*n23*n34;
        m[2]  = n22*n34*n41 - n24*n32*n41 + n24*n31*n42 - n21*n34*n42 - n22*n31*n44 + n21*n32*n44;
        m[6]  = n14*n32*n41 - n12*n34*n41 - n14*n31*n42 + n11*n34*n42 + n12*n31*n44 - n11*n32*n44;
        m[10] = n12*n24*n41 - n14*n22*n41 + n14*n21*n42 - n11*n24*n42 - n12*n21*n44 + n11*n22*n44;
        m[14] = n14*n22*n31 - n12*n24*n31 - n14*n21*n32 + n11*n24*n32 + n12*n21*n34 - n11*n22*n34;
        m[3]  = n23*n32*n41 - n22*n33*n41 - n23*n31*n42 + n21*n33*n42 + n22*n31*n43 - n21*n32*n43;
        m[7]  = n12*n33*n41 - n13*n32*n41 + n13*n31*n42 - n11*n33*n42 - n12*n31*n43 + n11*n32*n43;
        m[11] = n13*n22*n41 - n12*n23*n41 - n13*n21*n42 + n11*n23*n42 + n12*n21*n43 - n11*n22*n43;
        m[15] = n12*n23*n31 - n13*n22*n31 + n13*n21*n32 - n11*n23*n32 - n12*n21*n33 + n11*n22*n33;

        var det = n11 * m[0] + n21 * m[4] + n31 * m[8] + n41 * m[12];

        if (det == 0) {
            ceramic.Shortcuts.warning('Can\'t invert matrix, determinant is 0');
            matrixIdentity(m);
        }

    } //invertMatrix*/

    inline public function maxPosFloats():Int {

        return maxFloats;

    }

    /** Number of floats in a single position. 3 = vec3, 4 = vec4 */
    inline static var numFloatsInPos:Int = 3;

    #if !ceramic_debug_draw inline #end public function flush(posFloats:Int, uvFloats:Int, colorFloats:Int):Void {

        var useTextureIdAttribute = (activeShader != null && ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(activeShader));

        // vertexSize = number of bytes in a single vertex vertexSize = 4 = 4 times 1 byte = 4 bytes
        var vertexSize:Int = numFloatsInPos + (useTextureIdAttribute ? 1 : 0);
        if (activeShader != null) {
            var allAttrs = activeShader.customAttributes;
            if (allAttrs != null) {
                for (ii in 0...allAttrs.length) {
                    var attr = allAttrs.unsafeGet(ii);
                    vertexSize += attr.size;
                }
            }
        }

        // fromBuffer takes byte length, so floats * 4
        var _pos = Float32Array.fromBuffer(posList.buffer, 0, posFloats * 4 #if cpp , viewPosBuffer #end);
        var _uvs = Float32Array.fromBuffer(uvList.buffer, 0, uvFloats * 4 #if cpp , viewUvsBuffer #end);
        var _colors = Float32Array.fromBuffer(colorList.buffer, 0, colorFloats * 4 #if cpp , viewColorsBuffer #end);

        // Begin submit

        var pb = GL.createBuffer();
        var cb = GL.createBuffer();
        var tb = GL.createBuffer();

        GL.bindBuffer(GL.ARRAY_BUFFER, pb);
        GL.vertexAttribPointer(posAttribute, numFloatsInPos, GL.FLOAT, false, vertexSize * 4, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _pos, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, tb);
        GL.vertexAttribPointer(uvAttribute, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _uvs, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, cb);
        GL.vertexAttribPointer(colorAttribute, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _colors, GL.STREAM_DRAW);

        var offset = numFloatsInPos;
        var n = colorAttribute + 1;
        var customGLBuffersLen:Int = 0;

        if (useTextureIdAttribute) {

            var b = GL.createBuffer();
            customGLBuffers[customGLBuffersLen++] = b;

            GL.enableVertexAttribArray(n);
            GL.bindBuffer(GL.ARRAY_BUFFER, b);
            GL.vertexAttribPointer(n, 1, GL.FLOAT, false, vertexSize * 4, offset * 4);
            GL.bufferData(GL.ARRAY_BUFFER, _pos, GL.STREAM_DRAW);

            n++;
            offset++;

        }

        if (activeShader != null && activeShader.customAttributes != null) {

            var allAttrs = activeShader.customAttributes;
            var start = customGLBuffersLen;
            var end = start+allAttrs.length;
            customGLBuffersLen += allAttrs.length;
            for (ii in start...end) {
                var attrIndex = ii - start;
                var attr = allAttrs.unsafeGet(attrIndex);

                var b = GL.createBuffer();
                customGLBuffers[ii] = b;

                GL.enableVertexAttribArray(n);
                GL.bindBuffer(GL.ARRAY_BUFFER, b);
                GL.vertexAttribPointer(n, attr.size, GL.FLOAT, false, vertexSize * 4, offset * 4);
                GL.bufferData(GL.ARRAY_BUFFER, _pos, GL.STREAM_DRAW);

                n++;
                offset += attr.size;

            }
        }

        // Draw
        GL.drawArrays(primitiveType, 0, Std.int(_colors.length/4));

        GL.deleteBuffer(pb);
        GL.deleteBuffer(cb);
        GL.deleteBuffer(tb);

        if (customGLBuffersLen > 0) {
            var n = colorAttribute + 1;
            for (ii in 0...customGLBuffersLen) {
                var b = customGLBuffers.unsafeGet(ii);
                GL.deleteBuffer(b);
                GL.disableVertexAttribArray(n);
                n++;
            }
        }

        // End submit

        _pos = null;
        _uvs = null;
        _colors = null;

    }

    inline public function initBuffers(maxVerts:Int):Void {

        if (posList == null) {

            maxFloats = maxVerts * 4;

            posList = new Float32Array(maxFloats);
            uvList = new Float32Array(maxFloats);
            colorList = new Float32Array(maxFloats);

        }

    }

    inline public function beginRender():Void {

        defaultTransformScaleX = view.transform.scale.x;
        defaultTransformScaleY = view.transform.scale.y;
        defaultViewport = view.viewport;

    }

    inline public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        if (currentRenderTarget != renderTarget || force) {
            currentRenderTarget = renderTarget;
            if (renderTarget != null) {
                var renderTexture:backend.impl.CeramicRenderTexture = cast renderTarget.backendItem;
                luxeRenderer.target = renderTexture;

                updateProjectionMatrix(
                    renderTarget.width,
                    renderTarget.height
                );

                renderTargetTransform.identity();
                renderTargetTransform.scale(renderTarget.density, renderTarget.density);

                updateViewMatrix(
                    renderTarget.density,
                    renderTarget.width,
                    renderTarget.height,
                    renderTargetTransform,
                    -1
                );
                GL.viewport(
                    0, 0,
                    Std.int(renderTarget.width * renderTarget.density),
                    Std.int(renderTarget.height * renderTarget.density)
                );
                if (renderTarget.clearOnRender) Luxe.renderer.clear(blackTransparentColor);
                
            } else {
                luxeRenderer.target = null;
                updateProjectionMatrix(
                    ceramic.App.app.backend.screen.getWidth(),
                    ceramic.App.app.backend.screen.getHeight()
                );
                updateViewMatrix(
                    ceramic.App.app.backend.screen.getDensity(),
                    ceramic.App.app.backend.screen.getWidth(),
                    ceramic.App.app.backend.screen.getHeight(),
                    @:privateAccess ceramic.App.app.screen.matrix
                );
                GL.viewport(
                    0, 0,
                    Std.int(ceramic.App.app.backend.screen.getWidth() * ceramic.App.app.backend.screen.getDensity()),
                    Std.int(ceramic.App.app.backend.screen.getHeight() * ceramic.App.app.backend.screen.getDensity())
                );
            }
        }

    }

    inline public function useShader(shader:backend.impl.CeramicShader):Void {

        if (!shader.no_default_uniforms) {
            //shader.set_matrix4_arr('projectionMatrix', view.proj_arr);
            shader.set_matrix4_arr('projectionMatrix', projectionMatrix);
            //trace('proj_def=${matrixToArray(view.proj_arr)}');
            //trace('proj_new=${matrixToArray(projectionMatrix)}');

            //shader.set_matrix4_arr('modelViewMatrix', view.view_inverse_arr);
            shader.set_matrix4_arr('modelViewMatrix', modelViewMatrix);
            //trace('view_def=${matrixToArray(view.view_inverse_arr)}');
            //trace('view_new=${matrixToArray(modelViewMatrix)}');
        }
        
        shader.activate();
        
        activeShader = shader;

    }

    function matrixToArray(matrix:ceramic.Float32Array):Array<Float> {

        var result = [];
        for (i in 0...16) {
            result[i] = matrix[i];
        }
        return result;

    }

    /*inline public function useRenderTarget(renderTarget:backend.Texture):Void {

        if (renderTarget != null) {
            var renderTexture:backend.impl.CeramicRenderTexture = cast renderTarget;
            luxeRenderer.target = renderTexture;
            view.transform.scale.x = ceramic.App.app.screen.nativeDensity;
            view.transform.scale.y = ceramic.App.app.screen.nativeDensity;
            view.process();
            GL.viewport(0, 0, renderTexture.width, renderTexture.height);
        }
        else {
            luxeRenderer.target = null;
            view.transform.scale.x = defaultTransformScaleX;
            view.transform.scale.y = defaultTransformScaleY;
            view.viewport = defaultViewport;
            view.process();
            luxeRenderer.state.viewport(view.viewport.x, view.viewport.y, view.viewport.w, view.viewport.h);
        }

    } //useRenderTarget*/

    inline public function clear():Void {

        Luxe.renderer.clear(transparentColor);

    }

    inline public function enableBlending():Void {

        luxeRenderer.state.enable(GL.BLEND);

    }

    inline public function disableBlending():Void {

        luxeRenderer.state.disable(GL.BLEND);

    }

    inline public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        GL.blendFuncSeparate(
            srcRgb,
            dstRgb,
            srcAlpha,
            dstAlpha
        );

    }

    inline public function getActiveTexture():Int {

        return activeTextureSlot;

    }

    inline public function setActiveTexture(slot:Int):Void {

        activeTextureSlot = slot;
        luxeRenderer.state.activeTexture(GL.TEXTURE0 + slot);

    }

    inline public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem : phoenix.Texture).texture == textureId;

    }

    inline public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem : phoenix.Texture).texture;

    }

    /*inline public function getTextureSlot(backendItem:backend.Texture):Int {

        return (backendItem : phoenix.Texture).slot;

    } //getTextureSlot*/

    inline public function getTextureWidth(backendItem:backend.Texture):Int {

        return (backendItem : phoenix.Texture).width;

    }

    inline public function getTextureHeight(backendItem:backend.Texture):Int {

        return (backendItem : phoenix.Texture).height;

    }

    inline public function getTextureWidthActual(backendItem:backend.Texture):Int {

        return (backendItem : phoenix.Texture).width_actual;

    }

    inline public function getTextureHeightActual(backendItem:backend.Texture):Int {

        return (backendItem : phoenix.Texture).height_actual;

    }

    inline public function bindTexture(backendItem:backend.Texture):Void {

        GL.activeTexture(GL.TEXTURE0+activeTextureSlot);
        GL.bindTexture(GL.TEXTURE_2D, (backendItem : phoenix.Texture).texture);

    }

    inline public function bindNoTexture():Void {

        GL.bindTexture(GL.TEXTURE_2D, #if snow_web null #else 0 #end);

    }

    inline public function setRenderWireframe(value:Bool):Void {

        renderWireframe = value;
        primitiveType = value ? phoenix.Batcher.PrimitiveType.lines : phoenix.Batcher.PrimitiveType.triangles;

    }

    #if cpp

    inline public function getPosList():snow.api.buffers.ArrayBuffer {

        return (posList:snow.api.buffers.ArrayBufferView).buffer;

    }

    inline public function putInPosList(buffer:snow.api.buffers.ArrayBuffer, index:Int, value:Float):Void {

        snow.api.buffers.ArrayBufferIO.setFloat32(buffer, (index*Float32Array.BYTES_PER_ELEMENT), value);

    }

    inline public function getUvList():snow.api.buffers.ArrayBuffer {

        return (uvList:snow.api.buffers.ArrayBufferView).buffer;

    }

    inline public function putInUvList(uvList:snow.api.buffers.ArrayBuffer, index:Int, value:Float):Void {

        snow.api.buffers.ArrayBufferIO.setFloat32(uvList, (index*Float32Array.BYTES_PER_ELEMENT), value);

    }

    inline public function getColorList():snow.api.buffers.ArrayBuffer {

        return (colorList:snow.api.buffers.ArrayBufferView).buffer;

    }

    inline public function putInColorList(colorList:snow.api.buffers.ArrayBuffer, index:Int, value:Float):Void {

        snow.api.buffers.ArrayBufferIO.setFloat32(colorList, (index*Float32Array.BYTES_PER_ELEMENT), value);

    }

    #else

    inline public function getPosList():Float32Array {

        return posList;

    }

    inline public function putInPosList(posList:Float32Array, index:Int, value:Float):Void {

        posList[index] = value;

    }

    inline public function getUvList():Float32Array {

        return uvList;

    }

    inline public function putInUvList(uvList:Float32Array, index:Int, value:Float):Void {

        uvList[index] = value;

    }

    inline public function getColorList():Float32Array {

        return colorList;

    }

    inline public function putInColorList(colorList:Float32Array, index:Int, value:Float):Void {

        colorList[index] = value;

    }

    #end

    inline public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    inline public function endDrawQuad():Void {

    }

    inline public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    inline public function endDrawMesh():Void {

    }

    inline public function beginDrawingInStencilBuffer():Void {
        
        drawingInStencilBuffer = true;

        GL.stencilMask(0xFF);
        GL.clearStencil(0xFF);
        GL.clear(GL.STENCIL_BUFFER_BIT);
        GL.enable(GL.STENCIL_TEST);

        GL.stencilOp(GL.KEEP, GL.KEEP, GL.REPLACE);

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(false, false, false, false);

    }

    inline public function endDrawingInStencilBuffer():Void {
        
        drawingInStencilBuffer = false;

    }

    inline public function drawWithStencilTest():Void {

        GL.stencilFunc(GL.EQUAL, 1, 0xFF);
        GL.stencilMask(0x00);
        GL.colorMask(true, true, true, true);

        GL.enable(GL.STENCIL_TEST);

    }

    inline public function drawWithoutStencilTest():Void {

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(true, true, true, true);

        GL.disable(GL.STENCIL_TEST);

    }

#else

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

    }

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

    }

/// Public API

    public function new() {}

    inline public function getItem(visual:ceramic.Visual):VisualItem {

        // The backend decides how each visual should be drawn.
        // Instead of checking instance type at each draw iteration,
        // The backend provides/computes a VisualItem object when
        // a visual is instanciated that it can later re-use
        // at each draw iteration to read/store per visual data.

        if (Std.isOfType(visual, ceramic.Quad)) {
            return QUAD;
        }
        else if (Std.isOfType(visual, ceramic.Mesh)) {
            return MESH;
        }
        else {
            return NONE;
        }

    }

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
                    w = quad.width;
                    h = quad.height;

                    // Update clipping and check if this should even be drawn
                    //
                    isClipping = false;
                    /*
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
                    }*/

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

                    m.M11 = quad.a; //el[0]
                    m.M12 = quad.c; //el[4]
                    m.M14 = quad.tx; //el[12]
                    m.M21 = quad.b; //el[1]
                    m.M22 = quad.d; //el[5]
                    m.M24 = quad.ty; //el[13]

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
                    /*if (mesh.computedClipToBounds) {
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
                    }*/

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
                            color = indicesColor ? colors.unsafeGet(i) : colors.unsafeGet(j);
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

#end

}
