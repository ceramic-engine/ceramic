// Ported from gpui-pre 0.3.10: src/assets.rs (RenderImage, RenderImageParams, ImageId)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.io.Bytes;

/**
 * A cached and processed image, in BGRA format (straight alpha, like GPUI's
 * decoded images), or backed by a Ceramic texture.
 *
 * Differences with GPUI: a frame is either BGRA bytes (`RenderImageFrame.bytes`,
 * inserted into the polychrome atlas when painted, as in GPUI) or a Ceramic
 * `Texture` (`RenderImageFrame.texture`, drawn directly from that texture
 * through an atlas tile covering it, without copying its pixels).
 */
class RenderImage {

    static var nextId:Int = 0;

    /** The ID associated with this image */
    public final id:Int;

    /** The scale factor of this image on render. */
    public var scaleFactor:Float = 1.0;

    final frames:Array<RenderImageFrame>;

    public function new(frames:Array<RenderImageFrame>) {
        this.id = nextId++;
        this.frames = frames;
    }

    /** An image of one frame of BGRA bytes (straight alpha). */
    public static function fromBgra(width:Int, height:Int, bytes:Bytes):RenderImage {
        return new RenderImage([new RenderImageFrame(width, height, bytes, null, 0.1)]);
    }

    /** An image of one frame of RGBA bytes (straight alpha), converted to BGRA. */
    public static function fromRgba(width:Int, height:Int, rgba:Bytes):RenderImage {
        final bytes = Bytes.alloc(width * height * 4);
        var i = 0;
        final n = width * height * 4;
        while (i < n) {
            bytes.set(i, rgba.get(i + 2));
            bytes.set(i + 1, rgba.get(i + 1));
            bytes.set(i + 2, rgba.get(i));
            bytes.set(i + 3, rgba.get(i + 3));
            i += 4;
        }
        return fromBgra(width, height, bytes);
    }

    /**
     * An image drawn from a Ceramic texture (not owned). Its size is the
     * size of the texture in pixels (`nativeWidth` x `nativeHeight`), and
     * `scaleFactor` its density, so its render size is its logical size.
     */
    public static function fromTexture(texture:ceramic.Texture):RenderImage {
        final image = new RenderImage([new RenderImageFrame(Std.int(texture.nativeWidth), Std.int(texture.nativeHeight), null, texture, 0.1)]);
        image.scaleFactor = texture.density;
        return image;
    }

    /** Convert this image into a byte slice (BGRA), `null` for texture frames. */
    public function asBytes(frameIndex:Int):Null<Bytes> {
        final frame = frames[frameIndex];
        return frame != null ? frame.bytes : null;
    }

    /** The frame, or `null` if the index is out of range. */
    public inline function frame(frameIndex:Int):Null<RenderImageFrame> {
        return frames[frameIndex];
    }

    /** Get the size of this image, in pixels. */
    public function size(frameIndex:Int):Size {
        final frame = frames[frameIndex];
        return frame != null ? new Size(frame.width, frame.height) : new Size(0, 0);
    }

    /** Get the size of this image, in pixels for display, adjusted for the scale factor. */
    public function renderSize(frameIndex:Int):Size {
        final s = size(frameIndex);
        return new Size(s.width / scaleFactor, s.height / scaleFactor);
    }

    /** Get the delay of this frame from the previous, in seconds */
    public function delay(frameIndex:Int):Float {
        final frame = frames[frameIndex];
        return frame != null ? frame.delay : 0.1;
    }

    /** Get the number of frames for this image. */
    public inline function frameCount():Int {
        return frames.length;
    }

    public function toString():String {
        final first = frames[0];
        return 'ImageData(id=$id, size=${first != null ? first.width + 'x' + first.height : 'none'})';
    }

}

/**
 * A frame of a `RenderImage`.
 */
class RenderImageFrame {

    public final width:Int;

    public final height:Int;

    /** BGRA pixels, straight alpha (or `null` for a texture frame) */
    public final bytes:Null<Bytes>;

    /** Ceramic texture of this frame (or `null` for a bytes frame) */
    public final texture:Null<ceramic.Texture>;

    /** Delay of this frame from the previous, in seconds */
    public final delay:Float;

    public function new(width:Int, height:Int, bytes:Null<Bytes>, texture:Null<ceramic.Texture>, delay:Float) {
        this.width = width;
        this.height = height;
        this.bytes = bytes;
        this.texture = texture;
        this.delay = delay;
    }

}
