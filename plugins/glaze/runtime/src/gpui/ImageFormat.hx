// Ported from gpui-pre 0.3.10: src/platform.rs (ImageFormat)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.io.Bytes;

/**
 * One of the image formats GPUI knows about.
 */
enum abstract ImageFormat(Int) {

    /** .png */
    var Png = 0;

    /** .jpeg or .jpg */
    var Jpeg = 1;

    /** .webp */
    var Webp = 2;

    /** .gif */
    var Gif = 3;

    /** .svg */
    var Svg = 4;

    /** .bmp */
    var Bmp = 5;

    /** .tif or .tiff */
    var Tiff = 6;

    /** .ico */
    var Ico = 7;

    /** Netpbm image formats (.pbm, .ppm, .pgm). */
    var Pnm = 8;

    /** Returns the mime type for the ImageFormat */
    public function mimeType():String {
        return switch (cast this : ImageFormat) {
            case Png: 'image/png';
            case Jpeg: 'image/jpeg';
            case Webp: 'image/webp';
            case Gif: 'image/gif';
            case Svg: 'image/svg+xml';
            case Bmp: 'image/bmp';
            case Tiff: 'image/tiff';
            case Ico: 'image/ico';
            case Pnm: 'image/x-portable-anymap';
        }
    }

    /** Returns the file extension for this image format (without leading dot). */
    public function extension():String {
        return switch (cast this : ImageFormat) {
            case Png: 'png';
            case Jpeg: 'jpg';
            case Webp: 'webp';
            case Gif: 'gif';
            case Svg: 'svg';
            case Bmp: 'bmp';
            case Tiff: 'tiff';
            case Ico: 'ico';
            case Pnm: 'pnm';
        }
    }

    /** Returns the ImageFormat for the given mime type (`from_mime_type`, with its legacy aliases) */
    public static function fromMimeType(mimeType:String):Null<ImageFormat> {
        for (format in [Png, Jpeg, Webp, Gif, Svg, Bmp, Tiff, Ico, Pnm]) {
            if (format.mimeType() == mimeType)
                return format;
        }
        return switch mimeType {
            case 'image/jpg': Jpeg;
            case 'image/tif': Tiff;
            case _: null;
        }
    }

    /**
     * Guess the format of encoded image bytes from their magic number (Rust
     * `image::guess_format`), or `null` if unknown. SVG is never guessed: GPUI
     * renders bytes of an unknown format as SVG.
     */
    public static function guess(bytes:Bytes):Null<ImageFormat> {
        final n = bytes.length;
        inline function at(i:Int):Int {
            return i < n ? bytes.get(i) : -1;
        }
        if (at(0) == 0x89 && at(1) == 0x50 && at(2) == 0x4E && at(3) == 0x47 && at(4) == 0x0D && at(5) == 0x0A && at(6) == 0x1A && at(7) == 0x0A)
            return Png;
        if (at(0) == 0xFF && at(1) == 0xD8 && at(2) == 0xFF)
            return Jpeg;
        if (at(0) == 'G'.code && at(1) == 'I'.code && at(2) == 'F'.code && at(3) == '8'.code)
            return Gif;
        if (at(0) == 'R'.code && at(1) == 'I'.code && at(2) == 'F'.code && at(3) == 'F'.code
            && at(8) == 'W'.code && at(9) == 'E'.code && at(10) == 'B'.code && at(11) == 'P'.code)
            return Webp;
        if (at(0) == 'B'.code && at(1) == 'M'.code)
            return Bmp;
        if ((at(0) == 'I'.code && at(1) == 'I'.code && at(2) == 42 && at(3) == 0) || (at(0) == 'M'.code && at(1) == 'M'.code && at(2) == 0 && at(3) == 42))
            return Tiff;
        if (at(0) == 0 && at(1) == 0 && at(2) == 1 && at(3) == 0)
            return Ico;
        if (at(0) == 'P'.code && at(1) >= '1'.code && at(1) <= '7'.code)
            return Pnm;
        return null;
    }

}
