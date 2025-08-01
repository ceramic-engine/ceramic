package ceramic;

/**
 * Complete data structure containing all information about a bitmap font.
 * 
 * BitmapFontData stores everything needed to render text with a bitmap font:
 * character definitions, texture page references, kerning pairs, and metrics.
 * This data is typically loaded from font definition files (like BMFont format)
 * and used to construct a BitmapFont instance.
 * 
 * The data includes:
 * - Font metadata (face name, sizes)
 * - Character definitions with texture coordinates and metrics
 * - Texture page information for multi-page fonts
 * - Kerning data for improved character spacing
 * - Optional distance field data for high-quality scaling
 * 
 * @example
 * ```haxe
 * var fontData:BitmapFontData = {
 *     face: "Arial",
 *     pointSize: 32,
 *     baseSize: 32,
 *     lineHeight: 40,
 *     chars: new IntMap(),
 *     pages: [{id: 0, file: "arial_0.png"}],
 *     kernings: new IntMap()
 * };
 * ```
 * 
 * @see BitmapFont The font class that uses this data
 * @see BitmapFontParser For loading font data from files
 */
@:structInit
class BitmapFontData {

    /**
     * The name of the font face (e.g., "Arial", "Helvetica").
     * This identifies the typeface family.
     */
    public var face:String;

    /**
     * Path to the directory containing the font files.
     * Used to resolve relative paths for texture pages.
     * Can be null or empty for fonts in the root directory.
     */
    public var path:String;

    /**
     * Font size in points at which the glyphs were rendered.
     * This is the reference size for all metrics. When rendering
     * at different sizes, metrics are scaled proportionally.
     */
    public var pointSize:Float;

    /**
     * Base size of the font in pixels.
     * Usually matches pointSize but may differ depending on
     * the tool used to generate the bitmap font.
     */
    public var baseSize:Float;

    /**
     * Map of all characters in the font, indexed by Unicode code point.
     * Each character contains texture coordinates, size, and positioning data.
     * Missing characters will not be present in the map.
     */
    public var chars:IntMap<BitmapFontCharacter>;

    /**
     * Total number of characters defined in this font.
     * This count includes all glyphs across all texture pages.
     * Useful for validation and statistics.
     */
    public var charCount:Int;

    /**
     * Optional distance field data for SDF (Signed Distance Field) fonts.
     * When present, indicates this is an MSDF font that can be scaled
     * without quality loss. Null for regular bitmap fonts.
     * @see BitmapFontDistanceFieldData
     */
    public var distanceField:Null<BitmapFontDistanceFieldData>;

    /**
     * Array of texture pages containing the font glyphs.
     * Large fonts may span multiple textures to fit all characters.
     * Pages are referenced by index in BitmapFontCharacter.page.
     */
    public var pages:Array<BitmapFontDataPage>;

    /**
     * Recommended line height in pixels.
     * This is the vertical distance between baselines of consecutive
     * lines of text. Includes ascent, descent, and line gap.
     */
    public var lineHeight:Float;

    /**
     * Kerning information for character pairs.
     * 
     * Kerning adjusts the spacing between specific character pairs
     * for better visual appearance (e.g., "AV" vs "AA").
     * 
     * Structure: kernings[firstChar][secondChar] = adjustment
     * - First key: Unicode code point of the first character
     * - Second key: Unicode code point of the second character  
     * - Value: Horizontal adjustment in pixels (usually negative)
     * 
     * @example
     * ```haxe
     * var kernValue = kernings.get(65)?.get(86); // Kerning for "AV"
     * if (kernValue != null) cursorX += kernValue;
     * ```
     */
    public var kernings:IntMap<IntFloatMap>;
}

/**
 * Information about a single texture page in a multi-page bitmap font.
 * 
 * Large bitmap fonts may require multiple texture pages to accommodate
 * all characters. Each page is a separate texture file containing a
 * subset of the font's glyphs. Characters reference their page by ID.
 * 
 * @see BitmapFontData.pages Where page data is stored
 * @see BitmapFontCharacter.page References page by ID
 */
@:structInit
class BitmapFontDataPage {

    /**
     * Unique identifier of this texture page.
     * Referenced by characters to indicate which texture contains their glyph.
     * Typically starts at 0 and increments for each additional page.
     */
    public var id:Int;

    /**
     * Path to the texture file containing the glyphs.
     * Can be relative (resolved using BitmapFontData.path) or absolute.
     * Common formats: PNG, TGA, or other image formats supported by the engine.
     */
    public var file:String;
}
