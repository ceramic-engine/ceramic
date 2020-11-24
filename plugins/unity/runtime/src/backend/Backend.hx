package backend;

import ceramic.KeyCode;
import ceramic.ScanCode;
import unityengine.inputsystem.Keyboard;
import unityengine.inputsystem.controls.KeyControl;
import ceramic.Shortcuts.*;

@:allow(Main)
@:allow(backend.Textures)
class Backend implements tracker.Events implements spec.Backend {

/// Public API

    public var io(default,null) = new backend.IO();

    public var info(default,null) = new backend.Info();

    public var audio(default,null) = new backend.Audio();

    public var draw(default,null) = new backend.Draw();

    public var texts(default,null) = new backend.Texts();

    public var textures(default,null) = new backend.Textures();

    public var shaders(default,null) = new backend.Shaders();

    public var screen(default,null) = new backend.Screen();

    public var http(default,null) = new backend.Http();

    public var textInput(default,null) = new backend.TextInput();

    public var clipboard(default,null) = new backend.Clipboard();

    public function new() {}

    public function init(app:ceramic.App) {

        initKeyCodesMapping();

    }

/// Events

    @event function ready();

    @event function update(delta:Float);

    @event function keyDown(key:ceramic.Key);
    @event function keyUp(key:ceramic.Key);

    @event function controllerAxis(controllerId:Int, axisId:Int, value:Float);
    @event function controllerDown(controllerId:Int, buttonId:Int);
    @event function controllerUp(controllerId:Int, buttonId:Int);
    @event function controllerEnable(controllerId:Int, name:String);
    @event function controllerDisable(controllerId:Int);

/// Internal update logic

    inline function willEmitUpdate(delta:Float) {

        screen.update();

        updateKeyboardInput();

    }

    inline function didEmitUpdate(delta:Float) {

        //

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

        var keyboard = Keyboard.current;
        if (keyboard != null) {
            testKey(keyboard, 1, ScanCode.SPACE, KeyCode.SPACE);
            
            testKey(keyboard, 2, ScanCode.ENTER, KeyCode.ENTER);
            testKey(keyboard, 3, ScanCode.TAB, KeyCode.TAB);
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

            testKey(keyboard, 51, ScanCode.LSHIFT);
            testKey(keyboard, 52, ScanCode.RSHIFT);
            testKey(keyboard, 53, ScanCode.LALT);
            testKey(keyboard, 54, ScanCode.RALT);
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

}
