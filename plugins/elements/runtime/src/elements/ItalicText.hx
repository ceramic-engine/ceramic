package elements;

import ceramic.Component;
import ceramic.Entity;
import ceramic.Text;

/**
 * A component that applies italic-style skewing to Text visuals.
 * 
 * This component simulates italic text by applying a horizontal skew transform
 * to each glyph quad in a Text visual. This is useful when true italic fonts
 * are not available or when a consistent italic angle is desired across
 * different fonts.
 * 
 * ## Features
 * 
 * - Applies uniform skew to all glyphs
 * - Automatically updates when text content changes
 * - Configurable skew angle
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var text = new Text();
 * text.content = "Hello World";
 * text.component(new ItalicText());
 * 
 * // Adjust italic angle (default is 10 degrees)
 * var italic = text.component<ItalicText>();
 * italic.skewX = 15; // More pronounced italic
 * ```
 * 
 * @see ceramic.Text
 * @see ceramic.GlyphQuad
 */
class ItalicText extends Entity implements Component {

    /**
     * The Text entity this component is attached to.
     * Automatically set when the component is bound.
     */
    public var entity:Text;

    /**
     * The horizontal skew angle in degrees to apply to each glyph.
     * Positive values skew to the right (standard italic).
     * Default is 10 degrees.
     */
    public var skewX(default,set):Float = 10;
    function set_skewX(skewX:Float):Float {
        if (this.skewX == skewX) return skewX;
        if (entity != null) applyItalicTransform();
        return skewX;
    }

/// Lifecycle

    /**
     * Called when this component is bound to a Text entity.
     * Sets up listeners to apply italic transform when glyphs change.
     */
    function bindAsComponent():Void {

        entity.onGlyphQuadsChange(this, applyItalicTransform);

    }

/// Internal

    /**
     * Applies the italic skew transform to all glyph quads in the text.
     * Called automatically when text content or skewX changes.
     */
    function applyItalicTransform() {

        if (entity.glyphQuads == null) return;

        for (i in 0...entity.glyphQuads.length) {
            var glyph = entity.glyphQuads[i];
            glyph.skewX = skewX;
        }

    }

}
