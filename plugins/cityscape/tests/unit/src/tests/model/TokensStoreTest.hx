// Ported from vscode src/vs/editor/test/common/model/tokensStore.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.base.common.JsValues;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.core.Range;
import cityscape.common.services.LanguagesRegistry.LanguageIdCodec;
import cityscape.common.tokens.LineTokens;
import cityscape.common.tokens.SparseMultilineTokens;
import cityscape.common.tokens.SparseTokensStore;
import haxe.io.UInt32Array;
import cityscape.common.tokens.UInt32Arrays;
import testing.TestCase;

/**
 * Suite 'TokensStore', the tests that use a `SparseTokensStore` directly.
 *
 * Not ported yet (needs TextModel: `createTextModel`, `setSemanticTokens`,
 * `applyEdits`, `getWordAtPosition`); their port is in
 * `TokensStoreModelTest`, compiled only with `-D cityscape_text_model` and not
 * registered yet:
 * - 'issue #86303 - color shifting between different tokens'
 * - 'deleting a newline'
 * - 'inserting a newline'
 * - 'deleting a newline 2'
 * - 'issue #179268: a complex edit'
 * - 'issue #91936: Semantic token color highlighting fails on line with selected text'
 * - 'issue #147944: Language id "vs.editor.nullLanguage" is not configured nor known'
 */
class TokensStoreTest extends TestCase {

    function testPartialTokens1() {
        final codec = new LanguageIdCodec();
        final store = new SparseTokensStore(codec);

        // setPartial: [1,1 -> 31,2], [(5,5-10),(10,5-10),(15,5-10),(20,5-10),(25,5-10),(30,5-10)]
        store.setPartial(new Range(1, 1, 31, 2), [
            SparseMultilineTokens.create(5, UInt32Arrays.fromInts([
                0, 5, 10, 1,
                5, 5, 10, 2,
                10, 5, 10, 3,
                15, 5, 10, 4,
                20, 5, 10, 5,
                25, 5, 10, 6,
            ]))
        ]);

        // setPartial: [18,1 -> 42,1], [(20,5-10),(25,5-10),(30,5-10),(35,5-10),(40,5-10)]
        store.setPartial(new Range(18, 1, 42, 1), [
            SparseMultilineTokens.create(20, UInt32Arrays.fromInts([
                0, 5, 10, 4,
                5, 5, 10, 5,
                10, 5, 10, 6,
                15, 5, 10, 7,
                20, 5, 10, 8,
            ]))
        ]);

        // setPartial: [1,1 -> 31,2], [(5,5-10),(10,5-10),(15,5-10),(20,5-10),(25,5-10),(30,5-10)]
        store.setPartial(new Range(1, 1, 31, 2), [
            SparseMultilineTokens.create(5, UInt32Arrays.fromInts([
                0, 5, 10, 1,
                5, 5, 10, 2,
                10, 5, 10, 3,
                15, 5, 10, 4,
                20, 5, 10, 5,
                25, 5, 10, 6,
            ]))
        ]);

        final lineTokens = store.addSparseTokens(10, new LineTokens(UInt32Arrays.fromInts([12, 1]), 'enum Enum1 {', codec));
        assertEquals(3, lineTokens.getCount());
    }

    function testPartialTokens2() {
        final codec = new LanguageIdCodec();
        final store = new SparseTokensStore(codec);

        // setPartial: [1,1 -> 31,2], [(5,5-10),(10,5-10),(15,5-10),(20,5-10),(25,5-10),(30,5-10)]
        store.setPartial(new Range(1, 1, 31, 2), [
            SparseMultilineTokens.create(5, UInt32Arrays.fromInts([
                0, 5, 10, 1,
                5, 5, 10, 2,
                10, 5, 10, 3,
                15, 5, 10, 4,
                20, 5, 10, 5,
                25, 5, 10, 6,
            ]))
        ]);

        // setPartial: [6,1 -> 36,2], [(10,5-10),(15,5-10),(20,5-10),(25,5-10),(30,5-10),(35,5-10)]
        store.setPartial(new Range(6, 1, 36, 2), [
            SparseMultilineTokens.create(10, UInt32Arrays.fromInts([
                0, 5, 10, 2,
                5, 5, 10, 3,
                10, 5, 10, 4,
                15, 5, 10, 5,
                20, 5, 10, 6,
            ]))
        ]);

        // setPartial: [17,1 -> 42,1], [(20,5-10),(25,5-10),(30,5-10),(35,5-10),(40,5-10)]
        store.setPartial(new Range(17, 1, 42, 1), [
            SparseMultilineTokens.create(20, UInt32Arrays.fromInts([
                0, 5, 10, 4,
                5, 5, 10, 5,
                10, 5, 10, 6,
                15, 5, 10, 7,
                20, 5, 10, 8,
            ]))
        ]);

        final lineTokens = store.addSparseTokens(20, new LineTokens(UInt32Arrays.fromInts([12, 1]), 'enum Enum1 {', codec));
        assertEquals(3, lineTokens.getCount());
    }

    function testPartialTokens3() {
        final codec = new LanguageIdCodec();
        final store = new SparseTokensStore(codec);

        // setPartial: [1,1 -> 31,2], [(5,5-10),(10,5-10),(15,5-10),(20,5-10),(25,5-10),(30,5-10)]
        store.setPartial(new Range(1, 1, 31, 2), [
            SparseMultilineTokens.create(5, UInt32Arrays.fromInts([
                0, 5, 10, 1,
                5, 5, 10, 2,
                10, 5, 10, 3,
                15, 5, 10, 4,
                20, 5, 10, 5,
                25, 5, 10, 6,
            ]))
        ]);

        // setPartial: [11,1 -> 16,2], [(15,5-10),(20,5-10)]
        store.setPartial(new Range(11, 1, 16, 2), [
            SparseMultilineTokens.create(10, UInt32Arrays.fromInts([
                0, 5, 10, 3,
                5, 5, 10, 4,
            ]))
        ]);

        final lineTokens = store.addSparseTokens(5, new LineTokens(UInt32Arrays.fromInts([12, 1]), 'enum Enum1 {', codec));
        assertEquals(3, lineTokens.getCount());
    }

    function testIssue94133SemanticColorsStickAroundWhenUsingOnlyRangeProvider() {
        final codec = new LanguageIdCodec();
        final store = new SparseTokensStore(codec);

        // setPartial: [1,1 -> 1,20] [(1,9-11)]
        store.setPartial(new Range(1, 1, 1, 20), [
            SparseMultilineTokens.create(1, UInt32Arrays.fromInts([
                0, 9, 11, 1,
            ]))
        ]);

        // setPartial: [1,1 -> 1,20], []
        store.setPartial(new Range(1, 1, 1, 20), []);

        final lineTokens = store.addSparseTokens(1, new LineTokens(UInt32Arrays.fromInts([12, 1]), 'enum Enum1 {', codec));
        assertEquals(1, lineTokens.getCount());
    }

    function testBug() {
        function createTokens(str:String):SparseMultilineTokens {
            // str.replace(/^\[\(/, '') and str.replace(/\)\]$/, '')
            if (StringTools.startsWith(str, '[(')) {
                str = str.substring(2);
            }
            if (StringTools.endsWith(str, ')]')) {
                str = str.substring(0, str.length - 2);
            }
            final strTokens = str.split('),(');
            final result:Array<Int> = [];
            var firstLineNumber = 0;
            for (strToken in strTokens) {
                final pieces = strToken.split(',');
                final chars = pieces[1].split('-');
                final lineNumber = Std.int(JsValues.parseInt(pieces[0]));
                final startChar = Std.int(JsValues.parseInt(chars[0]));
                final endChar = Std.int(JsValues.parseInt(chars[1]));
                if (firstLineNumber == 0) {
                    // this is the first line
                    firstLineNumber = lineNumber;
                }
                result.push(lineNumber - firstLineNumber);
                result.push(startChar);
                result.push(endChar);
                result.push((lineNumber + startChar) % 13);
            }
            return SparseMultilineTokens.create(firstLineNumber, UInt32Arrays.fromInts(result));
        }

        final codec = new LanguageIdCodec();
        final store = new SparseTokensStore(codec);
        // setPartial [36446,1 -> 36475,115]
        store.setPartial(
            new Range(36446, 1, 36475, 115),
            [createTokens('[(36448,24-29),(36448,33-46),(36448,47-54),(36450,25-35),(36450,36-50),(36451,28-33),(36451,36-49),(36451,50-57),(36452,35-53),(36452,54-62),(36454,33-38),(36454,41-54),(36454,55-60),(36455,35-53),(36455,54-62),(36457,33-44),(36457,45-49),(36457,50-56),(36457,62-83),(36457,84-88),(36458,35-53),(36458,54-62),(36460,33-37),(36460,38-42),(36460,47-57),(36460,58-67),(36461,35-53),(36461,54-62),(36463,34-38),(36463,39-45),(36463,46-51),(36463,54-63),(36463,64-71),(36463,76-80),(36463,81-87),(36463,88-92),(36463,97-107),(36463,108-119),(36464,35-53),(36464,54-62),(36466,33-71),(36466,72-76),(36467,35-53),(36467,54-62),(36469,24-29),(36469,33-46),(36469,47-54),(36470,24-35),(36470,38-46),(36473,25-35),(36473,36-51),(36474,28-33),(36474,36-49),(36474,50-58),(36475,35-53),(36475,54-62)]')]
        );
        // setPartial [36436,1 -> 36464,142]
        store.setPartial(
            new Range(36436, 1, 36464, 142),
            [createTokens('[(36437,33-37),(36437,38-42),(36437,47-57),(36437,58-67),(36438,35-53),(36438,54-62),(36440,24-29),(36440,33-46),(36440,47-53),(36442,25-35),(36442,36-50),(36443,30-39),(36443,42-46),(36443,47-53),(36443,54-58),(36443,63-73),(36443,74-84),(36443,87-91),(36443,92-98),(36443,101-105),(36443,106-112),(36443,113-119),(36444,28-37),(36444,38-42),(36444,47-57),(36444,58-75),(36444,80-95),(36444,96-105),(36445,35-53),(36445,54-62),(36448,24-29),(36448,33-46),(36448,47-54),(36450,25-35),(36450,36-50),(36451,28-33),(36451,36-49),(36451,50-57),(36452,35-53),(36452,54-62),(36454,33-38),(36454,41-54),(36454,55-60),(36455,35-53),(36455,54-62),(36457,33-44),(36457,45-49),(36457,50-56),(36457,62-83),(36457,84-88),(36458,35-53),(36458,54-62),(36460,33-37),(36460,38-42),(36460,47-57),(36460,58-67),(36461,35-53),(36461,54-62),(36463,34-38),(36463,39-45),(36463,46-51),(36463,54-63),(36463,64-71),(36463,76-80),(36463,81-87),(36463,88-92),(36463,97-107),(36463,108-119),(36464,35-53),(36464,54-62)]')]
        );
        // setPartial [36457,1 -> 36485,140]
        store.setPartial(
            new Range(36457, 1, 36485, 140),
            [createTokens('[(36457,33-44),(36457,45-49),(36457,50-56),(36457,62-83),(36457,84-88),(36458,35-53),(36458,54-62),(36460,33-37),(36460,38-42),(36460,47-57),(36460,58-67),(36461,35-53),(36461,54-62),(36463,34-38),(36463,39-45),(36463,46-51),(36463,54-63),(36463,64-71),(36463,76-80),(36463,81-87),(36463,88-92),(36463,97-107),(36463,108-119),(36464,35-53),(36464,54-62),(36466,33-71),(36466,72-76),(36467,35-53),(36467,54-62),(36469,24-29),(36469,33-46),(36469,47-54),(36470,24-35),(36470,38-46),(36473,25-35),(36473,36-51),(36474,28-33),(36474,36-49),(36474,50-58),(36475,35-53),(36475,54-62),(36477,28-32),(36477,33-37),(36477,42-52),(36477,53-69),(36478,32-36),(36478,37-41),(36478,46-56),(36478,57-74),(36479,32-36),(36479,37-41),(36479,46-56),(36479,57-76),(36480,32-36),(36480,37-41),(36480,46-56),(36480,57-68),(36481,32-36),(36481,37-41),(36481,46-56),(36481,57-68),(36482,39-57),(36482,58-66),(36484,34-38),(36484,39-45),(36484,46-50),(36484,55-65),(36484,66-82),(36484,86-97),(36484,98-102),(36484,103-109),(36484,111-124),(36484,125-133),(36485,39-57),(36485,58-66)]')]
        );
        // setPartial [36441,1 -> 36469,56]
        store.setPartial(
            new Range(36441, 1, 36469, 56),
            [createTokens('[(36442,25-35),(36442,36-50),(36443,30-39),(36443,42-46),(36443,47-53),(36443,54-58),(36443,63-73),(36443,74-84),(36443,87-91),(36443,92-98),(36443,101-105),(36443,106-112),(36443,113-119),(36444,28-37),(36444,38-42),(36444,47-57),(36444,58-75),(36444,80-95),(36444,96-105),(36445,35-53),(36445,54-62),(36448,24-29),(36448,33-46),(36448,47-54),(36450,25-35),(36450,36-50),(36451,28-33),(36451,36-49),(36451,50-57),(36452,35-53),(36452,54-62),(36454,33-38),(36454,41-54),(36454,55-60),(36455,35-53),(36455,54-62),(36457,33-44),(36457,45-49),(36457,50-56),(36457,62-83),(36457,84-88),(36458,35-53),(36458,54-62),(36460,33-37),(36460,38-42),(36460,47-57),(36460,58-67),(36461,35-53),(36461,54-62),(36463,34-38),(36463,39-45),(36463,46-51),(36463,54-63),(36463,64-71),(36463,76-80),(36463,81-87),(36463,88-92),(36463,97-107),(36463,108-119),(36464,35-53),(36464,54-62),(36466,33-71),(36466,72-76),(36467,35-53),(36467,54-62),(36469,24-29),(36469,33-46),(36469,47-54),(36470,24-35)]')]
        );

        final lineTokens = store.addSparseTokens(36451, new LineTokens(UInt32Arrays.fromInts([60, 1]), '                        if (flags & ModifierFlags.Ambient) {', codec));
        assertEquals(7, lineTokens.getCount());
    }

    function testIssue95949IdentifiersAreColoredInBoldWhenTargettingKeywords() {

        function createTMMetadata(foreground:Int, fontStyle:Int, languageId:Int):Int {
            return (
                (languageId << MetadataConsts.LANGUAGEID_OFFSET)
                | (fontStyle << MetadataConsts.FONT_STYLE_OFFSET)
                | (foreground << MetadataConsts.FOREGROUND_OFFSET)
            ) >>> 0;
        }

        function toArr(lineTokens:LineTokens):Array<Int> {
            final r:Array<Int> = [];
            for (i in 0...lineTokens.getCount()) {
                r.push(lineTokens.getEndOffset(i));
                r.push(lineTokens.getMetadata(i));
            }
            return r;
        }

        final codec = new LanguageIdCodec();
        final store = new SparseTokensStore(codec);

        store.set([
            SparseMultilineTokens.create(1, UInt32Arrays.fromInts([
                0, 6, 11, (1 << MetadataConsts.FOREGROUND_OFFSET) | MetadataConsts.SEMANTIC_USE_FOREGROUND,
            ]))
        ], true);

        final lineTokens = store.addSparseTokens(1, new LineTokens(UInt32Arrays.fromInts([
            5, createTMMetadata(5, FontStyle.Bold, 53),
            14, createTMMetadata(1, FontStyle.None, 53),
            17, createTMMetadata(6, FontStyle.None, 53),
            18, createTMMetadata(1, FontStyle.None, 53),
        ]), 'const hello = 123;', codec));

        final actual = toArr(lineTokens);
        assertDeepEquals([
            5, createTMMetadata(5, FontStyle.Bold, 53),
            6, createTMMetadata(1, FontStyle.None, 53),
            11, createTMMetadata(1, FontStyle.None, 53),
            14, createTMMetadata(1, FontStyle.None, 53),
            17, createTMMetadata(6, FontStyle.None, 53),
            18, createTMMetadata(1, FontStyle.None, 53)
        ], actual);
    }

}
