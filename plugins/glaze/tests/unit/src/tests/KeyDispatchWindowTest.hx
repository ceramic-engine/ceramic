// Ported from gpui-pre 0.3.10: src/key_dispatch.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import glaze.Action;
import glaze.App;
import glaze.Bounds;
import glaze.DispatchEventResult;
import glaze.DispatchPhase;
import glaze.Element;
import glaze.GlobalElementId;
import glaze.InputHandler;
import glaze.InputPreference;
import glaze.KeyDownEvent;
import glaze.LayoutId;
import glaze.Point;
import glaze.Range;
import glaze.Style;
import glaze.TextInputStateChange;
import glaze.UTF16Selection;
import glaze.util.Ref;
import testing.TestPlatformTextInput;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.KeyContext;
import glaze.KeystrokeEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.Render;
import glaze.Subscription;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

@:action(namespace = dispatch_test) class WindowTestAction implements Action {}
@:action(namespace = dispatch_test) class WindowSecondaryTestAction implements Action {}

/**
 * The tests of `key_dispatch.rs` that need a window and a focus tree (the
 * keymap-only ones are in `KeymapTest`).
 *
 * `FocusHandle` release is not ported (handles are never released): the part of
 * `test_pending_input_observers_notified_on_focus_change_and_blur` dropping a
 * focus handle is left out.
 */
class KeyDispatchWindowTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    final subscriptions:Array<Subscription> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (subscription in subscriptions) {
            subscription.dispose();
        }
        subscriptions.resize(0);
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

/// Helpers

    function setupPendingInputTest(bindings:Array<KeyBinding>):PendingInputTestView {
        app.update(cx -> cx.bindKeys(bindings));

        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<PendingInputTestView>) -> new PendingInputTestView(cx.focusHandle()));
        cx = opened.cx;
        final view = opened.view.read(app);
        cx.update((window, cx) -> {
            window.focus(view.focusHandle, cx);
            window.setActive(true);
        });
        return view;
    }

    function captureObservedKeystrokes():Array<String> {
        final observed:Array<String> = [];
        subscriptions.push(cx.update((_, cx) -> cx.observeKeystrokes((event, _, _) -> {
            observed.push(observedKeystroke(event.keystroke, event.action != null ? event.action.name() : null, event.contextStack));
        })));
        return observed;
    }

    /** Rust `ObservedKeystroke`, as a comparable string */
    static function observedKeystroke(keystroke:Keystroke, actionName:Null<String>, contextStack:Array<KeyContext>):String {
        return '$keystroke action=$actionName contexts=[' + [for (context in contextStack) context.toString()].join(', ') + ']';
    }

    static function contextStackEquals(a:Array<KeyContext>, b:Array<KeyContext>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

    function simulateModifierTap(modifiers:Modifiers):Void {
        cx.simulateModifiersChange(modifiers);
        cx.simulateModifiersChange(Modifiers.none());
    }

    static function terminalContext():KeyContext {
        return KeyContext.parse('Terminal');
    }

    function setupPendingInputTimeoutTest():PendingInputTestView {
        return setupPendingInputTest([
            new KeyBinding('ctrl-b', new WindowTestAction(), 'Terminal'),
            new KeyBinding('ctrl-b h', new WindowSecondaryTestAction(), 'Terminal'),
            new KeyBinding('ctrl-b h j', new WindowTestAction(), 'Terminal'),
        ]);
    }

    function simulatePendingBinding():Void {
        cx.simulateModifiersChange(Modifiers.controlKey());
        cx.simulateKeystrokes('ctrl-b');
        cx.simulateModifiersChange(Modifiers.none());
    }

    function newPauseOwner():Entity<PendingInputTimeoutPauseOwner> {
        return cx.update((_, cx) -> cx.newEntity(_ -> new PendingInputTimeoutPauseOwner()));
    }

    static inline final PENDING_INPUT_TIMEOUT:Float = Window.PENDING_INPUT_TIMEOUT;

/// Tests

    function testStandaloneModifierDispatch() {
        final view = setupPendingInputTest([new KeyBinding('shift', new WindowTestAction(), 'Terminal')]);
        final interceptedKeystrokes:Array<String> = [];
        var shouldConsume = true;
        final terminal = terminalContext();
        final observedKeystrokes = captureObservedKeystrokes();
        subscriptions.push(cx.update((_, cx) -> cx.interceptKeystrokes((event, _, cx) -> {
            assertNull(event.action);
            assertTrue(contextStackEquals([terminal], event.contextStack), 'interceptor context stack');
            interceptedKeystrokes.push(Std.string(event.keystroke));
            if (shouldConsume) {
                cx.stopPropagation();
            }
        })));
        final shift = Std.string(Keystroke.parse('shift'));

        // Pressing Shift is not a keystroke. Consuming its recognized release suppresses
        // the binding.
        cx.simulateModifiersChange(Modifiers.shiftKey());
        assertEquals(0, interceptedKeystrokes.length);
        cx.simulateModifiersChange(Modifiers.none());
        assertEquals(shift, interceptedKeystrokes.join(' '));
        assertEquals(0, view.actionCount);
        assertEquals(0, observedKeystrokes.length);

        // Without consumption, the same recognized release reaches keymap dispatch.
        shouldConsume = false;
        interceptedKeystrokes.resize(0);
        cx.simulateModifiersChange(Modifiers.shiftKey());
        assertEquals(0, interceptedKeystrokes.length);
        cx.simulateModifiersChange(Modifiers.none());
        assertEquals(shift, interceptedKeystrokes.join(' '));
        assertEquals(1, view.actionCount);
        assertEquals([observedKeystroke(Keystroke.parse('shift'), WindowTestAction.nameForType(), [terminal])].join('\n'), observedKeystrokes.join('\n'));
    }

    function testUnboundStandaloneModifierObservation() {
        setupPendingInputTest([]);
        final terminal = terminalContext();
        final observedKeystrokes = captureObservedKeystrokes();

        for (entry in [
            {modifiers: Modifiers.shiftKey(), key: 'shift'},
            {modifiers: Modifiers.controlKey(), key: 'ctrl'},
            {modifiers: Modifiers.altKey(), key: 'alt'},
            {modifiers: Modifiers.command(), key: 'cmd'},
            {modifiers: Modifiers.functionKey(), key: 'fn'},
        ]) {
            observedKeystrokes.resize(0);
            cx.simulateModifiersChange(entry.modifiers);
            assertEquals(0, observedKeystrokes.length, 'modifier press must not notify observers');
            cx.simulateModifiersChange(Modifiers.none());
            assertEquals(observedKeystroke(Keystroke.parse(entry.key), null, [terminal]), observedKeystrokes.join('\n'));
        }
    }

    function testRawModifierHandlerCanSuppressObservation() {
        app.update(cx -> cx.bindKeys([new KeyBinding('shift', new WindowTestAction(), 'Terminal')]));
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ModifierListenerTestView>) -> new ModifierListenerTestView(cx.focusHandle()));
        cx = opened.cx;
        final view = opened.view.read(app);
        cx.update((window, cx) -> {
            window.focus(view.focusHandle, cx);
            window.setActive(true);
        });
        final observedKeystrokes = captureObservedKeystrokes();

        simulateModifierTap(Modifiers.shiftKey());
        assertEquals(1, view.releases);
        assertEquals(0, observedKeystrokes.length);

        view.consume = false;
        simulateModifierTap(Modifiers.shiftKey());
        assertEquals(2, view.releases);
        assertEquals(observedKeystroke(Keystroke.parse('shift'), null, [terminalContext()]), observedKeystrokes.join('\n'));
    }

    function testPendingModifierObservedWhenBindingResolves() {
        final view = setupPendingInputTest([
            new KeyBinding('shift', new WindowTestAction(), 'Terminal'),
            new KeyBinding('shift f1', new WindowSecondaryTestAction(), 'Terminal'),
        ]);
        final observedKeystrokes = captureObservedKeystrokes();

        simulateModifierTap(Modifiers.shiftKey());
        assertEquals(0, observedKeystrokes.length);
        assertEquals(0, view.actionCount);

        cx.advanceClock(PENDING_INPUT_TIMEOUT);
        cx.runUntilParked();
        assertEquals(1, view.actionCount);
        assertEquals(observedKeystroke(Keystroke.parse('shift'), WindowTestAction.nameForType(), []), observedKeystrokes.join('\n'));

        observedKeystrokes.resize(0);
        simulateModifierTap(Modifiers.shiftKey());
        assertEquals(0, observedKeystrokes.length);
        cx.simulateKeystrokes('f1');
        assertEquals(1, view.actionCount);
        assertEquals(1, view.secondaryActionCount);
        assertEquals(observedKeystroke(Keystroke.parse('f1'), WindowSecondaryTestAction.nameForType(), [terminalContext()]), observedKeystrokes.join('\n'));
    }

    function testCombinedShortcutHasNoStandaloneModifier() {
        final view = setupPendingInputTest([
            new KeyBinding('shift', new WindowTestAction(), 'Terminal'),
            new KeyBinding('shift-f1', new WindowTestAction(), 'Terminal'),
        ]);
        final interceptedKeystrokes:Array<String> = [];
        final observedKeystrokes = captureObservedKeystrokes();
        subscriptions.push(cx.update((_, cx) -> cx.interceptKeystrokes((event, _, _) -> {
            interceptedKeystrokes.push(Std.string(event.keystroke));
        })));

        // Shift-F1 is the only keystroke. Releasing Shift must not emit a second one.
        cx.simulateModifiersChange(Modifiers.shiftKey());
        assertEquals(0, interceptedKeystrokes.length);
        cx.simulateKeystrokes('shift-f1');
        cx.simulateModifiersChange(Modifiers.none());

        final shiftF1 = Keystroke.parse('shift-f1');
        assertEquals(Std.string(shiftF1), interceptedKeystrokes.join(' '));
        assertEquals(observedKeystroke(shiftF1, WindowTestAction.nameForType(), [terminalContext()]), observedKeystrokes.join('\n'));
        assertEquals(1, view.actionCount);
    }

    function testPendingInputTimeoutDispatchesShorterBinding() {
        final view = setupPendingInputTimeoutTest();
        simulatePendingBinding();
        cx.update((window, _) -> {
            final keystrokes = window.pendingInputKeystrokes();
            assertEquals(1, keystrokes != null ? keystrokes.length : -1);
            assertEquals(PENDING_INPUT_TIMEOUT, window.pendingInputTimeoutDuration());
        });
        assertEquals(0, view.actionCount);

        // Emulate a countdown indicator re-rendering the window while waiting for the timeout.
        for (_ in 0...10) {
            cx.advanceClock(PENDING_INPUT_TIMEOUT / 10);
            cx.update((window, _) -> window.refresh());
            cx.runUntilParked();
        }

        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(1, view.actionCount);
        assertEquals(0, view.secondaryActionCount);
    }

    function testRunningPendingInputTimeoutResetsWhenBindingAdvances() {
        final view = setupPendingInputTimeoutTest();
        simulatePendingBinding();

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 4 / 5);
        cx.runUntilParked();
        cx.simulateKeystrokes('h');
        cx.runUntilParked();

        cx.update((window, cx) -> {
            assertEquals(2, window.pendingInputKeystrokes().length);
            assertEquals(false, window.isPendingInputTimeoutPaused());
            assertFloatEquals(PENDING_INPUT_TIMEOUT, window.pendingInputTimeoutRemaining(cx));
        });

        cx.advanceClock(PENDING_INPUT_TIMEOUT / 5);
        cx.runUntilParked();
        cx.update((window, _) -> assertTrue(window.hasPendingKeystrokes()));
        assertEquals(0, view.actionCount);
        assertEquals(0, view.secondaryActionCount);

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 4 / 5);
        cx.runUntilParked();
        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(0, view.actionCount);
        assertEquals(1, view.secondaryActionCount);
    }

    function testPendingInputTimeoutStartsWhenBindingBecomesAmbiguous() {
        final view = setupPendingInputTest([
            new KeyBinding('ctrl-b h', new WindowSecondaryTestAction(), 'Terminal'),
            new KeyBinding('ctrl-b h j', new WindowTestAction(), 'Terminal'),
        ]);
        simulatePendingBinding();

        cx.update((window, _) -> {
            assertEquals(1, window.pendingInputKeystrokes().length);
            assertNull(window.pendingInputTimeoutDuration());
        });

        cx.simulateKeystrokes('h');
        cx.runUntilParked();
        cx.update((window, cx) -> {
            assertEquals(2, window.pendingInputKeystrokes().length);
            assertNotNull(window.pendingInputTimeoutDuration(), 'pending input timeout');
            assertFloatEquals(PENDING_INPUT_TIMEOUT, window.pendingInputTimeoutRemaining(cx));
        });

        cx.advanceClock(PENDING_INPUT_TIMEOUT);
        cx.runUntilParked();
        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(0, view.actionCount);
        assertEquals(1, view.secondaryActionCount);
    }

    function testInvalidContinuationWhileTimeoutPausedReplaysPendingInput() {
        final view = setupPendingInputTest([
            new KeyBinding('ctrl-b', new WindowTestAction(), 'Terminal'),
            new KeyBinding('ctrl-b h', new WindowSecondaryTestAction(), 'Terminal'),
            new KeyBinding('x', new WindowSecondaryTestAction(), 'Terminal'),
        ]);
        simulatePendingBinding();
        final pauseOwner = newPauseOwner();
        cx.update((window, cx) -> {
            assertTrue(window.setPendingInputTimeoutPaused(pauseOwner, true, cx));
        });
        cx.runUntilParked();

        cx.simulateKeystrokes('x');
        cx.runUntilParked();

        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(1, view.actionCount);
        assertEquals(1, view.secondaryActionCount);

        // drop(pause_owner)
        cx.update((_, _) -> (pauseOwner : Model).destroy());
        cx.update((_, _) -> {});
        cx.runUntilParked();
        cx.advanceClock(PENDING_INPUT_TIMEOUT);
        cx.runUntilParked();

        cx.update((window, _) -> assertTrue(window.pendingInputIsNone()));
        assertEquals(1, view.actionCount);
        assertEquals(1, view.secondaryActionCount);
    }

    function testPendingInputTimeoutPausesAndResumes() {
        final view = setupPendingInputTimeoutTest();
        simulatePendingBinding();

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 7 / 10);
        cx.runUntilParked();

        final pauseOwner = newPauseOwner();
        final otherOwner = newPauseOwner();
        cx.update((window, cx) -> {
            assertTrue(window.setPendingInputTimeoutPaused(pauseOwner, true, cx));
            assertFalse(window.setPendingInputTimeoutPaused(pauseOwner, true, cx));
            assertFalse(window.setPendingInputTimeoutPaused(otherOwner, false, cx));
        });
        cx.runUntilParked();
        cx.update((window, cx) -> {
            assertEquals(true, window.isPendingInputTimeoutPaused());
            assertFloatEquals(PENDING_INPUT_TIMEOUT * 3 / 10, window.pendingInputTimeoutRemaining(cx));
        });

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 2);
        cx.runUntilParked();
        cx.update((window, _) -> assertTrue(window.hasPendingKeystrokes()));
        assertEquals(0, view.actionCount);

        cx.update((window, cx) -> {
            assertTrue(window.setPendingInputTimeoutPaused(pauseOwner, false, cx));
        });
        cx.runUntilParked();
        cx.update((window, cx) -> {
            assertEquals(false, window.isPendingInputTimeoutPaused());
            assertFloatEquals(PENDING_INPUT_TIMEOUT * 3 / 10, window.pendingInputTimeoutRemaining(cx));
        });

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 3 / 10);
        cx.runUntilParked();

        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(1, view.actionCount);
        assertEquals(0, view.secondaryActionCount);
    }

    function testPendingInputTimeoutResumesWhenOwnerIsReleased() {
        final view = setupPendingInputTimeoutTest();
        simulatePendingBinding();

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 7 / 10);
        cx.runUntilParked();

        final pauseOwner = newPauseOwner();
        cx.update((window, cx) -> {
            assertTrue(window.setPendingInputTimeoutPaused(pauseOwner, true, cx));
        });
        cx.runUntilParked();

        // drop(pause_owner)
        cx.update((_, _) -> (pauseOwner : Model).destroy());
        cx.update((_, _) -> {});
        cx.runUntilParked();
        cx.update((window, cx) -> {
            assertEquals(false, window.isPendingInputTimeoutPaused());
            assertFloatEquals(PENDING_INPUT_TIMEOUT * 3 / 10, window.pendingInputTimeoutRemaining(cx));
        });

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 3 / 10);
        cx.runUntilParked();

        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(1, view.actionCount);
        assertEquals(0, view.secondaryActionCount);
    }

    function testPendingInputTimeoutResetsWhenBindingAdvances() {
        final view = setupPendingInputTimeoutTest();
        simulatePendingBinding();
        cx.advanceClock(PENDING_INPUT_TIMEOUT / 2);
        cx.runUntilParked();
        final pauseOwner = newPauseOwner();
        cx.update((window, cx) -> {
            assertTrue(window.setPendingInputTimeoutPaused(pauseOwner, true, cx));
        });
        cx.runUntilParked();
        cx.update((window, cx) -> {
            assertFloatEquals(PENDING_INPUT_TIMEOUT / 2, window.pendingInputTimeoutRemaining(cx));
        });

        cx.simulateKeystrokes('h');
        cx.runUntilParked();
        cx.update((window, cx) -> {
            assertEquals(2, window.pendingInputKeystrokes().length);
            assertEquals(true, window.isPendingInputTimeoutPaused());
            assertFloatEquals(PENDING_INPUT_TIMEOUT, window.pendingInputTimeoutRemaining(cx));
        });

        cx.advanceClock(PENDING_INPUT_TIMEOUT * 2);
        cx.runUntilParked();
        cx.update((window, _) -> assertTrue(window.hasPendingKeystrokes()));
        assertEquals(0, view.actionCount);
        assertEquals(0, view.secondaryActionCount);

        cx.update((window, cx) -> {
            assertTrue(window.setPendingInputTimeoutPaused(pauseOwner, false, cx));
        });
        cx.runUntilParked();
        cx.advanceClock(PENDING_INPUT_TIMEOUT);
        cx.runUntilParked();

        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(0, view.actionCount);
        assertEquals(1, view.secondaryActionCount);
    }

    function testClearingPendingInputInvalidatesTimeoutPause() {
        final view = setupPendingInputTimeoutTest();
        simulatePendingBinding();
        final pauseOwner = newPauseOwner();
        cx.update((window, cx) -> {
            assertTrue(window.setPendingInputTimeoutPaused(pauseOwner, true, cx));
            window.focus(cx.focusHandle(), cx);
            assertFalse(window.hasPendingKeystrokes());
        });

        // drop(pause_owner)
        cx.update((_, _) -> (pauseOwner : Model).destroy());
        cx.update((_, _) -> {});
        cx.runUntilParked();
        cx.advanceClock(PENDING_INPUT_TIMEOUT);
        cx.runUntilParked();

        cx.update((window, _) -> assertTrue(window.pendingInputIsNone()));
        assertEquals(0, view.actionCount);
        assertEquals(0, view.secondaryActionCount);
    }

/// Text input handler (PendingTextInputTestView)

    function setupTextInputView(?platform:TestPlatformTextInput):PendingTextInputTestView {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<PendingTextInputTestView>) -> {
            if (platform != null) window.textInputPlatform = platform;
            return new PendingTextInputTestView(cx.focusHandle());
        });
        cx = opened.cx;
        return opened.view.read(app);
    }

    function setupAltgrTest():PendingTextInputTestView {
        final test = setupTextInputView();
        cx.update((window, cx) -> {
            window.focus(test.focusHandle, cx);
            window.setActive(true);
            cx.bindKeys([new KeyBinding('ctrl-alt-a', new WindowTestAction(), 'Terminal')]);
        });
        return test;
    }

    function dispatchAltgrKeyDown(preferCharacterInput:Bool):DispatchEventResult {
        final parsed = Keystroke.parse('ctrl-alt-a');
        final keystroke = new Keystroke(parsed.modifiers, parsed.key, 'ą');
        return cx.update((window, cx) -> window.dispatchEvent(new KeyDownEvent(keystroke, false, preferCharacterInput), cx));
    }

    /** Rust `query_prefers_ime_for_printable_keys` */
    function queryPrefersImeForPrintableKeys():Null<Bool> {
        final inputHandler = cx.window.takeInputHandler();
        if (inputHandler == null)
            return null;
        final prefersIme = inputHandler.queryPrefersImeForPrintableKeys();
        cx.window.setInputHandler(inputHandler);
        return prefersIme;
    }

    function testPendingInputObserversNotifiedOnFocusChangeAndBlur() {
        app.update(cx -> {
            cx.bindKeys([new KeyBinding('ctrl-b', new WindowTestAction(), 'Terminal')]);
            cx.bindKeys([new KeyBinding('ctrl-b h', new WindowTestAction(), 'Terminal')]);
            cx.bindKeys([new KeyBinding('ctrl-d', new WindowTestAction(), null)]);
            cx.bindKeys([new KeyBinding('ctrl-d h', new WindowTestAction(), null)]);
        });

        final platform = new TestPlatformTextInput();
        final test = setupTextInputView(platform);
        final focusHandle = test.focusHandle;

        var pendingInputChangedCount = 0;
        subscriptions.push(cx.update((window, cx) -> window.observePendingInput(cx, (_, _) -> pendingInputChangedCount++)));

        cx.update((window, cx) -> {
            window.focus(focusHandle, cx);
            window.setActive(true);
        });

        cx.simulateKeystrokes('ctrl-b');

        var countAfterPending = 0;
        cx.update((window, cx) -> {
            assertTrue(window.hasPendingKeystrokes());
            countAfterPending = pendingInputChangedCount;
            assertTrue(countAfterPending > 0);

            window.focus(cx.focusHandle(), cx);

            assertFalse(window.hasPendingKeystrokes());
        });

        // Focus-triggered pending-input notifications are deferred to the end of the current
        // effect cycle, so the observer callback should run after the focus update completes.
        cx.update((_, _) -> {
            assertTrue(pendingInputChangedCount > countAfterPending);
        });
        assertEquals([TextInputStateChange.FocusGained, TextInputStateChange.FocusLost].join(','), platform.textInputStateChanges.join(','));

        cx.update((window, cx) -> window.focus(focusHandle, cx));
        cx.simulateKeystrokes('ctrl-b');
        final countBeforeBlur = pendingInputChangedCount;

        cx.update((window, cx) -> {
            assertTrue(window.hasPendingKeystrokes());
            window.blur(cx);
            assertFalse(window.hasPendingKeystrokes());
            assertTrue(window.pendingInputIsNone());
        });

        cx.update((_, _) -> {
            assertTrue(pendingInputChangedCount > countBeforeBlur);
        });

        // (Rust then drops a temporary focus handle: not ported.)

        cx.update((window, cx) -> window.disableFocus(cx));
        cx.simulateKeystrokes('ctrl-d');

        cx.update((window, cx) -> {
            assertTrue(window.hasPendingKeystrokes());
            window.blur(cx);
            assertTrue(window.pendingInputIsNone());
        });
    }

    function testKeystrokeInputPreference() {
        final test = setupAltgrTest();
        final interceptedPreferences:Array<InputPreference> = [];
        final observedPreferences:Array<InputPreference> = [];
        subscriptions.push(cx.update((_, cx) -> cx.interceptKeystrokes((event, _, _) -> interceptedPreferences.push(event.inputPreference))));
        subscriptions.push(cx.update((_, cx) -> cx.observeKeystrokes((event, _, _) -> observedPreferences.push(event.inputPreference))));

        for (entry in [
            {preferCharacterInput: true, acceptsTextInput: true, inputPreference: InputPreference.CharacterInput},
            {preferCharacterInput: false, acceptsTextInput: true, inputPreference: InputPreference.KeyBindings},
            {preferCharacterInput: true, acceptsTextInput: false, inputPreference: InputPreference.KeyBindings},
            {preferCharacterInput: false, acceptsTextInput: false, inputPreference: InputPreference.KeyBindings},
        ]) {
            test.acceptsTextInput = entry.acceptsTextInput;
            test.actionCount = 0;
            interceptedPreferences.resize(0);
            observedPreferences.resize(0);
            final result = dispatchAltgrKeyDown(entry.preferCharacterInput);
            assertEquals(entry.inputPreference == InputPreference.CharacterInput, result.propagate);
            assertEquals(Std.string([entry.inputPreference]), Std.string(interceptedPreferences));
            assertEquals(Std.string([entry.inputPreference]), Std.string(observedPreferences));
            assertEquals(entry.inputPreference == InputPreference.KeyBindings ? 1 : 0, test.actionCount);
        }
    }

    function testInputPreferenceRecheckedAfterInterception() {
        final test = setupAltgrTest();
        subscriptions.push(cx.update((_, cx) -> cx.interceptKeystrokes((event, _, _) -> {
            assertEquals(test.acceptsTextInput, event.inputPreference == InputPreference.CharacterInput);
            test.acceptsTextInput = !test.acceptsTextInput;
        })));
        final observedPreferences:Array<InputPreference> = [];
        subscriptions.push(cx.update((_, cx) -> cx.observeKeystrokes((event, _, _) -> observedPreferences.push(event.inputPreference))));

        for (entry in [
            {initiallyAcceptsTextInput: true, observedPreference: InputPreference.KeyBindings},
            {initiallyAcceptsTextInput: false, observedPreference: InputPreference.CharacterInput},
        ]) {
            test.acceptsTextInput = entry.initiallyAcceptsTextInput;
            test.actionCount = 0;
            observedPreferences.resize(0);
            final result = dispatchAltgrKeyDown(true);
            assertEquals(!entry.initiallyAcceptsTextInput, result.propagate);
            assertEquals(Std.string([entry.observedPreference]), Std.string(observedPreferences));
            assertEquals(entry.initiallyAcceptsTextInput ? 1 : 0, test.actionCount);
        }
    }

    function testKeystrokeInterceptorsCanConsumePreferredCharacterInput() {
        final test = setupAltgrTest();
        var intercepted = false;
        subscriptions.push(cx.update((_, cx) -> cx.interceptKeystrokes((event, _, cx) -> {
            assertEquals(InputPreference.CharacterInput, event.inputPreference);
            intercepted = true;
            cx.stopPropagation();
        })));

        final result = dispatchAltgrKeyDown(true);
        assertTrue(intercepted);
        assertFalse(result.propagate);
        assertEquals(0, test.actionCount);
    }

    function testConsumedModifierPreservesPendingInput() {
        final test = setupTextInputView();
        cx.update((window, cx) -> {
            window.focus(test.focusHandle, cx);
            window.setActive(true);
        });
        subscriptions.push(cx.update((_, cx) -> cx.interceptKeystrokes((event, _, cx) -> {
            if (event.keystroke.key == 'shift') {
                cx.stopPropagation();
            }
        })));

        // Exercise both paths that processing Shift would take: completing `j shift`, and
        // replaying `j` when `j k` no longer matches.
        for (binding in ['j shift', 'j k']) {
            cx.update((_, cx) -> {
                cx.clearKeyBindings();
                cx.bindKeys([new KeyBinding(binding, new WindowTestAction(), 'Terminal')]);
            });
            test.text = '';
            cx.simulateKeystrokes('j');
            cx.advanceClock(PENDING_INPUT_TIMEOUT / 2);
            cx.runUntilParked();
            final pendingKeystrokes = cx.update((window, _) -> {
                final keystrokes = window.pendingInputKeystrokes();
                assertTrue(keystrokes != null, 'pending input');
                return Std.string(keystrokes);
            });

            // Consuming Shift must not complete or replay the pending `j`.
            cx.simulateModifiersChange(Modifiers.shiftKey());
            cx.simulateModifiersChange(Modifiers.none());
            cx.update((window, _) -> {
                assertEquals(pendingKeystrokes, Std.string(window.pendingInputKeystrokes()));
                assertTrue(window.pendingInputTimeoutDuration() != null);
            });
            assertEquals(0, test.actionCount);
            assertEquals('', test.text);

            // The unchanged timeout should replay `j` after its remaining half.
            cx.advanceClock(PENDING_INPUT_TIMEOUT / 2);
            cx.runUntilParked();
            cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
            assertEquals(0, test.actionCount);
            assertEquals('j', test.text);
        }
    }

    function testPrintablePendingInputReplaysOnTimeout() {
        app.update(cx -> cx.bindKeys([new KeyBinding('j k', new WindowTestAction(), 'Terminal')]));
        final test = setupTextInputView();
        cx.update((window, cx) -> {
            window.focus(test.focusHandle, cx);
            window.setActive(true);
        });

        cx.simulateKeystrokes('j');

        cx.update((window, _) -> {
            final keystrokes = window.pendingInputKeystrokes();
            assertTrue(keystrokes != null, 'pending input');
            assertEquals(1, keystrokes.length);
            assertTrue(window.pendingInputTimeoutDuration() != null);
        });
        assertEquals(0, test.actionCount);
        assertEquals('', test.text);

        cx.advanceClock(PENDING_INPUT_TIMEOUT);
        cx.runUntilParked();

        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(0, test.actionCount);
        assertEquals('j', test.text);
    }

    function testInputHandlerPending() {
        app.update(cx -> {
            cx.bindKeys([new KeyBinding('ctrl-b', new WindowTestAction(), 'Terminal')]);
            cx.bindKeys([new KeyBinding('ctrl-b h', new WindowTestAction(), 'Terminal')]);
            cx.bindKeys([new KeyBinding('ctrl-x k', new WindowTestAction(), 'Terminal')]);
        });
        final test = setupTextInputView();
        cx.update((window, cx) -> {
            window.focus(test.focusHandle, cx);
            window.setActive(true);
        });

        assertEquals(true, queryPrefersImeForPrintableKeys());
        cx.simulateKeystrokes('ctrl-x');
        cx.update((window, _) -> assertTrue(window.hasPendingKeystrokes()));
        assertEquals(false, queryPrefersImeForPrintableKeys());

        final inputHandler = cx.window.takeInputHandler();
        cx.update((window, cx) -> {
            window.blur(cx);
            assertFalse(window.hasPendingKeystrokes());
            assertTrue(window.pendingInputIsNone());
        });
        final prefersImeAfterBlur = inputHandler != null ? inputHandler.queryPrefersImeForPrintableKeys() : null;
        if (inputHandler != null && cx.window.peekInputHandler() == null) {
            cx.window.setInputHandler(inputHandler);
        }
        assertEquals(true, prefersImeAfterBlur);
        cx.update((window, cx) -> window.focus(test.focusHandle, cx));

        cx.simulateKeystrokes('ctrl-x');
        assertEquals(false, queryPrefersImeForPrintableKeys());
        cx.simulateKeystrokes('k');
        cx.update((window, _) -> assertFalse(window.hasPendingKeystrokes()));
        assertEquals(true, queryPrefersImeForPrintableKeys());
        assertEquals(1, test.actionCount);
        assertEquals('', test.text);

        cx.simulateKeystrokes('ctrl-b [');
        assertEquals('[', test.text);
    }

}

/**
 * Rust `PendingTextInputTestView`: a view rendering itself as an element that
 * registers a text input handler (`PendingTextInputHandler`) in the
 * `Terminal` context. Typed text is appended to `text`.
 */
private class PendingTextInputTestView extends Model implements Render {

    public final focusHandle:FocusHandle;

    public var text:String = '';

    public var actionCount:Int = 0;

    public var acceptsTextInput:Bool = true;

    public function new(focusHandle:FocusHandle) {
        super();
        this.focusHandle = focusHandle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new PendingTextInputElement(this);
    }

}

private class PendingTextInputElement extends Element {

    final view:PendingTextInputTestView;

    public function new(view:PendingTextInputTestView) {
        this.view = view;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.requestLayout(new Style(), null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        window.setFocusHandle(view.focusHandle, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        window.setKeyContext(KeyContext.parse('Terminal'));
        window.handleInput(view.focusHandle, new PendingTextInputHandler(view), cx);
        final view = this.view;
        window.onAction(WindowTestAction, (_, phase, _, _) -> {
            if (phase == DispatchPhase.Bubble) {
                view.actionCount++;
            }
        });
    }

}

private class PendingTextInputHandler extends InputHandler {

    final view:PendingTextInputTestView;

    public function new(view:PendingTextInputTestView) {
        this.view = view;
    }

    override function acceptsTextInput(window:Window, cx:App):Bool {
        return view.acceptsTextInput;
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:App):Null<UTF16Selection> {
        return null;
    }

    public function markedTextRange(window:Window, cx:App):Null<Range> {
        return null;
    }

    public function textForRange(rangeUtf16:Range, adjustedRange:Ref<Null<Range>>, window:Window, cx:App):Null<String> {
        return null;
    }

    public function replaceTextInRange(replacementRange:Null<Range>, text:String, window:Window, cx:App):Void {
        if (replacementRange != null)
            throw 'unimplemented';
        view.text += text;
    }

    public function replaceAndMarkTextInRange(replacementRange:Null<Range>, newText:String, newSelectedRange:Null<Range>, window:Window, cx:App):Void {
        if (replacementRange != null)
            throw 'unimplemented';
        view.text += newText;
    }

    public function unmarkText(window:Window, cx:App):Void {}

    override function prefersImeForPrintableKeys(window:Window, cx:App):Bool {
        return true;
    }

    public function boundsForRange(rangeUtf16:Range, window:Window, cx:App):Null<Bounds> {
        return null;
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:App):Null<Int> {
        return null;
    }

}

private class PendingInputTestView extends Model implements Render {

    public final focusHandle:FocusHandle;

    public var actionCount:Int = 0;

    public var secondaryActionCount:Int = 0;

    public function new(focusHandle:FocusHandle) {
        super();
        this.focusHandle = focusHandle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .keyContext('Terminal')
            .trackFocus(focusHandle)
            .sizeFull()
            .onAction(WindowTestAction, (_, _, _) -> actionCount++)
            .onAction(WindowSecondaryTestAction, (_, _, _) -> secondaryActionCount++);
    }

}

private class ModifierListenerTestView extends Model implements Render {

    public final focusHandle:FocusHandle;

    public var consume:Bool = true;

    public var releases:Int = 0;

    public function new(focusHandle:FocusHandle) {
        super();
        this.focusHandle = focusHandle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .keyContext('Terminal')
            .trackFocus(focusHandle)
            .sizeFull()
            .onAction(WindowTestAction, (_, _, cx) -> cx.propagate())
            .onModifiersChanged((event, _, cx) -> {
                if (!event.modifiers.modified()) {
                    releases++;
                    if (consume) {
                        cx.stopPropagation();
                    }
                }
            });
    }

}

private class PendingInputTimeoutPauseOwner extends Model {

    public function new() {
        super();
    }

}
