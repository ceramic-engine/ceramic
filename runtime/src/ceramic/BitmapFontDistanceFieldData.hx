package ceramic;

/**
 * Configuration data for distance field fonts (SDF/MSDF).
 * 
 * Distance field fonts store distance-to-edge information instead of direct
 * pixel values, enabling high-quality scaling without the pixelation issues
 * of traditional bitmap fonts. This is especially useful for:
 * - UI text that needs to scale smoothly
 * - Text rendered at various sizes from a single texture
 * - Sharp text rendering at any resolution
 * 
 * MSDF (Multi-channel Signed Distance Field) fonts provide superior quality
 * compared to regular SDF by encoding distance information across RGB channels,
 * preserving sharp corners and fine details.
 * 
 * ```haxe
 * // Check if font uses distance fields
 * if (font.fontData.distanceField != null) {
 *     var msdf = font.fontData.distanceField.fieldType == 'msdf';
 *     var range = font.fontData.distanceField.distanceRange;
 *     // Font can be scaled smoothly
 * }
 * ```
 * 
 * @see BitmapFontData.distanceField Where this data is stored
 * @see BitmapFont.msdf Convenience property to check for MSDF fonts
 */
@:structInit
class BitmapFontDistanceFieldData {

    /**
     * The type of distance field encoding used in the font texture.
     * 
     * Supported values:
     * - `'msdf'`: Multi-channel Signed Distance Field (recommended)
     *   Uses RGB channels to encode distance data, providing sharp corners
     *   and excellent quality at all scales.
     * 
     * - `'sdf'`: Standard Signed Distance Field (not supported in Ceramic)
     *   Uses a single channel for distance data. While simpler, it has
     *   lower quality than MSDF. Use MSDF instead.
     * 
     * The field type determines which shader and rendering technique
     * will be used for the font.
     */
    public var fieldType:String;

    /**
     * The distance range in pixels used during font generation.
     * 
     * This value represents the maximum distance (in texture pixels) that
     * was calculated from each glyph edge during distance field generation.
     * It directly affects rendering quality:
     * 
     * - Lower values (2-4): Sharper edges, may show artifacts at extreme scales
     * - Higher values (4-8): Smoother edges, better for large scale variations
     * - Typical value: 4 pixels
     * 
     * This value is passed to the MSDF shader to correctly interpret
     * the distance field data during rendering.
     * 
     * ```haxe
     * // In shader setup
     * shader.setFloat('pxRange', fontData.distanceField.distanceRange);
     * ```
     */
    public var distanceRange:Int;

}