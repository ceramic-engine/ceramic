package backend;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

    #if !ceramic_debug_draw_backend inline #end static var MAX_VERTS_SIZE:Int = 65536;
    #if !ceramic_debug_draw_backend inline #end static var MAX_INDICES:Int = 16384;

    static var _vertexSize:Int = 0;
    static var _numIndices:Int = 0;

    static var _numPos:Int = 0;
    static var _posIndex:Int = 0;

    static var _numUVs:Int = 0;
    static var _uvIndex:Int = 0;

    static var _numColors:Int = 0;
    static var _colorIndex:Int = 0;

    static var _floatAttributesIndex:Int = 0;

    static var _currentShader:ShaderImpl;

    static var _maxVerts:Int = 0;

    static var _activeTextureSlot:Int = 0;

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

        // Unused in headless

    }

    public function swap():Void {

        // Unused in headless

    }

/// Rendering

    inline public function initBuffers():Void {

        // Unused in headless

    }

    inline public function beginRender():Void {

        // Unused in headless

    }

    inline public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        // Unused in headless

    }

    inline public function useShader(shader:backend.ShaderImpl):Void {

        _currentShader = shader;

        var attributesSize = ceramic.App.app.backend.shaders.customFloatAttributesSize(_currentShader);
        if (attributesSize % 2 == 1) attributesSize++;

        _vertexSize = 9 + attributesSize + (ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(_currentShader) ? 1 : 0);

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));

        if (_posIndex == 0) {
            resetIndexes();
        }

    }

    inline public function clear():Void {

        // Unused in headless

    }

    inline public function enableBlending():Void {

        // Unused in headless

    }

    inline public function disableBlending():Void {

        // Unused in headless

    }

    inline public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        // Unused in headless

    }

    inline public function getActiveTexture():Int {

        return _activeTextureSlot;

    }

    inline public function setActiveTexture(slot:Int):Void {

        _activeTextureSlot = slot;

    }

    inline public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem:TextureImpl).textureId == textureId;

    }

    inline public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem:TextureImpl).textureId;

    }

    inline public function getTextureWidth(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeight(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function getTextureWidthActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeightActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function bindTexture(backendItem:backend.Texture):Void {

        // Unused in headless

    }

    inline public function bindNoTexture():Void {

        // Unused in headless

    }

    inline public function setRenderWireframe(value:Bool):Void {

        // Unused in headless

    }

    inline public function beginDrawQuad(quad:ceramic.Quad):Void {

        // Unused in headless

    }

    inline public function endDrawQuad():Void {

        // Unused in headless

    }

    inline public function beginDrawMesh(mesh:ceramic.Mesh):Void {

        // Unused in headless

    }

    inline public function endDrawMesh():Void {

        // Unused in headless

    }

    inline public function enableScissor(x:Float, y:Float, width:Float, height:Float):Void {

        // Unused in headless

    }

    inline public function disableScissor():Void {

        // Unused in headless

    }

    inline public function beginDrawingInStencilBuffer():Void {

        // Unused in headless

    }

    inline public function endDrawingInStencilBuffer():Void {

        // Unused in headless

    }

    inline public function drawWithStencilTest():Void {

        // Unused in headless

    }

    inline public function drawWithoutStencilTest():Void {

        // Unused in headless

    }

    inline public function getNumPos():Int {

        return _numPos;

    }

    inline public function putPos(x:Float, y:Float, z:Float):Void {

        _posIndex += _vertexSize;
        _numPos++;

    }

    inline public function putPosAndTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void {

        _posIndex += _vertexSize;
        _numPos++;

    }

    inline public function putIndice(i:Int):Void {

        _numIndices++;

    }

    inline public function putUVs(uvX:Float, uvY:Float):Void {

        _numUVs++;
        _uvIndex += _vertexSize;

    }

    inline public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        _numColors++;
        _colorIndex += _vertexSize;

    }

    inline public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    inline public function putFloatAttribute(index:Int, value:Float):Void {

        // Unused in headless

    }

    inline public function endFloatAttributes():Void {

        _floatAttributesIndex += _vertexSize;

    }

    inline public function clearAndApplyBackground():Void {

        // Unused in headless

    }

    inline public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {

        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);

    }

    inline public function remainingVertices():Int {

        return _maxVerts - _numPos;

    }

    inline public function remainingIndices():Int {

        return MAX_INDICES - _numIndices;

    }

    inline public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    inline public function flush():Void {

        resetIndexes();

    }

    #if !ceramic_debug_draw_backend inline #end function resetIndexes():Void {

        _numIndices = 0;

        _numPos = 0;
        _posIndex = 0;

        if (ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(_currentShader)) {
            _numColors = 0;
            _colorIndex = 4;

            _numUVs = 0;
            _uvIndex = 8;

            _floatAttributesIndex = 10;
        }
        else {
            _numColors = 0;
            _colorIndex = 3;

            _numUVs = 0;
            _uvIndex = 7;

            _floatAttributesIndex = 9;
        }

    }

}
