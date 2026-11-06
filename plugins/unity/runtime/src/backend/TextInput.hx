package backend;

import ceramic.KeyCode;
import ceramic.ScanCode;
import ceramic.VirtualKeyboardType;
import cs.types.Char16;
import unityengine.inputsystem.Keyboard;

using StringTools;

#if !no_backend_docs
/**
 * Unity backend implementation for text input handling.
 * Captures keyboard input from Unity's Input System and converts it to Ceramic text events.
 * Handles special keys like arrows, backspace, enter, and escape.
 *
 * On iOS and Android (`TouchScreenKeyboard.isSupported`), text input and
 * text editing also open the virtual keyboard (`virtualKeyboard`): the edits
 * of its hidden field become caret moves, deletions and text
 * (`ceramic.VirtualKeyboardText`), given as left, right, backspace and enter
 * key events plus `textCommit` to text editing, and as `ceramic.TextInput`
 * calls to text input, like SDL does with its hidden iOS text field.
 */
#end
class TextInput implements spec.TextInput {

    #if !no_backend_docs
    /**
     * Whether text input is currently active.
     * When true, keyboard input is captured and converted to text events.
     */
    #end
    public var textInputActive(default, null):Bool = false;

    #if !no_backend_docs
    /**
     * Creates a new TextInput handler and binds to Unity's keyboard events.
     */
    #end
    public function new() {

        bindTextInput();

        keyboardText.onMove = keyboardMove;
        keyboardText.onDelete = keyboardDelete;
        keyboardText.onInsert = keyboardInsert;
        keyboardText.onLineBreak = keyboardLineBreak;

    }

    #if !no_backend_docs
    /**
     * Keyboard whose text and IME composition events are bound, if any.
     */
    #end
    var boundKeyboard:Keyboard = null;

    #if !no_backend_docs
    /**
     * Delegate bound to `Keyboard.onIMECompositionChange` (a C# delegate,
     * kept to unbind it).
     */
    #end
    var imeCompositionHandler:Dynamic = null;

    #if !no_backend_docs
    /**
     * Joins the UTF-16 surrogates of characters outside the BMP (emoji),
     * which Unity reports as two separate text input calls.
     */
    #end
    final utf16Joiner = new ceramic.Utf16Joiner();

    #if !no_backend_docs
    /**
     * Text and composition events received from the Input System, emitted
     * by `flushPendingText()` (after the key events of the same frame, as
     * SDL orders them).
     */
    #end
    var pendingTexts:Array<String> = [];

    #if !no_backend_docs
    /**
     * Kind of each pending event: 0 for committed text, 1 for a composition.
     */
    #end
    var pendingKinds:Array<Int> = [];

    #if !no_backend_docs
    /**
     * Binds to Unity's text input and IME composition events.
     */
    #end
    function bindTextInput():Void {

        updateKeyboardBinding();

    }

    #if !no_backend_docs
    /**
     * Binds the text events of `Keyboard.current`, again when it changes
     * (no keyboard when the app started, a keyboard added later, a virtual
     * keyboard of a test). Called every frame by `backend.Input`.
     */
    #end
    @:allow(backend.Input)
    function updateKeyboardBinding():Void {

        final keyboard = Keyboard.current;
        if (keyboard == boundKeyboard) return;

        if (boundKeyboard != null) {
            untyped __cs__('{0}.onTextInput -= handleTextInput', boundKeyboard);
            if (imeCompositionHandler != null) {
                untyped __cs__('{0}.onIMECompositionChange -= (System.Action<UnityEngine.InputSystem.LowLevel.IMECompositionString>){1}', boundKeyboard, imeCompositionHandler);
            }
        }

        boundKeyboard = keyboard;
        utf16Joiner.reset();

        if (keyboard != null) {
            untyped __cs__('{0}.onTextInput += handleTextInput', keyboard);
            if (imeCompositionHandler == null) {
                imeCompositionHandler = untyped __cs__('(System.Action<UnityEngine.InputSystem.LowLevel.IMECompositionString>)((s) => handleImeComposition(s.ToString()))');
            }
            untyped __cs__('{0}.onIMECompositionChange += (System.Action<UnityEngine.InputSystem.LowLevel.IMECompositionString>){1}', keyboard, imeCompositionHandler);
            if (textEditing) {
                untyped __cs__('{0}.SetIMEEnabled(true)', keyboard);
            }
        }

    }

    #if !no_backend_docs
    /**
     * Handles one UTF-16 code unit from Unity's `Keyboard.onTextInput`:
     * surrogate pairs are joined, then the text waits for
     * `flushPendingText()`.
     * @param csChar UTF-16 code unit from Unity
     */
    #end
    @:keep function handleTextInput(csChar:Char16):Void {

        final unit:Int = untyped __cs__('(int){0}', csChar);
        final text = utf16Joiner.push(unit);
        if (text != null) {
            pendingTexts.push(text);
            pendingKinds.push(0);
        }

    }

    #if !no_backend_docs
    /**
     * Handles a change of the IME composition (the whole composed text, an
     * empty string when the composition ends).
     * @param text The composed text
     */
    #end
    @:keep function handleImeComposition(text:String):Void {

        pendingTexts.push(text != null ? text : '');
        pendingKinds.push(1);

    }

    #if !no_backend_docs
    /**
     * Emits the text and composition events received since the previous
     * call, in their order. Called by `backend.Input` after the key events.
     */
    #end
    @:allow(backend.Input)
    function flushPendingText():Void {

        updateVirtualKeyboard();

        if (pendingTexts.length == 0) return;

        if (keyboardOpen) {
            // The virtual keyboard is the source of text while it is open:
            // text of the Input System (a hardware keyboard) would come twice
            pendingTexts.resize(0);
            pendingKinds.resize(0);
            utf16Joiner.reset();
            return;
        }

        final texts = pendingTexts;
        final kinds = pendingKinds;
        pendingTexts = [];
        pendingKinds = [];

        for (i in 0...texts.length) {
            if (kinds[i] == 1) {
                if (textEditing) {
                    final value = texts[i];
                    @:privateAccess ceramic.App.app.backend.input.emitTextComposition(value, value.length, 0);
                }
            }
            else {
                _handleTextInput(texts[i]);
            }
        }

    }

    #if !no_backend_docs
    /**
     * Processes text input and converts to appropriate Ceramic events.
     * Handles special keys and filters non-printable characters.
     * @param char One character (one or two UTF-16 code units)
     */
    #end
    function _handleTextInput(char:String):Void {

        if (textEditing) {
            var text:String = char;
            var code:Int = text.charCodeAt(0);
            // Skip control characters and the private use codes unity gives for arrows and function keys
            if (code >= 32 && code != 127 && !(code >= 63232 && code <= 63254)) {
                @:privateAccess ceramic.App.app.backend.input.emitTextCommit(text);
            }
        }

        if (textInputActive) {
            var code:Int = char.charCodeAt(0);

            #if ceramic_debug_text_input
            ceramic.Shortcuts.log.success('APPEND ' + haxe.Json.stringify(char) + ' / ' + char.charCodeAt(0));
            #end

            // Only tested on macOS for now
            // TODO: try on other platforms

            switch (code) {
                case 63234:
                    ceramic.App.app.textInput.moveLeft();
                case 63235:
                    ceramic.App.app.textInput.moveRight();
                case 63232:
                    ceramic.App.app.textInput.moveUp();
                case 63233:
                    ceramic.App.app.textInput.moveDown();
                case 32:
                    ceramic.App.app.textInput.space();
                case 127:
                    ceramic.App.app.textInput.backspace();
                case 27:
                    ceramic.App.app.textInput.escape();
                default:
                    if (code >= 63236 && code <= 63254) {
                        // Function keys, ignore
                    }
                    else if (char == '\n' || char == '\r' || char == '\r\n') {
                        ceramic.App.app.textInput.enter();
                    }
                    else if (code < 32) {
                        // Ignore, not printable
                    }
                    else {
                        ceramic.App.app.textInput.appendText(char);
                    }
            }

            /*
            var keyboard = Keyboard.current;
            if (keyboard.leftArrowKey.isPressed
                || keyboard.rightArrowKey.isPressed
                || keyboard.upArrowKey.isPressed
                || keyboard.downArrowKey.isPressed) {
                // Ignore: arrow keys
            }
            else if (keyboard.escapeKey.isPressed) {
                // Ignore escape
            }
            else if (keyboard.backspaceKey.isPressed) {
                // Ignore backspace
            }
            else if (keyboard.enterKey.isPressed) {
                // Ignore enter
            }
            else if (keyboard.f1Key.isPressed
                || keyboard.f2Key.isPressed
                || keyboard.f3Key.isPressed
                || keyboard.f4Key.isPressed
                || keyboard.f5Key.isPressed
                || keyboard.f6Key.isPressed
                || keyboard.f7Key.isPressed
                || keyboard.f8Key.isPressed
                || keyboard.f9Key.isPressed
                || keyboard.f10Key.isPressed
                || keyboard.f11Key.isPressed
                || keyboard.f12Key.isPressed) {
                // Ignore function keys
            }
            else if (char.trim().length > 0) {
                if (char == '\r' || char == '\n' || char == ' ') {
                    // Ignore: line break, spaces
                }
                else {
                    ceramic.App.app.textInput.appendText(char);
                }
            }
            */
        }

    }

    #if !no_backend_docs
    /**
     * Starts text input mode. Opens the virtual keyboard on iOS and Android.
     * @param initialText Initial text value (currently unused)
     * @param x Text field X position (for virtual keyboard positioning)
     * @param y Text field Y position (for virtual keyboard positioning)
     * @param w Text field width
     * @param h Text field height
     */
    #end
    public function start(initialText:String, x:Float, y:Float, w:Float, h:Float):Void {

        textInputActive = true;
        requestVirtualKeyboard();

    }

    #if !no_backend_docs
    /**
     * Stops text input mode.
     * Disables keyboard capture.
     */
    #end
    public function stop():Void {

        textInputActive = false;
        if (!textEditing) {
            keyboardWanted = false;
        }

    }

/// Text editing (independent from start/stop)

    #if !no_backend_docs
    /**
     * Whether text editing is active (see `ceramic.Input.startTextEditing()`).
     */
    #end
    var textEditing:Bool = false;

    #if !no_backend_docs
    /**
     * Enables IME input on the current keyboard and forwards its composition.
     * Committed text comes from `Keyboard.onTextInput`. Unity doesn't give the
     * cursor position inside the composition: it is reported at the end.
     */
    #end
    public function startTextEditing(x:Float, y:Float, w:Float, h:Float):Void {

        textEditing = true;

        updateKeyboardBinding();
        if (Keyboard.current != null) {
            untyped __cs__('UnityEngine.InputSystem.Keyboard.current.SetIMEEnabled(true)');
        }
        setTextEditingArea(x, y, w, h, 0);
        requestVirtualKeyboard();

    }

    #if !no_backend_docs
    /**
     * Disables IME input enabled with `startTextEditing()`.
     */
    #end
    public function stopTextEditing():Void {

        if (!textEditing) return;
        textEditing = false;

        if (Keyboard.current != null) {
            untyped __cs__('UnityEngine.InputSystem.Keyboard.current.SetIMEEnabled(false)');
        }
        if (!textInputActive) {
            keyboardWanted = false;
        }

    }

    #if !no_backend_docs
    /**
     * Moves the IME candidate window next to the cursor (best effort: Unity expects
     * screen pixels with a bottom-left origin).
     */
    #end
    public function setTextEditingArea(x:Float, y:Float, w:Float, h:Float, cursor:Float):Void {

        if (!textEditing || Keyboard.current == null) return;

        final density = ceramic.App.app.backend.screen.getDensity();
        final screenHeight = ceramic.App.app.backend.screen.getHeight();
        final posX:Single = (x + cursor) * density;
        final posY:Single = (screenHeight - (y + h)) * density;
        untyped __cs__('UnityEngine.InputSystem.Keyboard.current.SetIMECursorPosition(new UnityEngine.Vector2({0}, {1}))', posX, posY);

    }

    #if !no_backend_docs
    /**
     * Virtual keyboard settings (see `ceramic.Input.setTextEditingConfiguration()`).
     */
    #end
    var configInputMode:String = 'text';

    var configEnterKeyHint:Null<String> = null;

    var configAutocorrect:Bool = false;

    #if !no_backend_docs
    /**
     * Sets the virtual keyboard of iOS and Android: its type
     * (`ceramic.VirtualKeyboardType`, from `inputMode` and the `search`
     * enter key hint), whether its return key inserts line breaks or closes
     * it (`enterKeyHint`, see `VirtualKeyboardType.multilineFromConfiguration()`),
     * and autocorrection. Unity's keyboard has no autocapitalization or
     * spellcheck setting. An open keyboard is opened again (at the next
     * update) when its type, return key or autocorrection changes.
     */
    #end
    public function setTextEditingConfiguration(inputMode:String, enterKeyHint:Null<String>, autocapitalize:String, autocorrect:Bool, spellcheck:Bool):Void {

        configInputMode = inputMode != null ? inputMode : 'text';
        configEnterKeyHint = enterKeyHint;
        configAutocorrect = autocorrect;

    }

/// Virtual keyboard (iOS, Android)

    /**
     * The virtual keyboard opened by text input and text editing: Unity's
     * `TouchScreenKeyboard` where it is supported (iOS, Android), null
     * elsewhere (desktop keeps the Input System keyboard only). Tests can
     * set another implementation to simulate a keyboard.
     */
    public var virtualKeyboard:Null<VirtualKeyboard> = UnityTouchScreenKeyboard.isSupported() ? new UnityTouchScreenKeyboard() : null;

    #if !no_backend_docs
    /**
     * Turns the edits of the hidden field of the keyboard into operations.
     */
    #end
    final keyboardText:ceramic.VirtualKeyboardText = new ceramic.VirtualKeyboardText();

    #if !no_backend_docs
    /**
     * Follows the touches to tell taps apart (see `handleTouchUp()`).
     */
    #end
    final keyboardTaps:ceramic.TouchTapTracker = new ceramic.TouchTapTracker();

    /** Whether the virtual keyboard is open. */
    public var keyboardOpen(default, null):Bool = false;

    #if !no_backend_docs
    /**
     * Whether the keyboard should be open: set by text input and text
     * editing starting and by a tap on an editable area, cleared when both
     * stopped or when the user closed the keyboard. The keyboard follows it
     * at the next update (`updateVirtualKeyboard()`): the focus going from
     * a field to another stops then starts text editing in the same frame,
     * and the settings of the new field may arrive after it starts, which
     * must neither close and open the keyboard again nor open it twice.
     */
    #end
    var keyboardWanted:Bool = false;

    #if !no_backend_docs
    /**
     * Whether the hidden field starts over at the next update (another
     * field, or a caret moved by a tap).
     */
    #end
    var keyboardResetPending:Bool = false;

    #if !no_backend_docs
    /**
     * Settings of the open keyboard.
     */
    #end
    var keyboardType:VirtualKeyboardType = DEFAULT;

    var keyboardMultiline:Bool = true;

    var keyboardAutocorrect:Bool = false;

    #if !no_backend_docs
    /**
     * Asks for the keyboard, its hidden field starting over (another field
     * may be edited).
     */
    #end
    function requestVirtualKeyboard():Void {

        if (virtualKeyboard == null) return;
        keyboardWanted = true;
        keyboardResetPending = true;

    }

    #if !no_backend_docs
    /**
     * Opens, closes or opens again the keyboard to match `keyboardWanted`
     * and the settings.
     */
    #end
    function syncVirtualKeyboard():Void {

        final type = VirtualKeyboardType.fromConfiguration(configInputMode, configEnterKeyHint);
        if (!keyboardWanted || type == NONE) {
            closeVirtualKeyboard();
            keyboardResetPending = false;
            return;
        }

        final multiline = VirtualKeyboardType.multilineFromConfiguration(configEnterKeyHint);
        if (keyboardOpen && type == keyboardType && multiline == keyboardMultiline && configAutocorrect == keyboardAutocorrect) {
            if (keyboardResetPending) {
                resetVirtualKeyboardText();
            }
            keyboardResetPending = false;
            return;
        }

        keyboardResetPending = false;
        keyboardType = type;
        keyboardMultiline = multiline;
        keyboardAutocorrect = configAutocorrect;
        keyboardText.reset();
        virtualKeyboard.open(keyboardText.text, type, configAutocorrect, multiline);
        virtualKeyboard.setSelection(keyboardText.caret, 0);
        if (!keyboardOpen) {
            keyboardOpen = true;
            ceramic.App.app.backend.screen.virtualKeyboardVisibilityChange(true);
        }

    }

    #if !no_backend_docs
    /**
     * Closes the virtual keyboard now.
     */
    #end
    function closeVirtualKeyboard():Void {

        if (!keyboardOpen) return;
        keyboardOpen = false;
        if (virtualKeyboard != null) {
            virtualKeyboard.close();
        }
        ceramic.App.app.backend.screen.virtualKeyboardVisibilityChange(false);

    }

    #if !no_backend_docs
    /**
     * The hidden field of the keyboard starts over (`padding`, caret at the
     * end). The caret of the app does not move.
     */
    #end
    function resetVirtualKeyboardText():Void {

        keyboardText.reset();
        if (virtualKeyboard != null) {
            virtualKeyboard.setText(keyboardText.text);
            virtualKeyboard.setSelection(keyboardText.caret, 0);
        }

    }

    #if !no_backend_docs
    /**
     * Reads the hidden field of the open keyboard and gives its edits to the
     * app, handles a keyboard that the user closed (its return key on a
     * single line keyboard is an enter key), then opens or closes the
     * keyboard as text input and text editing ask. Called every frame,
     * after the key events (`flushPendingText()`).
     */
    #end
    function updateVirtualKeyboard():Void {

        if (virtualKeyboard == null) return;

        if (keyboardOpen) {
            final status = virtualKeyboard.getStatus();
            final text = virtualKeyboard.getText();
            if (text != null) {
                if (keyboardText.update(text, virtualKeyboard.getSelectionStart(), virtualKeyboard.getSelectionLength()) && status == VISIBLE) {
                    keyboardResetPending = true;
                }
            }
            if (status != VISIBLE) {
                // Closed by the user: stays closed until a tap on an
                // editable area or text editing starting again
                keyboardWanted = false;
                closeVirtualKeyboard();
                if (status == DONE && !keyboardMultiline) {
                    keyboardLineBreak();
                }
            }
        }

        syncVirtualKeyboard();

    }

    #if !no_backend_docs
    /**
     * Emits a key down and its key up (keys of the virtual keyboard).
     */
    #end
    function emitVirtualKey(keyCode:KeyCode, scanCode:ScanCode):Void {

        final input = ceramic.App.app.backend.input;
        @:privateAccess input.emitKeyDown(new ceramic.Key(keyCode, scanCode));
        @:privateAccess input.emitKeyUp(new ceramic.Key(keyCode, scanCode));

    }

    function keyboardMove(graphemes:Int):Void {

        final count = graphemes < 0 ? -graphemes : graphemes;
        for (_ in 0...count) {
            if (textEditing) {
                if (graphemes < 0) emitVirtualKey(KeyCode.LEFT, ScanCode.LEFT);
                else emitVirtualKey(KeyCode.RIGHT, ScanCode.RIGHT);
            }
            if (textInputActive) {
                if (graphemes < 0) ceramic.App.app.textInput.moveLeft();
                else ceramic.App.app.textInput.moveRight();
            }
        }

    }

    function keyboardDelete(graphemes:Int):Void {

        for (_ in 0...graphemes) {
            if (textEditing) {
                emitVirtualKey(KeyCode.BACKSPACE, ScanCode.BACKSPACE);
            }
            if (textInputActive) {
                ceramic.App.app.textInput.backspace();
            }
        }

    }

    function keyboardInsert(text:String):Void {

        if (textEditing) {
            @:privateAccess ceramic.App.app.backend.input.emitTextCommit(text);
        }

        if (textInputActive) {
            // Spaces go through space(), like the keyboard path
            final textInput = ceramic.App.app.textInput;
            var start = 0;
            for (i in 0...text.length) {
                if (StringTools.fastCodeAt(text, i) == ' '.code) {
                    if (i > start) textInput.appendText(text.substring(start, i));
                    textInput.space();
                    start = i + 1;
                }
            }
            if (text.length > start) {
                textInput.appendText(start == 0 ? text : text.substring(start));
            }
        }

    }

    function keyboardLineBreak():Void {

        if (textEditing) {
            emitVirtualKey(KeyCode.ENTER, ScanCode.ENTER);
        }
        if (textInputActive) {
            ceramic.App.app.textInput.enter();
        }

    }

    #if !no_backend_docs
    /**
     * Touches, from `backend.Screen` (native coordinates). A tap while the
     * keyboard is open may move the caret of the app: the hidden field
     * starts over. A tap on an editable area (`ceramic.Input.textEditingTapFilter`)
     * while text editing shows a keyboard that the user closed again.
     */
    #end
    @:allow(backend.Screen)
    function handleTouchDown(touchIndex:Int, x:Float, y:Float):Void {

        if (virtualKeyboard == null) return;
        keyboardTaps.touchDown(touchIndex, x, y, 0);

    }

    @:allow(backend.Screen)
    function handleTouchMove(touchIndex:Int, x:Float, y:Float):Void {

        if (virtualKeyboard == null) return;
        keyboardTaps.touchMove(touchIndex, x, y);

    }

    @:allow(backend.Screen)
    function handleTouchCancel(touchIndex:Int, x:Float, y:Float):Void {

        if (virtualKeyboard == null) return;
        keyboardTaps.touchCancel(touchIndex);

    }

    @:allow(backend.Screen)
    function handleTouchUp(touchIndex:Int, x:Float, y:Float):Void {

        if (virtualKeyboard == null) return;
        if (!keyboardTaps.touchUp(touchIndex, x, y, 0)) return;

        if (keyboardOpen) {
            keyboardResetPending = true;
        }
        else if (textEditing && ceramic.App.app.input.textEditingTapTargets(x, y)) {
            requestVirtualKeyboard();
        }

    }

}
