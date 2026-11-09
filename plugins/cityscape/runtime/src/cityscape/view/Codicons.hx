// New code for Cityscape (not a port): the codicons Monaco's view draws
// with the codicon font (folding controls), drawn by Glaze as SVG outlines.
// The outlines are the glyphs of codicon.ttf (vscode-codicons, Copyright (c)
// Microsoft Corporation, CC BY 4.0, shipped with monaco-editor): see NOTICE.md.
package cityscape.view;

import glaze.App;
import glaze.Bounds;
import glaze.Hsla;
import glaze.Point;
import glaze.Size;
import glaze.Window;

/**
 * Codicon glyphs, as Monaco draws them with the codicon font.
 *
 * Each glyph is its outline from codicon.ttf (unitsPerEm 300, ascender 300,
 * descender 0, advance 300), written as an SVG path in a 300x300 viewBox
 * (y down): the viewBox is the em square, its bottom edge the baseline.
 * Measured on the real Monaco 0.52.2 (glaze-golden scratchpad
 * cs4-edit-chevrons): the folding controls are the glyphs at 140% of the
 * editor font size, centered in the line decorations, `margin-left: 2px`.
 */
class Codicons {

    /**
     * `codicon-folding-expanded` (`chevron-down`, U+EAB4).
     */
    public static inline final FOLDING_EXPANDED_PATH = 'M150 189 L231 107 L243 119 L155 206 L144 206 L56 119 L68 107 Z';

    /**
     * `codicon-folding-collapsed` (`chevron-right`, U+EAB6).
     */
    public static inline final FOLDING_COLLAPSED_PATH = 'M189 150 L107 69 L119 57 L206 145 L206 156 L119 244 L107 232 Z';

    /**
     * The ascent Blink gives the codicon font, as a fraction of the font
     * size (19.5 px at 19.6 px): the baseline of a codicon line box.
     */
    public static inline final ASCENT = 19.5 / 19.6;

    static var _svgs:Null<Map<String, haxe.io.Bytes>> = null;

    static function svgData(key:String, path:String):haxe.io.Bytes {
        if (_svgs == null) {
            _svgs = new Map();
        }
        var data = _svgs.get(key);
        if (data == null) {
            data = haxe.io.Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300"><path fill="#000" d="' + path + '"/></svg>');
            _svgs.set(key, data);
        }
        return data;
    }

    /**
     * Paints a folding codicon whose em square is `size` pixels wide, its
     * left edge at `left` and its baseline at `baseline` (the baseline is
     * snapped to whole device pixels, like text).
     */
    public static function paintFoldingIcon(window:Window, cx:App, left:Float, baseline:Float, size:Float, collapsed:Bool, color:Hsla):Void {
        final scale = window.scaleFactor();
        final snappedBaseline = Math.round(baseline * scale) / scale;
        final key = collapsed ? 'cityscape/codicon-folding-collapsed.svg' : 'cityscape/codicon-folding-expanded.svg';
        final data = svgData(key, collapsed ? FOLDING_COLLAPSED_PATH : FOLDING_EXPANDED_PATH);
        try {
            window.paintSvg(new Bounds(new Point(left, snappedBaseline - size), new Size(size, size)), key, data, null, color, cx);
        }
        catch (e:Dynamic) {
            // no SVG renderer: nothing drawn
        }
    }

    /**
     * Monaco's gutter folding control (folding.css: the codicon at
     * `font-size: 140%`, `margin-left: 2px`, centered in the line
     * decorations of `decorationsWidth`, vertically centered in the line
     * with the codicon line height).
     */
    public static function paintGutterFoldingIcon(window:Window, cx:App, decorationsLeft:Float, decorationsWidth:Float, lineTop:Float, lineHeight:Float, fontSize:Float, collapsed:Bool, color:Hsla):Void {
        final size = fontSize * 1.4;
        final left = decorationsLeft + 2 + (decorationsWidth - size) / 2;
        final baseline = lineTop + (lineHeight - size) / 2 + size * ASCENT;
        paintFoldingIcon(window, cx, left, baseline, size, collapsed, color);
    }

}
