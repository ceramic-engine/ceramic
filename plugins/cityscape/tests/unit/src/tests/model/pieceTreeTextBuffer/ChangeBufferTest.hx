// New code for Cityscape (not a port): checks the change buffer rotation of
// `PieceTreeBase` (a new change buffer every `ChangeBufferLimit` characters)
// against a plain string, like the random tests of pieceTreeTextBuffer.test.ts.
package tests.model.pieceTreeTextBuffer;

import cityscape.base.common.Strings;
import cityscape.common.Model;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeBase;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeTextBuffer;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeTextBufferBuilder;
import testing.TestCase;

class ChangeBufferTest extends TestCase {

    var seed:Int = 4242;

    function next(bound:Int):Int {
        // Lehmer generator in Float math: the same sequence on every target
        seed = Std.int((seed * 48271.0) % 2147483647.0);
        return seed % bound;
    }

    function createPieceTree(text:String, normalizeEOL:Bool):PieceTreeBase {
        final builder = new PieceTreeTextBufferBuilder();
        builder.acceptChunk(text);
        final factory = builder.finishWithNormalizeEOL(normalizeEOL);
        final buffer:PieceTreeTextBuffer = cast factory.create(DefaultEndOfLine.LF).textBuffer;
        return buffer.getPieceTree();
    }

    function checkContent(pieceTree:PieceTreeBase, str:String):Void {
        assertEquals(pieceTree.getLinesRawContent(), str);
        final lines = Strings.splitLines(str);
        assertEquals(pieceTree.getLineCount(), lines.length);
        for (i in 0...lines.length) {
            if (pieceTree.getLineContent(i + 1) != lines[i]) {
                assertEquals(pieceTree.getLineContent(i + 1), lines[i], 'line ${i + 1}');
                return;
            }
        }
        assertEquals(pieceTree.getLength(), str.length);
    }

    function typeAndCheck(normalizeEOL:Bool, atEnd:Bool):Void {
        final chunks = ['a', 'bc', 'def', '\r', '\n', '\r\n', ' ', 'xyz\r'];
        var str = '';
        final pieceTree = createPieceTree(str, normalizeEOL);
        for (i in 0...40000) {
            final text = chunks[next(chunks.length)];
            final offset = (atEnd || str.length == 0) ? str.length : next(str.length + 1);
            if (!atEnd && i % 7 == 6 && str.length > 2) {
                // Some deletions too
                final cnt = 1 + next(2);
                final start = next(str.length - cnt + 1);
                pieceTree.delete(start, cnt);
                str = str.substring(0, start) + str.substring(start + cnt);
            }
            else {
                pieceTree.insert(offset, text);
                str = str.substring(0, offset) + text + str.substring(offset);
            }
            if (i % 8000 == 7999) {
                checkContent(pieceTree, str);
            }
        }
        // More than one change buffer was used
        assertTrue(str.length > 2 * 16384, "length " + str.length);
        checkContent(pieceTree, str);
    }

    function testTypingAtTheEndUsesSeveralChangeBuffers() {
        typeAndCheck(true, true);
    }

    function testTypingAtTheEndNotNormalized() {
        typeAndCheck(false, true);
    }

    function testEditingAtRandomPositionsUsesSeveralChangeBuffers() {
        typeAndCheck(true, false);
    }

    function testEditingAtRandomPositionsNotNormalized() {
        typeAndCheck(false, false);
    }

}
