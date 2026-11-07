// Ported from gpui-kit 0.8.1: crates/component/src/diff/tests.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FontStyle;
import gpui.FontWeight;
import gpui.HighlightStyle;
import gpui.IntoElement;
import gpui.ListOffset;
import gpui.Model;
import gpui.Range;
import gpui.Render;
import gpui.Window;
import gpui.base.input.HighlightStyleResolver;
import gpui.component.diff.DiffFile;
import gpui.component.diff.DiffLinePosition;
import gpui.component.diff.DiffLineRange;
import gpui.component.diff.DiffMode;
import gpui.component.diff.DiffSide;
import gpui.component.diff.Diff;
import gpui.component.diff.DiffState;
import gpui.component.diff.DiffState.DiffEvent;
import gpui.component.diff.Presentation.DiffStyledRange;
import tests.kit.ComponentDiffFixture as Fixture;

import gpui.Prelude.*;

/**
 * The state tests of gpui-kit's diff (`tests.rs`).
 */
class ComponentDiffStateTest extends KitTestCase {

    static function document(original:String, modified:String):DiffFile {
        return Fixture.modified('review.txt', original, modified);
    }

    static function contextDocument():DiffFile {
        final original = [for (line in 1...31) 'line $line\n'].join('');
        final modified = StringTools.replace(original, 'line 15\n', 'changed 15\n');
        return document(original, modified);
    }

    function newState(files:Array<DiffFile>):Entity<DiffState> {
        var state:Entity<DiffState> = null;
        app.update(cx -> state = cx.newEntity(cx -> new DiffState(files, cx)));
        return state;
    }

    function update(state:Entity<DiffState>, f:(DiffState, Context<DiffState>) -> Void):Void {
        app.update(cx -> state.update(cx, (s, cx) -> {
            f(s, cx);
            return null;
        }));
    }

    static function changedPairs(state:DiffState):String {
        return [
            for (row in @:privateAccess state.rows())
                switch (row) {
                    case Code(_, original, modified, true): '($original, $modified)';
                    default: null;
                }
        ].filter(s -> s != null).join(', ');
    }

    static function folds(state:DiffState):Array<Range> {
        return [
            for (row in @:privateAccess state.rows())
                switch (row) {
                    case Fold(_, pairs): pairs;
                    default: null;
                }
        ].filter(r -> r != null);
    }

    static function top(state:DiffState):Int {
        return @:privateAccess state.list().logicalScrollTop().itemIx;
    }

    static function sameRange(a:Null<DiffLineRange>, b:Null<DiffLineRange>):Bool {
        return DiffLineRange.same(a, b);
    }

    function testUnifiedChangesKeepDeletionsBeforeAdditionsAndSourceSelection() {
        final state = newState([document('head\nold one\nold two\ntail\n', 'head\nnew one\nnew two\nnew three\ntail\n')]);
        update(state, (state, cx) -> {
            assertEquals(Unified, state.mode());
            state.setMode(Split, cx);
            state.setContextLines(null, cx);
            state.setSelectedLines(new DiffLineRange('review.txt', Original, 2, 3), cx);
            @:privateAccess state.list().scrollTo(new ListOffset(2, 0.));
            state.setMode(Unified, cx);
            assertEquals(4, top(state));
            assertEquals('(1, null), (2, null), (null, 1), (null, 2), (null, 3)', changedPairs(state));
            assertTrue(sameRange(new DiffLineRange('review.txt', Original, 2, 3), state.selectedLines()));
            assertEquals('old one\nold two\n', state.selectedText(cx.app));

            state.setMode(Split, cx);
            assertEquals(2, top(state));
            assertEquals('(1, 1), (2, 2), (null, 3)', changedPairs(state));
            assertEquals('old one\nold two\n', state.selectedText(cx.app));
        });
    }

    function testContextDisclosuresRevealSourceRangesWithoutRetargetingSelection() {
        final state = newState([contextDocument()]);
        update(state, (state, cx) -> {
            state.setMode(Split, cx);
            state.setContextLines(1, cx);
            final found = folds(state);
            assertEquals('0..13,16..30', found.join(','));

            state.setSelectedLines(new DiffLineRange('review.txt', Modified, 14, 16), cx);
            @:privateAccess state.list().scrollTo(new ListOffset(3, 0.));
            @:privateAccess state.expandFold(0, found[0], All, cx);
            assertEquals(15, top(state));
            assertTrue(switch (@:privateAccess state.rows()[1]) {
                case Code(_, 0, 0, false): true;
                default: false;
            });
            assertEquals(1, folds(state).length);
            assertEquals('line 14\nchanged 15\nline 16\n', state.selectedText(cx.app));

            state.scrollToLine(new DiffLinePosition('review.txt', Original, 30), cx);
            assertEquals(30, top(state));
            assertEquals(0, folds(state).length);
            state.collapseUnchanged(cx);
            assertEquals(1, state.contextLines());
            assertTrue(sameRange(new DiffLineRange('review.txt', Modified, 14, 16), state.selectedLines()));
            state.expandUnchanged(cx);
            assertEquals(31, @:privateAccess state.rows().length);
            assertEquals(0, folds(state).length);

            // Rebuilt source maps must distinguish deletion and addition rows in
            // Unified, then point both source sides back to the paired Split row.
            state.setMode(Unified, cx);
            for (side in [DiffSide.Original, DiffSide.Modified]) {
                state.scrollToLine(new DiffLinePosition('review.txt', side, 15), cx);
                final row = @:privateAccess state.rows()[top(state)];
                assertTrue(switch [side, row] {
                    case [Original, Code(_, 14, null, _)]: true;
                    case [Modified, Code(_, null, 14, _)]: true;
                    default: false;
                }, 'row of $side');
            }
            state.setMode(Split, cx);
            for (side in [DiffSide.Original, DiffSide.Modified]) {
                state.scrollToLine(new DiffLinePosition('review.txt', side, 15), cx);
                assertEquals(15, top(state));
            }

            // An unavailable source line must not alter the current disclosure state.
            final count = @:privateAccess state.rows().length;
            state.scrollToLine(new DiffLinePosition('review.txt', Original, Fixture.MAX), cx);
            assertEquals(count, @:privateAccess state.rows().length);
            state.setContextLines(0, cx);
            assertEquals(4, @:privateAccess state.rows().length);
            assertEquals('line 14\nchanged 15\nline 16\n', state.selectedText(cx.app));
        });
    }

    function testSourceSelectionClampsRangesAndPreservesOriginalBytes() {
        final state = newState([document('\t旧值  \r\n\r\nlast', '\t新值  \r\n\r\nlast')]);
        update(state, (state, cx) -> {
            state.setSelectedLines(new DiffLineRange('review.txt', Original, Fixture.MAX, 0), cx);
            assertTrue(sameRange(new DiffLineRange('review.txt', Original, 1, 3), state.selectedLines()));
            assertEquals('\t旧值  \r\n\r\nlast', state.selectedText(cx.app));
            state.setSelectedLines(new DiffLineRange('review.txt', Modified, 2, Fixture.MAX), cx);
            assertEquals('\r\nlast', state.selectedText(cx.app));
            state.setSelectedLines(new DiffLineRange('review.txt', Original, 20, 30), cx);
            assertNull(state.selectedLines());
            assertEquals('', state.selectedText(cx.app));
            state.setSelectedLines(null, cx);
            assertEquals('', state.selectedText(cx.app));
        });

        final deleted = newState([Fixture.document(['deleted', 'one\n'], null)]);
        update(deleted, (state, cx) -> {
            state.setSelectedLines(new DiffLineRange('review.txt', Modified, 1, 2), cx);
            assertNull(state.selectedLines());
            assertEquals('', state.selectedText(cx.app));
        });
        final empty = newState([document('', '')]);
        update(empty, (state, cx) -> {
            state.setSelectedLines(new DiffLineRange('review.txt', Original, 1, 1), cx);
            assertNull(state.selectedLines());
            assertEquals('', state.selectedText(cx.app));
        });
    }

    function testChangeNavigationWrapsGroupsAndUnchangedDocumentsStayInPlace() {
        final state = newState([document('head\nold first\nmiddle\nold last\ntail\n', 'head\nnew first\nmiddle\nnew last\ntail\n')]);
        update(state, (state, cx) -> {
            state.setMode(Split, cx);
            state.setContextLines(null, cx);
            @:privateAccess state.list().scrollTo(new ListOffset());
            state.nextChange(cx);
            assertEquals(2, top(state));
            state.nextChange(cx);
            assertEquals(4, top(state));
            state.nextChange(cx);
            assertEquals(2, top(state));
            state.previousChange(cx);
            assertEquals(4, top(state));
            state.previousChange(cx);
            assertEquals(2, top(state));
        });

        final same = newState([document('one\ntwo\nthree\n', 'one\ntwo\nthree\n')]);
        update(same, (state, cx) -> {
            state.setContextLines(null, cx);
            @:privateAccess state.list().scrollTo(new ListOffset(1, 0.));
            state.nextChange(cx);
            state.previousChange(cx);
            assertEquals(1, top(state));
        });
    }

    function testControlledSelectionStaysSilentAndCoherentChangesNotify() {
        final state = newState([document('old\n', 'new\n')]);
        final events:Array<Null<DiffLineRange>> = [];
        var notifications = 0;
        final eventsSubscription = app.subscribe(state, DiffEvent, (_, event, _) -> {
            switch (event) {
                case SelectionChanged(range): events.push(range);
                default:
            }
        });
        final notificationsSubscription = app.observe(state, (_, _) -> notifications++);
        final range = new DiffLineRange('review.txt', Modified, 1, 1);
        update(state, (state, cx) -> state.setSelectedLines(range, cx));
        assertEquals(0, events.length);
        assertEquals(1, notifications);
        update(state, (state, cx) -> state.setSelectedLines(range, cx));
        assertEquals(1, notifications);
        update(state, (state, cx) -> state.setMode(Split, cx));
        assertEquals(0, events.length);
        assertEquals(2, notifications);
        update(state, (state, cx) -> state.setMode(Split, cx));
        assertEquals(2, notifications);
        update(state, (state, cx) -> state.setSelectedLines(null, cx));
        assertEquals(0, events.length);
        assertEquals(3, notifications);
        eventsSubscription.dispose();
        notificationsSubscription.dispose();
    }

    function testUserLineSelectionExtendsOnOneSideAndReplacementResetsSilently() {
        // This fixture needs a Window for focus and selection cleanup, but never
        // renders Component content. Rendered pointer/key paths live in Kit tests.
        final opened = openWindow(cx -> new EmptyView());
        final window = opened.window;
        final state = newState([document('old one\r\nold two\r\nold three', 'new one\r\nnew two\r\nnew three')]);
        final events:Array<Null<DiffLineRange>> = [];
        final subscription = app.subscribe(state, DiffEvent, (_, event, _) -> {
            switch (event) {
                case SelectionChanged(range): events.push(range);
                default:
            }
        });
        update(state, (state, cx) -> {
            @:privateAccess state.clickLine(new DiffLinePosition('review.txt', Original, 2), false, window, cx);
            assertTrue(@:privateAccess state.selection().hasLocalSelection(cx.app));
            // Base clears local participation synchronously, before its queued
            // notification reaches DiffState. Copy must stop immediately while
            // the retained gutter anchor still supports a subsequent extension.
            @:privateAccess state.selection().setLocalSelection(false, cx.app);
            assertEquals('', state.selectedText(cx.app));
            @:privateAccess state.keyboardSelect(1, true, window, cx);
            assertTrue(sameRange(new DiffLineRange('review.txt', Original, 2, 3), state.selectedLines()));
            assertEquals('old two\r\nold three', state.selectedText(cx.app));
            @:privateAccess state.keyboardSelect(-1, true, window, cx);
            assertTrue(sameRange(new DiffLineRange('review.txt', Original, 2, 2), state.selectedLines()));
            // Unified rows follow patch order, so Shift-click crosses sides.
            @:privateAccess state.clickLine(new DiffLinePosition('review.txt', Modified, 3), true, window, cx);
            assertTrue(sameRange(new DiffLineRange('review.txt', Original, 2, 3).withEndSide(Modified), state.selectedLines()));
            assertEquals('old two\r\nold three\nnew one\r\nnew two\r\nnew three', state.selectedText(cx.app));
            // Split columns are separate; changing side starts a new selection.
            state.setMode(Split, cx);
            @:privateAccess state.clickLine(new DiffLinePosition('review.txt', Original, 1), false, window, cx);
            @:privateAccess state.clickLine(new DiffLinePosition('review.txt', Modified, 3), true, window, cx);
            assertTrue(sameRange(new DiffLineRange('review.txt', Modified, 3, 3), state.selectedLines()));
            @:privateAccess state.selectAll(window, cx);
            assertEquals('new one\r\nnew two\r\nnew three', state.selectedText(cx.app));
            state.setFiles([Fixture.document(['replacement', 'one\ntwo\n'], null)], cx);
            assertNull(state.selectedLines());
            assertFalse(@:privateAccess state.selection().hasLocalSelection(cx.app));
            assertEquals('', state.selectedText(cx.app));
            assertEquals(0, top(state));
            assertEquals('replacement', state.files()[0].originalPath());
        });
        final expected = [
            new DiffLineRange('review.txt', Original, 2, 2),
            new DiffLineRange('review.txt', Original, 2, 3),
            new DiffLineRange('review.txt', Original, 2, 2),
            new DiffLineRange('review.txt', Original, 2, 3).withEndSide(Modified),
            new DiffLineRange('review.txt', Original, 1, 1),
            new DiffLineRange('review.txt', Modified, 3, 3),
            new DiffLineRange('review.txt', Modified, 1, 3),
        ];
        assertEquals(expected.length, events.length);
        for (i in 0...expected.length)
            assertTrue(i < events.length && sameRange(expected[i], events[i]), 'event $i: ${events[i]}');
        update(state, (state, cx) -> {
            @:privateAccess state.keyboardSelect(1, true, window, cx);
            assertTrue(sameRange(new DiffLineRange('replacement', Original, 1, 1), state.selectedLines()));
            @:privateAccess state.keyboardSelect(-1, true, window, cx);
            assertTrue(sameRange(new DiffLineRange('replacement', Original, 1, 1), state.selectedLines()));
        });
        assertEquals(8, events.length);
        subscription.dispose();
    }

    function testPatchNavigationAndSelectionUseSuppliedSourceCoordinates() {
        final document = DiffFile.parse('--- a/review.txt\n+++ b/review.txt\n@@ -100,2 +100,2 @@ first\n context 100\n-old 101\n+new 101\n@@ -200,2 +200,2 @@ second\n context 200\n-old 201\n+new 201\n')[0];
        final state = newState([document]);
        final opened = openWindow(cx -> new EmptyView());
        final window = opened.window;
        update(state, (state, cx) -> {
            assertEquals(2, Lambda.count(@:privateAccess state.rows(), r -> r.match(Hunk(_, _))));
            assertFalse(Lambda.exists(@:privateAccess state.rows(), r -> r.match(Fold(_, _))));
            @:privateAccess state.keyboardSelect(1, false, window, cx);
            assertEquals(100, state.selectedLines().start());
            @:privateAccess state.keyboardSelect(1, true, window, cx);
            @:privateAccess state.keyboardSelect(1, true, window, cx);
            assertTrue(sameRange(new DiffLineRange('review.txt', Modified, 100, 200), state.selectedLines()));
            assertEquals('context 100\nnew 101\ncontext 200\n', state.selectedText(cx.app));
            state.setSelectedLines(new DiffLineRange('review.txt', Modified, 105, 150), cx);
            assertNull(state.selectedLines());
            final before = @:privateAccess state.list().logicalScrollTop();
            state.scrollToLine(new DiffLinePosition('review.txt', Modified, 150), cx);
            assertEquals(before.itemIx, top(state));
            assertEquals(before.offsetInItem, @:privateAccess state.list().logicalScrollTop().offsetInItem);
        });
    }

    function testSettingOrClearingASyntaxHighlighterPreparesTheFilesAgain() {
        function firstWord(weight:FontWeight):(String, String) -> Array<DiffStyledRange> {
            final style = new HighlightStyle(null, weight);
            return (_, text) -> {
                final space = text.indexOf(' ');
                return [new DiffStyledRange(new Range(0, space == -1 ? gpui.util.Utf8.byteLength(text) : space), style)];
            };
        }
        final file = document('let a = 1;\n', 'let a = 2;\n').withLanguage('rust');
        var state:Entity<DiffState> = null;
        app.update(cx -> state = cx.newEntity(cx -> new DiffState([file], cx).withSyntaxHighlighter(firstWord(FontWeight.BOLD))));
        final keywordTheme = new KeywordTheme();
        function styles():Array<HighlightStyle> {
            update(state, (state, cx) -> @:privateAccess state.ensurePresentation(cx));
            runUntilParked();
            final presentation = @:privateAccess state.read(app).presentations()[0];
            assertNotNull(presentation, 'the file is prepared');
            if (presentation == null)
                return [];
            final line = file.lines(Modified)[0];
            return [for (s in presentation.syntaxHighlights(line, Modified, 0, keywordTheme)) s.style];
        }
        function weights(styles:Array<HighlightStyle>):String {
            return [for (s in styles) if (s.fontWeight != null) Std.string(s.fontWeight)].join(',');
        }
        assertEquals(Std.string(FontWeight.BOLD), weights(styles()));

        update(state, (state, cx) -> state.setSyntaxHighlighter(firstWord(FontWeight.LIGHT), cx));
        assertEquals(Std.string(FontWeight.LIGHT), weights(styles()));

        update(state, (state, cx) -> state.clearSyntaxHighlighter(cx));
        final cleared = styles();
        assertEquals('', weights(cleared), "the application's styles are gone");
        // With the grammar (tree-sitter-rust in Rust), GPUI Kit highlights `let`
        // again; the reference builds without it, so does this test.
    }

}

private class KeywordTheme implements HighlightStyleResolver {

    public function new() {}

    /** Paints GPUI Kit's `keyword` captures italic and nothing else. */
    public function style(name:String):Null<HighlightStyle> {
        return name == 'keyword' ? new HighlightStyle(null, null, FontStyle.Italic) : null;
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
