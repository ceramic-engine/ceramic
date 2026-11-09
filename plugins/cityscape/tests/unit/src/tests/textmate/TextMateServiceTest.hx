package tests.textmate;

import cityscape.Cityscape;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.TokenizationTextModelPart.BackgroundTokenizationState;
import testing.TestCase;
import tests.TestTextModel;

// New code for Cityscape (not a port): the TextMate service of a context.

/**
 * Embedded languages, token types, several contexts side by side, and the
 * tokenizer life cycle of `TextMateService`. Expected values follow from the
 * grammars written here and vscode-textmate's documented behaviour
 * (embedded language ids and token types in the metadata).
 */
class TextMateServiceTest extends TestCase {

    // A grammar with an embedded block (`<<` ... `>>` is `source.inner`)
    static final OUTER_GRAMMAR = '{
        "scopeName": "source.outer",
        "patterns": [
            {"begin": "<<", "end": ">>", "name": "meta.embedded.block.inner", "contentName": "source.inner", "patterns": [{"include": "source.inner"}]},
            {"match": "\\\\bkw\\\\b", "name": "keyword.control"},
            {"match": "\\"[^\\"]*\\"", "name": "string.quoted.double"},
            {"match": "#.*$", "name": "comment.line"}
        ]
    }';

    static final INNER_GRAMMAR = '{
        "scopeName": "source.inner",
        "patterns": [
            {"match": "\\\\d+", "name": "constant.numeric"}
        ]
    }';

    function createContext():Cityscape {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'outer', extensions: ['.outer']});
        context.languageService.registerLanguage({id: 'inner'});
        context.textMate.registerGrammar({
            languageId: 'outer',
            grammar: OUTER_GRAMMAR,
            path: 'outer.tmLanguage.json',
            embeddedLanguages: ['source.inner' => 'inner'],
            tokenTypes: ['comment' => StandardTokenType.Comment, 'string' => StandardTokenType.String]
        });
        context.textMate.registerGrammar({languageId: 'inner', grammar: INNER_GRAMMAR, path: 'inner.tmLanguage.json'});
        context.textMate.setTheme({settings: ([
            {settings: {foreground: '#000000', background: '#ffffff'}},
            {scope: 'keyword', settings: {foreground: '#0000ff'}},
            {scope: 'constant.numeric', settings: {foreground: '#00ff00'}}
        ] : Array<Dynamic>)});
        return context;
    }

    function testEmbeddedLanguages() {
        final context = createContext();
        final model = TestTextModel.instantiateTextModel(context, 'kw << 12 >> "s" # c', 'outer');
        model.tokenization.forceTokenization(1);
        // The embedded block is in the inner language
        assertEquals('outer', model.getLanguageIdAtPosition(1, 1));
        assertEquals('inner', model.getLanguageIdAtPosition(1, 7));
        assertEquals('inner', model.getLanguageIdAtPosition(1, 8));
        assertEquals('outer', model.getLanguageIdAtPosition(1, 14));
        // Token types from `tokenTypes`
        final tokens = model.tokenization.getLineTokens(1);
        assertEquals(StandardTokenType.String, tokens.getStandardTokenType(tokens.findTokenIndexAtOffset(13)));
        assertEquals(StandardTokenType.Comment, tokens.getStandardTokenType(tokens.findTokenIndexAtOffset(18)));
        assertEquals(StandardTokenType.Other, tokens.getStandardTokenType(tokens.findTokenIndexAtOffset(0)));
        // Colors
        final colorMap = context.textMate.getColorMap();
        assertEquals('#0000FF', colorMap[tokens.getForeground(tokens.findTokenIndexAtOffset(0))].toUpperCase());
        assertEquals('#00FF00', colorMap[tokens.getForeground(tokens.findTokenIndexAtOffset(6))].toUpperCase());
        model.dispose();
    }

    function testEncounteredEmbeddedLanguageIsReported() {
        final context = createContext();
        final support = context.textMate.createTokenizationSupport('outer');
        final seen:Array<Int> = [];
        support.onDidEncounterLanguage(id -> seen.push(id));
        final r = support.tokenizeEncoded('<< 1 >>', true, support.getInitialState());
        support.tokenizeEncoded('<< 2 >>', true, r.endState);
        final outerId:Int = context.languageService.languageIdCodec.encodeLanguageId('outer');
        final innerId:Int = context.languageService.languageIdCodec.encodeLanguageId('inner');
        // Each language once, in the order met
        assertDeepEquals([outerId, innerId], seen);
    }

    function testEndStateIsReusedWhenEqual() {
        final context = createContext();
        final support = context.textMate.createTokenizationSupport('outer');
        final initial = support.getInitialState();
        // The first line turns the initial (null) stack into the root state
        final r1 = support.tokenizeEncoded('kw', true, initial);
        assertFalse(r1.endState.equals(initial));
        // Same state: the object given is returned (VS Code's TextMateTokenizationSupport)
        final r2 = support.tokenizeEncoded('kw', true, r1.endState);
        assertTrue(r2.endState == r1.endState);
        final r3 = support.tokenizeEncoded('<< 1', true, r1.endState);
        assertFalse(r3.endState == r1.endState);
        assertFalse(r3.endState.equals(r1.endState));
        assertTrue(r3.endState.equals(support.tokenizeEncoded('<< 1', true, r1.endState).endState));
    }

    function testMaxTokenizationLineLength() {
        final context = createContext();
        context.textMate.maxTokenizationLineLength = 10;
        final model = TestTextModel.instantiateTextModel(context, 'kw\nkw kw kw kw kw', 'outer');
        model.tokenization.forceTokenization(2);
        final colorMap = context.textMate.getColorMap();
        final line1 = model.tokenization.getLineTokens(1);
        final line2 = model.tokenization.getLineTokens(2);
        assertEquals('#0000FF', colorMap[line1.getForeground(0)].toUpperCase());
        // The long line is not tokenized: one token with the default colors
        assertEquals(1, line2.getCount());
        assertEquals(ColorId.DefaultForeground, line2.getForeground(0));
        model.dispose();
    }

    function testContextsAreIndependent() {
        final a = createContext();
        final b = createContext();
        b.textMate.setTheme({settings: ([
            {settings: {foreground: '#111111', background: '#222222'}},
            {scope: 'keyword', settings: {foreground: '#ff0000'}}
        ] : Array<Dynamic>)});
        final modelA = TestTextModel.instantiateTextModel(a, 'kw', 'outer');
        final modelB = TestTextModel.instantiateTextModel(b, 'kw', 'outer');
        modelA.tokenization.forceTokenization(1);
        modelB.tokenization.forceTokenization(1);
        final colorA = a.textMate.getColorMap()[modelA.tokenization.getLineTokens(1).getForeground(0)];
        final colorB = b.textMate.getColorMap()[modelB.tokenization.getLineTokens(1).getForeground(0)];
        assertEquals('#0000FF', colorA.toUpperCase());
        assertEquals('#FF0000', colorB.toUpperCase());
        // A language registered in one context only
        assertTrue(a.languageService.isRegisteredLanguageId('outer'));
        assertFalse(new Cityscape().languageService.isRegisteredLanguageId('outer'));
        modelA.dispose();
        modelB.dispose();
    }

    function testGrammarRegisteredAfterTheModel() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'outer'});
        final model = TestTextModel.instantiateTextModel(context, 'kw', 'outer');
        model.tokenization.forceTokenization(1);
        assertEquals(ColorId.DefaultForeground, model.tokenization.getLineTokens(1).getForeground(0));
        var events = 0;
        model.onDidChangeTokens(e -> events++);
        // The model is tokenized again with the grammar (Monaco: TokenizationRegistry.onDidChange)
        final registration = context.textMate.registerGrammar({languageId: 'outer', grammar: OUTER_GRAMMAR, path: 'outer.tmLanguage.json'});
        context.textMate.setTheme({settings: ([
            {settings: {foreground: '#000000', background: '#ffffff'}},
            {scope: 'keyword', settings: {foreground: '#0000ff'}}
        ] : Array<Dynamic>)});
        assertTrue(events > 0);
        model.tokenization.forceTokenization(1);
        assertEquals('#0000FF', context.textMate.getColorMap()[model.tokenization.getLineTokens(1).getForeground(0)].toUpperCase());
        // Unregistered: no tokenizer anymore
        registration.dispose();
        model.tokenization.forceTokenization(1);
        assertEquals(ColorId.DefaultForeground, model.tokenization.getLineTokens(1).getForeground(0));
        model.dispose();
    }

    function testDetachedModelStopsBackgroundWork() {
        final context = createContext();
        final lines = [for (i in 0...2000) 'kw << $i >> "s"'];
        final model = TestTextModel.instantiateTextModel(context, lines.join('\n'), 'outer');
        final view = model.onBeforeAttached();
        view.setVisibleLines([{startLineNumber: 1, endLineNumber: 10}], true);
        assertFalse(context.backgroundScheduler.isIdle());
        context.backgroundScheduler.runFor(1);
        model.onBeforeDetached(view);
        // Detached: the task ends on its next turn, the rest is tokenized on demand
        context.backgroundScheduler.runUntilIdle();
        assertTrue(context.backgroundScheduler.isIdle());
        assertEquals(BackgroundTokenizationState.InProgress, model.tokenization.backgroundTokenizationState);
        model.tokenization.forceTokenization(2000);
        assertTrue(model.tokenization.hasAccurateTokensForLine(2000));
        model.dispose();
    }

}
