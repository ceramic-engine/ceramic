// Ported from gpui-pre-web 0.3.10: src/canvas_fallback.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.platform;

import haxe.iterators.StringIteratorUnicode;
import unicode_segmentation.UnicodeSegmentation;

/**
 * A supported grapheme assumed to be independently renderable by the
 * browser (Canvas2D fallback of the web text system).
 *
 * Eligibility only for independent, horizontal Canvas fallback of a complete
 * extended grapheme. Callers must still check whether bundled shaping
 * supplies the requested glyph and presentation; eligibility alone does not
 * override it.
 *
 * This is intentionally not a Unicode sequence validator or an RGI emoji
 * database. Han variation selectors are checked structurally, not against
 * the IVD registry. Emoji selectors are checked against the Emoji property,
 * not the registered variation-sequence list. Eligibility does not guarantee
 * browser coverage. Flags accept two regional indicators, not only assigned
 * country codes. ZWJ support is limited to person/profession pairs and a
 * small explicit allowlist; tags are limited to the three subdivision flags.
 * Other sequences stay on the loaded fonts.
 */
class CanvasFallback {

    /** Whether this is an emoji-capable grapheme, independent of its presentation. */
    public final isEmoji:Bool;

    /** Whether to request emoji presentation instead of ordinary text presentation. */
    public final emojiPresentation:Bool;

    public function new(isEmoji:Bool, emojiPresentation:Bool) {
        this.isEmoji = isEmoji;
        this.emojiPresentation = emojiPresentation;
    }

    public function equals(other:Null<CanvasFallback>):Bool {
        return other != null && other.isEmoji == isEmoji && other.emojiPresentation == emojiPresentation;
    }

    public function toString():String {
        return 'CanvasFallback(isEmoji: $isEmoji, emojiPresentation: $emojiPresentation)';
    }

    static final CJK = new CanvasFallback(false, false);

    static final EMOJI_TEXT = new CanvasFallback(true, false);

    static final EMOJI_PRESENTATION = new CanvasFallback(true, true);

/// Emoji status (unicode-properties `EmojiStatus`, in declaration order)

    static inline final NON_EMOJI = 0;
    static inline final NON_EMOJI_BUT_EMOJI_COMPONENT = 1;
    static inline final EMOJI_PRESENTATION_STATUS = 2;
    static inline final EMOJI_MODIFIER_BASE = 3;
    static inline final EMOJI_PRESENTATION_AND_MODIFIER_BASE = 4;
    static inline final EMOJI_OTHER = 5;
    static inline final EMOJI_PRESENTATION_AND_EMOJI_COMPONENT = 6;
    static inline final EMOJI_PRESENTATION_AND_MODIFIER_AND_EMOJI_COMPONENT = 7;
    static inline final EMOJI_OTHER_AND_EMOJI_COMPONENT = 8;

    static inline function isEmojiChar(c:Int):Bool {
        final s = CanvasFallbackTables.emojiStatus(c);
        return s != NON_EMOJI && s != NON_EMOJI_BUT_EMOJI_COMPONENT;
    }

    static inline function isEmojiComponent(c:Int):Bool {
        final s = CanvasFallbackTables.emojiStatus(c);
        return s == EMOJI_PRESENTATION_AND_EMOJI_COMPONENT || s == EMOJI_PRESENTATION_AND_MODIFIER_AND_EMOJI_COMPONENT || s == EMOJI_OTHER_AND_EMOJI_COMPONENT;
    }

    static inline function isRegionalIndicator(c:Int):Bool {
        return c >= 0x1F1E6 && c <= 0x1F1FF;
    }

    static function codePoints(text:String):Array<Int> {
        return [for (c in new StringIteratorUnicode(text)) c];
    }

    static function isAscii(chars:Array<Int>):Bool {
        for (c in chars)
            if (c > 0x7F)
                return false;
        return true;
    }

    static function containsChar(set:String, c:Int):Bool {
        for (s in new StringIteratorUnicode(set))
            if (s == c)
                return true;
        return false;
    }

/// Classification

    /**
     * Returns a presentation only when `grapheme` is exactly one supported
     * extended grapheme cluster (Rust `classify_canvas_fallback`). No
     * normalization, splitting, or font-coverage decision occurs.
     */
    public static function classify(grapheme:String):Null<CanvasFallback> {
        final chars = codePoints(grapheme);
        if (isAscii(chars))
            return null;
        final graphemes = UnicodeSegmentation.graphemes(grapheme, true);
        final first = graphemes.next();
        if (first == null || first != grapheme || graphemes.next() != null)
            return null;

        if (isCjk(chars)) {
            return CJK;
        }
        final emojiPresentation = classifyEmoji(grapheme, chars);
        if (emojiPresentation == null)
            return null;
        return emojiPresentation ? EMOJI_PRESENTATION : EMOJI_TEXT;
    }

    static function isCjk(chars:Array<Int>):Bool {
        if (chars.length == 0)
            return false;
        final base = chars[0];
        final suffixLength = chars.length - 1;

        // The script/category checks exclude unassigned holes; the ranges exclude
        // Han radicals, iteration marks, and other non-ideographic Han characters.
        if (CanvasFallbackTables.isHanLetter(base)
            && ((base >= 0x3400 && base <= 0x9FFF) || (base >= 0xF900 && base <= 0xFAFF) || (base >= 0x20000 && base <= 0x323AF))) {
            if (suffixLength == 0)
                return true;
            if (suffixLength != 1)
                return false;
            final vs = chars[1];
            return (vs >= 0xFE00 && vs <= 0xFE02) || (vs >= 0xE0100 && vs <= 0xE01EF);
        }

        if ((base >= 0x3041 && base <= 0x3096) || (base >= 0x30A1 && base <= 0x30FA)) {
            if (suffixLength == 0)
                return true;
            if (suffixLength != 1)
                return false;
            return switch chars[1] {
                case 0x3099: containsChar("うかきくけこさしすせそたちつてとはひふへほウカキクケコサシスセソタチツテトハヒフヘホワヰヱヲ", base);
                case 0x309A: containsChar("はひふへほハヒフヘホ", base);
                case _: false;
            }
        }

        if (base >= 0xAC00 && base <= 0xD7A3) {
            return suffixLength == 0
                || ((base - 0xAC00) % 28 == 0 && isSingleModernTrailingJamo(chars, 1));
        }
        if (base >= 0x1100 && base <= 0x1112) {
            if (chars.length < 2 || !(chars[1] >= 0x1161 && chars[1] <= 0x1175))
                return false;
            return chars.length == 2 || isSingleModernTrailingJamo(chars, 2);
        }

        return suffixLength == 0
            && ((base >= 0x3131 && base <= 0x3163)
                || containsChar("、。〈〉《》「」『』【】〔〕（）［］｛｝，．！？：；・ー々〆", base));
    }

    /** Whether `chars[start..]` is exactly one modern trailing jamo */
    static function isSingleModernTrailingJamo(chars:Array<Int>, start:Int):Bool {
        return chars.length == start + 1 && chars[start] >= 0x11A8 && chars[start] <= 0x11C2;
    }

    static final SUBDIVISION_FLAGS = [
        "🏴\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}",
        "🏴\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}",
        "🏴\u{E0067}\u{E0062}\u{E0077}\u{E006C}\u{E0073}\u{E007F}",
    ];

    /** Emoji presentation of an emoji grapheme, or null when it is not supported */
    static function classifyEmoji(grapheme:String, chars:Array<Int>):Null<Bool> {
        if (chars.length == 0)
            return null;
        final base = chars[0];

        if ((base >= '0'.code && base <= '9'.code) || base == '#'.code || base == '*'.code) {
            if (chars.length == 2 && chars[1] == 0x20E3)
                return true;
            if (chars.length == 3 && chars[1] == 0xFE0F && chars[2] == 0x20E3)
                return true;
            return null;
        }
        if (isRegionalIndicator(base)) {
            return (chars.length == 2 && isRegionalIndicator(chars[1])) ? true : null;
        }
        if (SUBDIVISION_FLAGS.indexOf(grapheme) != -1) {
            return true;
        }
        if (chars.indexOf(0x200D) != -1) {
            return isSupportedZwjSequence(grapheme) ? true : null;
        }
        return classifyEmojiUnit(chars);
    }

    static function classifyEmojiUnit(chars:Array<Int>):Null<Bool> {
        if (chars.length == 0)
            return null;
        final base = chars[0];
        if (!isEmojiChar(base) || isEmojiComponent(base))
            return null;
        final status = CanvasFallbackTables.emojiStatus(base);
        var emojiPresentation = status == EMOJI_PRESENTATION_STATUS || status == EMOJI_PRESENTATION_AND_MODIFIER_BASE;
        var i = 1;
        var next:Null<Int> = i < chars.length ? chars[i] : null;
        final explicitText = next == 0xFE0E;
        if (next == 0xFE0E || next == 0xFE0F) {
            emojiPresentation = !explicitText;
            i++;
            next = i < chars.length ? chars[i] : null;
        }
        if (next != null) {
            final modifier:Int = next;
            if (explicitText
                || !(status == EMOJI_MODIFIER_BASE || status == EMOJI_PRESENTATION_AND_MODIFIER_BASE)
                || CanvasFallbackTables.emojiStatus(modifier) != EMOJI_PRESENTATION_AND_MODIFIER_AND_EMOJI_COMPONENT) {
                return null;
            }
            emojiPresentation = true;
            i++;
        }
        return i >= chars.length ? emojiPresentation : null;
    }

    static final ZWJ_ALLOWLIST = [
        "👨‍👩‍👧", "👨‍👩‍👧‍👦", "👩‍👩‍👧‍👦", "👨‍👨‍👧‍👦", "🏳️‍🌈", "🏳️‍⚧️",
        "🏴‍☠️", "❤️‍🔥", "❤️‍🩹", "👁️‍🗨️", "🐻‍❄️",
    ];

    static final PROFESSIONS = [
        "⚕️", "⚖️", "✈️", "🌾", "🍳", "🎓", "🎤", "🎨", "🏫", "🏭", "💻", "💼", "🔧", "🔬", "🚀", "🚒",
    ];

    static function isSupportedZwjSequence(grapheme:String):Bool {
        if (ZWJ_ALLOWLIST.indexOf(grapheme) != -1)
            return true;
        final zwj = grapheme.indexOf('\u{200D}');
        if (zwj == -1)
            return false;
        final person = grapheme.substr(0, zwj);
        final profession = grapheme.substr(zwj + '\u{200D}'.length);
        final personChars = codePoints(person);
        if (personChars.length == 0)
            return false;
        final first = personChars[0];
        return (first == 0x1F468 || first == 0x1F469 || first == 0x1F9D1)
            && classifyEmojiUnit(personChars) == true
            && PROFESSIONS.indexOf(profession) != -1;
    }

}
