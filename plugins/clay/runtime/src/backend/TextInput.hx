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

        SDL.stopTextInput(window);

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