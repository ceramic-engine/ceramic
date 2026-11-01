// Ported from gpui-kit 0.8.1: crates/base/src/input/base/selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;
import ropey.Rope;

using gpui.base.input.RopeExt;

/**
 * Word and line ranges of a rope, for double and triple clicks.
 */
class TextSelector {

    /**
     * The line at the given UTF-8 offset: its start and end offsets (without
     * the `\n`).
     */
    public static function lineRange(text:Rope, offset:Int):Range {
        final offset = text.clipOffset(offset, Bias.Left);
        final row = text.offsetToPoint(offset).row;
        final start = text.lineStartOffset(row);
        final end = text.lineEndOffset(row);

        return new Range(start, end);
    }

    /**
     * The word at the given UTF-8 offset: its start and end offsets, or null
     * past the end.
     */
    public static function wordRange(text:Rope, offset:Int):Null<Range> {
        final offset = text.clipOffset(offset, Bias.Left);
        final char = text.charAt(offset);
        if (char == null) {
            return null;
        }

        final end = offset + gpui.util.Utf8.codePointLength(char);
        final prevChars = text.charsAt(offset).reversed();
        final nextChars = text.charsAt(end);
        return TextBoundary.wordRangeFromChars(offset, char, () -> prevChars.next(), () -> nextChars.next());
    }

}
