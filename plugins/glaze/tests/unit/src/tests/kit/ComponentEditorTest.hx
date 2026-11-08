// Ported from gpui-kit 0.8.1: crates/component/src/input/editor.rs, crates/component/src/input/search.rs,
// crates/component/src/input/overlay.rs, crates/component/src/input/language_config.rs,
// crates/component/src/input/popovers/completion_menu.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.Range;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.input.AutoClosingPair;
import glaze.kit.base.input.CodeActionItem;
import glaze.kit.base.input.CompletionItem;
import glaze.kit.base.input.Diagnostic;
import glaze.kit.base.input.DiagnosticEntry;
import glaze.kit.base.input.EditorLanguage.Languages;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.LanguageConfig;
import glaze.kit.base.input.LspCodeAction;
import glaze.kit.base.input.LspHover;
import glaze.kit.base.input.SearchMatcher;
import glaze.kit.Size;
import glaze.kit.input.CompletionMenu;
import glaze.kit.input.ComponentLanguages;
import glaze.kit.input.Editor;
import glaze.kit.input.InputOverlays;
import glaze.kit.input.SearchPanel;
import ropey.Rope;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.input.InputLspExt;
using glaze.kit.base.input.InputSearchExt;
using glaze.kit.Size.SizeTools;

/**
 * Tests of the styled code editor: `Editor` (`editor.rs`), the search panel
 * (`search.rs`), the overlay host (`overlay.rs`), the language defaults
 * (`language_config.rs`) and the completion menu (`completion_menu.rs`).
 *
 * Not ported: the tests behind gpui-kit's `tree-sitter` features
 * (`syntax_follows_language_before_first_render_and_after_switch`,
 * `python_pairing_uses_pre_edit_context`,
 * `generated_comment_closer_survives_syntax_changes` and every test of
 * `syntax_context.rs`): the port has no tree-sitter, like gpui-kit built
 * without those features.
 */
@:access(glaze.kit.input)
@:access(glaze.kit.base.input.InputBaseState)
class ComponentEditorTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var opened:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        opened = [];
    }

    override function teardown() {
        for (cx in opened) cx.destroy();
        opened = [];
        InputOverlays.focusOnSync = true;
        ceramic.App.app.flushImmediate();
    }

    function addWindowView<V:Model & Render>(build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        final result = VisualTestContext.addWindowView(app, dispatcher, build);
        opened.push(result.cx);
        return result;
    }

    /**
     * Rust `cx.update(crate::init)`. gpui's test platform resolves any font;
     * the port's text system only has Inter and JetBrains Mono, so the
     * theme's monospace family (Menlo on macOS) is set to JetBrains Mono.
     */
    function init():Void {
        app.update(cx -> {
            glaze.kit.theme.Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            glaze.kit.theme.Theme.syncBase(cx);
        });
    }

    static inline function base<T:InputBaseState>(state:Entity<T>):Entity<InputBaseState> {
        return cast state;
    }

/// editor.rs

    /** The row height the editor laid out with, which follows its font size. */
    function lineHeight(textSize:Null<Pixels>):Float {
        init();
        var state:Entity<EditorState> = null;
        final opened = addWindowView((window, cx) -> {
            final editor = cx.newEntity((c:Context<EditorState>) -> (new EditorState(window, c).defaultValue("fn main() {}") : EditorState));
            state = editor;
            return new Harness(editor, textSize);
        });
        opened.cx.update((window, _) -> window.draw());

        final lineHeight = state.read(app).lineHeight();
        assertNotNull(lineHeight, "the editor must lay out");
        return lineHeight;
    }

    function testTheRowsFollowTheFontSize() {
        // With nothing set, the theme's monospace size, not the ambient one.
        assertEquals(20., lineHeight(null));
        // A text style set on the editor refines over that, rows and all.
        assertEquals(36., lineHeight(24.));
        assertEquals(60., lineHeight(40.));
    }

    /**
     * How far the text starts below the top of the editor's frame, and the
     * row height it laid out with.
     */
    function topInset(size:Null<Size>):{inset:Float, lineHeight:Float} {
        init();
        var state:Entity<EditorState> = null;
        final frame = new BoundsCell();
        final opened = addWindowView((window, cx) -> {
            final editor = cx.newEntity((c:Context<EditorState>) -> (new EditorState(window, c).defaultValue("fn main() {}") : EditorState));
            state = editor;
            return new SizedHarness(editor, size, frame);
        });
        opened.cx.update((window, _) -> window.draw());

        assertNotNull(frame.bounds, "the frame must lay out");
        final s = state.read(app);
        final lineHeight = s.lineHeight();
        assertNotNull(lineHeight, "the editor must lay out");
        return {inset: s.inputBounds.top() - frame.bounds.top(), lineHeight: lineHeight};
    }

    function testTheInsetsFollowTheSize() {
        final medium = topInset(Medium);
        // With no size set, the editor keeps the medium insets it always had.
        final unset = topInset(null);
        assertEquals(medium.inset, unset.inset);
        assertEquals(medium.lineHeight, unset.lineHeight);
        for (size in [XSmall, Small, Large]) {
            final result = topInset(size);
            assertEquals(Medium.inputPy() - size.inputPy(), medium.inset - result.inset, '$size');
            // Only the insets change, not the font.
            assertEquals(medium.lineHeight, result.lineHeight, '$size');
        }
    }

    function testLanguageConfigWorksWithoutRenderSync() {
        init();
        var state:Entity<EditorState> = null;
        final opened = addWindowView((window, cx) -> {
            final editor = cx.newEntity((c:Context<EditorState>) -> new EditorState(window, c).language("plaintext"));
            // Plain-text defaults apply before the first render.
            editor.update(cx, (state, cx) -> {
                state.replaceTextInRange(null, "(", window, cx);
                assertEquals("(", state.text.toString());
                state.setValue("", window, cast cx);
                state.setHighlighter("json", cast cx);
                state.replaceTextInRange(null, "[", window, cx);
                assertEquals("[]", state.text.toString());
            });
            state = editor;
            return new Harness(editor, null);
        });
        final cx = opened.cx;
        cx.update((_, cx) -> {
            Languages.setLanguageConfig("json", new LanguageConfig().withAutoClosingPairs([new AutoClosingPair("«", "»")]), cx);
        });
        // A styled render must preserve the registered configuration.
        cx.update((window, _) -> window.draw());
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> {
                state.setValue("", window, cast cx);
                state.replaceTextInRange(null, "«", window, cx);
                assertEquals("«»", state.text.toString());
                state.setValue("if enabled:", window, cast cx);
                state.setSelectedRange(new Range(11, 11), cast cx);
                state.setHighlighter("python", cast cx);
                state.focus(window, cast cx);
            });
        });
        cx.update((window, _) -> window.draw());
        cx.simulateKeystrokes("enter");
        assertEquals("if enabled:\n  ", state.read(app).text.toString());
    }

    function testAliasesShareConfigEvenWhenRegisteredBeforeInit() {
        app.update(cx -> Languages.setLanguageConfig("py", new LanguageConfig().withAutoClosingPairs([new AutoClosingPair("«", "»")]), cx));
        init();
        addWindowView((window, cx) -> {
            final editor = cx.newEntity((c:Context<EditorState>) -> new EditorState(window, c).language("PYTHON"));
            editor.update(cx, (state, cx) -> {
                state.replaceTextInRange(null, "«", window, cx);
                assertEquals("«»", state.text.toString());
            });
            Languages.setLanguageConfig("pyi", new LanguageConfig().withAutoClosingPairs([]), cx.app);
            editor.update(cx, (state, cx) -> {
                state.setValue("", window, cast cx);
                state.setHighlighter("py", cast cx);
                state.replaceTextInRange(null, "(", window, cx);
                assertEquals("(", state.text.toString());
            });
            return new Harness(editor, null);
        });
    }

    function testOnPasteBuilder() {
        init();
        addWindowView((window, cx) -> {
            final state = cx.newEntity((c:Context<EditorState>) -> new EditorState(window, c));
            assertNull(new Editor(state).pasteHandler);
            final editor = new Editor(state).onPaste((_, _, _) -> true);
            assertNotNull(editor.pasteHandler);
            return new PasteProbe();
        });
    }

/// language_config.rs

    function testPlainTextHasNoEditingRules() {
        final rules = ComponentLanguages.defaultLanguageConfig("text");
        assertEquals(0, rules.brackets.length);
        assertEquals(0, rules.autoClosingPairs.length);
        assertNull(rules.indentationRules);
    }

    function testJsonOnlyClosesJsonDelimiters() {
        final rules = ComponentLanguages.defaultLanguageConfig("json");
        final pairs = rules.autoClosingPairs;
        assertEquals(3, pairs.length);
        for (p in pairs) {
            assertTrue(p.open != "'" && p.open != "(");
        }
    }

    function testColonIndentationIsLanguageSpecific() {
        assertTrue(ComponentLanguages.defaultLanguageConfig("python").indentationRules.increaseIndentPattern.match("if enabled:"));
        for (language in ["rust", "javascript", "json", "unknown"]) {
            assertNull(ComponentLanguages.defaultLanguageConfig(language).indentationRules);
        }
    }

/// search.rs

    static function rangeString(range:Null<Range>):String {
        return range == null ? 'None' : '${range.start}..${range.end}';
    }

    function testSearch() {
        final matcher = new SearchMatcher();
        matcher.update(Rope.fromStr("Hello 世界 this is a Is test string."));
        matcher.updateQuery("Is", true);

        assertEquals(3, matcher.len());
        final matches = matcher.clone();
        assertEquals(0, matches.currentMatchIndex());
        assertEquals('18..20', rangeString(matches.next()));
        assertEquals('23..25', rangeString(matches.next()));
        assertEquals(2, matches.currentMatchIndex());
        assertEquals('15..17', rangeString(matches.next()));
        assertEquals(0, matches.currentMatchIndex());
        assertEquals('23..25', rangeString(matches.nextBack()));
        assertEquals(2, matches.currentMatchIndex());
        assertEquals('18..20', rangeString(matches.nextBack()));
        assertEquals(1, matches.currentMatchIndex());
        assertEquals('15..17', rangeString(matches.nextBack()));
        assertEquals(0, matches.currentMatchIndex());
        assertEquals('23..25', rangeString(matches.nextBack()));

        matcher.updateQuery("IS", false);
        assertEquals(0, matcher.len());
        assertEquals('None', rangeString(matcher.next()));
        assertEquals('None', rangeString(matcher.nextBack()));
    }

    function testSearchLabel() {
        final matcher = new SearchMatcher();
        matcher.update(Rope.fromStr("Hello 世界 this is a Is test string."));
        matcher.updateQuery("Is", true);
        assertEquals("1/3", matcher.label());
        matcher.next();
        assertEquals("2/3", matcher.label());
        matcher.next();
        assertEquals("3/3", matcher.label());
        matcher.next();
        assertEquals("1/3", matcher.label());

        matcher.updateQuery("IS", false);
        assertEquals("0/0", matcher.label());
    }

    function testSelectRangeStart() {
        final matcher = new SearchMatcher();
        matcher.update(Rope.fromStr(".....aaaaa.....aaaaa.....aaaaa"));
        matcher.updateQuery("aaaaa", false);
        matcher.updateCursorByOffset(0);
        assertEquals(0, matcher.currentMatchIndex());

        matcher.updateCursorByOffset(5);
        assertEquals(0, matcher.currentMatchIndex());

        matcher.updateCursorByOffset(12);
        assertEquals(1, matcher.currentMatchIndex());

        matcher.updateCursorByOffset(16);
        assertEquals(1, matcher.currentMatchIndex());

        matcher.updateCursorByOffset(30);
        assertEquals(2, matcher.currentMatchIndex());

        matcher.updateCursorByOffset(31);
        assertEquals(2, matcher.currentMatchIndex());
    }

    function testNextScrollDirectionReturnsDownWithoutWrap() {
        assertTrue(SearchScroll.nextScrollDirection(0, 1) == glaze.kit.base.input.MoveDirection.Down);
    }

    function testNextScrollDirectionReturnsNoneOnWrap() {
        assertNull(SearchScroll.nextScrollDirection(2, 0));
    }

    function testNextScrollDirectionReturnsNoneForSingleMatch() {
        assertNull(SearchScroll.nextScrollDirection(0, 0));
    }

    function testPrevScrollDirectionReturnsUpWithoutWrap() {
        assertTrue(SearchScroll.prevScrollDirection(2, 1) == glaze.kit.base.input.MoveDirection.Up);
    }

    function testPrevScrollDirectionReturnsNoneOnWrap() {
        assertNull(SearchScroll.prevScrollDirection(0, 2));
    }

    function testPrevScrollDirectionReturnsNoneForSingleMatch() {
        assertNull(SearchScroll.prevScrollDirection(0, 0));
    }

/// Port regression: rendering inputs while the overlay registry exists

    /**
     * Port only. Every input reads the overlay registry while it renders; a
     * tracked read followed by a mutation through `globalMut` invalidated the
     * view that was rendering, so an open search panel and any other input
     * re-rendered each other forever (seen in the web golden runs, which
     * draw on every frame). The views must render without writing what they
     * read.
     */
    function testRenderingInputsWithAnOpenOverlayWritesNothingTheyRead() {
        init();
        final savedCheck = glaze.ViewTracker.checkWritesDuringCapture;
        final savedHook = glaze.ViewTracker.onWriteDuringCapture;
        final writes:Array<String> = [];
        glaze.ViewTracker.checkWritesDuringCapture = true;
        glaze.ViewTracker.onWriteDuringCapture = tracker -> writes.push(tracker.name);
        var state:Entity<EditorState> = null;
        final opened = addWindowView((window, cx) -> {
            state = cx.newEntity((c:Context<EditorState>) -> (new EditorState(window, c).defaultValue("let value = 1;\nvalue + 2\n") : EditorState));
            return new Harness(state, null);
        });
        opened.cx.update((window, cx) -> state.update(cx, (state, cx) -> {
            state.focus(window, cast cx);
            state.setSelectedRange(new Range(4, 9), cast cx);
            state.openSearch(true, cast cx);
        }));
        for (_ in 0...4) {
            opened.cx.runUntilParked();
            opened.cx.update((window, _) -> {
                window.refresh();
                window.draw();
            });
        }
        glaze.ViewTracker.checkWritesDuringCapture = savedCheck;
        glaze.ViewTracker.onWriteDuringCapture = savedHook;
        assertTrue(state.read(app).searchSession.open);
        assertEquals('', writes.join(','));
    }

/// popovers/completion_menu.rs

    static function rangesString(ranges:Array<Range>):String {
        return [for (range in ranges) rangeString(range)].join(',');
    }

    function testHighlightRangesAreOrderedAndDoNotOverlap() {
        assertEquals('0..1,2..3', rangesString(CompletionMenu.retainedHighlightRanges("flag", [new Range(2, 3), new Range(0, 1)])));
        assertEquals('0..4', rangesString(CompletionMenu.retainedHighlightRanges("flag", [new Range(0, 3), new Range(2, 4)])));
        assertEquals('0..3', rangesString(CompletionMenu.retainedHighlightRanges("flag", [new Range(0, 1), new Range(1, 2), new Range(5, 9), new Range(2, 3)])));
        assertEquals('0..3', rangesString(CompletionMenu.retainedHighlightRanges("你", [new Range(0, 1), new Range(0, 3)])));
    }

    function testHidingAnOldMenuDoesNotDismissANewCompletionResponse() {
        init();
        final opened = addWindowView((_, _) -> new PasteProbe());
        var editor:Entity<EditorState> = null;
        var menu:Entity<CompletionMenu> = null;
        opened.cx.update((window, cx) -> {
            editor = cx.newEntity((c:Context<EditorState>) -> (new EditorState(window, c).defaultValue("co") : EditorState));
            menu = CompletionMenu.create(editor, window, cx);
            final oldItems = [new CompletionItem("const")];
            editor.update(cx, (editor, cx) -> editor.presentCompletionItems(0, "c", oldItems.copy(), cast cx));
            menu.update(cx, (menu, cx) -> {
                menu.updateQuery(0, "c");
                menu.show(1, oldItems, window, cx);
                // The overlay observes the old request being hidden while a
                // replacement request is pending. Its deferred dismissal must
                // not act on the replacement response that arrives next.
                menu.hide(cx);
            });
            editor.update(cx, (editor, cx) -> editor.presentCompletionItems(0, "co", [new CompletionItem("const")], cast cx));
        });

        opened.cx.runUntilParked();

        final completion = editor.read(app).completionMenuState();
        assertTrue(completion.open, "an old menu dismissed the new response");
        assertEquals("co", completion.query);
        assertEquals(1, completion.items.length);
        assertEquals("const", completion.items[0].label);
    }

/// overlay.rs

    function openProbe(build:(Window, Context<EditorState>) -> EditorState):{state:Entity<EditorState>, cx:VisualTestContext} {
        init();
        var state:Entity<EditorState> = null;
        final opened = addWindowView((window, cx) -> {
            state = cx.newEntity((c:Context<EditorState>) -> build(window, c));
            return new PasteProbe();
        });
        return {state: state, cx: opened.cx};
    }

    /**
     * Asking for search again, while it is already open, must re-select the query.
     *
     * Re-invoking search leaves every other part of the session identical, so a
     * sync keyed only on that state reads it as an unchanged frame and drops the
     * request: the field keeps whatever caret the user left in it and the
     * shortcut looks dead. `activationRevision` is what carries the second
     * request through, and the echo guard below it is what must survive that.
     */
    function testReopeningSearchReselectsTheQuery() {
        InputOverlays.focusOnSync = false;
        final probe = openProbe((window, c) -> new EditorState(window, c).withSearchable(true));
        final state = probe.state;

        probe.cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> {
                state.setValue("foo bar foo", window, cast cx);
                state.setSelectedRange(new Range(0, 3), cast cx);
                state.openSearch(false, cast cx);
            });

            final host = new InputOverlayHost(base(state), window, cx);
            host.sync(base(state), window, cx);

            final searchInput = host.search.read(cx).getSearchInput();
            assertEquals("foo", searchInput.read(cx).value());
            assertEquals('0..3', rangeString(searchInput.read(cx).selectedRange()), "opening search selects the query it seeded the field with");

            // The user drops the caret into the field. An untouched frame must
            // leave it there: this is the echo guard, and a fix that reshows the
            // panel on every frame would fail here instead of silently annoying.
            searchInput.update(cx, (input, cx) -> input.unselect(window, cast cx));
            host.sync(base(state), window, cx);
            assertTrue(searchInput.read(cx).selectedRange().isEmpty(), "an unchanged frame must not touch the field");

            // The shortcut again, with the session already open and nothing else
            // about it moved.
            state.update(cx, (state, cx) -> state.openSearch(false, cast cx));
            host.sync(base(state), window, cx);
            assertEquals('0..3', rangeString(searchInput.read(cx).selectedRange()), "re-invoking search must select the query again");
        });
    }

    /**
     * Reopening search must preserve navigation already owned by Base.
     *
     * Closing and reopening Find keeps the previous occurrence in browsers.
     * Neither Base reopening the session nor the styled panel echoing its
     * retained query may reset the current match to zero.
     */
    function testReopeningSearchPanelPreservesThePreviousMatch() {
        InputOverlays.focusOnSync = false;
        final probe = openProbe((window, c) -> new EditorState(window, c).withSearchable(true));
        final state = probe.state;

        probe.cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> {
                state.setValue("foo bar foo baz foo", window, cast cx);
                state.openSearch(false, cast cx);
                state.setSearchQuery("foo", true, cast cx);
                assertEquals('8..11', rangeString(state.nextSearchMatch(cast cx)));
                assertEquals(1, state.searchSession.matcher.currentMatchIndex());
                state.closeSearch(cast cx);
                state.openSearch(false, cast cx);
                assertEquals(1, state.searchSession.matcher.currentMatchIndex());
            });

            final host = new InputOverlayHost(base(state), window, cx);
            host.sync(base(state), window, cx);

            assertEquals(1, state.read(cx).searchSession.matcher.currentMatchIndex());
            assertEquals("2/3", state.read(cx).searchSession.matcher.label());

            state.update(cx, (state, cx) -> {
                assertEquals('16..19', rangeString(state.nextSearchMatch(cast cx)));
            });
        });
    }

    /**
     * A frame that changed nothing must not rebuild the popovers.
     *
     * Sync runs every frame, so the change check has to be cheap and stable.
     * It is keyed on a revision the engine bumps when it swaps the content;
     * forgetting to bump, or comparing the content itself again, both show up
     * here.
     */
    function testUnchangedContentKeepsTheOverlaySignature() {
        InputOverlays.focusOnSync = false;
        final probe = openProbe((window, c) -> new EditorState(window, c).language("sql"));
        final state = probe.state;

        probe.cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> state.presentCompletionItems(0, "f", [new CompletionItem("foo")], cast cx));

            final host = new InputOverlayHost(base(state), window, cx);
            host.sync(base(state), window, cx);
            final afterFirst = host.lsp.completionSignature.revision;

            // A second pass over untouched content.
            host.sync(base(state), window, cx);
            assertEquals(afterFirst, host.lsp.completionSignature.revision, "an unchanged frame must not bump the signature");

            // Swapping the items must be noticed.
            state.update(cx, (state, cx) -> state.presentCompletionItems(0, "f", [new CompletionItem("bar")], cast cx));
            host.sync(base(state), window, cx);
            assertTrue(host.lsp.completionSignature.revision != afterFirst, "new items must be noticed");
        });
    }

    function testFacadeMaterializesAllBaseOverlaySessions() {
        InputOverlays.focusOnSync = false;
        final probe = openProbe((window, c) -> (cast new EditorState(window, c).language("sql").withSearchable(true).withReplaceable(true) : EditorState));
        final state = probe.state;
        probe.cx.update((window, cx) -> {
            assertTrue(InputOverlays.renderOverlays(base(state), window, cx).isEmpty());
            assertTrue(state.read(cx).hasOverlayActionHandler());
            state.update(cx, (state, cx) -> {
                state.setValue("foo bar foo", window, cast cx);
                state.setSelectedRange(new Range(4, 7), cast cx);
                state.openSearch(true, cast cx);
                assertEquals("bar", state.searchSession.query);
                assertTrue(state.searchSession.replaceMode);
                state.presentCompletionItems(0, "f", [new CompletionItem("foo")], cast cx);
                state.presentCodeActions([new CodeActionItem("test", new LspCodeAction("Fix"))], cast cx);
                state.presentHover(new Range(0, 1), new LspHover("docs"), cast cx);
                state.presentDiagnostic(new DiagnosticEntry(new Range(0, 0), new Diagnostic(new glaze.kit.base.input.LspPosition(0, 0), new glaze.kit.base.input.LspPosition(0, 0), "")), cast cx);
            });

            final host = new InputOverlayHost(base(state), window, cx);
            final overlays = host.sync(base(state), window, cx);
            assertNotNull(overlays.search);
            assertEquals(4, overlays.floating.length);
            assertEquals(5, overlays.len());
            assertEquals(5, InputOverlays.renderOverlays(base(state), window, cx).len());
            assertTrue(cx.global(InputOverlayRegistry).containsKey(state.entityId()));

            state.update(cx, (state, cx) -> {
                assertTrue(state.routeOverlayAction(new Escape(), window, cast cx));
                assertFalse(state.completionMenuState().open);
                state.dismissCodeActionOverlay(cast cx);
                state.closeSearch(cast cx);
                state.clearHoverState(cast cx);
                state.clearDiagnosticPopover(cast cx);
            });
            assertTrue(host.sync(base(state), window, cx).isEmpty());
            assertTrue(InputOverlays.renderOverlays(base(state), window, cx).isEmpty());
            assertFalse(cx.global(InputOverlayRegistry).containsKey(state.entityId()));
        });

        var ephemeralId = -1;
        probe.cx.update((window, cx) -> {
            final ephemeral:Entity<EditorState> = cx.newEntity((c:Context<EditorState>) -> new EditorState(window, c).language("sql").withSearchable(true));
            ephemeralId = ephemeral.entityId();
            ephemeral.update(cx, (state, cx) -> state.openSearch(false, cast cx));
            assertEquals(1, InputOverlays.renderOverlays(base(ephemeral), window, cx).len());
            ephemeral.update(cx, (state, cx) -> state.closeSearch(cast cx));
            assertTrue(InputOverlays.renderOverlays(base(ephemeral), window, cx).isEmpty());
            assertFalse(cx.global(InputOverlayRegistry).containsKey(ephemeral.entityId()));
        });
        probe.cx.runUntilParked();
    }

}

private class BoundsCell {

    public var bounds:Null<Bounds> = null;

    public function new() {}

}

private class Harness extends Model implements Render {

    final state:Entity<EditorState>;

    /** A text size set on the editor, as `.textSm()` would. */
    final textSize:Null<Pixels>;

    public function new(state:Entity<EditorState>, textSize:Null<Pixels>) {
        super();
        this.state = state;
        this.textSize = textSize;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        final editor = new Editor(state);
        if (textSize != null) editor.textSize(textSize);
        return div().sizeFull().child(editor);
    }

}

private class SizedHarness extends Model implements Render {

    final state:Entity<EditorState>;

    /** A size set on the editor; `null` leaves the default. */
    final size:Null<Size>;

    final frame:BoundsCell;

    public function new(state:Entity<EditorState>, size:Null<Size>, frame:BoundsCell) {
        super();
        this.state = state;
        this.size = size;
        this.frame = frame;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        final editor = new Editor(state);
        if (size != null) editor.withSize(size);
        final cell = frame;
        return div().sizeFull().child(editor).onPrepaint((bounds, _, _) -> cell.bounds = bounds);
    }

}

private class PasteProbe extends Model implements Render {

    public function new() {
        super();
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div();
    }

}
