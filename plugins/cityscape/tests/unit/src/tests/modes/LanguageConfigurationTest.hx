// Ported from vscode src/vs/editor/test/common/modes/languageConfiguration.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes;

import cityscape.Cityscape;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.languages.LanguageConfiguration;
import testing.TestCase;
import testing.TestLanguageConfigurationService;

/**
 * suite('StandardAutoClosingPairConditional')
 *
 * `testLanguageConfigurationsPrioritiesOnContext` is new: the same test, with
 * the same expected value, on the service of a `Cityscape` context.
 */
class LanguageConfigurationTest extends TestCase {

    function testMissingNotIn() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}'});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), true);
        assertEquals(v.isOK(StandardTokenType.String), true);
        assertEquals(v.isOK(StandardTokenType.RegEx), true);
    }

    function testEmptyNotIn() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: []});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), true);
        assertEquals(v.isOK(StandardTokenType.String), true);
        assertEquals(v.isOK(StandardTokenType.RegEx), true);
    }

    function testInvalidNotIn() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['bla']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), true);
        assertEquals(v.isOK(StandardTokenType.String), true);
        assertEquals(v.isOK(StandardTokenType.RegEx), true);
    }

    function testNotInInStrings() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['string']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), true);
        assertEquals(v.isOK(StandardTokenType.String), false);
        assertEquals(v.isOK(StandardTokenType.RegEx), true);
    }

    function testNotInInComments() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['comment']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), false);
        assertEquals(v.isOK(StandardTokenType.String), true);
        assertEquals(v.isOK(StandardTokenType.RegEx), true);
    }

    function testNotInInRegex() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['regex']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), true);
        assertEquals(v.isOK(StandardTokenType.String), true);
        assertEquals(v.isOK(StandardTokenType.RegEx), false);
    }

    function testNotInInStringsNorComments() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['string', 'comment']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), false);
        assertEquals(v.isOK(StandardTokenType.String), false);
        assertEquals(v.isOK(StandardTokenType.RegEx), true);
    }

    function testNotInInStringsNorRegex() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['string', 'regex']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), true);
        assertEquals(v.isOK(StandardTokenType.String), false);
        assertEquals(v.isOK(StandardTokenType.RegEx), false);
    }

    function testNotInInCommentsNorRegex() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['comment', 'regex']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), false);
        assertEquals(v.isOK(StandardTokenType.String), true);
        assertEquals(v.isOK(StandardTokenType.RegEx), false);
    }

    function testNotInInStringsCommentsNorRegex() {
        final v = new StandardAutoClosingPairConditional({open: '{', close: '}', notIn: ['string', 'comment', 'regex']});
        assertEquals(v.isOK(StandardTokenType.Other), true);
        assertEquals(v.isOK(StandardTokenType.Comment), false);
        assertEquals(v.isOK(StandardTokenType.String), false);
        assertEquals(v.isOK(StandardTokenType.RegEx), false);
    }

    function testLanguageConfigurationsPriorities() {
        final languageConfigurationService = new TestLanguageConfigurationService();
        final id = 'testLang1';
        final d1 = languageConfigurationService.register(id, {comments: {lineComment: '1'}}, 100);
        final d2 = languageConfigurationService.register(id, {comments: {lineComment: '2'}}, 10);
        assertEquals(languageConfigurationService.getLanguageConfiguration(id).comments.lineCommentToken, '1');
        d1.dispose();
        d2.dispose();
        languageConfigurationService.dispose();
    }

    function testLanguageConfigurationsPrioritiesOnContext() {
        final context = new Cityscape();
        final languageConfigurationService = context.languageConfigurationService;
        final id = 'testLang1';
        final d0 = context.languageService.registerLanguage({id: id});
        final d1 = languageConfigurationService.register(id, {comments: {lineComment: '1'}}, 100);
        final d2 = languageConfigurationService.register(id, {comments: {lineComment: '2'}}, 10);
        assertEquals(languageConfigurationService.getLanguageConfiguration(id).comments.lineCommentToken, '1');
        d1.dispose();
        d2.dispose();
        d0.dispose();
        languageConfigurationService.dispose();
    }

    /**
     * Types the modules that have no test of their own yet (they need a text
     * model), so that they keep compiling.
     */
    static function _typeModules():Array<Any> {
        return [
            cityscape.common.languages.EnterAction.EnterActionUtils.getEnterAction,
            cityscape.common.languages.supports.IndentationLineProcessor.ProcessedIndentRulesSupport,
            cityscape.common.languages.supports.InplaceReplaceSupport.BasicInplaceReplace.INSTANCE,
            cityscape.common.core.WordHelper.getWordAtText,
            cityscape.common.model.bracketPairsTextModelPart.BracketPairsImpl.BracketPairsTextModelPart,
            cityscape.common.model.bracketPairsTextModelPart.FixBrackets.fixBracketsInLine,
            cityscape.common.model.bracketPairsTextModelPart.ColorizedBracketPairsDecorationProvider,
        ];
    }

}
