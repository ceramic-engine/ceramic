package ceramic;

/**
 * A visual divided into 9 areas to create "nine-slice" textured scalable objects
 */
class NineSlice extends Visual {

    /**
     * Distance from top border to cut slices at the top
     */
    public var sliceTop(default, set):Float = 0;
    function set_sliceTop(sliceTop:Float):Float {
        if (this.sliceTop != sliceTop) {
            this.sliceTop = sliceTop;
            contentDirty = true;
        }
        return sliceTop;
    }

    /**
     * Distance from right border to cut slices on the right
     */
    public var sliceRight(default, set):Float = 0;
    function set_sliceRight(sliceRight:Float):Float {
        if (this.sliceRight != sliceRight) {
            this.sliceRight = sliceRight;
            contentDirty = true;
        }
        return sliceRight;
    }

    /**
     * Distance from bottom border to cut slices at the bottom
     */
    public var sliceBottom(default, set):Float = 0;
    function set_sliceBottom(sliceBottom:Float):Float {
        if (this.sliceBottom != sliceBottom) {
            this.sliceBottom = sliceBottom;
            contentDirty = true;
        }
        return sliceBottom;
    }

    /**
     * Distance from left border to cut slices on the left
     */
    public var sliceLeft(default, set):Float = 0;
    function set_sliceLeft(sliceLeft:Float):Float {
        if (this.sliceLeft != sliceLeft) {
            this.sliceLeft = sliceLeft;
            contentDirty = true;
        }
        return sliceLeft;
    }

    /**
     * Set distance from borders to cut slices.
     * This is equivalent to `slice(value, value, value, value)`
     */
    public extern inline overload function slice(value:Float)
        _slice(value, value, value, value);

    /**
     * Set distance from borders to cut slices.
     * This is equivalent to `slice(topBottom, leftRight, topBottom, leftRight)`
     */
    public extern inline overload function slice(topBottom:Float, leftRight:Float)
        _slice(topBottom, leftRight, topBottom, leftRight);

    /**
     * Set distance from borders to cut slices.
     * This is equivalent to setting `sliceTop`, `sliceRight`,
     * `sliceBottom` and `sliceLeft` properties.
     */
    public extern inline overload function slice(top:Float, right:Float, bottom:Float, left:Float)
        _slice(top, right, bottom, left);

    private function _slice(top:Float, right:Float, bottom:Float, left:Float) {

        this.sliceTop = top;
        this.sliceRight = right;
        this.sliceBottom = bottom;
        this.sliceLeft = left;

    }

    private var renderingDirty:Bool = true;

    public var innerRendering(default, set):NineSliceRendering = STRETCH;
    function set_innerRendering(innerRendering:NineSliceRendering):NineSliceRendering {
        if (this.innerRendering != innerRendering) {
            this.innerRendering = innerRendering;
            renderingDirty = true;
            contentDirty = true;
        }
        return this.innerRendering;
    }

    public var edgeRendering(default, set):NineSliceRendering = STRETCH;
    function set_edgeRendering(edgeRendering:NineSliceRendering):NineSliceRendering {
        if (this.edgeRendering != edgeRendering) {
            this.edgeRendering = edgeRendering;
            renderingDirty = true;
            contentDirty = true;
        }
        return this.edgeRendering;
    }

    public extern inline overload function rendering(value:NineSliceRendering)
        _rendering(value, value);

    public extern inline overload function rendering(innerRendering:NineSliceRendering, edgeRendering:NineSliceRendering)
        _rendering(innerRendering, edgeRendering);

    private function _rendering(innerRendering:NineSliceRendering, edgeRendering:NineSliceRendering) {

        this.innerRendering = innerRendering;
        this.edgeRendering = edgeRendering;

    }

    /**
     * The texture to use for this NineSlice object
     */
    public var texture(get,set):Texture;
    inline function get_texture():Texture {
        return quadTopLeft.texture;
    }
    inline function set_texture(texture:Texture):Texture {

        if (quadTopLeft.texture != texture) {
            _set_texture(texture);
        }

        return texture;
    }
    function _set_texture(texture:Texture):Void {

        if (quadTop != null) {
            quadTop.texture = texture;
            quadRight.texture = texture;
            quadBottom.texture = texture;
            quadLeft.texture = texture;
        }

        if (quadCenter != null) {
            quadCenter.texture = texture;
        }

        quadTopRight.texture = texture;
        quadBottomRight.texture = texture;
        quadBottomLeft.texture = texture;
        quadTopLeft.texture = texture;

        if (texture != null)
            size(texture.width, texture.height);

        contentDirty = true;

    }

    public var rotateFrame(get,set):Bool;
    inline function get_rotateFrame():Bool {
        return quadTopLeft.rotateFrame;
    }
    inline function set_rotateFrame(rotateFrame:Bool):Bool {

        if (quadTopLeft.rotateFrame != rotateFrame) {
            _set_rotateFrame(rotateFrame);
        }

        return rotateFrame;
    }
    function _set_rotateFrame(rotateFrame:Bool):Void {

        if (quadTop != null) {
            quadTop.rotateFrame = rotateFrame;
            quadRight.rotateFrame = rotateFrame;
            quadBottom.rotateFrame = rotateFrame;
            quadLeft.rotateFrame = rotateFrame;
        }

        if (quadCenter != null) {
            quadCenter.rotateFrame = rotateFrame;
        }

        quadTopRight.rotateFrame = rotateFrame;
        quadBottomRight.rotateFrame = rotateFrame;
        quadBottomLeft.rotateFrame = rotateFrame;
        quadTopLeft.rotateFrame = rotateFrame;

        contentDirty = true;

    }

    public var tile(default,set):TextureTile = null;
    inline function set_tile(tile:TextureTile):TextureTile {

        if (this.tile != tile) {
            this.tile = tile;
            _set_tile(tile);
        }

        return tile;
    }
    function _set_tile(tile:TextureTile):Void {

        var texture:Texture = null;

        if (tile != null) {
            texture = tile.texture;
        }

        if (quadTopLeft.texture != texture) {
            _set_texture(texture);
        }

        if (tile != null) {
            if (quadTopLeft.rotateFrame != tile.rotateFrame) {
                _set_rotateFrame(tile.rotateFrame);
            }

            size(tile.frameWidth, tile.frameHeight);
        }
        else {
            if (quadTopLeft.rotateFrame != false) {
                _set_rotateFrame(false);
            }
        }

        contentDirty = true;

    }

    override function set_width(width:Float):Float {
        if (_width == width) return width;
        super.set_width(width);
        contentDirty = true;
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        super.set_height(height);
        contentDirty = true;
        return height;
    }

    public var color(get,set):Color;
    inline function get_color():Color {
        return quadTopLeft.color;
    }
    inline function set_color(color:Color):Color {
        if (quadTopLeft.color != color) {
            _set_color(color);
        }
        return color;
    }
    function _set_color(color:Color):Color {

        if (quadTop != null) {
            quadTop.color = color;
            quadRight.color = color;
            quadBottom.color = color;
            quadLeft.color = color;
        }

        if (quadCenter != null) {
            quadCenter.color = color;
        }

        if (repeatTop != null) {
            repeatTop.color = color;
            repeatRight.color = color;
            repeatBottom.color = color;
            repeatLeft.color = color;
        }

        if (repeatCenter != null) {
            repeatCenter.color = color;
        }

        quadTopRight.color = color;
        quadBottomRight.color = color;
        quadBottomLeft.color = color;
        quadTopLeft.color = color;

        return color;
    }

    override function set_shader(shader:Shader):Shader {
        if (this.shader != shader) {
            this.shader = shader;
            _set_shader(shader);
        }
        return shader;
    }
    function _set_shader(shader:Shader):Shader {

        if (quadTop != null) {
            quadTop.shader = shader;
            quadRight.shader = shader;
            quadBottom.shader = shader;
            quadLeft.shader = shader;
        }

        if (quadCenter != null) {
            quadCenter.shader = shader;
        }

        if (repeatTop != null) {
            repeatTop.shader = shader;
            repeatRight.shader = shader;
            repeatBottom.shader = shader;
            repeatLeft.shader = shader;
        }

        if (repeatCenter != null) {
            repeatCenter.shader = shader;
        }

        quadTopRight.shader = shader;
        quadBottomRight.shader = shader;
        quadBottomLeft.shader = shader;
        quadTopLeft.shader = shader;

        return shader;
    }

    var quadTop:Quad = null;

    var quadRight:Quad = null;

    var quadBottom:Quad = null;

    var quadLeft:Quad = null;

    var quadCenter:Quad = null;

    var repeatTop:Repeat = null;

    var repeatRight:Repeat = null;

    var repeatBottom:Repeat = null;

    var repeatLeft:Repeat = null;

    var repeatCenter:Repeat = null;

    var quadTopRight:Quad;

    var quadBottomRight:Quad;

    var quadBottomLeft:Quad;

    var quadTopLeft:Quad;

    public function new() {

        super();

        createCornerQuads();

    }

    #if !ceramic_soft_inline inline #end function createCornerQuads() {

        quadTopRight = new Quad();
        quadTopRight.inheritAlpha = true;
        add(quadTopRight);

        quadBottomRight = new Quad();
        quadBottomRight.inheritAlpha = true;
        add(quadBottomRight);

        quadBottomLeft = new Quad();
        quadBottomLeft.inheritAlpha = true;
        add(quadBottomLeft);

        quadTopLeft = new Quad();
        quadTopLeft.inheritAlpha = true;
        add(quadTopLeft);

    }

    #if !ceramic_soft_inline inline #end function createCenterQuad() {

        if (quadCenter == null) {
            quadCenter = new Quad();
            quadCenter.texture = texture;
            quadCenter.rotateFrame = rotateFrame;
            quadCenter.color = color;
            quadCenter.shader = shader;
            quadCenter.inheritAlpha = true;
            add(quadCenter);
        }

    }

    #if !ceramic_soft_inline inline #end function destroyCenterQuad() {

        if (quadCenter != null) {
            quadCenter.destroy();
            quadCenter = null;
        }

    }

    #if !ceramic_soft_inline inline #end function createEdgeQuads() {

        if (quadTop == null) {
            quadTop = new Quad();
            quadTop.texture = texture;
            quadTop.rotateFrame = rotateFrame;
            quadTop.color = color;
            quadTop.shader = shader;
            quadTop.inheritAlpha = true;
            add(quadTop);
        }

        if (quadRight == null) {
            quadRight = new Quad();
            quadRight.texture = texture;
            quadRight.rotateFrame = rotateFrame;
            quadRight.color = color;
            quadRight.shader = shader;
            quadRight.inheritAlpha = true;
            add(quadRight);
        }

        if (quadBottom == null) {
            quadBottom = new Quad();
            quadBottom.texture = texture;
            quadBottom.rotateFrame = rotateFrame;
            quadBottom.color = color;
            quadBottom.shader = shader;
            quadBottom.inheritAlpha = true;
            add(quadBottom);
        }

        if (quadLeft == null) {
            quadLeft = new Quad();
            quadLeft.texture = texture;
            quadLeft.rotateFrame = rotateFrame;
            quadLeft.color = color;
            quadLeft.shader = shader;
            quadLeft.inheritAlpha = true;
            add(quadLeft);
        }

    }

    #if !ceramic_soft_inline inline #end function destroyEdgeQuads() {

        if (quadTop != null) {
            quadTop.destroy();
            quadTop = null;
        }

        if (quadRight != null) {
            quadRight.destroy();
            quadRight = null;
        }

        if (quadBottom != null) {
            quadBottom.destroy();
            quadBottom = null;
        }

        if (quadLeft != null) {
            quadLeft.destroy();
            quadLeft = null;
        }

    }

    #if !ceramic_soft_inline inline #end function createCenterRepeat(rendering:NineSliceRendering) {

        if (repeatCenter == null) {
            repeatCenter = new Repeat();
            repeatCenter.inheritAlpha = true;
            repeatCenter.mirror(rendering == MIRROR);
            add(repeatCenter);
        }

    }

    #if !ceramic_soft_inline inline #end function destroyCenterRepeat() {

        if (repeatCenter != null) {
            repeatCenter.destroy();
            repeatCenter = null;
        }

    }

    #if !ceramic_soft_inline inline #end function createEdgeRepeats(rendering:NineSliceRendering) {

        if (repeatTop == null) {
            repeatTop = new Repeat();
            repeatTop.inheritAlpha = true;
            repeatTop.mirror(rendering == MIRROR);
            add(repeatTop);
        }

        if (repeatRight == null) {
            repeatRight = new Repeat();
            repeatRight.inheritAlpha = true;
            repeatRight.mirror(rendering == MIRROR);
            add(repeatRight);
        }

        if (repeatBottom == null) {
            repeatBottom = new Repeat();
            repeatBottom.inheritAlpha = true;
            repeatBottom.mirror(rendering == MIRROR);
            add(repeatBottom);
        }

        if (repeatLeft == null) {
            repeatLeft = new Repeat();
            repeatLeft.inheritAlpha = true;
            repeatLeft.mirror(rendering == MIRROR);
            add(repeatLeft);
        }

    }

    #if !ceramic_soft_inline inline #end function destroyEdgeRepeats() {

        if (repeatTop != null) {
            repeatTop.destroy();
            repeatTop = null;
        }

        if (repeatRight != null) {
            repeatRight.destroy();
            repeatRight = null;
        }

        if (repeatBottom != null) {
            repeatBottom.destroy();
            repeatBottom = null;
        }

        if (repeatLeft != null) {
            repeatLeft.destroy();
            repeatLeft = null;
        }

    }

    function syncQuadsAndRepeats() {

        switch edgeRendering {
            case NONE:
                destroyEdgeQuads();
                destroyEdgeRepeats();

            case STRETCH:
                createEdgeQuads();
                destroyEdgeRepeats();

            case REPEAT | MIRROR:
                destroyEdgeQuads();
                createEdgeRepeats(edgeRendering);
        }

        switch innerRendering {
            case NONE:
                destroyCenterQuad();
                destroyCenterRepeat();

            case STRETCH:
                createCenterQuad();
                destroyCenterRepeat();

            case REPEAT | MIRROR:
                destroyCenterQuad();
                createCenterRepeat(edgeRendering);
        }

    }

    #if !ceramic_soft_inline inline #end function updateRepeatTile(
        repeat:Repeat,
        texture:Texture, rotateFrame:Bool,
        texX:Float, texY:Float, texWidth:Float, texHeight:Float,
        frameX:Float, frameY:Float,
        frameWidth:Float, frameHeight:Float) {

        var tile = repeat.tile;

        if (rotateFrame) {
            var _frameX = frameX;
            frameX = texX + frameY - texY;
            frameY = texY + texWidth - _frameX + texX - frameWidth;
        }

        if (tile == null) {
            tile = new TextureTile(texture, frameX, frameY, frameWidth, frameHeight, rotateFrame);
            repeat.tile = tile;
        }
        else {
            var changed = false;
            if (tile.texture != texture) {
                changed = true;
                tile.texture = texture;
            }
            if (tile.frameX != frameX) {
                changed = true;
                tile.frameX = frameX;
            }
            if (tile.frameY != frameY) {
                changed = true;
                tile.frameY = frameY;
            }
            if (tile.frameWidth != frameWidth) {
                changed = true;
                tile.frameWidth = frameWidth;
            }
            if (tile.frameHeight != frameHeight) {
                changed = true;
                tile.frameHeight = frameHeight;
            }
            if (tile.rotateFrame != rotateFrame) {
                changed = true;
                tile.rotateFrame = rotateFrame;
            }
            if (changed) {
                // This will force Repeat object to update
                // its internal values from changed tile
                repeat.tile = null;
                repeat.tile = tile;
            }
        }

        return tile;

    }

    override function computeContent() {

        if (renderingDirty) {
            syncQuadsAndRepeats();
        }

        var w = _width;
        var h = _height;

        if (w < sliceLeft + sliceRight || h < sliceTop + sliceBottom) {
            // Can't display if the area is not big enough
            if (quadTop != null) {
                quadTop.active = false;
                quadRight.active = false;
                quadBottom.active = false;
                quadLeft.active = false;
            }
            if (quadCenter != null) {
                quadCenter.active = false;
            }
            if (repeatTop != null) {
                repeatTop.active = false;
                repeatRight.active = false;
                repeatBottom.active = false;
                repeatLeft.active = false;
            }
            if (repeatCenter != null) {
                repeatCenter.active = false;
            }
            quadTopRight.active = false;
            quadBottomRight.active = false;
            quadBottomLeft.active = false;
            quadTopLeft.active = false;
        }
        else {
            if (quadTop != null) {
                quadTop.active = true;
                quadRight.active = true;
                quadBottom.active = true;
                quadLeft.active = true;
            }
            if (quadCenter != null) {
                quadCenter.active = true;
            }
            if (repeatTop != null) {
                repeatTop.active = true;
                repeatRight.active = true;
                repeatBottom.active = true;
                repeatLeft.active = true;
            }
            if (repeatCenter != null) {
                repeatCenter.active = true;
            }
            quadTopRight.active = true;
            quadBottomRight.active = true;
            quadBottomLeft.active = true;
            quadTopLeft.active = true;

            var top = sliceTop;
            var right = sliceRight;
            var bottom = sliceBottom;
            var left = sliceLeft;

            var texture = this.texture;
            var tile = this.tile;
            var rotateFrame = this.rotateFrame;
            var texX:Float = 0.0;
            var texY:Float = 0.0;
            var texWidth:Float = 0.0;
            var texHeight:Float = 0.0;

            if (tile != null) {
                texWidth = tile.frameWidth;
                texHeight = tile.frameHeight;
                texX = tile.frameX;
                texY = tile.frameY;
            }
            else if (texture != null) {
                texWidth = texture.width;
                texHeight = texture.height;
            }

            if (quadTop != null) {
                quadTop.frame(
                    texX + left,
                    texY,
                    texWidth - left - right,
                    top
                );
                quadRight.frame(
                    texX + texWidth - right,
                    texY + top,
                    right,
                    texHeight - top - bottom
                );
                quadBottom.frame(
                    texX + left,
                    texY + texHeight - bottom,
                    texWidth - left - right,
                    bottom
                );
                quadLeft.frame(
                    texX,
                    texY + top,
                    left,
                    texHeight - top - bottom
                );
            }
            if (quadCenter != null) {
                quadCenter.frame(
                    texX + left,
                    texY + top,
                    texWidth - left - right,
                    texHeight - top - bottom
                );
            }
            if (repeatTop != null) {
                updateRepeatTile(
                    repeatTop,
                    texture, rotateFrame,
                    texX, texY, texWidth, texHeight,
                    texX + left,
                    texY,
                    texWidth - left - right,
                    top
                );
                updateRepeatTile(
                    repeatRight,
                    texture, rotateFrame,
                    texX, texY, texWidth, texHeight,
                    texX + texWidth - right,
                    texY + top,
                    right,
                    texHeight - top - bottom
                );
                updateRepeatTile(
                    repeatBottom,
                    texture, rotateFrame,
                    texX, texY, texWidth, texHeight,
                    texX + left,
                    texY + texHeight - bottom,
                    texWidth - left - right,
                    bottom
                );
                updateRepeatTile(
                    repeatLeft,
                    texture, rotateFrame,
                    texX, texY, texWidth, texHeight,
                    texX,
                    texY + top,
                    left,
                    texHeight - top - bottom
                );
            }
            if (repeatCenter != null) {
                updateRepeatTile(
                    repeatCenter,
                    texture, rotateFrame,
                    texX, texY, texWidth, texHeight,
                    texX + left,
                    texY + top,
                    texWidth - left - right,
                    texHeight - top - bottom
                );
            }
            quadTopRight.frame(
                texX + texWidth - right,
                texY,
                right,
                top
            );
            quadBottomRight.frame(
                texX + texWidth - right,
                texY + texHeight - bottom,
                right,
                bottom
            );
            quadBottomLeft.frame(
                texX,
                texY + texHeight - bottom,
                left,
                bottom
            );
            quadTopLeft.frame(
                texX,
                texY,
                left,
                top
            );

            if (rotateFrame) {
                // When rotating the original frame, we need
                // to adapt coordinates of each slices
                inline function _rotateQuadFrame(quad:Quad) {
                    if (quad != null) {
                        var _frameX = quad.frameX;
                        quad.frameX = texX + quad.frameY - texY;
                        quad.frameY = texY + texWidth - _frameX + texX - quad.frameWidth;
                    }
                }
                _rotateQuadFrame(quadTop);
                _rotateQuadFrame(quadTopRight);
                _rotateQuadFrame(quadRight);
                _rotateQuadFrame(quadBottomRight);
                _rotateQuadFrame(quadBottom);
                _rotateQuadFrame(quadBottomLeft);
                _rotateQuadFrame(quadLeft);
                _rotateQuadFrame(quadTopLeft);
                _rotateQuadFrame(quadCenter);
            }

            if (quadTop != null) {
                quadTop.pos(left, 0);
                quadTop.size(w - left - right, top);

                quadRight.pos(w - right, top);
                quadRight.size(right, h - top - bottom);

                quadBottom.pos(left, h - bottom);
                quadBottom.size(w - left - right, bottom);

                quadLeft.pos(0, top);
                quadLeft.size(left, h - top - bottom);
            }

            if (quadCenter != null) {
                quadCenter.pos(left, top);
                quadCenter.size(w - left - right, h - top - bottom);
            }

            if (repeatTop != null) {
                repeatTop.pos(left, 0);
                repeatTop.size(w - left - right, top);

                repeatRight.pos(w - right, top);
                repeatRight.size(right, h - top - bottom);

                repeatBottom.pos(left, h - bottom);
                repeatBottom.size(w - left - right, bottom);

                repeatLeft.pos(0, top);
                repeatLeft.size(left, h - top - bottom);
            }

            if (repeatCenter != null) {
                repeatCenter.pos(left, top);
                repeatCenter.size(w - left - right, h - top - bottom);
            }

            quadTopRight.pos(w - right, 0);
            quadTopRight.size(right, top);

            quadBottomRight.pos(w - right, h - bottom);
            quadBottomRight.size(right, bottom);

            quadBottomLeft.pos(0, h - bottom);
            quadBottomLeft.size(left, bottom);

            quadTopLeft.pos(0, 0);
            quadTopLeft.size(left, top);
        }

        contentDirty = false;

    }

}
