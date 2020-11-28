package backend;

import cs.types.Char16;
import unityengine.inputsystem.Keyboard;

class TextInput implements spec.TextInput {

    public var textInputActive(default, null):Bool = false;

    public function new() {

        bindTextInput();

    }

    function bindTextInput():Void {

        if (Keyboard.current != null) {
            untyped __cs__('UnityEngine.InputSystem.Keyboard.current.onTextInput += handleTextInput');
        }
        
    }

    @:keep function handleTextInput(csChar:Char16):Void {

        if (textInputActive) {
            var char:String = Std.string(csChar);

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
            else if (char.length > 0) {
                if (char == '\r' || char == '\n' || char == ' ') {
                    // Ignore: line break, spaces
                }
                else {
                    ceramic.App.app.textInput.appendText(char);
                }
            }
        }

    }

    public function start(initialText:String, x:Float, y:Float, w:Float, h:Float):Void {
        
        textInputActive = true;

        // TODO show keyboard on mobile devices

    }

    public function stop():Void {

        textInputActive = false;

    }

}
