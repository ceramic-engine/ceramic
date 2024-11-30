package ceramic;

/**
 * Data structure containing information about a bitmap font,
 * including character metrics, kerning and texture pages.
 * Used by the Ceramic engine to render text using bitmap fonts.
 */
@:structInit
class BitmapFontData {

    /** The name of the font face */
    public var face:String;

    /** Path to the font file */
    public var path:String;

    /** Font size in points */
    public var pointSize:Float;

    /** Base size of the font in pixels */
    public var baseSize:Float;

    /** Map of font characters indexed by their character code */
    public var chars:IntMap<BitmapFontCharacter>;

    /** Total number of characters in the font */
    public var charCount:Int;

    /** Optional signed distance field data when font uses SDF rendering */
    public var distanceField:Null<BitmapFontDistanceFieldData>;

    /** Array of texture pages containing the font glyphs */
    public var pages:Array<BitmapFontDataPage>;

    /** Height of a line of text in pixels */
    public var lineHeight:Float;

    /** Kerning information between character pairs.
     * First key is the first character code,
     * second key is the second character code,
     * value is the kerning offset in pixels. */
    public var kernings:IntMap<IntFloatMap>;
}

/**
 * Information about a texture page containing font glyphs
 */
@:structInit
class BitmapFontDataPage {

    /** Unique identifier of the texture page */
    public var id:Int;

    /** Path to the texture file containing the glyphs */
    public var file:String;
}
