package ceramic;

import ceramic.Assert.assert;

using ceramic.Extensions;

/**
 * A visual component that repeats a texture pattern to fill a specified area.
 * 
 * The Repeat class efficiently tiles a texture (or texture region) across a
 * rectangular area, creating patterns like tiled backgrounds, repeating borders,
 * or texture fills. It automatically manages Quad instances from an object pool
 * to minimize memory allocation and improve performance.
 * 
 * Key features:
 * - Automatic texture tiling in X and/or Y directions
 * - Optional mirroring for seamless patterns
 * - Spacing between tiles
 * - Efficient object pooling of Quad instances
 * - Support for TextureTile regions
 * 
 * Example usage:
 * ```haxe
 * // Create a repeating background pattern
 * var background = new Repeat();
 * background.texture = assets.texture("pattern");
 * background.size(screen.width, screen.height);
 * background.spacing(2, 2); // 2px gap between tiles
 * 
 * // Create a horizontally repeating border
 * var border = new Repeat();
 * border.tile = atlas.get("border_segment");
 * border.size(400, 32);
 * border.repeatY = false; // Only repeat horizontally
 * 
 * // Create a mirrored pattern for seamless tiling
 * var seamless = new Repeat();
 * seamless.texture = assets.texture("tile");
 * seamless.mirror(true, true); // Mirror in both directions
 * seamless.size(800, 600);
 * ```
 * 
 * Performance note: The class reuses Quad instances from a pool, so creating
 * and destroying Repeat objects frequently has minimal performance impact.
 * 
 * @see ceramic.Quad For the underlying visual elements
 * @see ceramic.TextureTile For texture region support
 * @see ceramic.NineSlice For non-repeating scalable graphics
 */
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

    /**
     * Array of Quad instances used to render the repeated pattern.
     * Managed automatically by the class - do not modify directly.
     */
    public var quads(default,null):Array<Quad> = [];

    /**
     * Horizontal spacing between repeated tiles in pixels.
     * Positive values create gaps between tiles.
     */
    public var spacingX(default, set):Float = 0;
    function set_spacingX(spacingX:Float):Float {
        if (this.spacingX != spacingX) {
            this.spacingX = spacingX;
            contentDirty = true;
        }
        return spacingX;
    }

    /**
     * Vertical spacing between repeated tiles in pixels.
     * Positive values create gaps between tiles.
     */
    public var spacingY(default, set):Float = 0;
    function set_spacingY(spacingY:Float):Float {
        if (this.spacingY != spacingY) {
            this.spacingY = spacingY;
            contentDirty = true;
        }
        return spacingY;
    }

    /**
     * Sets spacing between tiles.
     * @overload function(value:Float):Void Sets both X and Y spacing to the same value
     * @overload function(spacingX:Float, spacingY:Float):Void Sets X and Y spacing independently
     */
    public extern inline overload function spacing(value:Float)
        _spacing(value, value);

    public extern inline overload function spacing(spacingX:Float, spacingY:Float)
        _spacing(spacingX, spacingY);

    private function _spacing(spacingX:Float, spacingY:Float) {

        this.spacingX = spacingX;
        this.spacingY = spacingY;

    }

    /**
     * Whether to repeat the texture horizontally.
     * When false, the texture is stretched to fill the width instead of tiling.
     */
    public var repeatX(default, set):Bool = true;
    function set_repeatX(repeatX:Bool):Bool {
        if (this.repeatX != repeatX) {
            this.repeatX = repeatX;
            contentDirty = true;
        }
        return repeatX;
    }

    /**
     * Whether to repeat the texture vertically.
     * When false, the texture is stretched to fill the height instead of tiling.
     */
    public var repeatY(default, set):Bool = true;
    function set_repeatY(repeatY:Bool):Bool {
        if (this.repeatY != repeatY) {
            this.repeatY = repeatY;
            contentDirty = true;
        }
        return repeatY;
    }

    /**
     * Controls texture repetition.
     * @overload function(value:Bool):Void Enable/disable repetition in both directions
     * @overload function(repeatX:Bool, repeatY:Bool):Void Control X and Y repetition independently
     */
    public extern inline overload function repeat(value:Bool)
        _repeat(value, value);

    public extern inline overload function repeat(repeatX:Bool, repeatY:Bool)
        _repeat(repeatX, repeatY);

    private function _repeat(repeatX:Bool, repeatY:Bool) {

        this.repeatX = repeatX;
        this.repeatY = repeatY;

    }

    /**
     * Whether to mirror alternate tiles horizontally.
     * Creates a seamless pattern by flipping every other column.
     */
    public var mirrorX(default,set):Bool = false;
    inline function set_mirrorX(mirrorX:Bool):Bool {
        if (this.mirrorX != mirrorX) {
            this.mirrorX = mirrorX;
            contentDirty = true;
        }
        return mirrorX;
    }

    /**
     * Whether to mirror alternate tiles vertically.
     * Creates a seamless pattern by flipping every other row.
     */
    public var mirrorY(default,set):Bool = false;
    inline function set_mirrorY(mirrorY:Bool):Bool {
        if (this.mirrorY != mirrorY) {
            this.mirrorY = mirrorY;
            contentDirty = true;
        }
        return mirrorY;
    }

    /**
     * Controls texture mirroring for seamless patterns.
     * @overload function(value:Bool):Void Enable/disable mirroring in both directions
     * @overload function(mirrorX:Bool, mirrorY:Bool):Void Control X and Y mirroring independently
     */
    public extern inline overload function mirror(value:Bool)
        _mirror(value, value);

    public extern inline overload function mirror(mirrorX:Bool, mirrorY:Bool)
        _mirror(mirrorX, mirrorY);

    private function _mirror(mirrorX:Bool, mirrorY:Bool) {

        this.mirrorX = mirrorX;
        this.mirrorY = mirrorY;

    }

    /**
     * The texture to repeat across the area.
     * Setting this will clear any previously set tile.
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

    /**
     * Whether the texture frame is rotated 90 degrees.
     * Used internally for texture atlas optimization.
     */
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

    /**
     * A texture tile (region) to repeat instead of a full texture.
     * Setting this will automatically update the texture and frame properties.
     */
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

    /**
     * The color tint applied to all repeated tiles.
     * White (0xFFFFFF) means no tinting.
     */
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

    /**
     * Creates a new Repeat instance.
     * Initializes with a single Quad that will be replicated as needed.
     */
    public function new() {

        super();

        quads.push(_getQuad());
        add(quads.unsafeGet(0));
        quads.unsafeGet(0).inheritAlpha = true;

    }

    /**
     * Recomputes the tiled pattern based on current properties.
     * Called automatically when properties change.
     */
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
                        var _frameX = quad.frameX;
                        quad.frameX = texX + quad.frameY - texY;
                        quad.frameY = texY + texWidth - _frameX + texX - quad.frameWidth;
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
