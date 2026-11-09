// Ported from vscode src/vs/editor/contrib/semanticTokens/test/browser/getSemanticTokens.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.semanticTokens;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event.VoidEvent;
import cityscape.base.common.Promise.CancellationError;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.contrib.semanticTokens.common.GetSemanticTokens;
import haxe.extern.EitherType;
import testing.TestCase;

private class ThrowingProvider implements DocumentSemanticTokensProvider {
    public var onDidChange(default, null):Null<VoidEvent> = null;

    public function new() {}

    public function getLegend():SemanticTokensLegend {
        return {tokenTypes: ['test'], tokenModifiers: []};
    }

    public function provideDocumentSemanticTokens(model:ITextModel, lastResultId:Null<String>, token:CancellationToken, resolve:(result:Null<EitherType<SemanticTokens, SemanticTokensEdits>>) -> Void):Void {
        throw new CancellationError();
    }

    public function releaseDocumentSemanticTokens(resultId:Null<String>):Void {}
}

/**
 * vscode's suite `getSemanticTokens`.
 */
class GetSemanticTokensTest extends TestCase {

    function testIssue136540SemanticHighlightingFlickers() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'testLang'});
        final registry = new LanguageFeatureRegistry<DocumentSemanticTokensProvider>();
        final registration = registry.register('testLang', new ThrowingProvider());

        final textModel = tests.TestTextModel.instantiateTextModel(context, 'example', 'testLang');

        var failed = false;
        var error:Any = null;
        GetSemanticTokens.getDocumentSemanticTokens(registry, textModel, null, null, CancellationTokens.None).done((res) -> {
            failed = true;
        }, (err) -> {
            error = err;
        });
        assertFalse(failed);
        assertTrue(error != null);

        registration.dispose();
        textModel.dispose();
    }

}
