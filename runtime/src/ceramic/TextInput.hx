package ceramic;

import ceramic.Shortcuts.*;
import tracker.Events;

using StringTools;

/**
 * Handles keyboard text input and cursor navigation.
 * 
 * This class manages text editing operations including text insertion,
 * deletion, selection, and cursor movement. It works in conjunction
 * with the backend's text input system.
 */
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

    var lshiftPressed:Bool = false;

    var rshiftPressed:Bool = false;

    var lctrlPressed:Bool = false;

    var rctrlPressed:Bool = false;

    var lmetaPressed:Bool = false;

    var rmetaPressed:Bool = false;

    var invertedSelection:Bool = false;

    /**
     * Whether cursor movement with arrow keys is allowed.
     */
    public var allowMovingCursor(default,null):Bool = false;

    /**
     * Whether multiline text input is enabled.
     * When true, Enter key creates new lines instead of submitting.
     */
    public var multiline(default,null):Bool = false;

    /**
     * The current text content.
     */
    public var text(default,set):String = '';

    /**
     * The start position of the text selection (cursor position when no selection).
     */
    public var selectionStart(default,null):Int = -1;

    /**
     * The end position of the text selection (same as selectionStart when no selection).
     */
    public var selectionEnd(default,null):Int = -1;

    /**
     * Optional delegate for custom text navigation behavior.
     */
    public var delegate(default,null):TextInputDelegate = null;

/// Lifecycle

    private function new() {

        //

    }

/// Public API

    /**
     * Start text input.
     * 
     * @param text Initial text content
     * @param x X position of the input area in screen coordinates
     * @param y Y position of the input area in screen coordinates
     * @param w Width of the input area
     * @param h Height of the input area
     * @param multiline Whether to allow multiline input
     * @param selectionStart Initial selection start position (-1 for end of text)
     * @param selectionEnd Initial selection end position (-1 for no selection)
     * @param allowMovingCursor Whether to allow cursor movement with arrow keys
     * @param delegate Optional delegate for custom navigation behavior
     */
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

        if (selectionStart < 0) selectionStart = text.length;
        if (selectionEnd < selectionStart) selectionEnd = selectionStart;
        this.selectionStart = selectionStart;
        this.selectionEnd = selectionEnd;

        final matrix = @:privateAccess screen.matrix;
        final nativeX = matrix.transformX(x, y) / screen.nativeDensity;
        final nativeY = matrix.transformY(x, y) / screen.nativeDensity;
        final nativeW = matrix.transformX(x + w, y + h) / screen.nativeDensity - nativeX;
        final nativeH = matrix.transformY(x + w, y + h) / screen.nativeDensity - nativeY;

        app.backend.textInput.start(text, nativeX, nativeY, nativeW, nativeH);
        emitUpdate(text);
        emitSelection(selectionStart, selectionEnd);

    }

    /**
     * Stop text input and release resources.
     */
    public function stop():Void {

        if (!inputActive) return;
        inputActive = false;

        selectionStart = -1;
        selectionEnd = -1;
        invertedSelection = false;
        delegate = null;

        app.backend.textInput.stop();
        emitStop();

    }

    /**
     * Update the current text selection.
     * 
     * @param selectionStart New selection start position
     * @param selectionEnd New selection end position
     * @param inverted Whether the selection is inverted (cursor at start)
     */
    public function updateSelection(selectionStart:Int, selectionEnd:Int, ?inverted:Bool):Void {

        if (this.selectionStart != selectionStart || this.selectionEnd != selectionEnd) {
            this.selectionStart = selectionStart;
            this.selectionEnd = selectionEnd;
            if (inverted != null) invertedSelection = inverted;
            emitSelection(selectionStart, selectionEnd);
        }

    }

    /**
     * Append text at the current cursor position.
     * Replaces any selected text.
     * 
     * @param text Text to append
     */
    public function appendText(text:String):Void {

        // Ignore text input if CTRL is pressed
        if (lctrlPressed || rctrlPressed) {
            #if ceramic_debug_text_input
            trace('skip appendText because lctrlPressed=$lctrlPressed rctrlPressed=$rctrlPressed');
            #end
            return;
        }

        // Clear selection and add text in place

        var newText = '';
        if (selectionStart > 0) {
            newText += this.text.substring(0, selectionStart);
        }
        newText += text;
        newText += this.text.substring(selectionEnd);

        selectionStart += text.length;
        selectionEnd = selectionStart;
        invertedSelection = false;
        this.text = newText;

        emitUpdate(this.text);
        emitSelection(selectionStart, selectionEnd);

        explicitPosInLine = posInCurrentLine(selectionStart);
        explicitPosLine = lineForPos(selectionStart);

    }

    /**
     * Insert a space character at the cursor position.
     */
    public function space():Void {

        appendText(' ');

    }

    /**
     * Delete the character before the cursor or the selected text.
     */
    public function backspace():Void {

        // Clear selection and erase text in place

        var eraseSelection = selectionEnd > selectionStart;

        var newText = '';
        if (selectionStart > 1) {
            newText += this.text.substring(0, eraseSelection ? selectionStart : selectionStart - 1);
        }
        newText += this.text.substring(selectionEnd);

        if (selectionStart > 0 && !eraseSelection) selectionStart--;
        selectionEnd = selectionStart;
        this.text = newText;

        emitUpdate(text);
        emitSelection(selectionStart, selectionEnd);

        explicitPosInLine = posInCurrentLine(selectionStart);
        explicitPosLine = lineForPos(selectionStart);

    }

    /**
     * Move the cursor one character to the left.
     * If Shift is pressed, extends the selection.
     */
    public function moveLeft():Void {

        if (!allowMovingCursor) return;

        if (lshiftPressed || rshiftPressed) {
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

    }

    /**
     * Move the cursor one character to the right.
     * If Shift is pressed, extends the selection.
     */
    public function moveRight():Void {

        if (!allowMovingCursor) return;

        if (lshiftPressed || rshiftPressed) {
            var textLength = text.length;

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
            else if (selectionStart < text.length) {
                // Move the cursor by one character to the right
                selectionStart++;
                selectionEnd = selectionStart;
                emitSelection(selectionStart, selectionEnd);
            }

            explicitPosInLine = posInCurrentLine(selectionStart);
            explicitPosLine = lineForPos(selectionStart);
        }

    }

    /**
     * Move the cursor one line up.
     * If Shift is pressed, extends the selection.
     */
    public function moveUp():Void {

        if (!allowMovingCursor) return;

        if (lshiftPressed || rshiftPressed) {
            var startLine = lineForPos(selectionStart);
            var endLine = lineForPos(selectionEnd);
            if (!invertedSelection && endLine > startLine) {
                // Move the cursor by one line to the top
                var offset = explicitPosInLine;
                var currentLine = endLine;
                if (delegate != null) offset = delegate.textInputClosestPositionInLine(explicitPosInLine, explicitPosLine, currentLine - 1);
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
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(explicitPosInLine, explicitPosLine, currentLine - 1);
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
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(explicitPosInLine, explicitPosLine, currentLine - 1);
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

    }

    /**
     * Move the cursor one line down.
     * If Shift is pressed, extends the selection.
     */
    public function moveDown():Void {

        if (!allowMovingCursor) return;

        var textLength = text.length;

        if (lshiftPressed || rshiftPressed) {
            var startLine = lineForPos(selectionStart);
            var endLine = lineForPos(selectionEnd);
            if (!invertedSelection) {
                if (selectionEnd < textLength - 1) {
                    var offset = explicitPosInLine;
                    var currentLine = endLine;
                    var numLines = numLines();
                    if (currentLine < numLines - 1) {
                        // Move the cursor by one line to the bottom
                        if (delegate != null) offset = delegate.textInputClosestPositionInLine(explicitPosInLine, explicitPosLine, currentLine + 1);
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
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(explicitPosInLine, explicitPosLine, currentLine + 1);
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
                        if (delegate != null) offset = delegate.textInputClosestPositionInLine(explicitPosInLine, explicitPosLine, currentLine + 1);
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
                    if (delegate != null) offset = delegate.textInputClosestPositionInLine(explicitPosInLine, explicitPosLine, currentLine + 1);
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

    }

    /**
     * Handle Enter key press.
     * In multiline mode, inserts a newline.
     * In single-line mode, triggers the enter event.
     */
    public function enter():Void {

        emitEnter();

        // In case input was stopped at `enter` event
        if (!inputActive) return;

        if (multiline) {
            appendText("\n");
        }

    }

    public function kpEnter():Void {
        
        enter();
        
    }

    /**
     * Handle Escape key press.
     * Triggers the escape event and stops input.
     */
    public function escape():Void {

        emitEscape();
        stop();

    }

    public function lshiftDown():Void {

        lshiftPressed = true;

    }

    public function lshiftUp():Void {

        lshiftPressed = false;

    }

    public function rshiftDown():Void {

        rshiftPressed = true;

    }

    public function rshiftUp():Void {

        rshiftPressed = false;

    }

    public function lctrlDown():Void {

        lctrlPressed = true;

    }

    public function lctrlUp():Void {

        lctrlPressed = false;

    }

    public function rctrlDown():Void {

        rctrlPressed = true;

    }

    public function rctrlUp():Void {

        rctrlPressed = false;

    }

    public function lmetaDown():Void {

        lmetaPressed = true;

    }

    public function lmetaUp():Void {

        lmetaPressed = false;

    }

    public function rmetaDown():Void {

        rmetaPressed = true;

    }

    public function rmetaUp():Void {

        rmetaPressed = false;

    }

/// Helpers

    /**
     * Get the position in the current line, from the given global position in text
     */
    function posInCurrentLine(globalPos:Int):Int {

        if (delegate != null) return delegate.textInputPosInLineForIndex(globalPos);

        var text = this.text;

        var posInLine = 0;
        while (globalPos > 0) {
            var char = text.charAt(globalPos);
            if (char == "\n" && posInLine > 0) {
                posInLine--;
                break;
            }
            globalPos--;
            posInLine++;
        }

        return posInLine;

    }

    /**
     * Get the current line (starts from 0) from the given global position in text
     */
    function lineForPos(globalPos:Int):Int {

        if (delegate != null) return delegate.textInputLineForIndex(globalPos);

        var text = this.text;

        var lineNumber = 0;
        var i = 0;
        while (i < globalPos) {
            var char = text.charAt(i);
            if (char == "\n") lineNumber++;
            i++;
        }

        return lineNumber;

    }

    function numLines():Int {

        if (delegate != null) return delegate.textInputNumberOfLines();

        return text.split("\n").length;

    }

    function globalPosForLine(lineNumber:Int, lineOffset:Int):Int {

        if (delegate != null) return delegate.textInputIndexForPosInLine(lineNumber, lineOffset);

        var text = this.text;
        var i = 0;
        var numChars = text.length;
        var currentLine = 0;
        while (i < numChars) {
            var c = text.charAt(i);
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

    }

    function set_text(text:String):String {

        if (this.text == text) return text;
        this.text = text;

        var len = text.length;

        var selectionStart = this.selectionStart;
        var selectionEnd = this.selectionEnd;

        if (selectionEnd > len) selectionEnd = len;
        if (selectionStart > selectionEnd) selectionStart = selectionEnd;
        updateSelection(selectionStart, selectionEnd);

        return text;

    }

}
