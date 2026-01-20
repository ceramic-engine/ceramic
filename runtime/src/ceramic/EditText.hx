package ceramic;

import ceramic.Shortcuts.*;
import tracker.Component;

using StringTools;
using ceramic.Extensions;

/**
 * Component that enables text editing functionality for Text visuals.
 * 
 * This component provides text input, selection, and editing capabilities
 * when attached to a Text entity. It handles user input, cursor positioning,
 * text selection, and clipboard operations.
 */
class EditText extends Entity implements Component implements TextInputDelegate {

/// Internal statics

    static var _point = new Point();

    static var _activeEditTextInput:EditText = null;

/// Events

    /**
     * Event fired when the text content is updated during editing.
     * 
     * @param content The updated text content
     */
    @event function update(content:String);

    /**
     * Event fired when text editing starts.
     */
    @event function start();

    /**
     * Event fired when the user submits the text (e.g., pressing Enter in single-line mode).
     */
    @event function submit();

    /**
     * Event fired when text editing stops.
     */
    @event function stop();

/// Public properties

    /**
     * The Text entity this component is attached to.
     */
    public var entity:Text;

    /**
     * Whether multiline editing is enabled.
     * When false, pressing Enter will submit the text.
     * When true, pressing Enter will create a new line.
     */
    public var multiline:Bool = false;

    /**
     * Whether this EditText is currently active and editing.
     */
    public var editing(get, never):Bool;
    function get_editing():Bool {
        return (_activeEditTextInput == this);
    }

    /**
     * The color used for text selection highlighting.
     */
    public var selectionColor(default, set):Color;
    function set_selectionColor(selectionColor:Color):Color {
        this.selectionColor = selectionColor;
        if (selectText != null)
            selectText.selectionColor = selectionColor;
        return selectionColor;
    }

    /**
     * The color of the text cursor.
     */
    public var textCursorColor(default, set):Color;
    function set_textCursorColor(textCursorColor:Color):Color {
        this.textCursorColor = textCursorColor;
        if (selectText != null)
            selectText.textCursorColor = textCursorColor;
        return textCursorColor;
    }

    /**
     * Horizontal offset for the text cursor position.
     */
    public var textCursorOffsetX(default, set):Float;
    function set_textCursorOffsetX(textCursorOffsetX:Float):Float {
        this.textCursorOffsetX = textCursorOffsetX;
        if (selectText != null)
            selectText.textCursorOffsetX = textCursorOffsetX;
        return textCursorOffsetX;
    }

    /**
     * Vertical offset for the text cursor position.
     */
    public var textCursorOffsetY(default, set):Float;
    function set_textCursorOffsetY(textCursorOffsetY:Float):Float {
        this.textCursorOffsetY = textCursorOffsetY;
        if (selectText != null)
            selectText.textCursorOffsetY = textCursorOffsetY;
        return textCursorOffsetY;
    }

    /**
     * Height factor for the text cursor (1.0 = full line height).
     */
    public var textCursorHeightFactor(default, set):Float;
    function set_textCursorHeightFactor(textCursorHeightFactor:Float):Float {
        this.textCursorHeightFactor = textCursorHeightFactor;
        if (selectText != null)
            selectText.textCursorHeightFactor = textCursorHeightFactor;
        return textCursorHeightFactor;
    }

    /**
     * Width of the text cursor in pixels.
     */
    public var textCursorWidth(default, set):Float;
    function set_textCursorWidth(textCursorWidth:Float):Float {
        this.textCursorWidth = textCursorWidth;
        if (selectText != null)
            selectText.textCursorWidth = textCursorWidth;
        return textCursorWidth;
    }

    /**
     * Whether text editing is disabled.
     * When disabled, the user cannot edit the text.
     */
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

    var inputRectX:Float = 0;

    var inputRectY:Float = 0;

    var inputRectW:Float = 0;

    var inputRectH:Float = 0;

/// Lifecycle

    /**
     * Create a new EditText component.
     * 
     * @param selectionColor Color for text selection highlighting
     * @param textCursorColor Color of the text cursor
     * @param textCursorOffsetX Horizontal offset for cursor position
     * @param textCursorOffsetY Vertical offset for cursor position
     * @param textCursorHeightFactor Height factor for cursor (1.0 = full line height)
     * @param textCursorWidth Width of the cursor in pixels
     */
    public function new(selectionColor:Color, textCursorColor:Color, textCursorOffsetX:Float = 0, textCursorOffsetY:Float = 0, textCursorHeightFactor:Float = 1, textCursorWidth:Float = 1) {

        super();

        id = Utils.uniqueId();
        this.selectionColor = selectionColor;
        this.textCursorColor = textCursorColor;
        this.textCursorOffsetX = textCursorOffsetX;
        this.textCursorOffsetY = textCursorOffsetY;
        this.textCursorHeightFactor = textCursorHeightFactor;
        this.textCursorWidth = textCursorWidth;

    }

    function bindAsComponent() {

        // Get or init SelectText component
        selectText = cast entity.component('selectText');
        if (selectText == null) {
            selectText = new SelectText(
                selectionColor, textCursorColor, textCursorOffsetX, textCursorOffsetY, textCursorHeightFactor, textCursorWidth
            );
            entity.component('selectText', selectText);
        }

        selectText.container = container;
        selectText.onSelection(this, updateFromSelection);

        bindPointerEvents();
        bindKeyBindings();

        app.onUpdate(this, handleAppUpdate);

        #if web
        handleMobileWebIfNeeded();
        #end

    }

/// Public API

    /**
     * Start text input and editing.
     * 
     * @param selectionStart Initial cursor position or selection start (-1 for end of text)
     * @param selectionEnd Selection end position (-1 for no selection)
     */
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

        computeInputRect();

        app.textInput.onUpdate(this, updateFromTextInput);
        app.textInput.onStop(this, handleStop);
        app.textInput.onEnter(this, handleEnter);
        app.textInput.onEscape(this, handleEscape);
        app.textInput.onSelection(this, updateFromInputSelection);

        selectText.showCursor = true;
        selectText.allowSelectingFromPointer = true;

        inputActive = true;

        #if web
        if (domInput != null) {
            domInput.focus();
        }
        #end

        app.textInput.start(
            content,
            inputRectX,
            inputRectY,
            inputRectW,
            inputRectH,
            multiline,
            selectionStart,
            selectionEnd,
            true,
            this
        );

    }

    /**
     * Stop text input and editing.
     */
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

    /**
     * Update the text content programmatically while editing.
     * 
     * @param text The new text content
     */
    public function updateText(text:String):Void {

        if (!inputActive) return;

        #if web
        if (domInput != null) {
            domInput.value = text;
        }
        #end

        app.textInput.text = text;
        entity.content = text;

        updateFromInputSelection(app.textInput.selectionStart, app.textInput.selectionEnd);

    }

    /**
     * Give focus to this text field and start editing.
     * Selects all text by default.
     */
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

        // If there is a dom input, update it as well
        #if web
        if (domInput != null) {
            domInput.value = text;
            domInputBlockHtmlInputEvent = true;
            app.offXUpdates(unBlockHtmlInputEvent);
            app.onceXUpdates(this, 2, unBlockHtmlInputEvent);
        }
        else {
            domInputBlockSelection = true;
            app.oncePostFlushImmediate(this, () -> domInputBlockSelection = false);
        }
        #end

        // But allow external code to put another processed value if needed
        emitUpdate(text);

    }

    function updateFromSelection(selectionStart:Int, selectionEnd:Int, inverted:Bool):Void {

        app.textInput.updateSelection(selectionStart, selectionEnd, inverted);

        // If there is a dom input, update it as well
        #if web
        if (!domInputBlockSelection && domInput != null) {
            domInput.selectionStart = selectionStart;
            domInput.selectionEnd = selectionEnd;
        }
        domInputBlockSelection = false;
        #end

    }

    function updateFromInputSelection(selectionStart:Int, selectionEnd:Int):Void {

        selectText.selectionStart = selectionStart;
        selectText.selectionEnd = selectionEnd;

        // If there is a dom input, update it as well
        #if web
        if (!domInputBlockSelection && domInput != null) {
            domInput.selectionStart = selectionStart;
            domInput.selectionEnd = selectionEnd;
        }
        domInputBlockSelection = false;
        #end

    }

/// TextInput delegate

    /**
     * Find the closest position in a target line from a position in another line.
     * Used for vertical cursor navigation.
     * 
     * @param fromPosition Position in the source line
     * @param fromLine Source line number
     * @param toLine Target line number
     * @return Closest position in the target line
     */
    public function textInputClosestPositionInLine(fromPosition:Int, fromLine:Int, toLine:Int):Int {

        var indexFromLine = entity.indexForPosInLine(fromLine, fromPosition);
        var xPosition = entity.xPositionAtIndex(indexFromLine);

        return entity.posInLineForX(toLine, xPosition);

    }

    /**
     * Get the total number of lines in the text.
     * 
     * @return Number of lines
     */
    public function textInputNumberOfLines():Int {

        var glyphQuads = entity.glyphQuads;
        if (glyphQuads.length == 0) return 1;

        return glyphQuads[glyphQuads.length - 1].line + 1;

    }

    /**
     * Get the global character index from a line number and position within that line.
     * 
     * @param lineNumber The line number (0-based)
     * @param lineOffset Position within the line
     * @return Global character index
     */
    public function textInputIndexForPosInLine(lineNumber:Int, lineOffset:Int):Int {

        return entity.indexForPosInLine(lineNumber, lineOffset);

    }

    /**
     * Get the line number for a given character index.
     * 
     * @param index Global character index
     * @return Line number (0-based)
     */
    public function textInputLineForIndex(index:Int):Int {

        return entity.lineForIndex(index);

    }

    /**
     * Get the position within a line for a given character index.
     * 
     * @param index Global character index
     * @return Position within the line
     */
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

        //Select all text
        keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_A)], function() {
            // CMD/CTRL + A 
            if (screen.focusedVisual != entity || entity.content.length == 0)
                return;

            selectText.selectionStart = 0;
            selectText.selectionEnd = entity.content.length;
        });
        
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

/// Internal

    function computeInputRect() {

        var rectTarget:ceramic.Visual = entity;
        if (container != null) {
            rectTarget = container;
        }

        rectTarget.visualToScreen(0, 0, _point);
        var screenLeft = _point.x;
        var screenTop = _point.y;
        rectTarget.visualToScreen(rectTarget.width, rectTarget.height, _point);
        var screenRight = _point.x;
        var screenBottom = _point.y;

        inputRectX = screenLeft;
        inputRectY = screenTop;
        inputRectW = screenRight - screenLeft;
        inputRectH = screenBottom - screenTop;

    }

    override function destroy() {

        if (inputActive)
            stopInput();

        #if web
        if (domInput != null) {
            domInput.parentNode.removeChild(domInput);
            domInput = null;
        }
        #end

        super.destroy();

    }

/// Mobile web

    #if web

    var domInput:js.html.InputElement = null;

    var domInputBlockSelection:Bool = false;

    var domInputBlockHtmlInputEvent:Bool = false;

    function unBlockHtmlInputEvent():Void {
        domInputBlockHtmlInputEvent = false;
    }

    function handleMobileWebIfNeeded() {

        // On mobile web (touch devices), we need to make sure the virtual
        // keyboard is displayed. The only way to do that is by putting an
        // HTML input element on top out editable text. The input element
        // needs to be there so that it will catch the click/touch instead
        // of our canvas like the default behaviour.

        computeInputRect();

        var ua = js.Browser.navigator != null ? js.Browser.navigator.userAgent : '';
        var notMSStream:Bool = js.Syntax.code('!window.MSStream');
        var isMobileWeb:Bool = Utils.isIos() || Utils.isAndroid();

        if (isMobileWeb) {
            domInput = cast js.Browser.document.createElement('input');
            domInput.type = 'text';
            domInput.className = 'edit-text';
            domInput.style.display = 'block';
            domInput.style.position = 'absolute';
            domInput.style.left = '-1px';
            domInput.style.top = '-1px';
            domInput.style.width = '1px';
            domInput.style.height = '1px';
            domInput.style.overflow = 'hidden';
            domInput.style.margin = '0';
            domInput.style.padding = '0';
            domInput.style.border = 'none';
            domInput.style.borderRadius = '0';
            domInput.style.outline = 'none';
            domInput.style.userSelect = 'none';
            domInput.style.zIndex = '99999';
            domInput.style.opacity = '0';
            domInput.style.backgroundColor = 'transparent';
            js.Syntax.code('{0}.webkitTapHighlightColor = "transparent"', domInput.style);
            domInput.addEventListener('click', () -> {
                if (!inputActive) {
                    startInput();
                }
            });
            domInput.addEventListener('input', e -> {
                if (inputActive) {
                    if (domInputBlockHtmlInputEvent) {
                        domInput.value = entity.content;
                        domInput.selectionStart = selectText.selectionStart;
                        domInput.selectionEnd = selectText.selectionEnd;
                    }
                    else {
                        var value:String = js.Syntax.code('{0}.target.value', e);
                        entity.content = value;
                        app.textInput.text = value;
                        selectText.selectionStart = domInput.selectionStart;
                        selectText.selectionEnd = domInput.selectionEnd;
                        emitUpdate(value);
                    }
                }
                domInputBlockHtmlInputEvent = false;
            });
            js.Browser.document.getElementById('ceramic-app').appendChild(domInput);
            app.onBeginDraw(this, updateDomInputState);
        }

        updateDomInputState();

    }

    function updateDomInputState() {

        if (domInput == null)
            return;

        computeInputRect();

        final matrix = @:privateAccess screen.matrix;
        final nativeX = matrix.transformX(inputRectX, inputRectY) / screen.nativeDensity;
        final nativeY = matrix.transformY(inputRectX, inputRectY) / screen.nativeDensity;
        final nativeW = matrix.transformX(inputRectX + inputRectW, inputRectY + inputRectH) / screen.nativeDensity - nativeX;
        final nativeH = matrix.transformY(inputRectX + inputRectW, inputRectY + inputRectH) / screen.nativeDensity - nativeY;

        if (inputActive) {
            domInput.style.left = (nativeX - 99999) + 'px';
        }
        else {
            domInput.style.left = nativeX + 'px';
        }
        domInput.style.top = nativeY + 'px';
        domInput.style.width = nativeW + 'px';
        domInput.style.height = nativeH + 'px';

        domInput.style.zIndex = (100 + Math.round(entity.computedDepth * 10000)) + 'px';

        if (!inputActive && js.Browser.document.activeElement == domInput) {
            domInput.blur();
        }

    }

    #end

}
