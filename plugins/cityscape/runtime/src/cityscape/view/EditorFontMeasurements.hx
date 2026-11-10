// New code for Cityscape (not a port): the font measurements of Monaco's
// browser/config/fontMeasurements.ts, done by Glaze's text system instead of
// the DOM (AUDIT A.3.2 recipe).
package cityscape.view;

import cityscape.common.config.FontInfo;
import cityscape.view.MeasuredLineBreaksComputer.ILineMeasurer;
import glaze.App;
import glaze.Font;
import glaze.FontFallbacks;
import glaze.FontFeatures;
import glaze.FontId;
import glaze.FontStyle;
import glaze.FontWeight;
import glaze.TextSystem;

/**
 * Glaze fonts and Monaco `FontInfo` metrics for the editor fonts.
 *
 * - The font family is the first family of Monaco's CSS font list that is
 *   added or installed (`TextSystem.isFamilyAvailable`: Glaze loads the
 *   families of the system by name on macOS), else the first one the text
 *   system resolves (`Menlo`, `SF Mono`, `monospace`... map to the bundled
 *   JetBrains Mono where they are not installed, on the web for instance).
 * - Italic runs synthesize an oblique when the family has no italic face
 *   (`Font.synthesizeStyle`), like the browser Monaco runs in.
 * - `fontLigatures` (`font-feature-settings` syntax) gives `FontFeatures`
 *   passed explicitly: an empty feature list means ligatures on in Glaze,
 *   so Monaco's `'"liga" off, "calt" off'` default must be given (AUDIT A.2.3).
 * - The metrics are Monaco's (`typicalHalfwidthCharacterWidth` from `n`,
 *   `typicalFullwidthCharacterWidth` from U+FF4D, space, middot, U+2E31,
 *   max digit), measured with `LineWrapper.widthForChar` (fallback fonts
 *   included). Every glyph keeps its own advance when painted (CJK about 1em,
 *   AUDIT A.3.3): caret and hit tests use the shaped x.
 */
class EditorFontMeasurements implements ILineMeasurer {

    final textSystem:TextSystem;

    final _fontCache:Map<String, Font> = new Map();

    public function new(textSystem:TextSystem) {
        this.textSystem = textSystem;
    }

    public static function forApp(cx:App):EditorFontMeasurements {
        return new EditorFontMeasurements(cx.textSystem());
    }

    /**
     * The families of a CSS font list, unquoted.
     */
    public static function parseFontFamilies(fontFamily:String):Array<String> {
        final result:Array<String> = [];
        for (part in fontFamily.split(',')) {
            var name = StringTools.trim(part);
            if (name.length >= 2 && ((StringTools.startsWith(name, "'") && StringTools.endsWith(name, "'")) || (StringTools.startsWith(name, '"') && StringTools.endsWith(name, '"')))) {
                name = name.substr(1, name.length - 2);
            }
            if (name.length > 0) {
                result.push(name);
            }
        }
        return result;
    }

    static function isGenericFamily(family:String):Bool {
        return switch family {
            case 'monospace' | 'sans-serif' | 'serif' | 'system-ui' | 'ui-monospace': true;
            case _: false;
        }
    }

    /**
     * CSS `font-feature-settings` (`'"liga" off, "calt" on'`, `'"ss01"'`,
     * `'normal'`) as Glaze features. Unknown or invalid tags are skipped.
     */
    public static function parseFontFeatureSettings(settings:String):FontFeatures {
        final tags:Array<String> = [];
        final values:Array<Int> = [];
        if (settings == null) {
            return new FontFeatures();
        }
        final trimmed = StringTools.trim(settings);
        if (trimmed == '' || trimmed == 'normal') {
            return new FontFeatures();
        }
        for (part in trimmed.split(',')) {
            final p = StringTools.trim(part);
            if (p.length < 6) {
                continue;
            }
            final quote = p.charAt(0);
            if (quote != '"' && quote != "'") {
                continue;
            }
            final end = p.indexOf(quote, 1);
            if (end != 5) {
                continue;
            }
            final tag = p.substring(1, 5);
            final rest = StringTools.trim(p.substr(6));
            var value = 1;
            if (rest == 'off') {
                value = 0;
            } else if (rest == 'on' || rest == '') {
                value = 1;
            } else {
                final n = Std.parseInt(rest);
                value = (n == null ? 1 : n);
            }
            if (!FontFeatures.isValidFeatureTag(tag)) {
                continue;
            }
            tags.push(tag);
            values.push(value);
        }
        return FontFeatures.fromList(tags, values);
    }

    public static function parseFontWeight(fontWeight:String):FontWeight {
        if (fontWeight == null || fontWeight == 'normal') {
            return FontWeight.NORMAL;
        }
        if (fontWeight == 'bold') {
            return FontWeight.BOLD;
        }
        final n = Std.parseFloat(fontWeight);
        return Math.isNaN(n) ? FontWeight.NORMAL : n;
    }

    /**
     * The Glaze font of the editor (the first resolvable family), with the
     * given weight, style and features, shaped like a browser
     * (`Font.wholeRunShaping`). The families after it in the CSS list are
     * its fallbacks (those available, and the generic families), tried in
     * order for the characters it lacks before the fonts of the system,
     * like a browser resolves a `font-family` list: `'Maple Mono',
     * monospace` draws `☕` with Menlo's glyph (the generic `monospace`) on
     * macOS, not with the emoji font.
     */
    public function resolveEditorFont(fontFamily:String, weight:FontWeight, italic:Bool, features:FontFeatures, preferColorEmoji:Bool = true):Font {
        final key = fontFamily + '|' + weight + '|' + italic + '|' + features.key() + '|' + textSystem.fontGeneration + (preferColorEmoji ? '|e' : '');
        final cached = _fontCache.get(key);
        if (cached != null) {
            return cached;
        }
        var result:Null<Font> = null;
        final candidates = parseFontFamilies(fontFamily);
        candidates.push('JetBrains Mono');
        // like a CSS font family list: the first family that is added or
        // installed on the system
        for (family in candidates) {
            if (textSystem.isFamilyAvailable(family)) {
                final font = new Font(family, features, null, weight, italic ? FontStyle.Italic : FontStyle.Normal);
                font.synthesizeStyle = true;
                try {
                    textSystem.resolveFont(font);
                    result = font;
                    break;
                } catch (e:Dynamic) {}
            }
        }
        // else the first one the text system resolves (Glaze substitutes its
        // bundled fonts for well known names: `SF Mono` is JetBrains Mono)
        if (result == null) for (family in candidates) {
            final font = new Font(family, features, null, weight, italic ? FontStyle.Italic : FontStyle.Normal);
            // like the browser: an italic run of a family without an italic
            // face is drawn slanted (synthetic oblique)
            font.synthesizeStyle = true;
            try {
                textSystem.resolveFont(font);
                result = font;
                break;
            } catch (e:Dynamic) {
                // not loaded: next family
            }
        }
        if (result == null) {
            result = new Font('JetBrains Mono', features, null, weight, italic ? FontStyle.Italic : FontStyle.Normal);
            result.synthesizeStyle = true;
        }
        final fallbacks:Array<String> = [];
        final primaryIndex = candidates.indexOf(result.family);
        if (primaryIndex != -1) {
            // the CSS list after the primary family, without the JetBrains Mono added above
            for (i in primaryIndex + 1...candidates.length - 1) {
                final family = candidates[i];
                if (family != result.family && fallbacks.indexOf(family) == -1 && (isGenericFamily(family) || textSystem.isFamilyAvailable(family))) {
                    fallbacks.push(family);
                }
            }
        }
        if (fallbacks.length > 0) {
            result.fallbacks = FontFallbacks.fromFonts(fallbacks);
        }
        result.wholeRunShaping = true;
        // Cityscape's `preferColorEmoji` option (owner decision 2026-11-11)
        result.preferColorEmoji = preferColorEmoji;
        _fontCache.set(key, result);
        return result;
    }

    /**
     * Monaco's `FontMeasurements.readFontInfo`: the metrics of `bareFontInfo`.
     */
    public function readFontInfo(bareFontInfo:BareFontInfo):FontInfo {
        final font = resolveEditorFont(bareFontInfo.fontFamily, parseFontWeight(bareFontInfo.fontWeight), false, parseFontFeatureSettings(bareFontInfo.fontFeatureSettings));
        final wrapper = textSystem.lineWrapper(font, bareFontInfo.fontSize);
        inline function w(c:Int):Float {
            return wrapper.widthForChar(c);
        }
        final typicalHalfwidthCharacterWidth = w('n'.code);
        final typicalFullwidthCharacterWidth = w(0xFF4D);
        final spaceWidth = w(' '.code);
        final middotWidth = w(0xB7);
        final wsmiddotWidth = w(0x2E31);
        var maxDigitWidth:Float = 0;
        for (c in '0'.code...'9'.code + 1) {
            final d = w(c);
            if (d > maxDigitWidth) {
                maxDigitWidth = d;
            }
        }
        // Monaco: monospace when the sampled characters have the same width
        var isMonospace = true;
        for (c in ['i'.code, 'l'.code, 'm'.code, 'W'.code, '|'.code, '@'.code, '_'.code, '.'.code]) {
            if (Math.abs(w(c) - typicalHalfwidthCharacterWidth) > 0.001) {
                isMonospace = false;
                break;
            }
        }
        final canUseHalfwidthRightwardsArrow = (Math.abs(w(0xFFEB) - typicalHalfwidthCharacterWidth) < 0.001);

        return new FontInfo({
            pixelRatio: bareFontInfo.pixelRatio,
            fontFamily: bareFontInfo.fontFamily,
            fontWeight: bareFontInfo.fontWeight,
            fontSize: bareFontInfo.fontSize,
            fontFeatureSettings: bareFontInfo.fontFeatureSettings,
            fontVariationSettings: bareFontInfo.fontVariationSettings,
            lineHeight: bareFontInfo.lineHeight,
            letterSpacing: bareFontInfo.letterSpacing,
            isMonospace: isMonospace,
            typicalHalfwidthCharacterWidth: typicalHalfwidthCharacterWidth,
            typicalFullwidthCharacterWidth: typicalFullwidthCharacterWidth,
            canUseHalfwidthRightwardsArrow: canUseHalfwidthRightwardsArrow,
            spaceWidth: spaceWidth,
            middotWidth: middotWidth,
            wsmiddotWidth: wsmiddotWidth,
            maxDigitWidth: maxDigitWidth
        }, true);
    }

    /**
     * `ILineMeasurer`: the x of every UTF-16 offset of `text`, shaped with the
     * editor font (for the `advanced` wrapping strategy).
     */
    public function measure(text:String, fontInfo:FontInfo):Array<Float> {
        return measureWith(text, fontInfo, true);
    }

    /**
     * `measure` with the `preferColorEmoji` option of an editor.
     */
    public function measureWith(text:String, fontInfo:FontInfo, preferColorEmoji:Bool):Array<Float> {
        final font = resolveEditorFont(fontInfo.fontFamily, parseFontWeight(fontInfo.fontWeight), false, parseFontFeatureSettings(fontInfo.fontFeatureSettings), preferColorEmoji);
        final layout = textSystem.platformTextSystem.layoutLine(text, fontInfo.fontSize, [new glaze.FontRun(glaze.util.Utf8.byteLength(text), textSystem.resolveFont(font))]);
        final map = new LineOffsetMap();
        map.reset(text);
        final result:Array<Float> = [];
        for (i in 0...text.length + 1) {
            result.push(layout.xForIndex(map.utf16ToByte(i)));
        }
        return result;
    }

}
