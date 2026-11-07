// Text field adapted from gpui-pre 0.3.10: examples/input.rs, as in reference/src/text_input.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import glaze.Action;
import glaze.App;
import glaze.Bounds;
import glaze.ClipboardItem;
import glaze.Context;
import glaze.ElementInputHandler;
import glaze.Entity;
import glaze.EntityInputHandler;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.KeyDownEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.TestClipboard;
import glaze.TestDispatcher;
import glaze.TextInputBridge;
import glaze.UTF16Selection;
import glaze.Window;
import glaze.util.MathUtil;
import glaze.util.Ref;
import glaze.util.Utf8;
import glaze.util.Utf8.Utf8Text;
import testing.GlazeTruth;
import testing.InteractionScript;
import testing.TestCase;

import glaze.Prelude.*;
import testing.InteractionScript.f;
import testing.InteractionScript.keystroke;

@:action(namespace = text_input_test) class InputBackspace implements Action {}
@:action(namespace = text_input_test) class InputDelete implements Action {}
@:action(namespace = text_input_test) class InputLeft implements Action {}
@:action(namespace = text_input_test) class InputRight implements Action {}
@:action(namespace = text_input_test) class InputSelectLeft implements Action {}
@:action(namespace = text_input_test) class InputSelectRight implements Action {}
@:action(namespace = text_input_test) class InputSelectAll implements Action {}
@:action(namespace = text_input_test) class InputHome implements Action {}
@:action(namespace = text_input_test) class InputEnd implements Action {}
@:action(namespace = text_input_test) class InputPaste implements Action {}
@:action(namespace = text_input_test) class InputCut implements Action {}
@:action(namespace = text_input_test) class InputCopy implements Action {}
@:action(namespace = text_input_test) class InputPercent implements Action {}
@:action(namespace = text_input_test) class InputBang implements Action {}
@:action(namespace = text_input_test) class InputJK implements Action {}
@:action(namespace = text_input_test) class InputAltA implements Action {}

/**
 * Replays the `text-input` behaviour of the reference harness
 * (`reference/src/text_input.rs`) on the port and requires the exact log of
 * the original GPUI (`test/golden/gpui/text-input.json`): every
 * `EntityInputHandler` call with its UTF-16 ranges, text and result, for
 * typing, non-ASCII commits, consumed / propagated / multi-stroke / AltGr
 * bindings, IME composition, selection replace, clipboard and mouse selection.
 *
 * Platform text input goes through the real Ceramic bridge
 * (`glaze.TextInputBridge`), fed with the events Ceramic would send: the key
 * down, then the key's character as a text commit (unless composing), and
 * compositions (an empty composition followed by a commit for an IME commit,
 * or by the end of the batch for a cancel). The Rust harness emulates the
 * same platform layer on GPUI's real windows (see the module documentation
 * of `text_input.rs`).
 */
class TextInputBehaviourTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var script:Null<InteractionScript> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = InteractionScript.testApp(dispatcher);
        app.platformClipboard = new TestClipboard();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (script != null) {
            script.destroy();
            script = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function compare(id:String, expectedJson:String, actual:Array<String>):Void {
        final expected:Array<String> = haxe.Json.parse(expectedJson).log;
        var firstDifference = -1;
        for (i in 0...Std.int(Math.max(expected.length, actual.length))) {
            if (expected[i] != actual[i]) {
                firstDifference = i;
                break;
            }
        }
        if (firstDifference != -1) {
            final from = Std.int(Math.max(0, firstDifference - 3));
            final context = [for (i in from...firstDifference + 4) '$i: gpui=${expected[i]} | port=${actual[i]}'].join('\n');
            fail('$id: logs differ at line $firstDifference\n$context');
        }
        assertEquals(expected.length, actual.length, '$id log length');
    }

    function testTextInputMatchesGpui() {
        app.bindKeys([
            new KeyBinding('backspace', new InputBackspace(), 'TextInput'),
            new KeyBinding('delete', new InputDelete(), 'TextInput'),
            new KeyBinding('left', new InputLeft(), 'TextInput'),
            new KeyBinding('right', new InputRight(), 'TextInput'),
            new KeyBinding('shift-left', new InputSelectLeft(), 'TextInput'),
            new KeyBinding('shift-right', new InputSelectRight(), 'TextInput'),
            new KeyBinding('cmd-a', new InputSelectAll(), 'TextInput'),
            new KeyBinding('cmd-v', new InputPaste(), 'TextInput'),
            new KeyBinding('cmd-c', new InputCopy(), 'TextInput'),
            new KeyBinding('cmd-x', new InputCut(), 'TextInput'),
            new KeyBinding('home', new InputHome(), 'TextInput'),
            new KeyBinding('end', new InputEnd(), 'TextInput'),
            new KeyBinding('%', new InputPercent(), 'TextInput'),
            new KeyBinding('!', new InputBang(), 'TextInput'),
            new KeyBinding('j k', new InputJK(), 'TextInput'),
            new KeyBinding('ctrl-alt-a', new InputAltA(), 'TextInput'),
        ]);
        final log:Array<String> = [];
        final focus = app.focusHandle();
        var bridge:Null<TestBridge> = null;
        final opened = InteractionScript.open(app, dispatcher, log, (window, cx:Context<LogTextInput>) -> {
            bridge = new TestBridge(window);
            window.textInputPlatform = bridge;
            return new LogTextInput(log, focus);
        });
        script = opened.script;
        final s = opened.script;
        final view = opened.view;
        final b:TestBridge = bridge;

        s.setState((window, cx) -> {
            final input = view.read(cx);
            final keys = window.pendingInputKeystrokes();
            final pending = keys != null ? [for (k in keys) keystroke(k)].join(' ') : 'none';
            log.push('state text="${input.content}" selected=${input.selectedRange} reversed=${input.selectionReversed} marked=${Range.describe(input.markedRange)} handler=${window.peekInputHandler() != null ? 'yes' : 'no'} pending=$pending');
        });

        // The platform steps (see `text_input.rs`)
        function platformKey(ks:String, preferCharacterInput:Bool = false, ?keyChar:String) {
            var keystroke = Keystroke.parse(ks).withSimulatedIme();
            if (keyChar != null) {
                keystroke = new Keystroke(keystroke.modifiers, keystroke.key, keyChar);
            }
            final composing = b.composing;
            s.step((preferCharacterInput ? 'platform_altgr ' : 'platform_key ') + ks, (_, _) -> {
                b.keyDown(new KeyDownEvent(keystroke, false, preferCharacterInput));
                // Ceramic then commits the character of a text key (the IME owns the keys while composing)
                final m = keystroke.modifiers;
                if (!composing && keystroke.keyChar != null && !m.platform && (!m.control || m.alt)) {
                    b.textCommit(keystroke.keyChar);
                }
                b.flush();
            });
        }
        function commit(text:String) {
            s.step('commit "$text"', (_, _) -> {
                b.textCommit(text);
                b.flush();
            });
        }
        function imeCompose(text:String, start:Int, len:Int) {
            s.step('ime_compose "$text" $start $len', (_, _) -> {
                b.textComposition(text, start, len);
                b.flush();
            });
        }
        function imeCommit(text:String) {
            s.step('ime_commit "$text"', (_, _) -> {
                b.textComposition('', 0, 0);
                b.textCommit(text);
                b.flush();
            });
        }
        function imeCancel() {
            s.step('ime_cancel', (_, _) -> {
                b.textComposition('', 0, 0);
                b.flush();
            });
        }
        function platformPaste(text:String) {
            s.step('platform_paste "$text"', (_, _) -> b.paste(ClipboardItem.newString(text)));
        }
        function query(range:Range, x:Float, y:Float) {
            s.step('query $range ${f(x)} ${f(y)}', (window, _) -> {
                final h = window.peekInputHandler();
                if (h == null)
                    return;
                h.selectedTextRange(false);
                h.markedTextRange();
                h.textLengthUtf16();
                h.textForRange(range, new Ref<Null<Range>>(null));
                h.boundsForRange(range);
                h.selectionBoundsForRange(range);
                h.characterIndexForPoint(new Point(x, y));
                log.push('element_bounds -> ${LogTextInput.optBounds(h.elementBounds())}');
                log.push('ime_candidate_bounds -> ${LogTextInput.optBounds(h.imeCandidateBounds())}');
            });
        }
        function clipboardLine(cx:App):String {
            final item = cx.readFromClipboard();
            final text = item != null ? item.text() : null;
            final metadata = item != null ? item.metadata() : null;
            return 'clipboard text=' + (text != null ? '"' + StringTools.replace(text, '\n', '\\n') + '"' : 'None')
                + ' metadata=' + (metadata != null ? '"$metadata"' : 'None');
        }

        // Not focused: no input handler, typing goes nowhere
        platformKey('a');
        commit('z');
        s.step('focus input', (window, cx) -> window.focus(focus, cx));

        // ASCII typing through the platform (key down, then the key char)
        platformKey('a');
        platformKey('b');
        platformKey('space');
        // Through the test platform: dispatchKeystroke inserts the key char itself
        s.key('c');
        // Non-ASCII commits: accented, emoji (surrogate pair), CJK
        commit('é');
        commit('🙂');
        commit('漢字');
        query(new Range(1, 5), 85.0, 30.0);

        // Bindings: consumed (%), propagated (!), multi-stroke (j k), AltGr
        platformKey('%');
        platformKey('!');
        platformKey('j');
        platformKey('k');
        platformKey('j');
        platformKey('x');
        platformKey('j');
        s.advance(1000);
        platformKey('ctrl-alt-a', true, 'ą');
        platformKey('ctrl-alt-a', false, 'ą');

        // Cursor moves and selection replace
        platformKey('left');
        platformKey('left');
        platformKey('shift-left');
        platformKey('shift-left');
        query(new Range(0, 3), 20.0, 35.0);
        commit('Z');
        platformKey('backspace');
        platformKey('home');
        platformKey('backspace');
        platformKey('end');

        // IME composition: start, update, commit
        imeCompose('k', 1, 0);
        imeCompose('か', 1, 0);
        // Keys go to the IME while composing
        platformKey('n');
        imeCompose('かん', 2, 0);
        imeCompose('漢字', 0, 2);
        query(new Range(0, 2), 200.0, 35.0);
        imeCommit('漢字');
        // Composition replacing a selection, then cancelled
        platformKey('shift-left');
        imeCompose('x', 1, 0);
        imeCompose('🙂y', 2, 0);
        query(new Range(0, 1), 0.0, 0.0);
        imeCancel();

        // Clipboard: select all, copy, paste at the end, cut
        platformKey('cmd-a');
        platformKey('cmd-c');
        s.step('read clipboard', (_, cx) -> log.push(clipboardLine(cx)));
        platformKey('end');
        platformKey('cmd-v');
        platformKey('shift-left');
        platformKey('shift-left');
        platformKey('cmd-x');
        platformKey('home');
        platformKey('cmd-v');
        s.step('write clipboard with metadata', (_, cx) -> {
            cx.writeToClipboard(ClipboardItem.newStringWithMetadata('line1\nline2', '{"kind":"test"}'));
            log.push(clipboardLine(cx));
        });
        platformKey('cmd-v');
        platformPaste('P');

        // Mouse selection: press at char 4, drag to char 9, back to char 0, release
        s.moveTo(60.0, 35.0);
        s.down(Left, 60.0, 35.0, 1);
        s.moveTo(110.0, 35.0);
        s.moveTo(15.0, 35.0);
        s.up(Left, 15.0, 35.0, 1);
        commit('M');

        // Blur: the handler is gone, text input is ignored
        s.step('blur', (window, cx) -> window.blur(cx));
        platformKey('q');
        commit('w');
        s.key('e');

        compare('text-input', GlazeTruth.load('text-input.json'), log);
    }

}

/**
 * The Ceramic bridge without Ceramic: text editing and IME area updates are
 * not sent anywhere (they would only call the input handler for the IME
 * position, outside of GPUI's log).
 */
private class TestBridge extends TextInputBridge {

    override function startEditing(bounds:Bounds):Void {}

    override function stopEditing():Void {}

    override function setEditingArea(bounds:Bounds):Void {}

    override function scheduleImeUpdate():Void {}

}

/**
 * The text field of `reference/src/text_input.rs`: GPUI's `examples/input.rs`
 * `TextInput` with logging and fixed width characters (`CHAR_WIDTH`).
 */
private class LogTextInput extends Model implements Render implements EntityInputHandler {

    public static inline final CHAR_WIDTH:Float = 10.0;

    final log:Array<String>;

    public final focusHandle:FocusHandle;

    public var content:String = '';

    public var selectedRange:Range = new Range(0, 0);

    public var selectionReversed:Bool = false;

    public var markedRange:Null<Range> = null;

    public var lastBounds:Null<Bounds> = null;

    var isSelecting:Bool = false;

    public function new(log:Array<String>, focusHandle:FocusHandle) {
        super();
        this.log = log;
        this.focusHandle = focusHandle;
    }

    public static function bounds(b:Bounds):String {
        return '${f(b.origin.x)} ${f(b.origin.y)} ${f(b.size.width)} ${f(b.size.height)}';
    }

    public static function optBounds(b:Null<Bounds>):String {
        return b != null ? bounds(b) : 'None';
    }

    static function sel(selection:Null<UTF16Selection>):String {
        return selection != null ? '${selection.range} reversed=${selection.reversed}' : 'None';
    }

    function contentState():String {
        return 'content="$content" selected=$selectedRange reversed=$selectionReversed marked=${Range.describe(markedRange)}';
    }

    function len():Int {
        return Utf8.byteLength(content);
    }

/// Actions

    function left(window:Window, cx:Context<Dynamic>):Void {
        log.push('action left');
        if (selectedRange.isEmpty()) {
            moveTo(previousBoundary(cursorOffset()), window, cx);
        }
        else {
            moveTo(selectedRange.start, window, cx);
        }
    }

    function right(window:Window, cx:Context<Dynamic>):Void {
        log.push('action right');
        if (selectedRange.isEmpty()) {
            moveTo(nextBoundary(selectedRange.end), window, cx);
        }
        else {
            moveTo(selectedRange.end, window, cx);
        }
    }

    function selectLeft(window:Window, cx:Context<Dynamic>):Void {
        log.push('action select_left');
        selectTo(previousBoundary(cursorOffset()), window, cx);
    }

    function selectRight(window:Window, cx:Context<Dynamic>):Void {
        log.push('action select_right');
        selectTo(nextBoundary(cursorOffset()), window, cx);
    }

    function selectAll(window:Window, cx:Context<Dynamic>):Void {
        log.push('action select_all');
        moveTo(0, window, cx);
        selectTo(len(), window, cx);
    }

    function home(window:Window, cx:Context<Dynamic>):Void {
        log.push('action home');
        moveTo(0, window, cx);
    }

    function end(window:Window, cx:Context<Dynamic>):Void {
        log.push('action end');
        moveTo(len(), window, cx);
    }

    function backspace(window:Window, cx:Context<Dynamic>):Void {
        log.push('action backspace');
        if (selectedRange.isEmpty()) {
            final prev = previousBoundary(cursorOffset());
            if (cursorOffset() == prev) {
                log.push('bell');
                window.playSystemBell();
                return;
            }
            selectTo(prev, window, cx);
        }
        replaceTextInRange(null, '', window, cx);
    }

    function delete(window:Window, cx:Context<Dynamic>):Void {
        log.push('action delete');
        if (selectedRange.isEmpty()) {
            final next = nextBoundary(cursorOffset());
            if (cursorOffset() == next) {
                log.push('bell');
                window.playSystemBell();
                return;
            }
            selectTo(next, window, cx);
        }
        replaceTextInRange(null, '', window, cx);
    }

    function onMouseDown(event:MouseDownEvent, window:Window, cx:Context<Dynamic>):Void {
        isSelecting = true;
        window.requestVirtualKeyboard();
        final index = indexForMousePosition(event.position);
        log.push('mouse_down index=$index');
        if (event.modifiers.shift) {
            selectTo(index, window, cx);
        }
        else {
            moveTo(index, window, cx);
        }
    }

    function onMouseUp():Void {
        log.push('mouse_up');
        isSelecting = false;
    }

    function onMouseMove(event:MouseMoveEvent, window:Window, cx:Context<Dynamic>):Void {
        if (isSelecting) {
            final index = indexForMousePosition(event.position);
            log.push('mouse_move select index=$index');
            selectTo(index, window, cx);
        }
    }

    function pasteAction(window:Window, cx:Context<Dynamic>):Void {
        log.push('action paste');
        final item = cx.readFromClipboard();
        final text = item != null ? item.text() : null;
        if (text != null) {
            replaceTextInRange(null, StringTools.replace(text, '\n', ' '), window, cx);
        }
    }

    function copy(cx:Context<Dynamic>):Void {
        log.push('action copy');
        if (!selectedRange.isEmpty()) {
            cx.writeToClipboard(ClipboardItem.newString(Utf8.substring(content, selectedRange.start, selectedRange.end)));
        }
    }

    function cut(window:Window, cx:Context<Dynamic>):Void {
        log.push('action cut');
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

    function cursorOffset():Int {
        return selectionReversed ? selectedRange.start : selectedRange.end;
    }

    function indexForMousePosition(position:Point):Int {
        if (content.length == 0) {
            return 0;
        }
        final bounds = lastBounds;
        if (bounds == null) {
            return 0;
        }
        if (position.y < bounds.top()) {
            return 0;
        }
        if (position.y > bounds.bottom()) {
            return len();
        }
        return closestIndexForX(position.x - bounds.left());
    }

    function closestIndexForX(x:Float):Int {
        final text = new Utf8Text(content);
        var ix = Std.int(Math.max(0, MathUtil.round(x / CHAR_WIDTH)));
        if (ix > text.count) ix = text.count;
        return ix < text.count ? text.byteOffsets[ix] : text.byteLength;
    }

    function xForIndex(offset:Int):Float {
        final text = new Utf8Text(content);
        var chars = 0;
        for (i in 0...text.count) {
            if (text.byteOffsets[i] < offset) chars++;
        }
        return chars * CHAR_WIDTH;
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

    function offsetFromUtf16(offset:Int):Int {
        var utf8Offset = 0;
        var utf16Count = 0;
        final text = new Utf8Text(content);
        for (i in 0...text.count) {
            if (utf16Count >= offset) break;
            utf16Count += Utf8.utf16Length(text.codePoints[i]);
            utf8Offset += Utf8.codePointLength(text.codePoints[i]);
        }
        return utf8Offset;
    }

    function offsetToUtf16(offset:Int):Int {
        var utf16Offset = 0;
        var utf8Count = 0;
        final text = new Utf8Text(content);
        for (i in 0...text.count) {
            if (utf8Count >= offset) break;
            utf8Count += Utf8.codePointLength(text.codePoints[i]);
            utf16Offset += Utf8.utf16Length(text.codePoints[i]);
        }
        return utf16Offset;
    }

    function rangeToUtf16(range:Range):Range {
        return new Range(offsetToUtf16(range.start), offsetToUtf16(range.end));
    }

    function rangeFromUtf16(range:Range):Range {
        return new Range(offsetFromUtf16(range.start), offsetFromUtf16(range.end));
    }

    function previousBoundary(offset:Int):Int {
        final text = new Utf8Text(content);
        var i = text.count - 1;
        while (i >= 0) {
            if (text.byteOffsets[i] < offset) return text.byteOffsets[i];
            i--;
        }
        return 0;
    }

    function nextBoundary(offset:Int):Int {
        final text = new Utf8Text(content);
        for (i in 0...text.count) {
            if (text.byteOffsets[i] > offset) return text.byteOffsets[i];
        }
        return text.byteLength;
    }

    static function utf16Length(text:String):Int {
        final decoded = new Utf8Text(text);
        var count = 0;
        for (i in 0...decoded.count) count += Utf8.utf16Length(decoded.codePoints[i]);
        return count;
    }

/// EntityInputHandler

    public function textForRange(rangeUtf16:Range, actualRange:Ref<Null<Range>>, window:Window, cx:Context<Dynamic>):Null<String> {
        final range = rangeFromUtf16(rangeUtf16);
        actualRange.value = rangeToUtf16(range);
        final text = Utf8.substring(content, range.start, range.end);
        log.push('text_for_range $rangeUtf16 -> "$text" adjusted=${Range.describe(actualRange.value)}');
        return text;
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:Context<Dynamic>):Null<UTF16Selection> {
        final selection = new UTF16Selection(rangeToUtf16(selectedRange), selectionReversed);
        log.push('selected_text_range ignore_disabled_input=$ignoreDisabledInput -> ${sel(selection)}');
        return selection;
    }

    public function setSelectedTextRange(rangeUtf16:Range, window:Window, cx:Context<Dynamic>):Void {
        selectedRange = rangeFromUtf16(rangeUtf16);
        selectionReversed = false;
        log.push('set_selected_text_range $rangeUtf16 -> ${contentState()}');
        window.notifyTextSelectionChanged(focusHandle);
        cx.notify();
    }

    public function textLengthUtf16(window:Window, cx:Context<Dynamic>):Null<Int> {
        final length = utf16Length(content);
        log.push('text_length_utf16 -> $length');
        return length;
    }

    public function markedTextRange(window:Window, cx:Context<Dynamic>):Null<Range> {
        final range = markedRange != null ? rangeToUtf16(markedRange) : null;
        log.push('marked_text_range -> ${Range.describe(range)}');
        return range;
    }

    public function unmarkText(window:Window, cx:Context<Dynamic>):Void {
        markedRange = null;
        log.push('unmark_text -> ${contentState()}');
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
        log.push('replace_text_in_range ${Range.describe(rangeUtf16)} "$newText" -> ${contentState()}');
        window.notifyTextInputChanged(focusHandle);
        cx.notify();
    }

    public function replaceAndMarkTextInRange(rangeUtf16:Null<Range>, newText:String, newSelectedRangeUtf16:Null<Range>, window:Window, cx:Context<Dynamic>):Void {
        final range = rangeUtf16 != null ? rangeFromUtf16(rangeUtf16) : (markedRange != null ? markedRange : selectedRange);
        content = Utf8.substring(content, 0, range.start) + newText + Utf8.substringFrom(content, range.end);
        final newLen = Utf8.byteLength(newText);
        markedRange = newText.length > 0 ? new Range(range.start, range.start + newLen) : null;
        final insertionStartUtf16 = offsetToUtf16(range.start);
        final insertedLengthUtf16 = utf16Length(newText);
        if (newSelectedRangeUtf16 != null) {
            selectedRange = rangeFromUtf16(new Range(
                insertionStartUtf16 + Std.int(Math.min(newSelectedRangeUtf16.start, insertedLengthUtf16)),
                insertionStartUtf16 + Std.int(Math.min(newSelectedRangeUtf16.end, insertedLengthUtf16))
            ));
        }
        else {
            selectedRange = new Range(range.start + newLen, range.start + newLen);
        }
        selectionReversed = false;
        log.push('replace_and_mark_text_in_range ${Range.describe(rangeUtf16)} "$newText" ${Range.describe(newSelectedRangeUtf16)} -> ${contentState()}');
        window.notifyTextInputChanged(focusHandle);
        cx.notify();
    }

    public function boundsForRange(rangeUtf16:Range, bounds:Bounds, window:Window, cx:Context<Dynamic>):Null<Bounds> {
        var result:Null<Bounds> = null;
        if (lastBounds != null) {
            final range = rangeFromUtf16(rangeUtf16);
            result = Bounds.fromCorners(
                new Point(bounds.left() + xForIndex(range.start), bounds.top()),
                new Point(bounds.left() + xForIndex(range.end), bounds.bottom())
            );
        }
        log.push('bounds_for_range $rangeUtf16 element=${LogTextInput.bounds(bounds)} -> ${optBounds(result)}');
        return result;
    }

    public function selectionBoundsForRange(rangeUtf16:Range, bounds:Bounds, window:Window, cx:Context<Dynamic>):Array<Bounds> {
        log.push('selection_bounds_for_range $rangeUtf16');
        final result = boundsForRange(rangeUtf16, bounds, window, cx);
        return result != null ? [result] : [];
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:Context<Dynamic>):Null<Int> {
        var result:Null<Int> = null;
        if (lastBounds != null) {
            final linePoint = lastBounds.localize(point);
            if (linePoint != null) {
                result = offsetToUtf16(closestIndexForX(linePoint.x));
            }
        }
        log.push('character_index_for_point ${f(point.x)} ${f(point.y)} -> ${result != null ? Std.string(result) : 'None'}');
        return result;
    }

/// Render

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<LogTextInput> = cast cx;
        final view = cx.entity();
        final focusHandle = this.focusHandle;
        return div().sizeFull().relative().bg(hsla(0.61, 0.20, 0.13, 1.0)).child(
            div()
                .id('input')
                .absolute()
                .left(px(20))
                .top(px(20))
                .w(px(300))
                .h(px(30))
                .bg(hsla(0.0, 0.0, 0.93, 1.0))
                .keyContext('TextInput')
                .trackFocus(focusHandle)
                .onAction(InputBackspace, cx.listener((input:LogTextInput, _:InputBackspace, window, cx) -> input.backspace(window, cx)))
                .onAction(InputDelete, cx.listener((input:LogTextInput, _:InputDelete, window, cx) -> input.delete(window, cx)))
                .onAction(InputLeft, cx.listener((input:LogTextInput, _:InputLeft, window, cx) -> input.left(window, cx)))
                .onAction(InputRight, cx.listener((input:LogTextInput, _:InputRight, window, cx) -> input.right(window, cx)))
                .onAction(InputSelectLeft, cx.listener((input:LogTextInput, _:InputSelectLeft, window, cx) -> input.selectLeft(window, cx)))
                .onAction(InputSelectRight, cx.listener((input:LogTextInput, _:InputSelectRight, window, cx) -> input.selectRight(window, cx)))
                .onAction(InputSelectAll, cx.listener((input:LogTextInput, _:InputSelectAll, window, cx) -> input.selectAll(window, cx)))
                .onAction(InputHome, cx.listener((input:LogTextInput, _:InputHome, window, cx) -> input.home(window, cx)))
                .onAction(InputEnd, cx.listener((input:LogTextInput, _:InputEnd, window, cx) -> input.end(window, cx)))
                .onAction(InputPaste, cx.listener((input:LogTextInput, _:InputPaste, window, cx) -> input.pasteAction(window, cx)))
                .onAction(InputCut, cx.listener((input:LogTextInput, _:InputCut, window, cx) -> input.cut(window, cx)))
                .onAction(InputCopy, cx.listener((input:LogTextInput, _:InputCopy, window, cx) -> input.copy(cx)))
                .onAction(InputPercent, cx.listener((input:LogTextInput, _:InputPercent, window, cx) -> log.push('action percent')))
                .onAction(InputBang, cx.listener((input:LogTextInput, _:InputBang, window, cx) -> {
                    log.push('action bang propagate');
                    cx.app.propagate();
                }))
                .onAction(InputJK, cx.listener((input:LogTextInput, _:InputJK, window, cx) -> log.push('action jk')))
                .onAction(InputAltA, cx.listener((input:LogTextInput, _:InputAltA, window, cx) -> log.push('action alt_a')))
                .onMouseDown(MouseButton.Left, cx.listener((input:LogTextInput, event:MouseDownEvent, window, cx) -> input.onMouseDown(event, window, cx)))
                .onMouseUp(MouseButton.Left, cx.listener((input:LogTextInput, _:MouseUpEvent, window, cx) -> input.onMouseUp()))
                .onMouseUpOut(MouseButton.Left, cx.listener((input:LogTextInput, _:MouseUpEvent, window, cx) -> input.onMouseUp()))
                .onMouseMove(cx.listener((input:LogTextInput, event:MouseMoveEvent, window, cx) -> input.onMouseMove(event, window, cx)))
                .child(
                    canvas((_, _, _) -> 0, (bounds, _, window, cx) -> {
                        window.handleInput(focusHandle, new ElementInputHandler(bounds, view), cx);
                        view.update(cx, (input, _) -> input.lastBounds = bounds);
                    }).sizeFull()
                )
        );
    }

}
