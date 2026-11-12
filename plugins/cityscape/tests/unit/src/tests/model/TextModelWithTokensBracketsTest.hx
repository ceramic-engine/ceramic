// Ported from vscode src/vs/editor/test/common/model/textModelWithTokens.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.TextModelBracketPairs.IFoundBracket;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageConfiguration.CharacterPair;
import cityscape.common.languages.NullTokenize;
import haxe.io.UInt32Array;
import cityscape.common.tokens.UInt32Arrays;
import testing.TestCase;
import tests.TestTextModel;
import testing.TestTokenizationSupport;

/**
 * The bracket tests of textModelWithTokens.test.ts: suites
 * 'TextModelWithTokens', 'TextModelWithTokens - bracket matching',
 * 'TextModelWithTokens 2' and the bracket tests of 'TextModelWithTokens
 * regression tests' (monaco-editor#133, #11856). Each test has its own
 * `Cityscape` context (Monaco's `createModelServices`).
 */
class TextModelWithTokensBracketsTest extends TestCase {

    static function createTextModelWithBrackets(disposables:DisposableStore, text:String, brackets:Array<CharacterPair>):TestTextModel {
        final languageId = 'bracketMode2';
        final context = new Cityscape();
        final languageConfigurationService = context.languageConfigurationService;
        final languageService = context.languageService;

        disposables.add(languageService.registerLanguage({id: languageId}));
        disposables.add(languageConfigurationService.register(languageId, {brackets: brackets}));

        final model = TestTextModel.instantiateTextModel(context, text, languageId);
        disposables.add(Lifecycle.toDisposable(() -> model.dispose()));
        return model;
    }

    /**
     * `assert.deepStrictEqual(toRelaxedFoundBracket(actual), toRelaxedFoundBracket(expected))`:
     * the ranges as strings, the bracket infos compared by identity (the
     * language configuration gives the same objects, so they are deeply
     * equal too).
     */
    function assertFoundBracket(expected:Null<IFoundBracket>, actual:Null<IFoundBracket>, message:String, ?pos:haxe.PosInfos):Void {
        if (expected == null || actual == null) {
            assertTrue(expected == null && actual == null, message + ': expected ' + (expected == null ? 'null' : expected.range.toString()) + ' but got ' + (actual == null ? 'null' : actual.range.toString()), pos);
            return;
        }
        assertEquals(expected.range.toString(), actual.range.toString(), message, pos);
        assertTrue(expected.bracketInfo == actual.bracketInfo, message + ': bracket info', pos);
    }

    function checkBrackets(contents:Array<String>, brackets:Array<CharacterPair>):Void {
        final languageId = 'testMode';
        final disposables = new DisposableStore();
        final context = new Cityscape();
        final languageConfigurationService = context.languageConfigurationService;
        final languageService = context.languageService;
        disposables.add(languageService.registerLanguage({id: languageId}));
        disposables.add(languageConfigurationService.register(languageId, {
            brackets: brackets
        }));

        final charIsBracket = new Map<String, Bool>();
        for (b in brackets) {
            charIsBracket.set(b[0], true);
            charIsBracket.set(b[1], true);
        }

        final expectedBrackets:Array<IFoundBracket> = [];
        for (lineIndex in 0...contents.length) {
            final lineText = contents[lineIndex];

            for (charIndex in 0...lineText.length) {
                final ch = lineText.charAt(charIndex);
                if (charIsBracket.exists(ch)) {
                    expectedBrackets.push({
                        bracketInfo: languageConfigurationService.getLanguageConfiguration(languageId).bracketsNew.getBracketInfo(ch),
                        range: new Range(lineIndex + 1, charIndex + 1, lineIndex + 1, charIndex + 2)
                    });
                }
            }
        }

        final model = TestTextModel.instantiateTextModel(context, contents.join('\n'), languageId);
        disposables.add(Lifecycle.toDisposable(() -> model.dispose()));

        // findPrevBracket
        {
            var expectedBracketIndex = expectedBrackets.length - 1;
            var currentExpectedBracket = expectedBracketIndex >= 0 ? expectedBrackets[expectedBracketIndex] : null;
            var lineNumber = contents.length;
            while (lineNumber >= 1) {
                final lineText = contents[lineNumber - 1];

                var column = lineText.length + 1;
                while (column >= 1) {

                    if (currentExpectedBracket != null) {
                        if (lineNumber == currentExpectedBracket.range.startLineNumber && column < currentExpectedBracket.range.endColumn) {
                            expectedBracketIndex--;
                            currentExpectedBracket = expectedBracketIndex >= 0 ? expectedBrackets[expectedBracketIndex] : null;
                        }
                    }

                    final actual = model.bracketPairs.findPrevBracket({
                        lineNumber: lineNumber,
                        column: column
                    });

                    assertFoundBracket(currentExpectedBracket, actual, 'findPrevBracket of ' + lineNumber + ', ' + column);
                    column--;
                }
                lineNumber--;
            }
        }

        // findNextBracket
        {
            var expectedBracketIndex = 0;
            var currentExpectedBracket = expectedBracketIndex < expectedBrackets.length ? expectedBrackets[expectedBracketIndex] : null;
            for (lineNumber in 1...(contents.length + 1)) {
                final lineText = contents[lineNumber - 1];

                for (column in 1...(lineText.length + 2)) {

                    if (currentExpectedBracket != null) {
                        if (lineNumber == currentExpectedBracket.range.startLineNumber && column > currentExpectedBracket.range.startColumn) {
                            expectedBracketIndex++;
                            currentExpectedBracket = expectedBracketIndex < expectedBrackets.length ? expectedBrackets[expectedBracketIndex] : null;
                        }
                    }

                    final actual = model.bracketPairs.findNextBracket({
                        lineNumber: lineNumber,
                        column: column
                    });

                    assertFoundBracket(currentExpectedBracket, actual, 'findNextBracket of ' + lineNumber + ', ' + column);
                }
            }
        }

        disposables.dispose();
    }

    function testBrackets1() {
        checkBrackets([
            'if (a == 3) { return (7 * (a + 5)); }'
        ], [
            ['{', '}'],
            ['[', ']'],
            ['(', ')']
        ]);
    }

    function assertIsNotBracket(model:TestTextModel, lineNumber:Int, column:Int, ?pos:haxe.PosInfos):Void {
        final match = model.bracketPairs.matchBracket(new Position(lineNumber, column));
        assertNull(match, 'is not matching brackets at ' + lineNumber + ', ' + column, pos);
    }

    function assertIsBracket(model:TestTextModel, testPosition:Position, expected:Array<Range>, ?pos:haxe.PosInfos):Void {
        expected.sort(Range.compareRangesUsingStarts);
        final actual = model.bracketPairs.matchBracket(testPosition);
        if (actual != null) {
            actual.sort(Range.compareRangesUsingStarts);
        }
        assertDeepEquals(
            [for (r in expected) r.toString()],
            actual == null ? null : [for (r in actual) r.toString()],
            'matches brackets at ' + testPosition, pos
        );
    }

    // suite('TextModelWithTokens - bracket matching')

    static inline final bracketMode1 = 'bracketMode1';

    function createBracketMode1Model(disposables:DisposableStore, text:String):TestTextModel {
        final context = new Cityscape();
        disposables.add(context.languageService.registerLanguage({id: bracketMode1}));
        disposables.add(context.languageConfigurationService.register(bracketMode1, {
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')'],
            ]
        }));
        final model = TestTextModel.instantiateTextModel(context, text, bracketMode1);
        disposables.add(Lifecycle.toDisposable(() -> model.dispose()));
        return model;
    }

    function testBracketMatching1() {
        final disposables = new DisposableStore();
        final text =
            ')]}{[(' + '\n' +
            ')]}{[(';
        final model = createBracketMode1Model(disposables, text);

        assertIsNotBracket(model, 1, 1);
        assertIsNotBracket(model, 1, 2);
        assertIsNotBracket(model, 1, 3);
        assertIsBracket(model, new Position(1, 4), [new Range(1, 4, 1, 5), new Range(2, 3, 2, 4)]);
        assertIsBracket(model, new Position(1, 5), [new Range(1, 5, 1, 6), new Range(2, 2, 2, 3)]);
        assertIsBracket(model, new Position(1, 6), [new Range(1, 6, 1, 7), new Range(2, 1, 2, 2)]);
        assertIsBracket(model, new Position(1, 7), [new Range(1, 6, 1, 7), new Range(2, 1, 2, 2)]);

        assertIsBracket(model, new Position(2, 1), [new Range(2, 1, 2, 2), new Range(1, 6, 1, 7)]);
        assertIsBracket(model, new Position(2, 2), [new Range(2, 2, 2, 3), new Range(1, 5, 1, 6)]);
        assertIsBracket(model, new Position(2, 3), [new Range(2, 3, 2, 4), new Range(1, 4, 1, 5)]);
        assertIsBracket(model, new Position(2, 4), [new Range(2, 3, 2, 4), new Range(1, 4, 1, 5)]);
        assertIsNotBracket(model, 2, 5);
        assertIsNotBracket(model, 2, 6);
        assertIsNotBracket(model, 2, 7);
        disposables.dispose();
    }

    function testBracketMatching2() {
        final disposables = new DisposableStore();
        final text =
            'var bar = {' + '\n' +
            'foo: {' + '\n' +
            '}, bar: {hallo: [{' + '\n' +
            '}, {' + '\n' +
            '}]}}';
        final model = createBracketMode1Model(disposables, text);

        final brackets:Array<Array<Dynamic>> = [
            [new Position(1, 11), new Range(1, 11, 1, 12), new Range(5, 4, 5, 5)],
            [new Position(1, 12), new Range(1, 11, 1, 12), new Range(5, 4, 5, 5)],

            [new Position(2, 6), new Range(2, 6, 2, 7), new Range(3, 1, 3, 2)],
            [new Position(2, 7), new Range(2, 6, 2, 7), new Range(3, 1, 3, 2)],

            [new Position(3, 1), new Range(3, 1, 3, 2), new Range(2, 6, 2, 7)],
            [new Position(3, 2), new Range(3, 1, 3, 2), new Range(2, 6, 2, 7)],
            [new Position(3, 9), new Range(3, 9, 3, 10), new Range(5, 3, 5, 4)],
            [new Position(3, 10), new Range(3, 9, 3, 10), new Range(5, 3, 5, 4)],
            [new Position(3, 17), new Range(3, 17, 3, 18), new Range(5, 2, 5, 3)],
            [new Position(3, 18), new Range(3, 18, 3, 19), new Range(4, 1, 4, 2)],
            [new Position(3, 19), new Range(3, 18, 3, 19), new Range(4, 1, 4, 2)],

            [new Position(4, 1), new Range(4, 1, 4, 2), new Range(3, 18, 3, 19)],
            [new Position(4, 2), new Range(4, 1, 4, 2), new Range(3, 18, 3, 19)],
            [new Position(4, 4), new Range(4, 4, 4, 5), new Range(5, 1, 5, 2)],
            [new Position(4, 5), new Range(4, 4, 4, 5), new Range(5, 1, 5, 2)],

            [new Position(5, 1), new Range(5, 1, 5, 2), new Range(4, 4, 4, 5)],
            [new Position(5, 2), new Range(5, 2, 5, 3), new Range(3, 17, 3, 18)],
            [new Position(5, 3), new Range(5, 3, 5, 4), new Range(3, 9, 3, 10)],
            [new Position(5, 4), new Range(5, 4, 5, 5), new Range(1, 11, 1, 12)],
            [new Position(5, 5), new Range(5, 4, 5, 5), new Range(1, 11, 1, 12)],
        ];

        final isABracket = new Map<String, Bool>();
        for (b in brackets) {
            final testPos:Position = b[0];
            assertIsBracket(model, testPos, [b[1], b[2]]);
            isABracket.set(testPos.lineNumber + ':' + testPos.column, true);
        }

        for (i in 1...(model.getLineCount() + 1)) {
            final line = model.getLineContent(i);
            for (j in 1...(line.length + 2)) {
                if (!isABracket.exists(i + ':' + j)) {
                    assertIsNotBracket(model, i, j);
                }
            }
        }
        disposables.dispose();
    }

    // suite('TextModelWithTokens 2')

    function testBracketMatching3() {
        final text = [
            'begin',
            '    loop',
            '        if then',
            '        end if;',
            '    end loop;',
            'end;',
            '',
            'begin',
            '    loop',
            '        if then',
            '        end ifa;',
            '    end loop;',
            'end;',
        ].join('\n');

        final disposables = new DisposableStore();
        final model = createTextModelWithBrackets(disposables, text, [
            ['if', 'end if'],
            ['loop', 'end loop'],
            ['begin', 'end']
        ]);

        // <if> ... <end ifa> is not matched
        assertIsNotBracket(model, 10, 9);

        // <if> ... <end if> is matched
        assertIsBracket(model, new Position(3, 9), [new Range(3, 9, 3, 11), new Range(4, 9, 4, 15)]);
        assertIsBracket(model, new Position(4, 9), [new Range(4, 9, 4, 15), new Range(3, 9, 3, 11)]);

        // <loop> ... <end loop> is matched
        assertIsBracket(model, new Position(2, 5), [new Range(2, 5, 2, 9), new Range(5, 5, 5, 13)]);
        assertIsBracket(model, new Position(5, 5), [new Range(5, 5, 5, 13), new Range(2, 5, 2, 9)]);

        // <begin> ... <end> is matched
        assertIsBracket(model, new Position(1, 1), [new Range(1, 1, 1, 6), new Range(6, 1, 6, 4)]);
        assertIsBracket(model, new Position(6, 1), [new Range(6, 1, 6, 4), new Range(1, 1, 1, 6)]);

        disposables.dispose();
    }

    function testBracketMatching4() {
        final text = [
            'recordbegin',
            '  simplerecordbegin',
            '  endrecord',
            'endrecord',
        ].join('\n');

        final disposables = new DisposableStore();
        final model = createTextModelWithBrackets(disposables, text, [
            ['recordbegin', 'endrecord'],
            ['simplerecordbegin', 'endrecord'],
        ]);

        // <recordbegin> ... <endrecord> is matched
        assertIsBracket(model, new Position(1, 1), [new Range(1, 1, 1, 12), new Range(4, 1, 4, 10)]);
        assertIsBracket(model, new Position(4, 1), [new Range(4, 1, 4, 10), new Range(1, 1, 1, 12)]);

        // <simplerecordbegin> ... <endrecord> is matched
        assertIsBracket(model, new Position(2, 3), [new Range(2, 3, 2, 20), new Range(3, 3, 3, 12)]);
        assertIsBracket(model, new Position(3, 3), [new Range(3, 3, 3, 12), new Range(2, 3, 2, 20)]);

        disposables.dispose();
    }

    function testIssue95843HighlightingOfClosingBracesIsIndicatingWrongBraceWhenCursorIsBehindOpeningBrace() {
        final disposables = new DisposableStore();
        final context = new Cityscape();
        final languageConfigurationService = context.languageConfigurationService;
        final languageService = context.languageService;
        final mode1 = 'testMode1';
        final mode2 = 'testMode2';

        final languageIdCodec = languageService.languageIdCodec;

        disposables.add(languageService.registerLanguage({id: mode1}));
        disposables.add(languageService.registerLanguage({id: mode2}));
        final encodedMode1:Int = languageIdCodec.encodeLanguageId(mode1);
        final encodedMode2:Int = languageIdCodec.encodeLanguageId(mode2);

        final otherMetadata1 = (
            (encodedMode1 << MetadataConsts.LANGUAGEID_OFFSET)
            | (StandardTokenType.Other << MetadataConsts.TOKEN_TYPE_OFFSET)
            | (MetadataConsts.BALANCED_BRACKETS_MASK)
        );
        final otherMetadata2 = (
            (encodedMode2 << MetadataConsts.LANGUAGEID_OFFSET)
            | (StandardTokenType.Other << MetadataConsts.TOKEN_TYPE_OFFSET)
            | (MetadataConsts.BALANCED_BRACKETS_MASK)
        );

        final tokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                switch (line) {
                    case 'function f() {':
                        final tokens = UInt32Arrays.fromInts([
                            0, otherMetadata1,
                            8, otherMetadata1,
                            9, otherMetadata1,
                            10, otherMetadata1,
                            11, otherMetadata1,
                            12, otherMetadata1,
                            13, otherMetadata1,
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                    case '  return <p>{true}</p>;':
                        final tokens = UInt32Arrays.fromInts([
                            0, otherMetadata1,
                            2, otherMetadata1,
                            8, otherMetadata1,
                            9, otherMetadata2,
                            10, otherMetadata2,
                            11, otherMetadata2,
                            12, otherMetadata2,
                            13, otherMetadata1,
                            17, otherMetadata2,
                            18, otherMetadata2,
                            20, otherMetadata2,
                            21, otherMetadata2,
                            22, otherMetadata2,
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                    case '}':
                        final tokens = UInt32Arrays.fromInts([
                            0, otherMetadata1
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                }
                throw 'Unexpected';
            }
        );

        disposables.add(context.tokenizationRegistry.register(mode1, tokenizationSupport));
        disposables.add(languageConfigurationService.register(mode1, {
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')']
            ],
        }));
        disposables.add(languageConfigurationService.register(mode2, {
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')']
            ],
        }));

        final model = TestTextModel.instantiateTextModel(
            context,
            [
                'function f() {',
                '  return <p>{true}</p>;',
                '}',
            ].join('\n'),
            mode1
        );
        disposables.add(Lifecycle.toDisposable(() -> model.dispose()));

        model.tokenization.forceTokenization(1);
        model.tokenization.forceTokenization(2);
        model.tokenization.forceTokenization(3);

        final actual = model.bracketPairs.matchBracket(new Position(2, 14));
        assertDeepEquals(
            [new Range(2, 13, 2, 14).toString(), new Range(2, 18, 2, 19).toString()],
            actual == null ? null : [for (r in actual) r.toString()]
        );

        disposables.dispose();
    }

    function testIssue88075TypeScriptBraceMatchingIsIncorrectInStrings() {
        final disposables = new DisposableStore();
        final context = new Cityscape();
        final languageConfigurationService = context.languageConfigurationService;
        final mode = 'testMode';

        final languageIdCodec = context.languageService.languageIdCodec;

        final encodedMode:Int = languageIdCodec.encodeLanguageId(mode);

        final otherMetadata = (
            (encodedMode << MetadataConsts.LANGUAGEID_OFFSET)
            | (StandardTokenType.Other << MetadataConsts.TOKEN_TYPE_OFFSET)
        );
        final stringMetadata = (
            (encodedMode << MetadataConsts.LANGUAGEID_OFFSET)
            | (StandardTokenType.String << MetadataConsts.TOKEN_TYPE_OFFSET)
        );

        final tokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> {
                switch (line) {
                    case 'function hello() {':
                        final tokens = UInt32Arrays.fromInts([
                            0, otherMetadata
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                    case "    console.log(`${100}`);":
                        final tokens = UInt32Arrays.fromInts([
                            0, otherMetadata,
                            16, stringMetadata,
                            19, otherMetadata,
                            22, stringMetadata,
                            24, otherMetadata,
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                    case '}':
                        final tokens = UInt32Arrays.fromInts([
                            0, otherMetadata
                        ]);
                        return new EncodedTokenizationResult(tokens, state);
                }
                throw 'Unexpected';
            }
        );

        disposables.add(context.tokenizationRegistry.register(mode, tokenizationSupport));
        disposables.add(languageConfigurationService.register(mode, {
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')']
            ],
        }));

        final model = TestTextModel.instantiateTextModel(
            context,
            [
                'function hello() {',
                "    console.log(`${100}`);",
                '}'
            ].join('\n'),
            mode
        );
        disposables.add(Lifecycle.toDisposable(() -> model.dispose()));

        model.tokenization.forceTokenization(1);
        model.tokenization.forceTokenization(2);
        model.tokenization.forceTokenization(3);

        assertNull(model.bracketPairs.matchBracket(new Position(2, 23)));
        assertNull(model.bracketPairs.matchBracket(new Position(2, 20)));

        disposables.dispose();
    }

    // suite('TextModelWithTokens regression tests'), the bracket tests

    function testMonacoEditor133ErrorCannotReadPropertyModeIdOfUndefined() {
        final disposables = new DisposableStore();
        final model = createTextModelWithBrackets(
            disposables,
            [
                'Imports System',
                'Imports System.Collections.Generic',
                '',
                'Module m1',
                '',
                '\tSub Main()',
                '\tEnd Sub',
                '',
                'End Module',
            ].join('\n'),
            [
                ['module', 'end module'],
                ['sub', 'end sub']
            ]
        );

        final actual = model.bracketPairs.matchBracket(new Position(4, 1));
        assertDeepEquals([new Range(4, 1, 4, 7).toString(), new Range(9, 1, 9, 11).toString()], actual == null ? null : [for (r in actual) r.toString()]);

        disposables.dispose();
    }

    function testIssue11856BracketMatchingDoesNotWorkAsExpectedIfTheOpeningBraceSymbolIsContainedInTheClosingBraceSymbol() {
        final disposables = new DisposableStore();
        final model = createTextModelWithBrackets(
            disposables,
            [
                'sequence "outer"',
                '     sequence "inner"',
                '     endsequence',
                'endsequence',
            ].join('\n'),
            [
                ['sequence', 'endsequence'],
                ['feature', 'endfeature']
            ]
        );

        final actual = model.bracketPairs.matchBracket(new Position(3, 9));
        assertDeepEquals([new Range(2, 6, 2, 14).toString(), new Range(3, 6, 3, 17).toString()], actual == null ? null : [for (r in actual) r.toString()]);

        disposables.dispose();
    }

}
