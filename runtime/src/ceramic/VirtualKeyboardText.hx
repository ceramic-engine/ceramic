package ceramic;

/**
 * Turns the changes of the hidden text field behind a native virtual keyboard
 * (Unity's `TouchScreenKeyboard`) into editing operations: caret moves,
 * deletions, inserted text and line breaks. A backend gives them to the app
 * as key events (left, right, backspace, enter) and text commits, the way
 * SDL turns the edits of its hidden iOS text field into backspace keys and
 * text events.
 *
 * The field does not mirror the text of the app. It starts with `padding`
 * (spaces), so that a backspace always has something to delete, and every
 * change is applied relative to the caret the app is believed to have:
 *
 * - The common prefix and suffix of the previous and the new text delimit
 *   the replaced range (when the platform gives the new caret, the suffix
 *   stops there: with repeated characters, the edit is placed where the
 *   user made it). The caret moves to the end of that range, the
 *   removed graphemes are deleted backward, then the inserted text is given
 *   (line breaks apart). Autocorrection replacing a word before the caret
 *   works the same way.
 * - Without a text change, a moved caret (an empty selection) is a caret
 *   move. A non empty selection is not reported.
 * - `update()` asks for a reset (the field gets `padding` again) when the
 *   caret gets close to the start of the field (`minPadding`) or the field
 *   grows beyond `maxLength`.
 *
 * Counts of moves and deletions are in grapheme clusters, the unit of the
 * arrow and backspace keys of a text field (an approximation of Unicode's
 * extended grapheme clusters: combining marks, variation selectors, emoji
 * modifiers, ZWJ sequences, flags, CR LF). Positions are in UTF-16 code
 * units, the unit of the platform's selection.
 */
class VirtualKeyboardText {

    /** Length of `padding`, the text the field gets on `reset()`. */
    public static inline final PADDING_LENGTH:Int = 64;

    /** The text the field gets on `reset()`. */
    public final padding:String;

    /** A reset is asked for when the caret gets closer than this to the start of the field. */
    public var minPadding:Int = 8;

    /** A reset is asked for when the field holds more code units than this. */
    public var maxLength:Int = 1024;

    /** The text of the field, as last seen. */
    public var text(default, null):String;

    /** Where the caret of the app is believed to be, in UTF-16 code units of `text`. */
    public var caret(default, null):Int;

    /** The caret moves by a number of graphemes (negative: to the left). */
    public var onMove:Null<(graphemes:Int) -> Void> = null;

    /** Graphemes before the caret are deleted. */
    public var onDelete:Null<(graphemes:Int) -> Void> = null;

    /** Text is inserted at the caret (never contains line breaks). */
    public var onInsert:Null<(text:String) -> Void> = null;

    /** A line break is inserted at the caret. */
    public var onLineBreak:Null<() -> Void> = null;

    public function new() {

        final buf = new StringBuf();
        for (_ in 0...PADDING_LENGTH) buf.addChar(' '.code);
        padding = buf.toString();
        reset();

    }

    /**
     * Starts over: the field holds `padding` with the caret at its end.
     * Write `text` and `caret` to the field after calling it.
     */
    public function reset():Void {

        text = padding;
        caret = padding.length;

    }

    /**
     * The field now holds `newText`, with the given selection (UTF-16 code
     * units, `selectionStart` -1 when the platform does not tell). Calls the
     * handlers for what changed.
     * @return Whether the field should be reset (`reset()`, then write `text`
     *         and `caret` to the field)
     */
    public function update(newText:Null<String>, selectionStart:Int, selectionLength:Int):Bool {

        if (newText == null) return false;

        if (newText != text) {
            final oldText = text;
            final oldLength = oldText.length;
            final newLength = newText.length;
            final minLength = oldLength < newLength ? oldLength : newLength;

            var prefix = 0;
            var suffix = 0;
            if (selectionStart >= 0 && selectionLength == 0 && selectionStart <= newLength) {
                // The edit ends at the new caret: the common suffix stops
                // there, the prefix takes what is left (with repeated
                // characters, the edit is placed where the user made it)
                final maxSuffix = minLength < newLength - selectionStart ? minLength : newLength - selectionStart;
                suffix = commonSuffix(oldText, newText, maxSuffix);
                prefix = commonPrefix(oldText, newText, minLength - suffix);
            }
            else {
                prefix = commonPrefix(oldText, newText, minLength);
                suffix = commonSuffix(oldText, newText, minLength - prefix);
            }

            final removedEnd = oldLength - suffix;
            final insertedEnd = newLength - suffix;

            moveCaret(oldText, removedEnd);
            if (removedEnd > prefix) {
                final count = graphemeCount(oldText, prefix, removedEnd);
                if (count > 0 && onDelete != null) onDelete(count);
            }
            if (insertedEnd > prefix) {
                insert(newText.substring(prefix, insertedEnd));
            }

            text = newText;
            caret = insertedEnd;
        }

        if (selectionStart >= 0 && selectionLength == 0 && selectionStart <= text.length && selectionStart != caret) {
            moveCaret(text, selectionStart);
        }

        return caret < minPadding || text.length > maxLength;

    }

    /** Length of the common prefix (at most `max`), never splitting a surrogate pair. */
    static function commonPrefix(a:String, b:String, max:Int):Int {

        var n = 0;
        while (n < max && StringTools.fastCodeAt(a, n) == StringTools.fastCodeAt(b, n)) {
            n++;
        }
        if (n > 0 && isHighSurrogate(StringTools.fastCodeAt(a, n - 1))) {
            n--;
        }
        return n;

    }

    /** Length of the common suffix (at most `max`), never splitting a surrogate pair. */
    static function commonSuffix(a:String, b:String, max:Int):Int {

        final aLength = a.length;
        final bLength = b.length;
        var n = 0;
        while (n < max && StringTools.fastCodeAt(a, aLength - 1 - n) == StringTools.fastCodeAt(b, bLength - 1 - n)) {
            n++;
        }
        if (n > 0 && isLowSurrogate(StringTools.fastCodeAt(a, aLength - n))) {
            n--;
        }
        return n;

    }

    function moveCaret(inText:String, target:Int):Void {

        if (target == caret) return;
        final delta = target > caret
            ? graphemeCount(inText, caret, target)
            : -graphemeCount(inText, target, caret);
        caret = target;
        if (delta != 0 && onMove != null) onMove(delta);

    }

    function insert(inserted:String):Void {

        var start = 0;
        var i = 0;
        final length = inserted.length;
        while (i < length) {
            final c = StringTools.fastCodeAt(inserted, i);
            if (c == '\n'.code || c == '\r'.code) {
                if (i > start && onInsert != null) onInsert(inserted.substring(start, i));
                if (onLineBreak != null) onLineBreak();
                // CR LF is one line break
                if (c == '\r'.code && i + 1 < length && StringTools.fastCodeAt(inserted, i + 1) == '\n'.code) {
                    i++;
                }
                start = i + 1;
            }
            i++;
        }
        if (length > start && onInsert != null) {
            onInsert(start == 0 ? inserted : inserted.substring(start, length));
        }

    }

    /**
     * Number of grapheme clusters between two UTF-16 offsets of `text` (the
     * first code point always starts one).
     */
    public static function graphemeCount(text:String, from:Int, to:Int):Int {

        if (to > text.length) to = text.length;
        var count = 0;
        var i = from;
        var prev = -1;
        var regionalRun = 0;
        while (i < to) {
            var c = StringTools.fastCodeAt(text, i);
            var size = 1;
            if (isHighSurrogate(c) && i + 1 < text.length) {
                final low = StringTools.fastCodeAt(text, i + 1);
                if (isLowSurrogate(low)) {
                    c = 0x10000 + ((c - 0xD800) << 10) + (low - 0xDC00);
                    size = 2;
                }
            }

            var startsCluster = true;
            if (prev != -1) {
                if (prev == '\r'.code && c == '\n'.code) {
                    startsCluster = false;
                }
                else if (prev == 0x200D || isExtend(c)) {
                    // After a zero width joiner (emoji sequences), or an extending mark
                    startsCluster = false;
                }
                else if (isRegionalIndicator(c) && isRegionalIndicator(prev) && regionalRun % 2 == 1) {
                    // Second half of a flag
                    startsCluster = false;
                }
            }
            regionalRun = isRegionalIndicator(c) ? (prev != -1 && isRegionalIndicator(prev) ? regionalRun + 1 : 1) : 0;

            if (startsCluster) count++;
            prev = c;
            i += size;
        }
        return count;

    }

    static inline function isHighSurrogate(c:Int):Bool {
        return c >= 0xD800 && c <= 0xDBFF;
    }

    static inline function isLowSurrogate(c:Int):Bool {
        return c >= 0xDC00 && c <= 0xDFFF;
    }

    static inline function isRegionalIndicator(c:Int):Bool {
        return c >= 0x1F1E6 && c <= 0x1F1FF;
    }

    /**
     * Code points that extend the previous grapheme cluster (main combining
     * ranges, joiners, variation selectors, emoji modifiers and tags).
     */
    static function isExtend(c:Int):Bool {

        if (c < 0x0300) return false;
        return (c >= 0x0300 && c <= 0x036F)
            || (c >= 0x0483 && c <= 0x0489)
            || (c >= 0x0591 && c <= 0x05BD) || c == 0x05BF || c == 0x05C1 || c == 0x05C2 || c == 0x05C4 || c == 0x05C5 || c == 0x05C7
            || (c >= 0x0610 && c <= 0x061A) || (c >= 0x064B && c <= 0x065F) || c == 0x0670
            || (c >= 0x06D6 && c <= 0x06DC) || (c >= 0x06DF && c <= 0x06E4) || c == 0x06E7 || c == 0x06E8 || (c >= 0x06EA && c <= 0x06ED)
            || (c >= 0x0900 && c <= 0x0903) || (c >= 0x093A && c <= 0x093C) || (c >= 0x093E && c <= 0x094F) || (c >= 0x0951 && c <= 0x0957) || c == 0x0962 || c == 0x0963
            || c == 0x0E31 || (c >= 0x0E34 && c <= 0x0E3A) || (c >= 0x0E47 && c <= 0x0E4E)
            || (c >= 0x1160 && c <= 0x11FF)
            || (c >= 0x1AB0 && c <= 0x1AFF)
            || (c >= 0x1DC0 && c <= 0x1DFF)
            || c == 0x200C || c == 0x200D
            || (c >= 0x20D0 && c <= 0x20FF)
            || (c >= 0x302A && c <= 0x302F)
            || c == 0x3099 || c == 0x309A
            || (c >= 0xD7B0 && c <= 0xD7FF)
            || (c >= 0xFE00 && c <= 0xFE0F)
            || (c >= 0xFE20 && c <= 0xFE2F)
            || c == 0xFF9E || c == 0xFF9F
            || (c >= 0x1F3FB && c <= 0x1F3FF)
            || (c >= 0xE0020 && c <= 0xE007F)
            || (c >= 0xE0100 && c <= 0xE01EF);

    }

}
