package backend;

import ceramic.ScanCode;

#if clay_sdl
import clay.sdl.SDL;
#end

/**
 * Clay backend implementation for system text input handling.
 * 
 * This class manages the platform-specific text input mechanisms,
 * including:
 * - IME (Input Method Editor) support for complex scripts
 * - Virtual keyboard positioning on mobile platforms
 * - Hardware keyboard input processing
 * - Modifier key state tracking (Shift, Ctrl, Meta)
 * 
 * The implementation uses SDL's text input API on native platforms,
 * which provides proper IME support and handles international text
 * input correctly.
 * 
 * @see spec.TextInput The interface this class implements
 * @see ceramic.TextInput For the high-level text input API
 */
class TextInput implements spec.TextInput {

    /** Whether text input mode is currently active */
    var inputActive:Bool = false;

    /** X position of the text input area (for IME positioning) */
    var inputRectX = 0;
    /** Y position of the text input area (for IME positioning) */
    var inputRectY = 0;
    /** Width of the text input area */
    var inputRectW = 0;
    /** Height of the text input area */
    var inputRectH = 0;

    public function new() {}

    /**
     * Starts text input mode.
     * 
     * This activates the system's text input mechanisms including:
     * - Virtual keyboard on mobile devices
     * - IME composition window positioning
     * - Text input event processing
     * 
     * The rectangle parameters help position IME windows and virtual
     * keyboards near the text being edited.
     * 
     * @param initialText Initial text content (currently unused)
     * @param x X position of the text input area
     * @param y Y position of the text input area
     * @param w Width of the text input area (minimum 1 pixel)
     * @param h Height of the text input area (minimum 1 pixel)
     */
    public function start(initialText:String, x:Float, y:Float, w:Float, h:Float):Void {

        #if ceramic_debug_text_input
        trace('TEXT INPUT START (was active: $inputActive) ${ceramic.App.app.frame}');
        #end

        if (inputActive) return;

        #if (clay_sdl && (windows || mac || linux))
        // Convert from logical native coordinates to SDL window coordinates
        // (pixels on windows/x11, logical points on mac/wayland)
        final toWindowCoords = clay.Clay.app.screenDensity / clay.Clay.app.runtime.windowPixelDensity();
        x *= toWindowCoords;
        y *= toWindowCoords;
        w *= toWindowCoords;
        h *= toWindowCoords;
        #end

        inputRectX = Std.int(x);
        inputRectY = Std.int(y);

        // On Android (again), width & height must be above zero
        inputRectW = Std.int(Math.max(1, w));
        inputRectH = Std.int(Math.max(1, h));

#if clay_sdl
        // Get the window from SDLRuntime
        final window = clay.Clay.app.runtime.window;

        untyped __cpp__(
            'const SDL_Rect sdlRect_ = { {0}, {1}, {2}, {3} }',
            inputRectX, inputRectY, inputRectW, inputRectH
        );

        untyped __cpp__(
            'SDL_SetTextInputArea({0}, &sdlRect_, 0)',
            window
        );
        SDL.startTextInput(window);
#end
        inputActive = true;

    }

    /**
     * Stops text input mode.
     * 
     * This deactivates text input, hiding virtual keyboards and
     * closing any IME composition windows. The input area is reset
     * to prevent any lingering visual artifacts.
     */
    public function stop():Void {

        #if ceramic_debug_text_input
        trace('TEXT INPUT STOP (was active: $inputActive) ${ceramic.App.app.frame}');
        #end

        if (!inputActive) return;

        inputRectX = 0;
        inputRectY = 0;
        inputRectW = 0;
        inputRectH = 0;

#if clay_sdl
        // Get the window from SDLRuntime
        final window = clay.Clay.app.runtime.window;

        if (!textEditing) {
            // Keep system text input running if text editing still needs it
            SDL.stopTextInput(window);
        }

        untyped __cpp__(
            'const SDL_Rect sdlRect_ = { 0, 0, 0, 0 }'
        );

        untyped __cpp__(
            'SDL_SetTextInputArea({0}, &sdlRect_, 0)',
            window
        );
#end

        inputActive = false;

    }

/// Text editing (independent from start/stop)

    /** Whether text editing is active (see `ceramic.Input.startTextEditing()`) */
    var textEditing:Bool = false;

    /**
     * Enables system text input and IME composition events, independently of `start()` / `stop()`.
     * Text and composition are emitted as `textCommit` and `textComposition` on `backend.input`.
     *
     * @param x X position of the edited text area, in native screen coordinates
     * @param y Y position of the edited text area, in native screen coordinates
     * @param w Width of the edited text area
     * @param h Height of the edited text area
     */
    public function startTextEditing(x:Float, y:Float, w:Float, h:Float):Void {

        final wasEditing = textEditing;
        textEditing = true;

#if clay_sdl
        if (!wasEditing) {
            // Let the app draw the composition itself (inline marked text),
            // where the platform supports it (windows). Mac always does.
            SDL.setHint('SDL_IME_IMPLEMENTED_UI', 'composition');
        }
        setTextEditingArea(x, y, w, h, 0);
        if (!wasEditing && !inputActive) {
            SDL.startTextInput(clay.Clay.app.runtime.window);
        }
#elseif web
        if (!wasEditing) {
            startWebTextEditing();
        }
        setTextEditingArea(x, y, w, h, 0);
#end

    }

    /**
     * Disables text editing started with `startTextEditing()`.
     */
    public function stopTextEditing():Void {

        if (!textEditing) return;
        textEditing = false;

#if clay_sdl
        if (!inputActive) {
            SDL.stopTextInput(clay.Clay.app.runtime.window);
        }
#elseif web
        stopWebTextEditing();
#end

    }

    /**
     * Updates the area where the IME should show its candidate window.
     *
     * @param x X position of the edited text area, in native screen coordinates
     * @param y Y position of the edited text area, in native screen coordinates
     * @param w Width of the edited text area
     * @param h Height of the edited text area
     * @param cursor Cursor position, as an offset from `x`
     */
    public function setTextEditingArea(x:Float, y:Float, w:Float, h:Float, cursor:Float):Void {

        if (!textEditing) return;

#if clay_sdl
        untyped __cpp__(
            'const SDL_Rect sdlRect_ = { {0}, {1}, {2}, {3} }',
            Std.int(x), Std.int(y), Std.int(Math.max(1, w)), Std.int(Math.max(1, h))
        );
        untyped __cpp__(
            'SDL_SetTextInputArea({0}, &sdlRect_, {1})',
            clay.Clay.app.runtime.window, Std.int(cursor)
        );
#elseif web
        webAreaX = x;
        webAreaY = y;
        webAreaW = w;
        webAreaH = h;
        webAreaCursor = cursor;
        updateWebTextAreaPosition();
#end

    }

    /**
     * Called from `ClayEvents.text()` with the text events from clay.
     */
    function handleTextEditingEvent(text:String, start:Int, length:Int, type:clay.Types.TextEventType):Void {

#if clay_sdl
        if (!textEditing) return;
        final input = ceramic.App.app.backend.input;
        if (type == clay.Types.TextEventType.EDIT) {
            @:privateAccess input.emitTextComposition(text != null ? text : '', start, length);
        }
        else if (type == clay.Types.TextEventType.INPUT) {
            if (text != null && text.length > 0) {
                @:privateAccess input.emitTextCommit(text);
            }
        }
#end
        // On web, text editing events come from the hidden textarea instead

    }

#if web

    /** Hidden element receiving keyboard text and IME composition while text editing */
    var webTextArea:js.html.TextAreaElement = null;

    /** Whether the browser is in a composition session */
    var webComposing:Bool = false;

    /** Last composition text sent */
    var webCompositionText:String = '';

    /** Area set with `setTextEditingArea()` (canvas relative CSS pixels) */
    var webAreaX:Float = 0;
    var webAreaY:Float = 0;
    var webAreaW:Float = 0;
    var webAreaH:Float = 0;
    var webAreaCursor:Float = 0;

    function startWebTextEditing():Void {

        if (webTextArea == null) {
            createWebTextArea();
        }
        webComposing = false;
        webCompositionText = '';
        webTextArea.value = '';
        focusWebTextArea();

    }

    function stopWebTextEditing():Void {

        if (webTextArea == null) return;

        webComposing = false;
        webCompositionText = '';
        if (js.Browser.document.activeElement == webTextArea) {
            webTextArea.blur();
            // Give keyboard focus back to the canvas
            final canvas:js.html.Element = cast clay.Clay.app.runtime.window;
            if (canvas != null) canvas.focus();
        }
        webTextArea.value = '';

    }

    /**
     * Same approach as GPUI's web platform (ime_mirror.rs): browsers only run IMEs for
     * a focused editable element, so a hidden textarea gets the focus while text editing.
     * Key events still bubble to the document, where clay listens to them.
     */
    function createWebTextArea():Void {

        final textArea:js.html.TextAreaElement = cast js.Browser.document.createElement('textarea');
        textArea.className = 'ceramic-text-editing';
        textArea.setAttribute('aria-hidden', 'true');
        textArea.tabIndex = -1;
        final style = textArea.style;
        style.position = 'fixed';
        style.left = '0px';
        style.top = '0px';
        style.width = '1px';
        style.height = '1px';
        style.opacity = '0';
        style.padding = '0';
        style.margin = '0';
        style.border = 'none';
        style.outline = 'none';
        style.resize = 'none';
        style.overflow = 'hidden';
        style.pointerEvents = 'none';
        style.zIndex = '-1';
        // Avoids browser zoom on focus with mobile browsers
        style.fontSize = '16px';

        textArea.addEventListener('compositionstart', function(_) {
            webComposing = true;
        });

        textArea.addEventListener('compositionupdate', function(ev:js.html.CompositionEvent) {
            webComposing = true;
            final data:String = ev.data != null ? ev.data : '';
            webCompositionText = data;
            // Cursor at the end until the input event gives the actual selection
            emitWebComposition(data, data.length, 0);
        });

        textArea.addEventListener('compositionend', function(ev:js.html.CompositionEvent) {
            webComposing = false;
            final data:String = ev.data != null ? ev.data : '';
            if (webCompositionText.length > 0) {
                webCompositionText = '';
                emitWebComposition('', 0, 0);
            }
            if (data.length > 0 && textEditing) {
                @:privateAccess ceramic.App.app.backend.input.emitTextCommit(data);
            }
            // Clear after the browser is done with the composition
            js.Browser.window.setTimeout(clearWebTextAreaIfIdle, 0);
        });

        textArea.addEventListener('input', function(ev:js.html.InputEvent) {
            if (webComposing || untyped ev.isComposing) {
                // The textarea only holds the composition: use its selection
                // to get the cursor position inside the composed text
                final value = textArea.value;
                if (value == webCompositionText) {
                    final start = Std.int(Math.min(textArea.selectionStart, value.length));
                    final end = Std.int(Math.min(textArea.selectionEnd, value.length));
                    if (start != value.length || end != start) {
                        emitWebComposition(value, start, end - start);
                    }
                }
                return;
            }
            final inputType:String = untyped ev.inputType;
            final data:String = untyped ev.data;
            if (inputType == 'insertText' && data != null && data.length > 0 && textEditing) {
                @:privateAccess ceramic.App.app.backend.input.emitTextCommit(data);
            }
            // Line breaks, deletions, paste... are left to key events
            clearWebTextAreaIfIdle();
        });

        textArea.addEventListener('blur', function(_) {
            if (!textEditing) return;
            // Keep the focus while text editing, unless another editable element took it
            js.Browser.window.setTimeout(function() {
                if (!textEditing) return;
                final active = js.Browser.document.activeElement;
                if (active != null && active != webTextArea && untyped (active.isContentEditable || active.matches('input, textarea, select'))) {
                    return;
                }
                focusWebTextArea();
            }, 0);
        });

        js.Browser.document.body.appendChild(textArea);
        webTextArea = textArea;

    }

    /**
     * Called by `ClayEvents.keyDown()` while text editing. Clay prevents the default
     * action of some keys (space by default, see `preventDefaultKeys`), so their
     * character never reaches the textarea: commit it from here instead.
     */
    function handleWebKeyDown(keyChar:String):Void {

        final ev = clay.Clay.app.runtime.currentKeyEvent;
        if (ev == null || keyChar == null || !ev.defaultPrevented || ev.isComposing || webComposing) return;
        @:privateAccess ceramic.App.app.backend.input.emitTextCommit(keyChar);

    }

    function emitWebComposition(text:String, start:Int, length:Int):Void {

        if (!textEditing) return;

        // The textarea selection is in UTF-16 code units: convert it to code points,
        // the unit used by SDL (and expected by `textComposition` listeners)
        final codePointStart = utf16ToCodePoints(text, 0, start);
        final codePointLength = utf16ToCodePoints(text, start, start + length);
        @:privateAccess ceramic.App.app.backend.input.emitTextComposition(text, codePointStart, codePointLength);

    }

    /**
     * Number of code points between two UTF-16 offsets of `text`.
     */
    static function utf16ToCodePoints(text:String, from:Int, to:Int):Int {

        if (to > text.length) to = text.length;
        var count = 0;
        var i = from;
        while (i < to) {
            final c = StringTools.fastCodeAt(text, i);
            // A high surrogate followed by a low surrogate is a single code point
            if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
                final next = StringTools.fastCodeAt(text, i + 1);
                if (next >= 0xDC00 && next <= 0xDFFF) {
                    i++;
                }
            }
            count++;
            i++;
        }
        return count;

    }

    function clearWebTextAreaIfIdle():Void {

        if (webTextArea != null && !webComposing) {
            webTextArea.value = '';
        }

    }

    function focusWebTextArea():Void {

        if (webTextArea == null) return;
        js.Syntax.code('{0}.focus({ preventScroll: true })', webTextArea);

    }

    function updateWebTextAreaPosition():Void {

        if (webTextArea == null) return;

        // Place the hidden textarea at the cursor so that the IME
        // candidate window shows up next to the edited text
        var offsetX:Float = 0;
        var offsetY:Float = 0;
        final canvas:js.html.Element = cast clay.Clay.app.runtime.window;
        if (canvas != null) {
            final rect = canvas.getBoundingClientRect();
            offsetX = rect.left;
            offsetY = rect.top;
        }
        final style = webTextArea.style;
        style.left = Math.round(offsetX + webAreaX + webAreaCursor) + 'px';
        style.top = Math.round(offsetY + webAreaY) + 'px';
        style.height = Math.round(Math.max(1, webAreaH)) + 'px';

    }

#end

/// Internal

    /**
     * Handles text input events from the system.
     * 
     * Processes Unicode text input, including composed characters
     * from IME systems. Filters out spaces (handled separately)
     * and forwards the text to the high-level text input system.
     * 
     * @param text The input text (may be multiple characters for IME)
     */
    function handleTextInput(text:String) {

        #if ceramic_debug_text_input
        trace('text input: $text ($inputActive) ${ceramic.App.app.frame}');
        #end

        if (text == ' ')
            return;

#if clay_sdl
        // Get the window from SDLRuntime
        final window = clay.Clay.app.runtime.window;

        untyped __cpp__(
            'const SDL_Rect sdlRect_ = { {0}, {1}, {2}, {3} }',
            inputRectX, inputRectY, inputRectW, inputRectH
        );

        untyped __cpp__(
            'SDL_SetTextInputArea({0}, &sdlRect_, 0)',
            window
        );
#end

        ceramic.App.app.textInput.appendText(text);

    }

    /**
     * Handles key press events for text editing.
     * 
     * Processes special keys like:
     * - Navigation (arrows, home, end)
     * - Editing (backspace, delete, enter)
     * - Modifiers (shift, ctrl, meta/cmd)
     * 
     * Regular character input is handled by handleTextInput instead.
     * 
     * @param keyCode Virtual key code
     * @param scanCode Physical key scan code
     */
    function handleKeyDown(keyCode:Int, scanCode:Int) {

        // Keyboard input could have been handled at ceramic cross-platform api level,
        // but it looks more like implementation details that could vary
        // depending on the backend so let's keep it in backend code

        if (inputActive) {
            if (scanCode == ScanCode.BACKSPACE) {
                // Backspace
                ceramic.App.app.textInput.backspace();
            }
            else if (scanCode == ScanCode.SPACE) {
                // Space
                ceramic.App.app.textInput.space();
            }
            else if (scanCode == ScanCode.ENTER) {
                // Enter
                ceramic.App.app.textInput.enter();
            } 
            else if (scanCode == ScanCode.KP_ENTER) {
                // Numpad Enter
                ceramic.App.app.textInput.kpEnter();
            } 
            else if (scanCode == ScanCode.ESCAPE) {
                // Escape
                ceramic.App.app.textInput.escape();
            }
            else if (scanCode == ScanCode.LEFT) {
                // Left
                ceramic.App.app.textInput.moveLeft();
            }
            else if (scanCode == ScanCode.RIGHT) {
                // Right
                ceramic.App.app.textInput.moveRight();
            }
            else if (scanCode == ScanCode.UP) {
                // Up
                ceramic.App.app.textInput.moveUp();
            }
            else if (scanCode == ScanCode.DOWN) {
                // Down
                ceramic.App.app.textInput.moveDown();
            }
        }

        if (scanCode == ScanCode.LSHIFT) {
            // Left Shift
            ceramic.App.app.textInput.lshiftDown();
        }
        else if (scanCode == ScanCode.RSHIFT) {
            // Right Shift
            ceramic.App.app.textInput.rshiftDown();
        }
        else if (scanCode == ScanCode.LCTRL) {
            // Left CTRL
            ceramic.App.app.textInput.lctrlDown();
        }
        else if (scanCode == ScanCode.RCTRL) {
            // Right CTRL
            ceramic.App.app.textInput.rctrlDown();
        }
        else if (scanCode == ScanCode.LMETA) {
            // Left META
            ceramic.App.app.textInput.lmetaDown();
        }
        else if (scanCode == ScanCode.RMETA) {
            // Right META
            ceramic.App.app.textInput.rmetaDown();
        }

    }

    /**
     * Handles key release events.
     * 
     * Only tracks modifier key releases (Shift, Ctrl, Meta) as these
     * affect text input behavior and selection. Regular keys are
     * processed on key down only.
     * 
     * @param keyCode Virtual key code
     * @param scanCode Physical key scan code
     */
    function handleKeyUp(keyCode:Int, scanCode:Int) {

        if (scanCode == ScanCode.LSHIFT) {
            // Left Shift
            ceramic.App.app.textInput.lshiftUp();
        }
        else if (scanCode == ScanCode.RSHIFT) {
            // Right Shift
            ceramic.App.app.textInput.rshiftUp();
        }
        else if (scanCode == ScanCode.LCTRL) {
            // Left CTRL
            ceramic.App.app.textInput.lctrlUp();
        }
        else if (scanCode == ScanCode.RCTRL) {
            // Right CTRL
            ceramic.App.app.textInput.rctrlUp();
        }
        else if (scanCode == ScanCode.LMETA) {
            // Left META
            ceramic.App.app.textInput.lmetaUp();
        }
        else if (scanCode == ScanCode.RMETA) {
            // Right META
            ceramic.App.app.textInput.rmetaUp();
        }

    }

}