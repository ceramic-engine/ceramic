// Ported from vscode src/vs/editor/test/common/model/tokensStore.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import testing.TestCase;

/**
 * Suite 'TokensStore', the tests that need a TextModel (`createTextModel`,
 * `model.tokenization.setSemanticTokens`, `model.applyEdits`,
 * `model.getWordAtPosition`). The other tests are in `TokensStoreTest`.
 *

 */
class TokensStoreModelTest extends TestCase {

    static final SEMANTIC_COLOR:cityscape.common.EncodedTokenAttributes.ColorId = 5;

    function parseTokensState(state:Array<String>):{text:String, tokens:cityscape.common.tokens.SparseMultilineTokens} {
        final text:Array<String> = [];
        final tokens:Array<Int> = [];
        var baseLine = 1;
        for (i in 0...state.length) {
            final line = state[i];

            var startOffset = 0;
            var lineText = '';
            while (true) {
                final firstPipeOffset = line.indexOf('|', startOffset);
                if (firstPipeOffset == -1) {
                    break;
                }
                final secondPipeOffset = line.indexOf('|', firstPipeOffset + 1);
                if (secondPipeOffset == -1) {
                    break;
                }
                if (firstPipeOffset + 1 == secondPipeOffset) {
                    // skip ||
                    lineText += line.substring(startOffset, secondPipeOffset + 1);
                    startOffset = secondPipeOffset + 1;
                    continue;
                }

                lineText += line.substring(startOffset, firstPipeOffset);
                final tokenStartCharacter = lineText.length;
                final tokenLength = secondPipeOffset - firstPipeOffset - 1;
                final metadata = (
                    (SEMANTIC_COLOR : Int) << cityscape.common.EncodedTokenAttributes.MetadataConsts.FOREGROUND_OFFSET
                    | cityscape.common.EncodedTokenAttributes.MetadataConsts.SEMANTIC_USE_FOREGROUND
                );

                if (tokens.length == 0) {
                    baseLine = i + 1;
                }
                tokens.push(i + 1 - baseLine);
                tokens.push(tokenStartCharacter);
                tokens.push(tokenStartCharacter + tokenLength);
                tokens.push(metadata);

                lineText += line.substr(firstPipeOffset + 1, tokenLength);
                startOffset = secondPipeOffset + 1;
            }

            lineText += line.substring(startOffset);

            text.push(lineText);
        }

        return {
            text: text.join('\n'),
            tokens: cityscape.common.tokens.SparseMultilineTokens.create(baseLine, haxe.io.UInt32Array.fromArray(tokens))
        };
    }

    function extractState(model:cityscape.common.Model.ITextModel):Array<String> {
        final result:Array<String> = [];
        for (lineNumber in 1...(model.getLineCount() + 1)) {
            final lineTokens = model.tokenization.getLineTokens(lineNumber);
            final lineContent = model.getLineContent(lineNumber);

            var lineText = '';
            for (i in 0...lineTokens.getCount()) {
                final tokenStartCharacter = lineTokens.getStartOffset(i);
                final tokenEndCharacter = lineTokens.getEndOffset(i);
                final metadata = lineTokens.getMetadata(i);
                final color:Int = cityscape.common.EncodedTokenAttributes.TokenMetadata.getForeground(metadata);
                final tokenText = lineContent.substring(tokenStartCharacter, tokenEndCharacter);
                if (color == (SEMANTIC_COLOR : Int)) {
                    lineText += '|$tokenText|';
                }
                else {
                    lineText += tokenText;
                }
            }

            result.push(lineText);
        }
        return result;
    }

    function checkTokensAdjustment(rawInitialState:Array<String>, edits:Array<cityscape.common.core.EditOperation.ISingleEditOperation>, rawFinalState:Array<String>):Void {
        final initialState = parseTokensState(rawInitialState);
        final model = tests.TestTextModel.createTextModel(initialState.text);
        model.tokenization.setSemanticTokens([initialState.tokens], true);

        model.applyEdits([for (e in edits) (cast e : cityscape.common.Model.IIdentifiedSingleEditOperation)]);

        final actualState = extractState(model);
        assertDeepEquals(rawFinalState, actualState);

        model.dispose();
    }

    function testIssue86303ColorShiftingBetweenDifferentTokens() {
        checkTokensAdjustment(
            [
                "import { |URI| } from 'vs/base/common/uri';",
                "const foo = |URI|.parse('hey');"
            ],
            [
                {range: new cityscape.common.core.Range(2, 9, 2, 10), text: ''}
            ],
            [
                "import { |URI| } from 'vs/base/common/uri';",
                "const fo = |URI|.parse('hey');"
            ]
        );
    }

    function testDeletingANewline() {
        checkTokensAdjustment(
            [
                "import { |URI| } from 'vs/base/common/uri';",
                "const foo = |URI|.parse('hey');"
            ],
            [
                {range: new cityscape.common.core.Range(1, 42, 2, 1), text: ''}
            ],
            [
                "import { |URI| } from 'vs/base/common/uri';const foo = |URI|.parse('hey');"
            ]
        );
    }

    function testInsertingANewline() {
        checkTokensAdjustment(
            [
                "import { |URI| } from 'vs/base/common/uri';const foo = |URI|.parse('hey');"
            ],
            [
                {range: new cityscape.common.core.Range(1, 42, 1, 42), text: '\n'}
            ],
            [
                "import { |URI| } from 'vs/base/common/uri';",
                "const foo = |URI|.parse('hey');"
            ]
        );
    }

    function testDeletingANewline2() {
        checkTokensAdjustment(
            [
                "import { ",
                "    |URI| } from 'vs/base/common/uri';const foo = |URI|.parse('hey');"
            ],
            [
                {range: new cityscape.common.core.Range(1, 10, 2, 5), text: ''}
            ],
            [
                "import { |URI| } from 'vs/base/common/uri';const foo = |URI|.parse('hey');"
            ]
        );
    }

    function testIssue179268AComplexEdit() {
        checkTokensAdjustment(
            [
                "|export| |'interior_material_selector.dart'|;",
                "|export| |'mileage_selector.dart'|;",
                "|export| |'owners_selector.dart'|;",
                "|export| |'price_selector.dart'|;",
                "|export| |'seat_count_selector.dart'|;",
                "|export| |'year_selector.dart'|;",
                "|export| |'winter_options_selector.dart'|;|export| |'camera_selector.dart'|;"
            ],
            [
                {range: new cityscape.common.core.Range(1, 9, 1, 9), text: "camera_selector.dart';\nexport '"},
                {range: new cityscape.common.core.Range(6, 9, 7, 9), text: ""},
                {range: new cityscape.common.core.Range(7, 39, 7, 39), text: "\n"},
                {range: new cityscape.common.core.Range(7, 47, 7, 48), text: "ye"},
                {range: new cityscape.common.core.Range(7, 49, 7, 51), text: ""},
                {range: new cityscape.common.core.Range(7, 52, 7, 53), text: ""},
            ],
            [
                "|export| |'|camera_selector.dart';",
                "export 'interior_material_selector.dart';",
                "|export| |'mileage_selector.dart'|;",
                "|export| |'owners_selector.dart'|;",
                "|export| |'price_selector.dart'|;",
                "|export| |'seat_count_selector.dart'|;",
                "|export| |'||winter_options_selector.dart'|;",
                "|export| |'year_selector.dart'|;"
            ]
        );
    }

    function testIssue91936SemanticTokenColorHighlightingFailsOnLineWithSelectedText() {
        final model = tests.TestTextModel.createTextModel("                    else if ($s = 08) then '\\b'");
        model.tokenization.setSemanticTokens([
            cityscape.common.tokens.SparseMultilineTokens.create(1, haxe.io.UInt32Array.fromArray([
                0, 20, 24, 0x78010, // 0b01111000000000010000
                0, 25, 27, 0x78010, // 0b01111000000000010000
                0, 28, 29, 0x08010, // 0b00001000000000010000
                0, 29, 31, 0x80010, // 0b10000000000000010000
                0, 32, 33, 0x08010, // 0b00001000000000010000
                0, 34, 36, 0x30010, // 0b00110000000000010000
                0, 36, 37, 0x08010, // 0b00001000000000010000
                0, 38, 42, 0x78010, // 0b01111000000000010000
                0, 43, 47, 0x58010, // 0b01011000000000010000
            ]))
        ], true);
        final lineTokens = model.tokenization.getLineTokens(1);
        final decodedTokens:Array<Int> = [];
        for (i in 0...lineTokens.getCount()) {
            decodedTokens.push(lineTokens.getEndOffset(i));
            decodedTokens.push(lineTokens.getMetadata(i));
        }

        assertDeepEquals([
            20, 0x2008401, // 0b10000000001000010000000001
            24, 0x2078401, // 0b10000001111000010000000001
            25, 0x2008401, // 0b10000000001000010000000001
            27, 0x2078401, // 0b10000001111000010000000001
            28, 0x2008401, // 0b10000000001000010000000001
            29, 0x2008401, // 0b10000000001000010000000001
            31, 0x2080401, // 0b10000010000000010000000001
            32, 0x2008401, // 0b10000000001000010000000001
            33, 0x2008401, // 0b10000000001000010000000001
            34, 0x2008401, // 0b10000000001000010000000001
            36, 0x2030401, // 0b10000000110000010000000001
            37, 0x2008401, // 0b10000000001000010000000001
            38, 0x2008401, // 0b10000000001000010000000001
            42, 0x2078401, // 0b10000001111000010000000001
            43, 0x2008401, // 0b10000000001000010000000001
            47, 0x2058401  // 0b10000001011000010000000001
        ], decodedTokens);

        model.dispose();
    }

    function testIssue147944LanguageIdVsEditorNullLanguageIsNotConfiguredNorKnown() {
        // Monaco creates the model with a LanguageConfigurationService
        // (`createModelServices`, `instantiateTextModel`).
        final model = tests.TestTextModel.createTextModel('--[[\n\n]]');
        model.tokenization.setSemanticTokens([
            cityscape.common.tokens.SparseMultilineTokens.create(1, haxe.io.UInt32Array.fromArray([
                0, 2, 4, 0x20010, // 0b100000000000010000
                1, 0, 0, 0x20010, // 0b100000000000010000
                2, 0, 2, 0x20010, // 0b100000000000010000
            ]))
        ], true);
        assertNull(model.getWordAtPosition(new cityscape.common.core.Position(2, 1)));
        model.dispose();
    }


}
