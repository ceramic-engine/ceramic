// Ported from vscode src/vs/editor/test/common/model/model.line.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - ModelLineGetIndentLevelTest
//
// Not ported: suite('ModelLinesTokens') with all its tests ('single delete 1' to 'append 3'): they need tokens
// (a tokenization support registered in TokenizationRegistry, LineTokens, ContiguousMultilineTokensBuilder,
// model.tokenization.getLineTokens).

import cityscape.common.model.Utils.computeIndentLevel;
import testing.TestCase;

/**
 * suite('ModelLine - getIndentLevel')
 */
class ModelLineGetIndentLevelTest extends TestCase {

    function assertIndentLevel(text:String, expected:Int, tabSize:Int = 4):Void {
        final actual = computeIndentLevel(text, tabSize);
        assertEquals(actual, expected, text);
    }

    function testGetIndentLevel() {
        assertIndentLevel('', -1);
        assertIndentLevel(' ', -1);
        assertIndentLevel('   \t', -1);
        assertIndentLevel('Hello', 0);
        assertIndentLevel(' Hello', 1);
        assertIndentLevel('   Hello', 3);
        assertIndentLevel('\tHello', 4);
        assertIndentLevel(' \tHello', 4);
        assertIndentLevel('  \tHello', 4);
        assertIndentLevel('   \tHello', 4);
        assertIndentLevel('    \tHello', 8);
        assertIndentLevel('     \tHello', 8);
        assertIndentLevel('\t Hello', 5);
        assertIndentLevel('\t \tHello', 8);
    }

}
