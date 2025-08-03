package ceramic;

import haxe.io.Bytes;

/**
 * Represents a single frame from an Aseprite animation.
 * 
 * Each frame contains the composited image data from all visible layers,
 * timing information, and metadata about which animation tags include this frame.
 * Frames may be deduplicated if they have identical pixel data to save memory.
 * 
 * The frame's pixel data is stored as RGBA bytes and can be packed into a
 * texture atlas for efficient rendering.
 * 
 * @see AsepriteData for the parent data structure
 * @see AsepriteTag for animation tag information
 */
@:structInit
class AsepriteFrame {
    /**
     * The underlying frame data from the ase library.
     * Contains raw frame information from the file format.
     */
    public var aseFrame(default, null):ase.Frame;
    /**
     * The frame index (0-based) in the animation sequence.
     */
    public var index(default, null):Int;
    /**
     * Duration of this frame in seconds.
     * Determines how long this frame is displayed during animation playback.
     */
    public var duration(default, null):Float;
    /**
     * Names of animation tags that include this frame.
     * A frame can belong to multiple overlapping tags.
     */
    public var tags(default, null):Array<String> = [];
    /**
     * The pixel data for this frame in RGBA format.
     * Each pixel uses 4 bytes (R, G, B, A) with values 0-255.
     * May be null if this frame is a duplicate of another frame.
     */
    public var pixels:UInt8Array = null;
    /**
     * Hash of the pixel data used for duplicate detection.
     * Frames with identical hashes can share the same texture region.
     */
    public var hash:Bytes = null;
    /**
     * Index used for grouping frames with identical hashes.
     * Frames with the same hashIndex have identical pixel data.
     */
    public var hashIndex:Int = -1;
    /**
     * If this frame is a duplicate, the index of the original frame.
     * -1 if this frame is not a duplicate.
     */
    public var duplicateOfIndex:Int = -1;
    /**
     * Whether this duplicate frame has the same offset as the original.
     * If true, the frames can share the exact same texture region.
     */
    public var duplicateSameOffset:Bool = false;
    /**
     * Horizontal offset for trimmed frames.
     * When frames are trimmed of transparent pixels, this indicates
     * where to position the trimmed image relative to the canvas.
     */
    public var offsetX:Int = 0;
    
    /**
     * Vertical offset for trimmed frames.
     * When frames are trimmed of transparent pixels, this indicates
     * where to position the trimmed image relative to the canvas.
     */
    public var offsetY:Int = 0;
    /**
     * Width of the frame after trimming transparent pixels.
     * This is the actual width stored in the texture atlas.
     */
    public var packedWidth:Int = 0;
    
    /**
     * Height of the frame after trimming transparent pixels.
     * This is the actual height stored in the texture atlas.
     */
    public var packedHeight:Int = 0;

}
