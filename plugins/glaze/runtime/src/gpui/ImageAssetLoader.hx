// Ported from gpui-pre 0.3.10: src/elements/img.rs (ImageAssetLoader, ImageDecoder), src/platform.rs (Image::to_image_data)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.ImageLoadResult;

import haxe.io.Bytes;

/**
 * The image loader of `img()` resources (Rust `ImageAssetLoader`) and the
 * decoder of `ImageSource.Image` (Rust `ImageDecoder`).
 *
 * Differences with GPUI:
 *
 * - by default (`decodeToBytes`), images are decoded like GPUI's: straight
 *   alpha BGRA bytes (`asBytes()` works), inserted into the polychrome atlas
 *   when painted and sampled from there as straight alpha. 8 bit, non
 *   interlaced PNGs are decoded by `format.png` (exact bytes, on every
 *   platform); other raster formats (PNG variants, JPEG, GIF, BMP, WebP when
 *   the platform supports them) are decoded by the Ceramic backend,
 *   asynchronously, without premultiplication, and their pixels are read
 *   back (one frame: GIFs are not animated);
 * - with `decodeToBytes = false`, raster images are decoded by the backend
 *   into a premultiplied texture drawn without a copy (texture backed
 *   `RenderImage`, edges clamped to the texture: no atlas neighbours);
 * - bytes of an unknown format are rendered as SVG (like GPUI), through
 *   `App.svgRenderer()`;
 * - `Uri` resources: `file://` URIs are read like paths, other schemes are
 *   not supported and fail (the `img()` fallback is shown);
 * - `Path` resources need a file system (native, or web under Electron).
 */
class ImageAssetLoader {

    /**
     * Whether raster images are decoded into straight alpha BGRA bytes, like
     * GPUI (default), instead of being kept as premultiplied texture backed
     * images.
     */
    public static var decodeToBytes:Bool = true;

    /** Textures created by `decodeRaster`, by image id (destroyed by `release`) */
    static final ownedTextures:Map<Int, ceramic.Texture> = new Map();

    /** Load an image resource: read its bytes, then decode them. */
    public static function load(source:Resource, cx:App):Task<ImageLoadResult> {
        final svgRenderer = cx.svgRenderer();
        final assetSource = cx.assetSource();
        return cx.backgroundExecutor().spawn(() -> readBytes(source, assetSource))
            .andThen(bytes -> decode(bytes, svgRenderer))
            .catchError(errorToResult);
    }

    /** Rust `ImageDecoder::load`: decode an `Image`. */
    public static function loadImage(image:Image, cx:App):Task<ImageLoadResult> {
        final svgRenderer = cx.svgRenderer();
        return cx.backgroundExecutor().spawn(() -> Unit.unit)
            .andThen(_ -> image.toImageData(svgRenderer))
            .catchError(errorToResult);
    }

    static function errorToResult(error:Dynamic):ImageLoadResult {
        return switch Type.typeof(error) {
            case TEnum(e) if (e == ImageCacheError):
                Failed((error : ImageCacheError));
            case _:
                Failed(ImageCacheError.Other(Std.string(error)));
        }
    }

    /** Reads the bytes of a resource, throws an `ImageCacheError`. */
    static function readBytes(source:Resource, assetSource:AssetSource):Bytes {
        return switch source {
            case Path(path):
                readFile(path);
            case Uri(uri):
                if (StringTools.startsWith(uri, 'file://')) {
                    readFile(StringTools.urlDecode(uri.substr('file://'.length)));
                }
                else {
                    throw ImageCacheError.Other('loading image asset from "$uri": uri loading is not supported');
                }
            case Embedded(path):
                final data = assetSource.load(path);
                if (data == null)
                    throw ImageCacheError.Asset('Embedded resource not found: $path');
                data;
        }
    }

    static function readFile(path:String):Bytes {
        #if (sys || (web && ceramic_use_electron))
        if (ceramic.Files.exists(path)) {
            final bytes = ceramic.Files.getBytes(path);
            if (bytes != null)
                return bytes;
        }
        throw ImageCacheError.Io('No such file or directory: $path');
        #else
        throw ImageCacheError.Io('No file system to read $path');
        #end
    }

    /** Decode encoded image bytes: a known raster format, otherwise SVG. */
    public static function decode(bytes:Bytes, svgRenderer:SvgRenderer):Task<ImageLoadResult> {
        final format = ImageFormat.guess(bytes);
        if (format != null)
            return decodeRaster(bytes, format);
        return Task.ready(renderSvg(svgRenderer, bytes));
    }

    /** Render SVG bytes at scale 1 (Rust `render_single_frame(&bytes, 1.0)`). */
    public static function renderSvg(svgRenderer:SvgRenderer, bytes:Bytes):ImageLoadResult {
        try {
            return Loaded(svgRenderer.renderSingleFrame(bytes, 1.0));
        }
        catch (e:Dynamic) {
            return Failed(ImageCacheError.Usvg(Std.string(e)));
        }
    }

    /**
     * Decode raster bytes into a straight alpha BGRA image (`decodeToBytes`,
     * default) or, with the Ceramic backend, into a texture backed image
     * (density 1, premultiplied).
     */
    public static function decodeRaster(bytes:Bytes, format:ImageFormat):Task<ImageLoadResult> {
        final type:Null<ceramic.ImageType> = switch format {
            case ImageFormat.Png: ceramic.ImageType.PNG;
            case ImageFormat.Jpeg: ceramic.ImageType.JPEG;
            case ImageFormat.Gif: ceramic.ImageType.GIF;
            case ImageFormat.Bmp: 'bmp';
            case ImageFormat.Webp: 'webp';
            case _: null;
        }
        if (type == null)
            return Task.ready(Failed(ImageCacheError.Image('unsupported image format: ' + format.extension())));

        final toBytes = decodeToBytes;
        if (toBytes && format == ImageFormat.Png) {
            final image = decodePng(bytes);
            if (image != null)
                return Task.ready(Loaded(image));
        }

        final task = new Task<ImageLoadResult>();
        try {
            ceramic.App.app.backend.textures.loadFromBytes(bytes, type, #if clay {premultiplyAlpha: !toBytes} #else null #end, backendItem -> {
                if (!task.isPending)
                    return;
                if (backendItem == null) {
                    task.resolve(Failed(ImageCacheError.Image('failed to decode ' + format.extension() + ' image')));
                    return;
                }
                final texture = new ceramic.Texture(backendItem, 1);
                if (texture.nativeWidth <= 0 || texture.nativeHeight <= 0) {
                    texture.destroy();
                    task.resolve(Failed(ImageCacheError.Image('failed to decode ' + format.extension() + ' image')));
                    return;
                }
                if (toBytes) {
                    final image = readBack(texture);
                    texture.destroy();
                    task.resolve(image != null ? Loaded(image) : Failed(ImageCacheError.Image('failed to read the pixels of a decoded ' + format.extension() + ' image')));
                    return;
                }
                final image = RenderImage.fromTexture(texture);
                ownedTextures.set(image.id, texture);
                task.resolve(Loaded(image));
            });
        }
        catch (e:Dynamic) {
            task.resolve(Failed(ImageCacheError.Image(Std.string(e))));
        }
        return task;
    }

    /**
     * Decodes a PNG into a straight alpha BGRA image with `format.png` (the
     * bytes the `image` crate decodes for GPUI). Returns null for what
     * `format.png` does not handle exactly (interlaced images, 16 bit
     * channels, transparent color keys of grey and truecolor images), which
     * the backend decodes instead.
     */
    public static function decodePng(bytes:Bytes):Null<RenderImage> {
        try {
            final data = new format.png.Reader(new haxe.io.BytesInput(bytes)).read();
            final header = format.png.Tools.getHeader(data);
            if (header.interlaced || header.width <= 0 || header.height <= 0)
                return null;
            switch header.color {
                case ColIndexed:
                    if (header.colbits > 8)
                        return null;
                case ColGrey(_) | ColTrue(_):
                    if (header.colbits != 8)
                        return null;
                    for (chunk in data) {
                        switch chunk {
                            case CUnknown('tRNS', _):
                                return null;
                            case _:
                        }
                    }
            }
            final bgra = format.png.Tools.extract32(data);
            return RenderImage.fromBgra(header.width, header.height, bgra);
        }
        catch (e:Dynamic) {
            return null;
        }
    }

    /** Reads the straight alpha RGBA pixels of a texture into a BGRA image. */
    static function readBack(texture:ceramic.Texture):Null<RenderImage> {
        final width = Std.int(texture.nativeWidth);
        final height = Std.int(texture.nativeHeight);
        final pixels = texture.fetchPixels();
        if (pixels == null || pixels.length < width * height * 4)
            return null;
        final bgra = Bytes.alloc(width * height * 4);
        var i = 0;
        final n = width * height * 4;
        while (i < n) {
            bgra.set(i, pixels[i + 2]);
            bgra.set(i + 1, pixels[i + 1]);
            bgra.set(i + 2, pixels[i]);
            bgra.set(i + 3, pixels[i + 3]);
            i += 4;
        }
        return RenderImage.fromBgra(width, height, bgra);
    }

    /**
     * Destroys the texture of an image decoded by this loader (call it after
     * the image was dropped from every window). Other images are left alone.
     */
    public static function release(image:RenderImage):Void {
        final texture = ownedTextures.get(image.id);
        if (texture != null) {
            ownedTextures.remove(image.id);
            texture.destroy();
        }
    }

}
