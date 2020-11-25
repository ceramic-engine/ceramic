package backend;

import ceramic.ScanCode;
#if cpp
import sdl.SDL;
#end

class TextInput implements spec.TextInput {

    var inputActive:Bool = false;

    var inputRectX = 0;
    var inputRectY = 0;
    var inputRectW = 0;
    var inputRectH = 0;

    public function new() {

        // Use luxe API to bind text input
        //
        Luxe.on(luxe.Ev.textinput, function(ev:luxe.Input.TextEvent) {
            if (inputActive) handleTextInput(ev.text);
        });

        Luxe.on(luxe.Ev.keydown, function(ev:luxe.Input.KeyEvent) {
            if (inputActive) handleKeyDown(ev.keycode, ev.scancode);
        });

        Luxe.on(luxe.Ev.keyup, function(ev:luxe.Input.KeyEvent) {
            if (inputActive) handleKeyUp(ev.keycode, ev.scancode);
        });

    }

    public function start(initialText:String, x:Float, y:Float, w:Float, h:Float):Void {

        if (inputActive) return;

        inputRectX = Std.int(x);
        inputRectY = Std.int(y);

        // On Android (again), width & height must be above zero
        inputRectW = Std.int(Math.max(1, w));
        inputRectH = Std.int(Math.max(1, h));

#if cpp
        SDL.setTextInputRect(
            inputRectX,
            inputRectY,
            inputRectW,
            inputRectH
        );
        SDL.startTextInput();
#end
        inputActive = true;

    }

    public function stop():Void {

        if (!inputActive) return;

        inputRectX = 0;
        inputRectY = 0;
        inputRectW = 0;
        inputRectH = 0;

#if cpp
        SDL.stopTextInput();
        SDL.setTextInputRect(0, 0, 0, 0);
#end

        inputActive = false;

    }

/// Internal

    function handleTextInput(text:String) {

        if (text == ' ')
            return;

#if cpp
        sdl.SDL.setTextInputRect(
            inputRectX,
            inputRectY,
            inputRectW,
            inputRectH
        );
#end

        ceramic.App.app.textInput.appendText(text);

    }

    function handleKeyDown(keyCode:Int, scanCode:Int) {

        // Keyboard input could have been handled at ceramic cross-platform api level,
        // but it looks more like implementation details that could vary
        // depending on the backend so let's keep it in backend code

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
        else if (scanCode == ScanCode.LSHIFT) {
            // Left Shift
            ceramic.App.app.textInput.lshiftDown();
        }
        else if (scanCode == ScanCode.RSHIFT) {
            // Right Shift
            ceramic.App.app.textInput.rshiftDown();
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

    }

}
