package tests;

import glaze.Font;
import glaze.FontFeatures;
import glaze.FontStyle;
import glaze.FontWeight;
import glaze.LineWrapper;
import glaze.NoopTextSystem;
import glaze.TextRun;
import glaze.TextSystem;
import testing.TestCase;

/**
 * Tests of the line wrapper (gpui-pre 0.3.10: src/text_system/line_wrapper.rs):
 *
 * - the `#[cfg(test)]` tests, with GPUI's test text system (`NoopTextSystem`:
 *   every character advances by 0.6 em, 9.6 px at 16 px);
 * - wrapping and truncation with Inter and JetBrains Mono, compared with the
 *   original GPUI (`CosmicTextSystem`, see `TextFixtures`).
 */
class LineWrapperTest extends TestCase {

    static function buildWrapper():LineWrapper {
        final textSystem = new TextSystem(new NoopTextSystem());
        return textSystem.lineWrapper(Font.of('.ZedMono'), 16);
    }

    static function generateTestRuns(inputRunLen:Array<Int>):Array<TextRun> {
        return [for (len in inputRunLen) new TextRun(len, new Font('Dummy', FontFeatures.defaultValue(), null, FontWeight.NORMAL, FontStyle.Normal))];
    }

    static function boundaries(list:Array<Boundary>):String {
        return [for (b in list) '${b.ix}:${b.nextIndent}'].join(' ');
    }

    static function byteLength(s:String):Int {
        return glaze.util.Utf8.byteLength(s);
    }

/// Ported #[cfg(test)] tests

    function testWrapLine() {
        final wrapper = buildWrapper();

        assertEquals('7:0 12:0 18:0', boundaries(wrapper.wrapLine([Text('aa bbb cccc ddddd eeee')], 72)));
        assertEquals('4:0 11:0 18:0', boundaries(wrapper.wrapLine([Text('aaa aaaaaaaaaaaaaaaaaa')], 72)));
        assertEquals('7:5 9:5 11:5', boundaries(wrapper.wrapLine([Text('     aaaaaaa')], 72)));
        assertEquals('7:0 14:0 21:0', boundaries(wrapper.wrapLine([Text('                            ')], 72)));
        assertEquals('7:0 14:3 18:3 22:3', boundaries(wrapper.wrapLine([Text('          aaaaaaaaaaaaaa')], 72)));

        // Test wrapping multiple text fragments
        assertEquals('7:0 12:0 18:0', boundaries(wrapper.wrapLine([Text('aa bbb '), Text('cccc ddddd eeee')], 72)));

        // Test wrapping with a mix of text and element fragments
        assertEquals('5:0 9:0 11:0', boundaries(wrapper.wrapLine([
            Text('aa '),
            Element(20, 1),
            Text(' bbb '),
            Element(30, 1),
            Text(' cccc')
        ], 72)));

        // Test with element at the beginning and text afterward
        assertEquals('2:0 7:0 12:0 17:0', boundaries(wrapper.wrapLine([Element(50, 1), Text(' aaaa bbbb cccc dddd')], 72)));

        // Test with a large element that forces wrapping by itself
        assertEquals('6:0 11:0 12:0 18:0', boundaries(wrapper.wrapLine([Text('short text '), Element(100, 1), Text(' more text')], 72)));

        // Test with non-breaking glue characters (3, 2 and 3 bytes, so the boundary ends up at 12)
        assertEquals('12:0', boundaries(wrapper.wrapLine([Text('a b c‑d e')], 72)));
    }

    function performTruncateTest(wrapper:LineWrapper, text:String, expected:String, ellipsis:String, from:TruncateFrom, ?pos:haxe.PosInfos) {
        final runs = generateTestRuns([byteLength(text)]);
        final result = wrapper.truncateLine(text, 220, ellipsis, runs, from);
        assertEquals(expected, result.text, null, pos);
        assertEquals(byteLength(result.text), result.runs[0].len, null, pos);
    }

    function testTruncateLineEnd() {
        final wrapper = buildWrapper();
        performTruncateTest(wrapper, 'aa bbb cccc ddddd eeee ffff gggg', 'aa bbb cccc ddddd eeee', '', End);
        performTruncateTest(wrapper, 'aa bbb cccc ddddd eeee ffff gggg', 'aa bbb cccc ddddd eee…', '…', End);
        performTruncateTest(wrapper, 'aa bbb cccc ddddd eeee ffff gggg', 'aa bbb cccc dddd......', '......', End);
        performTruncateTest(wrapper, 'aa bbb cccc 🦀🦀🦀🦀🦀 eeee ffff gggg', 'aa bbb cccc 🦀🦀🦀🦀…', '…', End);
    }

    function testTruncateLineStart() {
        final wrapper = buildWrapper();
        performTruncateTest(wrapper, 'aaaa bbbb cccc ddddd eeee fff gg', 'cccc ddddd eeee fff gg', '', Start);
        performTruncateTest(wrapper, 'aaaa bbbb cccc ddddd eeee fff gg', '…ccc ddddd eeee fff gg', '…', Start);
        performTruncateTest(wrapper, 'aaaa bbbb cccc ddddd eeee fff gg', '......dddd eeee fff gg', '......', Start);
        performTruncateTest(wrapper, 'aaaa bbbb cccc 🦀🦀🦀🦀🦀 eeee fff gg', '…🦀🦀🦀🦀 eeee fff gg', '…', Start);
    }

    function performMultipleRunsTest(wrapper:LineWrapper, text:String, expected:String, runLens:Array<Int>, resultRunLen:Array<Int>, lineWidth:Float, from:TruncateFrom, ?pos:haxe.PosInfos) {
        final runs = generateTestRuns(runLens);
        final result = wrapper.truncateLine(text, lineWidth, '…', runs, from);
        assertEquals(expected, result.text, null, pos);
        for (i in 0...Std.int(Math.min(result.runs.length, resultRunLen.length))) {
            assertEquals(resultRunLen[i], result.runs[i].len, null, pos);
        }
    }

    function testTruncateMultipleRunsEnd() {
        final wrapper = buildWrapper();
        // Case 0: Normal
        performMultipleRunsTest(wrapper, 'abcdefghijkl', 'abcd…', [12], [7], 50, End);
        // Case 1: Drop some runs
        performMultipleRunsTest(wrapper, 'abcdefghijkl', 'abcdef…', [4, 4, 4], [4, 5], 70, End);
        // Case 2: Truncate at start of some run
        performMultipleRunsTest(wrapper, 'abcdefghijkl', 'abcdefgh…', [4, 4, 4], [4, 4, 3], 90, End);
    }

    function testTruncateMultipleRunsStart() {
        final wrapper = buildWrapper();
        // Case 0: Normal
        performMultipleRunsTest(wrapper, 'abcdefghijkl', '…ijkl', [12], [7], 50, Start);
        // Case 1: Drop some runs
        performMultipleRunsTest(wrapper, 'abcdefghijkl', '…ghijkl', [4, 4, 4], [5, 4], 70, Start);
        // Case 2: Truncate at start of some run
        performMultipleRunsTest(wrapper, 'abcdefghijkl', '…efghijkl', [4, 4, 4], [3, 4, 4], 90, Start);
    }

    function testUpdateRunAfterTruncationEnd() {
        function performTest(result:String, runLens:Array<Int>, resultRunLens:Array<Int>) {
            final runs = generateTestRuns(runLens);
            LineWrapper.updateRunsAfterTruncation(result, '…', runs, End);
            for (i in 0...Std.int(Math.min(runs.length, resultRunLens.length))) {
                assertEquals(resultRunLens[i], runs[i].len);
            }
        }
        performTest('abcd…', [12], [7]);
        performTest('abcdef…', [4, 4, 4], [4, 5]);
        performTest('abcdefgh…', [4, 4, 4], [4, 4, 3]);
    }

    function testIsWordChar() {
        function assertWord(word:String, ?pos:haxe.PosInfos) {
            final d = new glaze.util.Utf8.Utf8Text(word);
            for (k in 0...d.count) {
                assertTrue(LineWrapper.isWordChar(d.codePoints[k]), 'assertion failed for \'${glaze.util.Utf8.fromCodePoint(d.codePoints[k])}\' (unicode 0x${StringTools.hex(d.codePoints[k])})', pos);
            }
        }
        function assertNotWord(word:String, ?pos:haxe.PosInfos) {
            final d = new glaze.util.Utf8.Utf8Text(word);
            var found = false;
            for (k in 0...d.count) {
                if (!LineWrapper.isWordChar(d.codePoints[k]))
                    found = true;
            }
            assertTrue(found, 'assertion failed for \'$word\'', pos);
        }

        assertWord('Hello123');
        assertWord('non-English');
        assertWord('var_name');
        assertWord('123456');
        assertWord('3.1415');
        assertWord('10^2');
        assertWord('1~2');
        assertWord('100%');
        assertWord('@mention');
        assertWord('#hashtag');
        assertWord("$variable");
        assertWord('a=1');
        assertWord('Self::is_word_char');
        assertWord('on;');
        assertWord('more⋯');
        assertWord('won’t');
        assertWord('‘twas');
        assertWord('plz!');
        assertWord('see)');
        assertWord('quoted”');
        assertWord('well…');

        // Space
        assertNotWord('foo bar');

        // URL case
        assertWord('github.com');
        assertNotWord('zed-industries/zed');
        assertNotWord('zed-industries\\zed');
        assertNotWord('a=1&b=2');
        assertNotWord('foo?b=2');

        // Latin-1 Supplement
        assertWord('ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ');
        // Latin Extended-A
        assertWord('ĀāĂăĄąĆćĈĉĊċČčĎď');
        // Latin Extended-B
        assertWord('ƀƁƂƃƄƅƆƇƈƉƊƋƌƍƎƏ');
        // Cyrillic
        assertWord('АБВГДЕЖЗИЙКЛМНОП');
        // Vietnamese (https://github.com/zed-industries/zed/issues/23245)
        assertWord('ThậmchíđếnkhithuachạychúngcònnhẫntâmgiếtnốtsốđôngtùchínhtrịởYênBáivàCaoBằng');
        // Bengali
        assertWord('গিয়েছিলেন');
        assertWord('ছেলে');
        assertWord('হচ্ছিল');

        // non-word characters
        assertNotWord('你好');
        assertNotWord('안녕하세요');
        assertNotWord('こんにちは');
        assertNotWord('😀😁😂');
        assertNotWord('()[]{}<>');

        // Non-breaking ("Glue") characters, see https://www.unicode.org/reports/tr14/
        assertWord(' ');
        assertWord(' ');
        assertWord('‑');
    }

    function wrapCount(wrapper:LineWrapper, text:String, wrapWidth:Float):Int {
        return wrapper.wrapLine([Text(text)], wrapWidth).length;
    }

    function testMultilineTruncationFitsWithinWrappedLines() {
        final wrapper = buildWrapper();
        final text = 'aa bbbbbb cccccc dddddd eeee ffff';
        final result = wrapper.truncateWrappedLine(text, 72, 2, '…', generateTestRuns([byteLength(text)]), End);
        assertTrue(wrapCount(wrapper, result.text, 72) < 2, 'Truncated text \'${result.text}\' wraps into too many visual lines');
        assertTrue(StringTools.endsWith(result.text, '…'));
    }

    function testMultilineTruncationNoTruncationNeeded() {
        final wrapper = buildWrapper();
        final text = 'aa bbb cccccc';
        final result = wrapper.truncateWrappedLine(text, 72, 2, '…', generateTestRuns([byteLength(text)]), End);
        assertEquals(text, result.text, 'Text that fits should not be modified');
    }

    function testMultilineTruncationThreeLines() {
        final wrapper = buildWrapper();
        final text = 'aa bbb cccc ddddd eeee ffff gggg hhhh iiii jjjj';
        final result = wrapper.truncateWrappedLine(text, 72, 3, '…', generateTestRuns([byteLength(text)]), End);
        assertTrue(wrapCount(wrapper, result.text, 72) < 3);
        assertTrue(StringTools.endsWith(result.text, '…'));
    }

    function testMultilineTruncationWithNewlines() {
        final wrapper = buildWrapper();
        final text = 'hello\nworld foo bar baz';
        final result = wrapper.truncateWrappedLine(text, 72, 2, '…', generateTestRuns([byteLength(text)]), End);
        final newline = result.text.indexOf('\n');
        assertTrue(newline != -1, 'Newline should be preserved: \'${result.text}\'');
        assertEquals('hello', result.text.substr(0, newline));
        final second = result.text.substr(newline + 1);
        var secondWidth = 0.0;
        final d = new glaze.util.Utf8.Utf8Text(second);
        for (k in 0...d.count)
            secondWidth += wrapper.widthForChar(d.codePoints[k]);
        assertTrue(secondWidth <= 72, 'Second line \'$second\' (${secondWidth}px) exceeds wrap_width');
        assertTrue(StringTools.endsWith(result.text, '…'));
    }

    function testMultilineTruncationNewlineOnLastLine() {
        final wrapper = buildWrapper();
        final text = 'hello\nworld\nmore';
        final result = wrapper.truncateWrappedLine(text, 72, 2, '…', generateTestRuns([byteLength(text)]), End);
        assertEquals('hello', result.text.split('\n')[0]);
        assertTrue(StringTools.endsWith(result.text, '…'), 'Should end with ellipsis since there\'s more content: \'${result.text}\'');
    }

    function testTruncateLineMiddle() {
        final wrapper = buildWrapper();

        // No truncation when text fits within a very wide budget.
        final shortText = 'hello world';
        var result = wrapper.truncateLine(shortText, 10000, '…', generateTestRuns([byteLength(shortText)]), Middle);
        assertEquals(shortText, result.text);
        assertEquals(1, result.runs.length);
        assertEquals(byteLength(shortText), result.runs[0].len);

        // Basic middle truncation: long string with px(100.) budget.
        final longText = 'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';
        result = wrapper.truncateLine(longText, 100, '…', generateTestRuns([byteLength(longText)]), Middle);
        assertTrue(result.text.indexOf('…') != -1, 'Middle-truncated result should contain \'…\', got: \'${result.text}\'');
        assertTrue(result.text.length < longText.length);
        assertEquals(longText.charAt(0), result.text.charAt(0));
        assertEquals(longText.charAt(longText.length - 1), result.text.charAt(result.text.length - 1));

        // Degenerate case: budget so narrow that middle truncation cannot find a valid split.
        final text = 'abcdef';
        result = wrapper.truncateLine(text, 1, '…', generateTestRuns([byteLength(text)]), Middle);
        assertEquals('…', result.text);
        assertEquals(1, result.runs.length);
        assertEquals(byteLength('…'), result.runs[0].len);

        // Run adjustment correctness: multiple runs across the string.
        final multiRunText = 'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';
        result = wrapper.truncateLine(multiRunText, 100, '…', generateTestRuns([20, 20, byteLength(multiRunText) - 40]), Middle);
        var totalRunLen = 0;
        for (run in result.runs)
            totalRunLen += run.len;
        assertEquals(byteLength(result.text), totalRunLen, 'Sum of run lengths should equal result byte length');
    }

    function testMultilineTruncationTrailingNewline() {
        final wrapper = buildWrapper();
        final text = 'hello\nworld\n';
        final result = wrapper.truncateWrappedLine(text, 72, 2, '…', generateTestRuns([byteLength(text)]), End);
        assertFalse(StringTools.endsWith(result.text, '…'), 'Trailing newline with no content should not add ellipsis: \'${result.text}\'');
    }

    function testMultilineTruncationNewlineFitsExactly() {
        final wrapper = buildWrapper();
        final text = 'hello\nworld';
        final result = wrapper.truncateWrappedLine(text, 72, 2, '…', generateTestRuns([byteLength(text)]), End);
        assertEquals(text, result.text, 'Text that fits exactly should not be modified');
    }

    function testExtraColumnsOverflowGuard() {
        final wrapper = buildWrapper();
        final spaceWidth = wrapper.widthForChar(' '.code);

        // 6 spaces indent, wrap width 10 columns.
        final text = '      ab cd ef gh';
        final wrapWidth = spaceWidth * 10.0;

        // When base_indent + extra overflows wrap width (6 + 8 + 2 > 10),
        // indent must fall back to 0 instead of degrading to one character per row.
        assertEquals('9:0', boundaries(wrapper.wrapLine([Text(text)], wrapWidth, ExtraColumns(8))));

        // When base_indent + extra fits within wrap width (6 + 2 + 2 <= 10),
        // the extra indent is applied and not clamped.
        assertEquals('9:8 11:8 13:8 15:8', boundaries(wrapper.wrapLine([Text(text)], wrapWidth, ExtraColumns(2))));

        // Full-width (two-column) glyphs: candidate + 2 > wrap_width, indent falls back to 0.
        assertEquals('17:0', boundaries(wrapper.wrapLine([Text(' 🦀🦀🦀🦀🦀🦀🦀🦀')], wrapWidth, ExtraColumns(8))));

        // The carried suffix fits alongside the extra indent (1 + 9 = 10 <= 10).
        assertEquals('2:1', boundaries(wrapper.wrapLine([Text('a abcdefghi')], wrapWidth, ExtraColumns(1))));

        // The extra indent exceeds wrap width by 1 column (2 + 9 = 11 > 10).
        assertEquals('2:0', boundaries(wrapper.wrapLine([Text('a abcdefghi')], wrapWidth, ExtraColumns(2))));

        // The carried suffix must be accounted for (8 + 9 = 17 > 10).
        assertEquals('2:0', boundaries(wrapper.wrapLine([Text('a abcdefghij')], wrapWidth, ExtraColumns(8))));

        // A wider inline element after the first wrap.
        assertEquals('10:8 12:0 15:8', boundaries(wrapper.wrapLine([
            Text('abcdefghijk '),
            Element(spaceWidth * 8.0, 1),
            Text('z 12'),
        ], wrapWidth, ExtraColumns(8))));

        // A line of only whitespace must not get extra columns.
        assertEquals('10:0', boundaries(wrapper.wrapLine([Text('                    ')], wrapWidth, ExtraColumns(8))));

        // Leading whitespace wrapping before the first non-whitespace character.
        assertEquals('10:0 20:6 23:6', boundaries(wrapper.wrapLine([Text('              ab cd ef gh')], wrapWidth, ExtraColumns(2))));

        // An oversized carried suffix rejects the earlier candidate.
        assertEquals('10:2 18:2 21:0', boundaries(wrapper.wrapLine([
            Text('aaaaaaaaaaaaaaaaaaa a'),
            Element(spaceWidth * 10.0, 1),
        ], wrapWidth, ExtraColumns(2))));

        // `u32::MAX` extra columns (saturating add)
        assertEquals('4:0 8:0', boundaries(wrapper.wrapLine([Text('  aaaaaaaa')], spaceWidth * 4.0, ExtraColumns(-1))));
    }

/// Against GPUI (Inter and JetBrains Mono)

    function testWrapperMatchesGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final ts = TextFixtures.textSystem();
        final wrappers:Array<Dynamic> = ref.wrappers;
        var wraps = 0;
        var truncations = 0;
        var maxWidthError = 0.0;
        for (w in wrappers) {
            final family:String = w.family;
            final size:Float = w.size;
            final wrapper = ts.lineWrapper(Font.of(family), size);
            for (entry in (w.char_widths:Array<Array<Dynamic>>)) {
                final ch = glaze.util.Utf8.codePointAtByte(entry[0], 0);
                final error = Math.abs((entry[1]:Float) - (wrapper.widthForChar(ch):Float));
                maxWidthError = Math.max(maxWidthError, error);
                assertFloatEquals(entry[1], (wrapper.widthForChar(ch):Float), 1e-4, '$family width of ${entry[0]}');
            }
            for (entry in (w.wrap_line:Array<Dynamic>)) {
                final indent:IndentAdjustment = switch (entry.indent:String) {
                    case 'none': NoIndent;
                    case 'extra2': ExtraColumns(2);
                    case _: SameIndent;
                };
                final expected = [for (b in (entry.boundaries:Array<Array<Int>>)) '${b[0]}:${b[1]}'].join(' ');
                assertEquals(expected, boundaries(wrapper.wrapLine([Text(entry.text)], entry.width, indent)), '$family wrap "${entry.text}" at ${entry.width} (${entry.indent})');
                wraps++;
            }
            for (entry in (w.truncate:Array<Dynamic>)) {
                final text:String = entry.text;
                final runs = [new TextRun(byteLength(text), Font.of(family))];
                final from:TruncateFrom = switch (entry.from:String) {
                    case 'start': Start;
                    case 'middle': Middle;
                    case _: End;
                };
                final result = entry.max_lines != null
                    ? wrapper.truncateWrappedLine(text, entry.width, entry.max_lines, entry.affix, runs, from)
                    : wrapper.truncateLine(text, entry.width, entry.affix, runs, from);
                final label = '$family truncate ${entry.from} "$text" at ${entry.width} with "${entry.affix}"${entry.max_lines != null ? ' on ' + entry.max_lines + ' lines' : ''}';
                assertEquals((entry.result:String), result.text, label);
                assertEquals((entry.run_lens:Array<Int>).join(','), [for (r in result.runs) r.len].join(','), '$label run lengths');
                truncations++;
            }
        }
        trace('LineWrapperTest: $wraps wrap_line and $truncations truncation results compared with GPUI, max char width difference $maxWidthError px');
    }

}
