package backend;

import ceramic.IntIntMap;
import ceramic.IntMap;
import ceramic.Key;
import ceramic.KeyCode;
import ceramic.ScanCode;
import ceramic.Shortcuts.*;
import unityengine.inputsystem.Gamepad;
import unityengine.inputsystem.Keyboard;
import unityengine.inputsystem.controls.KeyControl;

using ceramic.Extensions;

@:allow(Main)
class Input implements tracker.Events implements spec.Input {

    /**
     * Internal value to store gamepad state
     */
    inline static final GAMEPAD_STORAGE_SIZE:Int = 20;

    @event function keyDown(key:ceramic.Key);
    @event function keyUp(key:ceramic.Key);

    @event function gamepadAxis(gamepadId:Int, axisId:Int, value:Float);
    @event function gamepadDown(gamepadId:Int, buttonId:Int);
    @event function gamepadUp(gamepadId:Int, buttonId:Int);
    @event function gamepadEnable(gamepadId:Int, name:String);
    @event function gamepadDisable(gamepadId:Int);

    public function new() {

        initKeyCodesMapping();

    }

    @:allow(backend.Backend)
    inline function update():Void {

        updateKeyboardInput();
        updateGamepadInput();

    }

/// Keyboard input

    var keyCodeByName:Map<String,Int> = null;

    function initKeyCodesMapping() {

        keyCodeByName = new Map();

        keyCodeByName.set("a", KeyCode.KEY_A);
        keyCodeByName.set("b", KeyCode.KEY_B);
        keyCodeByName.set("c", KeyCode.KEY_C);
        keyCodeByName.set("d", KeyCode.KEY_D);
        keyCodeByName.set("e", KeyCode.KEY_E);
        keyCodeByName.set("f", KeyCode.KEY_F);
        keyCodeByName.set("g", KeyCode.KEY_G);
        keyCodeByName.set("h", KeyCode.KEY_H);
        keyCodeByName.set("i", KeyCode.KEY_I);
        keyCodeByName.set("j", KeyCode.KEY_J);
        keyCodeByName.set("k", KeyCode.KEY_K);
        keyCodeByName.set("l", KeyCode.KEY_L);
        keyCodeByName.set("m", KeyCode.KEY_M);
        keyCodeByName.set("n", KeyCode.KEY_N);
        keyCodeByName.set("o", KeyCode.KEY_O);
        keyCodeByName.set("p", KeyCode.KEY_P);
        keyCodeByName.set("q", KeyCode.KEY_Q);
        keyCodeByName.set("r", KeyCode.KEY_R);
        keyCodeByName.set("s", KeyCode.KEY_S);
        keyCodeByName.set("t", KeyCode.KEY_T);
        keyCodeByName.set("u", KeyCode.KEY_U);
        keyCodeByName.set("v", KeyCode.KEY_V);
        keyCodeByName.set("w", KeyCode.KEY_W);
        keyCodeByName.set("x", KeyCode.KEY_X);
        keyCodeByName.set("y", KeyCode.KEY_Y);
        keyCodeByName.set("z", KeyCode.KEY_Z);
        keyCodeByName.set("1", KeyCode.KEY_1);
        keyCodeByName.set("2", KeyCode.KEY_2);
        keyCodeByName.set("3", KeyCode.KEY_3);
        keyCodeByName.set("4", KeyCode.KEY_4);
        keyCodeByName.set("5", KeyCode.KEY_5);
        keyCodeByName.set("6", KeyCode.KEY_6);
        keyCodeByName.set("7", KeyCode.KEY_7);
        keyCodeByName.set("8", KeyCode.KEY_8);
        keyCodeByName.set("9", KeyCode.KEY_9);
        keyCodeByName.set("0", KeyCode.KEY_0);

    }

    function updateKeyboardInput() {

        // Codes from: https://docs.unity3d.com/Packages/com.unity.inputsystem@1.0/api/UnityEngine.InputSystem.Key.html

        var keyboard = Keyboard.current;
        if (keyboard != null && (keyboard.anyKey.wasPressedThisFrame || keyboard.anyKey.wasReleasedThisFrame || keyboard.anyKey.isPressed)) {

            testKey(keyboard, 1, ScanCode.SPACE, KeyCode.SPACE);

            testKey(keyboard, 2, ScanCode.ENTER, KeyCode.ENTER);
            testKey(keyboard, 3, ScanCode.TAB, KeyCode.TAB);

            // We don't provide keyCode when it depends on current keyboard layout.
            // It will be resolved when event is triggered using KeyControl.displayName

            testKey(keyboard, 4, ScanCode.GRAVE);
            testKey(keyboard, 5, ScanCode.APOSTROPHE);
            testKey(keyboard, 6, ScanCode.SEMICOLON);
            testKey(keyboard, 7, ScanCode.COMMA);
            testKey(keyboard, 8, ScanCode.PERIOD);
            testKey(keyboard, 9, ScanCode.SLASH);
            testKey(keyboard, 10, ScanCode.BACKSLASH);
            testKey(keyboard, 11, ScanCode.LEFTBRACKET);
            testKey(keyboard, 12, ScanCode.RIGHTBRACKET);
            testKey(keyboard, 13, ScanCode.MINUS);
            testKey(keyboard, 14, ScanCode.EQUALS);

            // Letters and digits
            var scanCode = ScanCode.KEY_A;
            for (i in 15...51) {
                testKey(keyboard, i, scanCode);
                scanCode++;
            }

            testKey(keyboard, 51, ScanCode.LSHIFT, KeyCode.LSHIFT);
            testKey(keyboard, 52, ScanCode.RSHIFT, KeyCode.RSHIFT);
            testKey(keyboard, 53, ScanCode.LALT, KeyCode.LALT);
            testKey(keyboard, 54, ScanCode.RALT, KeyCode.RALT);
            testKey(keyboard, 55, ScanCode.LCTRL, KeyCode.LCTRL);
            testKey(keyboard, 56, ScanCode.RCTRL, KeyCode.RCTRL);
            testKey(keyboard, 57, ScanCode.LMETA, KeyCode.LMETA);
            testKey(keyboard, 58, ScanCode.RMETA, KeyCode.RMETA);
            testKey(keyboard, 59, ScanCode.MENU, KeyCode.MENU);
            testKey(keyboard, 60, ScanCode.ESCAPE, KeyCode.ESCAPE);
            testKey(keyboard, 61, ScanCode.LEFT, KeyCode.LEFT);
            testKey(keyboard, 62, ScanCode.RIGHT, KeyCode.RIGHT);
            testKey(keyboard, 63, ScanCode.UP, KeyCode.UP);
            testKey(keyboard, 64, ScanCode.DOWN, KeyCode.DOWN);
            testKey(keyboard, 65, ScanCode.BACKSPACE, KeyCode.BACKSPACE);
            testKey(keyboard, 66, ScanCode.PAGEDOWN, KeyCode.PAGEDOWN);
            testKey(keyboard, 67, ScanCode.PAGEUP, KeyCode.PAGEUP);
            testKey(keyboard, 68, ScanCode.HOME, KeyCode.HOME);
            testKey(keyboard, 69, ScanCode.END, KeyCode.END);
            testKey(keyboard, 70, ScanCode.INSERT, KeyCode.INSERT);
            testKey(keyboard, 71, ScanCode.DELETE, KeyCode.DELETE);
            testKey(keyboard, 72, ScanCode.CAPSLOCK, KeyCode.CAPSLOCK);
            testKey(keyboard, 73, ScanCode.NUMLOCKCLEAR, KeyCode.NUMLOCKCLEAR);
            testKey(keyboard, 74, ScanCode.PRINTSCREEN, KeyCode.PRINTSCREEN);
            testKey(keyboard, 75, ScanCode.SCROLLLOCK, KeyCode.SCROLLLOCK);
            testKey(keyboard, 76, ScanCode.PAUSE, KeyCode.PAUSE);
            testKey(keyboard, 77, ScanCode.KP_ENTER, KeyCode.KP_ENTER);
            testKey(keyboard, 78, ScanCode.KP_DIVIDE, KeyCode.KP_DIVIDE);
            testKey(keyboard, 79, ScanCode.KP_MULTIPLY, KeyCode.KP_MULTIPLY);
            testKey(keyboard, 80, ScanCode.KP_PLUS, KeyCode.KP_PLUS);
            testKey(keyboard, 81, ScanCode.KP_MINUS, KeyCode.KP_MINUS);
            testKey(keyboard, 82, ScanCode.KP_PERIOD, KeyCode.KP_PERIOD);
            testKey(keyboard, 83, ScanCode.KP_EQUALS, KeyCode.KP_EQUALS);
            testKey(keyboard, 84, ScanCode.KP_0, KeyCode.KP_0);
            testKey(keyboard, 85, ScanCode.KP_1, KeyCode.KP_1);
            testKey(keyboard, 86, ScanCode.KP_2, KeyCode.KP_2);
            testKey(keyboard, 87, ScanCode.KP_3, KeyCode.KP_3);
            testKey(keyboard, 88, ScanCode.KP_4, KeyCode.KP_4);
            testKey(keyboard, 89, ScanCode.KP_5, KeyCode.KP_5);
            testKey(keyboard, 90, ScanCode.KP_6, KeyCode.KP_6);
            testKey(keyboard, 91, ScanCode.KP_7, KeyCode.KP_7);
            testKey(keyboard, 92, ScanCode.KP_8, KeyCode.KP_8);
            testKey(keyboard, 93, ScanCode.KP_9, KeyCode.KP_9);
            testKey(keyboard, 94, ScanCode.F1, KeyCode.F1);
            testKey(keyboard, 95, ScanCode.F2, KeyCode.F2);
            testKey(keyboard, 96, ScanCode.F3, KeyCode.F3);
            testKey(keyboard, 97, ScanCode.F4, KeyCode.F4);
            testKey(keyboard, 98, ScanCode.F5, KeyCode.F5);
            testKey(keyboard, 99, ScanCode.F6, KeyCode.F6);
            testKey(keyboard, 100, ScanCode.F7, KeyCode.F7);
            testKey(keyboard, 101, ScanCode.F8, KeyCode.F8);
            testKey(keyboard, 102, ScanCode.F9, KeyCode.F9);
            testKey(keyboard, 103, ScanCode.F10, KeyCode.F10);
            testKey(keyboard, 104, ScanCode.F11, KeyCode.F11);
            testKey(keyboard, 105, ScanCode.F12, KeyCode.F12);
        }

    }

    inline function testKey(keyboard:Keyboard, value:Int, scanCode:Int, ?keyCode:Null<Int>):Void {

        var key:KeyControl = untyped __cs__('{0}[{1}]', keyboard.allKeys, value-1);
        if (key.wasPressedThisFrame) {
            if (keyCode == null) {
                if (key.displayName != null && key.displayName.length > 0) {
                    keyCode = keyCodeByName.get(key.displayName.toLowerCase());
                    if (keyCode == null) {
                        keyCode = key.displayName.charCodeAt(0);
                    }
                }
                if (keyCode == null) {
                    keyCode = KeyCode.UNKNOWN;
                }
            }
            emitKeyDown({
                keyCode: keyCode != null ? keyCode : (key.displayName != null ? key.displayName.charCodeAt(0) : KeyCode.UNKNOWN),
                scanCode: scanCode
            });
        }
        if (key.wasReleasedThisFrame) {
            if (keyCode == null) {
                if (key.displayName != null) {
                    keyCode = keyCodeByName.get(key.displayName.toLowerCase());
                    if (keyCode == null) {
                        keyCode = key.displayName.charCodeAt(0);
                    }
                }
                if (keyCode == null) {
                    keyCode = KeyCode.UNKNOWN;
                }
            }
            emitKeyUp({
                keyCode: keyCode != null ? keyCode : KeyCode.UNKNOWN,
                scanCode: scanCode
            });
        }

    }

    function willEmitKeyDown(key:Key) {

        #if ceramic_debug_text_input
        trace('willEmitKeyDown($key)');
        #end

        // Keyboard input could have been handled at ceramic cross-platform api level,
        // but it looks more like implementation details that could vary
        // depending on the backend so let's keep it in backend code

        var scanCode = key.scanCode;

        /*if (scanCode == ScanCode.BACKSPACE) {
            // Backspace
            //ceramic.App.app.textInput.backspace();
        }
        else if (scanCode == ScanCode.SPACE) {
            // Space
            //ceramic.App.app.textInput.space();
        }
        else if (scanCode == ScanCode.ENTER) {
            // Enter
            //ceramic.App.app.textInput.enter();
        }
        else if (scanCode == ScanCode.ESCAPE) {
            // Escape
            //ceramic.App.app.textInput.escape();
        }
        else if (scanCode == ScanCode.LEFT) {
            // Left
            //ceramic.App.app.textInput.moveLeft();
        }
        else if (scanCode == ScanCode.RIGHT) {
            // Right
            //ceramic.App.app.textInput.moveRight();
        }
        else if (scanCode == ScanCode.UP) {
            // Up
            //ceramic.App.app.textInput.moveUp();
        }
        else if (scanCode == ScanCode.DOWN) {
            // Down
            //ceramic.App.app.textInput.moveDown();
        }
        else*/
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

    function willEmitKeyUp(key:Key) {

        var scanCode = key.scanCode;

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

/// Gamepad input

    var gamepads:Array<Gamepad> = [];

    var gamepadPressed:IntIntMap = new IntIntMap(16, 0.5, false);

    var gamepadAxis:IntMap<Single> = new IntMap(16, 0.5, false);

    var unusedGamepads:Array<Gamepad> = [];

    function updateGamepadInput() {

        var numPads = Gamepad.all.Count;

        for (i in 0...gamepads.length) {
            unusedGamepads[i] = gamepads.unsafeGet(i);
        }

        for (i in 0...numPads) {

            var gamepad:Gamepad = untyped __cs__('{0}[{1}]', Gamepad.all, i);
            var index = gamepads.indexOf(gamepad);
            if (index == -1) {
                for (n in 0...gamepads.length) {
                    if (gamepads.unsafeGet(n) == null) {
                        index = n;
                        gamepads.unsafeSet(index, gamepad);
                        break;
                    }
                }
                if (index == -1) {
                    gamepads.push(gamepad);
                    index = gamepads.length - 1;
                }
                emitGamepadEnable(index, gamepad.displayName);
                for (n in 0...GAMEPAD_STORAGE_SIZE) {
                    gamepadPressed.set(index * GAMEPAD_STORAGE_SIZE + n, 0);
                }
            }

            var unusedIndex = unusedGamepads.indexOf(gamepad);
            if (unusedIndex != -1) {
                unusedGamepads.unsafeSet(unusedIndex, null);
            }

            updateGamepadButton(index, 0, gamepad.buttonSouth.isPressed);
            updateGamepadButton(index, 1, gamepad.buttonEast.isPressed);
            updateGamepadButton(index, 2, gamepad.buttonWest.isPressed);
            updateGamepadButton(index, 3, gamepad.buttonNorth.isPressed);

            updateGamepadButton(index, 4, gamepad.leftShoulder.isPressed);
            updateGamepadButton(index, 5, gamepad.rightShoulder.isPressed);
            updateGamepadButton(index, 6, gamepad.leftTrigger.isPressed);
            updateGamepadButton(index, 7, gamepad.rightTrigger.isPressed);

            updateGamepadButton(index, 8, gamepad.selectButton.isPressed);
            updateGamepadButton(index, 9, gamepad.startButton.isPressed);

            updateGamepadButton(index, 10, gamepad.leftStickButton.isPressed);
            updateGamepadButton(index, 11, gamepad.rightStickButton.isPressed);

            updateGamepadButton(index, 12, gamepad.dpad.up.isPressed);
            updateGamepadButton(index, 13, gamepad.dpad.down.isPressed);
            updateGamepadButton(index, 14, gamepad.dpad.left.isPressed);
            updateGamepadButton(index, 15, gamepad.dpad.right.isPressed);

            updateGamepadAxis(index, 0, gamepad.leftStick.x.ReadValue());
            updateGamepadAxis(index, 1, gamepad.leftStick.y.ReadValue() * -1);
            updateGamepadAxis(index, 2, gamepad.rightStick.x.ReadValue());
            updateGamepadAxis(index, 3, gamepad.rightStick.y.ReadValue() * -1);

        }

        for (i in 0...unusedGamepads.length) {
            var gamepad:Gamepad = unusedGamepads.unsafeGet(i);
            if (gamepad != null) {
                var index = gamepads.indexOf(gamepad);
                if (index != -1) {
                    gamepads.unsafeSet(index, null);
                    for (n in 0...GAMEPAD_STORAGE_SIZE) {
                        if (gamepadPressed.get(index * GAMEPAD_STORAGE_SIZE + n) == 1) {
                            gamepadPressed.set(index * GAMEPAD_STORAGE_SIZE + n, 0);
                            emitGamepadUp(index, n);
                        }
                    }
                    emitGamepadDisable(index);
                }
                unusedGamepads.unsafeSet(i, null);
            }
        }

    }

    function updateGamepadButton(index:Int, button:Int, pressed:Bool) {

        var wasPressed = gamepadPressed.get(index * GAMEPAD_STORAGE_SIZE + button) == 1;

        if (pressed) {
            if (!wasPressed) {
                gamepadPressed.set(index * GAMEPAD_STORAGE_SIZE + button, 1);
                emitGamepadDown(index, button);
            }
        }
        else {
            if (wasPressed) {
                gamepadPressed.set(index * GAMEPAD_STORAGE_SIZE + button, 0);
                emitGamepadUp(index, button);
            }
        }

    }

    function updateGamepadAxis(index:Int, axis:Int, value:Single) {

        var prevValue = gamepadAxis.get(index * 5 + axis);
        if (prevValue != value) {
            gamepadAxis.set(index * 5 + axis, value);
            emitGamepadAxis(index, axis, value);
        }

    }

}
