package backend;

import clay.buffers.Uint16Array;
import clay.Clay;
import clay.opengl.GL;
import clay.graphics.Graphics;
import clay.buffers.Float32Array;
import clay.buffers.ArrayBufferView;

using ceramic.Extensions;

@:allow(backend.Backend)
@:access(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

    var renderer:ceramic.Renderer = new ceramic.Renderer();

/// Public API

    public function new() {

        renderer = new ceramic.Renderer();

    }

    #if !ceramic_debug_draw_backend inline #end function begin():Void {

        //

    }

    #if !ceramic_debug_draw_backend inline #end function end():Void {

        //

    }

    public function draw(visuals:Array<ceramic.Visual>):Void {

        #if ios
        // iOS doesn't like it when we send GPU commands when app is in background
        if (!ceramic.App.app.backend.mobileInBackground) {
        #end
            renderer.render(true, visuals);
        #if ios
        }
        #end

    }

    inline public function swap():Void {

        // Unused

    }

/// Rendering

    #if !ceramic_debug_draw_backend inline #end static var MAX_VERTS_SIZE:Int = 65536;
    #if !ceramic_debug_draw_backend inline #end static var MAX_INDICES:Int = 16384;
    #if !ceramic_debug_draw_backend inline #end static var MAX_BUFFERS:Int = 64;

    #if !ceramic_debug_draw_backend inline #end static var ATTRIBUTE_POS:Int = 0;
    #if !ceramic_debug_draw_backend inline #end static var ATTRIBUTE_UV:Int = 1;
    #if !ceramic_debug_draw_backend inline #end static var ATTRIBUTE_COLOR:Int = 2;

    #if cpp
    static var _viewPosBufferViewArray:Array<ArrayBufferView> = [];
    static var _viewUvsBufferViewArray:Array<ArrayBufferView> = [];
    static var _viewColorsBufferViewArray:Array<ArrayBufferView> = [];
    static var _viewIndicesBufferViewArray:Array<ArrayBufferView> = [];
    
    static var _viewPosBufferView:ArrayBufferView;
    static var _viewUvsBufferView:ArrayBufferView;
    static var _viewColorsBufferView:ArrayBufferView;
    static var _viewIndicesBufferView:ArrayBufferView;
    #end

    static var _buffersIndex:Int;

    static var _posListArray:Array<Float32Array> = [];
    static var _indiceListArray:Array<Uint16Array> = [];
    static var _uvListArray:Array<Float32Array> = [];
    static var _colorListArray:Array<Float32Array> = [];

    static var _posList:Float32Array;
    static var _indiceList:Uint16Array;
    static var _uvList:Float32Array;
    static var _colorList:Float32Array;

    #if cpp
    static var _posBuffer:clay.buffers.ArrayBuffer;
    static var _indiceBuffer:clay.buffers.ArrayBuffer;
    static var _uvBuffer:clay.buffers.ArrayBuffer;
    static var _colorBuffer:clay.buffers.ArrayBuffer;
    #end

    static var _activeTextureSlot:Int = 0;

    static var _batchMultiTexture:Bool = false;
    static var _posSize:Int = 0;
    static var _customGLBuffers:Array<GLBuffer> = [];

    static var _activeShader:ShaderImpl;

    static var _currentRenderTarget:ceramic.RenderTexture = null;

    static var _projectionMatrix = ceramic.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    static var _modelViewMatrix = ceramic.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    static var _modelViewTransform = new ceramic.Transform();
    
    static var _renderTargetTransform = new ceramic.Transform();

    static var _blackTransparentColor = new ceramic.AlphaColor(ceramic.Color.BLACK, 0);

    static var _whiteTransparentColor = new ceramic.AlphaColor(ceramic.Color.WHITE, 0);

    static var _maxVerts:Int = 0;

    static var _vertexSize:Int = 0;
    static var _numIndices:Int = 0;

    static var _numPos:Int = 0;
    static var _posIndex:Int = 0;
    static var _floatAttributesSize:Int = 0;

    static var _numUVs:Int = 0;
    static var _uvIndex:Int = 0;

    static var _numColors:Int = 0;
    static var _colorIndex:Int = 0;

    static var _drawingInStencilBuffer:Bool = false;

    #if !ceramic_debug_draw_backend inline #end public function initBuffers():Void {

        _activeTextureSlot = 0;
        _buffersIndex = -1;

        prepareNextBuffers();

    }

    function prepareNextBuffers():Void {

        _buffersIndex++;
        if (_buffersIndex > MAX_BUFFERS) {
            _buffersIndex = 0;
        }
        if (_posListArray.length <= _buffersIndex) {

            _posListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
             // For uvs, we'll never need more than two thirds of vertex buffer size
            _uvListArray[_buffersIndex] = new Float32Array(Std.int(Math.ceil(MAX_VERTS_SIZE * 2.0 / 3.0)));
            _colorListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
            _indiceListArray[_buffersIndex] = new Uint16Array(MAX_INDICES * 2);

            #if cpp
            _viewPosBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewUvsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewColorsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewIndicesBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Uint8);
            #end
        }

        _posList = _posListArray.unsafeGet(_buffersIndex);
        _uvList = _uvListArray.unsafeGet(_buffersIndex);
        _colorList = _colorListArray.unsafeGet(_buffersIndex);
        _indiceList = _indiceListArray.unsafeGet(_buffersIndex);

        #if cpp
        _viewPosBufferView = _viewPosBufferViewArray.unsafeGet(_buffersIndex);
        _viewUvsBufferView = _viewUvsBufferViewArray.unsafeGet(_buffersIndex);
        _viewColorsBufferView = _viewColorsBufferViewArray.unsafeGet(_buffersIndex);
        _viewIndicesBufferView = _viewIndicesBufferViewArray.unsafeGet(_buffersIndex);

        _posBuffer = (_posList:clay.buffers.ArrayBufferView).buffer;
        _uvBuffer = (_uvList:clay.buffers.ArrayBufferView).buffer;
        _colorBuffer = (_colorList:clay.buffers.ArrayBufferView).buffer;
        _indiceBuffer = (_indiceList:clay.buffers.ArrayBufferView).buffer;
        #end

    }

    #if !ceramic_debug_draw_backend inline #end public function beginRender():Void {

        GL.enableVertexAttribArray(ATTRIBUTE_POS);
        GL.enableVertexAttribArray(ATTRIBUTE_UV);
        GL.enableVertexAttribArray(ATTRIBUTE_COLOR);

    }

    #if !ceramic_debug_draw_backend inline #end public function clear():Void {

        #if !ceramic_debug_draw_backend inline #end Graphics.clear(
            _whiteTransparentColor.redFloat,
            _whiteTransparentColor.greenFloat,
            _whiteTransparentColor.blueFloat,
            _whiteTransparentColor.alpha
        );

    }

    #if !ceramic_debug_draw_backend inline #end public function clearAndApplyBackground():Void {

        var background = ceramic.App.app.settings.background;

        #if !ceramic_debug_draw_backend inline #end Graphics.clear(
            background.redFloat,
            background.greenFloat,
            background.blueFloat,
            1
        );

    }

    #if !ceramic_debug_draw_backend inline #end public function enableBlending():Void {

        Graphics.enableBlending();

    }

    #if !ceramic_debug_draw_backend inline #end public function disableBlending():Void {

        Graphics.disableBlending();

    }

    #if !ceramic_debug_draw_backend inline #end public function setActiveTexture(slot:Int):Void {

        _activeTextureSlot = slot;
        Graphics.setActiveTexture(slot);

    }

    #if !ceramic_debug_draw_backend inline #end public function setRenderWireframe(value:Bool):Void {

        // TODO?

    }

    #if !ceramic_debug_draw_backend inline #end public function getActiveTexture():Int {

        return _activeTextureSlot;

    }

    #if !ceramic_debug_draw_backend inline #end public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        if (_currentRenderTarget != renderTarget || force) {
            _currentRenderTarget = renderTarget;
            if (renderTarget != null) {
                var renderTexture:clay.graphics.RenderTexture = cast renderTarget.backendItem;
                
                Graphics.setRenderTarget(renderTexture.renderTarget);

                updateProjectionMatrix(
                    renderTarget.width,
                    renderTarget.height
                );

                _renderTargetTransform.identity();
                _renderTargetTransform.scale(renderTarget.density, renderTarget.density);

                updateViewMatrix(
                    renderTarget.density,
                    renderTarget.width,
                    renderTarget.height,
                    _renderTargetTransform,
                    -1
                );

                Graphics.setViewport(
                    0, 0,
                    Std.int(renderTarget.width * renderTarget.density),
                    Std.int(renderTarget.height * renderTarget.density)
                );

                if (renderTarget.clearOnRender) {
                    Graphics.clear(
                        _blackTransparentColor.redFloat,
                        _blackTransparentColor.greenFloat,
                        _blackTransparentColor.blueFloat,
                        _blackTransparentColor.alphaFloat
                    );
                }
                
            } else {
                
                Graphics.setRenderTarget(null);

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
                Graphics.setViewport(
                    0, 0,
                    Std.int(ceramic.App.app.backend.screen.getWidth() * ceramic.App.app.backend.screen.getDensity()),
                    Std.int(ceramic.App.app.backend.screen.getHeight() * ceramic.App.app.backend.screen.getDensity())
                );
            }
        }

    }

    #if !ceramic_debug_draw_backend inline #end public function useShader(shader:backend.Shader):Void {
        
        _activeShader = shader;

        (shader:ShaderImpl).uniforms.setMatrix4('projectionMatrix', _projectionMatrix);
        (shader:ShaderImpl).uniforms.setMatrix4('modelViewMatrix', _modelViewMatrix);

        var shadersBackend = ceramic.App.app.backend.shaders;

        _floatAttributesSize = shadersBackend.customFloatAttributesSize(_activeShader);

        _batchMultiTexture = shadersBackend.canBatchWithMultipleTextures(_activeShader);
        _vertexSize = 3 + _floatAttributesSize + (_batchMultiTexture ? 1 : 0);
        _posSize = _vertexSize;
        if (_vertexSize < 4)
            _vertexSize = 4;

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));
        
        (shader:ShaderImpl).activate();

        if (_numPos == 0) {
            resetIndexes();
        }

    }

    #if !ceramic_debug_draw_backend inline #end function resetIndexes():Void {

        _numIndices = 0;
        _numPos = 0;
        _numUVs = 0;
        _numColors = 0;

        _posIndex = 0;
        _uvIndex = 0;
        _colorIndex = 0;

    }

    #if !ceramic_debug_draw_backend inline #end public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        Graphics.setBlendFuncSeparate(
            srcRgb,
            dstRgb,
            srcAlpha,
            dstAlpha
        );

    }

    #if !ceramic_debug_draw_backend inline #end public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    #if !ceramic_debug_draw_backend inline #end public function endDrawQuad():Void {

    }

    #if !ceramic_debug_draw_backend inline #end public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    #if !ceramic_debug_draw_backend inline #end public function endDrawMesh():Void {

    }

    #if !ceramic_debug_draw_backend inline #end public function drawWithStencilTest():Void {

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilFunc(GL.EQUAL, 1, 0xFF);
        GL.stencilMask(0x00);
        GL.colorMask(true, true, true, true);

        GL.enable(GL.STENCIL_TEST);

    }

    #if !ceramic_debug_draw_backend inline #end public function drawWithoutStencilTest():Void {

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(true, true, true, true);

        GL.disable(GL.STENCIL_TEST);

    }

    #if !ceramic_debug_draw_backend inline #end public function beginDrawingInStencilBuffer():Void {
        
        _drawingInStencilBuffer = true;

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilMask(0xFF);
        GL.clearStencil(0xFF);
        GL.clear(GL.STENCIL_BUFFER_BIT);
        GL.enable(GL.STENCIL_TEST);

        GL.stencilOp(GL.KEEP, GL.KEEP, GL.REPLACE);

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(false, false, false, false);

    }

    #if !ceramic_debug_draw_backend inline #end public function endDrawingInStencilBuffer():Void {
        
        _drawingInStencilBuffer = false;

    }

    #if !ceramic_debug_draw_backend inline #end public function bindTexture(backendItem:backend.Texture):Void {

        Graphics.bindTexture2d((backendItem:clay.graphics.Texture).textureId);

    }

    #if !ceramic_debug_draw_backend inline #end public function bindNoTexture():Void {

        #if web
        var backendItem = ceramic.App.app.defaultWhiteTexture.backendItem;
        Graphics.bindTexture2d((backendItem:clay.graphics.Texture).textureId);
        #else
        Graphics.bindTexture2d(Graphics.NO_TEXTURE);
        #end

    }

    #if !ceramic_debug_draw_backend inline #end public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem:clay.graphics.Texture).textureId == textureId;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem:clay.graphics.Texture).textureId;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureWidth(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).width;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureHeight(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).height;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureWidthActual(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).widthActual;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureHeightActual(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).heightActual;

    }

    #if !ceramic_debug_draw_backend inline #end function updateProjectionMatrix(width:Float, height:Float):Void {

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

        var m = _projectionMatrix;

        m[0] = 2 / w;  m[4] = 0;      m[8] = 0;       m[12] = -tx;
        m[1] = 0;      m[5] = 2 / h;  m[9] = 0;       m[13] = -ty;
        m[2] = 0;      m[6] = 0;      m[10] = -2 / p; m[14] = -tz;
        m[3] = 0;      m[7] = 0;      m[11] = 0;      m[15] = 1;

    }

    #if !ceramic_debug_draw_backend inline #end function updateViewMatrix(density:Float, width:Float, height:Float, ?transform:ceramic.Transform, flipY:Float = 1):Void {

        if (transform != null) {
            _modelViewTransform.setToTransform(transform);
            _modelViewTransform.invert();
        }
        else {
            _modelViewTransform.identity();
        }
        var tx = _modelViewTransform.tx;
        var ty = _modelViewTransform.ty;
        _modelViewTransform.translate(-tx, -ty);
        _modelViewTransform.scale(density, density);
        _modelViewTransform.translate(tx, ty);

        if (flipY == -1) {
            // Flip vertically (needed when we are rendering to texture)
            _modelViewTransform.translate(
                -width * 0.5,
                -height * 0.5
            );
            _modelViewTransform.scale(1, -1);
            _modelViewTransform.translate(
                width * 0.5,
                height * 0.5
            );
        }

        _modelViewTransform.invert();

        setMatrixToTransform(_modelViewMatrix, _modelViewTransform);

    }

    #if !ceramic_debug_draw_backend inline #end function matrixIdentity(m:ceramic.Float32Array):Void {

        m[0] = 1;        m[4] = 0;        m[8] = 0;       m[12] = 0;
        m[1] = 0;        m[5] = 1;        m[9] = 0;       m[13] = 0;
        m[2] = 0;        m[6] = 0;        m[10] = 1;      m[14] = 0;
        m[3] = 0;        m[7] = 0;        m[11] = 0;      m[15] = 1;

    }

    #if !ceramic_debug_draw_backend inline #end function setMatrixToTransform(m:ceramic.Float32Array, transform:ceramic.Transform):Void {

        m[0] = transform.a; m[4] = transform.c; m[8] = 0;   m[12] = transform.tx;
        m[1] = transform.b; m[5] = transform.d; m[9] = 0;   m[13] = transform.ty;
        m[2] = 0;           m[6] = 0;           m[10] = 1;  m[14] = 0;
        m[3] = 0;           m[7] = 0;           m[11] = 0;  m[15] = 1;

    }

    #if !ceramic_debug_draw_backend inline #end public function getNumPos():Int {

        return _numPos;

    }

    #if !ceramic_debug_draw_backend inline #end public function putPos(x:Float, y:Float, z:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, _posIndex * Float32Array.BYTES_PER_ELEMENT, x);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 1) * Float32Array.BYTES_PER_ELEMENT, y);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 2) * Float32Array.BYTES_PER_ELEMENT, z);
        #else
        _posList[_posIndex] = x;
        _posList[_posIndex + 1] = y;
        _posList[_posIndex + 2] = z;
        #end
        _posIndex += 3;
        _numPos++;

    }

    #if !ceramic_debug_draw_backend inline #end public function putPosAndTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, _posIndex * Float32Array.BYTES_PER_ELEMENT, x);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 1) * Float32Array.BYTES_PER_ELEMENT, y);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 2) * Float32Array.BYTES_PER_ELEMENT, z);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 3) * Float32Array.BYTES_PER_ELEMENT, textureSlot);
        #else
        _posList[_posIndex] = x;
        _posList[_posIndex + 1] = y;
        _posList[_posIndex + 2] = z;
        _posList[_posIndex + 3] = textureSlot;
        #end
        _posIndex += 4;
        _numPos++;

    }

    #if !ceramic_debug_draw_backend inline #end public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    #if !ceramic_debug_draw_backend inline #end public function putFloatAttribute(index:Int, value:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + index) * Float32Array.BYTES_PER_ELEMENT, value);
        #else
        _posList[_posIndex + index] = value;
        #end

    }

    #if !ceramic_debug_draw_backend inline #end public function endFloatAttributes():Void {

        _posIndex += _floatAttributesSize;

    }

    #if !ceramic_debug_draw_backend inline #end public function putIndice(i:Int):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setUint16(_indiceBuffer, _numIndices * Uint16Array.BYTES_PER_ELEMENT, i);
        #else
        _indiceList[_numIndices] = i;
        #end
        _numIndices++;

    }

    #if !ceramic_debug_draw_backend inline #end public function putUVs(uvX:Float, uvY:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, _uvIndex * Float32Array.BYTES_PER_ELEMENT, uvX);
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, (_uvIndex + 1) * Float32Array.BYTES_PER_ELEMENT, uvY);
        #else
        _uvList[_uvIndex] = uvX;
        _uvList[_uvIndex + 1] = uvY;
        #end
        _uvIndex += 2;
        _numUVs++;

    }

    #if !ceramic_debug_draw_backend inline #end public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, _colorIndex * Float32Array.BYTES_PER_ELEMENT, r);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 1) * Float32Array.BYTES_PER_ELEMENT, g);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 2) * Float32Array.BYTES_PER_ELEMENT, b);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 3) * Float32Array.BYTES_PER_ELEMENT, a);
        #else
        _colorList[_colorIndex] = r;
        _colorList[_colorIndex + 1] = g;
        _colorList[_colorIndex + 2] = b;
        _colorList[_colorIndex + 3] = a;
        #end
        _colorIndex += 4;
        _numColors++;

    }

    #if !ceramic_debug_draw_backend inline #end public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    #if !ceramic_debug_draw_backend inline #end public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {
        
        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);

    }

    #if !ceramic_debug_draw_backend inline #end public function remainingVertices():Int {
        
        return _maxVerts - _numPos;

    }

    #if !ceramic_debug_draw_backend inline #end public function remainingIndices():Int {
        
        return MAX_INDICES - _numIndices;

    }

    static var debugShader:clay.graphics.Shader = null;

    #if !ceramic_debug_draw_backend inline #end public function flush():Void {

        var batchMultiTexture = _batchMultiTexture;

        // fromBuffer takes byte length, so floats * 4
        #if cpp
        var pos = Float32Array.fromBuffer(_posBuffer, 0, _posIndex * 4, _viewPosBufferView);
        var uvs = Float32Array.fromBuffer(_uvBuffer, 0, _uvIndex * 4, _viewUvsBufferView);
        var colors = Float32Array.fromBuffer(_colorBuffer, 0, _colorIndex * 4, _viewColorsBufferView);
        var indices = Uint16Array.fromBuffer(_indiceBuffer, 0, _numIndices * 2, _viewIndicesBufferView);
        #else
        var pos = Float32Array.fromBuffer(_posList.buffer, 0, _posIndex * 4);
        var uvs = Float32Array.fromBuffer(_uvList.buffer, 0, _uvIndex * 4);
        var colors = Float32Array.fromBuffer(_colorList.buffer, 0, _colorIndex * 4);
        var indices = Uint16Array.fromBuffer(_indiceList.buffer, 0, _numIndices * 2);
        #end

        // var posArray = [];
        // for (i in 0..._posIndex) {
        //     posArray.push(pos[i]);
        // }
        // trace('pos: $posArray');
        // var uvArray = [];
        // for (i in 0..._uvIndex) {
        //     uvArray.push(uvs[i]);
        // }
        // trace('uv: $uvArray');
        // var colorArray = [];
        // for (i in 0..._colorIndex) {
        //     colorArray.push(colors[i]);
        // }
        // trace('color: $colorArray');
        // var indiceArray = [];
        // for (i in 0..._numIndices) {
        //     indiceArray.push(indices[i]);
        // }
        // trace('indice: $indiceArray');

        // Begin submit

        var pb = GL.createBuffer();
        var cb = GL.createBuffer();
        var tb = GL.createBuffer();
        var ib = GL.createBuffer();

        GL.enableVertexAttribArray(0);
        GL.enableVertexAttribArray(1);
        GL.enableVertexAttribArray(2);

        GL.bindBuffer(GL.ARRAY_BUFFER, pb);
        GL.vertexAttribPointer(ATTRIBUTE_POS, 3, GL.FLOAT, false, _posSize * 4, 0);
        GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, tb);
        GL.vertexAttribPointer(ATTRIBUTE_UV, 2, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, uvs, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, cb);
        GL.vertexAttribPointer(ATTRIBUTE_COLOR, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, colors, GL.STREAM_DRAW);

        var offset = 3;
        var n = ATTRIBUTE_COLOR + 1;
        var customGLBuffersLen:Int = 0;

        if (batchMultiTexture) {

            var b = GL.createBuffer();
            _customGLBuffers[customGLBuffersLen++] = b;

            GL.enableVertexAttribArray(n);
            GL.bindBuffer(GL.ARRAY_BUFFER, b);
            GL.vertexAttribPointer(n, 1, GL.FLOAT, false, _posSize * 4, offset * 4);
            GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

            n++;
            offset++;

        }

        if (_activeShader != null && _activeShader.customAttributes != null) {

            var allAttrs = _activeShader.customAttributes;
            var start = customGLBuffersLen;
            var end = start + allAttrs.length;
            customGLBuffersLen += allAttrs.length;
            for (ii in start...end) {

                var attrIndex = ii - start;
                var attr = allAttrs.unsafeGet(attrIndex);

                var b = GL.createBuffer();
                _customGLBuffers[ii] = b;

                GL.enableVertexAttribArray(n);
                GL.bindBuffer(GL.ARRAY_BUFFER, b);
                GL.vertexAttribPointer(n, attr.size, GL.FLOAT, false, _posSize * 4, offset * 4);
                GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

                n++;
                offset += attr.size;

            }
        }

        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ib);
        GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indices, GL.STREAM_DRAW);

        // Draw
        GL.drawElements(GL.TRIANGLES, _numIndices, GL.UNSIGNED_SHORT, 0);

        GL.deleteBuffer(pb);
        GL.deleteBuffer(cb);
        GL.deleteBuffer(tb);

        if (customGLBuffersLen > 0) {
            var n = ATTRIBUTE_COLOR + 1;
            for (ii in 0...customGLBuffersLen) {
                var b = _customGLBuffers.unsafeGet(ii);
                GL.deleteBuffer(b);
                GL.disableVertexAttribArray(n);
                n++;
            }
        }

        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, Graphics.NO_BUFFER);
        GL.deleteBuffer(ib);

        // End submit

        pos = null;
        uvs = null;
        colors = null;
        indices = null;

        resetIndexes();

        prepareNextBuffers();

    }

}
