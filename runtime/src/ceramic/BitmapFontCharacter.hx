package ceramic;

/**
 * Represents a single character (glyph) in a bitmap font.
 *
 * This data structure stores all the metrics and texture coordinates needed
 * to correctly render a character from a bitmap font texture atlas. Each
 * character has position data for locating it in the texture, size information,
 * and rendering offsets for proper alignment.
 *
 * The character metrics follow standard font terminology:
 * - Texture coordinates (x, y, width, height) define the glyph's location in the atlas
 * - Offsets (xOffset, yOffset) position the glyph relative to the baseline
 * - Advance (xAdvance) determines cursor movement after rendering
 *
 * ```haxe
 * var charA = font.chars.get(65); // Get letter 'A'
 * var texture = font.pages.get(charA.page);
 *
 * // Render a single character with a quad.
 * // This is just for reference. In practice,
 * // you'd rather use Text class with a bitmap font
 * quad.texture = texture;
 * quad.frameX = charA.x;
 * quad.frameY = charA.y;
 * quad.frameWidth = charA.width;
 * quad.frameHeight = charA.height;
 * quad.pos(cursorX + charA.xOffset, cursorY + charA.yOffset);
 *
 * // Move cursor for next character
 * cursorX += charA.xAdvance;
 * ```
 *
 * @see BitmapFont The font class that contains these characters
 * @see BitmapFontData The complete font data structure
 * @see Text To render text using a bitmap font
 */
@:structInit
class BitmapFontCharacter {

    /**
     * The character's Unicode code point.
     *
     * This is the numeric representation of the character, e.g.:
     * - 65 for 'A'
     * - 32 for space
     * - 8364 for '€'
     */
    public var id:Int;

    /**
     * The x-coordinate of the character in the texture atlas.
     *
     * This is the left edge of the character's bounding box
     * within the texture, measured in pixels from the texture's origin.
     */
    public var x:Float;

    /**
     * The y-coordinate of the character in the texture atlas.
     *
     * This is the top edge of the character's bounding box
     * within the texture, measured in pixels from the texture's origin.
     */
    public var y:Float;

    /**
     * The width of the character in the texture atlas.
     *
     * This is the horizontal size of the character's bounding box
     * in pixels. May include padding depending on font generation settings.
     */
    public var width:Float;

    /**
     * The height of the character in the texture atlas.
     *
     * This is the vertical size of the character's bounding box
     * in pixels. May include padding depending on font generation settings.
     */
    public var height:Float;

    /**
     * The horizontal offset for rendering this character.
     *
     * This value adjusts the character's position relative to the
     * current cursor position. Positive values move the character right,
     * negative values move it left. Used for proper glyph alignment.
     */
    public var xOffset:Float;

    /**
     * The vertical offset for rendering this character.
     *
     * This value adjusts the character's position relative to the
     * text baseline. Positive values move the character down,
     * negative values move it up. Essential for proper vertical alignment.
     */
    public var yOffset:Float;

    /**
     * The horizontal advance width for this character.
     *
     * This is the distance to move the cursor after rendering this
     * character, before rendering the next one. Includes the character
     * width plus any additional spacing. Does not include kerning.
     */
    public var xAdvance:Float;

    /**
     * The texture page index where this character is stored.
     *
     * Bitmap fonts can span multiple texture pages to accommodate
     * large character sets. This index identifies which texture
     * contains this particular character's image data.
     */
    public var page:Int;
}
