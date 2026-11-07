// Ported from gpui-kit 0.8.1: crates/component/src/input/input.rs (focused input registry tests),
// crates/component/src/input/group/tests.rs, crates/base/src/number_input.rs (step button focus test),
// and the input parts of crates/kit/tests/integration/{input,input_focus}.rs
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
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.OtpInput.OtpState;
import glaze.kit.base.Root;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.TextareaState;
import glaze.kit.Component;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button.Button;
import glaze.kit.input.AnyInputState;
import glaze.kit.input.Input;
import glaze.kit.input.InputGroup;
import glaze.kit.input.InputGroup.GroupAppearance;
import glaze.kit.input.InputGroup.InputGroupAddon;
import glaze.kit.input.InputGroup.InputGroupButton;
import glaze.kit.input.InputGroup.InputGroupText;
import glaze.kit.input.OtpInput;
import glaze.kit.input.Textarea;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.kit.WindowExt;
using glaze.kit.Size.SizeTools;

/**
 * Behaviour tests of the styled inputs in a window: the focused input
 * registry (`input.rs`), the input group (`group/tests.rs`, the parts that do
 * not need gpui-kit's `test-support` element snapshots), the step buttons of
 * a number input (`number_input.rs`), and the input workflows of gpui-kit's
 * integration tests (`input.rs`, `input_focus.rs`).
 *
 * gpui-kit's integration tests find elements through its accessibility test
 * queries (`window.find(id)`, `click(id)`, `input(text)`); the port has no
 * accessibility tree, so a click lands on the input's text bounds and text is
 * typed through the window's platform input handler, like the test platform.
 * Assertions on accessibility nodes (roles, labels, the hidden value of a
 * masked input) are not ported; the code editor cases (`EditorState`) come
 * with wave 11.
 */
class ComponentInputTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    /** `common::open_window`: gpui-base's `Root` around the view. */
    function openRoot<V:Model & Render>(build:(Window, Context<V>) -> V, width:Float = 640, height:Float = 480):Entity<V> {
        var view:Entity<V> = null;
        app.update(cx -> {
            window = Window.open(cx, {width: width, height: height, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity((viewCx:Context<V>) -> build(window, viewCx));
                return cx.newEntity((rootCx:Context<Root>) -> new Root(view, window, rootCx));
            });
        });
        runUntilParked();
        draw();
        return view;
    }

    function runUntilParked():Void {
        dispatcher.runUntilParked();
    }

    function draw():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        runUntilParked();
    }

    function click(position:Point, count:Int = 1):Void {
        app.update(cx -> window.dispatchEvent(new glaze.MouseMoveEvent(position, null, Modifiers.none()), cx));
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, position, Modifiers.none(), count, false), cx));
        app.update(cx -> window.dispatchEvent(new MouseUpEvent(Left, position, Modifiers.none(), count), cx));
        runUntilParked();
        draw();
    }

    /** Clicks the middle of the text bounds of `state` (Rust `window.click(id)` on its frame). */
    function clickInput(state:Entity<InputBaseState>):Void {
        final bounds = state.read(app).inputBounds;
        click(new Point(bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2));
    }

    /** `window.input(text)`: the platform's text input, to the focused handler. */
    function input(text:String):Void {
        draw();
        app.update(_ -> {
            final handler = window.peekInputHandler();
            if (handler != null) handler.replaceTextInRange(null, text);
        });
        runUntilParked();
        draw();
    }

    /** `window.press(key)` (key down then key up), then settle. */
    function press(key:String):Void {
        app.update(cx -> window.dispatchKeystroke(Keystroke.parse(key), cx));
        app.update(cx -> window.dispatchEvent(new glaze.KeyUpEvent(Keystroke.parse(key)), cx));
        runUntilParked();
        draw();
    }

    static inline function base<T:InputBaseState>(state:Entity<T>):Entity<InputBaseState> {
        return cast state;
    }

    /// component input.rs

    function testFocusedInputRegistryTracksFocusAndBlur() {
        var input:Entity<InputState> = null;
        var textarea:Entity<TextareaState> = null;
        var otp:Entity<OtpState> = null;
        var other:FocusHandle = null;
        openRoot((window, cx:Context<ProbeView>) -> {
            input = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            textarea = cx.newEntity((c:Context<TextareaState>) -> new TextareaState(window, c));
            otp = cx.newEntity((c:Context<OtpState>) -> new OtpState(6, window, c));
            other = cx.focusHandle();
            final focus = other;
            return new ProbeView((_, _) -> div()
                .child(div().trackFocus(focus))
                .child(new Input(input))
                .child(new Textarea(textarea))
                .child(new OtpInput(otp)));
        });

        // Focusing each kind of input registers it, and blurring clears it.
        // (The code editor case comes with `EditorState`, wave 11.)
        final cases = [AnyInputState.input(input), AnyInputState.textarea(textarea), AnyInputState.otp(otp)];
        for (expected in cases) {
            app.update(_ -> window.draw());
            app.update(cx -> expected.focusHandle(cx).focus(window, cx));
            runUntilParked();
            app.update(_ -> window.draw());
            assertTrue(expected.equals(window.focusedInput(app)), 'registered ${expected}');

            app.update(cx -> other.focus(window, cx));
            runUntilParked();
            app.update(_ -> window.draw());
            assertNull(window.focusedInput(app));
        }
    }

    function testFocusedInputRegistryIgnoresInputRemovedWhileFocused() {
        var input:Entity<InputState> = null;
        var other:FocusHandle = null;
        var showInput = true;
        final probe = openRoot((window, cx:Context<ProbeView>) -> {
            input = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            other = cx.focusHandle();
            final focus = other;
            return new ProbeView((_, _) -> {
                final root = div().child(div().trackFocus(focus));
                if (showInput) root.child(new Input(input));
                return root;
            });
        });
        final state = AnyInputState.input(input);

        app.update(_ -> window.draw());
        app.update(cx -> state.focusHandle(cx).focus(window, cx));
        runUntilParked();
        app.update(_ -> window.draw());
        assertTrue(state.equals(window.focusedInput(app)));

        // Remove the input from the tree while it holds focus and move focus
        // elsewhere in the same update (e.g. closing a sidebar containing the
        // input): the input never re-renders to unregister itself.
        app.update(cx -> {
            showInput = false;
            probe.update(cx, (_, cx) -> cx.notify());
            other.focus(window, cx);
        });
        runUntilParked();
        app.update(_ -> window.draw());
        assertFalse(window.hasFocusedInput(app));
        assertNull(window.focusedInput(app));
    }

    /// group/tests.rs

    function testValidationTakesPrecedenceOverFocusAndRemainsVisibleWhenDisabled() {
        for (mode in [ThemeMode.Light, ThemeMode.Dark]) {
            final theme = new Theme();
            theme.mode = mode;
            final focused = @:privateAccess new GroupAppearance(theme, true, false, false);
            assertTrue(@:privateAccess focused.border.equals(theme.ring));
            assertTrue(@:privateAccess focused.ring.equals(theme.ring.opacity(0.5)));

            final disabled = @:privateAccess new GroupAppearance(theme, true, true, false);
            assertTrue(@:privateAccess disabled.border.equals(theme.input));
            assertNull(@:privateAccess disabled.ring);

            for (focused in [false, true]) {
                for (disabled in [false, true]) {
                    final invalid = @:privateAccess new GroupAppearance(theme, focused, disabled, true);
                    assertTrue(@:privateAccess invalid.border.equals(theme.danger));
                    assertTrue(@:privateAccess invalid.ring.equals(theme.danger.opacity(theme.isDark() ? 0.4 : 0.2)));
                }
            }
        }
    }

    function testInputGroupBuilder() {
        openRoot((window, cx:Context<ProbeView>) -> {
            final input:Entity<InputState> = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            final textarea:Entity<TextareaState> = cx.newEntity((c:Context<TextareaState>) -> new TextareaState(window, c));
            final group = new InputGroup('group')
                .input(new Input(input).ariaLabel('Replaced input'))
                .input(new Textarea(textarea).ariaLabel('Message').readonly(true))
                .disabled(true)
                .invalid(true)
                .small()
                .addon(new InputGroupAddon('footer')
                    .align(BlockEnd)
                    .child(new InputGroupText().child('Help'))
                    .child(new InputGroupButton('send').primary().label('Send')));
            assertEquals(textarea.entityId(), @:privateAccess group.control.getState().entityId());
            assertTrue(@:privateAccess group.disabledValue && @:privateAccess group.invalidValue);
            assertTrue((@:privateAccess group.size : Size).equals(Small));
            assertEquals(2, @:privateAccess group.addons[0].childElements.length);
            assertEquals(BlockEnd, @:privateAccess group.addons[0].alignment);

            final button = new InputGroupButton('icon').icon(IconName.Copy).small();
            assertTrue((@:privateAccess button.size : Size).equals(Small));
            assertTrue(@:privateAccess button.button.isIconOnly());
            assertTrue(@:privateAccess button.button.variant().match(Ghost));
            return new ProbeView((_, _) -> div());
        });
    }

    /// base number_input.rs

    /**
     * Pressing a step button must not move focus off the editor, not even for
     * the press itself: the frame draws a focus ring, so a focus round-trip
     * makes it flicker on every click.
     */
    function testPressingAStepButtonNeverTakesFocusOffTheEditor() {
        var state:Entity<InputState> = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 200, height: 100, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                state = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).step(1.));
                return cx.newEntity((_:Context<ProbeView>) -> new ProbeView((_, _) -> {
                    final number = new glaze.kit.base.NumberInput(state)
                        .decrementButton(button -> button.w(px(20.)).hFull())
                        .input(div().sizeFull())
                        .incrementButton(button -> button.w(px(20.)).hFull());
                    number.w(px(120.)).h(px(20.));
                    return number;
                }));
            });
        });
        runUntilParked();

        app.update(cx -> {
            base(state).update(cx, (s, cx) -> s.focus(window, cx));
            window.draw();
        });
        assertTrue(state.read(app).focusHandle.isFocused(window), 'the editor should start focused');

        // The decrement button sits at the left edge of the control.
        final position = new Point(10., 10.);
        app.update(cx -> window.dispatchEvent(new glaze.MouseMoveEvent(position, Left, Modifiers.none()), cx));
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, position, Modifiers.none(), 1, false), cx));
        assertTrue(state.read(app).focusHandle.isFocused(window), 'pressing the step button pulled focus off the editor');

        app.update(cx -> window.dispatchEvent(new MouseUpEvent(Left, position, Modifiers.none(), 1), cx));
        assertTrue(state.read(app).focusHandle.isFocused(window), 'releasing the step button left focus off the editor');
    }

    /// kit integration input.rs

    function inputs():InputsView {
        return openRoot((window, cx:Context<InputsView>) -> new InputsView(
            cx.newEntity((c:Context<InputState>) -> new InputState(window, c)),
            cx.newEntity((c:Context<InputState>) -> new InputState(window, c)),
            cx.newEntity((c:Context<InputState>) -> new InputState(window, c).defaultValue('fixed')),
            cx.newEntity((c:Context<InputState>) -> new InputState(window, c).withMasked(true))
        ));
    }

    function testTextGoesOnlyToTheFocusedInput() {
        final view = inputs();
        clickInput(base(view.first));
        input('A\u{1f980}');
        clickInput(base(view.second));
        input('中文');
        assertFalse(view.first.read(app).focusHandle.isFocused(window));
        assertTrue(view.second.read(app).focusHandle.isFocused(window));
        assertEquals('A\u{1f980}', view.first.read(app).value());
        assertEquals('中文', view.second.read(app).value());
    }

    function testReadonlyAndDisabledInputsRejectNativeTyping() {
        final view = inputs();
        for (disabled in [false, true]) {
            view.disabled = disabled;
            view.readonly = !disabled;
            app.update(cx -> (view : Entity<InputsView>).update(cx, (_, cx) -> cx.notify()));
            draw();
            clickInput(base(view.guarded));
            input('ignored');
            assertEquals('fixed', view.guarded.read(app).value());
        }
    }

    function testMaskedInputHandlesTypingWithoutReportingSecretValue() {
        final view = inputs();
        clickInput(base(view.secret));
        input('secret');
        assertTrue(view.secret.read(app).focusHandle.isFocused(window));
        assertEquals('secret', view.secret.read(app).value());
    }

    function testExistingGpuiKeyboardEditingUpdatesObservedValue() {
        final view = inputs();
        clickInput(base(view.first));
        input('ab');
        press('backspace');
        assertEquals('a', view.first.read(app).value());
    }

    function testMaskToggleFlipsTheMask() {
        final view = inputs();
        // Rust `mask_toggle_is_named_for_the_action_it_takes` reads the button's
        // accessibility label; the port checks what the click does.
        assertTrue(view.secret.read(app).masked);
        final bounds = view.secret.read(app).inputBounds;
        // The toggle is the suffix button, right after the text bounds.
        click(new Point(bounds.origin.x + bounds.size.width + 6 + 10, bounds.origin.y + bounds.size.height / 2));
        assertFalse(view.secret.read(app).masked);
    }

    /// kit integration input_focus.rs

    static final INPUT_IDS = ['first', 'second', 'third'];

    function openFocusInputs(buttons:Bool):FocusInputsView {
        return openRoot((window, cx:Context<FocusInputsView>) -> new FocusInputsView([for (_ in 0...3) cx.newEntity((c:Context<InputState>) -> new InputState(window, c))], buttons));
    }

    function assertFocus(view:FocusInputsView, expected:String):Void {
        draw();
        for (ix in 0...INPUT_IDS.length) {
            assertEquals(INPUT_IDS[ix] == expected, view.inputs[ix].read(app).focusHandle.isFocused(window), 'editor focus for ${INPUT_IDS[ix]} when $expected should be focused');
        }
        if (expected.indexOf('-button') >= 0) {
            assertNotNull(window.focused(app), '$expected should hold the focus');
        }
    }

    function testReverseTabCyclesThreeInputsWithPassiveAddons() {
        final order = INPUT_IDS;
        final view = openFocusInputs(false);
        clickInput(base(view.inputs[2]));
        assertFocus(view, order[2]);

        // Start with reverse traversal: duplicate entries used to leave the last
        // editor focused on the very first Shift-Tab. Include wraparound and repeat
        // each cycle to catch registrations accumulating across frames.
        for (pass in [{key: 'shift-tab', destinations: [order[1], order[0], order[2]]}, {key: 'tab', destinations: order}]) {
            for (_ in 0...2) {
                for (destination in pass.destinations) {
                    press(pass.key);
                    assertFocus(view, destination);
                    input('x');
                }
            }
        }

        for (ix in 0...INPUT_IDS.length) {
            assertEquals('xxxx', view.inputs[ix].read(app).value(), INPUT_IDS[ix]);
        }
    }

    function testTabCyclesKeepPrefixAndSuffixButtonsFocused() {
        final view = openFocusInputs(true);
        clickInput(base(view.inputs[2]));
        for (pass in [
            {key: 'shift-tab', destinations: ['suffix-button', 'second', 'prefix-button', 'first', 'third']},
            {key: 'tab', destinations: ['first', 'prefix-button', 'second', 'suffix-button', 'third']}
        ]) {
            for (destination in pass.destinations) {
                press(pass.key);
                assertFocus(view, destination);
                if (StringTools.endsWith(destination, '-button')) {
                    press('enter');
                    assertFocus(view, destination);
                } else {
                    input('x');
                }
            }
        }
        // Rust also clicks both buttons once before the cycles (3 in total):
        // the port cannot query their bounds, the keyboard clicks are checked.
        assertEquals(2, view.prefixClicks);
        assertEquals(2, view.suffixClicks);
        for (ix in 0...INPUT_IDS.length) {
            assertEquals('xx', view.inputs[ix].read(app).value(), INPUT_IDS[ix]);
        }
    }

    function testTextareaBodyClickFocusesEditorAndSupportsEditing() {
        var previous:Entity<InputState> = null;
        var field:Entity<TextareaState> = null;
        openRoot((window, cx:Context<ProbeView>) -> {
            previous = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            field = cx.newEntity((c:Context<TextareaState>) -> new TextareaState(window, c));
            return new ProbeView((_, _) -> div()
                .sizeFull()
                .flex()
                .flexCol()
                .p4()
                .gap4()
                .child(new Input(previous).id('previous').w96())
                .child(new Textarea(field).ariaLabel('Multiline field').w96().h(px(160.))));
        });
        clickInput(base(previous));
        final state = AnyInputState.textarea(field);
        assertTrue(previous.read(app).focusHandle.isFocused(window));
        assertFalse(state.focusHandle(app).isFocused(window));
        final body = field.read(app).textBounds();
        assertNotNull(body, 'multiline text body must be laid out');
        assertTrue(body.size.width > 8. && body.size.height > 8.);
        // Use measured text geometry, excluding the frame padding.
        click(new Point(body.origin.x + 4., body.origin.y + 4.));

        assertTrue(state.focusHandle(app).isFocused(window));
        assertFalse(previous.read(app).focusHandle.isFocused(window));
        input('abcd');
        assertEquals('abcd', state.value(app));
        // Delete at the caret, move left, then extend the selection left. The
        // replacement proves that both movement and selection reached the editor.
        press('backspace');
        assertEquals('abc', state.value(app));
        press('left');
        press('shift-left');
        input('Z');
        assertEquals('aZc', state.value(app));
        assertTrue(state.focusHandle(app).isFocused(window));
        // Multiline Shift-Tab is OutdentInline. Exercise the same public
        // traversal primitive Root uses without overriding that key binding.
        app.update(cx -> window.focusPrev(cx));
        runUntilParked();
        draw();
        assertTrue(previous.read(app).focusHandle.isFocused(window));
        assertFalse(state.focusHandle(app).isFocused(window));
        input('previous');
        assertEquals('previous', previous.read(app).value());
        assertEquals('aZc', state.value(app));
    }

}

/** A view rendering through a function. */
private class ProbeView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}

/** Rust `Inputs` of the integration `input.rs`. */
private class InputsView extends Model implements Render {

    public final first:Entity<InputState>;
    public final second:Entity<InputState>;
    public final guarded:Entity<InputState>;
    public final secret:Entity<InputState>;
    public var disabled:Bool = false;
    public var readonly:Bool = false;

    public function new(first:Entity<InputState>, second:Entity<InputState>, guarded:Entity<InputState>, secret:Entity<InputState>) {
        super();
        this.first = first;
        this.second = second;
        this.guarded = guarded;
        this.secret = secret;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .flex()
            .flexCol()
            .gap4()
            .child(new Input(first).id('first').w(px(240.)))
            .child(new Input(second).id('second').w(px(240.)))
            .child(new Input(guarded).id('guarded').w(px(240.)).disabled(disabled).readonly(readonly))
            .child(new Input(secret).id('secret').maskToggle().w(px(240.)));
    }

}

/** Rust `InputFocus` of the integration `input_focus.rs`. */
private class FocusInputsView extends Model implements Render {

    public final inputs:Array<Entity<InputState>>;
    public final buttons:Bool;
    public var prefixClicks:Int = 0;
    public var suffixClicks:Int = 0;

    static final INPUT_IDS = ['first', 'second', 'third'];
    static final INPUT_LABELS = ['First entry', 'Second entry', 'Third entry'];

    public function new(inputs:Array<Entity<InputState>>, buttons:Bool) {
        super();
        this.inputs = inputs;
        this.buttons = buttons;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().flex().flexCol().p4().gap4().children([for (ix in 0...INPUT_IDS.length) {
            final id = INPUT_IDS[ix];
            final input = new Input(inputs[ix])
                .id(id)
                .ariaLabel(INPUT_LABELS[ix])
                .prefix(div().child('Prefix'))
                .suffix(div().child('Suffix'));
            input.w96();
            if (buttons && id == 'second') {
                input
                    .prefix(new Button('prefix-button').label('Prefix').onClick((_, _, _) -> prefixClicks++))
                    .suffix(new Button('suffix-button').label('Suffix').onClick((_, _, _) -> suffixClicks++));
            }
            (input : IntoElement);
        }]);
    }

}
