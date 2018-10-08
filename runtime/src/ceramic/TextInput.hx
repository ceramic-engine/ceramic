package ceramic;

import ceramic.Shortcuts.*;

using unifill.Unifill;

@:allow(ceramic.App)
class TextInput implements Events {

/// Events

    @event function _update(text:String);

    @event function _enter();

    @event function _escape();

    @event function _stop();

/// Properties

    var inputActive:Bool = false;

    public var text:String = '';

/// Lifecycle

    private function new() {

        //

    } //new

/// Public API

    public function start(x:Float, y:Float, w:Float, h:Float):Void {

        if (inputActive) stop();
        inputActive = true;

        app.backend.textInput.start(text, x, y, w, h);
        emitUpdate(text);

    } //start

    public function stop():Void {

        if (!inputActive) return;
        inputActive = false;

        app.backend.textInput.stop();
        emitStop();

    } //stop

    public function appendText(text:String):Void {

        this.text += text;
        emitUpdate(this.text);

    } //appendText

    public function backspace():Void {

        if (text.length > 0) {
            text = text.uSubstring(0, text.uLength() - 1);
            emitUpdate(text);
        }

    } //backspace

    public function enter():Void {

        emitEnter();
        stop(); // TODO multiline input?

    } //enter

    public function escape():Void {

        emitEscape();
        stop();

    } //escape

} //TextInput
