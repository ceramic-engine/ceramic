// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.AtlasTile;

/**
 * Identifies an atlas entry.
 *
 * Differences with GPUI: `Svg` and `Image` keys carry plain values for now
 * (the path or image id and the rendered size): `RenderSvgParams` and
 * `RenderImageParams` come with the SVG and image elements.
 */
@:using(gpui.AtlasKey.AtlasKeyTools)
enum AtlasKey {
    Glyph(params:RenderGlyphParams);
    Svg(path:String, width:Int, height:Int);
    Image(imageId:Int, frameIndex:Int);
    /** Ceramic addition: the coverage mask of a path rasterized by `Window.paintPath()` */
    Path(key:String);
    /**
     * Ceramic addition: a path with Loop-Blinn curve triangles rasterized by
     * `Window.paintPath()` (RGBA encoding, see `PathRasterizer.rasterizeCurves()`)
     */
    PathCurves(key:String);
}

class AtlasKeyTools {

    /** Returns the texture kind for this atlas key. */
    public static function textureKind(key:AtlasKey):AtlasTextureKind {
        return switch key {
            case Glyph(params):
                if (params.isEmoji) Polychrome
                else if (params.subpixelRendering) Subpixel
                else Monochrome;
            case Svg(_, _, _): Monochrome;
            case Image(_, _): Polychrome;
            case Path(_): Monochrome;
            case PathCurves(_): Polychrome;
        }
    }

    /** A string identifying the key (map key). */
    public static function keyString(key:AtlasKey):String {
        return switch key {
            case Glyph(params): 'g:' + params.key();
            case Svg(path, width, height): 's:$width:$height:$path';
            case Image(imageId, frameIndex): 'i:$imageId:$frameIndex';
            case Path(key): 'p:$key';
            case PathCurves(key): 'pc:$key';
        }
    }

}
