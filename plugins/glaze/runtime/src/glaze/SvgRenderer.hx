// Ported from gpui-pre 0.3.10: src/svg_renderer.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.io.Bytes;
import plutovg.Utils.f32;

/**
 * Renders SVG documents, for `svg()` (alpha masks tinted by the text
 * color) and for SVG images.
 *
 * Differences with GPUI: documents are parsed and rendered by the Haxe
 * port of lunasvg (on plutovg) instead of usvg / resvg, so coverage can
 * differ slightly on curve and stroke edges. Text in SVG goes through
 * `SvgFontProvider` (the fonts of the GPUI text system).
 */
class SvgRenderer {

    /**
     * SVGs are rendered at twice their size for smoothness, then shown
     * at half that size (Rust `SMOOTH_SVG_SCALE_FACTOR`).
     */
    public static inline final SMOOTH_SVG_SCALE_FACTOR:Float = 2.0;

    static inline final MAX_SIZE:Float = 8192.0;

    final assetSource:AssetSource;

    /** Parsed documents by path (bytes passed explicitly are parsed each time) */
    final documents:Map<String, lunasvg.Document> = new Map();

    static var fontProviderInstalled:Bool = false;

    /** How many bitmaps this renderer rasterized. For tests. */
    public var rasterizations(default, null):Int = 0;

    public function new(assetSource:AssetSource, ?textSystem:TextSystem) {
        this.assetSource = assetSource;
        // SVG <text> uses the fonts of the GPUI text system
        if (!fontProviderInstalled && textSystem != null && Std.isOfType(textSystem.platformTextSystem, glaze.platform.CeramicTextSystem)) {
            fontProviderInstalled = true;
            lunasvg.Lunasvg.setFontProvider(new glaze.platform.SvgFontProvider(cast textSystem.platformTextSystem));
        }
    }

    /**
     * Parses an SVG document, throws if it is invalid.
     */
    public function parseSvg(bytes:Bytes):lunasvg.Document {
        final document = lunasvg.Document.loadFromBytes(bytes);
        if (document == null)
            throw 'Invalid SVG document';
        return document;
    }

    /**
     * Renders a parsed document as a BGRA image: at a size (the width sets
     * the scale), at an exact size, or at a scale factor of its intrinsic
     * size (times `SMOOTH_SVG_SCALE_FACTOR`, the image then has that scale factor).
     */
    public function renderParsed(document:lunasvg.Document, size:SvgSize):RenderImage {
        var imageScaleFactor = 1.0;
        final bitmap = switch size {
            case Size(width, height): rasterize(document, width, height, 0, false);
            case ExactSize(width, height): rasterize(document, width, height, 0, true);
            case ScaleFactor(scaleFactor):
                imageScaleFactor = SMOOTH_SVG_SCALE_FACTOR;
                rasterize(document, -1, -1, scaleFactor * SMOOTH_SVG_SCALE_FACTOR, false);
        };
        final width = bitmap.width();
        final height = bitmap.height();
        final data = bitmap.data();
        final stride = bitmap.stride();
        // Premultiplied BGRA to straight BGRA (swap_rgba_pa_to_bgra applied to RGBA pixels)
        final bytes = Bytes.alloc(width * height * 4);
        for (y in 0...height) {
            for (x in 0...width) {
                final src = y * stride + x * 4;
                final dst = (y * width + x) * 4;
                final a = data.get(src + 3);
                if (a == 0) {
                    bytes.setInt32(dst, 0);
                    continue;
                }
                final f = a / 255.0;
                bytes.set(dst, glaze.util.MathUtil.toU8(data.get(src) / f));
                bytes.set(dst + 1, glaze.util.MathUtil.toU8(data.get(src + 1) / f));
                bytes.set(dst + 2, glaze.util.MathUtil.toU8(data.get(src + 2) / f));
                bytes.set(dst + 3, a);
            }
        }
        final image = RenderImage.fromBgra(width, height, bytes);
        image.scaleFactor = imageScaleFactor;
        return image;
    }

    /**
     * Renders SVG bytes at the given scale factor, as a BGRA image.
     */
    public function renderSingleFrame(bytes:Bytes, scaleFactor:Float):RenderImage {
        return renderParsed(parseSvg(bytes), ScaleFactor(scaleFactor));
    }

    /**
     * Renders the alpha mask of an SVG at `params.width` device pixels wide
     * (the height follows the aspect ratio), from `bytes` or, when null,
     * from the asset source. Returns null if the asset does not exist.
     */
    public function renderAlphaMask(params:RenderSvgParams, bytes:Null<Bytes>):Null<AtlasTile.AtlasTileSource> {
        if (params.width == 0 || params.height == 0)
            throw "can't render at a zero size";

        var document:Null<lunasvg.Document> = null;
        if (bytes != null) {
            document = parseSvg(bytes);
        }
        else {
            document = documents.get(params.path);
            if (document == null) {
                final loaded = assetSource.load(params.path);
                if (loaded == null)
                    return null;
                document = parseSvg(loaded);
                documents.set(params.path, document);
            }
        }

        final bitmap = rasterize(document, params.width, params.height, 0, false);
        final width = bitmap.width();
        final height = bitmap.height();
        final data = bitmap.data();
        final stride = bitmap.stride();
        final mask = Bytes.alloc(width * height);
        for (y in 0...height) {
            for (x in 0...width) {
                mask.set(y * width + x, data.get(y * stride + x * 4 + 3));
            }
        }
        return new AtlasTile.AtlasTileSource(width, height, mask);
    }

    /**
     * Rust `rasterize_tree`: with a size, the width sets the scale (the
     * aspect ratio is kept), with an exact size the bitmap has that size;
     * otherwise the intrinsic size times `scale`.
     */
    function rasterize(document:lunasvg.Document, sizeWidth:Int, sizeHeight:Int, scale:Float, exact:Bool):lunasvg.Bitmap {
        final svgWidth = f32(document.width());
        final svgHeight = f32(document.height());
        if (svgWidth <= 0 || svgHeight <= 0)
            throw 'Invalid SVG size';
        var width:Float;
        var height:Float;
        if (exact) {
            width = sizeWidth;
            height = sizeHeight;
        }
        else if (sizeWidth > 0) {
            final s = f32(sizeWidth / svgWidth);
            width = f32(svgWidth * s);
            height = f32(svgHeight * s);
        }
        else {
            width = f32(svgWidth * scale);
            height = f32(svgHeight * scale);
        }
        final clampScale = Math.min(Math.min(MAX_SIZE / width, MAX_SIZE / height), 1.0);
        width = f32(width * clampScale);
        height = f32(height * clampScale);

        final pixmapWidth = Std.int(width);
        final pixmapHeight = Std.int(height);
        if (pixmapWidth <= 0 || pixmapHeight <= 0)
            throw 'Invalid SVG size';
        rasterizations++;
        final bitmap = lunasvg.Bitmap.create(pixmapWidth, pixmapHeight);
        document.render(bitmap, new lunasvg.Matrix(f32(width / svgWidth), 0, 0, f32(height / svgHeight), 0, 0));
        return bitmap;
    }

}

/**
 * The size an SVG is rendered at (Rust `SvgSize`), in device pixels.
 */
enum SvgSize {
    /** The width sets the scale, the aspect ratio is kept */
    Size(width:Int, height:Int);
    /** Exactly this size */
    ExactSize(width:Int, height:Int);
    /** The intrinsic size times this factor (times `SMOOTH_SVG_SCALE_FACTOR`) */
    ScaleFactor(scaleFactor:Float);
}
