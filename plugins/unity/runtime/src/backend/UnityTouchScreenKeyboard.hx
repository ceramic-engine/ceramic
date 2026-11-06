package backend;

import ceramic.VirtualKeyboardType;

/**
 * `VirtualKeyboard` on Unity's `TouchScreenKeyboard` (iOS and Android, where
 * `TouchScreenKeyboard.isSupported` is true). The input field the platform
 * shows above the keyboard is hidden (`TouchScreenKeyboard.hideInput`): the
 * app draws the edited text itself.
 */
class UnityTouchScreenKeyboard implements VirtualKeyboard {

    /** Whether the platform has a touch screen keyboard. */
    public static function isSupported():Bool {

        final supported:Bool = untyped __cs__('UnityEngine.TouchScreenKeyboard.isSupported');
        return supported;

    }

    /** The open `UnityEngine.TouchScreenKeyboard`, or null. */
    var keyboard:Dynamic = null;

    public function new() {}

    public function open(text:String, type:VirtualKeyboardType, autocorrect:Bool, multiline:Bool):Void {

        close();

        final unityType:Int = switch type {
            case NUMBER_PAD: untyped __cs__('(int)UnityEngine.TouchScreenKeyboardType.NumberPad');
            case DECIMAL_PAD: untyped __cs__('(int)UnityEngine.TouchScreenKeyboardType.DecimalPad');
            case PHONE_PAD: untyped __cs__('(int)UnityEngine.TouchScreenKeyboardType.PhonePad');
            case EMAIL: untyped __cs__('(int)UnityEngine.TouchScreenKeyboardType.EmailAddress');
            case URL: untyped __cs__('(int)UnityEngine.TouchScreenKeyboardType.URL');
            case SEARCH: untyped __cs__('(int)UnityEngine.TouchScreenKeyboardType.Search');
            case _: untyped __cs__('(int)UnityEngine.TouchScreenKeyboardType.Default');
        }

        untyped __cs__('UnityEngine.TouchScreenKeyboard.hideInput = true');
        keyboard = untyped __cs__('UnityEngine.TouchScreenKeyboard.Open({0}, (UnityEngine.TouchScreenKeyboardType){1}, {2}, {3}, false, false, "", 0)', text, unityType, autocorrect, multiline);
        setSelection(text.length, 0);

    }

    public function close():Void {

        if (keyboard == null) return;
        untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).active = false', keyboard);
        keyboard = null;

    }

    public function getText():Null<String> {

        if (keyboard == null) return null;
        return untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).text', keyboard);

    }

    public function setText(text:String):Void {

        if (keyboard == null) return;
        untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).text = {1}', keyboard, text);

    }

    public function getSelectionStart():Int {

        if (keyboard == null) return -1;
        if (!canGetSelection()) return -1;
        return untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).selection.start', keyboard);

    }

    public function getSelectionLength():Int {

        if (keyboard == null) return 0;
        if (!canGetSelection()) return 0;
        return untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).selection.length', keyboard);

    }

    public function setSelection(start:Int, length:Int):Void {

        if (keyboard == null) return;
        final canSet:Bool = untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).canSetSelection', keyboard);
        if (!canSet) return;
        untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).selection = new UnityEngine.RangeInt({1}, {2})', keyboard, start, length);

    }

    function canGetSelection():Bool {

        return untyped __cs__('((UnityEngine.TouchScreenKeyboard){0}).canGetSelection', keyboard);

    }

    public function getStatus():VirtualKeyboardStatus {

        if (keyboard == null) return CLOSED;
        final status:Int = untyped __cs__('(int)((UnityEngine.TouchScreenKeyboard){0}).status', keyboard);
        return status;

    }

}
