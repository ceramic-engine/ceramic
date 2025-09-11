package ceramic;

import ceramic.Shortcuts.*;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using StringTools;
using ceramic.Extensions;

/**
 * Component that handles text selection and cursor display for Text visuals.
 * 
 * This component provides visual feedback for text selection including
 * selection highlighting and text cursor display. It also handles
 * pointer-based text selection and double-click word selection.
 */
class SelectText extends Entity implements Component implements Observable {

/// Internal statics

    static var _point = new Point();

/// Events

    /**
     * Event fired when the text selection changes.
     * 
     * @param selectionStart Start position of the selection
     * @param selectionEnd End position of the selection
     * @param inverted Whether the selection is inverted (cursor at start)
     */
    @event function selection(selectionStart:Int, selectionEnd:Int, inverted:Bool);

/// Public properties

    /**
     * The Text entity this component is attached to.
     */
    public var entity:Text;

    /**
     * Color used for text selection highlighting.
     */
    public var selectionColor:Color;

    /**
     * Color of the text cursor.
     */
    public var textCursorColor:Color;

    /**
     * Horizontal offset for the text cursor position.
     */
    public var textCursorOffsetX:Float = 0;

    /**
     * Vertical offset for the text cursor position.
     */
    public var textCursorOffsetY:Float = 0;

    /**
     * Height factor for the text cursor (1.0 = full line height).
     */
    public var textCursorHeightFactor:Float = 1;

    /**
     * Width of the text cursor in pixels.
     */
    public var textCursorWidth:Float = 1;

    /**
     * Optional container on which pointer events are bound
     */
    @observe public var container:Visual = null;

    /**
     * Whether to allow text selection using pointer/mouse.
     */
    @observe public var allowSelectingFromPointer:Bool = false;

    /**
     * Whether to show the text cursor.
     */
    @observe public var showCursor:Bool = false;

    /**
     * Start position of the current text selection.
     * -1 means no selection.
     */
    @observe public var selectionStart:Int = -1;

    /**
     * End position of the current text selection.
     * -1 means no selection.
     */
    @observe public var selectionEnd:Int = -1;

    /**
     * Whether the selection is inverted (cursor at start instead of end).
     */
    @observe public var invertedSelection:Bool = false;

    /**
     * Whether the pointer is currently pressed down.
     */
    @observe public var pointerIsDown:Bool = false;

/// Internal properties

    var boundContainer:Visual = null;

    var doubleClick:DoubleClick = null;

    var didDoubleClick:Bool = false;

    var selectionBackgrounds:Array<Quad> = [];

    var willUpdateSelection:Bool = false;

    var textCursor:Quad = null;

    var textCursorToggleVisibilityTime:Float = 1.0;

/// Lifecycle

    /**
     * Create a new SelectText component.
     * 
     * @param selectionColor Color for selection highlighting
     * @param textCursorColor Color of the text cursor
     * @param textCursorOffsetX Horizontal offset for cursor position
     * @param textCursorOffsetY Vertical offset for cursor position
     * @param textCursorHeightFactor Height factor for cursor (1.0 = full line height)
     * @param textCursorWidth Width of the cursor in pixels
     */
    public function new(selectionColor:Color, textCursorColor:Color, textCursorOffsetX:Float = 0, textCursorOffsetY:Float = 0, textCursorHeightFactor:Float = 1, textCursorWidth:Float = 1) {

        super();

        this.selectionColor = selectionColor;
        this.textCursorColor = textCursorColor;
        this.textCursorOffsetX = textCursorOffsetX;
        this.textCursorOffsetY = textCursorOffsetY;
        this.textCursorHeightFactor = textCursorHeightFactor;
        this.textCursorWidth = textCursorWidth;

    }

/// Public apis

    public function findPreviousWordBoundary(fromPos:Int) {
        var content = entity.content;

        if (fromPos <= 0) {
            return 0;
        }

        var leftPart = content.substring(0, fromPos);
        var wordBoundaryRegex = ~/(\S+)\s*$/;

        if (wordBoundaryRegex.match(leftPart)) {
            return wordBoundaryRegex.matchedPos().pos;
        }

        return 0;
    }

    public function findNextWordBoundary(fromPos:Int) {
        var content = entity.content;
        var contentLength = content.length;

        if (fromPos >= contentLength) {
            return contentLength;
        }

        var rightPart = content.substring(fromPos);
        var nextWordRegex = ~/^\S*\s*(\S|$)/;

        if (nextWordRegex.match(rightPart)) {
            var matchInfo = nextWordRegex.matchedPos();
            var pos = fromPos + matchInfo.pos + matchInfo.len - 1;

            if (pos > contentLength || rightPart.charAt(matchInfo.pos + matchInfo.len - 1) == '') {
                pos = contentLength;
            }
            return pos;
        }

        return contentLength;
    }

    function bindAsComponent() {

        entity.onGlyphQuadsChange(this, updateSelectionGraphics);

        app.onUpdate(this, updateCursorVisibility);
        onShowCursorChange(this, handleShowCursorChange);

        autorun(updateFromSelection);
        autorun(updatePointerEventBindings);

        onSelectionStartChange(this, function(_, _) { updateSelectionGraphics(); });
        onSelectionEndChange(this, function(_, _) { updateSelectionGraphics(); });

        bindKeyBindings();

    }

/// Internal

    function updateFromSelection() {

        var selectionStart = this.selectionStart;
        var selectionEnd = this.selectionEnd;
        var invertedSelection = this.invertedSelection;

        unobserve();

        emitSelection(selectionStart, selectionEnd, invertedSelection);
        resetCursorVisibility();
        updateSelectionGraphics();

        reobserve();

    }

    function updateSelectionGraphics():Void {

        if (willUpdateSelection) return;

        willUpdateSelection = true;
        app.onceImmediate(doUpdateSelectionGraphics);

    }

    function doUpdateSelectionGraphics():Void {

        willUpdateSelection = false;

        if (selectionStart == -1 || selectionEnd == -1) {
            clearSelectionGraphics();
            return;
        }

        var glyphQuads = entity.glyphQuads;

        var backgroundIndex = -1;
        var backgroundCurrentLine = -1;
        var backgroundLeft:Float = -1;
        var backgroundTop:Float = -1;
        var backgroundRight:Float = -1;
        var backgroundBottom:Float = -1;
        var backgroundPad = Math.round(entity.pointSize * 0.1);
        var cursorPad = Math.round(entity.pointSize * (textCursorHeightFactor - 0.8));
        var selectionHeight = Math.ceil(entity.pointSize * 1.0);
        var cursorWidth:Float = textCursorWidth;
        var cursorHeight:Float = Math.ceil(entity.pointSize);
        var computedLineHeight = entity.lineHeight * entity.font.lineHeight * entity.pointSize / entity.font.pointSize;
        var lineBreakWidth:Float = entity.pointSize * 0.4;
        var selectionRightPadding = 1;

        var hasCharsSelection = selectionEnd > selectionStart;

        inline function addSelectionBackground() {

            backgroundIndex++;

            var bg = selectionBackgrounds[backgroundIndex];
            if (bg == null) {
                bg = new Quad();
                selectionBackgrounds[backgroundIndex] = bg;

                bg.depth = -1;
                entity.add(bg);
                bg.autorun(function() {
                    bg.color = selectionColor;
                });
            }
            if (backgroundLeft == 0) {
                bg.pos(backgroundLeft - backgroundPad + textCursorOffsetX, backgroundTop - backgroundPad + textCursorOffsetY);
                bg.size(backgroundRight + backgroundPad - backgroundLeft + selectionRightPadding, backgroundBottom + backgroundPad * 2 - backgroundTop);
            }
            else {
                bg.pos(backgroundLeft + textCursorOffsetX, backgroundTop - backgroundPad + textCursorOffsetY);
                bg.size(backgroundRight - backgroundLeft + selectionRightPadding, backgroundBottom + backgroundPad * 2 - backgroundTop);
            }

        }

        inline function createTextCursorIfNeeded() {

            if (textCursor == null) {
                textCursor = new Quad();
                textCursor.autorun(function() {
                    textCursor.color = textCursorColor;
                });
                textCursor.depth = 0;
                entity.add(textCursor);
            }

        }

        if (hasCharsSelection) {

            // Clear cursor as we display a selection
            if (textCursor != null) {
                textCursor.destroy();
                textCursor = null;
            }

            // Compute selection bacgkrounds
            for (i in 0...glyphQuads.length) {
                var glyphQuad = glyphQuads.unsafeGet(i);
                var index = glyphQuad.index;
                var line = glyphQuad.line;

                if (selectionEnd > selectionStart) {
                    if (backgroundCurrentLine == -1) {
                        if (index >= selectionStart) {
                            if (i > 0 && index > selectionStart && glyphQuad.posInLine == 0) {
                                // Selected a line break
                                var prevGlyphQuad = glyphQuads[i - 1];
                                var startLine = entity.lineForIndex(selectionStart);
                                var endLine = entity.lineForIndex(selectionEnd);
                                var matchedLine = glyphQuad.line;
                                if (endLine > startLine && startLine == prevGlyphQuad.line) {
                                    // Selection begins with a line break
                                    backgroundCurrentLine = line - 1;
                                    backgroundLeft = prevGlyphQuad.glyphX + prevGlyphQuad.glyphAdvance;
                                    backgroundRight = prevGlyphQuad.glyphX + prevGlyphQuad.glyphAdvance + lineBreakWidth;
                                    backgroundTop = prevGlyphQuad.glyphY;
                                    backgroundBottom = prevGlyphQuad.glyphY + selectionHeight;
                                    addSelectionBackground();
                                }
                                backgroundCurrentLine = -1;
                                if (index >= selectionStart && index < selectionEnd) {
                                    backgroundCurrentLine = line;
                                    backgroundLeft = glyphQuad.glyphX;
                                    backgroundRight = 0;
                                    backgroundTop = glyphQuad.glyphY;
                                    backgroundBottom = glyphQuad.glyphY + selectionHeight;
                                }
                            }
                            else if (index <= selectionEnd) {
                                backgroundCurrentLine = line;
                                backgroundLeft = glyphQuad.glyphX;
                                backgroundRight = glyphQuad.glyphX + glyphQuad.glyphAdvance;
                                backgroundTop = glyphQuad.glyphY;
                                backgroundBottom = glyphQuad.glyphY + selectionHeight;
                            }
                        }
                    }
                    if (backgroundCurrentLine != -1) {
                        if (line > backgroundCurrentLine || index >= selectionEnd) {
                            if (i > 0 && glyphQuad.posInLine == 0 && selectionEnd - 1 > glyphQuads[i-1].index) {
                                // Line break inside selection
                                var prevGlyphQuad = glyphQuads[i - 1];
                                backgroundRight = prevGlyphQuad.glyphX + prevGlyphQuad.glyphAdvance + lineBreakWidth;
                            }
                            addSelectionBackground();
                            backgroundCurrentLine = -1;
                            if (index >= selectionStart && index < selectionEnd) {
                                backgroundCurrentLine = line;
                                backgroundLeft = glyphQuad.glyphX;
                                backgroundRight = glyphQuad.glyphX + glyphQuad.glyphAdvance;
                                backgroundTop = glyphQuad.glyphY;
                                backgroundBottom = glyphQuad.glyphY + selectionHeight;
                            }
                        }
                        else {
                            backgroundTop = Math.min(backgroundTop, glyphQuad.glyphY);
                            backgroundRight = glyphQuad.glyphX + glyphQuad.glyphAdvance;
                            backgroundBottom = Math.max(backgroundBottom, glyphQuad.glyphY + selectionHeight);
                        }
                    }
                }
            }
        }
        else {
            // Compute text cursor position
            for (i in 0...glyphQuads.length) {
                var glyphQuad = glyphQuads.unsafeGet(i);
                var index = glyphQuad.index;
                if (index == selectionStart - 1) {
                    createTextCursorIfNeeded();
                    textCursor.pos(
                        glyphQuad.glyphX + glyphQuad.glyphAdvance + textCursorOffsetX,
                        glyphQuad.glyphY - cursorPad + textCursorOffsetY
                    );
                    textCursor.size(
                        cursorWidth,
                        cursorHeight + cursorPad * 2
                    );
                    break;
                }
                else if (index >= selectionStart) {
                    createTextCursorIfNeeded();
                    textCursor.pos(
                        glyphQuad.glyphX + textCursorOffsetX,
                        glyphQuad.glyphY - cursorPad * 0.5 + textCursorOffsetY
                    );
                    textCursor.size(
                        cursorWidth,
                        cursorHeight + cursorPad * 2
                    );
                    var glyphLine = glyphQuad.line;
                    var realLine = entity.lineForIndex(selectionStart);
                    while (realLine < glyphLine) {
                        textCursor.pos(
                            0,
                            textCursor.y - computedLineHeight
                        );
                        glyphLine--;
                    }
                    break;
                }
                else if (i == glyphQuads.length - 1) {
                    createTextCursorIfNeeded();
                    textCursor.pos(
                        glyphQuad.glyphX + glyphQuad.glyphAdvance + textCursorOffsetX,
                        glyphQuad.glyphY - cursorPad * 0.5 + textCursorOffsetY
                    );
                    textCursor.size(
                        cursorWidth,
                        cursorHeight + cursorPad * 2
                    );
                }
            }
        }

        if (backgroundCurrentLine != -1) {
            addSelectionBackground();
        }

        // Cleanup unused
        while (backgroundIndex < selectionBackgrounds.length - 1) {
            var bg = selectionBackgrounds.pop();
            bg.destroy();
        }

    }

    function clearSelectionGraphics() {

        if (textCursor != null) {
            textCursor.destroy();
            textCursor = null;
        }

        while (selectionBackgrounds.length > 0) {
            var bg = selectionBackgrounds.pop();
            bg.destroy();
        }

    }

    function handleShowCursorChange(_, _) {

        resetCursorVisibility();

    }

    function updateCursorVisibility(delta:Float):Void {

        if (textCursor == null) return;

        if (!showCursor) {
            textCursor.visible = false;
            return;
        }

        if (pointerIsDown) {
            resetCursorVisibility();
            return;
        }

        textCursorToggleVisibilityTime -= delta;
        while (textCursorToggleVisibilityTime <= 0) {
            textCursorToggleVisibilityTime += 0.5;
            textCursor.visible = !textCursor.visible;
        }

    }

    function resetCursorVisibility() {

        textCursorToggleVisibilityTime = 0.5;
        if (textCursor != null) {
            textCursor.visible = showCursor;
        }

    }

/// Selecting from pointer

    function updatePointerEventBindings() {

        var container = this.container;
        var allowSelectingFromPointer = this.allowSelectingFromPointer;

        unobserve();

        if (boundContainer != null) {
            boundContainer.offPointerDown(handlePointerDown);
            boundContainer.offPointerUp(handlePointerUp);
            boundContainer = null;
        }

        entity.offPointerDown(handlePointerDown);
        entity.offPointerUp(handlePointerUp);

        if (doubleClick != null) {
            doubleClick.destroy();
            doubleClick = null;
        }

        if (allowSelectingFromPointer) {
            var toBind:Visual = entity;
            if (container != null) {
                toBind = container;
                boundContainer = container;
            }
            toBind.onPointerDown(this, handlePointerDown);
            toBind.onPointerUp(this, handlePointerUp);
            doubleClick = new DoubleClick();
            doubleClick.onDoubleClick(this, handleDoubleClick);
            toBind.component('doubleClick', doubleClick);
        }
        else {
            pointerIsDown = false;
            screen.offPointerMove(handlePointerMove);
        }

        reobserve();

    }

    function indexFromScreenPosition(x, y):Int {

        entity.screenToVisual(x, y, _point);

        x = _point.x;
        y = _point.y;

        var line = entity.lineForYPosition(y);
        var posInLine = entity.posInLineForX(line, x);

        return entity.indexForPosInLine(line, posInLine);

    }

    function handlePointerDown(info:TouchInfo):Void {

        var x = screen.pointerX;
        var y = screen.pointerY;

        var cursorPosition = indexFromScreenPosition(x, y);

        selectionStart = cursorPosition;
        selectionEnd = cursorPosition;
        invertedSelection = false;

        resetCursorVisibility();

        pointerIsDown = true;
        screen.onPointerMove(this, handlePointerMove);

    }

    function handlePointerMove(info:TouchInfo):Void {

        updateSelectionFromMovingPointer(screen.pointerX, screen.pointerY);

    }

    function handlePointerUp(info:TouchInfo):Void {

        screen.offPointerMove(handlePointerMove);

        if (pointerIsDown) {
            pointerIsDown = false;

            if (didDoubleClick) {
                didDoubleClick = false;
            }
            else {
                updateSelectionFromMovingPointer(screen.pointerX, screen.pointerY);
            }
        }

    }

    function updateSelectionFromMovingPointer(x:Float, y:Float):Void {

        var index = indexFromScreenPosition(x, y);

        if (invertedSelection) {
            if (index >= selectionEnd) {
                invertedSelection = false;
                selectionStart = selectionEnd;
                selectionEnd = index;
            }
            else {
                selectionStart = index;
            }
        }
        else {
            if (index < selectionStart) {
                invertedSelection = true;
                selectionEnd = selectionStart;
                selectionStart = index;
            }
            else {
                selectionEnd = index;
            }
        }

        resetCursorVisibility();

    }

    inline function isSelectionBoundChararacter(c:String):Bool {

        // TODO Make this configurable?

        return c.trim() == '' || '/\\<>()[]{}-'.indexOf(c) != -1;

    }

    function handleDoubleClick():Void {

        didDoubleClick = true;

        var index = indexFromScreenPosition(screen.pointerX, screen.pointerY);

        var text = entity.content;
        var len = text.length;

        var start = index;
        var c:String = null;
        var didSelectBefore = false;
        while (start > 0) {
            c = text.charAt(start - 1);
            if (isSelectionBoundChararacter(c)) break;
            didSelectBefore = true;
            start--;
        }

        var end = didSelectBefore ? index : index + 1;
        c = text.charAt(index);
        if (c == null || c.trim() == '') {
            // Nothing to do
        }
        else {
            while (end < len) {
                c = text.charAt(end);
                if (isSelectionBoundChararacter(c)) break;
                end++;
            }
        }

        if (end > len) end = len;

        invertedSelection = false;
        selectionStart = start;
        selectionEnd = end;

    }

/// Key bindings

    function bindKeyBindings() {

        var keyBindings = new KeyBindings();

        keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_C)], function() {
            // CMD/CTRL + C
            if (screen.focusedVisual != entity || selectionEnd - selectionStart <= 0) return;
            var selectedText = entity.content.substring(selectionStart, selectionEnd);
            app.backend.clipboard.setText(selectedText);
        });

        onDestroy(keyBindings, function(_) {
            keyBindings.destroy();
            keyBindings = null;
        });

        entity.component('selectText.keyBindings', keyBindings);

    }

}
