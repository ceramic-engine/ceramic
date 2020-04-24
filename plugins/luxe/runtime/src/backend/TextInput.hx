package backend;

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
        inputRectW = Std.int(w);
        inputRectH = Std.int(h);

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

        if (scanCode == 42) {
            // Backspace
            ceramic.App.app.textInput.backspace();
        }
        else if (scanCode == 44) {
            // Space
            ceramic.App.app.textInput.space();
        }
        else if (scanCode == 40) {
            // Enter
            ceramic.App.app.textInput.enter();
        }
        else if (scanCode == 41) {
            // Escape
            ceramic.App.app.textInput.escape();
        }
        else if (scanCode == 80) {
            // Left
            ceramic.App.app.textInput.moveLeft();
        }
        else if (scanCode == 79) {
            // Right
            ceramic.App.app.textInput.moveRight();
        }
        else if (scanCode == 82) {
            // Up
            ceramic.App.app.textInput.moveUp();
        }
        else if (scanCode == 81) {
            // Down
            ceramic.App.app.textInput.moveDown();
        }
        else if (scanCode == 225) {
            // Shift
            ceramic.App.app.textInput.shiftDown();
        }

    }

    function handleKeyUp(keyCode:Int, scanCode:Int) {

        if (scanCode == 225) {
            // Shift
            ceramic.App.app.textInput.shiftUp();
        }

    }

}
