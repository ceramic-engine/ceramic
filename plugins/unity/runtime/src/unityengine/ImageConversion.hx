package unityengine;

import haxe.io.BytesData;

/**
 * Utility class for converting between Texture2D and image file formats.
 * Enables loading images from bytes and saving textures to common formats.
 * 
 * In Ceramic's Unity backend, this is used for:
 * - Dynamic texture loading from downloaded data
 * - Screenshot/capture functionality
 * - Runtime texture import/export
 * - Converting between formats
 * 
 * Supported formats:
 * - PNG: Lossless, supports transparency
 * - JPG: Lossy compression, no transparency
 * - EXR: High dynamic range (32-bit float)
 * - TGA: Uncompressed with alpha
 * 
 * @see Texture2D
 */
@:native('UnityEngine.ImageConversion')
extern class ImageConversion {

    /**
     * Encodes a Texture2D to PNG format bytes.
     * 
     * @param tex Source texture (must be readable)
     * @return PNG file data as bytes, or null if encoding fails
     * 
     * Features:
     * - Lossless compression
     * - Preserves alpha channel
     * - Smaller file size than TGA
     * - Wide compatibility
     * 
     * @example Saving a texture:
     * ```haxe
     * var pngData = ImageConversion.EncodeToPNG(myTexture);
     * File.saveBytes("screenshot.png", Bytes.ofData(pngData));
     * ```
     * 
     * Note: Texture must have Read/Write enabled in import settings.
     */
    static function EncodeToPNG(tex:Texture2D):BytesData;

    /**
     * Encodes a Texture2D to JPEG format with specified quality.
     * 
     * @param tex Source texture (must be readable)
     * @param quality JPEG compression quality (1-100):
     *               1 = Lowest quality, smallest file
     *               75 = Good balance (recommended)
     *               100 = Highest quality, largest file
     * @return JPEG file data as bytes, or null if encoding fails
     * 
     * Features:
     * - Lossy compression (smaller files)
     * - No alpha channel support
     * - Good for photos/complex images
     * 
     * Note: Alpha channel is converted to black.
     * Use PNG for images requiring transparency.
     */
    static function EncodeToJPG(tex:Texture2D, quality:Int):BytesData;

    /**
     * Loads image data into an existing Texture2D.
     * Automatically detects format (PNG, JPG, etc.).
     * 
     * @param tex Target texture (will be resized to match image)
     * @param data Image file bytes (PNG, JPG, etc.)
     * @param markNonReadable If true, marks texture as non-readable
     *                       after loading (saves memory)
     * @return True if loading succeeded, false otherwise
     * 
     * @example Loading downloaded image:
     * ```haxe
     * var texture = new Texture2D(2, 2); // Size will be replaced
     * if (ImageConversion.LoadImage(texture, imageBytes, false)) {
     *     // Texture now contains the image
     * }
     * ```
     * 
     * Supported formats: PNG, JPG, TGA, BMP, GIF, and more.
     * Format detected automatically from file data.
     */
    static function LoadImage(tex:Texture2D, data:BytesData, markNonReadable:Bool):Bool;

}
