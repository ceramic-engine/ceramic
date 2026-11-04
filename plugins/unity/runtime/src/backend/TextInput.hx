package backend;

import cs.types.Char16;
import unityengine.inputsystem.Keyboard;

using StringTools;

#if !no_backend_docs
/**
 * Unity backend implementation for text input handling.
 * Captures keyboard input from Unity's Input System and converts it to Ceramic text events.
 * Handles special keys like arrows, backspace, enter, and escape.
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

        if (pendingTexts.length == 0) return;

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
     * Starts text input mode.
     * TODO: Show virtual keyboard on mobile devices.
     * @param initialText Initial text value (currently unused)
     * @param x Text field X position (for virtual keyboard positioning)
     * @param y Text field Y position (for virtual keyboard positioning)
     * @param w Text field width
     * @param h Text field height
     */
    #end
    public function start(initialText:String, x:Float, y:Float, w:Float, h:Float):Void {

        textInputActive = true;

        // TODO show keyboard on mobile devices

    }

    #if !no_backend_docs
    /**
     * Stops text input mode.
     * Disables keyboard capture.
     */
    #end
    public function stop():Void {

        textInputActive = false;

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

    public function setTextEditingConfiguration(inputMode:String, enterKeyHint:Null<String>, autocapitalize:String, autocorrect:Bool, spellcheck:Bool):Void {

        // No virtual keyboard settings with Unity's text editing yet

    }

}
