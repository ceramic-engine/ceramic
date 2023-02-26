package ceramic;

import ceramic.Assert.assert;

using ceramic.Extensions;

class Repeat extends Visual {

    static var _pool(default, null):Pool<Quad> = null;

    static function _getQuad():Quad {

        var result:Quad = null;
        if (_pool != null) {
            result = _pool.get();
        }
        if (result == null) {
            result = new Quad();
        }
        else {
            result.active = true;
        }
        return result;

    }

    function _recycleQuad(quad:Quad):Void {

        if (quad.parent != null) {
            quad.parent.remove(quad);
        }

        quad.active = false;

        if (_pool == null) {
            _pool = new Pool<Quad>();
        }

        _pool.recycle(quad);

    }

    public var quads(default,null):Array<Quad> = [];

    public var spacingX(default, set):Float = 0;
    function set_spacingX(spacingX:Float):Float {
        if (this.spacingX != spacingX) {
            this.spacingX = spacingX;
            contentDirty = true;
        }
        return spacingX;
    }

    public var spacingY(default, set):Float = 0;
    function set_spacingY(spacingY:Float):Float {
        if (this.spacingY != spacingY) {
            this.spacingY = spacingY;
            contentDirty = true;
        }
        return spacingY;
    }

    public extern inline overload function spacing(value:Float)
        _spacing(value, value);

    public extern inline overload function spacing(spacingX:Float, spacingY:Float)
        _spacing(spacingX, spacingY);

    private function _spacing(spacingX:Float, spacingY:Float) {

        this.spacingX = spacingX;
        this.spacingY = spacingY;

    }

    public var repeatX(default, set):Bool = true;
    function set_repeatX(repeatX:Bool):Bool {
        if (this.repeatX != repeatX) {
            this.repeatX = repeatX;
            contentDirty = true;
        }
        return repeatX;
    }

    public var repeatY(default, set):Bool = true;
    function set_repeatY(repeatY:Bool):Bool {
        if (this.repeatY != repeatY) {
            this.repeatY = repeatY;
            contentDirty = true;
        }
        return repeatY;
    }

    public extern inline overload function repeat(value:Bool)
        _repeat(value, value);

    public extern inline overload function repeat(repeatX:Bool, repeatY:Bool)
        _repeat(repeatX, repeatY);

    private function _repeat(repeatX:Bool, repeatY:Bool) {

        this.repeatX = repeatX;
        this.repeatY = repeatY;

    }

    public var mirrorX(default,set):Bool = false;
    inline function set_mirrorX(mirrorX:Bool):Bool {
        if (this.mirrorX != mirrorX) {
            this.mirrorX = mirrorX;
            contentDirty = true;
        }
        return mirrorX;
    }

    public var mirrorY(default,set):Bool = false;
    inline function set_mirrorY(mirrorY:Bool):Bool {
        if (this.mirrorY != mirrorY) {
            this.mirrorY = mirrorY;
            contentDirty = true;
        }
        return mirrorY;
    }

    public extern inline overload function mirror(value:Bool)
        _mirror(value, value);

    public extern inline overload function mirror(mirrorX:Bool, mirrorY:Bool)
        _mirror(mirrorX, mirrorY);

    private function _mirror(mirrorX:Bool, mirrorY:Bool) {

        this.mirrorX = mirrorX;
        this.mirrorY = mirrorY;

    }

    /**
     * The texture to use for this NineSlice object
     */
    public var texture(get,set):Texture;
    inline function get_texture():Texture {
        return quads.unsafeGet(0).texture;
    }
    inline function set_texture(texture:Texture):Texture {

        if (quads.unsafeGet(0).texture != texture) {
            _set_texture(texture);
        }

        return texture;
    }
    function _set_texture(texture:Texture):Void {

        for (i in 0...quads.length) {
            quads.unsafeGet(i).texture = texture;
        }

        contentDirty = true;

    }

    public var rotateFrame(get,set):Bool;
    inline function get_rotateFrame():Bool {
        return quads.unsafeGet(0).rotateFrame;
    }
    inline function set_rotateFrame(rotateFrame:Bool):Bool {

        if (quads.unsafeGet(0).rotateFrame != rotateFrame) {
            _set_rotateFrame(rotateFrame);
        }

        return rotateFrame;
    }
    function _set_rotateFrame(rotateFrame:Bool):Void {

        for (i in 0...quads.length) {
            quads.unsafeGet(i).rotateFrame = rotateFrame;
        }

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

        if (quads.unsafeGet(0).texture != texture) {
            _set_texture(texture);
        }

        if (tile != null) {
            if (quads.unsafeGet(0).rotateFrame != tile.rotateFrame) {
                _set_rotateFrame(tile.rotateFrame);
            }

            size(tile.frameWidth, tile.frameHeight);
        }
        else {
            if (quads.unsafeGet(0).rotateFrame != false) {
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
        return quads.unsafeGet(0).color;
    }
    inline function set_color(color:Color):Color {
        if (quads.unsafeGet(0).color != color) {
            _set_color(color);
        }
        return color;
    }
    function _set_color(color:Color):Color {

        for (i in 0...quads.length) {
            quads.unsafeGet(i).color = color;
        }

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

        for (i in 0...quads.length) {
            quads.unsafeGet(i).shader = shader;
        }

        return shader;
    }

    public function new() {

        super();

        quads.push(_getQuad());
        add(quads.unsafeGet(0));
        quads.unsafeGet(0).inheritAlpha = true;

    }

    override function computeContent() {

        var w = _width;
        var h = _height;
        var texture = this.texture;
        var shader = this.shader;
        var color = this.color;
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

        var usedQuads = 0;
        if (w <= 0 || h <= 0) {
            quads.unsafeGet(0).active = false;
        }
        else {
            var stepX = repeatX ? texWidth : w;
            var stepY = repeatY ? texHeight : h;
            var x = 0.0;
            var y = 0.0;
            var col:Int = 0;
            var row:Int = 0;

            while (y < h) {
                col = 0;
                x = 0;
                while (x < w) {

                    var quad:Quad = usedQuads < quads.length ? quads[usedQuads] : null;
                    if (quad == null) {
                        quad = _getQuad();
                        quad.inheritAlpha = true;
                        quads.push(quad);
                        add(quad);
                    }
                    usedQuads++;

                    var tileW = Math.min(stepX, w - x);
                    var tileH = Math.min(stepY, h - y);
                    var flipX = mirrorX && (col % 2 == 1);
                    var flipY = mirrorY && (row % 2 == 1);
                    var usedTexX = flipX ? (texX + texWidth - tileW) : texX;
                    var usedTexY = flipY ? (texY + texHeight - tileH) : texY;
                    var usedTexW = Math.min(texWidth, tileW);
                    var usedTexH = Math.min(texHeight, tileH);

                    quad.texture = texture;
                    quad.color = color;
                    quad.shader = shader;
                    quad.frame(
                        usedTexX,
                        usedTexY,
                        usedTexW,
                        usedTexH
                    );
                    if (rotateFrame) {
                        quad.frame(
                            texX + quad.frameY - texY,
                            texY + texWidth - quad.frameX + texX - quad.frameWidth,
                            quad.frameWidth,
                            quad.frameHeight
                        );
                    }
                    quad.pos(x, y);
                    quad.size(
                        tileW,
                        tileH
                    );
                    quad.anchor(
                        flipX ? 1 : 0,
                        flipY ? 1 : 0
                    );
                    quad.scale(
                        flipX ? -1 : 1,
                        flipY ? -1 : 1
                    );

                    x += stepX + spacingX;
                    col++;
                }
                y += stepY + spacingY;
                row++;
            }
        }

        if (usedQuads == 0)
            usedQuads = 1;
        while (quads.length > usedQuads) {
            _recycleQuad(quads.pop());
        }

        contentDirty = false;

    }

}
