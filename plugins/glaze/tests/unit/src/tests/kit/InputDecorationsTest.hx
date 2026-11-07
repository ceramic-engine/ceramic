// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.FontWeight;
import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.Range;
import glaze.kit.base.input.DecorationCollections;
import glaze.kit.base.input.DecorationCollections.DecorationIndex;
import glaze.kit.base.input.RangeDecoration;
import glaze.kit.base.input.TextDecoration;
import ropey.Rope;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.input.DecorationCollections` (Rust `decorations.rs`).
 */
class InputDecorationsTest extends TestCase {

    static inline function r(a:Int, b:Int):Range {
        return new Range(a, b);
    }

    static function rangesOf<T:glaze.kit.base.input.TrackedDecoration>(decorations:Array<T>):String {
        return [for (d in decorations) d.getRange().toString()].join(',');
    }

    static function list(ranges:Array<Range>):String {
        return [for (range in ranges) range.toString()].join(',');
    }

    function testGeometricCollectionsShareUtf8NormalizationAndEditAffinity() {
        final collections = new DecorationCollections<RangeDecoration>();
        final text = Rope.fromStr("héllo world");
        final first = collections.create(DecorationCollections.normalize(text, [
            new RangeDecoration(r(2, 4)),
            new RangeDecoration(r(2, 1)),
            new RangeDecoration(r(100, 200)),
        ]));
        final second = collections.create(DecorationCollections.normalize(text, [new RangeDecoration(r(7, 12))]));
        assertTrue(r(1, 4).equals(collections.get(first)[0].range()));
        assertEquals(1, collections.get(first).length);
        collections.adjustForEdit(r(1, 1), 2);
        assertTrue(r(3, 6).equals(collections.get(first)[0].range()));
        collections.adjustForEdit(r(6, 6), 1);
        assertTrue(r(3, 6).equals(collections.get(first)[0].range()));
        collections.adjustForEdit(r(4, 4), 2);
        assertTrue(r(3, 8).equals(collections.get(first)[0].range()));
        collections.adjustForEdit(r(3, 8), 0);
        assertEquals(0, collections.get(first).length);
        assertTrue(collections.get(second).length > 0);
        collections.remove(first);
        final third = collections.create([]);
        assertTrue(third != first);
        assertFalse(collections.set(first, [new RangeDecoration(r(0, 1))]));
        assertNotNull(collections.get(second));
    }

    function testVisibleQueryPreservesLayersAndSkipsFoldedSpans() {
        final collections = new DecorationCollections<RangeDecoration>();
        final first = collections.create([
            new RangeDecoration(r(90, 100)),
            new RangeDecoration(r(0, 100)),
            new RangeDecoration(r(40, 50)), // hidden in a fold
            new RangeDecoration(r(0, 5)),
        ]);
        collections.create([new RangeDecoration(r(2, 4))]);
        final ranges = (collections:DecorationCollections<RangeDecoration>) -> rangesOf(collections.intersecting([r(0, 5), r(90, 100)]));
        assertEquals(list([r(90, 100), r(0, 100), r(0, 5), r(2, 4)]), ranges(collections));
        collections.adjustForEdit(r(0, 0), 1);
        assertEquals(list([r(91, 101), r(1, 101), r(1, 6), r(3, 5)]), ranges(collections));
        collections.set(first, [new RangeDecoration(r(50, 60))]);
        assertEquals(list([r(3, 5)]), ranges(collections));
    }

    function testIntervalIndexCullsLargeCollectionsEvenWithASpanningRange() {
        final decorations = [for (ix in 0...100000) new RangeDecoration(r(ix * 10, ix * 10 + 5))];
        decorations.push(new RangeDecoration(r(0, 1000000)));
        final index = new DecorationIndex(decorations);
        for (query in [r(0, 1), r(500000, 500020), r(999990, 1000001), r(1000000, 1000010)]) {
            final matches:Array<Int> = [];
            final visited = index.query(decorations, 0, decorations.length, query, matches);
            matches.sort((a, b) -> a - b);
            final expected:Array<Int> = [];
            for (ix in 0...decorations.length) {
                final d = decorations[ix].range();
                if (d.start < query.end && d.end > query.start)
                    expected.push(ix);
            }
            assertEquals(expected.join(','), matches.join(','));
            assertTrue(visited < 100, 'visited $visited nodes for $query');
        }
    }

    function testIntervalIndexMatchesLinearReferenceForOverlapsAndMutations() {
        final collections = new DecorationCollections<RangeDecoration>();
        final id = collections.create([for (ix in 0...512) {
            final start = (ix * 37) % 997;
            new RangeDecoration(r(start, start + ix % 61 + 1));
        }]);
        for (edit in [r(0, 0), r(300, 450), r(900, 1100)]) {
            collections.adjustForEdit(edit, 3);
            var start = 0;
            while (start < 1100) {
                final query = r(start, start + 17);
                final expected = [for (d in collections.get(id)) if (d.range().start < query.end && d.range().end > query.start) d];
                assertEquals(rangesOf(expected), rangesOf(collections.intersecting([query])));
                start += 13;
            }
        }
    }

    function testCollectionsAreIndependentAndRangesAreClipped() {
        final text = Rope.fromStr("héllo");
        final firstStyle = new HighlightStyle(null, FontWeight.BOLD);
        final secondStyle = new HighlightStyle(null, null, null, Hsla.red());
        final collections = new DecorationCollections<TextDecoration>();

        final first = collections.create(DecorationCollections.normalize(text, [new TextDecoration(r(2, 4), firstStyle)]));
        final second = collections.create(DecorationCollections.normalize(text, [new TextDecoration(r(5, 100), secondStyle)]));

        assertTrue(first != second);
        assertDecorations([new TextDecoration(r(1, 4), firstStyle)], collections.get(first));
        assertDecorations([new TextDecoration(r(5, 6), secondStyle)], collections.get(second));

        assertTrue(collections.append(first, [new TextDecoration(r(4, 5), secondStyle)]));
        assertDecorations([new TextDecoration(r(1, 4), firstStyle), new TextDecoration(r(4, 5), secondStyle)], collections.get(first));

        assertTrue(collections.set(first, []));
        assertDecorations([], collections.get(first));
        assertDecorations([new TextDecoration(r(5, 6), secondStyle)], collections.get(second));
    }

    function testDecorationRangesFollowTextEdits() {
        final style = new HighlightStyle();
        final collections = new DecorationCollections<TextDecoration>();
        final collection = collections.create([new TextDecoration(r(2, 6), style)]);

        collections.adjustForEdit(r(0, 0), 2);
        assertDecorations([new TextDecoration(r(4, 8), style)], collections.get(collection));

        collections.adjustForEdit(r(6, 6), 2);
        assertDecorations([new TextDecoration(r(4, 10), style)], collections.get(collection));

        collections.adjustForEdit(r(4, 10), 3);
        assertDecorations([new TextDecoration(r(4, 7), style)], collections.get(collection));

        assertTrue(r(4, 8).equals(DecorationCollections.adjustRangeForEdit(r(2, 6), r(2, 2), 2)));
        assertTrue(r(2, 6).equals(DecorationCollections.adjustRangeForEdit(r(2, 6), r(6, 6), 2)));
        assertTrue(r(2, 5).equals(DecorationCollections.adjustRangeForEdit(r(2, 6), r(2, 6), 3)));
    }

    function assertDecorations(expected:Array<TextDecoration>, actual:Null<Array<TextDecoration>>, ?pos:haxe.PosInfos) {
        assertNotNull(actual, null, pos);
        assertEquals(expected.length, actual.length, null, pos);
        for (i in 0...expected.length)
            assertTrue(expected[i].equals(actual[i]), 'decoration $i', pos);
    }

}
