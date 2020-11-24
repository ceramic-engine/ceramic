package unityengine.inputsystem;

import unityengine.inputsystem.controls.KeyControl;
import unityengine.inputsystem.controls.AnyKeyControl;

import cs.types.Char16;

@:native('UnityEngine.InputSystem.Keyboard')
extern class Keyboard extends InputDevice {

    static var current(default, null):Keyboard;

    var KeyCount(default, null):Int;

    var allKeys(default, null):unityengine.inputsystem.utilities.ReadOnlyArray<KeyControl>;

    var anyKey(default, null):AnyKeyControl;

    var keyboardLayout(default, null):String;

    var onTextInput:Dynamic;

    var leftArrowKey(default, null):KeyControl;

    var rightArrowKey(default, null):KeyControl;

    var upArrowKey(default, null):KeyControl;

    var downArrowKey(default, null):KeyControl;

    var enterKey(default, null):KeyControl;

    var escapeKey(default, null):KeyControl;

    var spaceKey(default, null):KeyControl;

    var f1Key(default, null):KeyControl;

    var f2Key(default, null):KeyControl;

    var f3Key(default, null):KeyControl;

    var f4Key(default, null):KeyControl;

    var f5Key(default, null):KeyControl;

    var f6Key(default, null):KeyControl;

    var f7Key(default, null):KeyControl;

    var f8Key(default, null):KeyControl;

    var f9Key(default, null):KeyControl;

    var f10Key(default, null):KeyControl;

    var f11Key(default, null):KeyControl;

    var f12Key(default, null):KeyControl;

}
