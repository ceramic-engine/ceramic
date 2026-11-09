// Ported from vscode src/vs/editor/test/common/model/textModelWithTokens.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.Cityscape;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.languages.NullTokenize;
import haxe.io.UInt32Array;
import testing.TestCase;
import tests.TestTextModel;
import testing.TestTokenizationSupport;

/**
 * Suite 'TextModelWithTokens regression tests', the tokenization tests
 * (each test has its own `Cityscape` context: Monaco registers the
 * tokenizers in the global registry).
 *
 * The bracket tests of this file are in `TextModelWithTokensBracketsTest`.
 * The suite 'TextModel.getLineIndentGuide' belongs to the guides part of
 * the model (`GuidesTextModelPart`, ported with TextModel).
 */
class TextModelWithTokensTest extends TestCase {

    function viewLineTokens(model:TestTextModel, lineNumber:Int, forceTokenization:Bool):Array<{endIndex:Int, foreground:Int}> {
        if (forceTokenization) {
            model.tokenization.forceTokenization(lineNumber);
        }
        final actual = model.tokenization.getLineTokens(lineNumber).inflate();
        return [for (i in 0...actual.getCount()) {endIndex: actual.getEndOffset(i), foreground: (actual.getForeground(i) : Int)}];
    }

    function testMonacoEditor122UnhandledExceptionTypeErrorUnableToGetPropertyReplaceOfUndefinedOrNullReference() {
        var _tokenId = 10;
        final LANG_ID1 = 'indicisiveMode1';
        final LANG_ID2 = 'indicisiveMode2';

        final tokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                final myId = ++_tokenId;
                final tokens = new UInt32Array(2);
                tokens[0] = 0;
                tokens[1] = (myId << MetadataConsts.FOREGROUND_OFFSET);
                return new EncodedTokenizationResult(tokens, state);
            }
        );

        final context = new Cityscape();
        final registration1 = context.tokenizationRegistry.register(LANG_ID1, tokenizationSupport);
        final registration2 = context.tokenizationRegistry.register(LANG_ID2, tokenizationSupport);

        final model = TestTextModel.instantiateTextModel(context, 'A model with\ntwo lines', null);

        assertDeepEquals([{endIndex: 12, foreground: 1}], viewLineTokens(model, 1, true));
        assertDeepEquals([{endIndex: 9, foreground: 1}], viewLineTokens(model, 2, true));

        model.setLanguage(LANG_ID1);

        assertDeepEquals([{endIndex: 12, foreground: 11}], viewLineTokens(model, 1, true));
        assertDeepEquals([{endIndex: 9, foreground: 12}], viewLineTokens(model, 2, true));

        model.setLanguage(LANG_ID2);

        assertDeepEquals([{endIndex: 12, foreground: 1}], viewLineTokens(model, 1, false));
        assertDeepEquals([{endIndex: 9, foreground: 1}], viewLineTokens(model, 2, false));

        model.dispose();
        registration1.dispose();
        registration2.dispose();
    }

    function testIssue63822WrongEmbeddedLanguageDetectedForEmptyLines() {
        final context = new Cityscape();
        final languageService = context.languageService;

        final outerMode = 'outerMode';
        final innerMode = 'innerMode';

        final r1 = languageService.registerLanguage({id: outerMode});
        final r2 = languageService.registerLanguage({id: innerMode});

        final languageIdCodec = languageService.languageIdCodec;
        final encodedInnerMode:Int = languageIdCodec.encodeLanguageId(innerMode);

        final tokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                final tokens = new UInt32Array(2);
                tokens[0] = 0;
                tokens[1] = (encodedInnerMode << MetadataConsts.LANGUAGEID_OFFSET);
                return new EncodedTokenizationResult(tokens, state);
            }
        );

        final r3 = context.tokenizationRegistry.register(outerMode, tokenizationSupport);

        final model = TestTextModel.instantiateTextModel(context, 'A model with one line', outerMode);

        model.tokenization.forceTokenization(1);
        assertEquals(innerMode, model.getLanguageIdAtPosition(1, 1));

        model.dispose();
        r3.dispose();
        r2.dispose();
        r1.dispose();
    }

}
