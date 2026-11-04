package ceramic;

/**
 * Joins the UTF-16 code units of a platform that reports text input one code
 * unit at a time (Unity's `Keyboard.onTextInput`): a character outside the
 * basic multilingual plane (an emoji for example) arrives as two surrogates,
 * which must become one character before being emitted as text.
 *
 * A lone surrogate (a high one not followed by a low one, or a low one alone)
 * is dropped: it cannot be represented as text on every target.
 */
class Utf16Joiner {

    /** The high surrogate waiting for its low half, or -1. */
    var pendingHigh:Int = -1;

    public function new() {}

    /**
     * Takes one UTF-16 code unit.
     * @param unit The code unit (0 to 0xFFFF)
     * @return The text to emit, or null while the first half of a pair waits
     *         for the second one (or when a lone surrogate is dropped)
     */
    public function push(unit:Int):Null<String> {

        if (unit >= 0xD800 && unit <= 0xDBFF) {
            // A previous high surrogate without its low half is dropped
            pendingHigh = unit;
            return null;
        }

        if (unit >= 0xDC00 && unit <= 0xDFFF) {
            if (pendingHigh == -1) return null;
            final code = 0x10000 + ((pendingHigh - 0xD800) << 10) + (unit - 0xDC00);
            pendingHigh = -1;
            return String.fromCharCode(code);
        }

        pendingHigh = -1;
        return String.fromCharCode(unit);

    }

    /** Whether a high surrogate waits for its low half. */
    public function hasPending():Bool {

        return pendingHigh != -1;

    }

    /** Drops a high surrogate waiting for its low half. */
    public function reset():Void {

        pendingHigh = -1;

    }

}
