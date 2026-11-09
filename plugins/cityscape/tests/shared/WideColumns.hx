// New code for Cityscape (not a port): the Monaco truth of the column
// positions of wide text, shared by the unit test and the visual check.
package;

import cityscape.common.config.EditorOptions.IEditorOptions;

/**
 * The recorded truth `tests/unit/data/monaco/wide-columns.json`: a copy of
 * glaze-golden `test/cityscape/recorder/truths/d-wide-columns.json`, recorded
 * by the Monaco recorder (scenario `scenarios/d-wide-columns.json`) from the
 * real loreline-monaco (Monaco 0.52.2) in the Electron 33 / Chromium 130 of
 * the Ceramic runner on macOS, device pixel ratio 2. Never edited by hand.
 *
 * Lines mixing ASCII, CJK, kana, Hangul, emoji sequences and full width
 * punctuation, in JetBrains Mono (the font bundled with Glaze, loaded from its
 * TTF) at 14 px: the characters the font lacks come from Chromium's fallback
 * fonts (Apple Color Emoji, Hiragino, Apple SD Gothic Neo), each with its own
 * advance, off the character grid. For every column the truth has Monaco's
 * `editor.getOffsetForColumn` (`x`, rounded to whole pixels by Monaco's
 * `HorizontalRange`) and the same DOM reading without the rounding (`xFloat`),
 * which is what the comparison uses.
 */
class WideColumns {

    /**
     * Largest difference allowed between a Cityscape column x and Monaco's
     * unrounded DOM x, in CSS pixels. Chromium positions glyphs on a grid of
     * 1/64 px with advances rounded on it (JetBrains Mono's 8.4 px is
     * 8.3984375 there), while Glaze keeps 32 bit float advances: the
     * difference grows by about 0.0016 px per character, under 0.1 px on these
     * lines. A wrong advance for one glyph is at least 0.5 px off.
     */
    public static inline final TOLERANCE:Float = 0.25;

    public final text:String;

    public final lines:Array<WideColumnsLine>;

    public final fontFamily:String;

    public final fontSize:Float;

    public final lineHeight:Int;

    function new(text:String, lines:Array<WideColumnsLine>, fontFamily:String, fontSize:Float, lineHeight:Int) {
        this.text = text;
        this.lines = lines;
        this.fontFamily = fontFamily;
        this.fontSize = fontSize;
        this.lineHeight = lineHeight;
    }

    public static function parse(json:String):WideColumns {
        final data:Dynamic = haxe.Json.parse(json);
        final states:Array<Dynamic> = data.states;
        final state:Dynamic = states[states.length - 1].state;
        final columns:Array<Dynamic> = state.columns;
        final lines:Array<WideColumnsLine> = [];
        for (c in columns) {
            final xs:Array<Float> = [];
            final raw:Array<Dynamic> = c.xFloat;
            for (x in raw) {
                xs.push(x == null ? Math.NaN : (x : Float));
            }
            lines.push(new WideColumnsLine(c.line, c.content, xs));
        }
        final font:Dynamic = data.environment.layout.font;
        return new WideColumns(state.text, lines, font.fontFamily, font.fontSize, data.environment.layout.lineHeight);
    }

    /**
     * The editor options of the recording.
     */
    public function editorOptions():IEditorOptions {
        return {
            fontFamily: fontFamily,
            fontSize: fontSize,
            lineHeight: lineHeight,
            fontLigatures: false,
            wordWrap: 'off',
            renderWhitespace: 'none',
            lineNumbers: 'on',
            cursorBlinking: 'solid'
        };
    }

    /**
     * Texts whose advances are known to differ from Monaco's on a target
     * (`os`: the Ceramic backend's operating system, `web`: in a browser
     * with Glaze's Canvas fallback). Open differences, not deliberate ones:
     *
     * - macOS, native: Glaze falls back on the faces already loaded before
     *   the system fonts, in load order (cosmic-text's database order), where
     *   Chromium asks CoreText for each character. Hangul syllables take
     *   Arial Unicode MS (14 px, loaded earlier for another character)
     *   instead of Apple SD Gothic Neo (12.11 px); `❤` (U+2764, text
     *   presentation) takes Inter (14.31 px) instead of the system text font
     *   (8.43 px).
     * - Both: `☺️`, `❤️`, `✌️` (emoji presentation selector after a text
     *   default symbol) take the emoji font (14 px), as Unicode asks, where
     *   Chromium keeps the text font of the same symbol earlier in the line
     *   (8.43 px); on the web `©️` and `↔️` too.
     * - Web: half width katakana and full width Latin letters and digits are
     *   not eligible for the Canvas fallback of gpui-pre-web (its CJK ranges)
     *   and show the primary font's notdef (8.4 px) instead of 7 px and 14 px.
     */
    public static function knownDifferences(os:String, web:Bool):Array<String> {
        final known = ['☺\u{FE0F}', '❤\u{FE0F}', '✌\u{FE0F}'];
        if (web) {
            for (t in ['©\u{FE0F}', '↔\u{FE0F}', '❤', 'ｶ', 'ﾀ', 'ﾅ', 'Ａ', 'Ｂ', 'Ｃ', '１', '２', '３']) {
                known.push(t);
            }
        } else if (os == 'mac') {
            for (t in ['한', '국', '어', '❤']) {
                known.push(t);
            }
        }
        return known;
    }

    /**
     * Largest difference allowed between the advance of a grapheme in
     * Cityscape and in Monaco (the x of a column minus the x of the column
     * before), in CSS pixels: the 1/64 px grid of Chromium's positions.
     */
    public static inline final ADVANCE_TOLERANCE:Float = 0.05;

    /**
     * Compares `xOf(line, column)` with the truth for every column of every
     * line: the advance of each column (from the column before), and the x
     * itself until the first known difference of the line.
     *
     * `knownDifferences`: texts whose advances are known to differ on the
     * target (open differences, listed by the caller with their reason): the
     * columns inside and right after each occurrence are not checked.
     * `asciiOnly`: only the columns after an ASCII character are checked
     * (targets without fallback fonts).
     */
    public function compare(xOf:(line:Int, column:Int) -> Float, knownDifferences:Array<String>, asciiOnly:Bool):WideColumnsReport {
        final report = new WideColumnsReport();
        for (l in lines) {
            final text = l.content;
            // Columns whose advance is not checked: after a character of a known difference
            final skipped:Array<Bool> = [for (_ in 0...text.length + 2) false];
            for (known in knownDifferences) {
                var at = text.indexOf(known);
                while (at != -1) {
                    for (o in at...at + known.length) {
                        skipped[o + 2] = true;
                    }
                    at = text.indexOf(known, at + known.length);
                }
            }
            if (asciiOnly) {
                for (o in 0...text.length) {
                    if (StringTools.fastCodeAt(text, o) > 0x7F) {
                        skipped[o + 2] = true;
                    }
                }
            }
            final actual:Array<Float> = [];
            var absolute = true;
            for (i in 0...l.x.length) {
                final column = i + 1;
                final x = xOf(l.line, column);
                actual.push(x);
                final expected = l.x[i];
                if (skipped[column]) {
                    absolute = false;
                    report.skipped++;
                    continue;
                }
                report.count++;
                if (column > 1) {
                    final advance = x - actual[i - 1];
                    final expectedAdvance = expected - l.x[i - 1];
                    final d = Math.abs(advance - expectedAdvance);
                    if (d > report.maxAdvanceDiff) {
                        report.maxAdvanceDiff = d;
                    }
                    if (d > ADVANCE_TOLERANCE) {
                        report.failures.push({line: l.line, column: column, kind: 'advance', expected: expectedAdvance, actual: advance});
                    }
                }
                if (absolute) {
                    final d = Math.abs(x - expected);
                    if (d > report.maxDiff) {
                        report.maxDiff = d;
                    }
                    if (d > TOLERANCE) {
                        report.failures.push({line: l.line, column: column, kind: 'x', expected: expected, actual: x});
                    }
                }
            }
            report.lines.push({line: l.line, content: l.content, x: actual});
        }
        return report;
    }

}

class WideColumnsLine {

    public final line:Int;

    public final content:String;

    /** Monaco's unrounded x of columns 1 to the max column (NaN when not measured). */
    public final x:Array<Float>;

    public function new(line:Int, content:String, x:Array<Float>) {
        this.line = line;
        this.content = content;
        this.x = x;
    }

}

class WideColumnsReport {

    /** Columns checked */
    public var count:Int = 0;

    /** Columns not checked (known differences) */
    public var skipped:Int = 0;

    /** Largest difference of x (columns before the first known difference of their line) */
    public var maxDiff:Float = 0;

    /** Largest difference of advance */
    public var maxAdvanceDiff:Float = 0;

    public final failures:Array<{line:Int, column:Int, kind:String, expected:Float, actual:Float}> = [];

    public final lines:Array<{line:Int, content:String, x:Array<Float>}> = [];

    public function new() {}

    public function summary():String {
        return '$count columns checked, $skipped skipped (known differences), ${failures.length} failures, max x difference $maxDiff px (tolerance ${WideColumns.TOLERANCE}), max advance difference $maxAdvanceDiff px (tolerance ${WideColumns.ADVANCE_TOLERANCE})';
    }

    public function toJson():String {
        return haxe.Json.stringify({
            count: count,
            skipped: skipped,
            maxDiff: maxDiff,
            maxAdvanceDiff: maxAdvanceDiff,
            tolerance: WideColumns.TOLERANCE,
            advanceTolerance: WideColumns.ADVANCE_TOLERANCE,
            failures: failures,
            columns: lines
        }, null, ' ') + '\n';
    }

}
