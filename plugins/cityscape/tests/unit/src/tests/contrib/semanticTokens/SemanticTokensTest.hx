// New code for Cityscape (not a port): semantic tokens of a provider over
// the TextMate tokens of a model, styled by VS Code and Monaco themes.
package tests.contrib.semanticTokens;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Color;
import cityscape.base.common.Event;
import cityscape.common.EncodedTokenAttributes.FontStyle;
import cityscape.common.EncodedTokenAttributes.TokenMetadata;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.contrib.semanticTokens.view.ViewportSemanticTokens;
import cityscape.platform.theme.common.TokenClassificationRegistry;
import cityscape.standalone.common.VSCodeTheme;
import cityscape.workbench.services.themes.common.ColorThemeData;
import haxe.extern.EitherType;
import haxe.io.UInt32Array;
import testing.TestCase;
import testing.TestCodeEditor;

private class DataProvider implements DocumentSemanticTokensProvider {
    public var onDidChange(default, null):Null<VoidEvent> = null;
    public var data:Array<Int>;
    public var calls = 0;
    final legend:SemanticTokensLegend;

    public function new(legend:SemanticTokensLegend, data:Array<Int>) {
        this.legend = legend;
        this.data = data;
    }

    public function getLegend():SemanticTokensLegend {
        return legend;
    }

    public function provideDocumentSemanticTokens(model:ITextModel, lastResultId:Null<String>, token:CancellationToken, resolve:(result:Null<EitherType<SemanticTokens, SemanticTokensEdits>>) -> Void):Void {
        calls++;
        final tokens:SemanticTokens = {data: UInt32Array.fromArray(data)};
        resolve(tokens);
    }

    public function releaseDocumentSemanticTokens(resultId:Null<String>):Void {}
}

private class RangeProvider implements DocumentRangeSemanticTokensProvider {
    public var ranges:Array<Range> = [];
    final legend:SemanticTokensLegend;
    final data:Array<Int>;

    public function new(legend:SemanticTokensLegend, data:Array<Int>) {
        this.legend = legend;
        this.data = data;
    }

    public function getLegend():SemanticTokensLegend {
        return legend;
    }

    public function provideDocumentRangeSemanticTokens(model:ITextModel, range:Range, token:CancellationToken, resolve:(result:Null<SemanticTokens>) -> Void):Void {
        ranges.push(range);
        resolve({data: UInt32Array.fromArray(data)});
    }
}

/**
 * A grammar (`kw` keywords, capitalized names as types, other words as
 * variables) and a VS Code theme coloring their scopes; semantic tokens of
 * a provider then color the words by their semantic class like VS Code:
 * with the theme's `semanticTokenColors`, else with the TextMate rules of
 * the scopes vscode's token classification registry probes (`type`:
 * `entity.name.type`, `variable.readonly`: `variable.other.constant`).
 */
class SemanticTokensTest extends TestCase {

    static final GRAMMAR = '{
        "scopeName": "source.sem",
        "patterns": [
            {"match": "\\\\bkw\\\\b", "name": "keyword.control"},
            {"match": "\\\\b[A-Z][a-z]*\\\\b", "name": "entity.name.type"},
            {"match": "\\\\b[a-z]+\\\\b", "name": "variable.other.readwrite"}
        ]
    }';

    static function vsCodeTheme(?semanticTokenColors:Dynamic, semanticHighlighting:Bool = true):Dynamic {
        final theme:Dynamic = {
            type: 'dark',
            colors: {'editor.foreground': '#d4d4d4', 'editor.background': '#1e1e1e'},
            tokenColors: ([
                {scope: 'keyword.control', settings: {foreground: '#c586c0'}},
                {scope: 'entity.name.type', settings: {foreground: '#4ec9b0'}},
                {scope: 'variable', settings: {foreground: '#9cdcfe'}},
                {scope: 'variable.other.constant', settings: {foreground: '#4fc1ff'}}
            ] : Array<Dynamic>),
            semanticHighlighting: semanticHighlighting
        };
        if (semanticTokenColors != null) {
            theme.semanticTokenColors = semanticTokenColors;
        }
        return theme;
    }

    static final LEGEND:SemanticTokensLegend = {tokenTypes: ['type', 'variable', 'function'], tokenModifiers: ['readonly']};

    // `foo` (line 1, character 3, 3 long) as a `type`, `Bar` (character 7)
    // as a `variable.readonly`
    static final DATA = [0, 3, 3, 0, 0, 0, 4, 3, 1, 1];

    var context:Cityscape;
    final disposables:Array<{function dispose():Void;}> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'sem'});
        context.textMate.registerGrammar({languageId: 'sem', grammar: GRAMMAR, path: 'sem.tmLanguage.json'});
        context.themeService.defineTheme('sem-dark', VSCodeTheme.toStandaloneThemeData(vsCodeTheme()));
        context.themeService.setTheme('sem-dark');
    }

    override public function teardown():Void {
        for (d in disposables) {
            d.dispose();
        }
        disposables.resize(0);
    }

    function createModel(text:String):TextModel {
        final model = context.modelService.createModel(text, 'sem');
        disposables.push(model);
        // the model shows in an editor: its semantic tokens are asked
        model.onBeforeAttached();
        return model;
    }

    function colorAt(model:TextModel, lineNumber:Int, offset:Int):String {
        model.tokenization.forceTokenization(lineNumber);
        final tokens = model.tokenization.getLineTokens(lineNumber);
        final color = context.tokenizationRegistry.getColorMap()[tokens.getForeground(tokens.findTokenIndexAtOffset(offset))];
        return ColorFormatCSS.formatHexA(color, true).toUpperCase();
    }

    function fontStyleAt(model:TextModel, lineNumber:Int, offset:Int):Int {
        final tokens = model.tokenization.getLineTokens(lineNumber);
        return TokenMetadata.getFontStyle(tokens.getMetadata(tokens.findTokenIndexAtOffset(offset)));
    }

    function registerProvider(?data:Array<Int>):DataProvider {
        final provider = new DataProvider(LEGEND, data != null ? data : DATA);
        disposables.push(context.registerDocumentSemanticTokensProvider('sem', provider));
        return provider;
    }

    function testTheTextMateColorsWithoutProvider() {
        final model = createModel('kw foo Bar');
        assertEquals('#C586C0', colorAt(model, 1, 0));
        assertEquals('#9CDCFE', colorAt(model, 1, 3));
        assertEquals('#4EC9B0', colorAt(model, 1, 7));
    }

    function testSemanticTokensColoredByTheProbedTextMateScopes() {
        final provider = registerProvider();
        final model = createModel('kw foo Bar');
        context.documentSemanticTokensFeature._flush();
        assertEquals(1, provider.calls);
        assertTrue(model.tokenization.hasCompleteSemanticTokens());
        // `kw` keeps its TextMate color
        assertEquals('#C586C0', colorAt(model, 1, 0));
        // `type` probes `entity.name.type`
        assertEquals('#4EC9B0', colorAt(model, 1, 3));
        // `variable.readonly` probes `variable.other.constant`
        assertEquals('#4FC1FF', colorAt(model, 1, 7));
    }

    function testSemanticTokenColorsOfTheThemeWin() {
        context.themeService.defineTheme('sem-rules', VSCodeTheme.toStandaloneThemeData(vsCodeTheme({
            'type': '#ff0000',
            '*.readonly': {foreground: '#00ff00', fontStyle: 'bold'}
        })));
        context.themeService.setTheme('sem-rules');
        registerProvider();
        final model = createModel('kw foo Bar');
        context.documentSemanticTokensFeature._flush();
        assertEquals('#FF0000', colorAt(model, 1, 3));
        assertEquals('#00FF00', colorAt(model, 1, 7));
        assertEquals(FontStyle.Bold, fontStyleAt(model, 1, 7));
        assertEquals(FontStyle.None, fontStyleAt(model, 1, 3));
    }

    function testThemeChangeRestylesTheTokens() {
        registerProvider();
        final model = createModel('kw foo Bar');
        context.documentSemanticTokensFeature._flush();
        assertEquals('#4EC9B0', colorAt(model, 1, 3));
        context.themeService.defineTheme('sem-rules', VSCodeTheme.toStandaloneThemeData(vsCodeTheme({'type': '#ff0000'})));
        context.themeService.setTheme('sem-rules');
        // the tokens are cleared, then asked again
        context.documentSemanticTokensFeature._flush();
        assertEquals('#FF0000', colorAt(model, 1, 3));
        context.themeService.setTheme('sem-dark');
        context.documentSemanticTokensFeature._flush();
        assertEquals('#4EC9B0', colorAt(model, 1, 3));
    }

    function testSemanticHighlightingSetting() {
        context.themeService.defineTheme('sem-off', VSCodeTheme.toStandaloneThemeData(vsCodeTheme(null, false)));
        context.themeService.setTheme('sem-off');
        final provider = registerProvider();
        final model = createModel('kw foo Bar');
        final feature = context.documentSemanticTokensFeature;
        feature._flush();
        // 'configuredByTheme' (the default) and a theme without semantic highlighting
        assertEquals(0, provider.calls);
        assertEquals('#9CDCFE', colorAt(model, 1, 3));

        // `editor.semanticHighlighting.enabled: true`
        context.configurationService.updateValues([{key: 'editor.semanticHighlighting.enabled', value: true}]);
        feature._flush();
        assertEquals(1, provider.calls);
        assertEquals('#4EC9B0', colorAt(model, 1, 3));

        // `false`: the tokens go away
        context.configurationService.updateValues([{key: 'editor.semanticHighlighting.enabled', value: false}]);
        feature._flush();
        assertFalse(model.tokenization.hasSomeSemanticTokens());
        assertEquals('#9CDCFE', colorAt(model, 1, 3));

        // 'configuredByTheme' with a theme enabling it
        context.configurationService.updateValues([{key: 'editor.semanticHighlighting.enabled', value: 'configuredByTheme'}]);
        context.themeService.setTheme('sem-dark');
        feature._flush();
        assertEquals('#4EC9B0', colorAt(model, 1, 3));
    }

    function testEditsMoveTheTokensThenAskAgain() {
        final provider = registerProvider();
        final model = createModel('kw foo Bar');
        final feature = context.documentSemanticTokensFeature;
        feature._flush();
        assertEquals(1, provider.calls);
        model.applyEdits([{range: new Range(1, 1, 1, 1), text: 'x '}]);
        // the tokens moved with the text before the new request
        assertEquals('#4EC9B0', colorAt(model, 1, 5));
        assertEquals('#4FC1FF', colorAt(model, 1, 9));
        assertTrue(feature.getModelSemanticColoring(model)._isScheduled());
        // the new tokens of the provider
        provider.data = [0, 0, 1, 2, 0];
        feature._flush();
        assertEquals(2, provider.calls);
        // `x` is a function: no rule for `function` probes a scope the theme has
        assertEquals('#9CDCFE', colorAt(model, 1, 0));
        assertEquals('#9CDCFE', colorAt(model, 1, 5));
    }

    function testMonacoThemeRules() {
        // A Monaco theme (token rules, no TextMate rules): the semantic
        // token class is matched as a token (`type.readonly`)
        final monaco = new Cityscape();
        monaco.languageService.registerLanguage({id: 'plain'});
        monaco.themeService.defineTheme('rules', {
            base: 'vs',
            inherit: false,
            rules: [{token: '', foreground: '000000'}, {token: 'type', foreground: 'ff0000'}, {token: 'variable.readonly', foreground: '00aa00', fontStyle: 'italic'}],
            colors: {},
            semanticHighlighting: true
        });
        monaco.themeService.setTheme('rules');
        final provider = new DataProvider(LEGEND, [0, 0, 3, 0, 1, 0, 4, 3, 1, 1]);
        final registration = monaco.registerDocumentSemanticTokensProvider('plain', provider);
        final model = monaco.modelService.createModel('foo Bar', 'plain');
        model.onBeforeAttached();
        monaco.documentSemanticTokensFeature._flush();
        final tokens = model.tokenization.getLineTokens(1);
        final colorMap = monaco.tokenizationRegistry.getColorMap();
        final foo = tokens.findTokenIndexAtOffset(0);
        final bar = tokens.findTokenIndexAtOffset(4);
        assertEquals('#FF0000', ColorFormatCSS.formatHex(colorMap[tokens.getForeground(foo)]).toUpperCase());
        assertEquals('#00AA00', ColorFormatCSS.formatHex(colorMap[tokens.getForeground(bar)]).toUpperCase());
        assertEquals(FontStyle.Italic, TokenMetadata.getFontStyle(tokens.getMetadata(bar)));
        registration.dispose();
        model.dispose();
    }

    function testViewportRangeProvider() {
        final provider = new RangeProvider(LEGEND, [0, 3, 3, 0, 0]);
        disposables.push(context.registerDocumentRangeSemanticTokensProvider('sem', provider));
        final model = context.modelService.createModel('kw foo Bar', 'sem');
        disposables.push(model);
        final editor = new TestCodeEditor(context, model, {}, context.editorExtensions.getSomeEditorContributions([ViewportSemanticTokensContribution.ID]));
        disposables.push(editor);
        final contribution = ViewportSemanticTokensContribution.get(editor);
        assertTrue(contribution._isScheduled());
        contribution._flush();
        assertTrue(provider.ranges.length > 0);
        assertEquals(1, provider.ranges[0].startLineNumber);
        assertTrue(model.tokenization.hasSomeSemanticTokens());
        assertFalse(model.tokenization.hasCompleteSemanticTokens());
        assertEquals('#4EC9B0', colorAt(model, 1, 3));
        // an edit asks again
        model.applyEdits([{range: new Range(1, 1, 1, 1), text: 'x'}]);
        assertTrue(contribution._isScheduled());
    }

    function testTokenClassificationSelectors() {
        final registry = TokenClassificationRegistry.getTokenClassificationRegistry();
        // vscode's scores: language 10, type 100 - level, modifiers 100 each
        assertEquals(100, registry.parseTokenSelector('variable').match('variable', [], 'x'));
        assertEquals(200, registry.parseTokenSelector('variable.readonly').match('variable', ['readonly'], 'x'));
        assertEquals(-1, registry.parseTokenSelector('variable.readonly').match('variable', [], 'x'));
        assertEquals(100, registry.parseTokenSelector('*.readonly').match('property', ['readonly'], 'x'));
        assertEquals(110, registry.parseTokenSelector('variable:x').match('variable', [], 'x'));
        assertEquals(-1, registry.parseTokenSelector('variable:y').match('variable', [], 'x'));
        // `member` is a `method`
        assertEquals(99, registry.parseTokenSelector('method').match('member', [], 'x'));
        assertEquals('variable.a.b:x', registry.parseTokenSelector('variable.b.a:x').id);
        final parsed = TokenClassificationRegistry.parseClassifierString('type.static.readonly:haxe', null);
        assertEquals('type', parsed.type);
        assertDeepEquals(['readonly', 'static'], parsed.modifiers);
        assertEquals('haxe', parsed.language);
    }

    function testColorNormalization() {
        assertEquals('#AABBCC', TokenColorIndex.normalizeColor('#abc'));
        assertEquals('#AABBCC', TokenColorIndex.normalizeColor('#aabbccff'));
        assertEquals('#AABBCC80', TokenColorIndex.normalizeColor('#aabbcc80'));
        assertEquals(null, TokenColorIndex.normalizeColor('red'));
        final index = new TokenColorIndex();
        assertEquals(1, index.addHex('#ff0000'));
        assertEquals(1, index.addHex('#F00'));
        assertEquals(2, index.addHex('#00ff00'));
        assertEquals(0, index.get(null));
    }

}
