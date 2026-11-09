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
    @:optional var border:IDecorationBorder;
    /**
     * Join contiguous ranges with the same style into one box per line:
     * only the outer corners are rounded (a pill made of several
     * decorations, without the CSS `:has(+ ...)` hack). True by default for
     * boxes with a background.
     */
    @:optional var join:Bool;
}

/**
 * Decoration styles registered by class name (`registerDecorationStyle`),
 * so that Monaco code using `className`, `inlineClassName` and the other
 * class names keeps working. One registry per `Cityscape` context.
 */
class DecorationStyles {

    final styles:Map<String, IDecorationStyle> = new Map();

    /**
     * Incremented at each change, so that resolved styles can be cached.
     */
    public var version(default, null):Int = 0;

    public function new() {}

    /**
     * Gives a style to a class name. Several class names separated by spaces
     * in a decoration combine their styles, in order.
     */
    public function registerDecorationStyle(className:String, style:IDecorationStyle):Void {
        styles.set(className, style);
        version++;
    }

    public function unregisterDecorationStyle(className:String):Void {
        if (styles.remove(className)) {
            version++;
        }
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
