package unityengine;

import cs.NativeArray;
import cs.types.UInt8;

/**
 * Unity Texture2D class extern binding for Ceramic.
 * Represents a 2D texture asset that can be used for rendering.
 * 
 * This binding provides essential properties and methods for
 * texture manipulation, including pixel data access and
 * render-to-texture capabilities used by the Ceramic backend.
 */
@:native('UnityEngine.Texture2D')
extern class Texture2D extends Texture {

    /**
     * Width of the texture in pixels.
     * Read-only property set when the texture is created.
     */
    var width:Int;

    /**
     * Height of the texture in pixels.
     * Read-only property set when the texture is created.
     */
    var height:Int;

    /**
     * Filtering mode of the texture.
     * Controls how the texture is sampled when transformed.
     * Point = nearest neighbor (pixelated), Bilinear/Trilinear = smooth.
     */
    var filterMode:FilterMode;

    /**
     * Sets raw pixel data for the texture from a byte array.
     * The data must be in the correct format for the texture.
     * 
     * @param data Raw pixel data as a native byte array
     * @param mipLevel Mipmap level to write to (0 = full resolution)
     * @param sourceDataStartIndex Starting index in the source data array
     */
    function SetPixelData(data:NativeArray<UInt8>, mipLevel:Int, sourceDataStartIndex:Int):Void;

    /**
     * Reads pixels from the current render target into this texture.
     * Commonly used to capture the screen or render texture contents.
     * 
     * @param source Rectangle in screen coordinates to read from
     * @param destX X coordinate in the texture to write to
     * @param destY Y coordinate in the texture to write to
     * @param recalculateMipMaps Whether to update mipmaps after reading
     */
    function ReadPixels(source:Rect, destX:Int, destY:Int, recalculateMipMaps:Bool):Void;

    /**
     * Applies all previous SetPixel and SetPixels changes.
     * Must be called to upload changed pixels to the GPU.
     * 
     * @param updateMipmaps Whether to recalculate mipmaps
     * @param makeNoLongerReadable If true, frees CPU memory copy (saves memory but prevents further CPU access)
     */
    function Apply(updateMipmaps:Bool, makeNoLongerReadable:Bool):Void;

}
