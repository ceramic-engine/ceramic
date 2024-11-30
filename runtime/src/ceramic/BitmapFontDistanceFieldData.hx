package ceramic;

/**
 * Data structure containing distance field information for a bitmap font.
 * Distance fields are used to enable high quality scaling of bitmap fonts by
 * storing distance information in the font texture instead of direct pixel values.
 */
@:structInit
class BitmapFontDistanceFieldData {

    /**
     * The type of distance field used.
     * Common values include:
     * - 'msdf' for Multi-channel Signed Distance Field
     * - 'sdf' for Signed Distance Field (but this is not supported by Ceramic. Use 'msdf' instead)
     */
    public var fieldType:String;

    /**
     * The range in pixels used to generate the distance field.
     * This value affects how sharp or smooth the font edges appear when scaled.
     * Typical values are between 2 and 8 pixels.
     */
    public var distanceRange:Int;

}