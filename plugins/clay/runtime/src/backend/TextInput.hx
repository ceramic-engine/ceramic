package backend;

import ceramic.ScanCode;

#if clay_sdl
import clay.sdl.SDL;
#end

class TextInput implements spec.TextInput {

    var inputActive:Bool = false;

    var inputRectX = 0;
    var inputRectY = 0;
    var inputRectW = 0;
    var inputRectH = 0;

    public function new() {}

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