// Ported from vscode src/vs/editor/test/common/model/pieceTreeTextBuffer/pieceTreeTextBuffer.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.pieceTreeTextBuffer;

// Classes of this module (register every one of them except PieceTreeTextBufferTestBase,
// which only holds the shared helpers of the test file and has no test method):
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.InsertsAndDeletesTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.PrefixSumForLineFeedTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.Offset2PositionTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.GetTextInRangeTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.CRLFTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.CentralizedLineStartsWithCRLFTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.RandomIsUnsupervisedTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.BufferApiTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.SearchOffsetCacheTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.SnapshotTest
//   tests.model.pieceTreeTextBuffer.PieceTreeTextBufferTest.ChunkBasedSearchTest

import cityscape.base.common.RegExp;
import cityscape.base.common.Strings.splitLines;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.WordCharacterClassifier;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeBase;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeTextBuffer;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeTextBufferBuilder;
import cityscape.common.model.pieceTreeTextBuffer.RbTreeBase;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

/**
 * Shared helpers of pieceTreeTextBuffer.test.ts (module level functions in vscode).
 * Not a suite: it has no test method.
 */
class PieceTreeTextBufferTestBase extends TestCase {

    static final alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n';

    static function randomChar():String {
        return alphabet.charAt(PieceTreeTextBufferTestBase.randomInt(alphabet.length));
    }

    static function randomInt(bound:Int):Int {
        return Math.floor(Math.random() * bound);
    }

    static function randomStr(len:Null<Int>):String {
        if (len == null) {
            len = 10;
        }
        final results:Array<String> = [];
        final ref:Int = len;
        var j = 1;
        while (1 <= ref ? j < ref : j > ref) {
            results.push(PieceTreeTextBufferTestBase.randomChar());
            if (1 <= ref) {
                j++;
            }
            else {
                j--;
            }
        }
        return results.join('');
    }

    static function trimLineFeed(text:String):String {
        if (text.length == 0) {
            return text;
        }

        if (text.length == 1) {
            if (
                StringTools.fastCodeAt(text, text.length - 1) == 10 ||
                StringTools.fastCodeAt(text, text.length - 1) == 13
            ) {
                return '';
            }
            return text;
        }

        if (StringTools.fastCodeAt(text, text.length - 1) == 10) {
            if (StringTools.fastCodeAt(text, text.length - 2) == 13) {
                return text.substring(0, text.length - 2);
            }
            return text.substring(0, text.length - 1);
        }

        if (StringTools.fastCodeAt(text, text.length - 1) == 13) {
            return text.substring(0, text.length - 1);
        }

        return text;
    }

    //#region Assertion

    function _testLinesContent(str:String, pieceTable:PieceTreeBase):Void {
        final lines = splitLines(str);
        assertEquals(pieceTable.getLineCount(), lines.length);
        assertEquals(pieceTable.getLinesRawContent(), str);
        for (i in 0...lines.length) {
            assertEquals(pieceTable.getLineContent(i + 1), lines[i]);
            assertEquals(
                PieceTreeTextBufferTestBase.trimLineFeed(
                    pieceTable.getValueInRange(
                        new Range(
                            i + 1,
                            1,
                            i + 1,
                            lines[i].length + (i == lines.length - 1 ? 1 : 2)
                        )
                    )
                ),
                lines[i]
            );
        }
    }

    function _testLineStarts(str:String, pieceTable:PieceTreeBase):Void {
        final lineStarts = [0];

        // Reset regex to search from the beginning
        final _regex = new RegExp('\\r\\n|\\r|\\n', 'g');
        _regex.lastIndex = 0;
        var prevMatchStartIndex = -1;
        var prevMatchLength = 0;

        var m:Null<RegExpExecArray> = null;
        do {
            if (prevMatchStartIndex + prevMatchLength == str.length) {
                // Reached the end of the line
                break;
            }

            m = _regex.exec(str);
            if (m == null) {
                break;
            }

            final matchStartIndex = m.index;
            final matchLength = m[0].length;

            if (
                matchStartIndex == prevMatchStartIndex &&
                matchLength == prevMatchLength
            ) {
                // Exit early if the regex matches the same range twice
                break;
            }

            prevMatchStartIndex = matchStartIndex;
            prevMatchLength = matchLength;

            lineStarts.push(matchStartIndex + matchLength);
        } while (m != null);

        for (i in 0...lineStarts.length) {
            assertDeepEquals(
                pieceTable.getPositionAt(lineStarts[i]),
                new Position(i + 1, 1)
            );
            assertEquals(pieceTable.getOffsetAt(i + 1, 1), lineStarts[i]);
        }

        for (i in 1...lineStarts.length) {
            final pos = pieceTable.getPositionAt(lineStarts[i] - 1);
            assertEquals(
                pieceTable.getOffsetAt(pos.lineNumber, pos.column),
                lineStarts[i] - 1
            );
        }
    }

    static function createTextBuffer(val:Array<String>, normalizeEOL:Bool = true):PieceTreeTextBuffer {
        final bufferBuilder = new PieceTreeTextBufferBuilder();
        for (chunk in val) {
            bufferBuilder.acceptChunk(chunk);
        }
        final factory = bufferBuilder.finishWithNormalizeEOL(normalizeEOL);
        return (cast factory.create(DefaultEndOfLine.LF).textBuffer : PieceTreeTextBuffer);
    }

    function assertTreeInvariants(T:PieceTreeBase):Void {
        final SENTINEL = T.SENTINEL;
        assertTrue(SENTINEL.color == NodeColor.Black);
        assertTrue(SENTINEL.parent == SENTINEL);
        assertTrue(SENTINEL.left == SENTINEL);
        assertTrue(SENTINEL.right == SENTINEL);
        assertTrue(SENTINEL.size_left == 0);
        assertTrue(SENTINEL.lf_left == 0);
        assertValidTree(T);
    }

    function depth(n:TreeNode, SENTINEL:TreeNode):Int {
        if (n == SENTINEL) {
            // The leafs are black
            return 1;
        }
        assertTrue(depth(n.left, SENTINEL) == depth(n.right, SENTINEL));
        return (n.color == NodeColor.Black ? 1 : 0) + depth(n.left, SENTINEL);
    }

    function assertValidNode(n:TreeNode, SENTINEL:TreeNode):{size:Int, lf_cnt:Int} {
        if (n == SENTINEL) {
            return {size: 0, lf_cnt: 0};
        }

        final l = n.left;
        final r = n.right;

        if (n.color == NodeColor.Red) {
            assertTrue(l.color == NodeColor.Black);
            assertTrue(r.color == NodeColor.Black);
        }

        final actualLeft = assertValidNode(l, SENTINEL);
        assertTrue(actualLeft.lf_cnt == n.lf_left);
        assertTrue(actualLeft.size == n.size_left);
        final actualRight = assertValidNode(r, SENTINEL);

        return {size: n.size_left + n.piece.length + actualRight.size, lf_cnt: n.lf_left + n.piece.lineFeedCnt + actualRight.lf_cnt};
    }

    function assertValidTree(T:PieceTreeBase):Void {
        final SENTINEL = T.SENTINEL;
        if (T.root == SENTINEL) {
            return;
        }
        assertTrue(T.root.color == NodeColor.Black);
        assertTrue(depth(T.root.left, SENTINEL) == depth(T.root.right, SENTINEL));
        assertValidNode(T.root, SENTINEL);
    }

    //#endregion

    static function getValueInSnapshot(snapshot:ITextSnapshot):String {
        var ret = '';
        var tmp = snapshot.read();

        while (tmp != null) {
            ret += tmp;
            tmp = snapshot.read();
        }

        return ret;
    }

}

/** suite('inserts and deletes') */
class InsertsAndDeletesTest extends PieceTreeTextBufferTestBase {

    // test('basic insert/delete')
    function testBasicInsertDelete() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([
            'This is a document with some text.'
        ]);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(34, 'This is some more text to insert at offset 34.');
        assertEquals(
            pieceTable.getLinesRawContent(),
            'This is a document with some text.This is some more text to insert at offset 34.'
        );
        pieceTable.delete(42, 5);
        assertEquals(
            pieceTable.getLinesRawContent(),
            'This is a document with some text.This is more text to insert at offset 34.'
        );
        assertTreeInvariants(pieceTable);
    }

    // test('more inserts')
    function testMoreInserts() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pt = pieceTree.getPieceTree();
        pt.insert(0, 'AAA');
        assertEquals(pt.getLinesRawContent(), 'AAA');
        pt.insert(0, 'BBB');
        assertEquals(pt.getLinesRawContent(), 'BBBAAA');
        pt.insert(6, 'CCC');
        assertEquals(pt.getLinesRawContent(), 'BBBAAACCC');
        pt.insert(5, 'DDD');
        assertEquals(pt.getLinesRawContent(), 'BBBAADDDACCC');
        assertTreeInvariants(pt);
    }

    // test('more deletes')
    function testMoreDeletes() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['012345678']);
        final pt = pieceTree.getPieceTree();

        pt.delete(8, 1);
        assertEquals(pt.getLinesRawContent(), '01234567');
        pt.delete(0, 1);
        assertEquals(pt.getLinesRawContent(), '1234567');
        pt.delete(5, 1);
        assertEquals(pt.getLinesRawContent(), '123457');
        pt.delete(5, 1);
        assertEquals(pt.getLinesRawContent(), '12345');
        pt.delete(0, 5);
        assertEquals(pt.getLinesRawContent(), '');
        assertTreeInvariants(pt);
    }

    // test('random test 1')
    function testRandomTest1() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'ceLPHmFzvCtFeHkCBej ');
        str = str.substring(0, 0) + 'ceLPHmFzvCtFeHkCBej ' + str.substring(0);
        assertEquals(pieceTable.getLinesRawContent(), str);
        pieceTable.insert(8, 'gDCEfNYiBUNkSwtvB K ');
        str = str.substring(0, 8) + 'gDCEfNYiBUNkSwtvB K ' + str.substring(8);
        assertEquals(pieceTable.getLinesRawContent(), str);
        pieceTable.insert(38, 'cyNcHxjNPPoehBJldLS ');
        str = str.substring(0, 38) + 'cyNcHxjNPPoehBJldLS ' + str.substring(38);
        assertEquals(pieceTable.getLinesRawContent(), str);
        pieceTable.insert(59, 'ejMx\nOTgWlbpeDExjOk ');
        str = str.substring(0, 59) + 'ejMx\nOTgWlbpeDExjOk ' + str.substring(59);

        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random test 2')
    function testRandomTest2() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'VgPG ');
        str = str.substring(0, 0) + 'VgPG ' + str.substring(0);
        pieceTable.insert(2, 'DdWF ');
        str = str.substring(0, 2) + 'DdWF ' + str.substring(2);
        pieceTable.insert(0, 'hUJc ');
        str = str.substring(0, 0) + 'hUJc ' + str.substring(0);
        pieceTable.insert(8, 'lQEq ');
        str = str.substring(0, 8) + 'lQEq ' + str.substring(8);
        pieceTable.insert(10, 'Gbtp ');
        str = str.substring(0, 10) + 'Gbtp ' + str.substring(10);

        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random test 3')
    function testRandomTest3() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'gYSz');
        str = str.substring(0, 0) + 'gYSz' + str.substring(0);
        pieceTable.insert(1, 'mDQe');
        str = str.substring(0, 1) + 'mDQe' + str.substring(1);
        pieceTable.insert(1, 'DTMQ');
        str = str.substring(0, 1) + 'DTMQ' + str.substring(1);
        pieceTable.insert(2, 'GGZB');
        str = str.substring(0, 2) + 'GGZB' + str.substring(2);
        pieceTable.insert(12, 'wXpq');
        str = str.substring(0, 12) + 'wXpq' + str.substring(12);
        assertEquals(pieceTable.getLinesRawContent(), str);
    }

    // test('random delete 1')
    function testRandomDelete1() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'vfb');
        str = str.substring(0, 0) + 'vfb' + str.substring(0);
        assertEquals(pieceTable.getLinesRawContent(), str);
        pieceTable.insert(0, 'zRq');
        str = str.substring(0, 0) + 'zRq' + str.substring(0);
        assertEquals(pieceTable.getLinesRawContent(), str);

        pieceTable.delete(5, 1);
        str = str.substring(0, 5) + str.substring(5 + 1);
        assertEquals(pieceTable.getLinesRawContent(), str);

        pieceTable.insert(1, 'UNw');
        str = str.substring(0, 1) + 'UNw' + str.substring(1);
        assertEquals(pieceTable.getLinesRawContent(), str);

        pieceTable.delete(4, 3);
        str = str.substring(0, 4) + str.substring(4 + 3);
        assertEquals(pieceTable.getLinesRawContent(), str);

        pieceTable.delete(1, 4);
        str = str.substring(0, 1) + str.substring(1 + 4);
        assertEquals(pieceTable.getLinesRawContent(), str);

        pieceTable.delete(0, 1);
        str = str.substring(0, 0) + str.substring(0 + 1);
        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random delete 2')
    function testRandomDelete2() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'IDT');
        str = str.substring(0, 0) + 'IDT' + str.substring(0);
        pieceTable.insert(3, 'wwA');
        str = str.substring(0, 3) + 'wwA' + str.substring(3);
        pieceTable.insert(3, 'Gnr');
        str = str.substring(0, 3) + 'Gnr' + str.substring(3);
        pieceTable.delete(6, 3);
        str = str.substring(0, 6) + str.substring(6 + 3);
        pieceTable.insert(4, 'eHp');
        str = str.substring(0, 4) + 'eHp' + str.substring(4);
        pieceTable.insert(1, 'UAi');
        str = str.substring(0, 1) + 'UAi' + str.substring(1);
        pieceTable.insert(2, 'FrR');
        str = str.substring(0, 2) + 'FrR' + str.substring(2);
        pieceTable.delete(6, 7);
        str = str.substring(0, 6) + str.substring(6 + 7);
        pieceTable.delete(3, 5);
        str = str.substring(0, 3) + str.substring(3 + 5);
        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random delete 3')
    function testRandomDelete3() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'PqM');
        str = str.substring(0, 0) + 'PqM' + str.substring(0);
        pieceTable.delete(1, 2);
        str = str.substring(0, 1) + str.substring(1 + 2);
        pieceTable.insert(1, 'zLc');
        str = str.substring(0, 1) + 'zLc' + str.substring(1);
        pieceTable.insert(0, 'MEX');
        str = str.substring(0, 0) + 'MEX' + str.substring(0);
        pieceTable.insert(0, 'jZh');
        str = str.substring(0, 0) + 'jZh' + str.substring(0);
        pieceTable.insert(8, 'GwQ');
        str = str.substring(0, 8) + 'GwQ' + str.substring(8);
        pieceTable.delete(5, 6);
        str = str.substring(0, 5) + str.substring(5 + 6);
        pieceTable.insert(4, 'ktw');
        str = str.substring(0, 4) + 'ktw' + str.substring(4);
        pieceTable.insert(5, 'GVu');
        str = str.substring(0, 5) + 'GVu' + str.substring(5);
        pieceTable.insert(9, 'jdm');
        str = str.substring(0, 9) + 'jdm' + str.substring(9);
        pieceTable.insert(15, 'na\n');
        str = str.substring(0, 15) + 'na\n' + str.substring(15);
        pieceTable.delete(5, 8);
        str = str.substring(0, 5) + str.substring(5 + 8);
        pieceTable.delete(3, 4);
        str = str.substring(0, 3) + str.substring(3 + 4);
        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random insert/delete \r bug 1')
    function testRandomInsertDeleteRBug1() {
        var str = 'a';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.delete(0, 1);
        str = str.substring(0, 0) + str.substring(0 + 1);
        pieceTable.insert(0, '\r\r\n\n');
        str = str.substring(0, 0) + '\r\r\n\n' + str.substring(0);
        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.insert(2, '\n\n\ra');
        str = str.substring(0, 2) + '\n\n\ra' + str.substring(2);
        pieceTable.delete(4, 3);
        str = str.substring(0, 4) + str.substring(4 + 3);
        pieceTable.insert(2, '\na\r\r');
        str = str.substring(0, 2) + '\na\r\r' + str.substring(2);
        pieceTable.insert(6, '\ra\n\n');
        str = str.substring(0, 6) + '\ra\n\n' + str.substring(6);
        pieceTable.insert(0, 'aa\n\n');
        str = str.substring(0, 0) + 'aa\n\n' + str.substring(0);
        pieceTable.insert(5, '\n\na\r');
        str = str.substring(0, 5) + '\n\na\r' + str.substring(5);

        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random insert/delete \r bug 2')
    function testRandomInsertDeleteRBug2() {
        var str = 'a';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(1, '\naa\r');
        str = str.substring(0, 1) + '\naa\r' + str.substring(1);
        pieceTable.delete(0, 4);
        str = str.substring(0, 0) + str.substring(0 + 4);
        pieceTable.insert(1, '\r\r\na');
        str = str.substring(0, 1) + '\r\r\na' + str.substring(1);
        pieceTable.insert(2, '\n\r\ra');
        str = str.substring(0, 2) + '\n\r\ra' + str.substring(2);
        pieceTable.delete(4, 1);
        str = str.substring(0, 4) + str.substring(4 + 1);
        pieceTable.insert(8, '\r\n\r\r');
        str = str.substring(0, 8) + '\r\n\r\r' + str.substring(8);
        pieceTable.insert(7, '\n\n\na');
        str = str.substring(0, 7) + '\n\n\na' + str.substring(7);
        pieceTable.insert(13, 'a\n\na');
        str = str.substring(0, 13) + 'a\n\na' + str.substring(13);
        pieceTable.delete(17, 3);
        str = str.substring(0, 17) + str.substring(17 + 3);
        pieceTable.insert(2, 'a\ra\n');
        str = str.substring(0, 2) + 'a\ra\n' + str.substring(2);

        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random insert/delete \r bug 3')
    function testRandomInsertDeleteRBug3() {
        var str = 'a';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, '\r\na\r');
        str = str.substring(0, 0) + '\r\na\r' + str.substring(0);
        pieceTable.delete(2, 3);
        str = str.substring(0, 2) + str.substring(2 + 3);
        pieceTable.insert(2, 'a\r\n\r');
        str = str.substring(0, 2) + 'a\r\n\r' + str.substring(2);
        pieceTable.delete(4, 2);
        str = str.substring(0, 4) + str.substring(4 + 2);
        pieceTable.insert(4, 'a\n\r\n');
        str = str.substring(0, 4) + 'a\n\r\n' + str.substring(4);
        pieceTable.insert(1, 'aa\n\r');
        str = str.substring(0, 1) + 'aa\n\r' + str.substring(1);
        pieceTable.insert(7, '\na\r\n');
        str = str.substring(0, 7) + '\na\r\n' + str.substring(7);
        pieceTable.insert(5, '\n\na\r');
        str = str.substring(0, 5) + '\n\na\r' + str.substring(5);
        pieceTable.insert(10, '\r\r\n\r');
        str = str.substring(0, 10) + '\r\r\n\r' + str.substring(10);
        assertEquals(pieceTable.getLinesRawContent(), str);
        pieceTable.delete(21, 3);
        str = str.substring(0, 21) + str.substring(21 + 3);

        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random insert/delete \r bug 4s')
    function testRandomInsertDeleteRBug4s() {
        var str = 'a';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.delete(0, 1);
        str = str.substring(0, 0) + str.substring(0 + 1);
        pieceTable.insert(0, '\naaa');
        str = str.substring(0, 0) + '\naaa' + str.substring(0);
        pieceTable.insert(2, '\n\naa');
        str = str.substring(0, 2) + '\n\naa' + str.substring(2);
        pieceTable.delete(1, 4);
        str = str.substring(0, 1) + str.substring(1 + 4);
        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.delete(1, 2);
        str = str.substring(0, 1) + str.substring(1 + 2);
        pieceTable.delete(0, 1);
        str = str.substring(0, 0) + str.substring(0 + 1);
        pieceTable.insert(0, 'a\n\n\r');
        str = str.substring(0, 0) + 'a\n\n\r' + str.substring(0);
        pieceTable.insert(2, 'aa\r\n');
        str = str.substring(0, 2) + 'aa\r\n' + str.substring(2);
        pieceTable.insert(3, 'a\naa');
        str = str.substring(0, 3) + 'a\naa' + str.substring(3);

        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

    // test('random insert/delete \r bug 5')
    function testRandomInsertDeleteRBug5() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, '\n\n\n\r');
        str = str.substring(0, 0) + '\n\n\n\r' + str.substring(0);
        pieceTable.insert(1, '\n\n\n\r');
        str = str.substring(0, 1) + '\n\n\n\r' + str.substring(1);
        pieceTable.insert(2, '\n\r\r\r');
        str = str.substring(0, 2) + '\n\r\r\r' + str.substring(2);
        pieceTable.insert(8, '\n\r\n\r');
        str = str.substring(0, 8) + '\n\r\n\r' + str.substring(8);
        pieceTable.delete(5, 2);
        str = str.substring(0, 5) + str.substring(5 + 2);
        pieceTable.insert(4, '\n\r\r\r');
        str = str.substring(0, 4) + '\n\r\r\r' + str.substring(4);
        pieceTable.insert(8, '\n\n\n\r');
        str = str.substring(0, 8) + '\n\n\n\r' + str.substring(8);
        pieceTable.delete(0, 7);
        str = str.substring(0, 0) + str.substring(0 + 7);
        pieceTable.insert(1, '\r\n\r\r');
        str = str.substring(0, 1) + '\r\n\r\r' + str.substring(1);
        pieceTable.insert(15, '\n\r\r\r');
        str = str.substring(0, 15) + '\n\r\r\r' + str.substring(15);

        assertEquals(pieceTable.getLinesRawContent(), str);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('prefix sum for line feed') */
class PrefixSumForLineFeedTest extends PieceTreeTextBufferTestBase {

    // test('basic')
    function testBasic() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['1\n2\n3\n4']);
        final pieceTable = pieceTree.getPieceTree();

        assertEquals(pieceTable.getLineCount(), 4);
        assertDeepEquals(pieceTable.getPositionAt(0), new Position(1, 1));
        assertDeepEquals(pieceTable.getPositionAt(1), new Position(1, 2));
        assertDeepEquals(pieceTable.getPositionAt(2), new Position(2, 1));
        assertDeepEquals(pieceTable.getPositionAt(3), new Position(2, 2));
        assertDeepEquals(pieceTable.getPositionAt(4), new Position(3, 1));
        assertDeepEquals(pieceTable.getPositionAt(5), new Position(3, 2));
        assertDeepEquals(pieceTable.getPositionAt(6), new Position(4, 1));

        assertEquals(pieceTable.getOffsetAt(1, 1), 0);
        assertEquals(pieceTable.getOffsetAt(1, 2), 1);
        assertEquals(pieceTable.getOffsetAt(2, 1), 2);
        assertEquals(pieceTable.getOffsetAt(2, 2), 3);
        assertEquals(pieceTable.getOffsetAt(3, 1), 4);
        assertEquals(pieceTable.getOffsetAt(3, 2), 5);
        assertEquals(pieceTable.getOffsetAt(4, 1), 6);
        assertTreeInvariants(pieceTable);
    }

    // test('append')
    function testAppend() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\nb\nc\nde']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(8, 'fh\ni\njk');

        assertEquals(pieceTable.getLineCount(), 6);
        assertDeepEquals(pieceTable.getPositionAt(9), new Position(4, 4));
        assertEquals(pieceTable.getOffsetAt(1, 1), 0);
        assertTreeInvariants(pieceTable);
    }

    // test('insert')
    function testInsert() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\nb\nc\nde']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(7, 'fh\ni\njk');

        assertEquals(pieceTable.getLineCount(), 6);
        assertDeepEquals(pieceTable.getPositionAt(6), new Position(4, 1));
        assertDeepEquals(pieceTable.getPositionAt(7), new Position(4, 2));
        assertDeepEquals(pieceTable.getPositionAt(8), new Position(4, 3));
        assertDeepEquals(pieceTable.getPositionAt(9), new Position(4, 4));
        assertDeepEquals(pieceTable.getPositionAt(12), new Position(6, 1));
        assertDeepEquals(pieceTable.getPositionAt(13), new Position(6, 2));
        assertDeepEquals(pieceTable.getPositionAt(14), new Position(6, 3));

        assertEquals(pieceTable.getOffsetAt(4, 1), 6);
        assertEquals(pieceTable.getOffsetAt(4, 2), 7);
        assertEquals(pieceTable.getOffsetAt(4, 3), 8);
        assertEquals(pieceTable.getOffsetAt(4, 4), 9);
        assertEquals(pieceTable.getOffsetAt(6, 1), 12);
        assertEquals(pieceTable.getOffsetAt(6, 2), 13);
        assertEquals(pieceTable.getOffsetAt(6, 3), 14);
        assertTreeInvariants(pieceTable);
    }

    // test('delete')
    function testDelete() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\nb\nc\ndefh\ni\njk']);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.delete(7, 2);

        assertEquals(pieceTable.getLinesRawContent(), 'a\nb\nc\ndh\ni\njk');
        assertEquals(pieceTable.getLineCount(), 6);
        assertDeepEquals(pieceTable.getPositionAt(6), new Position(4, 1));
        assertDeepEquals(pieceTable.getPositionAt(7), new Position(4, 2));
        assertDeepEquals(pieceTable.getPositionAt(8), new Position(4, 3));
        assertDeepEquals(pieceTable.getPositionAt(9), new Position(5, 1));
        assertDeepEquals(pieceTable.getPositionAt(11), new Position(6, 1));
        assertDeepEquals(pieceTable.getPositionAt(12), new Position(6, 2));
        assertDeepEquals(pieceTable.getPositionAt(13), new Position(6, 3));

        assertEquals(pieceTable.getOffsetAt(4, 1), 6);
        assertEquals(pieceTable.getOffsetAt(4, 2), 7);
        assertEquals(pieceTable.getOffsetAt(4, 3), 8);
        assertEquals(pieceTable.getOffsetAt(5, 1), 9);
        assertEquals(pieceTable.getOffsetAt(6, 1), 11);
        assertEquals(pieceTable.getOffsetAt(6, 2), 12);
        assertEquals(pieceTable.getOffsetAt(6, 3), 13);
        assertTreeInvariants(pieceTable);
    }

    // test('add+delete 1')
    function testAddDelete1() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\nb\nc\nde']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(8, 'fh\ni\njk');
        pieceTable.delete(7, 2);

        assertEquals(pieceTable.getLinesRawContent(), 'a\nb\nc\ndh\ni\njk');
        assertEquals(pieceTable.getLineCount(), 6);
        assertDeepEquals(pieceTable.getPositionAt(6), new Position(4, 1));
        assertDeepEquals(pieceTable.getPositionAt(7), new Position(4, 2));
        assertDeepEquals(pieceTable.getPositionAt(8), new Position(4, 3));
        assertDeepEquals(pieceTable.getPositionAt(9), new Position(5, 1));
        assertDeepEquals(pieceTable.getPositionAt(11), new Position(6, 1));
        assertDeepEquals(pieceTable.getPositionAt(12), new Position(6, 2));
        assertDeepEquals(pieceTable.getPositionAt(13), new Position(6, 3));

        assertEquals(pieceTable.getOffsetAt(4, 1), 6);
        assertEquals(pieceTable.getOffsetAt(4, 2), 7);
        assertEquals(pieceTable.getOffsetAt(4, 3), 8);
        assertEquals(pieceTable.getOffsetAt(5, 1), 9);
        assertEquals(pieceTable.getOffsetAt(6, 1), 11);
        assertEquals(pieceTable.getOffsetAt(6, 2), 12);
        assertEquals(pieceTable.getOffsetAt(6, 3), 13);
        assertTreeInvariants(pieceTable);
    }

    // test('insert random bug 1: prefixSumComputer.removeValues(start, cnt) cnt is 1 based.')
    function testInsertRandomBug1PrefixSumComputerRemoveValuesStartCntCntIs1Based() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, ' ZX \n Z\nZ\n YZ\nY\nZXX ');
        str =
            str.substring(0, 0) +
            ' ZX \n Z\nZ\n YZ\nY\nZXX ' +
            str.substring(0);
        pieceTable.insert(14, 'X ZZ\nYZZYZXXY Y XY\n ');
        str =
            str.substring(0, 14) + 'X ZZ\nYZZYZXXY Y XY\n ' + str.substring(14);

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('insert random bug 2: prefixSumComputer initialize does not do deep copy of UInt32Array.')
    function testInsertRandomBug2PrefixSumComputerInitializeDoesNotDoDeepCopyOfUInt32Array() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'ZYZ\nYY XY\nX \nZ Y \nZ ');
        str =
            str.substring(0, 0) + 'ZYZ\nYY XY\nX \nZ Y \nZ ' + str.substring(0);
        pieceTable.insert(3, 'XXY \n\nY Y YYY  ZYXY ');
        str = str.substring(0, 3) + 'XXY \n\nY Y YYY  ZYXY ' + str.substring(3);

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('delete random bug 1: I forgot to update the lineFeedCnt when deletion is on one single piece.')
    function testDeleteRandomBug1IForgotToUpdateTheLineFeedCntWhenDeletionIsOnOneSinglePiece() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'ba\na\nca\nba\ncbab\ncaa ');
        pieceTable.insert(13, 'cca\naabb\ncac\nccc\nab ');
        pieceTable.delete(5, 8);
        pieceTable.delete(30, 2);
        pieceTable.insert(24, 'cbbacccbac\nbaaab\n\nc ');
        pieceTable.delete(29, 3);
        pieceTable.delete(23, 9);
        pieceTable.delete(21, 5);
        pieceTable.delete(30, 3);
        pieceTable.insert(3, 'cb\nac\nc\n\nacc\nbb\nb\nc ');
        pieceTable.delete(19, 5);
        pieceTable.insert(18, '\nbb\n\nacbc\ncbb\nc\nbb\n ');
        pieceTable.insert(65, 'cbccbac\nbc\n\nccabba\n ');
        pieceTable.insert(77, 'a\ncacb\n\nac\n\n\n\n\nabab ');
        pieceTable.delete(30, 9);
        pieceTable.insert(45, 'b\n\nc\nba\n\nbbbba\n\naa\n ');
        pieceTable.insert(82, 'ab\nbb\ncabacab\ncbc\na ');
        pieceTable.delete(123, 9);
        pieceTable.delete(71, 2);
        pieceTable.insert(33, 'acaa\nacb\n\naa\n\nc\n\n\n\n ');

        final str = pieceTable.getLinesRawContent();
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('delete random bug rb tree 1')
    function testDeleteRandomBugRbTree1() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([str]);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'YXXZ\n\nYY\n');
        str = str.substring(0, 0) + 'YXXZ\n\nYY\n' + str.substring(0);
        pieceTable.delete(0, 5);
        str = str.substring(0, 0) + str.substring(0 + 5);
        pieceTable.insert(0, 'ZXYY\nX\nZ\n');
        str = str.substring(0, 0) + 'ZXYY\nX\nZ\n' + str.substring(0);
        pieceTable.insert(10, '\nXY\nYXYXY');
        str = str.substring(0, 10) + '\nXY\nYXYXY' + str.substring(10);
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('delete random bug rb tree 2')
    function testDeleteRandomBugRbTree2() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([str]);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'YXXZ\n\nYY\n');
        str = str.substring(0, 0) + 'YXXZ\n\nYY\n' + str.substring(0);
        pieceTable.insert(0, 'ZXYY\nX\nZ\n');
        str = str.substring(0, 0) + 'ZXYY\nX\nZ\n' + str.substring(0);
        pieceTable.insert(10, '\nXY\nYXYXY');
        str = str.substring(0, 10) + '\nXY\nYXYXY' + str.substring(10);
        pieceTable.insert(8, 'YZXY\nZ\nYX');
        str = str.substring(0, 8) + 'YZXY\nZ\nYX' + str.substring(8);
        pieceTable.insert(12, 'XX\nXXYXYZ');
        str = str.substring(0, 12) + 'XX\nXXYXYZ' + str.substring(12);
        pieceTable.delete(0, 4);
        str = str.substring(0, 0) + str.substring(0 + 4);

        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('delete random bug rb tree 3')
    function testDeleteRandomBugRbTree3() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([str]);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'YXXZ\n\nYY\n');
        str = str.substring(0, 0) + 'YXXZ\n\nYY\n' + str.substring(0);
        pieceTable.delete(7, 2);
        str = str.substring(0, 7) + str.substring(7 + 2);
        pieceTable.delete(6, 1);
        str = str.substring(0, 6) + str.substring(6 + 1);
        pieceTable.delete(0, 5);
        str = str.substring(0, 0) + str.substring(0 + 5);
        pieceTable.insert(0, 'ZXYY\nX\nZ\n');
        str = str.substring(0, 0) + 'ZXYY\nX\nZ\n' + str.substring(0);
        pieceTable.insert(10, '\nXY\nYXYXY');
        str = str.substring(0, 10) + '\nXY\nYXYXY' + str.substring(10);
        pieceTable.insert(8, 'YZXY\nZ\nYX');
        str = str.substring(0, 8) + 'YZXY\nZ\nYX' + str.substring(8);
        pieceTable.insert(12, 'XX\nXXYXYZ');
        str = str.substring(0, 12) + 'XX\nXXYXYZ' + str.substring(12);
        pieceTable.delete(0, 4);
        str = str.substring(0, 0) + str.substring(0 + 4);
        pieceTable.delete(30, 3);
        str = str.substring(0, 30) + str.substring(30 + 3);

        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('offset 2 position') */
class Offset2PositionTest extends PieceTreeTextBufferTestBase {

    // test('random tests bug 1')
    function testRandomTestsBug1() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'huuyYzUfKOENwGgZLqn ');
        str = str.substring(0, 0) + 'huuyYzUfKOENwGgZLqn ' + str.substring(0);
        pieceTable.delete(18, 2);
        str = str.substring(0, 18) + str.substring(18 + 2);
        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.delete(12, 4);
        str = str.substring(0, 12) + str.substring(12 + 4);
        pieceTable.insert(3, 'hMbnVEdTSdhLlPevXKF ');
        str = str.substring(0, 3) + 'hMbnVEdTSdhLlPevXKF ' + str.substring(3);
        pieceTable.delete(22, 8);
        str = str.substring(0, 22) + str.substring(22 + 8);
        pieceTable.insert(4, 'S umSnYrqOmOAV\nEbZJ ');
        str = str.substring(0, 4) + 'S umSnYrqOmOAV\nEbZJ ' + str.substring(4);

        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('get text in range') */
class GetTextInRangeTest extends PieceTreeTextBufferTestBase {

    // test('getContentInRange')
    function testGetContentInRange() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\nb\nc\nde']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(8, 'fh\ni\njk');
        pieceTable.delete(7, 2);
        // 'a\nb\nc\ndh\ni\njk'

        assertEquals(pieceTable.getValueInRange(new Range(1, 1, 1, 3)), 'a\n');
        assertEquals(pieceTable.getValueInRange(new Range(2, 1, 2, 3)), 'b\n');
        assertEquals(pieceTable.getValueInRange(new Range(3, 1, 3, 3)), 'c\n');
        assertEquals(pieceTable.getValueInRange(new Range(4, 1, 4, 4)), 'dh\n');
        assertEquals(pieceTable.getValueInRange(new Range(5, 1, 5, 3)), 'i\n');
        assertEquals(pieceTable.getValueInRange(new Range(6, 1, 6, 3)), 'jk');
        assertTreeInvariants(pieceTable);
    }

    // test('random test value in range')
    function testRandomTestValueInRange() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([str]);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'ZXXY');
        str = str.substring(0, 0) + 'ZXXY' + str.substring(0);
        pieceTable.insert(1, 'XZZY');
        str = str.substring(0, 1) + 'XZZY' + str.substring(1);
        pieceTable.insert(5, '\nX\n\n');
        str = str.substring(0, 5) + '\nX\n\n' + str.substring(5);
        pieceTable.insert(3, '\nXX\n');
        str = str.substring(0, 3) + '\nXX\n' + str.substring(3);
        pieceTable.insert(12, 'YYYX');
        str = str.substring(0, 12) + 'YYYX' + str.substring(12);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random test value in range exception')
    function testRandomTestValueInRangeException() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([str]);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'XZ\nZ');
        str = str.substring(0, 0) + 'XZ\nZ' + str.substring(0);
        pieceTable.delete(0, 3);
        str = str.substring(0, 0) + str.substring(0 + 3);
        pieceTable.delete(0, 1);
        str = str.substring(0, 0) + str.substring(0 + 1);
        pieceTable.insert(0, 'ZYX\n');
        str = str.substring(0, 0) + 'ZYX\n' + str.substring(0);
        pieceTable.delete(0, 4);
        str = str.substring(0, 0) + str.substring(0 + 4);

        pieceTable.getValueInRange(new Range(1, 1, 1, 1));
        assertTreeInvariants(pieceTable);
    }

    // test('random tests bug 1')
    function testRandomTestsBug1() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'huuyYzUfKOENwGgZLqn ');
        str = str.substring(0, 0) + 'huuyYzUfKOENwGgZLqn ' + str.substring(0);
        pieceTable.delete(18, 2);
        str = str.substring(0, 18) + str.substring(18 + 2);
        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.delete(12, 4);
        str = str.substring(0, 12) + str.substring(12 + 4);
        pieceTable.insert(3, 'hMbnVEdTSdhLlPevXKF ');
        str = str.substring(0, 3) + 'hMbnVEdTSdhLlPevXKF ' + str.substring(3);
        pieceTable.delete(22, 8);
        str = str.substring(0, 22) + str.substring(22 + 8);
        pieceTable.insert(4, 'S umSnYrqOmOAV\nEbZJ ');
        str = str.substring(0, 4) + 'S umSnYrqOmOAV\nEbZJ ' + str.substring(4);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random tests bug 2')
    function testRandomTestsBug2() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'xfouRDZwdAHjVXJAMV\n ');
        str = str.substring(0, 0) + 'xfouRDZwdAHjVXJAMV\n ' + str.substring(0);
        pieceTable.insert(16, 'dBGndxpFZBEAIKykYYx ');
        str = str.substring(0, 16) + 'dBGndxpFZBEAIKykYYx ' + str.substring(16);
        pieceTable.delete(7, 6);
        str = str.substring(0, 7) + str.substring(7 + 6);
        pieceTable.delete(9, 7);
        str = str.substring(0, 9) + str.substring(9 + 7);
        pieceTable.delete(17, 6);
        str = str.substring(0, 17) + str.substring(17 + 6);
        pieceTable.delete(0, 4);
        str = str.substring(0, 0) + str.substring(0 + 4);
        pieceTable.insert(9, 'qvEFXCNvVkWgvykahYt ');
        str = str.substring(0, 9) + 'qvEFXCNvVkWgvykahYt ' + str.substring(9);
        pieceTable.delete(4, 6);
        str = str.substring(0, 4) + str.substring(4 + 6);
        pieceTable.insert(11, 'OcSChUYT\nzPEBOpsGmR ');
        str =
            str.substring(0, 11) + 'OcSChUYT\nzPEBOpsGmR ' + str.substring(11);
        pieceTable.insert(15, 'KJCozaXTvkE\nxnqAeTz ');
        str =
            str.substring(0, 15) + 'KJCozaXTvkE\nxnqAeTz ' + str.substring(15);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('get line content')
    function testGetLineContent() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['1']);
        final pieceTable = pieceTree.getPieceTree();

        assertEquals(pieceTable.getLineRawContent(1), '1');
        pieceTable.insert(1, '2');
        assertEquals(pieceTable.getLineRawContent(1), '12');
        assertTreeInvariants(pieceTable);
    }

    // test('get line content basic')
    function testGetLineContentBasic() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['1\n2\n3\n4']);
        final pieceTable = pieceTree.getPieceTree();

        assertEquals(pieceTable.getLineRawContent(1), '1\n');
        assertEquals(pieceTable.getLineRawContent(2), '2\n');
        assertEquals(pieceTable.getLineRawContent(3), '3\n');
        assertEquals(pieceTable.getLineRawContent(4), '4');
        assertTreeInvariants(pieceTable);
    }

    // test('get line content after inserts/deletes')
    function testGetLineContentAfterInsertsDeletes() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\nb\nc\nde']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(8, 'fh\ni\njk');
        pieceTable.delete(7, 2);
        // 'a\nb\nc\ndh\ni\njk'

        assertEquals(pieceTable.getLineRawContent(1), 'a\n');
        assertEquals(pieceTable.getLineRawContent(2), 'b\n');
        assertEquals(pieceTable.getLineRawContent(3), 'c\n');
        assertEquals(pieceTable.getLineRawContent(4), 'dh\n');
        assertEquals(pieceTable.getLineRawContent(5), 'i\n');
        assertEquals(pieceTable.getLineRawContent(6), 'jk');
        assertTreeInvariants(pieceTable);
    }

    // test('random 1')
    function testRandom1() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'J eNnDzQpnlWyjmUu\ny ');
        str = str.substring(0, 0) + 'J eNnDzQpnlWyjmUu\ny ' + str.substring(0);
        pieceTable.insert(0, 'QPEeRAQmRwlJqtZSWhQ ');
        str = str.substring(0, 0) + 'QPEeRAQmRwlJqtZSWhQ ' + str.substring(0);
        pieceTable.delete(5, 1);
        str = str.substring(0, 5) + str.substring(5 + 1);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random 2')
    function testRandom2() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'DZoQ tglPCRHMltejRI ');
        str = str.substring(0, 0) + 'DZoQ tglPCRHMltejRI ' + str.substring(0);
        pieceTable.insert(10, 'JRXiyYqJ qqdcmbfkKX ');
        str = str.substring(0, 10) + 'JRXiyYqJ qqdcmbfkKX ' + str.substring(10);
        pieceTable.delete(16, 3);
        str = str.substring(0, 16) + str.substring(16 + 3);
        pieceTable.delete(25, 1);
        str = str.substring(0, 25) + str.substring(25 + 1);
        pieceTable.insert(18, 'vH\nNlvfqQJPm\nSFkhMc ');
        str =
            str.substring(0, 18) + 'vH\nNlvfqQJPm\nSFkhMc ' + str.substring(18);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('CRLF') */
class CRLFTest extends PieceTreeTextBufferTestBase {

    // test('delete CR in CRLF 1')
    function testDeleteCRInCRLF1() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'a\r\nb');
        pieceTable.delete(0, 2);

        assertEquals(pieceTable.getLineCount(), 2);
        assertTreeInvariants(pieceTable);
    }

    // test('delete CR in CRLF 2')
    function testDeleteCRInCRLF2() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, 'a\r\nb');
        pieceTable.delete(2, 2);

        assertEquals(pieceTable.getLineCount(), 2);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 1')
    function testRandomBug1() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.insert(0, '\n\n\r\r');
        str = str.substring(0, 0) + '\n\n\r\r' + str.substring(0);
        pieceTable.insert(1, '\r\n\r\n');
        str = str.substring(0, 1) + '\r\n\r\n' + str.substring(1);
        pieceTable.delete(5, 3);
        str = str.substring(0, 5) + str.substring(5 + 3);
        pieceTable.delete(2, 3);
        str = str.substring(0, 2) + str.substring(2 + 3);

        final lines = splitLines(str);
        assertEquals(pieceTable.getLineCount(), lines.length);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 2')
    function testRandomBug2() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\n\r\n\r');
        str = str.substring(0, 0) + '\n\r\n\r' + str.substring(0);
        pieceTable.insert(2, '\n\r\r\r');
        str = str.substring(0, 2) + '\n\r\r\r' + str.substring(2);
        pieceTable.delete(4, 1);
        str = str.substring(0, 4) + str.substring(4 + 1);

        final lines = splitLines(str);
        assertEquals(pieceTable.getLineCount(), lines.length);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 3')
    function testRandomBug3() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\n\n\n\r');
        str = str.substring(0, 0) + '\n\n\n\r' + str.substring(0);
        pieceTable.delete(2, 2);
        str = str.substring(0, 2) + str.substring(2 + 2);
        pieceTable.delete(0, 2);
        str = str.substring(0, 0) + str.substring(0 + 2);
        pieceTable.insert(0, '\r\r\r\r');
        str = str.substring(0, 0) + '\r\r\r\r' + str.substring(0);
        pieceTable.insert(2, '\r\n\r\r');
        str = str.substring(0, 2) + '\r\n\r\r' + str.substring(2);
        pieceTable.insert(3, '\r\r\r\n');
        str = str.substring(0, 3) + '\r\r\r\n' + str.substring(3);

        final lines = splitLines(str);
        assertEquals(pieceTable.getLineCount(), lines.length);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 4')
    function testRandomBug4() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\n\n\n\n');
        str = str.substring(0, 0) + '\n\n\n\n' + str.substring(0);
        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.insert(1, '\r\r\r\r');
        str = str.substring(0, 1) + '\r\r\r\r' + str.substring(1);
        pieceTable.insert(6, '\r\n\n\r');
        str = str.substring(0, 6) + '\r\n\n\r' + str.substring(6);
        pieceTable.delete(5, 3);
        str = str.substring(0, 5) + str.substring(5 + 3);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 5')
    function testRandomBug5() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\n\n\n\n');
        str = str.substring(0, 0) + '\n\n\n\n' + str.substring(0);
        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.insert(0, '\n\r\r\n');
        str = str.substring(0, 0) + '\n\r\r\n' + str.substring(0);
        pieceTable.insert(4, '\n\r\r\n');
        str = str.substring(0, 4) + '\n\r\r\n' + str.substring(4);
        pieceTable.delete(4, 3);
        str = str.substring(0, 4) + str.substring(4 + 3);
        pieceTable.insert(5, '\r\r\n\r');
        str = str.substring(0, 5) + '\r\r\n\r' + str.substring(5);
        pieceTable.insert(12, '\n\n\n\r');
        str = str.substring(0, 12) + '\n\n\n\r' + str.substring(12);
        pieceTable.insert(5, '\r\r\r\n');
        str = str.substring(0, 5) + '\r\r\r\n' + str.substring(5);
        pieceTable.insert(20, '\n\n\r\n');
        str = str.substring(0, 20) + '\n\n\r\n' + str.substring(20);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 6')
    function testRandomBug6() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\n\r\r\n');
        str = str.substring(0, 0) + '\n\r\r\n' + str.substring(0);
        pieceTable.insert(4, '\r\n\n\r');
        str = str.substring(0, 4) + '\r\n\n\r' + str.substring(4);
        pieceTable.insert(3, '\r\n\n\n');
        str = str.substring(0, 3) + '\r\n\n\n' + str.substring(3);
        pieceTable.delete(4, 8);
        str = str.substring(0, 4) + str.substring(4 + 8);
        pieceTable.insert(4, '\r\n\n\r');
        str = str.substring(0, 4) + '\r\n\n\r' + str.substring(4);
        pieceTable.insert(0, '\r\n\n\r');
        str = str.substring(0, 0) + '\r\n\n\r' + str.substring(0);
        pieceTable.delete(4, 0);
        str = str.substring(0, 4) + str.substring(4 + 0);
        pieceTable.delete(8, 4);
        str = str.substring(0, 8) + str.substring(8 + 4);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 8')
    function testRandomBug8() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\r\n\n\r');
        str = str.substring(0, 0) + '\r\n\n\r' + str.substring(0);
        pieceTable.delete(1, 0);
        str = str.substring(0, 1) + str.substring(1 + 0);
        pieceTable.insert(3, '\n\n\n\r');
        str = str.substring(0, 3) + '\n\n\n\r' + str.substring(3);
        pieceTable.insert(7, '\n\n\r\n');
        str = str.substring(0, 7) + '\n\n\r\n' + str.substring(7);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 7')
    function testRandomBug7() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\r\r\n\n');
        str = str.substring(0, 0) + '\r\r\n\n' + str.substring(0);
        pieceTable.insert(4, '\r\n\n\r');
        str = str.substring(0, 4) + '\r\n\n\r' + str.substring(4);
        pieceTable.insert(7, '\n\r\r\r');
        str = str.substring(0, 7) + '\n\r\r\r' + str.substring(7);
        pieceTable.insert(11, '\n\n\r\n');
        str = str.substring(0, 11) + '\n\n\r\n' + str.substring(11);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 10')
    function testRandomBug10() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'qneW');
        str = str.substring(0, 0) + 'qneW' + str.substring(0);
        pieceTable.insert(0, 'YhIl');
        str = str.substring(0, 0) + 'YhIl' + str.substring(0);
        pieceTable.insert(0, 'qdsm');
        str = str.substring(0, 0) + 'qdsm' + str.substring(0);
        pieceTable.delete(7, 0);
        str = str.substring(0, 7) + str.substring(7 + 0);
        pieceTable.insert(12, 'iiPv');
        str = str.substring(0, 12) + 'iiPv' + str.substring(12);
        pieceTable.insert(9, 'V\rSA');
        str = str.substring(0, 9) + 'V\rSA' + str.substring(9);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 9')
    function testRandomBug9() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, '\n\n\n\n');
        str = str.substring(0, 0) + '\n\n\n\n' + str.substring(0);
        pieceTable.insert(3, '\n\r\n\r');
        str = str.substring(0, 3) + '\n\r\n\r' + str.substring(3);
        pieceTable.insert(2, '\n\r\n\n');
        str = str.substring(0, 2) + '\n\r\n\n' + str.substring(2);
        pieceTable.insert(0, '\n\n\r\r');
        str = str.substring(0, 0) + '\n\n\r\r' + str.substring(0);
        pieceTable.insert(3, '\r\r\r\r');
        str = str.substring(0, 3) + '\r\r\r\r' + str.substring(3);
        pieceTable.insert(3, '\n\n\r\r');
        str = str.substring(0, 3) + '\n\n\r\r' + str.substring(3);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('centralized lineStarts with CRLF') */
class CentralizedLineStartsWithCRLFTest extends PieceTreeTextBufferTestBase {

    // test('delete CR in CRLF 1')
    function testDeleteCRInCRLF1() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\r\nb'], false);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.delete(2, 2);
        assertEquals(pieceTable.getLineCount(), 2);
        assertTreeInvariants(pieceTable);
    }

    // test('delete CR in CRLF 2')
    function testDeleteCRInCRLF2() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['a\r\nb']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.delete(0, 2);

        assertEquals(pieceTable.getLineCount(), 2);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 1')
    function testRandomBug1() {
        var str = '\n\n\r\r';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\n\r\r'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(1, '\r\n\r\n');
        str = str.substring(0, 1) + '\r\n\r\n' + str.substring(1);
        pieceTable.delete(5, 3);
        str = str.substring(0, 5) + str.substring(5 + 3);
        pieceTable.delete(2, 3);
        str = str.substring(0, 2) + str.substring(2 + 3);

        final lines = splitLines(str);
        assertEquals(pieceTable.getLineCount(), lines.length);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 2')
    function testRandomBug2() {
        var str = '\n\r\n\r';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\r\n\r'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(2, '\n\r\r\r');
        str = str.substring(0, 2) + '\n\r\r\r' + str.substring(2);
        pieceTable.delete(4, 1);
        str = str.substring(0, 4) + str.substring(4 + 1);

        final lines = splitLines(str);
        assertEquals(pieceTable.getLineCount(), lines.length);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 3')
    function testRandomBug3() {
        var str = '\n\n\n\r';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\n\n\r'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.delete(2, 2);
        str = str.substring(0, 2) + str.substring(2 + 2);
        pieceTable.delete(0, 2);
        str = str.substring(0, 0) + str.substring(0 + 2);
        pieceTable.insert(0, '\r\r\r\r');
        str = str.substring(0, 0) + '\r\r\r\r' + str.substring(0);
        pieceTable.insert(2, '\r\n\r\r');
        str = str.substring(0, 2) + '\r\n\r\r' + str.substring(2);
        pieceTable.insert(3, '\r\r\r\n');
        str = str.substring(0, 3) + '\r\r\r\n' + str.substring(3);

        final lines = splitLines(str);
        assertEquals(pieceTable.getLineCount(), lines.length);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 4')
    function testRandomBug4() {
        var str = '\n\n\n\n';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\n\n\n'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.insert(1, '\r\r\r\r');
        str = str.substring(0, 1) + '\r\r\r\r' + str.substring(1);
        pieceTable.insert(6, '\r\n\n\r');
        str = str.substring(0, 6) + '\r\n\n\r' + str.substring(6);
        pieceTable.delete(5, 3);
        str = str.substring(0, 5) + str.substring(5 + 3);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 5')
    function testRandomBug5() {
        var str = '\n\n\n\n';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\n\n\n'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.delete(3, 1);
        str = str.substring(0, 3) + str.substring(3 + 1);
        pieceTable.insert(0, '\n\r\r\n');
        str = str.substring(0, 0) + '\n\r\r\n' + str.substring(0);
        pieceTable.insert(4, '\n\r\r\n');
        str = str.substring(0, 4) + '\n\r\r\n' + str.substring(4);
        pieceTable.delete(4, 3);
        str = str.substring(0, 4) + str.substring(4 + 3);
        pieceTable.insert(5, '\r\r\n\r');
        str = str.substring(0, 5) + '\r\r\n\r' + str.substring(5);
        pieceTable.insert(12, '\n\n\n\r');
        str = str.substring(0, 12) + '\n\n\n\r' + str.substring(12);
        pieceTable.insert(5, '\r\r\r\n');
        str = str.substring(0, 5) + '\r\r\r\n' + str.substring(5);
        pieceTable.insert(20, '\n\n\r\n');
        str = str.substring(0, 20) + '\n\n\r\n' + str.substring(20);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 6')
    function testRandomBug6() {
        var str = '\n\r\r\n';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\r\r\n'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(4, '\r\n\n\r');
        str = str.substring(0, 4) + '\r\n\n\r' + str.substring(4);
        pieceTable.insert(3, '\r\n\n\n');
        str = str.substring(0, 3) + '\r\n\n\n' + str.substring(3);
        pieceTable.delete(4, 8);
        str = str.substring(0, 4) + str.substring(4 + 8);
        pieceTable.insert(4, '\r\n\n\r');
        str = str.substring(0, 4) + '\r\n\n\r' + str.substring(4);
        pieceTable.insert(0, '\r\n\n\r');
        str = str.substring(0, 0) + '\r\n\n\r' + str.substring(0);
        pieceTable.delete(4, 0);
        str = str.substring(0, 4) + str.substring(4 + 0);
        pieceTable.delete(8, 4);
        str = str.substring(0, 8) + str.substring(8 + 4);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 7')
    function testRandomBug7() {
        var str = '\r\n\n\r';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\r\n\n\r'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.delete(1, 0);
        str = str.substring(0, 1) + str.substring(1 + 0);
        pieceTable.insert(3, '\n\n\n\r');
        str = str.substring(0, 3) + '\n\n\n\r' + str.substring(3);
        pieceTable.insert(7, '\n\n\r\n');
        str = str.substring(0, 7) + '\n\n\r\n' + str.substring(7);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 8')
    function testRandomBug8() {
        var str = '\r\r\n\n';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\r\r\n\n'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(4, '\r\n\n\r');
        str = str.substring(0, 4) + '\r\n\n\r' + str.substring(4);
        pieceTable.insert(7, '\n\r\r\r');
        str = str.substring(0, 7) + '\n\r\r\r' + str.substring(7);
        pieceTable.insert(11, '\n\n\r\n');
        str = str.substring(0, 11) + '\n\n\r\n' + str.substring(11);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 9')
    function testRandomBug9() {
        var str = 'qneW';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['qneW'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(0, 'YhIl');
        str = str.substring(0, 0) + 'YhIl' + str.substring(0);
        pieceTable.insert(0, 'qdsm');
        str = str.substring(0, 0) + 'qdsm' + str.substring(0);
        pieceTable.delete(7, 0);
        str = str.substring(0, 7) + str.substring(7 + 0);
        pieceTable.insert(12, 'iiPv');
        str = str.substring(0, 12) + 'iiPv' + str.substring(12);
        pieceTable.insert(9, 'V\rSA');
        str = str.substring(0, 9) + 'V\rSA' + str.substring(9);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random bug 10')
    function testRandomBug10() {
        var str = '\n\n\n\n';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\n\n\n'], false);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.insert(3, '\n\r\n\r');
        str = str.substring(0, 3) + '\n\r\n\r' + str.substring(3);
        pieceTable.insert(2, '\n\r\n\n');
        str = str.substring(0, 2) + '\n\r\n\n' + str.substring(2);
        pieceTable.insert(0, '\n\n\r\r');
        str = str.substring(0, 0) + '\n\n\r\r' + str.substring(0);
        pieceTable.insert(3, '\r\r\r\r');
        str = str.substring(0, 3) + '\r\r\r\r' + str.substring(3);
        pieceTable.insert(3, '\n\n\r\r');
        str = str.substring(0, 3) + '\n\n\r\r' + str.substring(3);

        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random chunk bug 1')
    function testRandomChunkBug1() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\r\r\n\n\n\r\n\r'], false);
        final pieceTable = pieceTree.getPieceTree();

        var str = '\n\r\r\n\n\n\r\n\r';
        pieceTable.delete(0, 2);
        str = str.substring(0, 0) + str.substring(0 + 2);
        pieceTable.insert(1, '\r\r\n\n');
        str = str.substring(0, 1) + '\r\r\n\n' + str.substring(1);
        pieceTable.insert(7, '\r\r\r\r');
        str = str.substring(0, 7) + '\r\r\r\r' + str.substring(7);

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random chunk bug 2')
    function testRandomChunkBug2() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([
            '\n\r\n\n\n\r\n\r\n\r\r\n\n\n\r\r\n\r\n'
        ], false);
        final pieceTable = pieceTree.getPieceTree();
        var str = '\n\r\n\n\n\r\n\r\n\r\r\n\n\n\r\r\n\r\n';
        pieceTable.insert(16, '\r\n\r\r');
        str = str.substring(0, 16) + '\r\n\r\r' + str.substring(16);
        pieceTable.insert(13, '\n\n\r\r');
        str = str.substring(0, 13) + '\n\n\r\r' + str.substring(13);
        pieceTable.insert(19, '\n\n\r\n');
        str = str.substring(0, 19) + '\n\n\r\n' + str.substring(19);
        pieceTable.delete(5, 0);
        str = str.substring(0, 5) + str.substring(5 + 0);
        pieceTable.delete(11, 2);
        str = str.substring(0, 11) + str.substring(11 + 2);

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random chunk bug 3')
    function testRandomChunkBug3() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\r\n\n\n\n\n\n\r\n'], false);
        final pieceTable = pieceTree.getPieceTree();
        var str = '\r\n\n\n\n\n\n\r\n';
        pieceTable.insert(4, '\n\n\r\n\r\r\n\n\r');
        str = str.substring(0, 4) + '\n\n\r\n\r\r\n\n\r' + str.substring(4);
        pieceTable.delete(4, 4);
        str = str.substring(0, 4) + str.substring(4 + 4);
        pieceTable.insert(11, '\r\n\r\n\n\r\r\n\n');
        str = str.substring(0, 11) + '\r\n\r\n\n\r\r\n\n' + str.substring(11);
        pieceTable.delete(1, 2);
        str = str.substring(0, 1) + str.substring(1 + 2);

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random chunk bug 4')
    function testRandomChunkBug4() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['\n\r\n\r'], false);
        final pieceTable = pieceTree.getPieceTree();
        var str = '\n\r\n\r';
        pieceTable.insert(4, '\n\n\r\n');
        str = str.substring(0, 4) + '\n\n\r\n' + str.substring(4);
        pieceTable.insert(3, '\r\n\n\n');
        str = str.substring(0, 3) + '\r\n\n\n' + str.substring(3);

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('random is unsupervised') */
class RandomIsUnsupervisedTest extends PieceTreeTextBufferTestBase {

    // test('splitting large change buffer')
    function testSplittingLargeChangeBuffer() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([''], false);
        final pieceTable = pieceTree.getPieceTree();
        var str = '';

        pieceTable.insert(0, 'WUZ\nXVZY\n');
        str = str.substring(0, 0) + 'WUZ\nXVZY\n' + str.substring(0);
        pieceTable.insert(8, '\r\r\nZXUWVW');
        str = str.substring(0, 8) + '\r\r\nZXUWVW' + str.substring(8);
        pieceTable.delete(10, 7);
        str = str.substring(0, 10) + str.substring(10 + 7);
        pieceTable.delete(10, 1);
        str = str.substring(0, 10) + str.substring(10 + 1);
        pieceTable.insert(4, 'VX\r\r\nWZVZ');
        str = str.substring(0, 4) + 'VX\r\r\nWZVZ' + str.substring(4);
        pieceTable.delete(11, 3);
        str = str.substring(0, 11) + str.substring(11 + 3);
        pieceTable.delete(12, 4);
        str = str.substring(0, 12) + str.substring(12 + 4);
        pieceTable.delete(8, 0);
        str = str.substring(0, 8) + str.substring(8 + 0);
        pieceTable.delete(10, 2);
        str = str.substring(0, 10) + str.substring(10 + 2);
        pieceTable.insert(0, 'VZXXZYZX\r');
        str = str.substring(0, 0) + 'VZXXZYZX\r' + str.substring(0);

        assertEquals(pieceTable.getLinesRawContent(), str);

        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random insert delete')
    function testRandomInsertDelete() {
        var str = '';
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([str], false);
        final pieceTable = pieceTree.getPieceTree();
        // var output = '';
        for (i in 0...1000) {
            if (Math.random() < 0.6) {
                // insert
                final text = PieceTreeTextBufferTestBase.randomStr(100);
                final pos = PieceTreeTextBufferTestBase.randomInt(str.length + 1);
                pieceTable.insert(pos, text);
                str = str.substring(0, pos) + text + str.substring(pos);
                // output += `pieceTable.insert(${pos}, '${text.replace(/\n/g, '\\n').replace(/\r/g, '\\r')}');\n`;
                // output += `str = str.substring(0, ${pos}) + '${text.replace(/\n/g, '\\n').replace(/\r/g, '\\r')}' + str.substring(${pos});\n`;
            } else {
                // delete
                final pos = PieceTreeTextBufferTestBase.randomInt(str.length);
                final length = Std.int(Math.min(
                    str.length - pos,
                    Math.floor(Math.random() * 10)
                ));
                pieceTable.delete(pos, length);
                str = str.substring(0, pos) + str.substring(pos + length);
                // output += `pieceTable.delete(${pos}, ${length});\n`;
                // output += `str = str.substring(0, ${pos}) + str.substring(${pos} + ${length});\n`

            }
        }
        // console.log(output);

        assertEquals(pieceTable.getLinesRawContent(), str);

        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random chunks')
    function testRandomChunks() {
        final chunks:Array<String> = [];
        for (i in 0...5) {
            chunks.push(PieceTreeTextBufferTestBase.randomStr(1000));
        }

        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(chunks, false);
        final pieceTable = pieceTree.getPieceTree();
        var str = chunks.join('');

        for (i in 0...1000) {
            if (Math.random() < 0.6) {
                // insert
                final text = PieceTreeTextBufferTestBase.randomStr(100);
                final pos = PieceTreeTextBufferTestBase.randomInt(str.length + 1);
                pieceTable.insert(pos, text);
                str = str.substring(0, pos) + text + str.substring(pos);
            } else {
                // delete
                final pos = PieceTreeTextBufferTestBase.randomInt(str.length);
                final length = Std.int(Math.min(
                    str.length - pos,
                    Math.floor(Math.random() * 10)
                ));
                pieceTable.delete(pos, length);
                str = str.substring(0, pos) + str.substring(pos + length);
            }
        }

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('random chunks 2')
    function testRandomChunks2() {
        final chunks:Array<String> = [];
        chunks.push(PieceTreeTextBufferTestBase.randomStr(1000));

        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(chunks, false);
        final pieceTable = pieceTree.getPieceTree();
        var str = chunks.join('');

        for (i in 0...50) {
            if (Math.random() < 0.6) {
                // insert
                final text = PieceTreeTextBufferTestBase.randomStr(30);
                final pos = PieceTreeTextBufferTestBase.randomInt(str.length + 1);
                pieceTable.insert(pos, text);
                str = str.substring(0, pos) + text + str.substring(pos);
            } else {
                // delete
                final pos = PieceTreeTextBufferTestBase.randomInt(str.length);
                final length = Std.int(Math.min(
                    str.length - pos,
                    Math.floor(Math.random() * 10)
                ));
                pieceTable.delete(pos, length);
                str = str.substring(0, pos) + str.substring(pos + length);
            }
            _testLinesContent(str, pieceTable);
        }

        assertEquals(pieceTable.getLinesRawContent(), str);
        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('buffer api') */
class BufferApiTest extends PieceTreeTextBufferTestBase {

    // test('equal')
    function testEqual() {
        final a = PieceTreeTextBufferTestBase.createTextBuffer(['abc']);
        final b = PieceTreeTextBufferTestBase.createTextBuffer(['ab', 'c']);
        final c = PieceTreeTextBufferTestBase.createTextBuffer(['abd']);
        final d = PieceTreeTextBufferTestBase.createTextBuffer(['abcd']);

        assertTrue(a.getPieceTree().equal(b.getPieceTree()));
        assertTrue(!a.getPieceTree().equal(c.getPieceTree()));
        assertTrue(!a.getPieceTree().equal(d.getPieceTree()));
    }

    // test('equal with more chunks')
    function testEqualWithMoreChunks() {
        final a = PieceTreeTextBufferTestBase.createTextBuffer(['ab', 'cd', 'e']);
        final b = PieceTreeTextBufferTestBase.createTextBuffer(['ab', 'c', 'de']);
        assertTrue(a.getPieceTree().equal(b.getPieceTree()));
    }

    // test('equal 2, empty buffer')
    function testEqual2EmptyBuffer() {
        final a = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final b = PieceTreeTextBufferTestBase.createTextBuffer(['']);

        assertTrue(a.getPieceTree().equal(b.getPieceTree()));
    }

    // test('equal 3, empty buffer')
    function testEqual3EmptyBuffer() {
        final a = PieceTreeTextBufferTestBase.createTextBuffer(['a']);
        final b = PieceTreeTextBufferTestBase.createTextBuffer(['']);

        assertTrue(!a.getPieceTree().equal(b.getPieceTree()));
    }

    // test('getLineCharCode - issue #45735')
    function testGetLineCharCodeIssue45735() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['LINE1\nline2']);
        final pieceTable = pieceTree.getPieceTree();
        assertEquals(pieceTable.getLineCharCode(1, 0), 'L'.code, 'L');
        assertEquals(pieceTable.getLineCharCode(1, 1), 'I'.code, 'I');
        assertEquals(pieceTable.getLineCharCode(1, 2), 'N'.code, 'N');
        assertEquals(pieceTable.getLineCharCode(1, 3), 'E'.code, 'E');
        assertEquals(pieceTable.getLineCharCode(1, 4), '1'.code, '1');
        assertEquals(pieceTable.getLineCharCode(1, 5), '\n'.code, '\\n');
        assertEquals(pieceTable.getLineCharCode(2, 0), 'l'.code, 'l');
        assertEquals(pieceTable.getLineCharCode(2, 1), 'i'.code, 'i');
        assertEquals(pieceTable.getLineCharCode(2, 2), 'n'.code, 'n');
        assertEquals(pieceTable.getLineCharCode(2, 3), 'e'.code, 'e');
        assertEquals(pieceTable.getLineCharCode(2, 4), '2'.code, '2');
    }

    // test('getLineCharCode - issue #47733')
    function testGetLineCharCodeIssue47733() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['', 'LINE1\n', 'line2']);
        final pieceTable = pieceTree.getPieceTree();
        assertEquals(pieceTable.getLineCharCode(1, 0), 'L'.code, 'L');
        assertEquals(pieceTable.getLineCharCode(1, 1), 'I'.code, 'I');
        assertEquals(pieceTable.getLineCharCode(1, 2), 'N'.code, 'N');
        assertEquals(pieceTable.getLineCharCode(1, 3), 'E'.code, 'E');
        assertEquals(pieceTable.getLineCharCode(1, 4), '1'.code, '1');
        assertEquals(pieceTable.getLineCharCode(1, 5), '\n'.code, '\\n');
        assertEquals(pieceTable.getLineCharCode(2, 0), 'l'.code, 'l');
        assertEquals(pieceTable.getLineCharCode(2, 1), 'i'.code, 'i');
        assertEquals(pieceTable.getLineCharCode(2, 2), 'n'.code, 'n');
        assertEquals(pieceTable.getLineCharCode(2, 3), 'e'.code, 'e');
        assertEquals(pieceTable.getLineCharCode(2, 4), '2'.code, '2');
    }

    // test('getNearestChunk')
    function testGetNearestChunk() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['012345678']);
        final pt = pieceTree.getPieceTree();

        pt.insert(3, 'ABC');
        assertEquals(pt.getLineContent(1), '012ABC345678');
        assertEquals(pt.getNearestChunk(3), 'ABC');
        assertEquals(pt.getNearestChunk(6), '345678');

        pt.delete(9, 1);
        assertEquals(pt.getLineContent(1), '012ABC34578');
        assertEquals(pt.getNearestChunk(6), '345');
        assertEquals(pt.getNearestChunk(9), '78');
    }

}

/** suite('search offset cache') */
class SearchOffsetCacheTest extends PieceTreeTextBufferTestBase {

    // test('render white space exception')
    function testRenderWhiteSpaceException() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['class Name{\n\t\n\t\t\tget() {\n\n\t\t\t}\n\t\t}']);
        final pieceTable = pieceTree.getPieceTree();
        var str = 'class Name{\n\t\n\t\t\tget() {\n\n\t\t\t}\n\t\t}';

        pieceTable.insert(12, 's');
        str = str.substring(0, 12) + 's' + str.substring(12);

        pieceTable.insert(13, 'e');
        str = str.substring(0, 13) + 'e' + str.substring(13);

        pieceTable.insert(14, 't');
        str = str.substring(0, 14) + 't' + str.substring(14);

        pieceTable.insert(15, '()');
        str = str.substring(0, 15) + '()' + str.substring(15);

        pieceTable.delete(16, 1);
        str = str.substring(0, 16) + str.substring(16 + 1);

        pieceTable.insert(17, '()');
        str = str.substring(0, 17) + '()' + str.substring(17);

        pieceTable.delete(18, 1);
        str = str.substring(0, 18) + str.substring(18 + 1);

        pieceTable.insert(18, '}');
        str = str.substring(0, 18) + '}' + str.substring(18);

        pieceTable.insert(12, '\n');
        str = str.substring(0, 12) + '\n' + str.substring(12);

        pieceTable.delete(12, 1);
        str = str.substring(0, 12) + str.substring(12 + 1);

        pieceTable.delete(18, 1);
        str = str.substring(0, 18) + str.substring(18 + 1);

        pieceTable.insert(18, '}');
        str = str.substring(0, 18) + '}' + str.substring(18);

        pieceTable.delete(17, 2);
        str = str.substring(0, 17) + str.substring(17 + 2);

        pieceTable.delete(16, 1);
        str = str.substring(0, 16) + str.substring(16 + 1);

        pieceTable.insert(16, ')');
        str = str.substring(0, 16) + ')' + str.substring(16);

        pieceTable.delete(15, 2);
        str = str.substring(0, 15) + str.substring(15 + 2);

        final content = pieceTable.getLinesRawContent();
        assertTrue(content == str);
    }

    // test('Line breaks replacement is not necessary when EOL is normalized')
    function testLineBreaksReplacementIsNotNecessaryWhenEOLIsNormalized() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['abc']);
        final pieceTable = pieceTree.getPieceTree();
        var str = 'abc';

        pieceTable.insert(3, 'def\nabc');
        str = str + 'def\nabc';

        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('Line breaks replacement is not necessary when EOL is normalized 2')
    function testLineBreaksReplacementIsNotNecessaryWhenEOLIsNormalized2() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['abc\n']);
        final pieceTable = pieceTree.getPieceTree();
        var str = 'abc\n';

        pieceTable.insert(4, 'def\nabc');
        str = str + 'def\nabc';

        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('Line breaks replacement is not necessary when EOL is normalized 3')
    function testLineBreaksReplacementIsNotNecessaryWhenEOLIsNormalized3() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['abc\n']);
        final pieceTable = pieceTree.getPieceTree();
        var str = 'abc\n';

        pieceTable.insert(2, 'def\nabc');
        str = str.substring(0, 2) + 'def\nabc' + str.substring(2);

        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

    // test('Line breaks replacement is not necessary when EOL is normalized 4')
    function testLineBreaksReplacementIsNotNecessaryWhenEOLIsNormalized4() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['abc\n']);
        final pieceTable = pieceTree.getPieceTree();
        var str = 'abc\n';

        pieceTable.insert(3, 'def\nabc');
        str = str.substring(0, 3) + 'def\nabc' + str.substring(3);

        _testLineStarts(str, pieceTable);
        _testLinesContent(str, pieceTable);
        assertTreeInvariants(pieceTable);
    }

}

/** suite('snapshot') */
class SnapshotTest extends PieceTreeTextBufferTestBase {

    // test('bug #45564, piece tree pieces should be immutable')
    function testBug45564PieceTreePiecesShouldBeImmutable() {
        final model = createTextModel('\n');
        model.applyEdits([
            {
                range: new Range(2, 1, 2, 1),
                text: '!'
            }
        ]);
        final snapshot = model.createSnapshot();
        final snapshot1 = model.createSnapshot();
        assertEquals(model.getLinesContent().join('\n'), PieceTreeTextBufferTestBase.getValueInSnapshot(snapshot));

        model.applyEdits([
            {
                range: new Range(2, 1, 2, 2),
                text: ''
            }
        ]);
        model.applyEdits([
            {
                range: new Range(2, 1, 2, 1),
                text: '!'
            }
        ]);

        assertEquals(model.getLinesContent().join('\n'), PieceTreeTextBufferTestBase.getValueInSnapshot(snapshot1));

        model.dispose();
    }

    // test('immutable snapshot 1')
    function testImmutableSnapshot1() {
        final model = createTextModel('abc\ndef');
        final snapshot = model.createSnapshot();
        model.applyEdits([
            {
                range: new Range(2, 1, 2, 4),
                text: ''
            }
        ]);

        model.applyEdits([
            {
                range: new Range(1, 1, 2, 1),
                text: 'abc\ndef'
            }
        ]);

        assertEquals(model.getLinesContent().join('\n'), PieceTreeTextBufferTestBase.getValueInSnapshot(snapshot));

        model.dispose();
    }

    // test('immutable snapshot 2')
    function testImmutableSnapshot2() {
        final model = createTextModel('abc\ndef');
        final snapshot = model.createSnapshot();
        model.applyEdits([
            {
                range: new Range(2, 1, 2, 1),
                text: '!'
            }
        ]);

        model.applyEdits([
            {
                range: new Range(2, 1, 2, 2),
                text: ''
            }
        ]);

        assertEquals(model.getLinesContent().join('\n'), PieceTreeTextBufferTestBase.getValueInSnapshot(snapshot));

        model.dispose();
    }

    // test('immutable snapshot 3')
    function testImmutableSnapshot3() {
        final model = createTextModel('abc\ndef');
        model.applyEdits([
            {
                range: new Range(2, 4, 2, 4),
                text: '!'
            }
        ]);
        final snapshot = model.createSnapshot();
        model.applyEdits([
            {
                range: new Range(2, 5, 2, 5),
                text: '!'
            }
        ]);

        assertTrue(model.getLinesContent().join('\n') != PieceTreeTextBufferTestBase.getValueInSnapshot(snapshot));

        model.dispose();
    }

}

/** suite('chunk based search') */
class ChunkBasedSearchTest extends PieceTreeTextBufferTestBase {

    // test('#45892. For some cases, the buffer is empty but we still try to search')
    function test45892ForSomeCasesTheBufferIsEmptyButWeStillTryToSearch() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer(['']);
        final pieceTable = pieceTree.getPieceTree();
        pieceTable.delete(0, 1);
        final ret = pieceTree.findMatchesLineByLine(new Range(1, 1, 1, 1), new SearchData(new RegExp('abc'), WordCharacterClassifier.getMapForWordSeparators(',./', []), 'abc'), true, 1000);
        assertEquals(ret.length, 0);
    }

    // test('#45770. FindInNode should not cross node boundary.')
    function test45770FindInNodeShouldNotCrossNodeBoundary() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([
            [
                'balabalababalabalababalabalaba',
                'balabalababalabalababalabalaba',
                '',
                '* [ ] task1',
                '* [x] task2 balabalaba',
                '* [ ] task 3'
            ].join('\n')
        ]);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.delete(0, 62);
        pieceTable.delete(16, 1);

        pieceTable.insert(16, ' ');
        final ret = pieceTable.findMatchesLineByLine(new Range(1, 1, 4, 13), new SearchData(new RegExp('\\[', 'gi'), WordCharacterClassifier.getMapForWordSeparators(',./', []), '['), true, 1000);
        assertEquals(ret.length, 3);

        assertDeepEquals(ret[0].range, new Range(2, 3, 2, 4));
        assertDeepEquals(ret[1].range, new Range(3, 3, 3, 4));
        assertDeepEquals(ret[2].range, new Range(4, 3, 4, 4));
    }

    // test('search searching from the middle')
    function testSearchSearchingFromTheMiddle() {
        final pieceTree = PieceTreeTextBufferTestBase.createTextBuffer([
            [
                'def',
                'dbcabc'
            ].join('\n')
        ]);
        final pieceTable = pieceTree.getPieceTree();

        pieceTable.delete(4, 1);
        var ret = pieceTable.findMatchesLineByLine(new Range(2, 3, 2, 6), new SearchData(new RegExp('a', 'gi'), null, 'a'), true, 1000);
        assertEquals(ret.length, 1);
        assertDeepEquals(ret[0].range, new Range(2, 3, 2, 4));

        pieceTable.delete(4, 1);
        ret = pieceTable.findMatchesLineByLine(new Range(2, 2, 2, 5), new SearchData(new RegExp('a', 'gi'), null, 'a'), true, 1000);
        assertEquals(ret.length, 1);
        assertDeepEquals(ret[0].range, new Range(2, 2, 2, 3));
    }

}

