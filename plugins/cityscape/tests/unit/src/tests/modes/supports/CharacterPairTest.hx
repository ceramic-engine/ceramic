// Ported from vscode src/vs/editor/test/common/modes/supports/characterPair.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.supports.CharacterPair;
import haxe.PosInfos;
import testing.ModesTestUtils;
import testing.TestCase;

/**
 * suite('CharacterPairSupport')
 *
 * `assert.deepStrictEqual` on `StandardAutoClosingPairConditional` instances
 * compares `open`, `close` and the answer of `isOK` for every token type
 * (the private fields).
 */
class CharacterPairTest extends TestCase {

    function assertPairsEqual(expected:Array<StandardAutoClosingPairConditional>, actual:Array<Any>, ?pos:PosInfos) {
        assertEquals(expected.length, actual.length, 'length', pos);
        for (i in 0...expected.length) {
            final e = expected[i];
            assertTrue(Std.isOfType(actual[i], StandardAutoClosingPairConditional), 'class', pos);
            final a:StandardAutoClosingPairConditional = cast actual[i];
            assertEquals(e.open, a.open, 'open', pos);
            assertEquals(e.close, a.close, 'close', pos);
            for (type in [StandardTokenType.Other, StandardTokenType.Comment, StandardTokenType.String, StandardTokenType.RegEx]) {
                assertEquals(e.isOK(type), a.isOK(type), 'isOK', pos);
            }
        }
    }

    function testOnlyAutoClosingPairs() {
        final characaterPairSupport = new CharacterPairSupport({autoClosingPairs: [{open: 'a', close: 'b'}]});
        assertPairsEqual([new StandardAutoClosingPairConditional({open: 'a', close: 'b'})], cast characaterPairSupport.getAutoClosingPairs());
        assertPairsEqual([new StandardAutoClosingPairConditional({open: 'a', close: 'b'})], cast characaterPairSupport.getSurroundingPairs());
    }

    function testOnlyEmptyAutoClosingPairs() {
        final characaterPairSupport = new CharacterPairSupport({autoClosingPairs: []});
        assertDeepEquals(characaterPairSupport.getAutoClosingPairs(), []);
        assertDeepEquals(characaterPairSupport.getSurroundingPairs(), []);
    }

    function testOnlyBrackets() {
        final characaterPairSupport = new CharacterPairSupport({brackets: [['a', 'b']]});
        assertPairsEqual([new StandardAutoClosingPairConditional({open: 'a', close: 'b'})], cast characaterPairSupport.getAutoClosingPairs());
        assertPairsEqual([new StandardAutoClosingPairConditional({open: 'a', close: 'b'})], cast characaterPairSupport.getSurroundingPairs());
    }

    function testOnlyEmptyBrackets() {
        final characaterPairSupport = new CharacterPairSupport({brackets: []});
        assertDeepEquals(characaterPairSupport.getAutoClosingPairs(), []);
        assertDeepEquals(characaterPairSupport.getSurroundingPairs(), []);
    }

    function testOnlySurroundingPairs() {
        final characaterPairSupport = new CharacterPairSupport({surroundingPairs: [{open: 'a', close: 'b'}]});
        assertDeepEquals(characaterPairSupport.getAutoClosingPairs(), []);
        assertDeepEquals(characaterPairSupport.getSurroundingPairs(), [{open: 'a', close: 'b'}]);
    }

    function testOnlyEmptySurroundingPairs() {
        final characaterPairSupport = new CharacterPairSupport({surroundingPairs: []});
        assertDeepEquals(characaterPairSupport.getAutoClosingPairs(), []);
        assertDeepEquals(characaterPairSupport.getSurroundingPairs(), []);
    }

    function testBracketsIsIgnoredWhenHavingAutoClosingPairs() {
        final characaterPairSupport = new CharacterPairSupport({autoClosingPairs: [], brackets: [['a', 'b']]});
        assertDeepEquals(characaterPairSupport.getAutoClosingPairs(), []);
        assertDeepEquals(characaterPairSupport.getSurroundingPairs(), []);
    }

    function shouldAutoCloseHelper(characterPairSupport:CharacterPairSupport, line:Array<TokenText>, column:Int):Bool {
        final autoClosingPair = characterPairSupport.getAutoClosingPairs()[0];
        return autoClosingPair.shouldAutoClose(ModesTestUtils.createFakeScopedLineTokens(line), column);
    }

    function testShouldAutoClosePairInEmptyLine() {
        final sup = new CharacterPairSupport({autoClosingPairs: [{open: '{', close: '}', notIn: ['string', 'comment']}]});
        final tokenText:Array<TokenText> = [];
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 1), true);
    }

    function testShouldAutoClosePairInNotInterestingLine1() {
        final sup = new CharacterPairSupport({autoClosingPairs: [{open: '{', close: '}', notIn: ['string', 'comment']}]});
        final tokenText:Array<TokenText> = [
            {text: 'do', type: StandardTokenType.Other}
        ];
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 3), true);
    }

    function testShouldAutoClosePairInNotInterestingLine2() {
        final sup = new CharacterPairSupport({autoClosingPairs: [{open: '{', close: '}'}]});
        final tokenText:Array<TokenText> = [
            {text: 'do', type: StandardTokenType.String}
        ];
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 3), true);
    }

    function testShouldAutoClosePairInInterestingLine1() {
        final sup = new CharacterPairSupport({autoClosingPairs: [{open: '{', close: '}', notIn: ['string', 'comment']}]});
        final tokenText:Array<TokenText> = [
            {text: '"a"', type: StandardTokenType.String}
        ];
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 1), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 2), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 3), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 4), false);
    }

    function testShouldAutoClosePairInInterestingLine2() {
        final sup = new CharacterPairSupport({autoClosingPairs: [{open: '{', close: '}', notIn: ['string', 'comment']}]});
        final tokenText:Array<TokenText> = [
            {text: 'x=', type: StandardTokenType.Other},
            {text: '"a"', type: StandardTokenType.String},
            {text: ';', type: StandardTokenType.Other}
        ];
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 1), true);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 2), true);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 3), true);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 4), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 5), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 6), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 7), true);
    }

    function testShouldAutoClosePairInInterestingLine3() {
        final sup = new CharacterPairSupport({autoClosingPairs: [{open: '{', close: '}', notIn: ['string', 'comment']}]});
        final tokenText:Array<TokenText> = [
            {text: ' ', type: StandardTokenType.Other},
            {text: '//a', type: StandardTokenType.Comment}
        ];
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 1), true);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 2), true);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 3), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 4), false);
        assertEquals(shouldAutoCloseHelper(sup, tokenText, 5), false);
    }

}
