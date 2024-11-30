package ceramic;

/**
 * Represents a single character in a bitmap font.
 * This class stores all the metrics needed to render
 * a character from a bitmap font texture atlas.
 */
@:structInit
class BitmapFontCharacter {

    /** The character id (unicode value) */
    public var id:Int;

    /** The x position of the character in the texture atlas */
    public var x:Float;

    /** The y position of the character in the texture atlas */
    public var y:Float;

    /** The width of the character in the texture atlas */
    public var width:Float;

    /** The height of the character in the texture atlas */
    public var height:Float;

    /** The x offset to apply when rendering this character */
    public var xOffset:Float;

    /** The y offset to apply when rendering this character */
    public var yOffset:Float;

    /** The horizontal advance (spacing) after this character */
    public var xAdvance:Float;

    /** The texture page index where this character is stored */
    public var page:Int;
}
