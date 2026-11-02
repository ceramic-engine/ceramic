// Original code (not a port), written for the Ceramic vector plugin.
// MIT License, see Ceramic's LICENSE file.
package ceramic;

import ceramic.Shortcuts.*;

/**
 * Draws vector graphics with plutovg (paths, fills, strokes, gradients...)
 * into a Ceramic texture, from code.
 *
 * The canvas has a logical size; the underlying surface is
 * `width * density` x `height * density` pixels, and the plutovg canvas is
 * scaled by `density`, so drawing code works in logical units.
 *
 * Give a `draw` function to make the canvas redraw itself when the texture
 * density changes (the texture is then replaced: listen to `onTextureChange`
 * or use `quad`). Without `draw`, draw directly on `canvas` and call `commit()`.
 *
 * ```haxe
 * var vector = new VectorCanvas(120, 120, canvas -> {
 *     canvas.moveTo(10, 110);
 *     canvas.cubicTo(40, -20, 80, 140, 110, 10);
 *     canvas.setRgb(1, 0.6, 0.1);
 *     canvas.setLineWidth(6);
 *     canvas.stroke();
 * });
 * add(vector.quad); // a quad displaying the texture, kept up to date
 * ```
 */
class VectorCanvas extends Entity {

    /**
     * Emitted when `texture` is replaced by a new one (pixel size change).
     */
    @event function textureChange(texture:Texture, prevTexture:Texture);

    /**
     * Logical width.
     */
    public var width(default, null):Float;

    /**
     * Logical height.
     */
    public var height(default, null):Float;

    /**
     * Pixels per logical unit of the surface and texture.
     */
    public var density(default, null):Float;

    /**
     * Whether `density` follows `screen.texturesDensity` (when created with a density of -1).
     */
    public var autoDensity(default, null):Bool;

    /**
     * The plutovg surface (premultiplied ARGB pixels).
     */
    public var surface(default, null):plutovg.Surface = null;

    /**
     * The plutovg canvas drawing into `surface`, scaled by `density`.
     */
    public var canvas(default, null):plutovg.Canvas = null;

    /**
     * Drawing function called by `redraw()` (and on texture density changes),
     * after the surface is cleared. Optional.
     */
    public var draw:(canvas:plutovg.Canvas)->Void = null;

    /**
     * The texture holding the last committed pixels (owned by this canvas).
     * Replaced by a new texture when the pixel size changes.
     */
    public var texture(default, null):Texture = null;

    /**
     * A quad displaying `texture` at the logical size, created on first access
     * and kept up to date. Destroyed with the canvas.
     */
    public var quad(get, never):Quad;
    var _quad:Quad = null;
    function get_quad():Quad {
        if (_quad == null) {
            _quad = new Quad();
            if (texture != null)
                assignTexture(_quad, texture);
            _quad.size(width, height);
        }
        return _quad;
    }

    var pixels:UInt8Array = null;

    /**
     * @param width Logical width
     * @param height Logical height
     * @param draw Optional drawing function (drawn immediately and on density changes)
     * @param density Pixels per logical unit (-1 to follow `screen.texturesDensity`)
     */
    public function new(width:Float, height:Float, ?draw:(canvas:plutovg.Canvas)->Void, density:Float = -1) {

        super();

        this.width = width;
        this.height = height;
        this.draw = draw;
        this.autoDensity = density <= 0;
        this.density = density > 0 ? density : screen.texturesDensity;

        createSurface();

        if (autoDensity) {
            screen.onTexturesDensityChange(this, texturesDensityChange);
        }

        if (draw != null) {
            redraw();
        }

    }

    /**
     * Clears the surface (transparent), resets the canvas state, calls `draw`
     * if any, then commits the pixels to `texture`.
     */
    public function redraw():Void {

        clear();
        if (draw != null) {
            canvas.save();
            draw(canvas);
            canvas.restore();
        }
        commit();

    }

    /**
     * Clears the surface to transparent and resets the canvas (path, paint,
     * matrix scaled by `density`).
     */
    public function clear():Void {

        surface.data.fill(0, surface.data.length, 0);
        canvas = new plutovg.Canvas(surface);
        canvas.scale(density, density);

    }

    /**
     * Uploads the surface pixels to `texture` (created on first commit).
     */
    public function commit():Void {

        pixels = VectorTextures.surfaceToPixels(surface, pixels);

        var prevTexture = texture;
        if (prevTexture != null && !prevTexture.destroyed
            && prevTexture.nativeWidth == surface.width && prevTexture.nativeHeight == surface.height) {
            prevTexture.submitPixels(pixels);
            return;
        }

        var newTexture = Texture.fromPixels(surface.width / density, surface.height / density, pixels, density);
        // The texture keeps a reference to the pixels buffer on some backends
        pixels = null;
        texture = newTexture;

        if (_quad != null)
            assignTexture(_quad, newTexture);

        emitTextureChange(newTexture, prevTexture);

        if (prevTexture != null)
            prevTexture.destroy();

    }

    /**
     * Changes the logical size: the surface is created again (empty) and,
     * with a `draw` function, redrawn.
     */
    public function resize(width:Float, height:Float):Void {

        if (this.width == width && this.height == height)
            return;

        this.width = width;
        this.height = height;
        createSurface();

        if (_quad != null)
            _quad.size(width, height);

        if (draw != null)
            redraw();

    }

    override function destroy() {

        super.destroy();

        if (_quad != null) {
            _quad.destroy();
            _quad = null;
        }

        if (texture != null) {
            texture.destroy();
            texture = null;
        }

        surface = null;
        canvas = null;
        draw = null;

    }

/// Internal

    function createSurface():Void {

        var w = Math.round(width * density);
        var h = Math.round(height * density);
        if (w < 1) w = 1;
        if (h < 1) h = 1;

        surface = plutovg.Surface.create(w, h);
        canvas = new plutovg.Canvas(surface);
        canvas.scale(density, density);

    }

    function texturesDensityChange(newDensity:Float, prevDensity:Float):Void {

        if (density == newDensity)
            return;

        density = newDensity;
        createSurface();

        if (draw != null)
            redraw();

    }

    function assignTexture(quad:Quad, texture:Texture):Void {

        var w = width;
        var h = height;
        quad.texture = texture;
        quad.size(w, h);

    }

}
