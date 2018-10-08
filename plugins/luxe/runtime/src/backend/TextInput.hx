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
            if (inputActive) handleKeyInput(ev.keycode, ev.scancode);
        });

    } //new

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

    } //start

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

    } //stop

/// Internal

    function handleTextInput(text:String) {

#if cpp
        sdl.SDL.setTextInputRect(
            inputRectX,
            inputRectY,
            inputRectW,
            inputRectH
        );
#end

        ceramic.App.app.textInput.appendText(text);

    } //handleTextInput

    function handleKeyInput(keyCode:Int, scanCode:Int) {

        if (scanCode == 42) {
            // Backspace
            ceramic.App.app.textInput.backspace();
        }
        else if (scanCode == 40) {
            // Enter
            ceramic.App.app.textInput.enter();
        }
        else if (scanCode == 41) {
            // Escape
            ceramic.App.app.textInput.escape();
        }

    } //handleKeyInput

} //TextInput
