package ceramic;

import ceramic.Shortcuts.*;

using StringTools;
using unifill.Unifill;

@:allow(ceramic.App)
class TextInput implements Events {

/// Events

    @event function _update(text:String);

    @event function _enter();

    @event function _escape();

    @event function _selection(selectionStart:Int, selectionEnd:Int);

    @event function _stop();

/// Properties

    var inputActive:Bool = false;

    var explicitPosInLine:Int = 0;

    var explicitPosLine:Int = 0;

    var shiftPressed:Bool = false;

    var invertedSelection:Bool = false;

    public var allowMovingCursor(default,null):Bool = false;

    public var multiline(default,null):Bool = false;

    public var text(default,null):String = '';

    public var selectionStart(default,null):Int = -1;

    public var selectionEnd(default,null):Int = -1;

    public var delegate(default,null):TextInputDelegate = null;

/// Lifecycle

    private function new() {

        //

    } //new

/// Public API

    public function start(
        text:String,
        x:Float, y:Float, w:Float, h:Float,
        multiline:Bool = false,
        selectionStart:Int = -1, selectionEnd:Int = -1,
        allowMovingCursor:Bool = false,
        delegate:TextInputDelegate = null
    ):Void {

        if (inputActive) stop();
        inputActive = true;

        this.text = text;
        this.multiline = multiline;
        this.allowMovingCursor = allowMovingCursor;
        this.delegate = delegate;

        explicitPosInLine = 0;
        explicitPosLine = 0;
        invertedSelection = false;
        
        if (selectionStart < 0) selectionStart = text.uLength();
        if (selectionEnd < selectionStart) selectionEnd = selectionStart;
        this.selectionStart = selectionStart;
        this.selectionEnd = selectionEnd;

        app.backend.textInput.start(text, x, y, w, h);
        emitUpdate(text);
        emitSelection(selectionStart, selectionEnd);

    } //start

    public function stop():Void {

        if (!inputActive) return;
        inputActive = false;

        selectionStart = -1;
        selectionEnd = -1;
        invertedSelection = false;
        delegate = null;

        app.backend.textInput.stop();
        emitStop();

    } //stop

    public function appendText(text:String):Void {

        // Clear selection and add text in place

        var newText = '';
        if (selectionStart > 0) {
            newText += this.text.uSubstring(0, selectionStart);
        }
        newText += text;
        newText += this.text.uSubstring(selectionEnd);

        selectionStart += text.uLength();
        selectionEnd = selectionStart;
        invertedSelection = false;
        this.text = newText;

        emitUpdate(this.text);
        emitSelection(selectionStart, selectionEnd);
        
        explicitPosInLine = posInCurrentLine(selectionStart);
        explicitPosLine = lineForPos(selectionStart);

    } //appendText

    public function backspace():Void {

        // Clear selection and erase text in place

        var newText = '';
        if (selectionStart > 1) {
            newText += this.text.uSubstring(0, selectionStart - 1);
        }
        newText += this.text.uSubstring(selectionEnd);

        if (selectionStart > 0) selectionStart--;
        selectionEnd = selectionStart;
        this.text = newText;

        emitUpdate(text);
        emitSelection(selectionStart, selectionEnd);
        
        explicitPosInLine = posInCurrentLine(selectionStart);
        explicitPosLine = lineForPos(selectionStart);

    } //backspace

    public function moveLeft():Void {

        if (!allowMovingCursor) return;

        if (shiftPressed) {
            if (invertedSelection) {
                if (selectionStart > 0) {
                    selectionStart--;
                    emitSelection(selectionStart, selectionEnd);
                }

                explicitPosInLine = posInCurrentLine(selectionStart);
                explicitPosLine = lineForPos(selectionStart);
            }
            else if (selectionEnd > selectionStart) {
                selectionEnd--;
                emitSelection(selectionStart, selectionEnd);

                explicitPosInLine = posInCurrentLine(selectionEnd);
                explicitPosLine = lineForPos(selectionEnd);
            }
            else {
                if (selectionStart > 0) {
                    invertedSelection = true;
                    selectionStart--;
                    emitSelection(selectionStart, selectionEnd);
                }

                explicitPosInLine = posInCurrentLine(selectionStart);
                explicitPosLine = lineForPos(selectionStart);
            }
        }
        else {
            invertedSelection = false;

            if (selectionEnd > selectionStart) {
                // Some text is selected, just deselect and
                // put the cursor at the start of previous selection
                selectionEnd = selectionStart;
                emitSelection(selectionStart, selectionEnd);
            }
            else if (selectionStart > 0) {
                // Move the cursor by one character to the left
                selectionStart--;
                selectionEnd = selectionStart;
                emitSelection(selectionStart, selectionEnd);
            }

            explicitPosInLine = posInCurrentLine(selectionStart);
            explicitPosLine = lineForPos(selectionStart);
        }

    } //moveLeft

    public function moveRight():Void {

        if (!allowMovingCursor) return;

        if (shiftPressed) {
            var textLength = text.uLength();

            if (selectionStart == selectionEnd) {
                invertedSelection = false;
                
                if (selectionEnd < textLength) {
                    selectionEnd++;
                    emitSelection(selectionStart, selectionEnd);
                }

                explicitPosInLine = posInCurrentLine(selectionEnd);
                explicitPosLine = lineForPos(selectionEnd);
            }
            else if (invertedSelection) {
                selectionStart++;
                emitSelection(selectionStart, selectionEnd);
                explicitPosInLine = posInCurrentLine(selectionStart);
                explicitPosLine = lineForPos(selectionStart);
            }
            else {
                if (selectionEnd < textLength) {
                    selectionEnd++;
                    emitSelection(selectionStart, selectionEnd);
                }

                explicitPosInLine = posInCurrentLine(selectionEnd);
                explicitPosLine = lineForPos(selectionEnd);
            }

        }
        else {
            invertedSelection = false;

            if (selectionEnd > selectionStart) {
                // Some text is selected, just deselect and
                // put the cursor at the end of previous selection
                selectionStart = selectionEnd;
                emitSelection(selectionStart, selectionEnd);
            }
            else if (selectionStart < text.uLength()) {
                // Move the cursor by one character to the right
                selectionStart++;
                selectionEnd = selectionStart;
                emitSelection(selectionStart, selectionEnd);
            }

            explicitPosInLine = posInCurrentLine(selectionStart);
            explicitPosLine = lineForPos(selectionStart);
        }

    } //moveRight

    public function moveUp():Void {

        if (!allowMovingCursor) return;

        if (shiftPressed) {
            var startLine = lineForPos(selectionStart);
            var endLine = lineForPos(selectionEnd);
            if (!invertedSelection && endLine > startLine) {
                // Move the cursor by one line to the top
                var offset = explicitPosInLine;
                var currentLine = endLine;
                if (delegate != null) offset = delegate.textInputClosestPositionInLine(text, explicitPosInLine, explicitPosLine, currentLine - 1);
                var newPos = globalPosForLine(currentLine - 1, offset);
                selectionEnd = Std.int(Math.max(selectionStart, newPos));
                emitSelection(selectionStart, selectionEnd);
            }
            else if (selectionStart > 0) {
                invertedSelection = true;
                if (startLine > 0) {
                    // Move the cursor by one line to the top
                    var offset = explicitPosInLine;
                    var currentLine = startLine;
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(text, explicitPosInLine, explicitPosLine, currentLine - 1);
                    selectionStart = globalPosForLine(currentLine - 1, offset);
                }
                else {
                    selectionStart = 0;
                }
                emitSelection(selectionStart, selectionEnd);
            }
        }
        else {
            invertedSelection = false;

            if (selectionStart > 0) {
                var currentLine = lineForPos(selectionStart);
                if (currentLine > 0) {
                    // Move the cursor by one line to the top
                    var offset = explicitPosInLine;
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(text, explicitPosInLine, explicitPosLine, currentLine - 1);
                    selectionStart = globalPosForLine(currentLine - 1, offset);
                    selectionEnd = selectionStart;
                    emitSelection(selectionStart, selectionEnd);
                }
                else {
                    // Move the cursor to the beginning of the text
                    selectionStart = 0;
                    selectionEnd = 0;
                    emitSelection(selectionStart, selectionEnd);
                }
            }
            else {
                selectionStart = 0;
                selectionEnd = 0;
                emitSelection(selectionStart, selectionEnd);
            }
        }

    } //moveUp

    public function moveDown():Void {

        if (!allowMovingCursor) return;

        var textLength = text.uLength();

        if (shiftPressed) {
            var startLine = lineForPos(selectionStart);
            var endLine = lineForPos(selectionEnd);
            if (!invertedSelection) {
                if (selectionEnd < textLength - 1) {
                    var offset = explicitPosInLine;
                    var currentLine = endLine;
                    var numLines = numLines();
                    if (currentLine < numLines - 1) {
                        // Move the cursor by one line to the bottom
                        if (delegate != null) offset = delegate.textInputClosestPositionInLine(text, explicitPosInLine, explicitPosLine, currentLine + 1);
                        selectionEnd = globalPosForLine(currentLine + 1, offset);
                    }
                    else {
                        selectionEnd = textLength;
                    }
                    emitSelection(selectionStart, selectionEnd);
                }
                else if (selectionEnd < textLength) {
                    selectionEnd = textLength;
                    emitSelection(selectionStart, selectionEnd);
                }
            }
            else if (invertedSelection) {
                if (endLine > startLine) {
                    var offset = explicitPosInLine;
                    var currentLine = startLine;
                    // Move the cursor by one line to the bottom
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(text, explicitPosInLine, explicitPosLine, currentLine + 1);
                    var newPos = globalPosForLine(currentLine + 1, offset);
                    selectionStart = Std.int(Math.min(selectionEnd, newPos));
                    emitSelection(selectionStart, selectionEnd);
                }
                else if (selectionEnd < textLength - 1) {
                    invertedSelection = false;
                    var currentLine = startLine;
                    var numLines = numLines();
                    var offset = explicitPosInLine;
                    if (currentLine < numLines - 1) {
                        // Move the cursor by one line to the bottom
                        if (delegate != null) offset = delegate.textInputClosestPositionInLine(text, explicitPosInLine, explicitPosLine, currentLine + 1);
                        selectionEnd = globalPosForLine(currentLine + 1, offset);
                    }
                    else {
                        selectionEnd = textLength;
                    }
                    emitSelection(selectionStart, selectionEnd);
                }
                else if (selectionEnd < textLength) {
                    invertedSelection = false;
                    selectionEnd = textLength;
                    emitSelection(selectionStart, selectionEnd);
                }
            }
        }
        else {
            invertedSelection = false;

            if (selectionEnd < textLength - 1) {
                var currentLine = lineForPos(selectionEnd);
                var numLines = numLines();
                if (currentLine < numLines - 1) {
                    // Move the cursor by one line to the bottom
                    var offset = explicitPosInLine;
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(text, explicitPosInLine, explicitPosLine, currentLine + 1);
                    selectionStart = globalPosForLine(currentLine + 1, offset);
                    selectionEnd = selectionStart;
                    emitSelection(selectionStart, selectionEnd);
                }
                else {
                    // Move the cursor to the end of the text
                    selectionStart = textLength;
                    selectionEnd = selectionStart;
                    emitSelection(selectionStart, selectionEnd);
                }
            }
            else {
                selectionStart = textLength;
                selectionEnd = selectionStart;
                emitSelection(selectionStart, selectionEnd);
            }
        }

    } //moveDown

    public function enter():Void {

        emitEnter();

        // In case input was stopped at `enter` event
        if (!inputActive) return;
        
        if (multiline) {
            appendText("\n");
        }
        else {
            stop();
        }

    } //enter

    public function escape():Void {

        emitEscape();
        stop();

    } //escape

    public function shiftDown():Void {

        shiftPressed = true;

    } //shiftDown

    public function shiftUp():Void {

        shiftPressed = false;

    } //shiftUp

/// Helpers

    /** Get the position in the current line, from the given global position in text */
    function posInCurrentLine(globalPos:Int):Int {

        var text = this.text;

        var posInLine = 0;
        while (globalPos > 0) {
            var char = text.uCharAt(globalPos);
            if (char == "\n" && posInLine > 0) {
                posInLine--;
                break;
            }
            globalPos--;
            posInLine++;
        }

        return posInLine;

    } //posInLine

    /** Get the current line (starts from 0) from the given global position in text */
    function lineForPos(globalPos:Int):Int {

        var text = this.text;

        var lineNumber = 0;
        var i = 0;
        while (i < globalPos) {
            var char = text.uCharAt(i);
            if (char == "\n") lineNumber++;
            i++;
        }

        return lineNumber;

    } //lineForPos

    function numLines():Int {

        return text.split("\n").length;

    } //numLines

    function globalPosForLine(lineNumber:Int, lineOffset:Int):Int {

        var text = this.text;
        var i = 0;
        var numChars = text.uLength();
        var currentLine = 0;
        while (i < numChars) {
            var c = text.uCharAt(i);
            if (currentLine == lineNumber) {
                if (lineOffset > 0) {
                    if (c == "\n") break;
                    lineOffset--;
                }
                else {
                    break;
                }
            }
            else if (c == "\n") {
                currentLine++;
            }
            i++;
        }

        return i;

    } //globalPosForLine

} //TextInput
