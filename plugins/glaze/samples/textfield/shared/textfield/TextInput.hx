// Ported from gpui-pre 0.3.10: examples/input.rs (TextInput, TextElement)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package textfield;

import glaze.Action;
import glaze.App;
import glaze.Bounds;
import glaze.ClipboardItem;
import glaze.Context;
import glaze.CursorStyle;
import glaze.Element;
import glaze.ElementInputHandler;
import glaze.Entity;
import glaze.EntityInputHandler;
import glaze.FocusHandle;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Model;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.PaintQuad;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.ShapedLine;
import glaze.Style;
import glaze.TextRun;
import glaze.UTF16Selection;
import glaze.UnderlineStyle;
import glaze.Window;
import glaze.util.Ref;
import glaze.util.Utf8;
import glaze.util.Utf8.Utf8Text;

import glaze.Prelude.*;

@:action(namespace = text_input) class Backspace implements Action {}
@:action(namespace = text_input) class Delete implements Action {}
@:action(namespace = text_input) class Left implements Action {}
@:action(namespace = text_input) class Right implements Action {}
@:action(namespace = text_input) class SelectLeft implements Action {}
@:action(namespace = text_input) class SelectRight implements Action {}
@:action(namespace = text_input) class SelectAll implements Action {}
@:action(namespace = text_input) class Home implements Action {}
@:action(namespace = text_input) class End implements Action {}
@:action(namespace = text_input) class ShowCharacterPalette implements Action {}
@:action(namespace = text_input) class Paste implements Action {}
@:action(namespace = text_input) class Cut implements Action {}
@:action(namespace = text_input) class Copy implements Action {}

/**
 * A single line text field built only on GPUI APIs: GPUI's `examples/input.rs`.
 *
 * Typing, IME composition (marked text, underlined), selection with the
 * keyboard (shift-left / shift-right, cmd-a) and the mouse, copy / cut /
 * paste. Text goes through `EntityInputHandler` (registered in paint by
 * `TextElement` with `window.handleInput`), so the platform (Ceramic's text
 * editing, through `glaze.TextInputBridge`) types into it.
 *
 * Offsets are UTF-8 bytes (`selectedRange`, `markedRange`), converted to and
 * from UTF-16 for the input handler. Difference with the Rust example: cursor
 * moves go by code point instead of grapheme cluster (no grapheme segmentation
 * in the port yet).
 *
 * Bind its keys with `TextInput.bindKeys(cx)`.
 */
class TextInput extends Model implements Render implements EntityInputHandler {

    public final focusHandle:FocusHandle;

    public var content:String;

    public var placeholder:String;

    /** Selection, UTF-8 byte offsets */
    public var selectedRange:Range;

    public var selectionReversed:Bool = false;

    /** IME marked text, UTF-8 byte offsets */
    public var markedRange:Null<Range> = null;

    public var lastLayout:Null<ShapedLine> = null;

    public var lastBounds:Null<Bounds> = null;

    public var isSelecting:Bool = false;

    public function new(focusHandle:FocusHandle, content:String = '', placeholder:String = '') {
        super();
        this.focusHandle = focusHandle;
        this.content = content;
        this.placeholder = placeholder;
        this.selectedRange = new Range(0, 0);
    }

    /**
     * The key bindings of the example (`cmd` shortcuts are also bound to `ctrl`
     * outside macOS).
     */
    public static function bindKeys(cx:App):Void {
        final mod = glaze.OperatingSystem.current.isMac() ? 'cmd' : 'ctrl';
        cx.bindKeys([
            new glaze.KeyBinding('backspace', new Backspace(), null),
            new glaze.KeyBinding('delete', new Delete(), null),
            new glaze.KeyBinding('left', new Left(), null),
            new glaze.KeyBinding('right', new Right(), null),
            new glaze.KeyBinding('shift-left', new SelectLeft(), null),
            new glaze.KeyBinding('shift-right', new SelectRight(), null),
            new glaze.KeyBinding('$mod-a', new SelectAll(), null),
            new glaze.KeyBinding('$mod-v', new Paste(), null),
            new glaze.KeyBinding('$mod-c', new Copy(), null),
            new glaze.KeyBinding('$mod-x', new Cut(), null),
            new glaze.KeyBinding('home', new Home(), null),
            new glaze.KeyBinding('end', new End(), null),
            new glaze.KeyBinding('ctrl-cmd-space', new ShowCharacterPalette(), null),
        ]);
    }

/// Actions

    function left(_:Left, window:Window, cx:Context<TextInput>):Void {
        if (selectedRange.isEmpty()) {
            moveTo(previousBoundary(cursorOffset()), window, cx);
        }
        else {
            moveTo(selectedRange.start, window, cx);
        }
    }

    function right(_:Right, window:Window, cx:Context<TextInput>):Void {
        if (selectedRange.isEmpty()) {
            moveTo(nextBoundary(selectedRange.end), window, cx);
        }
        else {
            moveTo(selectedRange.end, window, cx);
        }
    }

    function selectLeft(_:SelectLeft, window:Window, cx:Context<TextInput>):Void {
        selectTo(previousBoundary(cursorOffset()), window, cx);
    }

    function selectRight(_:SelectRight, window:Window, cx:Context<TextInput>):Void {
        selectTo(nextBoundary(cursorOffset()), window, cx);
    }

    function selectAll(_:SelectAll, window:Window, cx:Context<TextInput>):Void {
        moveTo(0, window, cx);
        selectTo(Utf8.byteLength(content), window, cx);
    }

    function home(_:Home, window:Window, cx:Context<TextInput>):Void {
        moveTo(0, window, cx);
    }

    function end(_:End, window:Window, cx:Context<TextInput>):Void {
        moveTo(Utf8.byteLength(content), window, cx);
    }

    function backspace(_:Backspace, window:Window, cx:Context<TextInput>):Void {
        if (selectedRange.isEmpty()) {
            final prev = previousBoundary(cursorOffset());
            if (cursorOffset() == prev) {
                window.playSystemBell();
                return;
            }
            selectTo(prev, window, cx);
        }
        replaceTextInRange(null, '', window, cx);
    }

    function delete(_:Delete, window:Window, cx:Context<TextInput>):Void {
        if (selectedRange.isEmpty()) {
            final next = nextBoundary(cursorOffset());
            if (cursorOffset() == next) {
                window.playSystemBell();
                return;
            }
            selectTo(next, window, cx);
        }
        replaceTextInRange(null, '', window, cx);
    }

    function onMouseDown(event:MouseDownEvent, window:Window, cx:Context<TextInput>):Void {
        isSelecting = true;
        window.requestVirtualKeyboard();

        if (event.modifiers.shift) {
            selectTo(indexForMousePosition(event.position), window, cx);
        }
        else {
            moveTo(indexForMousePosition(event.position), window, cx);
        }
    }

    function onMouseUp(_:MouseUpEvent, _:Window, _:Context<TextInput>):Void {
        isSelecting = false;
    }

    function onMouseMove(event:MouseMoveEvent, window:Window, cx:Context<TextInput>):Void {
        if (isSelecting) {
            selectTo(indexForMousePosition(event.position), window, cx);
        }
    }

    function showCharacterPalette(_:ShowCharacterPalette, window:Window, _:Context<TextInput>):Void {
        window.showCharacterPalette();
    }

    function pasteAction(_:Paste, window:Window, cx:Context<TextInput>):Void {
        final item = cx.readFromClipboard();
        final text = item != null ? item.text() : null;
        if (text != null) {
            replaceTextInRange(null, StringTools.replace(text, '\n', ' '), window, cx);
        }
    }

    function copy(_:Copy, _:Window, cx:Context<TextInput>):Void {
        if (!selectedRange.isEmpty()) {
            cx.writeToClipboard(ClipboardItem.newString(Utf8.substring(content, selectedRange.start, selectedRange.end)));
        }
    }

    function cut(_:Cut, window:Window, cx:Context<TextInput>):Void {
        if (!selectedRange.isEmpty()) {
            cx.writeToClipboard(ClipboardItem.newString(Utf8.substring(content, selectedRange.start, selectedRange.end)));
            replaceTextInRange(null, '', window, cx);
        }
    }

/// Helpers

    function moveTo(offset:Int, window:Window, cx:Context<Dynamic>):Void {
        selectedRange = new Range(offset, offset);
        selectionReversed = false;
        window.notifyTextSelectionChanged(focusHandle);
        cx.notify();
    }

    public function cursorOffset():Int {
        return selectionReversed ? selectedRange.start : selectedRange.end;
    }

    function indexForMousePosition(position:Point):Int {
        if (content.length == 0) {
            return 0;
        }

        final bounds = lastBounds;
        final line = lastLayout;
        if (bounds == null || line == null) {
            return 0;
        }
        if (position.y < bounds.top()) {
            return 0;
        }
        if (position.y > bounds.bottom()) {
            return Utf8.byteLength(content);
        }
        return line.closestIndexForX(position.x - bounds.left());
    }

    function selectTo(offset:Int, window:Window, cx:Context<Dynamic>):Void {
        var start = selectedRange.start;
        var end = selectedRange.end;
        if (selectionReversed) {
            start = offset;
        }
        else {
            end = offset;
        }
        if (end < start) {
            selectionReversed = !selectionReversed;
            selectedRange = new Range(end, start);
        }
        else {
            selectedRange = new Range(start, end);
        }
        window.notifyTextSelectionChanged(focusHandle);
        cx.notify();
    }

    public function offsetFromUtf16(offset:Int):Int {
        var utf8Offset = 0;
        var utf16Count = 0;
        final text = new Utf8Text(content);
        for (i in 0...text.count) {
            if (utf16Count >= offset) {
                break;
            }
            final c = text.codePoints[i];
            utf16Count += Utf8.utf16Length(c);
            utf8Offset += Utf8.codePointLength(c);
        }
        return utf8Offset;
    }

    public function offsetToUtf16(offset:Int):Int {
        var utf16Offset = 0;
        var utf8Count = 0;
        final text = new Utf8Text(content);
        for (i in 0...text.count) {
            if (utf8Count >= offset) {
                break;
            }
            final c = text.codePoints[i];
            utf8Count += Utf8.codePointLength(c);
            utf16Offset += Utf8.utf16Length(c);
        }
        return utf16Offset;
    }

    public function rangeToUtf16(range:Range):Range {
        return new Range(offsetToUtf16(range.start), offsetToUtf16(range.end));
    }

    public function rangeFromUtf16(rangeUtf16:Range):Range {
        return new Range(offsetFromUtf16(rangeUtf16.start), offsetFromUtf16(rangeUtf16.end));
    }

    /** Start of the code point before `offset` (Rust: grapheme cluster). */
    function previousBoundary(offset:Int):Int {
        final text = new Utf8Text(content);
        var i = text.count - 1;
        while (i >= 0) {
            if (text.byteOffsets[i] < offset) {
                return text.byteOffsets[i];
            }
            i--;
        }
        return 0;
    }

    /** Start of the code point after `offset` (Rust: grapheme cluster). */
    function nextBoundary(offset:Int):Int {
        final text = new Utf8Text(content);
        for (i in 0...text.count) {
            if (text.byteOffsets[i] > offset) {
                return text.byteOffsets[i];
            }
        }
        return text.byteLength;
    }

    public function reset(window:Window, cx:Context<Dynamic>):Void {
        content = '';
        selectedRange = new Range(0, 0);
        selectionReversed = false;
        markedRange = null;
        lastLayout = null;
        lastBounds = null;
        isSelecting = false;
        window.notifyTextInputChanged(focusHandle);
        cx.notify();
    }

    static function utf16Length(text:String):Int {
        final decoded = new Utf8Text(text);
        var count = 0;
        for (i in 0...decoded.count) {
            count += Utf8.utf16Length(decoded.codePoints[i]);
        }
        return count;
    }

/// EntityInputHandler

    public function textForRange(rangeUtf16:Range, actualRange:Ref<Null<Range>>, window:Window, cx:Context<Dynamic>):Null<String> {
        final range = rangeFromUtf16(rangeUtf16);
        actualRange.value = rangeToUtf16(range);
        return Utf8.substring(content, range.start, range.end);
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:Context<Dynamic>):Null<UTF16Selection> {
        return new UTF16Selection(rangeToUtf16(selectedRange), selectionReversed);
    }

    public function setSelectedTextRange(rangeUtf16:Range, window:Window, cx:Context<Dynamic>):Void {
        selectedRange = rangeFromUtf16(rangeUtf16);
        selectionReversed = false;
        window.notifyTextSelectionChanged(focusHandle);
        cx.notify();
    }

    public function textLengthUtf16(window:Window, cx:Context<Dynamic>):Null<Int> {
        return utf16Length(content);
    }

    public function markedTextRange(window:Window, cx:Context<Dynamic>):Null<Range> {
        return markedRange != null ? rangeToUtf16(markedRange) : null;
    }

    public function unmarkText(window:Window, cx:Context<Dynamic>):Void {
        markedRange = null;
        window.notifyTextInputChanged(focusHandle);
        cx.notify();
    }

    public function replaceTextInRange(rangeUtf16:Null<Range>, newText:String, window:Window, cx:Context<Dynamic>):Void {
        final range = rangeUtf16 != null ? rangeFromUtf16(rangeUtf16) : (markedRange != null ? markedRange : selectedRange);

        content = Utf8.substring(content, 0, range.start) + newText + Utf8.substringFrom(content, range.end);
        final newLen = Utf8.byteLength(newText);
        selectedRange = new Range(range.start + newLen, range.start + newLen);
        selectionReversed = false;
        markedRange = null;
        window.notifyTextInputChanged(focusHandle);
        cx.notify();
    }

    public function replaceAndMarkTextInRange(rangeUtf16:Null<Range>, newText:String, newSelectedRangeUtf16:Null<Range>, window:Window, cx:Context<Dynamic>):Void {
        final range = rangeUtf16 != null ? rangeFromUtf16(rangeUtf16) : (markedRange != null ? markedRange : selectedRange);

        content = Utf8.substring(content, 0, range.start) + newText + Utf8.substringFrom(content, range.end);
        final newLen = Utf8.byteLength(newText);
        if (newText.length > 0) {
            markedRange = new Range(range.start, range.start + newLen);
        }
        else {
            markedRange = null;
        }
        final insertionStartUtf16 = offsetToUtf16(range.start);
        final insertedLengthUtf16 = utf16Length(newText);
        if (newSelectedRangeUtf16 != null) {
            selectedRange = rangeFromUtf16(new Range(
                insertionStartUtf16 + (newSelectedRangeUtf16.start < insertedLengthUtf16 ? newSelectedRangeUtf16.start : insertedLengthUtf16),
                insertionStartUtf16 + (newSelectedRangeUtf16.end < insertedLengthUtf16 ? newSelectedRangeUtf16.end : insertedLengthUtf16)
            ));
        }
        else {
            selectedRange = new Range(range.start + newLen, range.start + newLen);
        }
        selectionReversed = false;

        window.notifyTextInputChanged(focusHandle);
        cx.notify();
    }

    public function boundsForRange(rangeUtf16:Range, bounds:Bounds, window:Window, cx:Context<Dynamic>):Null<Bounds> {
        final layout = lastLayout;
        if (layout == null || layout.text != content) {
            return null;
        }
        final range = rangeFromUtf16(rangeUtf16);
        return Bounds.fromCorners(
            point(bounds.left() + layout.xForIndex(range.start), bounds.top()),
            point(bounds.left() + layout.xForIndex(range.end), bounds.bottom())
        );
    }

    public function selectionBoundsForRange(rangeUtf16:Range, bounds:Bounds, window:Window, cx:Context<Dynamic>):Array<Bounds> {
        final result = boundsForRange(rangeUtf16, bounds, window, cx);
        return result != null ? [result] : [];
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:Context<Dynamic>):Null<Int> {
        if (lastBounds == null) {
            return null;
        }
        final linePoint = lastBounds.localize(point);
        if (linePoint == null) {
            return null;
        }
        final layout = lastLayout;
        if (layout == null || layout.text != content) {
            return null;
        }
        final utf8Index = layout.closestIndexForX(linePoint.x);
        return offsetToUtf16(utf8Index);
    }

/// Render

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<TextInput> = cast cx;
        return div()
            .flex()
            .keyContext('TextInput')
            .trackFocus(focusHandle)
            .cursor(CursorStyle.IBeam)
            .onAction(Backspace, cx.listener((input:TextInput, action:Backspace, window, cx) -> input.backspace(action, window, cx)))
            .onAction(Delete, cx.listener((input:TextInput, action:Delete, window, cx) -> input.delete(action, window, cx)))
            .onAction(Left, cx.listener((input:TextInput, action:Left, window, cx) -> input.left(action, window, cx)))
            .onAction(Right, cx.listener((input:TextInput, action:Right, window, cx) -> input.right(action, window, cx)))
            .onAction(SelectLeft, cx.listener((input:TextInput, action:SelectLeft, window, cx) -> input.selectLeft(action, window, cx)))
            .onAction(SelectRight, cx.listener((input:TextInput, action:SelectRight, window, cx) -> input.selectRight(action, window, cx)))
            .onAction(SelectAll, cx.listener((input:TextInput, action:SelectAll, window, cx) -> input.selectAll(action, window, cx)))
            .onAction(Home, cx.listener((input:TextInput, action:Home, window, cx) -> input.home(action, window, cx)))
            .onAction(End, cx.listener((input:TextInput, action:End, window, cx) -> input.end(action, window, cx)))
            .onAction(ShowCharacterPalette, cx.listener((input:TextInput, action:ShowCharacterPalette, window, cx) -> input.showCharacterPalette(action, window, cx)))
            .onAction(Paste, cx.listener((input:TextInput, action:Paste, window, cx) -> input.pasteAction(action, window, cx)))
            .onAction(Cut, cx.listener((input:TextInput, action:Cut, window, cx) -> input.cut(action, window, cx)))
            .onAction(Copy, cx.listener((input:TextInput, action:Copy, window, cx) -> input.copy(action, window, cx)))
            .onMouseDown(glaze.MouseButton.Left, cx.listener((input:TextInput, event:MouseDownEvent, window, cx) -> input.onMouseDown(event, window, cx)))
            .onMouseUp(glaze.MouseButton.Left, cx.listener((input:TextInput, event:MouseUpEvent, window, cx) -> input.onMouseUp(event, window, cx)))
            .onMouseUpOut(glaze.MouseButton.Left, cx.listener((input:TextInput, event:MouseUpEvent, window, cx) -> input.onMouseUp(event, window, cx)))
            .onMouseMove(cx.listener((input:TextInput, event:MouseMoveEvent, window, cx) -> input.onMouseMove(event, window, cx)))
            .bg(rgb(0xeeeeee))
            .lineHeight(px(30))
            .textSize(px(24))
            .child(
                div()
                    .h(px(30 + 4 * 2))
                    .wFull()
                    .p(px(4))
                    .bg(white())
                    .child(new TextElement(cx.entity()))
            );
    }

}

/**
 * Lays out, paints and registers the input handler of a `TextInput`.
 */
class TextElement extends Element {

    final input:Entity<TextInput>;

    var line:Null<ShapedLine> = null;

    var cursor:Null<PaintQuad> = null;

    var selection:Null<PaintQuad> = null;

    public function new(input:Entity<TextInput>) {
        this.input = input;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.sizeWidth = glaze.Length.Definite(relative(1));
        style.sizeHeight = glaze.Length.Definite(glaze.DefiniteLength.Absolute(glaze.AbsoluteLength.Pixels(window.lineHeight())));
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final input = this.input.read(cx);
        final content = input.content;
        final selectedRange = input.selectedRange;
        final cursor = input.cursorOffset();
        final style = window.textStyle();

        final displayText = content.length == 0 ? input.placeholder : content;
        final textColor = content.length == 0 ? hsla(0, 0, 0, 0.2) : style.color;

        final displayLen = Utf8.byteLength(displayText);
        final runs:Array<TextRun> = [];
        final markedRange = input.markedRange;
        if (markedRange != null) {
            final before = new TextRun(markedRange.start, style.font(), textColor);
            final marked = new TextRun(markedRange.end - markedRange.start, style.font(), textColor, null, new UnderlineStyle(px(1), textColor, false));
            final after = new TextRun(displayLen - markedRange.end, style.font(), textColor);
            for (run in [before, marked, after]) {
                if (run.len > 0) runs.push(run);
            }
        }
        else {
            runs.push(new TextRun(displayLen, style.font(), textColor));
        }

        final fontSize = glaze.AbsoluteLengthTools.toPixels(style.fontSize, window.remSize());
        final line = window.textSystem().shapeLine(displayText, fontSize, runs);

        final cursorPos = line.xForIndex(cursor);
        if (selectedRange.isEmpty()) {
            this.selection = null;
            this.cursor = fill(
                new Bounds(point(bounds.left() + cursorPos, bounds.top()), size(px(2), bounds.bottom() - bounds.top())),
                blue()
            );
        }
        else {
            this.selection = fill(
                Bounds.fromCorners(
                    point(bounds.left() + line.xForIndex(selectedRange.start), bounds.top()),
                    point(bounds.left() + line.xForIndex(selectedRange.end), bounds.bottom())
                ),
                rgba(0x3311ff30)
            );
            this.cursor = null;
        }
        this.line = line;
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final focusHandle = this.input.read(cx).focusHandle;
        window.handleInput(focusHandle, new ElementInputHandler(bounds, this.input), cx);
        if (selection != null) {
            window.paintQuad(selection);
            selection = null;
        }
        final line = this.line;
        this.line = null;
        line.paint(bounds.origin, window.lineHeight(), glaze.TextAlign.Left, null, window.textPainter());

        if (focusHandle.isFocused(window) && cursor != null) {
            window.paintQuad(cursor);
            cursor = null;
        }

        this.input.update(cx, (input, _) -> {
            input.lastLayout = line;
            input.lastBounds = bounds;
        });
    }

}
