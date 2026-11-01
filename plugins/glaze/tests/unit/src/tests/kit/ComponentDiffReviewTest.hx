// Ported from gpui-kit 0.8.1: crates/component/src/diff/review_tests.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.ListOffset;
import gpui.Model;
import gpui.Range;
import gpui.Render;
import gpui.Subscription;
import gpui.Window;
import gpui.component.diff.DiffConflictResolution;
import gpui.component.diff.DiffFile;
import gpui.component.diff.DiffFileStatus;
import gpui.component.diff.DiffInlineUnit;
import gpui.component.diff.DiffLinePosition;
import gpui.component.diff.DiffLineRange;
import gpui.component.diff.DiffMode;
import gpui.component.diff.DiffSide;
import gpui.component.diff.DiffState;
import gpui.component.diff.DiffState.DiffEvent;
import gpui.component.diff.DiffState.DisplayRow;
import tests.kit.ComponentDiffFixture as Fixture;

import gpui.Prelude.*;

/**
 * The review tests of gpui-kit's diff (`review_tests.rs`).
 */
class ComponentDiffReviewTest extends KitTestCase {

    static final PATCH = 'diff --git a/first.txt b/first.txt\n--- a/first.txt\n+++ b/first.txt\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\ndiff --git a/second.txt b/second.txt\n--- a/second.txt\n+++ b/second.txt\n@@ -10 +10 @@\n-ten\n+TEN\n';

    function newState(build:Context<DiffState>->DiffState):Entity<DiffState> {
        var state:Entity<DiffState> = null;
        app.update(cx -> state = cx.newEntity(build));
        return state;
    }

    function update(state:Entity<DiffState>, f:(DiffState, Context<DiffState>) -> Void):Void {
        app.update(cx -> state.update(cx, (s, cx) -> {
            f(s, cx);
            return null;
        }));
    }

    function recordEvents(state:Entity<DiffState>):{events:Array<DiffEvent>, subscription:Subscription} {
        final events = [];
        final subscription = app.subscribe(state, DiffEvent, (_, event, _) -> events.push(event));
        return {events: events, subscription: subscription};
    }

    static function codeRows(state:DiffState, file:Int):Int {
        return Lambda.count(@:privateAccess state.rows(), row -> switch (row) {
            case Code(f, _, _, _): f == file;
            default: false;
        });
    }

    static function folds(state:DiffState):String {
        return [
            for (row in @:privateAccess state.rows())
                switch (row) {
                    case Fold(_, pairs): pairs.toString();
                    default: null;
                }
        ].filter(s -> s != null).join(',');
    }

    function testCollapsedFilesKeepTheirHeaderAndSurviveReplacement() {
        final state = newState(cx -> new DiffState(DiffFile.parse(PATCH), cx));
        final recorded = recordEvents(state);
        update(state, (state, cx) -> {
            assertTrue(codeRows(state, 0) > 0);
            state.setFileCollapsed('first.txt', true, cx);
            assertTrue(state.isFileCollapsed('first.txt'));
            assertEquals(0, codeRows(state, 0));
            assertTrue(@:privateAccess state.rows()[0].match(File(0)));
            assertTrue(@:privateAccess state.rows()[1].match(File(1)));
            // Programmatic changes stay silent; the header toggle reports.
            @:privateAccess state.toggleFileCollapsed(1, cx);
            assertTrue(state.isFileCollapsed('second.txt'));

            // Revealing a line expands its file.
            state.scrollToLine(new DiffLinePosition('first.txt', Modified, 2), cx);
            assertFalse(state.isFileCollapsed('first.txt'));

            // Paths identify files, so collapse survives a newer patch revision.
            final files = DiffFile.parse(PATCH);
            files.reverse();
            state.setFiles(files, cx);
            assertTrue(state.isFileCollapsed('second.txt'));
            state.scrollToFile('first.txt', cx);
            assertEquals(1, @:privateAccess state.list().logicalScrollTop().itemIx);
            state.scrollToFile('missing.txt', cx);
            assertEquals(1, @:privateAccess state.list().logicalScrollTop().itemIx);
        });
        assertEquals(1, recorded.events.length);
        assertTrue(switch (recorded.events[0]) {
            case FileCollapsed(path): path == 'second.txt';
            default: false;
        });
        recorded.subscription.dispose();
    }

    function testFoldsExpandByDirectionAndShortRangesStayVisible() {
        final original = [for (line in 1...61) 'line $line\n'].join('');
        final modified = StringTools.replace(StringTools.replace(original, 'line 30\n', 'changed 30\n'), 'line 60\n', 'changed 60\n');
        var file = Fixture.modified('long.txt', original, modified);
        var state = newState(cx -> new DiffState([file], cx).withContextLines(2).withExpansionLines(5));
        update(state, (state, cx) -> {
            assertEquals('0..27,32..57', folds(state));
            @:privateAccess state.expandFold(0, new Range(32, 57), Down, cx);
            assertEquals('0..27,37..57', folds(state));
            @:privateAccess state.expandFold(0, new Range(37, 57), Up, cx);
            assertEquals('0..27,37..52', folds(state));
            @:privateAccess state.expandFold(0, new Range(0, 27), All, cx);
            assertEquals('37..52', folds(state));
            state.collapseUnchanged(cx);
            assertEquals('0..27,32..57', folds(state));
        });

        // With a high threshold, ranges shorter than it are never collapsed.
        file = Fixture.modified('long.txt', original, modified);
        state = newState(cx -> new DiffState([file], cx).withContextLines(2).withMinCollapsedLines(26));
        update(state, (state, _) -> {
            assertEquals('0..27', folds(state));
            assertEquals(26, state.minCollapsedLines());
            assertEquals(20, state.expansionLines());
        });
    }

    function testLineSelectionReportsAGestureLifecycle() {
        final window = openWindow(cx -> new EmptyView()).window;
        final state = newState(cx -> new DiffState(DiffFile.parse(PATCH), cx));
        final recorded = recordEvents(state);
        function position(side:DiffSide, line:Int) {
            return new DiffLinePosition('first.txt', side, line);
        }
        update(state, (state, cx) -> {
            @:privateAccess state.beginLineSelection(position(Original, 1), false, window, cx);
            @:privateAccess state.dragLineSelection(position(Original, 2), cx);
            // A drag into another file does not extend the selection.
            @:privateAccess state.dragLineSelection(new DiffLinePosition('second.txt', Original, 10), cx);
            // In Unified, dragging onto the addition crosses sides.
            @:privateAccess state.dragLineSelection(position(Modified, 2), cx);
            @:privateAccess state.endLineSelection(cx);
            @:privateAccess state.endLineSelection(cx);
        });
        final cross = new DiffLineRange('first.txt', Original, 1, 2).withEndSide(Modified);
        final events = recorded.events;
        assertTrue(switch (events[0]) {
            case SelectionStarted(range): range.equals(new DiffLineRange('first.txt', Original, 1, 1));
            default: false;
        });
        assertTrue(switch (events[1]) {
            case SelectionChanged(range): range != null && range.equals(new DiffLineRange('first.txt', Original, 1, 1));
            default: false;
        });
        assertTrue(switch (events[2]) {
            case SelectionChanged(range): range != null && range.equals(new DiffLineRange('first.txt', Original, 1, 2));
            default: false;
        });
        assertTrue(switch (events[3]) {
            case SelectionChanged(range): range != null && range.equals(cross);
            default: false;
        });
        assertTrue(switch (events[4]) {
            case SelectionEnded(range): range.equals(cross);
            default: false;
        });
        assertEquals(5, events.length);
        final read = state.read(app);
        assertTrue(DiffLineRange.same(cross, read.selectedLines()));
        assertEquals('one\ntwo\nTWO\n', read.selectedText(app));
        recorded.subscription.dispose();
    }

    function testProgrammaticCrossSideRangesClipToSuppliedLines() {
        final state = newState(cx -> new DiffState(DiffFile.parse(PATCH), cx));
        update(state, (state, cx) -> {
            state.setSelectedLines(new DiffLineRange('first.txt', Original, 2, 99).withEndSide(Modified), cx);
            assertTrue(DiffLineRange.same(new DiffLineRange('first.txt', Original, 2, 3).withEndSide(Modified), state.selectedLines()));
            assertEquals('two\nTWO\nthree\n', state.selectedText(cx.app));
            // A single-side range is normalized.
            state.setSelectedLines(new DiffLineRange('first.txt', Modified, 3, 1), cx);
            assertTrue(DiffLineRange.same(new DiffLineRange('first.txt', Modified, 1, 3), state.selectedLines()));
            @:privateAccess state.list().scrollTo(new ListOffset());
        });
    }

    function testFilesReportGitStatusAndHiddenLines() {
        final files = DiffFile.parse('diff --git a/new b/new\nnew file mode 100644\n--- /dev/null\n+++ b/new\n@@ -0,0 +1 @@\n+a\n'
            + 'diff --git a/old b/old\ndeleted file mode 100644\n--- a/old\n+++ /dev/null\n@@ -1 +0,0 @@\n-a\n'
            + 'diff --git a/from b/to\nsimilarity index 100%\nrename from from\nrename to to\n'
            + 'diff --git a/src b/copy\nsimilarity index 100%\ncopy from src\ncopy to copy\n'
            + 'diff --git a/edit b/edit\n--- a/edit\n+++ b/edit\n@@ -5,2 +5,2 @@\n x\n-y\n+z\n@@ -20 +20 @@\n-p\n+q\n');
        final expected:Array<DiffFileStatus> = [Added, Deleted, Renamed, Copied, Modified];
        assertEquals(expected.length, files.length);
        for (i in 0...expected.length)
            assertTrue(expected[i] == files[i].status(), 'status $i');
        final hunks = files[4].hunks();
        assertEquals(4, hunks[0].hiddenLinesBefore(null));
        assertEquals(13, hunks[1].hiddenLinesBefore(hunks[0]));
        final added = files[0].hunks();
        assertEquals(0, added[0].hiddenLinesBefore(null));
    }

    static final MERGE = 'start\n<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> feature\nmiddle\n<<<<<<< HEAD\na\n||||||| base\nb\n=======\nc\n>>>>>>> other\nend\n';

    function testConflictsProjectTheirPartsAndResolveToWorkingText() {
        final file = DiffFile.parseConflicts('merge.txt', MERGE);
        final state = newState(cx -> new DiffState([file], cx).withMode(Split).withContextLines(null));
        final recorded = recordEvents(state);
        function conflictRows(state:DiffState):Int {
            return Lambda.count(@:privateAccess state.rows(), row -> row.match(Conflict(_, _, _)));
        }
        update(state, (state, cx) -> {
            // Two parts for the first conflict, three with its base for the second.
            assertEquals(5, conflictRows(state));
            assertEquals(8, codeRows(state, 0));
            assertNull(state.resolvedText('merge.txt'));
            state.resolveConflict('merge.txt', 0, DiffConflictResolution.Incoming, cx);
            assertEquals(4, conflictRows(state));
            assertNull(state.resolvedText('merge.txt'));
            @:privateAccess state.chooseConflict(0, 1, DiffConflictResolution.Both, cx);
            assertEquals('start\ntheirs\nmiddle\na\nc\nend\n', state.resolvedText('merge.txt'));
            assertEquals(DiffConflictResolution.Both, state.conflictResolution('merge.txt', 1));
            @:privateAccess state.chooseConflict(0, 1, null, cx);
            assertNull(state.conflictResolution('merge.txt', 1));
            // Out-of-range conflicts and other files are ignored.
            state.resolveConflict('merge.txt', 9, DiffConflictResolution.Current, cx);
            assertNull(state.resolvedText('other.txt'));
        });
        assertEquals(2, recorded.events.length);
        assertTrue(Lambda.foreach(recorded.events, e -> switch (e) {
            case ConflictResolved(path, 1): path == 'merge.txt';
            default: false;
        }));
        recorded.subscription.dispose();
    }

    function testUnchangedFilesShowEveryLineWithoutFolding() {
        final text = [for (line in 1...41) 'line $line\n'].join('');
        final state = newState(cx -> new DiffState([DiffFile.unchanged('notes.txt', text)], cx).withMode(Split));
        update(state, (state, cx) -> {
            assertEquals(40, codeRows(state, 0));
            assertFalse(Lambda.exists(@:privateAccess state.rows(), r -> r.match(Fold(_, _))));
            state.setSelectedLines(new DiffLineRange('notes.txt', Modified, 2, 3), cx);
            assertEquals('line 2\nline 3\n', state.selectedText(cx.app));
        });
    }

    function testBuildersAfterNewShapeThePreparedEmphasis() {
        final patch = '--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-let total = price;\n+let total = cost;\n';
        function inlineCount(state:Entity<DiffState>):Int {
            update(state, (state, cx) -> @:privateAccess state.ensurePresentation(cx));
            runUntilParked();
            final s = state.read(app);
            final file = s.files()[0];
            final line = file.lines(Modified)[0];
            final presentation = @:privateAccess s.presentations()[0];
            assertNotNull(presentation, 'prepared in the background');
            return presentation == null ? -1 : presentation.inlineChanges(line, Modified, 0).length;
        }
        final words = newState(cx -> new DiffState(DiffFile.parse(patch), cx));
        assertEquals(1, inlineCount(words));
        final wholeLines = newState(cx -> new DiffState(DiffFile.parse(patch), cx).withInlineUnit(null));
        assertEquals(0, inlineCount(wholeLines));
        // Runtime changes invalidate earlier work, including an in-flight preparation.
        update(words, (state, cx) -> {
            state.setInlineUnit(null, cx);
            state.setInlineUnit(DiffInlineUnit.Character, cx);
        });
        assertTrue(inlineCount(words) > 0);
        update(words, (state, cx) -> state.setInlineMaxLineLength(5, cx));
        assertEquals(0, inlineCount(words));
        update(words, (state, cx) -> {
            state.setInlineMaxLineLength(2048, cx);
            state.setInlineUnit(DiffInlineUnit.Word, cx);
        });
        assertEquals(1, inlineCount(words));
    }

    function testChangingPresentationOptionsKeepsSelectionAndScroll() {
        final state = newState(cx -> new DiffState(DiffFile.parse(PATCH), cx));
        final recorded = recordEvents(state);
        update(state, (state, cx) -> {
            final range = new DiffLineRange('second.txt', Modified, 10, 10);
            state.setSelectedLines(range, cx);
            state.scrollToLine(@:privateAccess range.startPosition(), cx);
            final top = @:privateAccess state.list().logicalScrollTop();
            state.setInlineUnit(DiffInlineUnit.Character, cx);
            state.setInlineMaxLineLength(2048, cx);
            state.setSyntaxMaxLineLength(4096, cx);
            state.setExpansionLines(5, cx);
            state.setMinCollapsedLines(4, cx);
            assertTrue(DiffLineRange.same(range, state.selectedLines()));
            assertEquals(top.itemIx, @:privateAccess state.list().logicalScrollTop().itemIx);
            assertEquals(DiffInlineUnit.Character, state.inlineUnit());
            assertEquals(2048, state.inlineMaxLineLength());
            assertEquals(4096, state.syntaxMaxLineLength());
            assertEquals(5, state.expansionLines());
            assertEquals(4, state.minCollapsedLines());
            // Null disables emphasis, without replacing the entity or patch.
            state.setInlineUnit(null, cx);
            assertNull(state.inlineUnit());
            assertEquals(2, state.files().length);
        });
        assertEquals(0, recorded.events.length);
        recorded.subscription.dispose();
    }

}

private class EmptyView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}
