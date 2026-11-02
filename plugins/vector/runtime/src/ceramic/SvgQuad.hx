// Original code (not a port), written for the Ceramic vector plugin.
// MIT License, see Ceramic's LICENSE file.
package ceramic;

import ceramic.Shortcuts.*;

/**
 * A `Quad` displaying an SVG document rasterized at its own size.
 *
 * The document is rendered at `width * density` x `height * density` pixels
 * (`density` defaults to `screen.texturesDensity`), so it stays sharp at any
 * size. It is rendered again, before the next frame, when the quad is resized,
 * when the texture density changes, when another document is assigned and
 * after `invalidate()` (or the `setAttribute()` / `setCurrentColor()` helpers).
 *
 * The quad owns its texture: do not assign another one.
 *
 * ```haxe
 * var icon = new SvgQuad();
 * icon.asset = assets.svgAsset('icons/heart'); // own copy of the document
 * icon.size(48, 48);
 * icon.setCurrentColor(Color.RED);             // Lucide icons use currentColor
 * add(icon);
 * ```
 *
 * When no size is set (both 0), the quad takes the intrinsic size of the document.
 * A size whose aspect ratio differs from the document stretches it, like an image.
 */
class SvgQuad extends Quad {

    /**
     * The SVG document to display. It can be shared with other quads (an
     * attribute change then affects all of them, each one has to be invalidated).
     */
    public var document(default, set):lunasvg.Document = null;
    function set_document(document:lunasvg.Document):lunasvg.Document {
        if (this.document == document) return document;
        this.document = document;
        if (document != null && width == 0 && height == 0) {
            sizing = true;
            size(document.width(), document.height());
            sizing = false;
        }
        contentDirty = true;
        return document;
    }

    /**
     * An SVG asset to display. The quad gets its own copy of the document
     * (`asset.createDocument()`), so that its attributes can be changed without
     * affecting other users of the asset. When the asset file is hot reloaded,
     * the document is parsed again (attribute changes made on the previous one are lost).
     */
    public var asset(default, set):SvgAsset = null;
    function set_asset(asset:SvgAsset):SvgAsset {
        if (this.asset == asset) return asset;
        if (this.asset != null) {
            this.asset.offDocumentChange(assetDocumentChange);
            this.asset.release();
        }
        this.asset = asset;
        if (asset != null) {
            asset.retain();
            asset.onDocumentChange(this, assetDocumentChange);
            document = asset.createDocument();
        }
        else {
            document = null;
        }
        return asset;
    }

    /**
     * Pixels per logical unit used to rasterize the document.
     * -1 (default) follows `screen.texturesDensity`.
     */
    public var density(default, set):Float = -1;
    function set_density(density:Float):Float {
        if (this.density == density) return density;
        this.density = density;
        contentDirty = true;
        return density;
    }

    /**
     * The texture holding the rasterized document (owned by this quad).
     */
    var svgTexture:Texture = null;

    var sizing:Bool = false;

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        screen.onTexturesDensityChange(this, texturesDensityChange);

    }

    /**
     * Renders the document again before the next frame, for instance after
     * changing attributes of `document`.
     */
    public function invalidate():Void {

        contentDirty = true;

    }

    /**
     * Sets an attribute (or CSS property) on the element with the given `id`, or
     * on the root `<svg>` element when `id` is null, then invalidates the quad.
     * ```haxe
     * quad.setAttribute('fill', '#ff0000', 'dot');
     * ```
     */
    public function setAttribute(name:String, value:String, ?id:String):Void {

        if (document == null)
            return;

        var element = id != null ? document.getElementById(id) : document.documentElement();
        if (element.isNull()) {
            log.warning('SVG element not found: $id');
            return;
        }

        element.setAttribute(name, value);
        contentDirty = true;

    }

    /**
     * Sets the `color` attribute of the root element, used by every `currentColor`
     * paint of the document (Lucide icons draw with `stroke="currentColor"`).
     * Unlike `Quad.color` (which multiplies the texture), this changes the SVG
     * paint itself, so it also works for icons mixing several colors.
     */
    public function setCurrentColor(color:Color, alpha:Float = 1):Void {

        if (alpha >= 1) {
            setAttribute('color', color.toWebString());
        }
        else {
            setAttribute('color', 'rgba(' + color.red + ',' + color.green + ',' + color.blue + ',' + alpha + ')');
        }

    }

    override function set_width(width:Float):Float {
        if (this.width == width) return width;
        super.set_width(width);
        if (!sizing) contentDirty = true;
        return width;
    }

    override function set_height(height:Float):Float {
        if (this.height == height) return height;
        super.set_height(height);
        if (!sizing) contentDirty = true;
        return height;
    }

    override function computeContent() {

        rasterize();

        super.computeContent();

    }

    override function destroy() {

        asset = null;

        var prevTexture = svgTexture;
        svgTexture = null;

        super.destroy();

        if (prevTexture != null) {
            prevTexture.destroy();
        }

    }

/// Internal

    function texturesDensityChange(newDensity:Float, prevDensity:Float):Void {

        if (density <= 0)
            contentDirty = true;

    }

    function assetDocumentChange(newDocument:lunasvg.Document, prevDocument:lunasvg.Document):Void {

        document = asset != null ? asset.createDocument() : null;

    }

    function rasterize():Void {

        var prevTexture = svgTexture;
        var newTexture:Texture = null;

        if (document != null && width > 0 && height > 0) {
            var actualDensity = density > 0 ? density : screen.texturesDensity;
            newTexture = VectorTextures.textureFromSvg(document, width, height, actualDensity, prevTexture);
        }

        if (newTexture == prevTexture)
            return;

        svgTexture = newTexture;

        // Assigning a texture resets the frame and the size of the quad
        // to the texture size: keep the size of the quad instead
        var w = width;
        var h = height;
        sizing = true;
        texture = newTexture;
        size(w, h);
        sizing = false;

        if (prevTexture != null) {
            prevTexture.destroy();
        }

    }

}
