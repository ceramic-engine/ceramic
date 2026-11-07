// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/search.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Range;
import glaze.kit.base.input.SearchMatcher;
import glaze.kit.base.input.SearchSession;
import ropey.Rope;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.input.SearchMatcher` and `SearchSession` (Rust `search.rs`).
 */
class InputSearchTest extends TestCase {

    static inline function r(a:Int, b:Int):Range {
        return new Range(a, b);
    }

    static function list(ranges:Array<Range>):String {
        return [for (range in ranges) range.toString()].join(',');
    }

    function testFindsNavigatesAndPreservesReplacementPosition() {
        final matcher = new SearchMatcher();
        matcher.update(Rope.fromStr("foo FOO foo"));
        matcher.updateQuery("foo", true);
        assertEquals(list([r(0, 3), r(4, 7), r(8, 11)]), list(matcher.matchedRanges()));
        assertTrue(r(4, 7).equals(matcher.next()));
        assertTrue(r(0, 3).equals(matcher.nextBack()));

        matcher.setCurrentMatchIndex(2);
        matcher.beginReplacement();
        matcher.update(Rope.fromStr("foo FOO bar"));
        assertEquals(1, matcher.currentMatchIndex());
    }

    function testNextWrapsToStart() {
        final matcher = new SearchMatcher();
        matcher.update(Rope.fromStr(".....aaaaa.....aaaaa.....aaaaa"));
        matcher.updateQuery("aaaaa", false);
        matcher.setCurrentMatchIndex(2);
        assertTrue(r(5, 10).equals(matcher.next()));
    }

    function testAQuerySetWithoutThePanelKeepsTheSessionActiveUntilClosed() {
        final session = SearchSession.defaultValue();
        assertFalse(session.isActive());

        session.openPanel(false, true);
        assertTrue(session.isActive());
        session.close();
        assertFalse(session.isActive());

        // A custom search UI never opens the panel; setting a query is what
        // turns the match highlights on, and closing turns them off again.
        session.activate();
        assertTrue(session.isActive());
        assertFalse(session.open);
        session.close();
        assertFalse(session.isActive());
    }

    function testIdenticalQueryKeepsTheCurrentMatch() {
        final session = SearchSession.defaultValue();
        session.updateQuery("foo", true);
        session.matcher.update(Rope.fromStr("foo bar foo baz foo"));
        session.matcher.updateCursorByOffset(12);
        assertEquals(2, session.matcher.currentMatchIndex());

        // Reopening Find and the styled search panel's initial query echo both
        // update the session with the same query. Neither should reset the
        // previously active occurrence.
        session.updateQuery("foo", true);

        assertEquals(2, session.matcher.currentMatchIndex());
        assertEquals("3/3", session.matcher.label());
    }

    function testReplacementKeepsCurrentMatchIndexOnNextMatch() {
        final matcher = new SearchMatcher();
        matcher.update(Rope.fromStr("foo foo foo"));
        matcher.updateQuery("foo", true);
        assertEquals("1/3", matcher.label());

        assertTrue(matcher.hasNextWithoutWrap());
        matcher.beginReplacement();
        matcher.update(Rope.fromStr("bar foo foo"));
        assertEquals(0, matcher.currentMatchIndex());
        assertTrue(r(4, 7).equals(matcher.matchedRanges()[0]));
        assertEquals("1/2", matcher.label());

        matcher.setCurrentMatchIndex(1);
        assertFalse(matcher.hasNextWithoutWrap());
        matcher.setCurrentMatchIndex(0);
        matcher.beginReplacement();
        matcher.update(Rope.fromStr("bar foo bar"));
        assertEquals(0, matcher.currentMatchIndex());
        assertTrue(r(4, 7).equals(matcher.matchedRanges()[0]));
        assertEquals("1/1", matcher.label());
    }

    function testUpdateMatchesClampsCurrentMatchIndexWhileReplacing() {
        final matcher = new SearchMatcher();
        matcher.update(Rope.fromStr("foo foo foo"));
        matcher.updateQuery("foo", true);
        matcher.setCurrentMatchIndex(2);
        matcher.beginReplacement();

        matcher.update(Rope.fromStr("foo xoo foo"));

        assertEquals(2, matcher.len());
        assertEquals(1, matcher.currentMatchIndex());
        assertEquals("2/2", matcher.label());
    }

}
