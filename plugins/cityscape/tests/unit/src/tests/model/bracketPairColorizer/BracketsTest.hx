// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/brackets.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;

import cityscape.base.common.Lifecycle;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Brackets;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Tokenizer;
import testing.TestCase;
import testing.TestLanguageConfigurationService;

private typedef ExpectedToken = {
    final text:String;
    final length:Int;
    final kind:String;
    final bracketId:Int;
    final bracketIds:SmallImmutableSet<Int>;
}

/**
 * suite('Bracket Pair Colorizer - Brackets')
 *
 * `assert.deepStrictEqual` compares each field: the length as a number
 * (`toLength(0, length)`), the sets with `equals`.
 */
class BracketsTest extends TestCase {

    function testBasic() {
        final languageId = 'testMode1';
        final denseKeyProvider = new DenseKeyProvider<String>();
        final getImmutableSet = (elements:Array<String>) -> {
            var newSet:SmallImmutableSet<String> = SmallImmutableSet.getEmpty();
            for (x in elements) {
                newSet = newSet.add(languageId + ':::' + x, denseKeyProvider);
            }
            final result:SmallImmutableSet<Int> = cast newSet;
            return result;
        };
        final getKey = (value:String) -> {
            return denseKeyProvider.getKey(languageId + ':::' + value);
        };

        final disposableStore = new DisposableStore();
        final languageConfigService = disposableStore.add(new TestLanguageConfigurationService());
        disposableStore.add(languageConfigService.register(languageId, {
            brackets: [
                ['{', '}'], ['[', ']'], ['(', ')'],
                ['begin', 'end'], ['case', 'endcase'], ['casez', 'endcase'], // Verilog
                ['\\left(', '\\right)'], ['\\left(', '\\right.'], ['\\left.', '\\right)'], // LaTeX Parentheses
                ['\\left[', '\\right]'], ['\\left[', '\\right.'], ['\\left.', '\\right]'] // LaTeX Brackets
            ]
        }));

        final brackets = new LanguageAgnosticBracketTokens(denseKeyProvider, l -> languageConfigService.getLanguageConfiguration(l));
        final bracketsExpected:Array<ExpectedToken> = [
            {text: '{', length: 1, kind: 'OpeningBracket', bracketId: getKey('{'), bracketIds: getImmutableSet(['{'])},
            {text: '[', length: 1, kind: 'OpeningBracket', bracketId: getKey('['), bracketIds: getImmutableSet(['['])},
            {text: '(', length: 1, kind: 'OpeningBracket', bracketId: getKey('('), bracketIds: getImmutableSet(['('])},
            {text: 'begin', length: 5, kind: 'OpeningBracket', bracketId: getKey('begin'), bracketIds: getImmutableSet(['begin'])},
            {text: 'case', length: 4, kind: 'OpeningBracket', bracketId: getKey('case'), bracketIds: getImmutableSet(['case'])},
            {text: 'casez', length: 5, kind: 'OpeningBracket', bracketId: getKey('casez'), bracketIds: getImmutableSet(['casez'])},
            {text: '\\left(', length: 6, kind: 'OpeningBracket', bracketId: getKey('\\left('), bracketIds: getImmutableSet(['\\left('])},
            {text: '\\left.', length: 6, kind: 'OpeningBracket', bracketId: getKey('\\left.'), bracketIds: getImmutableSet(['\\left.'])},
            {text: '\\left[', length: 6, kind: 'OpeningBracket', bracketId: getKey('\\left['), bracketIds: getImmutableSet(['\\left['])},

            {text: '}', length: 1, kind: 'ClosingBracket', bracketId: getKey('{'), bracketIds: getImmutableSet(['{'])},
            {text: ']', length: 1, kind: 'ClosingBracket', bracketId: getKey('['), bracketIds: getImmutableSet(['['])},
            {text: ')', length: 1, kind: 'ClosingBracket', bracketId: getKey('('), bracketIds: getImmutableSet(['('])},
            {text: 'end', length: 3, kind: 'ClosingBracket', bracketId: getKey('begin'), bracketIds: getImmutableSet(['begin'])},
            {text: 'endcase', length: 7, kind: 'ClosingBracket', bracketId: getKey('case'), bracketIds: getImmutableSet(['case', 'casez'])},
            {text: '\\right)', length: 7, kind: 'ClosingBracket', bracketId: getKey('\\left('), bracketIds: getImmutableSet(['\\left(', '\\left.'])},
            {text: '\\right.', length: 7, kind: 'ClosingBracket', bracketId: getKey('\\left('), bracketIds: getImmutableSet(['\\left(', '\\left['])},
            {text: '\\right]', length: 7, kind: 'ClosingBracket', bracketId: getKey('\\left['), bracketIds: getImmutableSet(['\\left[', '\\left.'])}
        ];

        for (x in bracketsExpected) {
            final token = brackets.getToken(x.text, languageId);
            assertNotNull(token, x.text);
            if (token == null) {
                continue;
            }
            assertTrue(Length.lengthEquals(token.length, Length.toLength(0, x.length)), x.text + ' length');
            assertEquals(x.kind, kindToString(token.kind), x.text + ' kind');
            assertEquals(x.bracketId, token.bracketId, x.text + ' bracketId');
            assertTrue(x.bracketIds.equals(token.bracketIds), x.text + ' bracketIds');
        }

        disposableStore.dispose();
    }

    static function kindToString(kind:TokenKind):String {
        return switch (kind) {
            case TokenKind.ClosingBracket: 'ClosingBracket';
            case TokenKind.OpeningBracket: 'OpeningBracket';
            case TokenKind.Text: 'Text';
            case _: null;
        }
    }

    /**
     * Types the helpers of the tests that need a text model (tokenizer.test.ts,
     * combineTextEditInfos.test.ts), so that they keep compiling.
     */
    static function _typeHelpers():Array<Any> {
        return [
            new tests.model.bracketPairColorizer.TokenizerTest.TokenizedDocument([]).getTokenizationSupport(),
            testing.Random.create(0).nextString(3),
        ];
    }

}
