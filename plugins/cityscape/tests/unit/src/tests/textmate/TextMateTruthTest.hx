package tests.textmate;

import cityscape.Cityscape;
import cityscape.base.common.Color;
import cityscape.common.TokenizationTextModelPart.BackgroundTokenizationState;
import cityscape.common.tokens.LineTokens;
import cityscape.standalone.common.VSCodeTheme;
import testing.MonacoTruth;
import testing.TestCase;
import tests.TestTextModel;

// New code for Cityscape (not a port): the TextMate bridge against the real Monaco and vscode-textmate.

/**
 * Tokenizes Glaze's highlighter samples with the TextMate grammars bundled
 * with Glaze and VS Code's Dark+ and Light+ themes, and compares the final
 * colors and font styles of every line, as runs of equal look, and the token
 * color map, with `data/monaco/textmate-tokens.json`. That file is written by
 * glaze-golden's `reference/cityscape/textmate-tokens-truth.mjs`: the real
 * vscode-textmate and vscode-oniguruma, with Monaco 0.52.2's color map and
 * token store, the pipeline of loreline-monaco's `src/provider.js`.
 */
class TextMateTruthTest extends TestCase {

    static final FONT_STYLE_NAMES = ['italic', 'bold', 'underline', 'strikethrough'];

    static var truth:Null<Dynamic> = null;

    public static function data():Dynamic {
        if (truth == null) {
            truth = haxe.Json.parse(MonacoTruth.load('textmate-tokens.json'));
        }
        return truth;
    }

    /**
     * The text of a grammar of the truth (the files of Glaze, embedded at compile time).
     */
    public static function grammarText(file:String):String {
        return switch file {
            case 'javascript.json': MonacoTruth.loadGlazeGrammar('javascript.json');
            case 'json.json': MonacoTruth.loadGlazeGrammar('json.json');
            case 'css.json': MonacoTruth.loadGlazeGrammar('css.json');
            case 'html.json': MonacoTruth.loadGlazeGrammar('html.json');
            case 'markdown.json': MonacoTruth.loadGlazeGrammar('markdown.json');
            case 'haxe.json': MonacoTruth.loadGlazeGrammar('haxe.json');
            case 'shellscript.json': MonacoTruth.loadGlazeGrammar('shellscript.json');
            case _: throw 'Grammar not embedded: ' + file;
        }
    }

    public static function theme(id:String):Dynamic {
        for (theme in (data().themes : Array<Dynamic>)) {
            if (theme.id == id) {
                return theme;
            }
        }
        throw 'No theme ' + id;
    }

    public static function sample(file:String):Dynamic {
        for (sample in (data().samples : Array<Dynamic>)) {
            if (sample.file == file) {
                return sample;
            }
        }
        throw 'No sample ' + file;
    }

    /**
     * A context with the languages and grammars of the truth, and a theme of
     * it set through `TextMateService.setTheme` (what loreline-monaco's
     * provider gives to vscode-textmate's registry).
     */
    public static function createContext(themeId:String):Cityscape {
        final context = new Cityscape();
        for (grammar in (data().grammars : Array<Dynamic>)) {
            final languageId:String = grammar.languageId;
            final file:String = grammar.file;
            context.languageService.registerLanguage({id: languageId});
            context.textMate.registerGrammar({languageId: languageId, grammar: grammarText(file), path: file});
        }
        if (themeId != null) {
            context.textMate.setTheme(theme(themeId).theme);
        }
        return context;
    }

    static function fontStyleOf(metadata:Int):String {
        final bits = (metadata & 0x00007800) >>> 11;
        final names = [];
        for (i in 0...FONT_STYLE_NAMES.length) {
            if (bits & (1 << i) != 0) {
                names.push(FONT_STYLE_NAMES[i]);
            }
        }
        return names.join(' ');
    }

    /**
     * The runs of the truth: [startColumn, endColumn (exclusive), color, fontStyle].
     */
    public static function runsOf(tokens:LineTokens, colorMap:Array<String>):Array<Array<Any>> {
        final runs:Array<Array<Any>> = [];
        var start = 0;
        for (i in 0...tokens.getCount()) {
            final end = tokens.getEndOffset(i);
            if (end <= start) {
                continue;
            }
            final foreground:Int = tokens.getForeground(i);
            final color:Null<String> = foreground < colorMap.length ? colorMap[foreground] : null;
            final style = fontStyleOf(tokens.getMetadata(i));
            final last = runs.length > 0 ? runs[runs.length - 1] : null;
            if (last != null && last[2] == color && last[3] == style) {
                last[1] = end + 1;
            }
            else {
                runs.push([start + 1, end + 1, color, style]);
            }
            start = end;
        }
        return runs;
    }

    /**
     * The final token colors of a context, as CSS (`Color.Format.CSS.format`, the `.mtkN` rules).
     */
    public static function cssColorMap(context:Cityscape):Array<String> {
        return [for (c in context.tokenizationRegistry.getColorMap()) c != null ? ColorFormatCSS.format(c) : null];
    }

    function assertColorMap(expected:Array<Null<String>>, actual:Array<String>, message:String) {
        assertEquals(expected.length, actual.length, message + ' color map length');
        for (i in 1...expected.length) {
            assertEquals(expected[i], actual[i], message + ' color ' + i);
        }
    }

    function testGrammarsAreTheOnesOfTheTruth() {
        // The truth was written from these exact files (SHA-256 of their
        // UTF-8 bytes; Sha256.encode would hash only the first length * 8
        // bits of a non-ASCII string)
        final grammars:Array<Dynamic> = data().grammars;
        assertEquals(7, grammars.length);
        for (grammar in grammars) {
            assertEquals(grammar.sha256, haxe.crypto.Sha256.make(haxe.io.Bytes.ofString(grammarText(grammar.file))).toHex(), grammar.file + ' changed: run reference/cityscape/textmate-tokens-truth.mjs again');
        }
    }

    function testTokensAndColorsOfEveryLine() {
        final themes:Array<Dynamic> = data().themes;
        final samples:Array<Dynamic> = data().samples;
        assertEquals(2, themes.length);
        var comparedLines = 0;
        var expectedLines = 0;
        for (theme in themes) {
            final themeId:String = theme.id;
            final context = createContext(themeId);
            final colorMap = cssColorMap(context);
            assertColorMap(theme.colorMap, colorMap, themeId);
            for (sample in samples) {
                final text:String = sample.text;
                final model = TestTextModel.instantiateTextModel(context, text, sample.languageId);
                final lines:Array<Array<Array<Any>>> = Reflect.field(sample.tokens, themeId);
                assertEquals(lines.length, model.getLineCount(), sample.file);
                expectedLines += lines.length;
                model.tokenization.forceTokenization(model.getLineCount());
                for (i in 0...lines.length) {
                    final actual = runsOf(model.tokenization.getLineTokens(i + 1), colorMap);
                    assertDeepEquals(lines[i], actual, themeId + ' / ' + sample.file + ' / line ' + (i + 1));
                    comparedLines++;
                }
                model.dispose();
            }
            context.textMate.dispose();
        }
        // 486 lines in 6 samples, with 2 themes
        assertEquals(972, expectedLines);
        assertEquals(expectedLines, comparedLines);
    }

    /**
     * The same colors through Monaco's API: the theme defined with the theme
     * service (`defineTheme`, `setTheme`) from the tmTheme object.
     */
    function testTokensThroughTheThemeService() {
        final dark:Dynamic = theme('dark-plus');
        final html:Dynamic = sample('embedded.html');
        final context = createContext(null);
        context.themeService.defineTheme('custom-theme', VSCodeTheme.toStandaloneThemeData(dark.theme));
        context.themeService.setTheme('custom-theme');

        final colorMap = cssColorMap(context);
        assertColorMap(dark.colorMap, colorMap, 'dark-plus');
        final model = TestTextModel.instantiateTextModel(context, html.text, 'html');
        final lines:Array<Array<Array<Any>>> = Reflect.field(html.tokens, 'dark-plus');
        model.tokenization.forceTokenization(model.getLineCount());
        for (i in 0...lines.length) {
            assertDeepEquals(lines[i], runsOf(model.tokenization.getLineTokens(i + 1), colorMap), 'line ' + (i + 1));
        }
        // The first scope-less entry of the theme gives the editor colors (#1E1E1E in dark_vs.json)
        assertEquals('#1e1e1e', ColorFormatCSS.formatHex(context.themeService.getColorTheme().getColor('editor.background')));
        model.dispose();

        // Switching to a built-in theme changes the token colors live (Monaco rules as TextMate rules)
        final js:Dynamic = sample('demo.js');
        final jsModel = TestTextModel.instantiateTextModel(context, js.text, 'javascript');
        final view = jsModel.onBeforeAttached();
        view.setVisibleLines([{startLineNumber: 1, endLineNumber: 10}], true);
        context.themeService.setTheme('vs');
        final vsColorMap = cssColorMap(context);
        assertEquals('#000000', vsColorMap[1]);
        // Line 1 is a comment: '008000' in the 'comment' rule of Monaco's 'vs' theme (themes.ts)
        assertEquals('#008000', runsOf(jsModel.tokenization.getLineTokens(1), vsColorMap)[0][2]);
        jsModel.onBeforeDetached(view);
        jsModel.dispose();
    }

    function testLiveThemeChange() {
        final js:Dynamic = sample('demo.js');
        final context = createContext('dark-plus');
        final model = TestTextModel.instantiateTextModel(context, js.text, 'javascript');
        final view = model.onBeforeAttached();
        final lineCount = model.getLineCount();
        view.setVisibleLines([{startLineNumber: 1, endLineNumber: lineCount}], true);
        // Visible lines are tokenized at once
        final dark:Array<Array<Array<Any>>> = Reflect.field(js.tokens, 'dark-plus');
        final darkColors = cssColorMap(context);
        for (i in 0...lineCount) {
            assertDeepEquals(dark[i], runsOf(model.tokenization.getLineTokens(i + 1), darkColors), 'dark line ' + (i + 1));
        }

        var tokenEvents = 0;
        model.onDidChangeTokens(e -> tokenEvents++);
        context.textMate.setTheme(theme('light-plus').theme);
        assertTrue(tokenEvents > 0);
        final lightColors = cssColorMap(context);
        assertColorMap(theme('light-plus').colorMap, lightColors, 'light-plus');
        // The visible lines have the new colors without being asked
        final light:Array<Array<Array<Any>>> = Reflect.field(js.tokens, 'light-plus');
        for (i in 0...lineCount) {
            assertDeepEquals(light[i], runsOf(model.tokenization.getLineTokens(i + 1), lightColors), 'light line ' + (i + 1));
        }
        model.onBeforeDetached(view);
        model.dispose();
    }

    function testBackgroundSchedulerTokenizesAttachedModels() {
        final rule:Dynamic = sample('Rule.hx');
        final text:String = rule.text;
        final context = createContext('dark-plus');
        final a = TestTextModel.instantiateTextModel(context, text, 'haxe');
        final b = TestTextModel.instantiateTextModel(context, text, 'haxe');
        final c = TestTextModel.instantiateTextModel(context, text, 'haxe');
        final lineCount = a.getLineCount();
        assertEquals(301, lineCount);
        final viewA = a.onBeforeAttached();
        final viewB = b.onBeforeAttached();
        viewA.setVisibleLines([{startLineNumber: 100, endLineNumber: 120}], true);
        viewB.setVisibleLines([{startLineNumber: 1, endLineNumber: 20}], true);
        // Viewport first: the visible lines have tokens (heuristic start state for A)
        assertTrue(b.tokenization.hasAccurateTokensForLine(20));
        assertFalse(a.tokenization.hasAccurateTokensForLine(120));
        assertEquals(BackgroundTokenizationState.InProgress, a.tokenization.backgroundTokenizationState);
        // The background work of both attached models shares the scheduler
        assertFalse(context.backgroundScheduler.isIdle());
        context.backgroundScheduler.runUntilIdle();
        assertTrue(a.tokenization.hasAccurateTokensForLine(lineCount));
        assertTrue(b.tokenization.hasAccurateTokensForLine(lineCount));
        assertEquals(BackgroundTokenizationState.Completed, a.tokenization.backgroundTokenizationState);
        assertEquals(BackgroundTokenizationState.Completed, b.tokenization.backgroundTokenizationState);
        // The tokens made in the background are the truth's
        final colorMap = cssColorMap(context);
        final lines:Array<Array<Array<Any>>> = Reflect.field(rule.tokens, 'dark-plus');
        for (i in 0...lineCount) {
            assertDeepEquals(lines[i], runsOf(a.tokenization.getLineTokens(i + 1), colorMap), 'line ' + (i + 1));
        }
        // A model that is not attached to an editor is not tokenized in the background
        assertFalse(c.tokenization.hasAccurateTokensForLine(2));
        a.onBeforeDetached(viewA);
        b.onBeforeDetached(viewB);
        a.dispose();
        b.dispose();
        c.dispose();
    }

    function asyncTestBackgroundTokenizationRunsInFrames(done:() -> Void) {
        final context = createContext('dark-plus');
        context.backgroundScheduler.budgetMs = 2;
        final text:String = sample('Rule.hx').text;
        final model = TestTextModel.instantiateTextModel(context, text, 'haxe');
        final view = model.onBeforeAttached();
        view.setVisibleLines([{startLineNumber: 1, endLineNumber: 30}], true);
        var frames = 0;
        function check(delta:Float) {
            frames++;
            if (model.tokenization.backgroundTokenizationState == BackgroundTokenizationState.Completed) {
                ceramic.App.app.offUpdate(check);
                assertTrue(model.tokenization.hasAccurateTokensForLine(model.getLineCount()));
                assertTrue(frames >= 1);
                assertTrue(context.backgroundScheduler.isIdle());
                model.onBeforeDetached(view);
                model.dispose();
                done();
            }
        }
        ceramic.App.app.onUpdate(null, check);
    }

}
