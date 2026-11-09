// Ported from vscode src/vs/editor/test/common/modes/supports/richEditBrackets.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.base.common.RegExp;
import cityscape.common.core.Range;
import cityscape.common.languages.supports.RichEditBrackets;
import testing.TestCase;

/**
 * suite('richEditBrackets')
 */
class RichEditBracketsTest extends TestCase {

    function findPrevBracketInRange(reversedBracketRegex:RegExp, lineText:String, currentTokenStart:Int, currentTokenEnd:Int):Null<Range> {
        return BracketsUtils.findPrevBracketInRange(reversedBracketRegex, 1, lineText, currentTokenStart, currentTokenEnd);
    }

    function findNextBracketInRange(forwardBracketRegex:RegExp, lineText:String, currentTokenStart:Int, currentTokenEnd:Int):Null<Range> {
        return BracketsUtils.findNextBracketInRange(forwardBracketRegex, 1, lineText, currentTokenStart, currentTokenEnd);
    }

    function testFindPrevBracketInTokenOneChar1() {
        final result = findPrevBracketInRange(new RegExp("(\\{)|(\\})", "i"), '{', 0, 1);
        assertEquals(result.startColumn, 1);
        assertEquals(result.endColumn, 2);
    }

    function testFindPrevBracketInTokenOneChar2() {
        final result = findPrevBracketInRange(new RegExp("(\\{)|(\\})", "i"), '{{', 0, 1);
        assertEquals(result.startColumn, 1);
        assertEquals(result.endColumn, 2);
    }

    function testFindPrevBracketInTokenOneChar3() {
        final result = findPrevBracketInRange(new RegExp("(\\{)|(\\})", "i"), '{hello world!', 0, 13);
        assertEquals(result.startColumn, 1);
        assertEquals(result.endColumn, 2);
    }

    function testFindPrevBracketInTokenMoreChars1() {
        final result = findPrevBracketInRange(new RegExp("(olleh)", "i"), 'hello world!', 0, 12);
        assertEquals(result.startColumn, 1);
        assertEquals(result.endColumn, 6);
    }

    function testFindPrevBracketInTokenMoreChars2() {
        final result = findPrevBracketInRange(new RegExp("(olleh)", "i"), 'hello world!', 0, 5);
        assertEquals(result.startColumn, 1);
        assertEquals(result.endColumn, 6);
    }

    function testFindPrevBracketInTokenMoreChars3() {
        final result = findPrevBracketInRange(new RegExp("(olleh)", "i"), ' hello world!', 0, 6);
        assertEquals(result.startColumn, 2);
        assertEquals(result.endColumn, 7);
    }

    function testFindNextBracketInTokenOneChar() {
        final result = findNextBracketInRange(new RegExp("(\\{)|(\\})", "i"), '{', 0, 1);
        assertEquals(result.startColumn, 1);
        assertEquals(result.endColumn, 2);
    }

    function testFindNextBracketInTokenMoreChars() {
        final result = findNextBracketInRange(new RegExp("(world)", "i"), 'hello world!', 0, 12);
        assertEquals(result.startColumn, 7);
        assertEquals(result.endColumn, 12);
    }

    function testFindNextBracketInTokenWithEmotyResult() {
        final result = findNextBracketInRange(new RegExp("(\\{)|(\\})", "i"), '', 0, 0);
        assertEquals(result, null);
    }

    function testIssue3894HandlebarsCurlyBracesEditIssues() {
        final result = findPrevBracketInRange(new RegExp("(\\-\\-!<)|(>\\-\\-)|(\\{\\{)|(\\}\\})", "i"), '{{asd}}', 0, 2);
        assertEquals(result.startColumn, 1);
        assertEquals(result.endColumn, 3);
    }

}
