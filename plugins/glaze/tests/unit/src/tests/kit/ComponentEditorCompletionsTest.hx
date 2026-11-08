// Ported from gpui-kit 0.8.1: crates/kit/tests/integration/input/completions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.OperatingSystem;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.Subscription;
import glaze.Task;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.base.input.CodeActionProvider;
import glaze.kit.base.input.CompletionContext;
import glaze.kit.base.input.CompletionItem;
import glaze.kit.base.input.CompletionProvider.CompletionProviderBase;
import glaze.kit.base.input.CompletionTextEdit;
import glaze.kit.base.input.DefinitionProvider;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InlineCompletionContext;
import glaze.kit.base.input.InlineCompletionItem;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.LspCodeAction;
import glaze.kit.base.input.LspLocationLink;
import glaze.kit.base.input.LspPosition;
import glaze.kit.base.input.LspRange;
import glaze.kit.base.input.LspShowDocumentParams;
import glaze.kit.base.input.LspTextEdit;
import glaze.kit.input.CaretAnchoredPopup;
import glaze.kit.input.Editor;
import glaze.kit.input.Input;
import glaze.kit.theme.Theme;
import ropey.Rope;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.kit.base.input.InputLspExt;

/**
 * Completion, code action, inline completion and definition workflows
 * through the styled editor (gpui-kit's integration tests
 * `input/completions.rs`).
 *
 * gpui-kit finds elements through its accessibility test queries; the port
 * has no accessibility tree, so `window.click(id)` clicks the middle of the
 * input's text bounds; `window.input(text)` and `window.press(key)` follow
 * gpui-kit's `test.rs`. Popup bounds come from the caret anchor
 * (`CaretAnchoredPopup`).
 *
 * Not ported: `completion_popup_follows_caret_on_first_frame` and
 * `completion_popup_anchors_to_wrapped_and_scrolled_caret_on_first_frame`
 * (they read the popup's accessibility bounds; the anchor itself is checked
 * by the golden scenes), `closing_window_disposes_editor_with_completion_in_flight`
 * (GPUI's test platform window retention).
 */
@:access(glaze.kit.base.input.InputBaseState)
@:access(glaze.kit.input)
class ComponentEditorCompletionsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

/// Fixture

    function fixture(?provider:Suggestions, activate:Bool = true):Fixture {
        if (provider == null) provider = new Suggestions(false, app);
        app.update(cx -> {
            // The port's text system only has Inter and JetBrains Mono.
            Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            Theme.syncBase(cx);
        });
        var view:Entity<CompletionEditor> = null;
        final p = provider;
        app.update(cx -> {
            window = Window.open(cx, {width: 800, height: 480, scaleFactor: 2, autoDraw: false, active: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity((c:Context<CompletionEditor>) -> new CompletionEditor(window, c, p));
                return cx.newEntity((rootCx:Context<Root>) -> new Root(view, window, rootCx));
            });
        });
        dispatcher.runUntilParked();
        app.update(_ -> window.draw());
        final state = view.read(app).state;
        final f = new Fixture(this, view, state, provider);
        f.subscription = app.update(cx -> cx.subscribe(state, InputEvent, (_, event, _) -> {
            switch event {
                case Blur: f.blurs++;
                case _:
            }
        }));
        if (activate) {
            app.update(_ -> window.setActive(true));
            dispatcher.runUntilParked();
        }
        clickInput(cast state);
        f.settle();
        f.assertEditor("");
        return f;
    }

    function deferredFixture():Fixture {
        return fixture(new Suggestions(true, app));
    }

    @:allow(tests.kit)
    function settle():Void {
        // Provider responses and popup acceptance update entities asynchronously.
        dispatcher.runUntilParked();
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
    }

    function click(position:Point):Void {
        app.update(cx -> window.dispatchEvent(new MouseMoveEvent(position, null, Modifiers.none()), cx));
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, position, Modifiers.none(), 1, false), cx));
        app.update(cx -> window.dispatchEvent(new MouseUpEvent(Left, position, Modifiers.none(), 1), cx));
    }

    function center(state:Entity<InputBaseState>):Point {
        final bounds = state.read(app).inputBounds;
        return new Point(bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2);
    }

    /** `window.click(id)` on an input: the middle of its text bounds. */
    @:allow(tests.kit)
    function clickInput(state:Entity<InputBaseState>):Void {
        click(center(state));
    }

    /** `window.hover(id)`: the pointer moves over the input without a button. */
    function hoverInput(state:Entity<InputBaseState>):Void {
        app.update(cx -> window.dispatchEvent(new MouseMoveEvent(center(state), null, Modifiers.none()), cx));
    }

    /**
     * `window.input(text)` (gpui-kit `test::input_text`): one keystroke per
     * character, carrying the character as its key char, each followed by a
     * frame.
     */
    @:allow(tests.kit)
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

    function renderFrame():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
    }

    /**
     * `window.press(key)` (gpui-kit `test::press_key`): enter and tab are
     * dispatched as key downs without the simulated IME text, so a propagated
     * completion or submit action inserts no extra newline; other keys go
     * through `dispatch_keystroke` with the simulated IME. A key up follows.
     */
    @:allow(tests.kit)
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

    @:allow(tests.kit)
    function assertEditorValue(state:Entity<EditorState>, value:String, ?pos:haxe.PosInfos):Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        assertEquals(value, state.read(app).value(), pos);
        assertTrue(state.read(app).focusHandle.isFocused(window), 'the editor holds the focus', pos);
    }

    static function requestsString(provider:Suggestions):String {
        return [for (r in provider.requests) r.toString()].join(' | ');
    }

    static function req(text:String, offset:Int, kind:Int, character:Null<String>):String {
        return new CompletionRequest(text, offset, new CompletionContext(kind, character)).toString();
    }

    static inline final TRIGGER_CHARACTER = 2;

    static inline final INVOKED = 1;

    function startCompletion(f:Fixture):Void {
        f.input("p");
        f.assertEditor("p");
        assertEquals(req("p", 1, TRIGGER_CHARACTER, "p"), requestsString(f.provider));
    }

/// Tests

    function testTypingOpensCompletionAndEnterAcceptsWithoutANewline() {
        final f = fixture();
        startCompletion(f);
        // Enter is the production menu-acceptance key. Tab is used for indentation
        // and inline completion, so it is deliberately not treated as an alias.
        f.press("enter");
        f.assertEditor("print");
        assertEquals(1, f.provider.requests.length);
        f.input("!");
        f.assertEditor("print!");
    }

    function testEscapeCancelsCompletionAndPreservesEditorTextAndFocus() {
        final f = fixture();
        startCompletion(f);
        f.press("escape");
        f.assertEditor("p");
        // Enter now edits the document, proving the dismissed menu cannot accept.
        f.press("enter");
        f.assertEditor("p\n");
        f.input("!");
        f.assertEditor("p\n!");
        assertEquals(1, f.provider.requests.length);
    }

    function testManualOpensCompletionForTheWordBeforeTheCaret() {
        final f = fixture();
        startCompletion(f);
        f.input("ri");
        f.press("escape");
        f.assertEditor("pri");
        final typed = f.provider.requests.length;

        f.showCompletions();
        assertEquals(req("pri", 3, INVOKED, null), f.provider.requests[typed].toString());
        f.press("enter");
        f.assertEditor("print");
    }

    function testManualWithNoWordBeforeTheCaretAsksWithAnEmptyQuery() {
        final f = fixture();
        f.showCompletions();
        assertEquals(req("", 0, INVOKED, null), requestsString(f.provider));
        f.press("enter");
        f.assertEditor("print");
    }

    function testManualAsksNothingOfAReadonlyEditor() {
        final f = fixture();
        f.protect(true, false);
        f.showCompletions();
        assertEquals(0, f.provider.requests.length);
    }

    function testManualCompletionHasNoDefaultShortcutAndHostBindingsAreEditorScoped() {
        final f = fixture();
        f.press("ctrl-space");
        assertEquals(0, f.provider.requests.length);
        app.update(cx -> cx.bindKeys([new KeyBinding("ctrl-alt-j", new ShowCompletions(), "Input && mode == editor")]));
        clickInput(cast f.view.read(app).other);
        press("ctrl-alt-j");
        settle();
        assertEquals(0, f.provider.requests.length);
        clickInput(cast f.state);
        press("ctrl-alt-j");
        settle();
        assertEquals(1, f.provider.requests.length);
        f.press("enter");
        f.assertEditor("print");
    }

    function testManualCompletionKeepsAnOpenMenuAndItsSelectedItem() {
        final f = fixture();
        f.showCompletions();
        f.press("down");
        f.showCompletions();
        assertEquals(1, f.provider.requests.length);
        f.press("enter");
        f.assertEditor("println");
    }

    function testManualCompletionCancelsAnOlderPendingRequest() {
        final f = deferredFixture();
        f.showCompletions();
        f.showCompletions();
        assertEquals(2, f.provider.requests.length);
        f.provider.respond(0, "private");
        f.settle();
        f.provider.respond(1, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("print");
    }

    function testManualCompletionIsCancelledByEscapeOrACaretRoundTrip() {
        for (escape in [true, false]) {
            if (window != null) window.destroy();
            final f = deferredFixture();
            f.setValue("pri");
            f.select(new Range(3, 3));
            f.showCompletions();
            if (escape) {
                f.press("escape");
            }
            else {
                f.press("left");
                f.press("right");
            }
            f.provider.respond(0, "print");
            f.settle();
            f.press("enter");
            f.assertEditor("pri\n");
        }
    }

    function testManualCompletionDoesNotRequestDuringImePreedit() {
        final f = fixture();
        app.update(cx -> {
            final handler = new glaze.ElementInputHandler(f.state.read(cx).inputBounds, (cast f.state : Entity<InputBaseState>));
            handler.replaceAndMarkTextInRange(null, "中", new Range(1, 1), window, cx);
            final marked = handler.markedTextRange(window, cx);
            assertTrue(marked != null && marked.equals(new Range(0, 1)));
        });
        f.settle();
        f.showCompletions();
        assertEquals(0, f.provider.requests.length);
        app.update(cx -> {
            final handler = new glaze.ElementInputHandler(f.state.read(cx).inputBounds, (cast f.state : Entity<InputBaseState>));
            handler.replaceTextInRange(null, "中", window, cx);
            assertNull(handler.markedTextRange(window, cx));
        });
        f.settle();
        f.showCompletions();
        assertEquals(1, f.provider.requests.length);
        assertEquals(3, f.provider.requests[0].offset);
        assertEquals(INVOKED, f.provider.requests[0].trigger.triggerKind);
        assertNull(f.provider.requests[0].trigger.triggerCharacter);
        assertEquals("中", f.state.read(app).completionMenuState().query);
    }

    function testManualCompletionIgnoresDisabledEditorsAndMissingProviders() {
        final f = fixture();
        f.protect(false, true);
        app.update(cx -> f.state.update(cx, (state, cx) -> state.showCompletions(window, cast cx)));
        assertEquals(0, f.provider.requests.length);
        f.protect(false, false);
        app.update(_ -> f.state.read(app).lsp().completionProvider = null);
        f.showCompletions();
        assertEquals(0, f.provider.requests.length);
    }

    function testManualCompletionClearsInlineSuggestionsBeforeAPendingRequest() {
        final pair = inlineFixture(false);
        final f = pair.f;
        final provider = new Suggestions(true, app);
        f.state.read(app).lsp().completionProvider = provider;
        f.showCompletions();
        f.press("tab");
        f.assertEditor("p  ");
        assertEquals(1, pair.inlineProvider.requests.length);
        provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("p  \n");
    }

    function testManualCompletionCancelsPendingInlineDebounce() {
        final f = fixture();
        final inlineProvider = new InlineSuggestions(false);
        f.state.read(app).lsp().completionProvider = inlineProvider;
        f.input("p");
        assertEquals(0, inlineProvider.requests.length);
        f.state.read(app).lsp().completionProvider = f.provider;
        f.showCompletions();
        dispatcher.advanceClock(0.001);
        f.settle();
        assertEquals(0, inlineProvider.requests.length);
        f.press("enter");
        f.assertEditor("print");
    }

    function testManualCompletionReplacesTheCodeActionMenu() {
        final actions = new Actions("Action", false);
        final f = fixture();
        f.state.read(app).lsp().codeActionProviders = [actions];
        f.press(CODE_ACTIONS);
        assertTrue(f.state.read(app).codeActionMenuState().open);
        f.showCompletions();
        assertFalse(f.state.read(app).codeActionMenuState().open);
        f.press("enter");
        f.assertEditor("print");
        assertEquals(0, actions.performed.length);
    }

    function testManualCompletionApiFocusesTheEditorFromAnApplicationCommand() {
        final f = fixture();
        final other:Entity<InputBaseState> = cast f.view.read(app).other;
        clickInput(other);
        assertTrue(other.read(app).focusHandle.isFocused(window));
        app.update(cx -> f.state.update(cx, (state, cx) -> state.showCompletions(window, cast cx)));
        f.settle();
        f.press("enter");
        f.assertEditor("print");
    }

    function testArrowNavigationAcceptsTheSelectedCompletion() {
        final f = fixture();
        startCompletion(f);
        f.press("down");
        f.press("down");
        f.press("up");
        f.assertEditor("p");
        f.press("enter");
        f.assertEditor("println");
        assertEquals(1, f.provider.requests.length);
    }

    function testContinuedTypingRefreshesProviderFilteredSuggestions() {
        final f = fixture();
        startCompletion(f);
        f.press("down");
        f.input("riv");
        f.assertEditor("priv");
        final request = f.provider.requests[f.provider.requests.length - 1];
        assertEquals("priv", request.text);
        assertEquals(4, request.offset);
        assertEquals("priv", request.trigger.triggerCharacter);
        // Only "private" matches now; acceptance also checks that the previous
        // selection does not leave the refreshed one-item list out of bounds.
        f.press("enter");
        f.assertEditor("private");
    }

    function testOrdinaryInputSchedulesNoFollowupFrame() {
        // The caret-anchored popup fix must not cost ordinary inputs an extra
        // frame: geometry changes notify during paint, but nothing may schedule
        // a follow-up frame.
        final f = fixture();
        clickInput(cast f.view.read(app).other);
        input("hello");
        final callbacks = window.simulateNextFrame(app);
        assertEquals(0, callbacks, "an ordinary input must not schedule a follow-up frame");
    }

    function testTypingOverASelectionMeasuresThePrefixFromWhereTheTextBegins() {
        final f = fixture();
        // No menu has opened yet, so nothing but the replaced range locates the
        // typed text.
        f.setValue("print");
        f.select(new Range(2, 5));
        f.input("x");
        f.assertEditor("prx");
        f.select(new Range(0, 1));
        f.input("q");
        f.assertEditor("qrx");
        assertEquals(req("prx", 3, TRIGGER_CHARACTER, "x") + ' | ' + req("qrx", 1, TRIGGER_CHARACTER, "q"), requestsString(f.provider));
    }

    function testDeletingBackIntoTheWordKeepsRefiningTheSameQuery() {
        final f = fixture();
        startCompletion(f);
        f.input("ri");
        f.press("backspace");
        f.input("v");
        f.assertEditor("prv");
        final request = f.provider.requests[f.provider.requests.length - 1];
        assertEquals("prv", request.text);
        assertEquals("prv", request.trigger.triggerCharacter);
    }

    function testTypingElsewhereDoesNotReuseAStaleTriggerOffset() {
        final f = fixture();
        startCompletion(f);
        // Delete the word the menu opened for, then type non-trigger text and a
        // newline. The earlier trigger offset still points at the start of the
        // document, but nothing typed since continues that word.
        f.press("backspace");
        f.input("!");
        f.press("enter");
        f.input("a");
        f.assertEditor("!\na");
        final requests = f.provider.requests;
        assertEquals(2, requests.length);
        assertEquals("!\na", requests[1].text);
        assertEquals(3, requests[1].offset);
        assertEquals("a", requests[1].trigger.triggerCharacter);
    }

    function testReplacingTheDocumentStartsANewQueryAtTheEdit() {
        final f = fixture();
        startCompletion(f);
        f.setValue("hello");
        f.select(new Range(5, 5));
        f.input("x");
        f.assertEditor("hellox");
        final requests = f.provider.requests;
        assertEquals(2, requests.length);
        assertEquals(6, requests[1].offset);
        assertEquals("x", requests[1].trigger.triggerCharacter);
    }

    function testAcceptedCompletionIsOneUndoSeparateFromTheTypedPrefix() {
        final f = fixture();
        startCompletion(f);
        f.press("enter");
        f.assertEditor("print");
        f.press("secondary-z");
        f.assertEditor("p");
        f.press("secondary-z");
        f.assertEditor("");
        // History replay must not issue new completion requests.
        assertEquals(1, f.provider.requests.length);
    }

    function testTypingAfterVisibleCompletionKeepsTheRefreshedRequestAlive() {
        final f = deferredFixture();
        startCompletion(f);
        f.provider.respond(0, "print");
        f.settle();

        // Continue typing with a visible popup, then release the refreshed response
        // after drawing its temporarily closed state.
        f.input("r");
        assertEquals(2, f.provider.requests.length);
        f.provider.respond(1, "private");
        f.settle();
        f.assertEditor("pr");

        f.press("enter");
        f.assertEditor("private");
    }

    function testOlderCompletionResponseCannotReplaceNewerSuggestions() {
        final f = deferredFixture();
        startCompletion(f);
        f.input("r");
        assertEquals(2, f.provider.requests.length);
        f.provider.respond(1, "private");
        f.settle();
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("private");
    }

    function testEmptyNewerResponseCannotBeReopenedByOlderSuggestions() {
        final f = deferredFixture();
        startCompletion(f);
        f.input("z");
        assertEquals(2, f.provider.requests.length);
        f.provider.respond(1, null);
        f.settle();
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("pz\n");
    }

    function testCompletionResponseAfterFocusLossCannotReopenOnRefocus() {
        final f = deferredFixture();
        startCompletion(f);
        final other:Entity<InputBaseState> = cast f.view.read(app).other;
        clickInput(other);
        input("other field");
        assertFalse(f.state.read(app).focusHandle.isFocused(window));
        f.settle();
        assertEquals(1, f.blurs);
        f.provider.respond(0, "print");
        f.settle();
        assertEquals("other field", other.read(app).value());
        assertTrue(other.read(app).focusHandle.isFocused(window));
        press("tab");
        f.settle();
        f.press("enter");
        f.assertEditor("p\n");
    }

    function testFocusRoundTripInvalidatesCompletionRequestedBeforeBlur() {
        final f = deferredFixture();
        startCompletion(f);
        final other:Entity<InputBaseState> = cast f.view.read(app).other;
        clickInput(other);
        assertTrue(other.read(app).focusHandle.isFocused(window));
        f.settle();
        assertEquals(1, f.blurs);
        press("tab");
        f.settle();
        f.assertEditor("p");
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("p\n");
    }

    function testEscapeWhileRequestIsPendingRejectsItsLateResponse() {
        final f = deferredFixture();
        startCompletion(f);
        f.press("escape");
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("p\n");
        assertEquals(1, f.provider.requests.length);
    }

    function testNonTriggerEditInvalidatesPendingCompletion() {
        final f = deferredFixture();
        startCompletion(f);
        f.input("!");
        assertEquals(1, f.provider.requests.length);
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("p!\n");
    }

    function testDeletingPrefixInvalidatesPendingCompletion() {
        final f = deferredFixture();
        startCompletion(f);
        f.press("backspace");
        f.assertEditor("");
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("\n");
        assertEquals(1, f.provider.requests.length);
    }

    function testCaretRoundTripDoesNotRevivePendingCompletion() {
        final f = deferredFixture();
        startCompletion(f);
        f.press("left");
        f.press("right");
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("p\n");
    }

    function testTabIndentsInsteadOfAcceptingPopupAndInvalidatesItsResponse() {
        final f = deferredFixture();
        startCompletion(f);
        f.press("tab");
        f.assertEditor("p  ");
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("p  \n");
    }

    function testTabDismissesVisibleCompletionWithoutAcceptingIt() {
        final f = fixture();
        startCompletion(f);
        f.press("tab");
        f.assertEditor("p  ");
        f.press("enter");
        f.assertEditor("p  \n");
    }

    function protectionInvalidatesCompletion(disabled:Bool):Void {
        final f = deferredFixture();
        startCompletion(f);
        f.protect(!disabled, disabled);
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.input("ignored");
        assertEquals("p", f.state.read(app).value());
        assertEquals(1, f.provider.requests.length);
        f.protect(false, false);
        // No click: re-enabling cannot rely on pointer cancellation to clear stale work.
        f.press("enter");
        f.assertEditor("p\n");
    }

    function testReadonlyTransitionInvalidatesInflightCompletion() {
        protectionInvalidatesCompletion(false);
    }

    function testDisabledTransitionInvalidatesInflightCompletion() {
        protectionInvalidatesCompletion(true);
    }

    function testProviderErrorLeavesEditorUsableAndNextRequestCanSucceed() {
        final f = deferredFixture();
        startCompletion(f);
        f.provider.fail(0);
        f.settle();
        f.assertEditor("p");
        f.input("r");
        assertEquals(2, f.provider.requests.length);
        f.provider.respond(1, "private");
        f.settle();
        f.press("enter");
        f.assertEditor("private");
    }

    function testFailedRefreshDismissesPreviousItemsAndRejectsOlderResponse() {
        final f = deferredFixture();
        startCompletion(f);
        f.provider.respond(0, "print");
        f.settle();
        f.input("r");
        f.input("i");
        assertEquals(3, f.provider.requests.length);
        f.provider.fail(2);
        f.settle();
        f.provider.respond(1, "private");
        f.settle();
        f.press("enter");
        f.assertEditor("pri\n");
    }

    function testLateErrorFromOlderRequestCannotDismissNewerItems() {
        final f = deferredFixture();
        startCompletion(f);
        f.input("r");
        f.provider.respond(1, "private");
        f.settle();
        f.provider.fail(0);
        f.settle();
        f.press("enter");
        f.assertEditor("private");
    }

/// Code actions

    static inline final CODE_ACTIONS = "cmd-.";

    function codeActionFixture(providers:Array<CodeActionProvider>):Fixture {
        final f = fixture();
        f.state.read(app).lsp().completionProvider = null;
        f.state.read(app).lsp().codeActionProviders = providers;
        f.input("value");
        f.press("shift-left");
        f.press("shift-left");
        return f;
    }

    function testClickingBesideCodeActionMenuDismissesIt() {
        final provider = new Actions("First action", false);
        final f = codeActionFixture([provider]);
        f.press(CODE_ACTIONS);
        assertTrue(f.state.read(app).codeActionMenuState().open);

        // The popup's left edge is the caret anchor and it is at most 320 wide.
        final anchor = CaretAnchoredPopup.caretPopupAnchor(f.state.read(app).prepaintCaretGeometry);
        final outside = new Point(anchor.x + 320 + 24, anchor.y + 10);
        assertTrue(outside.x < window.viewportSize().width);
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, outside, Modifiers.none(), 1, false), cx));
        app.update(cx -> window.dispatchEvent(new MouseUpEvent(Left, outside, Modifiers.none(), 1), cx));
        f.settle();
        assertFalse(f.state.read(app).codeActionMenuState().open);
        assertEquals(0, provider.performed.length);
    }

    function testCodeActionSelectionRoutesToItsProviderWithSelectedRange() {
        final first = new Actions("First action", false);
        final second = new Actions("Second action", false);
        final f = codeActionFixture([first, second]);
        f.press(CODE_ACTIONS);
        for (provider in [first, second]) {
            assertEquals('value 3..5', provider.requests.join(','));
        }
        f.press("down");
        f.press("enter");
        assertEquals(0, first.performed.length);
        assertEquals('Second action true', second.performed.join(','));
        f.assertEditor("value");
        f.press("right");
        f.press("enter");
        f.assertEditor("value\n");
        assertEquals(1, second.performed.length);
    }

    function testRequestingCodeActionsAgainReplacesTheOpenMenu() {
        final provider = new RangeActions();
        final f = fixture();
        f.state.read(app).lsp().completionProvider = null;
        f.state.read(app).lsp().codeActionProviders = [provider];
        f.input("value");
        f.press("shift-left");
        f.press(CODE_ACTIONS);
        // Widen the selection with the menu still open and ask again.
        f.press("shift-left");
        f.press(CODE_ACTIONS);
        f.press("enter");
        assertEquals("3..5", provider.performed.join(','));
    }

    function testEscapeDismissesCodeActionsWithoutPerformingThem() {
        final provider = new Actions("Action", false);
        final f = codeActionFixture([provider]);
        f.press(CODE_ACTIONS);
        assertEquals(1, provider.requests.length);
        f.press("escape");
        f.press("right");
        f.press("enter");
        f.assertEditor("value\n");
        assertEquals(0, provider.performed.length);
    }

    function testFailedCodeActionProviderDoesNotHideSuccessfulProvider() {
        final failed = new Actions("Failed action", true);
        final successful = new Actions("Successful action", false);
        final f = codeActionFixture([failed, successful]);
        f.press(CODE_ACTIONS);
        f.press("enter");
        assertEquals(1, failed.requests.length);
        assertEquals(0, failed.performed.length);
        assertEquals('Successful action true', successful.performed.join(','));
        f.assertEditor("value");
    }

    function testAllCodeActionProvidersFailingPreservesNormalEnter() {
        final provider = new Actions("Failed action", true);
        final f = codeActionFixture([provider]);
        f.press("right");
        f.press(CODE_ACTIONS);
        assertEquals(1, provider.requests.length);
        f.press("enter");
        f.assertEditor("value\n");
        assertEquals(0, provider.performed.length);
    }

    function protectionRoundTripInvalidatesCompletion(disabled:Bool):Void {
        final f = deferredFixture();
        startCompletion(f);
        f.protect(!disabled, disabled);
        f.protect(false, false);
        f.assertEditor("p");
        f.provider.respond(0, "print");
        f.settle();
        f.press("enter");
        f.assertEditor("p\n");
        assertEquals(1, f.provider.requests.length);
    }

    function testReadonlyRoundTripInvalidatesResponseReleasedAfterReenable() {
        protectionRoundTripInvalidatesCompletion(false);
    }

    function testDisabledRoundTripInvalidatesResponseReleasedAfterReenable() {
        protectionRoundTripInvalidatesCompletion(true);
    }

/// Inline completion

    function inlineFixture(fail:Bool):{f:Fixture, inlineProvider:InlineSuggestions} {
        final f = fixture();
        final provider = new InlineSuggestions(fail);
        f.state.read(app).lsp().completionProvider = provider;
        f.input("p");
        // Advance the deterministic executor clock; never sleep or wait on wall time.
        dispatcher.advanceClock(0.001);
        f.settle();
        assertEquals('p 1', provider.requests.join(','));
        f.assertEditor("p");
        return {f: f, inlineProvider: provider};
    }

    function testInlineCompletionTabAcceptsWithoutIssuingAnotherRequest() {
        final pair = inlineFixture(false);
        pair.f.press("tab");
        pair.f.assertEditor("print");
        assertEquals(1, pair.inlineProvider.requests.length);
        pair.f.press("enter");
        pair.f.assertEditor("print\n");
    }

    function testEscapeDismissesInlineCompletionAndTabReturnsToIndentation() {
        final pair = inlineFixture(false);
        pair.f.press("escape");
        pair.f.press("tab");
        pair.f.assertEditor("p  ");
    }

    function testTypingClearsInlineSuggestionBeforeNextDebounce() {
        final pair = inlineFixture(false);
        pair.f.input("!");
        pair.f.press("tab");
        pair.f.assertEditor("p!  ");
    }

    function testInlineProviderErrorPreservesTabIndentation() {
        final pair = inlineFixture(true);
        pair.f.press("tab");
        pair.f.assertEditor("p  ");
    }

/// Definitions

    function definitionFixture(response:DefinitionResponse):{f:Fixture, provider:Definitions} {
        final f = fixture();
        // GoToDefinition is public but has no default shortcut. Hosts can bind it;
        // exercise that supported action path through a real key event.
        app.update(cx -> cx.bindKeys([new KeyBinding("f12", new GoToDefinition(), "Input")]));
        final provider = new Definitions(response, app);
        f.state.read(app).lsp().completionProvider = null;
        f.state.read(app).lsp().definitionProvider = provider;
        f.input("source target");
        for (_ in 0...7) {
            f.press("left");
        }
        assertEquals(6, f.state.read(app).cursor());
        return {f: f, provider: provider};
    }

    function testGoToDefinitionRequestsCurrentSymbolWithoutHoverAndSelectsTarget() {
        final d = definitionFixture(Location);
        d.f.press("f12");
        assertEquals('source target 6', d.provider.requests.join(','));
        d.f.assertEditor("source target");
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(7, 13)));
        assertEquals("target", d.f.state.read(app).selectedValue());
    }

    function testGoToDefinitionDispatchesShowDocumentAndRespectsHostHandling() {
        final d = definitionFixture(Location);
        final shown:Array<LspShowDocumentParams> = [];
        d.f.state.read(app).lsp().showDocument = (params, _, _) -> {
            shown.push(params);
            return true;
        };
        d.f.press("f12");
        assertEquals('source target 6', d.provider.requests.join(','));
        assertEquals(1, shown.length);
        assertEquals("fixture:///definition", shown[0].uri);
        assertEquals(false, shown[0].external);
        assertEquals(true, shown[0].takeFocus);
        assertTrue(shown[0].selection.equals(new LspRange(new LspPosition(0, 7), new LspPosition(0, 13))));
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(6, 6)));
        d.f.assertEditor("source target");
    }

    function testEmptyDefinitionResponsePreservesCaretAndEditing() {
        final d = definitionFixture(Empty);
        d.f.press("f12");
        assertEquals('source target 6', d.provider.requests.join(','));
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(6, 6)));
        d.f.input("!");
        d.f.assertEditor("source! target");
    }

    function testDefinitionProviderErrorPreservesCaretAndAllowsRetry() {
        final d = definitionFixture(Error);
        d.f.press("f12");
        assertEquals('source target 6', d.provider.requests.join(','));
        d.f.assertEditor("source target");
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(6, 6)));
        d.provider.response = Location;
        d.f.press("f12");
        assertEquals('source target 6,source target 6', d.provider.requests.join(','));
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(7, 13)));
        d.f.assertEditor("source target");
    }

    function pendingDefinitionFixture():{f:Fixture, provider:Definitions} {
        final d = definitionFixture(Location);
        d.provider.deferred = true;
        d.f.press("f12");
        assertEquals('source target 6', d.provider.requests.join(','));
        return d;
    }

    function testLateDefinitionResponseDoesNotMoveChangedCaret() {
        final d = pendingDefinitionFixture();
        d.f.press("left");
        d.provider.release(0);
        d.f.settle();
        d.f.assertEditor("source target");
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(5, 5)));
    }

    function testLateDefinitionResponseRejectsChangedTextEvenAtOriginalCaret() {
        final d = pendingDefinitionFixture();
        d.f.input("!");
        d.f.press("left");
        assertEquals(6, d.f.state.read(app).cursor());
        d.provider.release(0);
        d.f.settle();
        d.f.assertEditor("source! target");
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(6, 6)));
    }

    function testLateDefinitionResponseCannotNavigateAfterBlurAndKeyboardRefocus() {
        final d = pendingDefinitionFixture();
        final other:Entity<InputBaseState> = cast d.f.view.read(app).other;
        clickInput(other);
        assertTrue(other.read(app).focusHandle.isFocused(window));
        d.f.settle();
        assertEquals(1, d.f.blurs);
        d.f.press("tab");
        d.f.assertEditor("source target");
        d.provider.release(0);
        d.f.settle();
        d.f.assertEditor("source target");
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(6, 6)));
    }

    function testPendingKeyboardDefinitionSurvivesPointerLeavingEditor() {
        final d = pendingDefinitionFixture();
        final other:Entity<InputBaseState> = cast d.f.view.read(app).other;
        // Hover the other field without clicking: the pointer leaves the editor
        // while the keyboard action's focus, document, and caret stay valid.
        hoverInput(other);
        assertFalse(other.read(app).focusHandle.isFocused(window));
        assertTrue(d.f.state.read(app).focusHandle.isFocused(window));
        d.f.settle();
        assertEquals(0, d.f.blurs);
        d.provider.release(0);
        d.f.settle();
        d.f.assertEditor("source target");
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(7, 13)));
        assertEquals(1, d.provider.requests.length);
    }

    function testSecondKeyboardDefinitionCancelsOlderRequestAtSameCaret() {
        final d = pendingDefinitionFixture();
        // Keep the document and cursor identical, so only request ownership can
        // reject the older location after the latest lookup reports no definition.
        d.provider.response = Empty;
        d.f.press("f12");
        assertEquals('source target 6,source target 6', d.provider.requests.join(','));
        d.provider.release(1);
        d.f.settle();
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(6, 6)));
        d.provider.release(0);
        d.f.settle();
        d.f.assertEditor("source target");
        assertTrue(d.f.state.read(app).selectedRange().equals(new Range(6, 6)));
    }

}

private class CompletionRequest {

    public final text:String;

    public final offset:Int;

    public final trigger:CompletionContext;

    public function new(text:String, offset:Int, trigger:CompletionContext) {
        this.text = text;
        this.offset = offset;
        this.trigger = trigger;
    }

    public function toString():String {
        return '$text@$offset kind=${trigger.triggerKind} char=${trigger.triggerCharacter}';
    }

}

/** Rust `Suggestions`: print, println and private, optionally answered later. */
private class Suggestions extends CompletionProviderBase {

    public final requests:Array<CompletionRequest> = [];

    final deferred:Bool;

    final app:App;

    final pending:Array<Task<Array<CompletionItem>>> = [];

    public function new(deferred:Bool, app:App) {
        this.deferred = deferred;
        this.app = app;
    }

    public function fail(index:Int):Void {
        final task = pending[index];
        app.update(_ -> task.reject("synthetic provider failure"));
    }

    public function respond(index:Int, label:Null<String>):Void {
        final offset = requests[index].offset;
        final items = label == null ? [] : [item(label, offset)];
        final task = pending[index];
        app.update(_ -> task.resolve(items));
    }

    static function item(label:String, offset:Int):CompletionItem {
        return new CompletionItem(label, null, null, null, null, null, null,
            CompletionTextEdit.Edit(new LspTextEdit(new LspRange(new LspPosition(0, 0), new LspPosition(0, offset)), label)));
    }

    public function completions(text:Rope, offset:Int, trigger:CompletionContext, _:Window, _:App):Task<Array<CompletionItem>> {
        final text = text.toString();
        // This fixture uses single-line ASCII identifiers; LSP character
        // positions and byte offsets therefore coincide.
        final prefix = text.substr(0, offset);
        final items = [for (label in ["print", "println", "private"]) if (StringTools.startsWith(label, prefix)) item(label, offset)];
        requests.push(new CompletionRequest(text, offset, trigger));
        if (deferred) {
            final task = new Task<Array<CompletionItem>>();
            pending.push(task);
            return task;
        }
        return Task.ready(items);
    }

    public function isCompletionTrigger(_:Int, newText:String, _:App):Bool {
        if (newText.length == 0)
            return false;
        for (i in 0...newText.length) {
            final c = StringTools.fastCodeAt(newText, i);
            if (!((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code)))
                return false;
        }
        return true;
    }

}

/** Rust `InlineSuggestions`: an inline-only provider suggesting "rint". */
private class InlineSuggestions extends CompletionProviderBase {

    public final requests:Array<String> = [];

    final fail:Bool;

    public function new(fail:Bool) {
        this.fail = fail;
    }

    public function completions(_:Rope, _:Int, _:CompletionContext, _:Window, _:App):Task<Array<CompletionItem>> {
        throw "inline-only provider must not receive popup requests";
    }

    public function isCompletionTrigger(_:Int, _:String, _:App):Bool {
        return false;
    }

    override public function inlineCompletionDebounce():Float {
        return 1;
    }

    override public function inlineCompletion(text:Rope, offset:Int, trigger:InlineCompletionContext, _:Window, _:App):Task<Array<InlineCompletionItem>> {
        if (trigger.triggerKind != 1)
            throw "expected an automatic trigger";
        requests.push('${text.toString()} $offset');
        if (fail)
            return Task.failed("synthetic inline failure");
        return Task.ready([new InlineCompletionItem("rint")]);
    }

}

/** Rust `Actions`: one action titled after the provider id. */
private class Actions implements CodeActionProvider {

    final idValue:String;

    final failing:Bool;

    public final requests:Array<String> = [];

    public final performed:Array<String> = [];

    public function new(id:String, fail:Bool) {
        this.idValue = id;
        this.failing = fail;
    }

    public function id():String {
        return idValue;
    }

    public function codeActions(state:Entity<InputBaseState>, range:Range, _:Window, cx:App):Task<Array<LspCodeAction>> {
        requests.push('${state.read(cx).value()} ${range.start}..${range.end}');
        if (failing)
            return Task.failed("synthetic code action failure");
        return Task.ready([new LspCodeAction(idValue)]);
    }

    public function performCodeAction(_:Entity<InputBaseState>, action:LspCodeAction, pushToHistory:Bool, _:Window, _:App):Task<glaze.Unit> {
        performed.push('${action.title} $pushToHistory');
        return Task.done();
    }

}

/** Rust `RangeActions`: offers one action named after the range it was asked about. */
private class RangeActions implements CodeActionProvider {

    public final performed:Array<String> = [];

    public function new() {}

    public function id():String {
        return "range";
    }

    public function codeActions(_:Entity<InputBaseState>, range:Range, _:Window, _:App):Task<Array<LspCodeAction>> {
        return Task.ready([new LspCodeAction('${range.start}..${range.end}')]);
    }

    public function performCodeAction(_:Entity<InputBaseState>, action:LspCodeAction, _:Bool, _:Window, _:App):Task<glaze.Unit> {
        performed.push(action.title);
        return Task.done();
    }

}

private enum DefinitionResponse {
    Location;
    Empty;
    Error;
}

/** Rust `Definitions`: one location, none, or an error, optionally released later. */
private class Definitions implements DefinitionProvider {

    public var response:DefinitionResponse;

    public final requests:Array<String> = [];

    public var deferred:Bool = false;

    final pending:Array<{gate:Task<glaze.Unit>}> = [];

    final app:App;

    public function new(response:DefinitionResponse, app:App) {
        this.response = response;
        this.app = app;
    }

    public function release(index:Int):Void {
        final gate = pending[index].gate;
        app.update(_ -> gate.resolve(glaze.Unit.unit));
    }

    public function definitions(text:Rope, offset:Int, _:Window, _:App):Task<Array<LspLocationLink>> {
        requests.push('${text.toString()} $offset');
        final result:Task<Array<LspLocationLink>> = switch response {
            case Location:
                Task.ready([new LspLocationLink("fixture:///definition", new LspRange(new LspPosition(0, 0), new LspPosition(0, 13)),
                    new LspRange(new LspPosition(0, 7), new LspPosition(0, 13)), new LspRange(new LspPosition(0, 0), new LspPosition(0, 6)))]);
            case Empty:
                Task.ready([]);
            case Error:
                Task.failed("synthetic definition failure");
        };
        if (!deferred)
            return result;
        final gate = new Task<glaze.Unit>();
        pending.push({gate: gate});
        return gate.andThen(_ -> result);
    }

}

/** The fixture of a test: the window's view, the editor and its provider. */
@:access(glaze.kit.base.input.InputBaseState)
private class Fixture {

    final test:ComponentEditorCompletionsTest;

    public final view:Entity<CompletionEditor>;

    public final state:Entity<EditorState>;

    public final provider:Suggestions;

    public var blurs:Int = 0;

    public var subscription:Null<Subscription> = null;

    public function new(test:ComponentEditorCompletionsTest, view:Entity<CompletionEditor>, state:Entity<EditorState>, provider:Suggestions) {
        this.test = test;
        this.view = view;
        this.state = state;
        this.provider = provider;
    }

    public function settle():Void {
        test.settle();
    }

    public function input(text:String):Void {
        test.input(text);
        settle();
    }

    public function press(key:String):Void {
        test.press(key);
        settle();
    }

    public function protect(readonly:Bool, disabled:Bool):Void {
        final app = @:privateAccess test.app;
        view.update(app, (view, cx) -> {
            view.readonly = readonly;
            view.disabled = disabled;
            cx.notify();
        });
        settle();
    }

    public function setValue(value:String):Void {
        final app = @:privateAccess test.app;
        final window = @:privateAccess test.window;
        app.update(cx -> state.update(cx, (state, cx) -> state.setValue(value, window, cast cx)));
        settle();
    }

    public function select(range:Range):Void {
        final app = @:privateAccess test.app;
        app.update(cx -> state.update(cx, (state, cx) -> state.setSelectedRange(range, cast cx)));
        settle();
    }

    public function showCompletions():Void {
        final app = @:privateAccess test.app;
        final window = @:privateAccess test.window;
        app.update(cx -> window.dispatchAction(new ShowCompletions(), cx));
        settle();
    }

    public function assertEditor(value:String, ?pos:haxe.PosInfos):Void {
        test.assertEditorValue(state, value, pos);
    }

}

/** Rust `CompletionEditor`: an ordinary input above the editor. */
private class CompletionEditor extends Model implements Render {

    public final state:Entity<EditorState>;

    public final other:Entity<InputState>;

    public var readonly:Bool = false;

    public var disabled:Bool = false;

    public function new(window:Window, cx:Context<CompletionEditor>, provider:CompletionProviderBase) {
        super();
        other = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
        state = cx.newEntity((c:Context<EditorState>) -> {
            final state = new EditorState(window, c).language("plaintext");
            state.lsp().completionProvider = provider;
            return state;
        });
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .p4()
            .flex()
            .flexCol()
            .child(Input.component(other).id("other"))
            .child(Editor.component(state).readonly(readonly).disabled(disabled).flex1());
    }

}
