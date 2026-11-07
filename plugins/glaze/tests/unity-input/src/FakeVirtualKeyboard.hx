package;

#if unity

import backend.VirtualKeyboardStatus;
import ceramic.VirtualKeyboardType;

/**
 * A simulated `TouchScreenKeyboard` for the self test in batch mode (Unity
 * has no touch screen keyboard on desktop): its hidden field is edited the
 * way a platform keyboard edits it (text at the caret, backspace, caret
 * moves, autocorrection), and its status set like the platform does.
 */
class FakeVirtualKeyboard implements backend.VirtualKeyboard {

    /** One entry per `open()`: type, return key and autocorrection. */
    public final opens:Array<String> = [];

    public var closes(default, null):Int = 0;

    public var text:Null<String> = null;

    public var selectionStart:Int = -1;

    public var selectionLength:Int = 0;

    public var status:VirtualKeyboardStatus = CLOSED;

    public function new() {}

    public function open(text:String, type:VirtualKeyboardType, autocorrect:Bool, multiline:Bool):Void {

        opens.push('${type.toString()} ${multiline ? 'multiline' : 'single'}${autocorrect ? ' autocorrect' : ''}');
        this.text = text;
        selectionStart = text.length;
        selectionLength = 0;
        status = VISIBLE;

    }

    public function close():Void {

        closes++;
        text = null;
        status = CLOSED;

    }

    public function getText():Null<String> {
        return text;
    }

    public function setText(text:String):Void {
        this.text = text;
    }

    public function getSelectionStart():Int {
        return text != null ? selectionStart : -1;
    }

    public function getSelectionLength():Int {
        return selectionLength;
    }

    public function setSelection(start:Int, length:Int):Void {
        selectionStart = start;
        selectionLength = length;
    }

    public function getStatus():VirtualKeyboardStatus {
        return status;
    }

/// What the user does

    public function type(value:String):Void {

        text = text.substring(0, selectionStart) + value + text.substring(selectionStart + selectionLength);
        selectionStart += value.length;
        selectionLength = 0;

    }

    public function backspace():Void {

        if (selectionStart == 0) return;
        var size = 1;
        final c = StringTools.fastCodeAt(text, selectionStart - 1);
        if (c >= 0xDC00 && c <= 0xDFFF && selectionStart >= 2) size = 2;
        text = text.substring(0, selectionStart - size) + text.substring(selectionStart);
        selectionStart -= size;

    }

    public function moveCaret(delta:Int):Void {

        selectionStart += delta;

    }

    /** Replaces the `length` code units before the caret (autocorrection). */
    public function replaceBefore(length:Int, value:String):Void {

        text = text.substring(0, selectionStart - length) + value + text.substring(selectionStart);
        selectionStart += value.length - length;

    }

}

#end
