// Original code for Glaze (not a port): the look of rasterized text.
package glaze;

/**
 * How glyph outlines are rasterized (`TextSystem.fontSmoothing`, global to
 * a text system).
 *
 * - `Dense` (Glaze's default, on every platform): stems are made thicker,
 *   close to the font smoothing of macOS (CoreGraphics, what Safari, Chrome
 *   and native apps show there): the outline grows by an amount that
 *   depends on the size in device pixels and, a little, on the luminance of
 *   the text color (light text grows more). The amounts were measured on
 *   Chromium's text on macOS (CoreText through Skia) for several fonts,
 *   sizes and colors; the result is the same on every platform.
 * - `Thin`: the raw coverage of the outline, without dilation (what the
 *   real GPUI renders with its font file text system, and what Glaze did
 *   before this setting; the Glaze golden uses it).
 * - `Auto`: the usual look of the platform, like CSS
 *   `-webkit-font-smoothing: auto`: `Dense` on macOS (natively, or in a
 *   browser running on macOS), `Thin` elsewhere (Windows and Linux render
 *   grayscale text without stem darkening).
 *
 * The default can be changed at compile time with the define
 * `glaze_font_smoothing=thin` (or `dense`, `auto`).
 */
enum abstract FontSmoothing(Int) from Int to Int {

    var Dense = 0;

    var Thin = 1;

    var Auto = 2;

    /**
     * The compile time default (`glaze_font_smoothing`), `Dense` when not
     * defined.
     */
    public static function compileTimeDefault():FontSmoothing {
        #if glaze_font_smoothing
        final value = haxe.macro.Compiler.getDefine('glaze_font_smoothing');
        return switch value {
            case 'thin': Thin;
            case 'auto': Auto;
            case _: Dense;
        }
        #else
        return Dense;
        #end
    }

    /**
     * `Dense` or `Thin`: what `Auto` gives on the current platform.
     */
    public function resolve():FontSmoothing {
        if (this != Auto) {
            return this;
        }
        return isMacPlatform() ? Dense : Thin;
    }

    static function isMacPlatform():Bool {
        #if js
        try {
            final platform:String = js.Syntax.code('(typeof navigator !== "undefined" && navigator.platform) ? navigator.platform : ""');
            return platform != null && StringTools.startsWith(platform, 'Mac');
        }
        catch (e:Dynamic) {
            return false;
        }
        #elseif (mac || macos)
        return true;
        #elseif sys
        return Sys.systemName() == 'Mac';
        #else
        return false;
        #end
    }

    /**
     * The dilation code of a glyph painted in `color` (part of the glyph
     * cache key, `RenderGlyphParams.dilation`): 0 without dilation, else
     * 1 + the luminance level of the color (0 to 3).
     */
    public function dilationCodeForColor(color:Hsla):Int {
        if (resolve() != Dense) {
            return 0;
        }
        return 1 + luminanceLevel(color);
    }

    /**
     * The luminance level of a text color (0 to 3): the luma of its sRGB
     * components, in quarters, at most 3 (CoreGraphics darkens text in a
     * few steps of the foreground luminance: black, dark gray, mid gray,
     * light gray and white are the measured steps 0, 1, 2, 2 and 3).
     */
    public static function luminanceLevel(color:Hsla):Int {
        // `color.toRgb()` (`Rgba.fromHsla`) without the `Rgba`: this runs for
        // every glyph painted
        final h = color.h;
        final s = color.s;
        final l = color.l;
        final c = (1.0 - Math.abs(2.0 * l - 1.0)) * s;
        final x = c * (1.0 - Math.abs((h * 6.0) % 2.0 - 1.0));
        final m = l - c / 2.0;
        final cm = c + m;
        final xm = x + m;
        var r:Float;
        var g:Float;
        var b:Float;
        switch glaze.util.MathUtil.toI32(Math.ffloor(h * 6.0)) {
            case 0 | 6:
                r = cm; g = xm; b = m;
            case 1:
                r = xm; g = cm; b = m;
            case 2:
                r = m; g = cm; b = xm;
            case 3:
                r = m; g = xm; b = cm;
            case 4:
                r = xm; g = m; b = cm;
            case _:
                r = cm; g = m; b = xm;
        }
        r = glaze.util.MathUtil.clamp(r, 0.0, 1.0);
        g = glaze.util.MathUtil.clamp(g, 0.0, 1.0);
        b = glaze.util.MathUtil.clamp(b, 0.0, 1.0);
        final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        var level = Math.floor(4 * luma);
        if (level < 0) {
            level = 0;
        }
        else if (level > 3) {
            level = 3;
        }
        return level;
    }

    /**
     * The total dilation (pixels, the outline grows by half of it on each
     * side) of `Dense` for a glyph of `ppem` device pixels per em and a text
     * color of luminance level `level` (0 to 3): 0.0115 per pixel per em up
     * to 0.64 px, plus 0.1 px per level. Measured on Chromium on macOS
     * (Maple Mono Light and Bold, JetBrains Mono, Inter, 22 to 64 px per em,
     * gray levels from black to white): the ink of a line is within about
     * 2% of Chromium's.
     */
    public static function denseDilation(ppem:Float, level:Int):Float {
        var base = 0.0115 * ppem;
        if (base > 0.64) {
            base = 0.64;
        }
        return base + 0.1 * level;
    }

}
