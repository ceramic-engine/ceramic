// Ported from vscode src/vs/editor/test/browser/commands/trimTrailingWhitespaceCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.commands;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.commands.TrimTrailingWhitespaceCommand;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.NullTokenize;
import haxe.io.UInt32Array;
import testing.TestCase;
import testing.TestCommand;
import testing.TestTokenizationSupport;
import tests.TestTextModel;

/**
 * suite('Editor Commands - Trim Trailing Whitespace Command')
 */
class TrimTrailingWhitespaceCommandTest extends TestCase {

    var disposables:DisposableStore;

    override function setup():Void {
        disposables = new DisposableStore();
    }

    override function teardown():Void {
        disposables.dispose();
    }

    /**
     * Create single edit operation
     */
    static function createInsertDeleteSingleEditOp(text:Null<String>, positionLineNumber:Int, positionColumn:Int, ?selectionLineNumber:Int, ?selectionColumn:Int):ISingleEditOperation {
        return {
            range: new Range(selectionLineNumber != null ? selectionLineNumber : positionLineNumber, selectionColumn != null ? selectionColumn : positionColumn, positionLineNumber, positionColumn),
            text: text
        };
    }

    /**
     * Create single edit operation
     */
    static function createSingleEditOp(text:Null<String>, positionLineNumber:Int, positionColumn:Int, ?selectionLineNumber:Int, ?selectionColumn:Int):ISingleEditOperation {
        return {
            range: new Range(selectionLineNumber != null ? selectionLineNumber : positionLineNumber, selectionColumn != null ? selectionColumn : positionColumn, positionLineNumber, positionColumn),
            text: text,
            forceMoveMarkers: false
        };
    }

    function assertTrimTrailingWhitespaceCommand(text:Array<String>, expected:Array<ISingleEditOperation>, ?pos:haxe.PosInfos):Void {
        TestTextModel.withEditorModel(text, (model) -> {
            final op = new TrimTrailingWhitespaceCommand(new Selection(1, 1, 1, 1), [], true);
            final actual = TestCommand.getEditOperation(model, op);
            assertDeepEquals(expected, actual, null, pos);
        });
    }

    function assertTrimTrailingWhitespace(text:Array<String>, cursors:Array<Position>, expected:Array<ISingleEditOperation>, ?pos:haxe.PosInfos):Void {
        TestTextModel.withEditorModel(text, (model) -> {
            final actual = TrimTrailingWhitespaceCommand.trimTrailingWhitespace(model, cursors, true);
            assertDeepEquals(expected, actual, null, pos);
        });
    }

    /**
     * test('remove trailing whitespace')
     */
    function testRemoveTrailingWhitespace() {
        assertTrimTrailingWhitespaceCommand([''], []);
        assertTrimTrailingWhitespaceCommand(['text'], []);
        assertTrimTrailingWhitespaceCommand(['text   '], [createSingleEditOp(null, 1, 5, 1, 8)]);
        assertTrimTrailingWhitespaceCommand(['text\t   '], [createSingleEditOp(null, 1, 5, 1, 9)]);
        assertTrimTrailingWhitespaceCommand(['\t   '], [createSingleEditOp(null, 1, 1, 1, 5)]);
        assertTrimTrailingWhitespaceCommand(['text\t'], [createSingleEditOp(null, 1, 5, 1, 6)]);
        assertTrimTrailingWhitespaceCommand([
            'some text\t',
            'some more text',
            '\t  ',
            'even more text  ',
            'and some mixed\t   \t'
        ], [
            createSingleEditOp(null, 1, 10, 1, 11),
            createSingleEditOp(null, 3, 1, 3, 4),
            createSingleEditOp(null, 4, 15, 4, 17),
            createSingleEditOp(null, 5, 15, 5, 20)
        ]);


        assertTrimTrailingWhitespace(['text   '], [new Position(1, 1), new Position(1, 2), new Position(1, 3)], [createInsertDeleteSingleEditOp(null, 1, 5, 1, 8)]);
        assertTrimTrailingWhitespace(['text   '], [new Position(1, 1), new Position(1, 5)], [createInsertDeleteSingleEditOp(null, 1, 5, 1, 8)]);
        assertTrimTrailingWhitespace(['text   '], [new Position(1, 1), new Position(1, 5), new Position(1, 6)], [createInsertDeleteSingleEditOp(null, 1, 6, 1, 8)]);
        assertTrimTrailingWhitespace([
            'some text\t',
            'some more text',
            '\t  ',
            'even more text  ',
            'and some mixed\t   \t'
        ], [], [
            createInsertDeleteSingleEditOp(null, 1, 10, 1, 11),
            createInsertDeleteSingleEditOp(null, 3, 1, 3, 4),
            createInsertDeleteSingleEditOp(null, 4, 15, 4, 17),
            createInsertDeleteSingleEditOp(null, 5, 15, 5, 20)
        ]);
        assertTrimTrailingWhitespace([
            'some text\t',
            'some more text',
            '\t  ',
            'even more text  ',
            'and some mixed\t   \t'
        ], [new Position(1, 11), new Position(3, 2), new Position(5, 1), new Position(4, 1), new Position(5, 10)], [
            createInsertDeleteSingleEditOp(null, 3, 2, 3, 4),
            createInsertDeleteSingleEditOp(null, 4, 15, 4, 17),
            createInsertDeleteSingleEditOp(null, 5, 15, 5, 20)
        ]);
    }

    /**
     * test('skips strings and regex if configured')
     */
    function testSkipsStringsAndRegexIfConfigured() {
        final instantiationService = new Cityscape();
        final languageService = instantiationService.languageService;
        final languageId = 'testLanguageId';
        final languageIdCodec = languageService.languageIdCodec;
        disposables.add(languageService.registerLanguage({id: languageId}));
        final encodedLanguageId:Int = languageIdCodec.encodeLanguageId(languageId);

        final otherMetadata = (
            (encodedLanguageId << MetadataConsts.LANGUAGEID_OFFSET)
            | ((StandardTokenType.Other : Int) << MetadataConsts.TOKEN_TYPE_OFFSET)
            | (MetadataConsts.BALANCED_BRACKETS_MASK : Int)
        );
        final stringMetadata = (
            (encodedLanguageId << MetadataConsts.LANGUAGEID_OFFSET)
            | ((StandardTokenType.String : Int) << MetadataConsts.TOKEN_TYPE_OFFSET)
            | (MetadataConsts.BALANCED_BRACKETS_MASK : Int)
        );

        final tokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                switch (line) {
                    case 'const a = `  ': {
                        final tokens = UInt32Array.fromArray([
                            0, otherMetadata,
                            10, stringMetadata,
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                    }
                    case '  a string  ': {
                        final tokens = UInt32Array.fromArray([
                            0, stringMetadata,
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                    }
                    case '`;  ': {
                        final tokens = UInt32Array.fromArray([
                            0, stringMetadata,
                            1, otherMetadata
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                    }
                    case _:
                }
                throw 'Unexpected';
            }
        );

        disposables.add(instantiationService.tokenizationRegistry.register(languageId, tokenizationSupport));

        final model = TestTextModel.instantiateTextModel(
            instantiationService,
            [
                'const a = `  ',
                '  a string  ',
                '`;  ',
            ].join('\n'),
            languageId
        );
        disposables.add(Lifecycle.toDisposable(() -> model.dispose()));

        model.tokenization.forceTokenization(1);
        model.tokenization.forceTokenization(2);
        model.tokenization.forceTokenization(3);

        final op = new TrimTrailingWhitespaceCommand(new Selection(1, 1, 1, 1), [], false);
        final actual = TestCommand.getEditOperation(model, op);
        assertDeepEquals([createSingleEditOp(null, 3, 3, 3, 5)], actual);
    }

}
