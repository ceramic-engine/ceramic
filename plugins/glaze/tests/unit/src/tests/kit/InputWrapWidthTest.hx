// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper/wrap_width/tests.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Font;
import glaze.NoopTextSystem;
import glaze.Range;
import glaze.TestDispatcher;
import glaze.TextSystem;
import glaze.kit.base.input.InlineMetric;
import glaze.kit.base.input.TextWrapper;
import glaze.kit.base.input.WrappingIndent;
import glaze.util.Utf8;
import haxe.io.Bytes;
import haxe.io.FPHelper;
import ropey.Rope;
import testing.TestCase;
import unicode_segmentation.UnicodeSegmentation;

using glaze.kit.base.input.RopeExt;

/**
 * Differential wrapping and edit invalidation checks over the display-map
 * implementation (Rust `wrap_width/tests.rs`).
 *
 * Not ported: `native_cached_resize_matches_original_word_and_grapheme_breaks`
 * and `native_tab_size_changes_invalidate_warm_wrap_caches`, which only run on
 * Windows with its native text system (`#[cfg(target_os = "windows")]`).
 */
class InputWrapWidthTest extends TestCase {

    /** Deterministic fractional glyph widths include multibyte graphemes and contextual ligatures. */
    static function measure(text:String):Float {
        var width = 0.0;
        for (g in UnicodeSegmentation.graphemes(text, true)) {
            if (g == "\t")
                width += 28.25;
            else if (Utf8.isAscii(g))
                width += 7.125;
            else
                width += 15.75;
        }
        var fi = 0;
        var index = text.indexOf("fi");
        while (index >= 0) {
            fi++;
            index = text.indexOf("fi", index + 2);
        }
        return width - fi * 0.875;
    }

    /** Compare complete logical-to-visual row geometry, including continuation indentation. */
    static function rows(wrapper:TextWrapper):String {
        return [for (line in wrapper.iterLines()) '(${line.len()}, ${line.indent}, [${[for (r in line.wrappedLines) r.toString()].join(',')}])'].join(' ');
    }

    /** Run the same row-splice path with deterministic glyph widths and count actual rewraps. */
    static function resize(wrapper:TextWrapper, text:Rope, width:Float, reuse:Bool):Int {
        wrapper.wrapWidth = width;
        final indent = wrapper.wrappingIndent;
        var calls = 0;
        wrapper.updateLines(text, new Range(0, text.len()), text, reuse, (line, width, _) -> {
            calls += 1;
            return TextWrapper.measuredWrap(line, width, indent, measure);
        });
        return calls;
    }

    /** Rust `f32::next_up` (of a value representable as an `f32`) */
    static function f32NextUp(value:Float):Float {
        final bits = FPHelper.floatToI32(value);
        return FPHelper.i32ToFloat(value >= 0 ? bits + 1 : bits - 1);
    }

    /** Rust `f32::next_down` (of a positive value representable as an `f32`) */
    static function f32NextDown(value:Float):Float {
        final bits = FPHelper.floatToI32(value);
        return FPHelper.i32ToFloat(value > 0 ? bits - 1 : bits + 1);
    }

    function testOversizedWordsKeepMeasurementWorkLocal() {
        for (length in [8192, 16384]) {
            for (prefix in ["", "short ", "    "]) {
                final text = prefix + StringTools.lpad('', 'x', length);
                for (indent in [WrappingIndent.None, WrappingIndent.Same]) {
                    for (width in [80., 256., 512.]) {
                        var measuredBytes = 0;
                        var longestProbe = 0;
                        final measured = TextWrapper.measuredWrap(text, width, indent, part -> {
                            final len = part.length;
                            measuredBytes += len;
                            if (len > longestProbe)
                                longestProbe = len;
                            return len;
                        });
                        final original = TextWrapper.measuredWrapBoundaries(text, width, indent, part -> part.length);
                        assertEquals([for (b in original) b.toString()].join(','), [for (b in measured.boundaries) b.toString()].join(','));
                        assertTrue(longestProbe <= 4 * Std.int(width), 'a $width-pixel row measured a $longestProbe-byte suffix');
                        assertTrue(measuredBytes <= 32 * text.length, '${text.length} bytes required $measuredBytes bytes of shaping');
                    }
                }
            }
        }
    }

    function testCachedResizeMatchesColdUnicodeWrappingAtFractionalThresholds() {
        final text = Rope.fromStr("    alphabet 中文😀 é family 👨‍👩‍👧‍👦 finish\n\tfi ffi office\nمرحبا بالعالم\n\r\nend");
        for (indent in [WrappingIndent.None, WrappingIndent.Same]) {
            final cached = new TextWrapper(Font.of("test"), 14., 160.);
            cached.wrappingIndent = indent;
            resize(cached, text, 160., false);
            var reused = 0;
            // Narrow, widen, then jump across multiple break thresholds; test exact and adjacent floats.
            final values:Array<Int> = [for (v in 1...1440) v];
            var v = 1439;
            while (v >= 1)
                values.push(v--);
            for (extra in [4096, 1, 1600, 23])
                values.push(extra);
            for (value in values) {
                final base = value / 8.;
                for (width in [base, f32NextUp(base), f32NextDown(base)]) {
                    final wrapped = resize(cached, text, width, true);
                    final lines = text.linesLen();
                    reused += lines > wrapped ? lines - wrapped : 0;
                    final cold = new TextWrapper(Font.of("test"), 14., width);
                    cold.wrappingIndent = indent;
                    cold._update(text, new Range(0, text.len()), text, (line, width, _) -> TextWrapper.measuredWrapBoundaries(line, width, indent, measure));
                    final a = rows(cached);
                    final b = rows(cold);
                    if (a != b) {
                        assertEquals(b, a, 'width=$width, indent=$indent');
                        return;
                    }
                }
            }
            assertTrue(reused > 1000, "nearby widths must reuse real row geometry");
        }
    }

    /** A fresh wrapper with the same source and rendering inputs is the uncached layout oracle. */
    function assertCold(cached:TextWrapper, cx:App, ?pos:haxe.PosInfos) {
        final cold = new TextWrapper(cached.font, cached.fontSize, cached.wrapWidth);
        cold.wrappingIndent = cached.wrappingIndent;
        cold.tabSize = cached.tabSize;
        cold.inlineMetrics = cached.inlineMetrics;
        cold.update(cached.text, new Range(0, 0), cached.text, cx);
        assertEquals(rows(cold), rows(cached), null, pos);
    }

    /** A short changed line invalidates only itself while distant rows retain their measured decisions. */
    function testResizeReusesMeasuredLinesAndInvalidatesEditsFontsIndentAndTokens() {
        // `#[gpui::test]`: the test platform measures with GPUI's `NoopTextSystem`
        final cx = new App(new TestDispatcher());
        cx.setTextSystem(new TextSystem(new NoopTextSystem()));
        cx.update(cx -> {
            final text = Rope.fromStr("short\n    a longer line containing 中文 and fi\nlast\n");
            final cached = new TextWrapper(Font.of("Arial"), 14., 1000.);
            cached.update(text, new Range(0, 0), text, cx);
            TextWrapper.measuredLines = 0;
            var width = 999;
            while (width >= 800) {
                cached.setWrapWidth(width, cx);
                width--;
            }
            assertEquals(0, TextWrapper.measuredLines, "fitting lines must not be shaped again during a width drag");
            cached.setWrapWidth(1., cx);
            assertTrue(TextWrapper.measuredLines > 0);
            assertCold(cached, cx);

            final edited = text.clone();
            edited.replace(new Range(0, 5), "edited 中文😀 new line\ninserted");
            cached.update(edited, new Range(0, 5), Rope.fromStr("edited 中文😀 new line\ninserted"), cx);
            cached.setWrapWidth(82.5, cx);
            assertCold(cached, cx);
            cached.setFont(Font.of("Arial"), 22., cx);
            assertCold(cached, cx);
            cached.setWrappingIndent(WrappingIndent.None, cx);
            assertCold(cached, cx);
            cached.setInlineMetrics([new InlineMetric(new Range(0, 6), 80.)], cx);
            cached.setWrapWidth(120., cx);
            assertCold(cached, cx);
            cached.setWrapWidth(null, cx);
            assertCold(cached, cx);
            cached.setWrapWidth(130., cx);
            assertCold(cached, cx);
        });
    }

}
