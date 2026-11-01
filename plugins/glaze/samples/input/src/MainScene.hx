package;

import ceramic.Color;
import ceramic.Key;
import ceramic.KeyCode;
import ceramic.KeyModifiers;
import ceramic.MouseCursor;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.ScanCode;
import ceramic.Text;
import ceramic.Timer;

/**
 * Input patches test:
 * - logs key events with their modifiers and produced character
 * - TAB cycles the mouse cursor shape (shift + TAB goes back)
 * - text editing is active: committed text and IME composition are logged
 *   and displayed (composition between brackets)
 *
 * With `INPUT_SAMPLE_SELFTEST=1` in the environment (native, or web under the electron runner), every cursor
 * shape is applied once, then the app quits after a few seconds.
 */
class MainScene extends Scene {

    var info:Text;

    var field:Quad;

    var fieldText:Text;

    var committed:String = '';

    var composition:String = '';

    var cursorIndex:Int = 0;

    static final CURSORS:Array<MouseCursor> = [
        ARROW, IBEAM, CROSSHAIR, CLOSED_HAND, OPEN_HAND, POINTING_HAND,
        RESIZE_LEFT, RESIZE_RIGHT, RESIZE_LEFT_RIGHT, RESIZE_UP, RESIZE_DOWN, RESIZE_UP_DOWN,
        RESIZE_UP_LEFT_DOWN_RIGHT, RESIZE_UP_RIGHT_DOWN_LEFT, RESIZE_COLUMN, RESIZE_ROW,
        IBEAM_VERTICAL, OPERATION_NOT_ALLOWED, DRAG_LINK, DRAG_COPY, CONTEXTUAL_MENU, NONE
    ];

    override function create() {

        info = new Text();
        info.pointSize = 14;
        info.color = Color.WHITE;
        info.pos(20, 20);
        add(info);

        field = new Quad();
        field.color = 0x333333;
        field.size(width - 40, 40);
        field.pos(20, 200);
        add(field);

        fieldText = new Text();
        fieldText.pointSize = 20;
        fieldText.color = Color.WHITE;
        fieldText.pos(28, 208);
        add(fieldText);

        input.onKeyDown(this, handleKeyDown);
        input.onKeyUp(this, key -> log.info('keyUp $key'));

        input.onTextCommit(this, text -> {
            log.success('textCommit ${haxe.Json.stringify(text)}');
            committed += text;
            composition = '';
            updateField();
        });
        input.onTextComposition(this, (text, start, length) -> {
            log.warning('textComposition ${haxe.Json.stringify(text)} start=$start length=$length');
            composition = text;
            updateField();
        });

        screen.onPointerDown(this, info -> {
            log.info('pointerDown modifiers=${input.modifiers.toString()}');
        });

        input.startTextEditing(field.x, field.y, field.width, field.height);
        log.success('text editing started: ${input.textEditing}');

        updateInfo();
        updateField();

        if (ceramic.Platform.getEnv('INPUT_SAMPLE_SELFTEST') == '1') {
            selfTest();
        }

    }

    function handleKeyDown(key:Key) {

        log.info('keyDown $key modifiers=${key.modifiers.toString()} keyChar=${haxe.Json.stringify(key.keyChar)} composing=${input.textComposing}');

        if (key.scanCode == ScanCode.TAB) {
            cursorIndex = (cursorIndex + (key.modifiers.shift ? CURSORS.length - 1 : 1)) % CURSORS.length;
            screen.cursor = CURSORS[cursorIndex];
            log.success('cursor = ${screen.cursor.toString()}');
            updateInfo();
        }
        else if (key.scanCode == ScanCode.BACKSPACE && !input.textComposing && committed.length > 0) {
            committed = committed.substr(0, committed.length - 1);
            updateField();
        }

    }

    function updateInfo() {

        info.content = 'Press keys: events are logged with modifiers and produced character.\n'
            + 'TAB / shift + TAB: cycle mouse cursor (current: ${screen.cursor.toString()})\n'
            + 'Type below, IME composition is shown between brackets.';

    }

    function updateField() {

        fieldText.content = committed + (composition.length > 0 ? '[' + composition + ']' : '');
        input.setTextEditingArea(field.x, field.y, field.width, field.height, fieldText.width + 8);

    }

    function selfTest() {

        var index = 0;
        app.onUpdate(this, _ -> {
            if (index < CURSORS.length) {
                screen.cursor = CURSORS[index];
                log.success('selftest cursor ${index}: ${screen.cursor.toString()}');
                index++;
            }
        });

        #if web
        // Real DOM events, going through clay's web runtime and the hidden textarea
        Timer.delay(this, 0.5, () -> {
            final doc = js.Browser.document;
            final keyInit:Dynamic = { key: 'A', code: 'KeyA', keyCode: 65, shiftKey: true, bubbles: true };
            doc.dispatchEvent(js.Syntax.code('new KeyboardEvent("keydown", {0})', keyInit));
            doc.dispatchEvent(js.Syntax.code('new KeyboardEvent("keyup", {0})', keyInit));
            final cmdInit:Dynamic = { key: 's', code: 'KeyS', keyCode: 83, metaKey: true, bubbles: true };
            doc.dispatchEvent(js.Syntax.code('new KeyboardEvent("keydown", {0})', cmdInit));
            final spaceInit:Dynamic = { key: ' ', code: 'Space', keyCode: 32, bubbles: true, cancelable: true };
            doc.dispatchEvent(js.Syntax.code('new KeyboardEvent("keydown", {0})', spaceInit));
            doc.dispatchEvent(js.Syntax.code('new KeyboardEvent("keyup", {0})', spaceInit));
            final textArea:js.html.Element = cast doc.querySelector('textarea.ceramic-text-editing');
            log.success('selftest textarea found=${textArea != null} focused=${doc.activeElement == textArea}');
            if (textArea != null) {
                textArea.dispatchEvent(js.Syntax.code('new CompositionEvent("compositionstart", { data: "" })'));
                textArea.dispatchEvent(js.Syntax.code('new CompositionEvent("compositionupdate", { data: "にほ" })'));
                textArea.dispatchEvent(js.Syntax.code('new CompositionEvent("compositionend", { data: "日本" })'));
                textArea.dispatchEvent(js.Syntax.code('new InputEvent("input", { inputType: "insertText", data: "x" })'));
            }
        });
        #else
        // Simulated backend events (as a platform would send them)
        @:privateAccess app.backend.input.emitKeyDown(new Key(KeyCode.KEY_A, ScanCode.KEY_A, KeyModifiers.SHIFT | KeyModifiers.CAPS_LOCK, 'A'));
        @:privateAccess app.backend.input.emitTextComposition('にほ', 2, 0);
        @:privateAccess app.backend.input.emitTextCommit('日本');
        #end

        Timer.delay(this, 3.0, () -> {
            log.success('selftest done, modifiers=${input.modifiers.toString()} composing=${input.textComposing} text=${haxe.Json.stringify(committed)}');
            input.stopTextEditing();
            screen.cursor = ARROW;
            #if web
            final runner = backend.ElectronRunner.electronRunner;
            if (runner != null && runner.takeScreenshot != null) runner.takeScreenshot();
            #elseif sys
            Sys.exit(0);
            #end
        });

    }

}
