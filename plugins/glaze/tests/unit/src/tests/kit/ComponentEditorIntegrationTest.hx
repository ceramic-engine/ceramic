// Ported from gpui-kit 0.8.1: crates/kit/tests/integration/input/editor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.ClipboardItem;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.OperatingSystem;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestClipboard;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.FoldRange;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.input.Editor;
import glaze.kit.input.InputOverlays;
import glaze.kit.input.SearchPanel;
import glaze.kit.theme.Theme;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.kit.base.input.InputSearchExt;

/**
 * Styled editor workflows driven through the window and native events
 * (gpui-kit's integration tests `input/editor.rs`).
 *
 * gpui-kit finds elements through its accessibility test queries; the port
 * has no accessibility tree. `window.click(input)` clicks the middle of the
 * editor's bounds, a fold chevron is clicked at its gutter position, and the
 * search panel's buttons (`next`, `prev`, `replace-one`, `replace-all`,
 * `replace-mode`, `case-insensitive`, `close`) run the handler their click
 * runs, on the panel the overlay host shows. `window.input` and
 * `window.press` follow gpui-kit's `test.rs`.
 *
 * Not ported: `visual_end_does_not_scroll_a_fully_visible_wrapped_editor_row`
 * (it resizes the test platform window).
 */
@:access(glaze.kit.base.input.InputBaseState)
@:access(glaze.kit.input)
class ComponentEditorIntegrationTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    var view:Entity<EditorFixture>;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.platformClipboard = new TestClipboard();
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    function editor(language:Null<String>, value:String, readonly:Bool = false, searchable:Bool = true):Entity<EditorState> {
        app.update(cx -> {
            // The port's text system only has Inter and JetBrains Mono.
            Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            Theme.syncBase(cx);
        });
        app.update(cx -> {
            window = Window.open(cx, {width: 800, height: 480, scaleFactor: 2, autoDraw: false, active: true, bindInput: false}, (window, cx) -> {
                view = cx.newEntity((c:Context<EditorFixture>) -> new EditorFixture(window, c, language, value, readonly, searchable));
                return Root.component().child(view);
            });
        });
        dispatcher.runUntilParked();
        renderFrame();
        return view.read(app).state;
    }

/// gpui-kit `test.rs`

    function renderFrame():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
    }

    /** A Rust `cx.update_window(...)` block: effects flush once, at its end. */
    function inWindow(f:() -> Void):Void {
        app.update(_ -> f());
    }

    function runUntilParked():Void {
        dispatcher.runUntilParked();
    }

    function clickAt(position:Point, ?modifiers:Modifiers):Void {
        final m = modifiers != null ? modifiers : Modifiers.none();
        renderFrame();
        app.update(cx -> window.dispatchEvent(new MouseMoveEvent(position, null, m), cx));
        renderFrame();
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, position, m, 1, false), cx));
        renderFrame();
        app.update(cx -> window.dispatchEvent(new MouseUpEvent(Left, position, m, 1), cx));
        renderFrame();
    }

    /** `window.click(("input", id))`: the middle of the editor's bounds. */
    function click(state:Entity<EditorState>):Void {
        final bounds = state.read(app).inputBounds;
        clickAt(new Point(bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2));
    }

    /** `window.click(("fold-icon", ix))` on the chevron of the first visible row. */
    function clickFoldIcon(state:Entity<EditorState>):Void {
        final s = state.read(app);
        final layout = s.lastLayout;
        final bounds = s.inputBounds;
        // Rust `layout_fold_icons`: the icon sits after the line numbers, its
        // 18 px hitbox ending 6 px before the text.
        final x = bounds.origin.x + layout.lineNumberWidth - 6 - 9;
        final y = bounds.origin.y + layout.visibleTop + layout.lineHeight / 2;
        clickAt(new Point(x, y));
    }

    function input(text:String):Void {
        renderFrame();
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            final buf = new StringBuf();
            buf.addChar(c);
            final character = buf.toString();
            final key = Keystroke.parseWithOs(character, OperatingSystem.Mac);
            key.keyChar = character;
            app.update(cx -> window.dispatchKeystroke(key, cx));
            renderFrame();
        }
    }

    function press(key:String):Void {
        var keystroke = Keystroke.parseWithOs(key, OperatingSystem.Mac);
        renderFrame();
        if (keystroke.key == "enter" || keystroke.key == "tab") {
            final k = keystroke;
            app.update(cx -> window.dispatchEvent(new glaze.KeyDownEvent(k, false, false), cx));
        }
        else {
            keystroke = keystroke.withSimulatedIme();
            final k = keystroke;
            app.update(cx -> window.dispatchKeystroke(k, cx));
        }
        final k = keystroke;
        app.update(cx -> window.dispatchEvent(new glaze.KeyUpEvent(k), cx));
        renderFrame();
    }

    function scroll(state:Entity<EditorState>, delta:ScrollDelta):Void {
        renderFrame();
        final bounds = state.read(app).inputBounds;
        final position = new Point(bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2);
        app.update(cx -> window.dispatchEvent(new MouseMoveEvent(position, null, Modifiers.none()), cx));
        app.update(cx -> window.dispatchEvent(new ScrollEvent(position, delta, Modifiers.none()), cx));
        renderFrame();
    }

    function clipboardText():Null<String> {
        final item = app.readFromClipboard();
        return item != null ? item.text() : null;
    }

    /** The search panel the overlay host of `state` shows. */
    function panel(state:Entity<EditorState>):Entity<SearchPanel> {
        final registry = app.tryGlobal(InputOverlayRegistry);
        final entry = registry != null ? registry.hosts.get(state.entityId()) : null;
        assertNotNull(entry, 'the search panel is shown');
        return entry.host.search;
    }

    /** `window.within("search-panel").click(id)`: the handler of that button. */
    function clickPanel(state:Entity<EditorState>, id:String):Void {
        renderFrame();
        final panel = panel(state);
        app.update(cx -> panel.update(cx, (panel, cx) -> switch id {
            case "next": panel.next(window, cx);
            case "prev": panel.prev(window, cx);
            case "replace-one": panel.replaceNext(window, cx);
            case "replace-all": panel.replaceAll(window, cx);
            case "replace-mode": panel.toggleReplaceMode(window, cx);
            case "case-insensitive": panel.toggleCaseInsensitive(cx);
            case "close": panel.onActionEscape(new glaze.kit.base.input.InputActions.Escape(), window, cx);
            case _: throw 'unknown button $id';
        }));
        renderFrame();
    }

    static inline final ADD_CURSOR_BELOW = "cmd-alt-down";

    static inline final ADD_CURSOR_ABOVE = "cmd-alt-up";

    static inline final REPLACE = "cmd-shift-f";

    static inline final REDO = "cmd-shift-z";

    function value(state:Entity<EditorState>):String {
        return state.read(app).value();
    }

    function sel(state:Entity<EditorState>):String {
        final r = state.read(app).selectedRange();
        return '${r.start}..${r.end}';
    }

    function cursor(state:Entity<EditorState>):Int {
        return state.read(app).cursor();
    }

    function focused(state:Entity<EditorState>):Bool {
        return state.read(app).focusHandle.isFocused(window);
    }

    static function ranges(ranges:Array<Range>):String {
        return [for (r in ranges) '${r.start}..${r.end}'].join(',');
    }

    function matches(state:Entity<EditorState>):String {
        return ranges(state.read(app).searchSession.matcher.matchedRanges());
    }

    function current(state:Entity<EditorState>):Null<Int> {
        return state.read(app).searchSession.matcher.current();
    }

/// Tests

    function testNestedJsonPairsSkipTheirGeneratedClosers() {
        final state = editor("json", "");
        inWindow(() -> {
            click(state);
            input("[");
            assertEquals("[]", value(state));
            assertEquals("1..1", sel(state));
            input("{");
            assertEquals("[{}]", value(state));
            assertEquals("2..2", sel(state));
            input("}");
            assertEquals("[{}]", value(state));
            assertEquals("3..3", sel(state));
            input("]");
            assertEquals("[{}]", value(state));
            assertEquals("4..4", sel(state));
            input("!");
            assertEquals("[{}]!", value(state));
    
        });
    }

    function testQuotedUnicodeTextKeepsOneCloserAndACollapsedCaret() {
        final state = editor("json", "");
        inWindow(() -> {
            click(state);
            input("\"");
            assertEquals("\"\"", value(state));
            assertEquals("1..1", sel(state));
            input("中🦀");
            assertEquals("\"中🦀\"", value(state));
            assertEquals("8..8", sel(state));
            input("\"");
            assertEquals("\"中🦀\"", value(state));
            assertEquals("9..9", sel(state));
            input(",");
            assertEquals("\"中🦀\",", value(state));
    
        });
    }

    function testPlaintextLanguageDoesNotAutoCloseOrSplitBrackets() {
        final state = editor("plaintext", "");
        inWindow(() -> {
            click(state);
            input("{");
            assertEquals("{", value(state));
            input("}");
            press("left");
            press("enter");
            assertEquals("{\n}", value(state));
            assertEquals("2..2", sel(state));
            input("\"");
            assertEquals("{\n\"}", value(state));
    
        });
    }

    function testPairedBackspaceAndUndoPreserveUnicodeNeighbors() {
        final state = editor("json", "中 ");
        inWindow(() -> {
            click(state);
            press("secondary-a");
            press("right");
            input("[");
            assertEquals("中 []", value(state));
            assertEquals("5..5", sel(state));
            // Navigation establishes a distinct undo boundary before deletion.
            press("left");
            press("right");
            press("backspace");
            assertEquals("中 ", value(state));
            assertEquals("4..4", sel(state));
            press("secondary-z");
            assertEquals("中 []", value(state));
            assertEquals("5..5", sel(state));
            input("]");
            assertEquals("中 []", value(state));
            assertEquals("6..6", sel(state));
    
        });
    }

    function testEnterBetweenBracesIndentsTheBodyAndRetainsTheClosingLine() {
        final state = editor("json", "{}");
        inWindow(() -> {
            click(state);
            press("secondary-a");
            press("left");
            press("right");
            press("enter");
            assertEquals("{\n  \n}", value(state));
            assertEquals("4..4", sel(state));
            input("\"key\": 1");
            assertEquals("{\n  \"key\": 1\n}", value(state));
            press("down");
            press("end");
            press("enter");
            assertEquals("{\n  \"key\": 1\n}\n", value(state));
            assertEquals("15..15", sel(state));
    
        });
    }

    function testPythonEnterUsesColonIndentAndOutdentsBeforeACloser() {
        final state = editor("python", "if ready:");
        inWindow(() -> {
            click(state);
            press("secondary-a");
            press("right");
            press("enter");
            assertEquals("if ready:\n  ", value(state));
            assertEquals("12..12", sel(state));
            input("value)");
            press("left");
            press("enter");
            assertEquals("if ready:\n  value\n)", value(state));
            assertEquals("18..18", sel(state));
    
        });
    }

    function testTabAndShiftTabPreserveMultilineSelectionAndUndo() {
        final state = editor("rust", "one\n  two");
        inWindow(() -> {
            click(state);
            press("secondary-a");
            assertEquals("0..9", sel(state));
            press("tab");
            assertEquals("  one\n    two", value(state));
            assertEquals("2..13", sel(state));
            press("shift-tab");
            assertEquals("one\n  two", value(state));
            assertEquals("0..9", sel(state));
            press("secondary-z");
            assertEquals("  one\n    two", value(state));
            assertEquals("2..13", sel(state));
            press("secondary-z");
            assertEquals("one\n  two", value(state));
            assertEquals("0..9", sel(state));
    
        });
    }

    function testReadonlyEditorRejectsIndentationAndKeepsMultilineTextCopyable() {
        final text = "  one\n    中🦀";
        final state = editor("rust", text, true);
        inWindow(() -> {
            for (key in ["tab", "shift-tab"]) {
                click(state);
                press("secondary-a");
                press(key);
                assertEquals(text, value(state), 'read-only $key');
                assertEquals('0..${glaze.util.Utf8.byteLength(text)}', sel(state));
            }
            click(state);
            press("secondary-a");
            press("secondary-c");
            assertEquals(text, clipboardText());
    
        });
    }

    function testKeyboardMulticursorReplacementUndoAndEscapeKeepTheActiveCursor() {
        final state = editor("rust", "ab\nab\nab");
        inWindow(() -> {
            click(state);
            press("secondary-a");
            press("left");
            press("right");
            press(ADD_CURSOR_BELOW);
            press(ADD_CURSOR_BELOW);
            press("shift-right");
            // Additional cursors do not replace the original primary selection.
            assertEquals("1..2", sel(state));
            input("X");
            assertEquals("aX\naX\naX", value(state));
            press("secondary-z");
            assertEquals("ab\nab\nab", value(state));
            assertEquals("1..2", sel(state));
            // Replacing again proves undo restored all three selections.
            input("Y");
            assertEquals("aY\naY\naY", value(state));
            press("escape");
            input("!");
            assertEquals("aY!\naY\naY", value(state));
            assertEquals("3..3", sel(state));
    
        });
    }

    function testMulticursorVerticalSelectionReplacesAndUndoesEachRange() {
        final text = "abcd\nabcd\nabcd\nabcd\nabcd\nabcd";
        final state = editor("plaintext", text);
        inWindow(() -> {
            click(state);
            press("secondary-a");
            press("left");
            press("right");
            press("down");
            assertEquals(6, cursor(state));
            final first = state.read(app).cursorLayout().bounds.center();
            for (_ in 0...3) {
                press("down");
            }
            assertEquals(21, cursor(state));
            final second = state.read(app).cursorLayout().bounds.center();
            assertEquals(0., state.read(app).scrollOffset().y);

            // Native clicks at measured carets keep the two ranges apart, so
            // merging adjacent selections cannot hide a lost secondary cursor.
            for (pair in [{position: first, alt: false}, {position: second, alt: true}]) {
                clickAt(pair.position, Modifiers.of(false, pair.alt));
            }
            // Vertical selection must honor the column established by Alt-click,
            // without a horizontal movement to initialize the secondary anchor.
            assertEquals("6..6", sel(state));
            assertEquals(6, cursor(state));
            press("shift-up");
            assertEquals("1..6", sel(state));
            assertEquals(1, cursor(state));
            assertEquals(text, value(state));
            input("X");
            assertEquals("aXbcd\nabcd\naXbcd\nabcd", value(state));
            press("secondary-z");
            assertEquals(text, value(state));
            assertEquals("1..6", sel(state));
            assertEquals(1, cursor(state));
            // A second replacement proves Undo restored both reversed selections.
            input("Y");
            assertEquals("aYbcd\nabcd\naYbcd\nabcd", value(state));
    
        });
    }

    function testSearchKeyboardNavigationWrapsAndEscapeReturnsEditorFocus() {
        final state = editor("plaintext", "one two one");
        inWindow(() -> {
            click(state);
            press("secondary-a");
            press("left");
            press("secondary-f");
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            assertTrue(state.read(app).searchSession.open);
            input("one");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("one two one", value(state));
            assertEquals("one", state.read(app).searchSession.query);
            assertEquals("0..3,8..11", matches(state));
            assertEquals(0, current(state));
            press("enter");
            assertEquals(1, current(state));
            press("enter");
            assertEquals(0, current(state));
            press("shift-enter");
            assertEquals(1, current(state));
            press("escape");
            assertFalse(state.read(app).searchSession.open);
            assertTrue(focused(state));
            input("!");
            assertEquals("!one two one", value(state));
    
        });
    }

    function testReplaceOverlayTabsToReplacementAndReplaceAllIsOneUndo() {
        final state = editor("plaintext", "cat dog cat");
        inWindow(() -> {
            click(state);
            press("secondary-a");
            press("left");
            press(REPLACE);
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            assertTrue(state.read(app).searchSession.replaceMode);
            input("cat");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("cat", state.read(app).searchSession.query);
            assertEquals(2, state.read(app).searchSession.matcher.len());
            press("tab");
            input("fox");
            press("shift-tab");
            // Retyping the query proves Shift-Tab returned focus to search; if
            // focus stayed in replacement, Replace All would insert "cat".
            press("secondary-a");
            input("cat");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("cat", state.read(app).searchSession.query);
            assertEquals("cat dog cat", value(state));
            clickPanel(state, "replace-all");
            assertEquals("fox dog fox", value(state));
            assertEquals(0, state.read(app).searchSession.matcher.len());
            clickPanel(state, "close");
            assertTrue(focused(state));
            press("secondary-z");
            assertEquals("cat dog cat", value(state));
    
        });
    }

    function customSearchEditor():{state:Entity<EditorState>, value:String} {
        final text = [for (row in 0...180) switch row {
            case 20 | 90: 'Needle on row $row';
            case 140: 'needle on row $row';
            case _: 'line $row';
        }].join("\n");
        final state = editor(null, text, false, false);
        click(state);
        return {state: state, value: text};
    }

    function scrollCustomSearchToLaterMatch(state:Entity<EditorState>):Void {
        final lineHeight = state.read(app).cursorLayout().lineHeight;
        final cursor = state.read(app).cursor();
        scroll(state, ScrollDelta.Pixels(new Point(0, -lineHeight * 80)));
        final visible = state.read(app).lastLayout.visibleRange;
        assertTrue(visible.start > 20, "the first match must be offscreen");
        assertTrue(visible.start <= 90 && 90 < visible.end, "the later match must be visible");
        assertEquals(cursor, state.read(app).cursor(), "scroll must not move the caret");
    }

    function testCustomSearchFreshQueryReplacesViewportMatchAndUndoes() {
        final c = customSearchEditor();
        inWindow(() -> {
            final state = c.state;
            final start = c.value.indexOf("Needle on row 90");
            scrollCustomSearchToLaterMatch(state);
            app.update(cx -> state.update(cx, (state, cx) -> {
                state.setSearchQuery("needle", true, cast cx);
                assertTrue(state.searchSession.isActive());
                assertFalse(state.searchSession.open);
                // Replace immediately, without navigation or another rendered frame.
                assertTrue(state.replaceCurrentSearchMatch("found", window, cast cx));
            }));
            final expected = c.value.substr(0, start) + "found" + c.value.substr(start + 6);
            assertEquals(expected, value(state));
            renderFrame();
            assertFalse(state.read(app).searchSession.open);
            press("secondary-z");
            assertEquals(c.value, value(state));
    
        });
    }

    function testCustomSearchRetainedQueryResumesNavigationAfterManualScroll() {
        final c = customSearchEditor();
        inWindow(() -> {
            final state = c.state;
            final middle = c.value.indexOf("Needle on row 90");
            final last = c.value.indexOf("needle on row 140");
            app.update(cx -> state.update(cx, (state, cx) -> {
                state.setSearchQuery("needle", true, cast cx);
                assertTrue(new Range(middle, middle + 6).equals(state.nextSearchMatch(cast cx)));
                assertTrue(new Range(last, last + 6).equals(state.nextSearchMatch(cast cx)));
                assertTrue(new Range(middle, middle + 6).equals(state.previousSearchMatch(cast cx)));
                state.closeSearch(cast cx);
            }));
            renderFrame();
            scroll(state, ScrollDelta.Pixels(new Point(0, 10000)));
            assertEquals(0., state.read(app).scrollOffset().y);
            app.update(cx -> state.update(cx, (state, cx) -> {
                state.setSearchQuery("needle", true, cast cx);
                assertEquals(1, state.searchSession.matcher.current());
                assertFalse(state.searchSession.open);
                assertTrue(state.replaceCurrentSearchMatch("found", window, cast cx));
            }));
            final expected = c.value.substr(0, middle) + "found" + c.value.substr(middle + 6);
            assertEquals(expected, value(state));
            renderFrame();
            assertFalse(state.read(app).searchSession.open);
    
        });
    }

    function testCustomSearchCaseChangeReanchorsReplacementToViewport() {
        final c = customSearchEditor();
        inWindow(() -> {
            final state = c.state;
            final start = c.value.indexOf("Needle on row 90");
            app.update(cx -> state.update(cx, (state, cx) -> state.setSearchQuery("Needle", true, cast cx)));
            scrollCustomSearchToLaterMatch(state);
            app.update(cx -> state.update(cx, (state, cx) -> {
                state.setSearchQuery("Needle", false, cast cx);
                assertEquals(2, state.searchSession.matcher.len());
                assertFalse(state.searchSession.open);
                assertTrue(state.replaceCurrentSearchMatch("found", window, cast cx));
            }));
            final expected = c.value.substr(0, start) + "found" + c.value.substr(start + 6);
            assertEquals(expected, value(state));
            renderFrame();
            assertFalse(state.read(app).searchSession.open);
    
        });
    }

    function testBlockIndentOutdentPreservesReversedSelectionAndRedo() {
        final state = editor("plaintext", "one\n  two");
        inWindow(() -> {
            click(state);
            press("cmd-down");
            press("cmd-shift-up");
            assertEquals("0..9", sel(state));
            assertEquals(0, cursor(state));
            press("secondary-]");
            assertEquals("  one\n    two", value(state));
            assertEquals("2..13", sel(state));
            assertEquals(2, cursor(state));
            press("secondary-[");
            assertEquals("one\n  two", value(state));
            assertEquals("0..9", sel(state));
            assertEquals(0, cursor(state));
            press("secondary-z");
            assertEquals("  one\n    two", value(state));
            assertEquals(2, cursor(state));
            press(REDO);
            assertEquals("one\n  two", value(state));
            assertEquals("0..9", sel(state));
            assertEquals(0, cursor(state));
            // Moving the head right proves history kept the selection direction.
            press("shift-right");
            assertEquals("1..9", sel(state));
            assertEquals(1, cursor(state));
    
        });
    }

    function testBlockIndentAtACaretChangesOnlyItsLine() {
        final state = editor("plaintext", "one\ntwo\nthree");
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press("right");
            press("down");
            assertEquals(5, cursor(state));
            press("secondary-]");
            assertEquals("one\n  two\nthree", value(state));
            assertEquals("7..7", sel(state));
            press("secondary-[");
            assertEquals("one\ntwo\nthree", value(state));
            assertEquals("5..5", sel(state));
            press("secondary-[");
            assertEquals("one\ntwo\nthree", value(state));
            assertEquals(5, cursor(state));
    
        });
    }

    function testWordAndDocumentMovementSelectAndReplaceAcrossLines() {
        final text = "alpha beta\ngamma delta";
        final state = editor("plaintext", text);
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press("alt-right");
            assertEquals("5..5", sel(state));
            press("alt-shift-right");
            assertEquals("5..10", sel(state));
            press("alt-left");
            assertEquals("6..6", sel(state));
            press("alt-shift-left");
            assertEquals("0..6", sel(state));
            assertEquals(0, cursor(state));
            press("cmd-down");
            assertEquals('${text.length}..${text.length}', sel(state));
            press("cmd-shift-up");
            assertEquals('0..${text.length}', sel(state));
            assertEquals(0, cursor(state));
            press("left");
            press("cmd-shift-down");
            assertEquals(text.length, cursor(state));
            assertEquals('0..${text.length}', sel(state));
            input("中🦀");
            assertEquals("中🦀", value(state));
            // Native input dispatches one keystroke per character. Deviation
            // DEV-015: 中 typed over the selection starts a typing run that 🦀
            // joins, so one undo restores the text (the original undid 🦀 first,
            // leaving "中" at 3..3). Declared in reference/deviations/DEV-015.json.
            press("secondary-z");
            assertEquals(text, value(state));
            assertEquals('0..${text.length}', sel(state));
            assertEquals(text.length, cursor(state));
    
        });
    }

    function testPageMovementPreservesColumnAndClampsAtDocumentEdges() {
        final state = editor("plaintext", "");
        inWindow(() -> {
            final text = [for (_ in 0...100) "abcd"].join("\n");
            app.update(cx -> state.update(cx, (state, cx) -> state.setValue(text, window, cast cx)));
            renderFrame();
            click(state);
            press("cmd-up");
            press("right");
            press("right");
            press("pagedown");
            final nextPage = cursor(state);
            assertTrue(nextPage > 7 && nextPage < text.length - 5);
            assertEquals(2, nextPage % 5);
            assertTrue(state.read(app).scrollOffset().y < 0);
            press("pageup");
            assertEquals("2..2", sel(state));
            press("pageup");
            assertEquals(2, cursor(state));
            press("cmd-down");
            press("left");
            press("left");
            press("pagedown");
            assertEquals(text.length - 2, cursor(state));
            assertEquals(text, value(state));
    
        });
    }

    function testGutterFoldAndUnfoldChangeVerticalNavigationWithoutEditing() {
        final text = "start\ninside\nend\ntail";
        final state = editor("plaintext", text);
        runUntilParked();
        inWindow(() -> {
            click(state);
            press("cmd-up");
            // Supply a deterministic language-provider fixture; folding itself is
            // exercised through the production gutter's native mouse handler.
            app.update(cx -> state.update(cx, (state, cx) -> state.applyHighlighterFoldCandidates([new FoldRange(0, 2)], cast cx)));
            renderFrame();
            clickFoldIcon(state);
            press("down");
            assertEquals(13, cursor(state));
            assertEquals(text, value(state));
            clickFoldIcon(state);
            press("cmd-up");
            press("down");
            assertEquals(6, cursor(state));
            input("!");
            assertEquals("start\n!inside\nend\ntail", value(state));
            press("secondary-z");
            assertEquals(text, value(state));
    
        });
    }

    function testMulticursorCopyCutPasteAndRedoRestoreEverySelection() {
        final text = "ab\ncd\nef";
        final state = editor("plaintext", text);
        inWindow(() -> {
            click(state);
            // Add upwards so clipboard order cannot accidentally follow creation order.
            press("cmd-down");
            press("home");
            press(ADD_CURSOR_ABOVE);
            press(ADD_CURSOR_ABOVE);
            press("shift-right");
            press("secondary-c");
            assertEquals("a\nc\ne", clipboardText());
            assertEquals(text, value(state));
            press("secondary-x");
            assertEquals("b\nd\nf", value(state));
            assertEquals("a\nc\ne", clipboardText());
            press("secondary-z");
            assertEquals(text, value(state));
            press(REDO);
            assertEquals("b\nd\nf", value(state));
            press("secondary-v");
            assertEquals(text, value(state));
            press("secondary-z");
            assertEquals("b\nd\nf", value(state));
            press(REDO);
            assertEquals(text, value(state));
            press("escape");
            input("!");
            assertEquals("ab\ncd\ne!f", value(state));
    
        });
    }

    function testMulticursorPasteBroadcastsWhenClipboardLineCountDiffers() {
        final state = editor("plaintext", "ab\ncd\nef");
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press("right");
            press(ADD_CURSOR_BELOW);
            press(ADD_CURSOR_BELOW);
            app.update(cx -> cx.writeToClipboard(ClipboardItem.newString("中\n🦀")));
            press("secondary-v");
            assertEquals("a中\n🦀b\nc中\n🦀d\ne中\n🦀f", value(state));
            press("secondary-z");
            assertEquals("ab\ncd\nef", value(state));
            input("!");
            assertEquals("a!b\nc!d\ne!f", value(state));
    
        });
    }

    function testReadonlyEditorRejectsNativeMutationsAndKeepsSearchAvailable() {
        final text = "alpha\nbeta";
        final state = editor("plaintext", text, true);
        inWindow(() -> {
            click(state);
            press("secondary-a");
            app.update(cx -> cx.writeToClipboard(ClipboardItem.newString("replacement")));
            input("ignored");
            assertEquals(text, value(state));
            for (key in ["backspace", "delete", "enter", "secondary-v", "secondary-x", "secondary-]", "secondary-[", "secondary-z", REDO]) {
                press(key);
                assertEquals(text, value(state), 'readonly $key');
                assertEquals('0..${text.length}', sel(state), 'readonly $key');
            }
            press("left");
            press("down");
            assertEquals(6, cursor(state));
            press("secondary-f");
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            assertFalse(state.read(app).isReplaceable());
            input("beta");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("6..10", matches(state));
            press(REPLACE);
            assertFalse(state.read(app).searchSession.replaceMode);
            press("escape");
            assertTrue(focused(state));
            assertEquals(text, value(state));
    
        });
    }

    function testSearchCaseToggleRecomputesMatchesAndButtonsWrap() {
        final state = editor("plaintext", "Cat cat CAT");
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press("secondary-f");
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            input("cat");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("0..3,4..7,8..11", matches(state));
            clickPanel(state, "prev");
            assertEquals(2, current(state));
            clickPanel(state, "next");
            assertEquals(0, current(state));
            clickPanel(state, "case-insensitive");
            assertFalse(state.read(app).searchSession.caseInsensitive);
            assertEquals("4..7", matches(state));
            clickPanel(state, "next");
            assertEquals(0, current(state));
            clickPanel(state, "case-insensitive");
            assertTrue(state.read(app).searchSession.caseInsensitive);
            assertEquals(3, state.read(app).searchSession.matcher.len());
            assertEquals("Cat cat CAT", value(state));
    
        });
    }

    function testSearchTreatsRegexMetacharactersLiterallyAndHandlesNoMatches() {
        final state = editor("plaintext", "a.b axb a.b");
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press("secondary-f");
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            input("a.b");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("0..3,8..11", matches(state));
            press("secondary-a");
            input("[");
        });
        runUntilParked();
        inWindow(() -> {
            assertTrue(state.read(app).searchSession.matcher.isEmpty());
            clickPanel(state, "next");
            clickPanel(state, "prev");
            assertEquals("[", state.read(app).searchSession.query);
            assertEquals("a.b axb a.b", value(state));
            press("enter");
            press("shift-enter");
            assertNull(current(state));
            press("secondary-a");
            press("backspace");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("", state.read(app).searchSession.query);
            assertTrue(state.read(app).searchSession.matcher.isEmpty());
            press("escape");
            assertEquals("a.b axb a.b", value(state));
    
        });
    }

    function testReplaceOneUpdatesUnicodeMatchOffsetsAndUndoesAtomically() {
        final text = "🦀 cat cat 中";
        final state = editor("plaintext", text);
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press(REPLACE);
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            input("cat");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals("5..8,9..12", matches(state));
            press("tab");
            input("猫");
            clickPanel(state, "replace-one");
            assertEquals("🦀 猫 cat 中", value(state));
            assertEquals("9..12", matches(state));
            clickPanel(state, "replace-one");
            assertEquals("🦀 猫 猫 中", value(state));
            assertTrue(state.read(app).searchSession.matcher.isEmpty());
            clickPanel(state, "replace-one");
            assertEquals("🦀 猫 猫 中", value(state));
            assertTrue(state.read(app).searchSession.matcher.isEmpty());
            press("tab");
            clickPanel(state, "close");
            press("secondary-z");
            assertEquals("🦀 猫 cat 中", value(state));
            press("secondary-z");
            assertEquals(text, value(state));
            press(REDO);
            assertEquals("🦀 猫 cat 中", value(state));
    
        });
    }

    function testReplaceAllWithEmptyReplacementPreservesUnicodeSuffix() {
        final text = "🦀 cat cat 中";
        final state = editor("plaintext", text);
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press(REPLACE);
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            input("cat");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals(2, state.read(app).searchSession.matcher.len());
            clickPanel(state, "replace-all");
            assertEquals("🦀   中", value(state));
            assertTrue(state.read(app).searchSession.matcher.isEmpty());
            clickPanel(state, "close");
            press("secondary-z");
            assertEquals(text, value(state));
            press(REDO);
            assertEquals("🦀   中", value(state));
    
        });
    }

    function testMulticursorBlockIndentOutdentIsOneHistoryEntry() {
        final text = "ab\ncd\nef";
        final state = editor("plaintext", text);
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press("right");
            press(ADD_CURSOR_BELOW);
            press(ADD_CURSOR_BELOW);
            press("secondary-]");
            assertEquals("  ab\n  cd\n  ef", value(state));
            assertEquals(3, cursor(state));
            press("secondary-[");
            assertEquals(text, value(state));
            assertEquals(1, cursor(state));
            press("secondary-z");
            assertEquals("  ab\n  cd\n  ef", value(state));
            press("secondary-z");
            assertEquals(text, value(state));
            press(REDO);
            assertEquals("  ab\n  cd\n  ef", value(state));
            input("!");
            assertEquals("  a!b\n  c!d\n  e!f", value(state));
    
        });
    }

    function testWordDeletionAtMultipleCursorsRestoresRangesOnUndo() {
        final text = "one two\nred fox";
        final state = editor("plaintext", text);
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press(ADD_CURSOR_BELOW);
            press("alt-delete");
            assertEquals(" two\n fox", value(state));
            press("secondary-z");
            assertEquals(text, value(state));
            press("end");
            press("alt-backspace");
            assertEquals("one \nred ", value(state));
            press("secondary-z");
            assertEquals(text, value(state));
            input("!");
            assertEquals("one two!\nred fox!", value(state));
    
        });
    }

    function testUnwrappedEditorScrollsHorizontallyAndNavigatesLogicalLines() {
        final state = editor("plaintext", "");
        inWindow(() -> {
            final firstLine = [for (_ in 0...80) "abcdefghij"].join("");
            final text = '$firstLine\nlast';
            app.update(cx -> state.update(cx, (state, cx) -> {
                state.setSoftWrap(false, window, cast cx);
                state.setValue(text, window, cast cx);
            }));
            renderFrame();
            click(state);
            press("cmd-up");
            press("end");
            assertEquals(firstLine.length, cursor(state));
            assertTrue(state.read(app).scrollOffset().x < 0);
            assertEquals(0., state.read(app).scrollOffset().y);
            press("down");
            assertEquals(text.length, cursor(state));
            press("up");
            assertEquals(firstLine.length, cursor(state));
            press("shift-home");
            assertEquals('0..${firstLine.length}', sel(state));
            press("secondary-c");
            assertEquals(firstLine, clipboardText());
            input("X");
            assertEquals("X\nlast", value(state));
            press("secondary-z");
            assertEquals(text, value(state));
            assertEquals('0..${firstLine.length}', sel(state));
    
        });
    }

    function testOpenReplacePanelTracksLiveReadonlyChanges() {
        final state = editor("plaintext", "cat cat");
        inWindow(() -> {
            click(state);
            press("cmd-up");
            press(REPLACE);
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            input("cat");
        });
        runUntilParked();
        inWindow(() -> {
            assertEquals(2, state.read(app).searchSession.matcher.len());
            press("tab");
            input("dog");
            // An application may revoke edit permission while replacement has focus.
            view.update(app, (view, cx) -> {
                view.readonly = true;
                cx.notify();
            });
            renderFrame();
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            assertTrue(state.read(app).searchSession.open);
            assertFalse(state.read(app).searchSession.replaceMode);
            assertFalse(state.read(app).isReplaceable());
            assertEquals("cat cat", value(state));
            clickPanel(state, "next");
            assertEquals(1, current(state));
            view.update(app, (view, cx) -> {
                view.readonly = false;
                cx.notify();
            });
            renderFrame();
        });
        runUntilParked();
        inWindow(() -> {
            renderFrame();
            clickPanel(state, "replace-mode");
            assertTrue(state.read(app).searchSession.replaceMode);
            press("secondary-a");
            input("fox");
            clickPanel(state, "replace-all");
            assertEquals("fox fox", value(state));
            clickPanel(state, "close");
            press("secondary-z");
            assertEquals("cat cat", value(state));
    
        });
    }

    function testShiftEndThenDownPreservesEditorVisualRowEndAffinity() {
        final text = [for (_ in 0...600) "x"].join("");
        final state = editor("plaintext", "");
        inWindow(() -> {
            app.update(cx -> state.update(cx, (state, cx) -> {
                state.setSoftWrap(true, window, cast cx);
                state.setValue(text, window, cast cx);
            }));
            renderFrame();
            click(state);
            press("cmd-up");
            final firstRowTop = state.read(app).cursorLayout().bounds.top();
            press("cmd-right");
            final firstEnd = cursor(state);
            final firstCaret = state.read(app).cursorLayout().bounds;
            assertTrue(firstEnd > 3 && firstEnd < text.length);
            assertEquals(firstRowTop, firstCaret.top());

            // Measure the next visual row independently, starting at its left edge.
            press("cmd-up");
            press("down");
            press("cmd-right");
            final secondEnd = cursor(state);
            final secondCaret = state.read(app).cursorLayout().bounds;
            assertTrue(secondEnd > firstEnd && secondEnd < text.length);
            assertTrue(secondCaret.top() > firstCaret.top());

            for (down in ["shift-down", "down"]) {
                press("cmd-up");
                for (_ in 0...3) {
                    press("right");
                }
                press("cmd-shift-right");
                assertEquals('3..$firstEnd', sel(state));
                assertEquals(firstEnd, cursor(state));
                assertTrue(state.read(app).cursorLayout().bounds.equals(firstCaret));
                press(down);
                assertEquals(secondEnd, cursor(state), down);
                assertTrue(state.read(app).cursorLayout().bounds.equals(secondCaret), down);
                final expected = down == "shift-down" ? '3..$secondEnd' : '$secondEnd..$secondEnd';
                assertEquals(expected, sel(state), down);
            }
            assertEquals(text, value(state));
    
        });
    }

}

/** Rust `EditorFixture`: an editor filling a padded window. */
private class EditorFixture extends Model implements Render {

    public final state:Entity<EditorState>;

    public var readonly:Bool;

    public function new(window:Window, cx:Context<EditorFixture>, language:Null<String>, value:String, readonly:Bool, searchable:Bool) {
        super();
        this.readonly = readonly;
        state = cx.newEntity((c:Context<EditorState>) -> {
            var state = new EditorState(window, c).withSearchable(searchable);
            if (language != null) state = state.language(language);
            return (state.defaultValue(value) : EditorState);
        });
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .p4()
            .child(Editor.component(state).readonly(readonly).sizeFull());
    }

}
