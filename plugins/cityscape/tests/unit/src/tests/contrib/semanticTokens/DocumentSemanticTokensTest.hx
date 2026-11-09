// Ported from vscode src/vs/editor/contrib/semanticTokens/test/browser/documentSemanticTokens.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.semanticTokens;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.contrib.semanticTokens.common.GetSemanticTokens;
import cityscape.contrib.semanticTokens.view.DocumentSemanticTokens;
import haxe.extern.EitherType;
import haxe.io.UInt32Array;
import testing.TestCase;

typedef SemanticTokensResolve = (result:Null<EitherType<SemanticTokens, SemanticTokensEdits>>) -> Void;

/**
 * A document semantic tokens provider made of functions.
 */
private class FnProvider implements DocumentSemanticTokensProvider {
    public var onDidChange(default, null):Null<VoidEvent>;
    final legend:SemanticTokensLegend;
    final provide:(model:ITextModel, lastResultId:Null<String>, resolve:SemanticTokensResolve) -> Void;

    public function new(legend:SemanticTokensLegend, provide:(model:ITextModel, lastResultId:Null<String>, resolve:SemanticTokensResolve) -> Void, ?onDidChange:VoidEvent) {
        this.legend = legend;
        this.provide = provide;
        this.onDidChange = onDidChange;
    }

    public function getLegend():SemanticTokensLegend {
        return legend;
    }

    public function provideDocumentSemanticTokens(model:ITextModel, lastResultId:Null<String>, token:CancellationToken, resolve:SemanticTokensResolve):Void {
        provide(model, lastResultId, resolve);
    }

    public function releaseDocumentSemanticTokens(resultId:Null<String>):Void {}
}

/**
 * vscode's suite `ModelSemanticColoring`. Monaco's tests run with faked
 * timers and barriers; here the providers keep their `resolve` callback to
 * answer later, and the tests run the scheduled requests with
 * `DocumentSemanticTokensFeature._flush` instead of waiting.
 */
class DocumentSemanticTokensTest extends TestCase {

    var context:Cityscape;
    var feature:DocumentSemanticTokensFeature;
    final disposables:Array<{function dispose():Void;}> = [];

    override public function setup():Void {
        context = new Cityscape();
        // `new TestConfigurationService({ editor: { semanticHighlighting: true } })`:
        // `editor.semanticHighlighting.enabled` stays unset, the theme decides
        context.configurationService.updateValues([{key: 'editor.semanticHighlighting', value: true}]);
        // `new TestColorTheme({}, ColorScheme.DARK, true)`
        context.themeService.defineTheme('test-theme', {base: 'vs-dark', inherit: true, rules: [], colors: {}, semanticHighlighting: true});
        context.themeService.setTheme('test-theme');
        feature = new DocumentSemanticTokensFeature(context.semanticTokensStylingService, context.modelService, DocumentSemanticTokensFeature.themeSourceOf(context.themeService), context.configurationService, context.languageFeaturesService);
    }

    override public function teardown():Void {
        for (d in disposables) {
            d.dispose();
        }
        disposables.resize(0);
        feature.dispose();
    }

    function createModel(text:String, languageId:String):TextModel {
        final model = context.modelService.createModel(text, languageId);
        disposables.push(model);
        return model;
    }

    function testDocumentSemanticTokensShouldBeFetchedWhenTheResultIsEmptyIfThereArePendingChanges() {
        context.languageService.registerLanguage({id: 'testMode'});

        var callCount = 0;
        var firstResolve:Null<SemanticTokensResolve> = null;
        var secondResultProvided = false;

        disposables.push(context.languageFeaturesService.documentSemanticTokensProvider.register('testMode', new FnProvider({tokenTypes: ['class'], tokenModifiers: []}, (model, lastResultId, resolve) -> {
            callCount++;
            if (callCount == 1) {
                // in the first call: answer later
                firstResolve = resolve;
                return;
            }
            if (callCount == 2) {
                secondResultProvided = true;
                resolve(null);
                return;
            }
            fail('Unexpected call');
        })));

        final textModel = createModel('Hello world', 'testMode');
        // pretend the text model is attached to an editor (so that semantic tokens are computed)
        textModel.onBeforeAttached();

        // wait for the provider to be called
        feature._flush();
        assertTrue(firstResolve != null);

        // the provider is now in the provide call
        // change the text buffer while the provider is running
        textModel.applyEdits([{range: new Range(1, 1, 1, 1), text: 'x'}]);

        // the scheduler fires while the request runs (it lets it finish)
        feature._flush();
        assertEquals(1, callCount);

        // let the provider finish its first result
        firstResolve(null);

        // we need to check that the provider is called again, even if it returns null
        feature._flush();
        assertTrue(secondResultProvided);

        // assert that it got called twice
        assertEquals(2, callCount);
    }

    function testIssue149412VSCodeHangsWhenBadSemanticTokenDataIsReceived() {
        context.languageService.registerLanguage({id: 'testMode'});

        var lastResult:Null<EitherType<SemanticTokens, SemanticTokensEdits>> = null;
        var lastResultId:Null<String> = null;

        disposables.push(context.languageFeaturesService.documentSemanticTokensProvider.register('testMode', new FnProvider({tokenTypes: ['class'], tokenModifiers: []}, (model, previousResultId, resolve) -> {
            if (previousResultId == null) {
                // this is the first call
                final tokens:SemanticTokens = {
                    resultId: '1',
                    // 4294967293 is -3 as a 32 bit integer
                    data: UInt32Array.fromArray([-3, 0, 7, 16, 0, 1, 4, 3, 11, 1])
                };
                lastResult = tokens;
                lastResultId = '1';
            }
            else {
                // this is the second call
                final edits:SemanticTokensEdits = {
                    resultId: '2',
                    edits: [{
                        // 4294967276 is -20 as a 32 bit integer
                        start: -20,
                        deleteCount: 0,
                        data: UInt32Array.fromArray([2, 0, 3, 11, 0])
                    }]
                };
                lastResult = edits;
                lastResultId = '2';
            }
            resolve(lastResult);
        })));

        final textModel = createModel('', 'testMode');
        // pretend the text model is attached to an editor (so that semantic tokens are computed)
        textModel.onBeforeAttached();

        // wait for the semantic tokens to be fetched
        var tokensChanged = 0;
        disposables.push(textModel.onDidChangeTokens(_ -> tokensChanged++));
        feature._flush();
        assertTrue(tokensChanged > 0);
        assertEquals('1', lastResultId);

        // edit the text
        textModel.applyEdits([{range: new Range(1, 1, 1, 1), text: 'foo'}]);

        // wait for the semantic tokens to be fetched again
        tokensChanged = 0;
        feature._flush();
        assertTrue(tokensChanged > 0);
        assertEquals('2', lastResultId);
    }

    function testIssue161573OnDidChangeSemanticTokensDoesntConsistentlyTriggerProvideDocumentSemanticTokens() {
        context.languageService.registerLanguage({id: 'testMode'});

        final emitter = new VoidEmitter();
        var requestCount = 0;
        var pending:Null<SemanticTokensResolve> = null;
        disposables.push(context.languageFeaturesService.documentSemanticTokensProvider.register('testMode', new FnProvider({tokenTypes: ['class'], tokenModifiers: []}, (model, lastResultId, resolve) -> {
            requestCount++;
            if (requestCount == 1) {
                pending = resolve;
                return;
            }
            resolve(null);
        }, emitter.event)));

        final textModel = createModel('', 'testMode');
        // pretend the text model is attached to an editor (so that semantic tokens are computed)
        textModel.onBeforeAttached();

        feature._flush();
        // send a change event while the first request runs
        emitter.fire();
        pending(null);

        feature._flush();
        assertEquals(2, requestCount);
    }

    function testDocumentSemanticTokensShouldBePickTheTokenProviderWithActualItems() {
        var callCount = 0;
        context.languageService.registerLanguage({id: 'testMode2'});
        disposables.push(context.languageFeaturesService.documentSemanticTokensProvider.register('testMode2', new FnProvider({tokenTypes: ['class1'], tokenModifiers: []}, (model, lastResultId, resolve) -> {
            callCount++;
            // For a secondary request return a different value
            if (lastResultId != null) {
                final tokens:SemanticTokens = {data: UInt32Array.fromArray([2, 1, 1, 1, 1, 0, 2, 1, 1, 1])};
                resolve(tokens);
                return;
            }
            final tokens:SemanticTokens = {resultId: '1', data: UInt32Array.fromArray([0, 1, 1, 1, 1, 0, 2, 1, 1, 1])};
            resolve(tokens);
        })));
        disposables.push(context.languageFeaturesService.documentSemanticTokensProvider.register('testMode2', new FnProvider({tokenTypes: ['class2'], tokenModifiers: []}, (model, lastResultId, resolve) -> {
            callCount++;
            resolve(null);
        })));

        function toArr(arr:UInt32Array):Array<Int> {
            return [for (i in 0...arr.length) (arr[i] : Int)];
        }

        final textModel = createModel('Hello world 2', 'testMode2');
        var result:Null<DocumentSemanticTokensResult> = null;
        GetSemanticTokens.getDocumentSemanticTokens(context.languageFeaturesService.documentSemanticTokensProvider, textModel, null, null, CancellationTokens.None).done(r -> result = r);
        assertTrue(result != null, 'We should have tokens (1)');
        assertTrue(result.tokens != null, 'Tokens are found from multiple providers (1)');
        assertTrue(GetSemanticTokens.isSemanticTokens(result.tokens), 'Tokens are full (1)');
        var tokens:SemanticTokens = result.tokens;
        assertTrue(tokens.resultId != null, 'Token result id found from multiple providers (1)');
        assertDeepEquals([0, 1, 1, 1, 1, 0, 2, 1, 1, 1], toArr(tokens.data), 'Token data returned for multiple providers (1)');
        assertEquals(2, callCount, 'Called both token providers (1)');
        assertDeepEquals({tokenTypes: ['class1'], tokenModifiers: []}, result.provider.getLegend(), 'Legend matches the tokens (1)');

        // Make a second request. Make sure we get the secondary value
        final first = result;
        result = null;
        GetSemanticTokens.getDocumentSemanticTokens(context.languageFeaturesService.documentSemanticTokensProvider, textModel, first.provider, tokens.resultId, CancellationTokens.None).done(r -> result = r);
        assertTrue(result != null, 'We should have tokens (2)');
        assertTrue(result.tokens != null, 'Tokens are found from multiple providers (2)');
        assertTrue(GetSemanticTokens.isSemanticTokens(result.tokens), 'Tokens are full (2)');
        tokens = result.tokens;
        assertTrue(tokens.resultId == null, 'Token result id found from multiple providers (2)');
        assertDeepEquals([2, 1, 1, 1, 1, 0, 2, 1, 1, 1], toArr(tokens.data), 'Token data returned for multiple providers (2)');
        assertEquals(4, callCount, 'Called both token providers (2)');
        assertDeepEquals({tokenTypes: ['class1'], tokenModifiers: []}, result.provider.getLegend(), 'Legend matches the tokens (2)');
    }

}
