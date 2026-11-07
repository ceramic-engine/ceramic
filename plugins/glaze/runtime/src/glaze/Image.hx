// Ported from gpui-pre 0.3.10: src/platform.rs (Image)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.io.Bytes;

/**
 * An image, with a format and encoded bytes (the source of
 * `ImageSource.Image`, decoded by `img()` through the asset cache).
 */
class Image {

    /** The image format the bytes represent (e.g. PNG) */
    public final format:ImageFormat;

    /** The raw image bytes */
    public final bytes:Bytes;

    /** The unique ID for the image (derived from the bytes) */
    public final id:String;

    function new(format:ImageFormat, bytes:Bytes) {
        this.format = format;
        this.bytes = bytes;
        this.id = haxe.crypto.Md5.make(bytes).toHex();
    }

    /** An empty image containing no data */
    public static function empty():Image {
        return fromBytes(ImageFormat.Png, Bytes.alloc(0));
    }

    /** Create an image from a format and bytes */
    public static function fromBytes(format:ImageFormat, bytes:Bytes):Image {
        return new Image(format, bytes);
    }

    /** Use the GPUI `use_asset` API to make this image renderable */
    public function useRenderImage(window:Window, cx:App):Null<RenderImage> {
        return ImageSource.Image(this).useData(null, window, cx).okOrNull();
    }

    /** Use the GPUI `get_asset` API to make this image renderable */
    public function getRenderImage(window:Window, cx:App):Null<RenderImage> {
        return ImageSource.Image(this).getData(null, window, cx).okOrNull();
    }

    /** Use the GPUI `remove_asset` API to drop this image, if possible. */
    public function removeAsset(cx:App):Void {
        ImageSource.Image(this).removeAsset(cx);
    }

    /** Check whether this image is present in the asset cache (loading or loaded), without fetching it. */
    public function isAssetCached(cx:App):Bool {
        return ImageSource.Image(this).isAssetCached(cx);
    }

    /**
     * Decode this image (Rust `to_image_data`): raster formats become straight
     * alpha BGRA bytes like GPUI's, see `ImageAssetLoader.decodeRaster`.
     */
    public function toImageData(svgRenderer:SvgRenderer):Task<ImageLoadResult> {
        if (format == ImageFormat.Svg)
            return Task.ready(ImageAssetLoader.renderSvg(svgRenderer, bytes));
        return ImageAssetLoader.decodeRaster(bytes, format);
    }

}
