// Ported from vscode src/vs/editor/test/common/model/model.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.core.Position;
import cityscape.common.languages.NullTokenize;
import haxe.io.UInt32Array;
import testing.TestCase;
import testing.TestTokenizationSupport;
import tests.TestTextModel;

/**
 * suite('Editor Model - Words'), the tests that need languages: 'getWordAtPosition
 * at embedded language boundaries' and 'issue #61296' (the others are in
 * `ModelTest.EditorModelWordsTest`). A `Cityscape` context stands for vscode's
 * `createModelServices`.
 */
class ModelWordsLanguagesTest extends TestCase {

    static inline final OUTER_LANGUAGE_ID = 'outerMode';
    static inline final INNER_LANGUAGE_ID = 'innerMode';

    /**
     * `OuterMode`: a language whose tokens are in `innerMode` on the `x` characters.
     */
    static function registerOuterMode(context:Cityscape, disposables:DisposableStore):String {
        final languageId = OUTER_LANGUAGE_ID;
        disposables.add(context.languageService.registerLanguage({id: languageId}));
        disposables.add(context.languageConfigurationService.register(languageId, {}));

        final languageIdCodec = context.languageService.languageIdCodec;
        disposables.add(context.tokenizationRegistry.register(languageId, new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                final tokensArr:Array<Int> = [];
                var prevLanguageId:Null<String> = null;
                for (i in 0...line.length) {
                    final languageId = (line.charAt(i) == 'x' ? INNER_LANGUAGE_ID : OUTER_LANGUAGE_ID);
                    final encodedLanguageId:Int = languageIdCodec.encodeLanguageId(languageId);
                    if (prevLanguageId != languageId) {
                        tokensArr.push(i);
                        tokensArr.push((encodedLanguageId << MetadataConsts.LANGUAGEID_OFFSET));
                    }
                    prevLanguageId = languageId;
                }
                return new EncodedTokenizationResult(UInt32Array.fromArray(tokensArr), state);
            }
        )));
        return languageId;
    }

    /**
     * `InnerMode`.
     */
    static function registerInnerMode(context:Cityscape, disposables:DisposableStore):String {
        disposables.add(context.languageService.registerLanguage({id: INNER_LANGUAGE_ID}));
        disposables.add(context.languageConfigurationService.register(INNER_LANGUAGE_ID, {}));
        return INNER_LANGUAGE_ID;
    }

    function testGetWordAtPositionAtEmbeddedLanguageBoundaries() {
        final disposables = new DisposableStore();
        final context = new Cityscape();
        final outerMode = registerOuterMode(context, disposables);
        registerInnerMode(context, disposables);

        final model = TestTextModel.instantiateTextModel(context, 'ab<xx>ab<x>', outerMode);
        disposables.add(Lifecycle.toDisposable(() -> model.dispose()));

        assertDeepEquals({word: 'ab', startColumn: 1, endColumn: 3}, model.getWordAtPosition(new Position(1, 1)));
        assertDeepEquals({word: 'ab', startColumn: 1, endColumn: 3}, model.getWordAtPosition(new Position(1, 2)));
        assertDeepEquals({word: 'ab', startColumn: 1, endColumn: 3}, model.getWordAtPosition(new Position(1, 3)));
        assertDeepEquals({word: 'xx', startColumn: 4, endColumn: 6}, model.getWordAtPosition(new Position(1, 4)));
        assertDeepEquals({word: 'xx', startColumn: 4, endColumn: 6}, model.getWordAtPosition(new Position(1, 5)));
        assertDeepEquals({word: 'xx', startColumn: 4, endColumn: 6}, model.getWordAtPosition(new Position(1, 6)));
        assertDeepEquals({word: 'ab', startColumn: 7, endColumn: 9}, model.getWordAtPosition(new Position(1, 7)));

        disposables.dispose();
    }

    function testIssue61296VSCodeFreezesWhenEditingCSSFileWithEmoji() {
        final MODE_ID = 'testMode';
        final disposables = new DisposableStore();
        final context = new Cityscape();

        disposables.add(context.languageService.registerLanguage({id: MODE_ID}));
        disposables.add(context.languageConfigurationService.register(MODE_ID, {
            wordPattern: new RegExp("(#?-?\\d*\\.\\d\\w*%?)|(::?[\\w-]*(?=[^,{;]*[,{]))|(([@#.!])?[\\w-?]+%?|[@#!.])", 'g')
        }));

        final thisModel = TestTextModel.instantiateTextModel(context, '.\u{1F437}-a-b', MODE_ID);
        disposables.add(Lifecycle.toDisposable(() -> thisModel.dispose()));

        assertDeepEquals({word: '.', startColumn: 1, endColumn: 2}, thisModel.getWordAtPosition(new Position(1, 1)));
        assertDeepEquals({word: '.', startColumn: 1, endColumn: 2}, thisModel.getWordAtPosition(new Position(1, 2)));
        assertDeepEquals(null, thisModel.getWordAtPosition(new Position(1, 3)));
        assertDeepEquals({word: '-a-b', startColumn: 4, endColumn: 8}, thisModel.getWordAtPosition(new Position(1, 4)));
        assertDeepEquals({word: '-a-b', startColumn: 4, endColumn: 8}, thisModel.getWordAtPosition(new Position(1, 5)));
        assertDeepEquals({word: '-a-b', startColumn: 4, endColumn: 8}, thisModel.getWordAtPosition(new Position(1, 6)));
        assertDeepEquals({word: '-a-b', startColumn: 4, endColumn: 8}, thisModel.getWordAtPosition(new Position(1, 7)));
        assertDeepEquals({word: '-a-b', startColumn: 4, endColumn: 8}, thisModel.getWordAtPosition(new Position(1, 8)));

        disposables.dispose();
    }

}
