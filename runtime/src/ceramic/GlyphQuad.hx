package ceramic;

/**
 * A specialized Quad that represents a single rendered glyph (character) in text rendering.
 * 
 * GlyphQuad extends Quad to add text-specific metadata and tracking information.
 * Each instance represents one visible character in a Text display, containing
 * both the visual representation (texture from the font atlas) and metadata
 * about the character's position within the text.
 * 
 * This class is primarily used internally by the Text class for efficient
 * glyph management, pooling, and event handling. Each glyph can be individually
 * positioned, styled, and tracked.
 * 
 * @example
 * ```haxe
 * // Typically created internally by Text, but can be accessed:
 * text.onGlyphQuadsChange(this, (glyphQuads) -> {
 *     for (quad in glyphQuads) {
 *         trace('Character ${quad.char} at position ${quad.index}');
 *         trace('Line ${quad.line}, position in line: ${quad.posInLine}');
 *     }
 * });
 * ```
 * 
 * @see Text The main text rendering class that manages GlyphQuads
 * @see BitmapFontCharacter The glyph data this quad represents
 */
class GlyphQuad extends Quad {

    /**
     * Event triggered when this glyph quad is cleared or recycled.
     * 
     * This event fires before the quad is returned to the pool or destroyed,
     * allowing cleanup of any references or custom data attached to the glyph.
     * 
     * @param quad The GlyphQuad being cleared
     */
    @event function clear(quad:GlyphQuad);

    /**
     * The character string this quad represents.
     * 
     * Usually a single character, but can be multiple characters for
     * ligatures or composed characters. Null if the quad is not active.
     */
    public var char:String = null;

    /**
     * Reference to the bitmap font character data.
     * 
     * Contains texture coordinates, metrics, and other rendering information
     * for this specific glyph from the font atlas.
     */
    public var glyph:BitmapFontCharacter = null;

    /**
     * The absolute character index in the source text.
     * 
     * This is the position of the character in the original text string,
     * starting from 0. Useful for mapping glyphs back to text positions.
     * Set to -1 when the quad is not active.
     */
    public var index:Int = -1;

    /**
     * The character's position within its line.
     * 
     * Zero-based index indicating this character's position on the current
     * line of text. Resets to 0 at the start of each new line.
     * Set to -1 when the quad is not active.
     */
    public var posInLine:Int = -1;

    /**
     * The line number this character appears on.
     * 
     * Zero-based line index for multi-line text. Increments with each
     * line break in the rendered text. Set to -1 when the quad is not active.
     */
    public var line:Int = -1;

    /**
     * The Unicode code point of the character.
     * 
     * The numeric representation of the character (e.g., 65 for 'A').
     * Useful for character-specific logic or debugging.
     * Set to -1 when the quad is not active.
     */
    public var code:Int = -1;

    /**
     * The x-coordinate where this glyph starts in text layout.
     * 
     * This is the horizontal position where the glyph begins, before
     * applying any character-specific offsets. In the text's local
     * coordinate space. Set to -1 when the quad is not active.
     */
    public var glyphX:Float = -1;

    /**
     * The y-coordinate where this glyph starts in text layout.
     * 
     * This is the vertical position (baseline) where the glyph is placed,
     * before applying any character-specific offsets. In the text's local
     * coordinate space. Set to -1 when the quad is not active.
     */
    public var glyphY:Float = -1;

    /**
     * The horizontal advance width for this glyph.
     * 
     * The distance to advance the cursor after rendering this character,
     * including the character width and spacing. Does not include kerning
     * with the next character. Set to -1 when the quad is not active.
     */
    public var glyphAdvance:Float = -1;

/// Print

    /**
     * Returns a string representation of this GlyphQuad for debugging.
     * 
     * Includes the character, index, line number, and position information
     * in a compact format suitable for logging or debugging text layout issues.
     * 
     * @return A string like "GlyphQuad(c=A,i=0,l=0,x=10.5,y=20.0)"
     */
    override function toString() {

        return 'GlyphQuad(c=$char,i=$index,l=$line,x=$glyphX,y=$glyphY)';

    }

    /**
     * Clears this glyph quad and prepares it for reuse.
     * 
     * Emits the clear event before calling the parent clear method,
     * allowing listeners to perform cleanup. This is typically called
     * when the quad is returned to a pool or when text content changes.
     */
    override function clear() {

        emitClear(this);

        super.clear();

    }

}
