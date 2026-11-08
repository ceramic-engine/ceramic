// Ported from gpui-pre 0.3.10: examples/input.rs (InputExample, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package;

import ceramic.Scene;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Glaze;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseUpEvent;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import textfield.TextInput;

import glaze.Prelude.*;

/**
 * GPUI's input example: a text field (`textfield.TextInput`, built only on
 * GPUI APIs) with typing, IME composition (try a Japanese input source),
 * selection with the keyboard and the mouse, copy / cut / paste, and the list
 * of recent keystrokes. The text field is focused at start.
 */
class MainScene extends Scene {

    var ui:Glaze;

    var keystrokes:Subscription;

    override function create() {

        final cx = Glaze.app;
        TextInput.bindKeys(cx);

        var example:Entity<InputExample> = null;
        ui = new Glaze((window, cx) -> {
            final textInput = cx.newEntity((inputCx:Context<TextInput>) -> new TextInput(inputCx.focusHandle(), '', 'Type here...'));
            example = cx.newEntity((exampleCx:Context<InputExample>) -> new InputExample(textInput, exampleCx.focusHandle()));
            return example;
        });
        ui.size(width, height);
        add(ui);
        final window = ui.window;

        keystrokes = cx.observeKeystrokes((event, _, cx) -> {
            example.update(cx, (view, cx) -> {
                view.recentKeystrokes.push(event.keystroke);
                cx.notify();
            });
        });

        cx.update(cx -> window.focus(example.read(cx).textInput.read(cx).focusHandle, cx));

        final selfTest = ceramic.Platform.getEnv('TEXTFIELD_SELFTEST');
        if (selfTest != null && selfTest != '') {
            runSelfTest(selfTest);
        }

    }

    /**
     * Feeds Ceramic text editing events (what SDL or the browser would send),
     * captures the screen to `path` and quits.
     */
    function runSelfTest(path:String):Void {

        final input = app.input;
        ceramic.Timer.delay(this, 0.5, () -> {
            @:privateAccess input.emitTextCommit('Hello ');
            @:privateAccess input.emitTextCommit('🙂 ');
            @:privateAccess input.emitTextComposition('かん', 2, 0);
        });
        ceramic.Timer.delay(this, 1.5, () -> {
            screen.toPng(path, () -> {
                log.success('Captured $path');
                app.quit();
            });
        });

    }

    override function resize(width:Float, height:Float) {

        if (ui != null) ui.size(width, height);

    }

    override function destroy() {

        if (keystrokes != null) {
            keystrokes.dispose();
            keystrokes = null;
        }

        super.destroy();

    }

}

class InputExample extends Model implements Render {

    public final textInput:Entity<TextInput>;

    public final recentKeystrokes:Array<Keystroke> = [];

    public final focusHandle:FocusHandle;

    public function new(textInput:Entity<TextInput>, focusHandle:FocusHandle) {
        super();
        this.textInput = textInput;
        this.focusHandle = focusHandle;
    }

    function onResetClick(_:MouseUpEvent, window:Window, cx:Context<InputExample>):Void {
        recentKeystrokes.resize(0);
        textInput.update(cx, (textInput, cx) -> textInput.reset(window, cx));
        cx.notify();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<InputExample> = cast cx;
        final recent = recentKeystrokes.copy();
        recent.reverse();
        return div()
            .bg(rgb(0xaaaaaa))
            .trackFocus(focusHandle)
            .flex()
            .flexCol()
            .sizeFull()
            .child(
                div()
                    .bg(white())
                    .borderB1()
                    .borderColor(black())
                    .flex()
                    .flexRow()
                    .justifyBetween()
                    .child('Keyboard')
                    .child(
                        div()
                            .border1()
                            .borderColor(black())
                            .px2()
                            .bg(yellow())
                            .child('Reset')
                            .hover(style -> style.bg(yellow().blend(opaqueGrey(0.5, 0.5))).cursorPointer())
                            .onMouseUp(MouseButton.Left, cx.listener((view:InputExample, event:MouseUpEvent, window, cx) -> view.onResetClick(event, window, cx)))
                    )
            )
            .child(textInput)
            .children([for (keystroke in recent) (describe(keystroke) : IntoElement)]);
    }

    static function describe(keystroke:Keystroke):String {
        return keystroke.unparse(glaze.OperatingSystem.current) + (keystroke.keyChar != null ? ' -> "' + keystroke.keyChar + '"' : '');
    }

}
