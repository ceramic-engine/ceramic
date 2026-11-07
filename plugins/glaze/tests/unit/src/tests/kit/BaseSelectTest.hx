// Ported from gpui-kit 0.8.1: crates/base/src/select.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Base;
import glaze.kit.base.Select;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * The tests of gpui-base's controlled `Select` root.
 *
 * `projects_application_owned_accessible_state` reads the properties the
 * root keeps in `a11y` (the port has no accesskit node).
 */
class BaseSelectTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        // Rust `cx.update(crate::init)`
        app.update(cx -> Base.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    function harness(disabled:Bool):Entity<SelectHarness> {
        var state:Entity<SelectHarness> = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 640, height: 480, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                state = cx.newEntity((c:Context<SelectHarness>) -> new SelectHarness(disabled, c));
                return state;
            });
        });
        dispatcher.runUntilParked();
        app.update(cx -> {
            state.read(cx).focusHandle.focus(window, cx);
            window.draw();
        });
        dispatcher.runUntilParked();
        return state;
    }

    /** `cx.simulate_keystrokes(keys)`: every keystroke, then run until parked. */
    function simulateKeystrokes(keys:String):Void {
        for (key in keys.split(' ')) {
            app.update(cx -> window.dispatchKeystroke(Keystroke.parse(key), cx));
            dispatcher.runUntilParked();
        }
    }

    function draw():Void {
        app.update(_ -> window.draw());
        dispatcher.runUntilParked();
    }

    function testArrowsOpenAndTransferFocusToContent() {
        final state = harness(false);

        simulateKeystrokes('down');
        assertTrue(state.read(app).open);
        assertTrue(state.read(app).contentFocusHandle.isFocused(window));
        assertEquals('true', state.read(app).changes.join(','));
    }

    function testConfirmOpensAClosedSelect() {
        final state = harness(false);

        simulateKeystrokes('enter');
        assertTrue(state.read(app).open);
        assertTrue(state.read(app).contentFocusHandle.isFocused(window));
    }

    function testSpaceOpensAndConfirmsANonSearchableSelect() {
        final state = harness(false);
        simulateKeystrokes('space');
        assertTrue(state.read(app).open);
        assertTrue(state.read(app).contentFocusHandle.isFocused(window));
        draw();
        simulateKeystrokes('space');
        assertEquals('open,confirm', state.read(app).closing.join(','));
    }

    function testSpaceInASelectSearchInputRemainsText() {
        final state = harness(false);
        var input:Entity<InputState> = null;
        app.update(cx -> {
            input = cx.newEntity((c:Context<InputState>) -> new InputState(window, cast c));
            state.update(cx, (state, cx) -> {
                state.contentFocusHandle = input.read(cx).focusHandle;
                state.searchInput = input;
                cx.notify();
            });
            window.draw();
        });
        dispatcher.runUntilParked();
        simulateKeystrokes('space');
        assertTrue(state.read(app).open);
        assertTrue(input.read(app).focusHandle.isFocused(window));
        draw();
        simulateKeystrokes('t w o space w o r d s');
        assertEquals('two words', (cast input : Entity<InputBaseState>).read(app).value());
        assertEquals('open', state.read(app).closing.join(','));
        assertTrue(state.read(app).open);
    }

    function testEscapeClosesAndRestoresTriggerFocus() {
        final state = harness(false);

        simulateKeystrokes('down escape');
        assertFalse(state.read(app).open);
        assertTrue(state.read(app).focusHandle.isFocused(window));
        assertEquals('true,false', state.read(app).changes.join(','));
    }

    /**
     * Closing runs `on_dismiss`, and runs it before the open state is asked
     * to close, so a caller that commits a pending value on dismissal can
     * still read that value.
     */
    function testEveryCloseDismissesBeforeItCloses() {
        final state = harness(false);

        simulateKeystrokes('down escape');
        assertEquals('open,dismiss,close', state.read(app).closing.join(','));
    }

    function testDisabledSelectIsNotKeyboardInteractive() {
        final state = harness(true);

        simulateKeystrokes('down enter space');
        assertFalse(state.read(app).open);
        assertEquals(0, state.read(app).changes.length);
    }

    function testProjectsApplicationOwnedAccessibleState() {
        app.update(cx -> {
            window = Window.open(cx, {width: 100, height: 100, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                return cx.newEntity((c:Context<EmptyView>) -> new EmptyView());
            });
        });
        app.update(cx -> {
            final info = (select:Select) -> {
                select.render(window, cx);
                return select.a11y;
            };
            final enabled = info(new Select('enabled').open(true).accessibilityLabel('Programming language').accessibilityValue('Rust'));
            // Open, so the expanded assertion below says something about
            // `disabled` rather than about the default open state.
            final disabled = info(new Select('disabled').open(true).disabled(true));

            assertEquals('Programming language', enabled.label);
            assertEquals('Rust', enabled.value);
            assertEquals(true, enabled.expanded);
            // a disabled control still reports the state it is in
            assertEquals(true, disabled.expanded);
            assertTrue(enabled.clickable);
            assertFalse(disabled.clickable);
        });
    }

    function testConfirmIsConsumedWhenOpeningAndAccepting() {
        final state = harness(false);
        simulateKeystrokes('enter');
        draw();
        simulateKeystrokes('enter');
        assertTrue(state.read(app).open);
        assertEquals(1, state.read(app).confirmations);
        assertEquals(0, state.read(app).parentConfirms);
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

private class SelectHarness extends Model implements Render {

    public var open:Bool = false;

    public final disabled:Bool;

    public final focusHandle:FocusHandle;

    public var contentFocusHandle:FocusHandle;

    public var searchInput:Null<Entity<InputState>> = null;

    public final changes:Array<Bool> = [];

    public var parentConfirms:Int = 0;

    public var confirmations:Int = 0;

    /** Every step of a close, in the order it ran. */
    public final closing:Array<String> = [];

    public function new(disabled:Bool, cx:Context<SelectHarness>) {
        super();
        this.disabled = disabled;
        focusHandle = cx.focusHandle();
        contentFocusHandle = cx.focusHandle();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final self = this;
        final state:Entity<SelectHarness> = cast cx.entity();
        final select = new Select('select')
            .open(open)
            .disabled(disabled)
            .focusHandle(focusHandle)
            .contentFocusHandle(contentFocusHandle)
            .onOpenChange((open, _, cx) -> {
                self.changes.push(open);
                self.closing.push(open ? 'open' : 'close');
                state.update(cx, (state, cx) -> {
                    state.open = open;
                    cx.notify();
                });
            })
            .onDismiss((_, _) -> self.closing.push('dismiss'))
            .onConfirm((_, _) -> {
                self.closing.push('confirm');
                self.confirmations += 1;
            });
        if (searchInput != null) {
            select.child(new glaze.kit.base.input.Input(searchInput));
        } else {
            select.child(div().trackFocus(contentFocusHandle).size(px(20.)));
        }
        return div()
            .onAction(Confirm, (_, _, _) -> self.parentConfirms += 1)
            .child(select);
    }

}
