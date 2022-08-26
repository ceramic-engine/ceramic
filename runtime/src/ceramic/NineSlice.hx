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

    /**
     * The texture to use for this NineSlice object
     */
    public var texture(get,set):Texture;
    inline function get_texture():Texture {
        return quadCenter.texture;
    }
    inline function set_texture(texture:Texture):Texture {

        if (quadCenter.texture != texture) {
            _set_texture(texture);
        }

        return texture;
    }
    function _set_texture(texture:Texture):Void {

        quadTop.texture = texture;
        quadTopRight.texture = texture;
        quadRight.texture = texture;
        quadBottomRight.texture = texture;
        quadBottom.texture = texture;
        quadBottomLeft.texture = texture;
        quadLeft.texture = texture;
        quadTopLeft.texture = texture;
        quadCenter.texture = texture;

        if (texture != null)
            size(texture.width, texture.height);

        contentDirty = true;

    }

    public var rotateFrame(get,set):Bool;
    inline function get_rotateFrame():Bool {
        return quadCenter.rotateFrame;
    }
    inline function set_rotateFrame(rotateFrame:Bool):Bool {

        if (quadCenter.rotateFrame != rotateFrame) {
            _set_rotateFrame(rotateFrame);
        }

        return rotateFrame;
    }
    function _set_rotateFrame(rotateFrame:Bool):Void {

        quadTop.rotateFrame = rotateFrame;
        quadTopRight.rotateFrame = rotateFrame;
        quadRight.rotateFrame = rotateFrame;
        quadBottomRight.rotateFrame = rotateFrame;
        quadBottom.rotateFrame = rotateFrame;
        quadBottomLeft.rotateFrame = rotateFrame;
        quadLeft.rotateFrame = rotateFrame;
        quadTopLeft.rotateFrame = rotateFrame;
        quadCenter.rotateFrame = rotateFrame;

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

        if (quadCenter.texture != texture) {
            _set_texture(texture);
        }

        if (tile != null) {
            if (quadCenter.rotateFrame != tile.rotateFrame) {
                _set_rotateFrame(tile.rotateFrame);
            }

            size(tile.frameWidth, tile.frameHeight);
        }
        else {
            if (quadCenter.rotateFrame != false) {
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
        return quadCenter.color;
    }
    inline function set_color(color:Color):Color {
        if (quadCenter.color != color) {
            _set_color(color);
        }
        return color;
    }
    function _set_color(color:Color):Color {

        quadTop.color = color;
        quadTopRight.color = color;
        quadRight.color = color;
        quadBottomRight.color = color;
        quadBottom.color = color;
        quadBottomLeft.color = color;
        quadLeft.color = color;
        quadTopLeft.color = color;
        quadCenter.color = color;

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

        quadTop.shader = shader;
        quadTopRight.shader = shader;
        quadRight.shader = shader;
        quadBottomRight.shader = shader;
        quadBottom.shader = shader;
        quadBottomLeft.shader = shader;
        quadLeft.shader = shader;
        quadTopLeft.shader = shader;
        quadCenter.shader = shader;

        return shader;
    }

    var quadTop:Quad;

    var quadTopRight:Quad;

    var quadRight:Quad;

    var quadBottomRight:Quad;

    var quadBottom:Quad;

    var quadBottomLeft:Quad;

    var quadLeft:Quad;

    var quadTopLeft:Quad;

    var quadCenter:Quad;

    public function new() {

        super();

        quadTop = new Quad();
        add(quadTop);

        quadTopRight = new Quad();
        add(quadTopRight);

        quadRight = new Quad();
        add(quadRight);

        quadBottomRight = new Quad();
        add(quadBottomRight);

        quadBottom = new Quad();
        add(quadBottom);

        quadBottomLeft = new Quad();
        add(quadBottomLeft);

        quadLeft = new Quad();
        add(quadLeft);

        quadTopLeft = new Quad();
        add(quadTopLeft);

        quadCenter = new Quad();
        add(quadCenter);

    }

    override function computeContent() {

        var w = _width;
        var h = _height;

        if (w < sliceLeft + sliceRight || h < sliceTop + sliceBottom) {
            // Can't display if the area is not big enough
            quadTop.active = false;
            quadTopRight.active = false;
            quadRight.active = false;
            quadBottomRight.active = false;
            quadBottom.active = false;
            quadBottomLeft.active = false;
            quadLeft.active = false;
            quadTopLeft.active = false;
            quadCenter.active = false;
        }
        else {
            quadTop.active = true;
            quadTopRight.active = true;
            quadRight.active = true;
            quadBottomRight.active = true;
            quadBottom.active = true;
            quadBottomLeft.active = true;
            quadLeft.active = true;
            quadTopLeft.active = true;
            quadCenter.active = true;

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

            quadTop.frame(
                texX + left,
                texY,
                texWidth - left - right,
                top
            );
            quadTopRight.frame(
                texX + texWidth - right,
                texY,
                right,
                top
            );
            quadRight.frame(
                texX + texWidth - right,
                texY + top,
                right,
                texHeight - top - bottom
            );
            quadBottomRight.frame(
                texX + texWidth - right,
                texY + texHeight - bottom,
                right,
                bottom
            );
            quadBottom.frame(
                texX + left,
                texY + texHeight - bottom,
                texWidth - left - right,
                bottom
            );
            quadBottomLeft.frame(
                texX,
                texY + texHeight - bottom,
                left,
                bottom
            );
            quadLeft.frame(
                texX,
                texY + top,
                left,
                texHeight - top - bottom
            );
            quadTopLeft.frame(
                texX,
                texY,
                left,
                top
            );
            quadCenter.frame(
                texX + left,
                texY + top,
                texWidth - left - right,
                texHeight - top - bottom
            );

            if (rotateFrame) {
                // When rotating the original frame, we need
                // to adapt coordinates of each slices
                inline function _rotateQuadFrame(quad:Quad) {
                    quad.frame(
                        texX + quad.frameY - texY,
                        texY + texWidth - quad.frameX + texX - quad.frameWidth,
                        quad.frameWidth,
                        quad.frameHeight
                    );
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

            quadTop.pos(left, 0);
            quadTop.size(w - left - right, top);

            quadTopRight.pos(w - right, 0);
            quadTopRight.size(right, top);

            quadRight.pos(w - right, top);
            quadRight.size(right, h - top - bottom);

            quadBottomRight.pos(w - right, h - bottom);
            quadBottomRight.size(right, bottom);

            quadBottom.pos(left, h - bottom);
            quadBottom.size(w - left - right, bottom);

            quadBottomLeft.pos(0, h - bottom);
            quadBottomLeft.size(left, bottom);

            quadLeft.pos(0, top);
            quadLeft.size(left, h - top - bottom);

            quadTopLeft.pos(0, 0);
            quadTopLeft.size(left, top);

            quadCenter.pos(left, top);
            quadCenter.size(w - left - right, h - top - bottom);
        }

        contentDirty = false;

    }

}
