// Ported from gpui-kit 0.8.1: crates/base/src/text/stream_fade.rs (tests), crates/base/src/text/editor_seam.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Bounds;
import glaze.Range;
import glaze.TextLayout;
import glaze.kit.base.text.EditorSeam;
import glaze.kit.base.text.RangedColor;
import glaze.kit.base.text.StreamFade;
import glaze.kit.base.text.TextViewMotion;
import glaze.util.Utf8;
import testing.TestCase;

private class Nop implements EditorSink {
    public function new() {}
    public function report(_:Int, _:TextLayout):Void {}
    public function beginPieces(_:Int):Void {}
    public function reportTextPiece(_:Int, _:Int, _:TextLayout):Void {}
    public function reportBoxPiece(_:Int, _:Range, _:Bounds):Void {}
    public function reportEmptyPiece(_:Int, _:Int, _:Bounds):Void {}
    public function backgrounds(_:Int):Array<RangedColor> {
        return [];
    }
}

/**
 * Tests of the streamed fade-in (Rust `text/stream_fade.rs`) and of the
 * editor seam (Rust `text/editor_seam.rs`).
 */
@:access(glaze.kit.base.text)
class TextStreamFadeTest extends TestCase {

    static function ranges(ranges:Array<Range>):String {
        return [for (r in ranges) '${r.start}..${r.end}'].join(',');
    }

    function testCommonPrefixSpansChunkBoundaries() {
        assertEquals(4, StreamFade.commonPrefixLenOfChunks(["ab", "cd"], ["abc", "d"]));
        assertEquals(3, StreamFade.commonPrefixLenOfChunks(["ab", "cd"], ["abc", "x"]));
        assertEquals(2, StreamFade.commonPrefixLenOfChunks(["", "ab"], ["a", "", "b", "c"]));
        assertEquals(0, StreamFade.commonPrefixLenOfChunks(["ab"], []));
    }

    function testFadeUnitsAreWordsWithTheirTrailingSpace() {
        final text = ["hello", " one two", "  three"];
        assertEquals('5..10,10..15,15..20', ranges(StreamFade.fadeUnits(text, 5, 20)));
        // A unit that is only whitespace joins the word after it.
        assertEquals('1..4', ranges(StreamFade.fadeUnits(["a  b"], 1, 4)));
        assertEquals('', ranges(StreamFade.fadeUnits(["abc"], 3, 3)));
    }

    function testFadeUnitsSplitCjkByCharacter() {
        assertEquals('0..3,3..6,6..9,9..12,12..16,16..18', ranges(StreamFade.fadeUnits(["你好，世界 ok"], 0, 18)));
        // Latin before CJK starts a unit at the script change.
        assertEquals('0..2,2..5', ranges(StreamFade.fadeUnits(["ab中"], 0, 5)));
    }

    function testStaggerHoldsWhileTheUpdateLightsUpWithinOneFade() {
        final motion = new TextViewMotion().withStreamFade(0.6).withStreamFadeStagger(0.1);
        assertEquals(0., motion.staggerStep(1));
        assertEquals(0.1, motion.staggerStep(3));
        // The 7th word starts at 600 ms, exactly one fade in: still the stagger as asked.
        assertEquals(0.1, motion.staggerStep(7));
    }

    function testAnUpdateTooLargeToLightUpInOneFadeFadesAsOneChunk() {
        final motion = new TextViewMotion().withStreamFade(0.6).withStreamFadeStagger(0.1);
        // An 8th word would start past the fade: that is a sweep, not typing.
        assertEquals(0., motion.staggerStep(8));
        assertEquals(0., motion.staggerStep(200));
        // Without a stagger nothing changes: every update was already one chunk.
        final plain = new TextViewMotion().withStreamFade(0.6);
        assertEquals(0., plain.staggerStep(200));
    }

    function testPrefixNeverSplitsACharacter() {
        // "中" and "串" share their first UTF-8 byte.
        final next = "a中";
        final old = "a串";
        final prefix = StreamFade.commonPrefixLenOfChunks([next], [old]);
        assertTrue(prefix > 1 && !Utf8.isCharBoundary(next, prefix));
        assertEquals(1, StreamFade.floorCharBoundary([next], prefix));
        assertEquals(4, StreamFade.floorCharBoundary(["a", "中"], 4));
    }

    function testWithSinkRestoresOnPanic() {
        var failed = false;
        try {
            EditorSeam.withSink(new Nop(), () -> {
                assertTrue(EditorSeam.current() != null);
                throw 'boom';
                return true;
            });
        }
        catch (e:Dynamic) {
            failed = true;
        }
        assertTrue(failed);
        assertTrue(EditorSeam.current() == null, 'sink is cleared after a panic');
    }

}
