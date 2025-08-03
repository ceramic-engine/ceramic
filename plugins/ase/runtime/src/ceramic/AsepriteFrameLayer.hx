package ceramic;

import ase.chunks.CelChunk;
import ase.chunks.LayerChunk;

/**
 * Represents a single layer's data within an Aseprite frame.
 * 
 * Aseprite files can contain multiple layers that are composited together
 * to create the final frame image. This structure holds the pixel data
 * for one layer within a specific frame.
 * 
 * Layers can have different blend modes, opacity levels, and visibility states
 * that affect how they are combined with other layers.
 * 
 * @see AsepriteFrame for the complete frame data
 * @see LayerChunk for layer properties and settings
 */
@:structInit
class AsepriteFrameLayer {
    /**
     * The layer definition containing properties like name, blend mode,
     * opacity, and visibility settings.
     */
    public var layer:LayerChunk;
    /**
     * The cel (cell) data for this layer in this frame.
     * Contains position, opacity, and link information.
     * May be null if this layer has no content in this frame.
     */
    public var celChunk:CelChunk = null;
    /**
     * The pixel data for this layer in RGBA format.
     * Each pixel uses 4 bytes (R, G, B, A) with values 0-255.
     * May be null if this layer has no visible content in this frame
     * or if the cel is linked to another frame.
     */
    public var pixels:UInt8Array = null;
}