// New code for Cityscape (not a port): the typed decoration style that
// replaces Monaco's CSS class names (see the plan, "API de décorations").
package cityscape.common;

import cityscape.common.Model.DecorationColor;

/**
 * A line drawn under or through text.
 */
typedef IDecorationTextLine = {
    /**
     * The color, the text color when not set.
     */
    @:optional var color:DecorationColor;
    /**
     * The thickness in pixels (1 by default).
     */
    @:optional var thickness:Float;
    /**
     * A wavy line (underline only, like the squiggles of diagnostics).
     */
    @:optional var wavy:Bool;
}

/**
 * A border around a decoration box.
 */
typedef IDecorationBorder = {
    @:optional var color:DecorationColor;
    /**
     * The width in pixels (1 by default).
     */
    @:optional var width:Float;
}

/**
 * The typed style of a decoration: what a CSS class gives in Monaco.
 *
 * Text properties apply to `inlineStyle` (and to injected text); box
 * properties apply to `inlineStyle` and `style` (a box drawn behind the
 * text of the range), to `lineStyle` (the whole line) and to the margin
 * styles. Colors are CSS-like strings (`#rgb`, `#rrggbb`, `#rrggbbaa`,
 * `rgb()`, `rgba()`, `hsl()`, `hsla()`, `transparent`) or theme color keys
 * (`ThemeColor`, `{id: 'editorError.foreground'}`).
 */
typedef IDecorationStyle = {
    // Cascade

    /**
     * Like CSS `!important` on every property of the style: when several
     * styles of a part set a property, an important one wins over the
     * others, whatever their priority and order.
     */
    @:optional var important:Bool;
    /**
     * The precedence of the style among the styles of a part with the same
     * importance (0 by default): when several set a property, the highest
     * priority wins; on equal priority the style registered last wins (the
     * order of rules in a CSS style sheet), and typed styles given directly
     * to a decoration win over registered class styles, in the order of the
     * decorations on the part (Monaco orders the class names of a part by
     * decoration end offset).
     */
    @:optional var priority:Float;

    // Text

    /**
     * The text color.
     */
    @:optional var color:DecorationColor;
    /**
     * `'normal'` or `'italic'`.
     */
    @:optional var fontStyle:String;
    /**
     * `'normal'`, `'bold'`, or a CSS weight (`'100'` to `'900'`).
     */
    @:optional var fontWeight:String;
    /**
     * The opacity of the text, from 0 to 1 (multiplied with the color alpha).
     */
    @:optional var opacity:Float;
    @:optional var underline:IDecorationTextLine;
    @:optional var strikethrough:IDecorationTextLine;
    /**
     * Extra space after each character, in pixels (CSS `letter-spacing`).
     * Hook only for now: the range is laid out without it (TODO: needs the
     * Glaze letter spacing per run, AUDIT A.1.6).
     */
    @:optional var letterSpacing:Float;
    /**
     * OpenType features of the range, CSS `font-feature-settings` syntax
     * (`'"liga" 0, "calt" 0'`): ligatures can be cut on a range.
     */
    @:optional var fontFeatures:String;

    // Box

    /**
     * The background color of the box.
     */
    @:optional var background:DecorationColor;
    /**
     * The corner radius of the box, in pixels.
     */
    @:optional var borderRadius:Float;
    /**
     * Vertical padding of the box, in pixels: like CSS padding on an inline
     * element, it grows the box around the font's content area without
     * moving the text. Negative values shrink it.
     */
    @:optional var paddingTop:Float;
    @:optional var paddingBottom:Float;
    /**
     * Horizontal padding of the box, in pixels: like CSS padding on an
     * inline element, the box grows by it and the text after it moves
     * (the inlay hints' `padding: 0 3px`). Inline styles and injected text
     * only (step 7, cs7-rest-inlay).
     */
    @:optional var paddingLeft:Float;
    @:optional var paddingRight:Float;
    /**
     * The width of the range in pixels, whatever its text (CSS
     * `display: inline-block; width`, the spacers of the inlay hints).
     * Inline styles and injected text only (step 7, cs7-rest-inlay).
     */
    @:optional var width:Float;
    @:optional var border:IDecorationBorder;
    /**
     * Join contiguous ranges with the same style into one box per line:
     * only the outer corners are rounded (a pill made of several
     * decorations, without the CSS `:has(+ ...)` hack). True by default for
     * boxes with a background.
     */
    @:optional var join:Bool;
    // Snippets (step 7, cs7-rest-snip)
    /**
     * The minimum width of the box, in pixels (CSS `min-width`): a box of
     * a `className` decoration with an empty range is painted this wide,
     * centered on its position (the snippet placeholders of Monaco, whose
     * empty tab stops show as a thin box).
     */
    @:optional var minWidth:Float;
}

/**
 * Decoration styles registered by class name (`registerDecorationStyle`),
 * so that Monaco code using `className`, `inlineClassName` and the other
 * class names keeps working. One registry per `Cityscape` context.
 */
class DecorationStyles {

    final styles:Map<String, IDecorationStyle> = new Map();
    final orders:Map<String, Int> = new Map();
    var nextOrder:Int = 0;

    /**
     * Incremented at each change, so that resolved styles can be cached.
     */
    public var version(default, null):Int = 0;

    public function new() {}

    /**
     * Gives a style to a class name. When several styles apply to a part of
     * a line, each property comes from the style that wins the cascade
     * (`important`, then `priority`, then the style registered last, like
     * the rules of a CSS style sheet): registering a class name again moves
     * it to the end of that order.
     */
    public function registerDecorationStyle(className:String, style:IDecorationStyle):Void {
        styles.set(className, style);
        orders.set(className, nextOrder++);
        version++;
    }

    public function unregisterDecorationStyle(className:String):Void {
        orders.remove(className);
        if (styles.remove(className)) {
            version++;
        }
    }

    /**
     * The registration order of `className` (higher is later), -1 when not
     * registered.
     */
    public function orderOf(className:String):Int {
        final order = orders.get(className);
        return order == null ? -1 : order;
    }

    /**
     * The style registered for `className`, or `null`.
     */
    public function get(className:String):Null<IDecorationStyle> {
        return styles.get(className);
    }

    /**
     * Whether some style is registered for one of the space separated class
     * names of `classNames`.
     */
    public function hasAny(classNames:Null<String>):Bool {
        if (classNames == null || classNames.length == 0) {
            return false;
        }
        if (classNames.indexOf(' ') == -1) {
            return styles.exists(classNames);
        }
        for (name in classNames.split(' ')) {
            if (styles.exists(name)) {
                return true;
            }
        }
        return false;
    }

}
