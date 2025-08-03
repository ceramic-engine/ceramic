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
     * Binds to Unity's onTextInput event for character input.
     */
    #end
    function bindTextInput():Void {

        if (Keyboard.current != null) {
            untyped __cs__('UnityEngine.InputSystem.Keyboard.current.onTextInput += handleTextInput');
        }

    }

    #if !no_backend_docs
    /**
     * Handles raw text input from Unity.
     * Defers processing to next frame to avoid timing issues.
     * @param csChar Unicode character from Unity
     */
    #end
    @:keep function handleTextInput(csChar:Char16):Void {

        ceramic.App.app.onceImmediate(function() {
            _handleTextInput(csChar);
        });

    }

    #if !no_backend_docs
    /**
     * Processes text input and converts to appropriate Ceramic events.
     * Handles special keys and filters non-printable characters.
     * @param csChar Unicode character to process
     */
    #end
    @:keep function _handleTextInput(csChar:Char16):Void {

        if (textInputActive) {
            var char:String = Std.string(csChar);
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

}
