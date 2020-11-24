package unityengine.inputsystem;

import cs.NativeArray;
import cs.types.Char16;

@:native('UnityEngine.InputSystem.Keyboard')
extern class Keyboard extends InputDevice {

    static var current(default, null):Keyboard;

    var KeyCount(default, null):Int;

    var allKeys(default, null):NativeArray<KeyControl>;

    var anyKey(default, null):AnyKeyControl;

    var keyboardLayout(default, null):String;

    var onTextInput:cs.system.Action_1<Char16>;

}
