package backend;

import clay.buffers.Uint8Array;
import clay.Clay;
import clay.opengl.GL;
import clay.graphics.Graphics;
import clay.buffers.Float32Array;
import clay.buffers.ArrayBufferView;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

    var renderer:ceramic.Renderer = new ceramic.Renderer();

/// Public API

    public function new() {

        trace('- create renderer');
        renderer = new ceramic.Renderer();

    }

    #if !debug /*inline*/ #end function begin():Void {

    }

    #if !debug /*inline*/ #end function end():Void {

    }

    public function draw(visuals:Array<ceramic.Visual>):Void {

        renderer.render(true, visuals);

    }

    public function swap():Void {

        // Unused

    }

/// Rendering

    #if !ceramic_debug_draw_backend /*inline*/ #end static var MAX_VERTS_SIZE:Int = 65536;
    #if !ceramic_debug_draw_backend /*inline*/ #end static var MAX_INDICES:Int = 16384;
    #if !ceramic_debug_draw_backend /*inline*/ #end static var MAX_BUFFERS:Int = 64;

    #if cpp
    static var _viewPosBufferViewArray:Array<ArrayBufferView> = [];// = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
    static var _viewUvsBufferViewArray:Array<ArrayBufferView> = [];// = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
    static var _viewColorsBufferViewArray:Array<ArrayBufferView> = [];// = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
    
    static var _viewPosBufferView:ArrayBufferView;
    static var _viewUvsBufferView:ArrayBufferView;
    static var _viewColorsBufferView:ArrayBufferView;
    #end

    static var _buffersIndex:Int;

    static var _posListArray:Array<Float32Array> = [];
    static var _indiceListArray:Array<Uint8Array> = [];
    static var _uvListArray:Array<Float32Array> = [];
    static var _colorListArray:Array<Float32Array> = [];

    static var _posList:Float32Array;
    static var _indiceList:UInt8Array;
    static var _uvList:Float32Array;
    static var _colorList:Float32Array;

    #if cpp
    static var _posBuffer:clay.buffers.ArrayBuffer;
    static var _indiceBuffer:clay.buffers.ArrayBuffer;
    static var _uvBuffer:clay.buffers.ArrayBuffer;
    static var _colorBuffer:clay.buffers.ArrayBuffer;
    #end

    static var _activeTextureSlot:Int = 0;

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

    /*inline*/ public function initBuffers():Void {

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
            _uvListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
            _colorListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
            _indiceListArray[_buffersIndex] = new Uint8Array(MAX_INDICES);
            #if cpp
            _viewPosBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewUvsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewColorsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            #end
        }

        _posList = _posListArray.unsafeGet(_buffersIndex);
        _uvList = _uvListArray.unsafeGet(_buffersIndex);
        _colorList = _colorListArray.unsafeGet(_buffersIndex);
        _indiceList = _indiceListArray.unsafeGet(_buffersIndex);
        _viewPosBufferView = _viewPosBufferViewArray.unsafeGet(_buffersIndex);
        _viewUvsBufferView = _viewUvsBufferViewArray.unsafeGet(_buffersIndex);
        _viewColorsBufferView = _viewColorsBufferViewArray.unsafeGet(_buffersIndex);

        _posBuffer = (_posList:clay.buffers.ArrayBufferView).buffer;
        _uvBuffer = (_uvList:clay.buffers.ArrayBufferView).buffer;
        _colorBuffer = (_colorList:clay.buffers.ArrayBufferView).buffer;
        _indiceBuffer = (_indiceList:clay.buffers.ArrayBufferView).buffer;

    }

    /*inline*/ public function beginRender():Void {

        //

    }

    /*inline*/ public function clear():Void {

        /*inline*/ Graphics.clear(
            _whiteTransparentColor.redFloat,
            _whiteTransparentColor.greenFloat,
            _whiteTransparentColor.blueFloat,
            _whiteTransparentColor.alpha
        );

    }

    /*inline*/ public function clearAndApplyBackground():Void {

        var background = ceramic.App.app.settings.background;

        /*inline*/ Graphics.clear(
            background.redFloat,
            background.greenFloat,
            background.blueFloat,
            1
        );

    }

    /*inline*/ public function enableBlending():Void {

        Graphics.enableBlending();

    }

    /*inline*/ public function disableBlending():Void {

        Graphics.disableBlending();

    }

    /*inline*/ public function setActiveTexture(slot:Int):Void {

        _activeTextureSlot = slot;
        Graphics.setActiveTexture(slot);

    }

    /*inline*/ public function setRenderWireframe(value:Bool):Void {

        // TODO?

    }

    /*inline*/ public function getActiveTexture():Int {

        return _activeTextureSlot;

    }

    /*inline*/ public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

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

    /*inline*/ public function useShader(shader:backend.Shader):Void {
        
        _activeShader = shader;

        (shader:ShaderImpl).uniforms.setMatrix4('projectionMatrix', _projectionMatrix);
        (shader:ShaderImpl).uniforms.setMatrix4('modelViewMatrix', _modelViewMatrix);

        var shadersBackend = ceramic.App.app.backend.shaders;

        _floatAttributesSize = shadersBackend.customFloatAttributesSize(_activeShader);

        _vertexSize = 3 + _floatAttributesSize + (shadersBackend.canBatchWithMultipleTextures(_activeShader) ? 1 : 0);
        if (_vertexSize < 4)
            _vertexSize = 4;

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));
        
        (shader:ShaderImpl).activate();

        if (_numPos == 0) {
            resetIndexes();
        }

    }

    /*inline*/ function resetIndexes():Void {

        _numIndices = 0;

        _numPos = 0;
        _posIndex = 0;
        _uvIndex = 0;
        _colorIndex = 0;

    }

    /*inline*/ public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        Graphics.setBlendFuncSeparate(
            srcRgb,
            dstRgb,
            srcAlpha,
            dstAlpha
        );

    }

    /*inline*/ public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    /*inline*/ public function endDrawQuad():Void {

    }

    /*inline*/ public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    /*inline*/ public function endDrawMesh():Void {

    }

    /*inline*/ public function drawWithStencilTest():Void {

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilFunc(GL.EQUAL, 1, 0xFF);
        GL.stencilMask(0x00);
        GL.colorMask(true, true, true, true);

        GL.enable(GL.STENCIL_TEST);

    }

    /*inline*/ public function drawWithoutStencilTest():Void {

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(true, true, true, true);

        GL.disable(GL.STENCIL_TEST);

    }

    /*inline*/ public function beginDrawingInStencilBuffer():Void {
        
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

    /*inline*/ public function endDrawingInStencilBuffer():Void {
        
        _drawingInStencilBuffer = false;

    }

    /*inline*/ public function bindTexture(backendItem:backend.Texture):Void {

        Graphics.setActiveTexture(_activeTextureSlot);
        Graphics.bindTexture2d((backendItem:clay.graphics.Texture).textureId);

    }

    /*inline*/ public function bindNoTexture():Void {

        Graphics.bindTexture2d(Graphics.NO_TEXTURE);

    }

    /*inline*/ public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem:clay.graphics.Texture).textureId == textureId;

    }

    /*inline*/ public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem:clay.graphics.Texture).textureId;

    }

    /*inline*/ public function getTextureWidth(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).width;

    }

    /*inline*/ public function getTextureHeight(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).height;

    }

    /*inline*/ public function getTextureWidthActual(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).widthActual;

    }

    /*inline*/ public function getTextureHeightActual(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).heightActual;

    }

    /*inline*/ function updateProjectionMatrix(width:Float, height:Float):Void {

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

    /*inline*/ function updateViewMatrix(density:Float, width:Float, height:Float, ?transform:ceramic.Transform, flipY:Float = 1):Void {

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

    /*inline*/ function matrixIdentity(m:ceramic.Float32Array):Void {

        m[0] = 1;        m[4] = 0;        m[8] = 0;       m[12] = 0;
        m[1] = 0;        m[5] = 1;        m[9] = 0;       m[13] = 0;
        m[2] = 0;        m[6] = 0;        m[10] = 1;      m[14] = 0;
        m[3] = 0;        m[7] = 0;        m[11] = 0;      m[15] = 1;

    }

    /*inline*/ function setMatrixToTransform(m:ceramic.Float32Array, transform:ceramic.Transform):Void {

        m[0] = transform.a; m[4] = transform.c; m[8] = 0;   m[12] = transform.tx;
        m[1] = transform.b; m[5] = transform.d; m[9] = 0;   m[13] = transform.ty;
        m[2] = 0;           m[6] = 0;           m[10] = 1;  m[14] = 0;
        m[3] = 0;           m[7] = 0;           m[11] = 0;  m[15] = 1;

    }

    /*inline*/ public function getNumPos():Int {

        return _numPos;

    }

    /*inline*/ public function putPos(x:Float, y:Float, z:Float):Void {

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

    /*inline*/ public function putPosAndTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void {

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

    /*inline*/ public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    /*inline*/ public function putFloatAttribute(index:Int, value:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + index) * Float32Array.BYTES_PER_ELEMENT, value);
        #else
        _posList[_posIndex + index] = value;
        #end

    }

    /*inline*/ public function endFloatAttributes():Void {

        _posIndex += _floatAttributesSize;

    }

    /*inline*/ public function putIndice(i:Int):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setUint8(_indiceBuffer, _numIndices, i);
        #else
        _indiceList[_numIndices] = i;
        #end
        _numIndices++;

    }

    /*inline*/ public function putUVs(uvX:Float, uvY:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, _uvIndex * Float32Array.BYTES_PER_ELEMENT, uvX);
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, (_uvIndex + 1) * Float32Array.BYTES_PER_ELEMENT, uvY);
        #else
        _uvList[_uvIndex] = uvX;
        _uvList[_uvIndex + 1] = uvY;
        #end
        _uvIndex += 2;

    }

    /*inline*/ public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

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

    /*inline*/ public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    /*inline*/ public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {
        
        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);

    }

    /*inline*/ public function remainingVertices():Int {
        
        return _maxVerts - _numPos;

    }

    /*inline*/ public function remainingIndices():Int {
        
        return MAX_INDICES - _numIndices;

    }

    /*inline*/ public function flush():Void {

        throw 'TODO';

    }

}
