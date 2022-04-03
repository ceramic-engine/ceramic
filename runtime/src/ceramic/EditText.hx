package ceramic;

import ceramic.Shortcuts.*;
import tracker.Component;

using StringTools;
using ceramic.Extensions;

class EditText extends Entity implements Component implements TextInputDelegate {

/// Internal statics

    static var _point = new Point();

    static var _activeEditTextInput:EditText = null;

/// Events

    @event function update(content:String);

    @event function start();

    @event function submit();

    @event function stop();

/// Public properties

    public var entity:Text;

    public var multiline:Bool = false;

    public var editing(get, never):Bool;
    function get_editing():Bool {
        return (_activeEditTextInput == this);
    }

    public var selectionColor(default, set):Color;
    function set_selectionColor(selectionColor:Color):Color {
        this.selectionColor = selectionColor;
        if (selectText != null)
            selectText.selectionColor = selectionColor;
        return selectionColor;
    }

    public var textCursorColor(default, set):Color;
    function set_textCursorColor(textCursorColor:Color):Color {
        this.textCursorColor = textCursorColor;
        if (selectText != null)
            selectText.textCursorColor = textCursorColor;
        return textCursorColor;
    }

    public var textCursorOffsetX(default, set):Float;
    function set_textCursorOffsetX(textCursorOffsetX:Float):Float {
        this.textCursorOffsetX = textCursorOffsetX;
        if (selectText != null)
            selectText.textCursorOffsetX = textCursorOffsetX;
        return textCursorOffsetX;
    }

    public var textCursorOffsetY(default, set):Float;
    function set_textCursorOffsetY(textCursorOffsetY:Float):Float {
        this.textCursorOffsetY = textCursorOffsetY;
        if (selectText != null)
            selectText.textCursorOffsetY = textCursorOffsetY;
        return textCursorOffsetY;
    }

    public var textCursorHeightFactor(default, set):Float;
    function set_textCursorHeightFactor(textCursorHeightFactor:Float):Float {
        this.textCursorHeightFactor = textCursorHeightFactor;
        if (selectText != null)
            selectText.textCursorHeightFactor = textCursorHeightFactor;
        return textCursorHeightFactor;
    }

    public var disabled(default, set):Bool = false;
    function set_disabled(disabled:Bool):Bool {
        if (disabled == this.disabled) return disabled;
        this.disabled = disabled;
        if (disabled) {
            stopInput();
        }
        return disabled;
    }

    /**
     * Optional container on which pointer events are bound
     */
    public var container(default,set):Visual = null;
    function set_container(container:Visual):Visual {
        if (this.container == container) return container;
        this.container = container;
        if (selectText != null) {
            selectText.container = container;
        }
        if (entity != null) bindPointerEvents();
        return container;
    }

    /**
     * SelectText instance used internally to manage text selection.
     * Will be defined after component has been assigned to an entity.
     */
    public var selectText(default, null):SelectText = null;

/// Internal properties

    var boundContainer:Visual = null;

    var selectionBackgrounds:Array<Quad> = [];

    var inputActive:Bool = false;

    var willUpdateSelection:Bool = false;

    var textCursor:Quad = null;

    var textCursorToggleVisibilityTime:Float = 1.0;

/// Lifecycle

    public function new(selectionColor:Color, textCursorColor:Color, textCursorOffsetX:Float = 0, textCursorOffsetY:Float = 0, textCursorHeightFactor:Float = 1) {

        super();

        id = Utils.uniqueId();
        this.selectionColor = selectionColor;
        this.textCursorColor = textCursorColor;
        this.textCursorOffsetX = textCursorOffsetX;
        this.textCursorOffsetY = textCursorOffsetY;
        this.textCursorHeightFactor = textCursorHeightFactor;

    }

    function bindAsComponent() {

        // Get or init SelectText component
        selectText = cast entity.component('selectText');
        if (selectText == null) {
            selectText = new SelectText(
                selectionColor, textCursorColor, textCursorOffsetX, textCursorOffsetY, textCursorHeightFactor
            );
            entity.component('selectText', selectText);
        }

        selectText.container = container;
        selectText.onSelection(this, updateFromSelection);

        bindPointerEvents();
        bindKeyBindings();

        app.onUpdate(this, handleAppUpdate);

    }

/// Public API

    public function startInput(selectionStart:Int = -1, selectionEnd:Int = -1):Void {

        if (_activeEditTextInput != null) {
            _activeEditTextInput.stopInput();
            _activeEditTextInput = null;
            app.onceImmediate(function() {
                if (destroyed || disabled)
                    return;
                startInput(selectionStart, selectionEnd);
            });
            return;
        }

        emitStart();

        // In case we changed content in start event handler
        if (selectionEnd > entity.content.length) {
            selectionEnd = entity.content.length;
        }

        _activeEditTextInput = this;

        var content = entity.content;

        var rectTarget:ceramic.Visual = entity;
        if (container != null) {
            rectTarget = container;
        }

        var x = rectTarget.x;
        var y = rectTarget.y;
        var width = rectTarget.width;
        var height = rectTarget.height;
        var anchorX = rectTarget.anchorX;
        var anchorY = rectTarget.anchorY;

        rectTarget.visualToScreen(x - width * anchorX, y - height * anchorY, _point);
        var screenLeft = _point.x;
        var screenTop = _point.y;
        rectTarget.visualToScreen(x - width * anchorX + width, y - height * anchorY + height, _point);
        var screenRight = _point.x;
        var screenBottom = _point.y;

        app.textInput.onUpdate(this, updateFromTextInput);
        app.textInput.onStop(this, handleStop);
        app.textInput.onEnter(this, handleEnter);
        app.textInput.onEscape(this, handleEscape);
        app.textInput.onSelection(this, updateFromInputSelection);

        selectText.showCursor = true;
        selectText.allowSelectingFromPointer = true;

        inputActive = true;

        app.textInput.start(
            content,
            screenLeft,
            screenTop,
            screenRight - screenLeft,
            screenBottom - screenTop,
            multiline,
            selectionStart,
            selectionEnd,
            true,
            this
        );

    }

    public function stopInput():Void {

        inputActive = false;

        app.textInput.offUpdate(updateFromTextInput);
        app.textInput.offStop(handleStop);
        app.textInput.offEnter(handleEnter);
        app.textInput.offEscape(handleEscape);
        app.textInput.offSelection(updateFromInputSelection);

        if (_activeEditTextInput == this) {
            app.textInput.stop();
            _activeEditTextInput = null;
        }

        selectText.showCursor = false;
        selectText.allowSelectingFromPointer = false;
        selectText.selectionStart = -1;
        selectText.selectionEnd = -1;

        emitStop();

    }

    public function updateText(text:String):Void {

        if (!inputActive) return;

        app.textInput.text = text;

    }

    public function focus() {

        if (disabled)
            return;

        screen.focusedVisual = entity;
        if (!inputActive) {
            app.onceImmediate(function() {
                if (destroyed || disabled)
                    return;
                // This way of calling will ensure any previous text input
                // can be stopped before we start this new one
                startInput(0, entity.content.length);
            });
        }

    }

/// Internal

    function handleStop():Void {

        stopInput();

    }

    function handleEnter():Void {

        if (!multiline) {
            emitSubmit();
            stopInput();
        }

    }

    function handleEscape():Void {

        stopInput();

    }

    function updateFromTextInput(text:String):Void {

        // Update text content ourself
        entity.content = text;

        // But allow external code to put another processed value if needed
        emitUpdate(text);

    }

    function updateFromSelection(selectionStart:Int, selectionEnd:Int, inverted:Bool):Void {

        app.textInput.updateSelection(selectionStart, selectionEnd, inverted);

    }

    function updateFromInputSelection(selectionStart:Int, selectionEnd:Int):Void {

        selectText.selectionStart = selectionStart;
        selectText.selectionEnd = selectionEnd;

    }

/// TextInput delegate

    public function textInputClosestPositionInLine(fromPosition:Int, fromLine:Int, toLine:Int):Int {

        var indexFromLine = entity.indexForPosInLine(fromLine, fromPosition);
        var xPosition = entity.xPositionAtIndex(indexFromLine);

        return entity.posInLineForX(toLine, xPosition);

    }

    public function textInputNumberOfLines():Int {

        var glyphQuads = entity.glyphQuads;
        if (glyphQuads.length == 0) return 1;

        return glyphQuads[glyphQuads.length - 1].line + 1;

    }

    public function textInputIndexForPosInLine(lineNumber:Int, lineOffset:Int):Int {

        return entity.indexForPosInLine(lineNumber, lineOffset);

    }

    public function textInputLineForIndex(index:Int):Int {

        return entity.lineForIndex(index);

    }

    public function textInputPosInLineForIndex(index:Int):Int {

        return entity.posInLineForIndex(index);

    }

/// Pointer events and focus

    function bindPointerEvents() {

        if (boundContainer != null) {
            boundContainer.offPointerDown(handlePointerDown);
            boundContainer = null;
        }
        else {
            entity.offPointerDown(handlePointerDown);
        }

        if (container != null) {
            container.onPointerDown(this, handlePointerDown);
            boundContainer = container;
        }
        else {
            entity.onPointerDown(this, handlePointerDown);
        }

    }

    function handlePointerDown(info:TouchInfo) {

        focus();

    }

    function handleAppUpdate(delta:Float) {

        // Check focus
        if (inputActive && screen.focusedVisual != entity && (container == null || screen.focusedVisual != container)) {
            stopInput();
        }

    }

/// Key bindings

    function bindKeyBindings() {

        var keyBindings = new KeyBindings();

        // CMD/CTRL + C is handled in SelectText component

        keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_X)], function() {
            // CMD/CTRL + X
            if (screen.focusedVisual != entity || selectText.selectionEnd - selectText.selectionStart <= 0) return;
            var selectedText = entity.content.substring(selectText.selectionStart, selectText.selectionEnd);
            app.backend.clipboard.setText(selectedText);

            var newText = entity.content.substring(0, selectText.selectionStart) + entity.content.substring(selectText.selectionEnd);
            selectText.selectionEnd = selectText.selectionStart;

            // Update text content
            entity.content = newText;
            emitUpdate(newText);
        });

        keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_V)], function() {
            // CMD/CTRL + V
            if (screen.focusedVisual != entity) return;
            var pasteText = app.backend.clipboard.getText();
            if (pasteText == null) pasteText = '';
            if (!multiline) pasteText = pasteText.replace("\n", ' ');
            pasteText.replace("\r", '');
            var newText = entity.content.substring(0, selectText.selectionStart) + pasteText + entity.content.substring(selectText.selectionEnd);
            selectText.selectionStart += pasteText.length;
            selectText.selectionEnd = selectText.selectionStart;

            // Update text content
            entity.content = newText;
            emitUpdate(newText);
        });

        onDestroy(keyBindings, function(_) {
            keyBindings.destroy();
            keyBindings = null;
        });

        entity.component('editText.keyBindings', keyBindings);

    }

    override function destroy() {

        if (inputActive)
            stopInput();

        super.destroy();

    }

}
