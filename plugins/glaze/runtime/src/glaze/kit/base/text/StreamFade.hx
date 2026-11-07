// Ported from gpui-kit 0.8.1: crates/base/src/text/stream_fade.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Range;
import glaze.kit.base.text.TextLeaf.KeyedTextLeaf;
import glaze.util.Utf8;

/**
 * Fades streamed text in: the rendered characters an update adds start
 * transparent and reach full color over `TextViewMotion.streamFade`, as one
 * chunk, or word by word (character by character for CJK) when
 * `TextViewMotion.streamFadeStagger` separates them. An update too large to
 * light up within one fade goes back to fading as one chunk, see
 * `TextViewMotion.staggerStep`.
 *
 * The tracker compares rendered text, not source, so `**bo` completing into
 * bold `bold` fades the changed glyphs rather than mapping source bytes.
 *
 * Instants are seconds of the app's clock (`BackgroundExecutor.now`).
 */
class StreamFade {

    /** Rust `text_leaves`: the text leaves of `block`, appended to `out`. */
    public static function textLeaves(block:BlockNode, out:Array<KeyedTextLeaf>):Void {
        switch block {
            case Paragraph(paragraph):
                if (paragraph.span != null) {
                    out.push(new KeyedTextLeaf(TextLeafKey.block(paragraph.span.start), TextLeaf.Paragraph(paragraph)));
                }
            case Heading(_, children, span) if (span != null):
                out.push(new KeyedTextLeaf(TextLeafKey.block(span.start), TextLeaf.Paragraph(children)));
            case CodeBlock(codeBlock):
                if (codeBlock.span != null) {
                    out.push(new KeyedTextLeaf(TextLeafKey.block(codeBlock.span.start), TextLeaf.Code(codeBlock.code())));
                }
            case Table(table):
                if (table.span != null) {
                    var ordinal = 0;
                    for (row in table.children) {
                        for (cell in row.children) {
                            out.push(new KeyedTextLeaf(TextLeafKey.tableCell(table.span.start, ordinal), TextLeaf.Paragraph(cell.children)));
                            ordinal++;
                        }
                    }
                }
            case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                for (child in children) {
                    textLeaves(child, out);
                }
            case _:
        }
    }

    /**
     * Compares chunk by chunk with string equality, descending to bytes only at
     * the first chunk pair that differs.
     */
    public static function commonPrefixLenOfChunks(a:Array<String>, b:Array<String>):Int {
        var ai = 0;
        var bi = 0;
        var aRest:Null<haxe.io.Bytes> = null;
        var aPos = 0;
        var bRest:Null<haxe.io.Bytes> = null;
        var bPos = 0;
        var len = 0;
        while (true) {
            if (aRest == null || aPos >= aRest.length) {
                if (ai >= a.length) return len;
                aRest = haxe.io.Bytes.ofString(a[ai++]);
                aPos = 0;
                continue;
            }
            if (bRest == null || bPos >= bRest.length) {
                if (bi >= b.length) return len;
                bRest = haxe.io.Bytes.ofString(b[bi++]);
                bPos = 0;
                continue;
            }
            final step = Std.int(Math.min(aRest.length - aPos, bRest.length - bPos));
            var same = 0;
            while (same < step && aRest.get(aPos + same) == bRest.get(bPos + same)) same++;
            if (same < step) {
                return len + same;
            }
            len += step;
            aPos += step;
            bPos += step;
        }
    }

    /**
     * Splits `start..end` of the rendered text into the units that fade one
     * after another: a word together with the whitespace after it, or one CJK
     * character, since CJK text has no spaces to reveal it by.
     */
    public static function fadeUnits(chunks:Array<String>, start:Int, end:Int):Array<Range> {
        final units:Array<Range> = [];
        var unitStart = start;
        var unitHasGlyph = false;
        var previous:Int = -1;
        var offset = 0;
        for (chunk in chunks) {
            final chunkLen = Utf8.byteLength(chunk);
            if (offset + chunkLen <= start) {
                offset += chunkLen;
                previous = lastChar(chunk);
                continue;
            }
            var ix = 0;
            for (c in new haxe.iterators.StringIteratorUnicode(chunk)) {
                final position = offset + ix;
                if (position >= end) {
                    break;
                }
                if (position >= start) {
                    final isWs = Utf8.isWhitespace(c);
                    final startsUnit = unitHasGlyph
                        && !isWs
                        && (isCjk(c) || (previous != -1 && (Utf8.isWhitespace(previous) || isCjk(previous))));
                    if (startsUnit && position > unitStart) {
                        units.push(new Range(unitStart, position));
                        unitStart = position;
                        unitHasGlyph = false;
                    }
                    if (!isWs) unitHasGlyph = true;
                }
                previous = c;
                ix += Utf8.codePointLength(c);
            }
            offset += chunkLen;
            if (offset >= end) {
                break;
            }
        }
        if (unitStart < end) {
            units.push(new Range(unitStart, end));
        }
        return units;
    }

    static function lastChar(chunk:String):Int {
        var last = -1;
        for (c in new haxe.iterators.StringIteratorUnicode(chunk)) last = c;
        return last;
    }

    public static function isCjk(c:Int):Bool {
        return (c >= 0x3040 && c <= 0x30FF) // Hiragana, Katakana
            || (c >= 0x3400 && c <= 0x4DBF) // CJK Unified Ideographs Extension A
            || (c >= 0x4E00 && c <= 0x9FFF) // CJK Unified Ideographs
            || (c >= 0xAC00 && c <= 0xD7AF) // Hangul syllables
            || (c >= 0xF900 && c <= 0xFAFF) // CJK Compatibility Ideographs
            || (c >= 0x20000 && c <= 0x2FA1F); // CJK Unified Ideographs Extensions B and later
    }

    public static function floorCharBoundary(chunks:Array<String>, offset:Int):Int {
        var start = 0;
        for (chunk in chunks) {
            final end = start + Utf8.byteLength(chunk);
            if (offset < end) {
                var local = offset - start;
                while (!Utf8.isCharBoundary(chunk, local)) {
                    local -= 1;
                }
                return start + local;
            }
            start = end;
        }
        return offset;
    }

}
