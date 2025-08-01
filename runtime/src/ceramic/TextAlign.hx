package ceramic;

/**
 * Horizontal text alignment options for text rendering.
 * 
 * Controls how text lines are positioned horizontally within their container
 * or relative to their anchor point. This enum is used by the Text class
 * to determine the horizontal alignment of text content.
 * 
 * The alignment affects:
 * - Multi-line text: Each line is aligned independently
 * - Single-line text: Positions the text relative to its anchor
 * - Text bounds: The alignment point determines which edge or center is used
 * 
 * @example
 * ```haxe
 * // Create centered text
 * var title = new Text();
 * title.content = "Game Title";
 * title.align = CENTER;
 * title.anchor(0.5, 0.5); // Center anchor point
 * title.pos(screen.width * 0.5, 100);
 * 
 * // Create right-aligned score
 * var score = new Text();
 * score.content = "Score: 1000";
 * score.align = RIGHT;
 * score.pos(screen.width - 20, 20);
 * ```
 * 
 * @see Text.align The property that uses this enum
 * @see Text The main text rendering class
 */
enum TextAlign {

    /**
     * Align text to the left edge.
     * 
     * - Text starts at the x position and extends to the right
     * - Multi-line text: All lines start at the same x coordinate
     * - Default alignment for most text
     * - Natural for left-to-right languages
     * 
     * @example
     * ```haxe
     * text.align = LEFT;
     * text.pos(10, 10); // Text starts at x=10
     * ```
     */
    LEFT;

    /**
     * Align text to the right edge.
     * 
     * - Text ends at the x position and extends to the left
     * - Multi-line text: All lines end at the same x coordinate
     * - Useful for numeric displays, scores, or right-to-left languages
     * - Common in UI elements like menus
     * 
     * @example
     * ```haxe
     * text.align = RIGHT;
     * text.pos(screen.width - 10, 10); // Text ends at x=screen.width-10
     * ```
     */
    RIGHT;

    /**
     * Center text horizontally.
     * 
     * - Text is centered around the x position
     * - Multi-line text: Each line is individually centered
     * - Common for titles, headings, and UI labels
     * - Works well with centered anchor points
     * 
     * @example
     * ```haxe
     * text.align = CENTER;
     * text.anchor(0.5, 0.5);
     * text.pos(screen.width * 0.5, screen.height * 0.5);
     * ```
     */
    CENTER;

}
