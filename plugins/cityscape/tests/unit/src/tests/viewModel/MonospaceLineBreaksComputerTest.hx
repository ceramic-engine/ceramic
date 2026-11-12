// Ported from vscode src/vs/editor/test/common/viewModel/monospaceLineBreaksComputer.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.viewModel;

import cityscape.common.ModelLineProjectionData;
import cityscape.common.config.EditorOptions.WrappingIndent;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.config.FontInfo;
import cityscape.common.viewModel.MonospaceLineBreaksComputer;
import testing.TestCase;

/**
 * suite('Editor ViewModel - MonospaceLineBreaksComputer')
 *
 * Plus Cityscape tests of the `[loreline]` wrappingIndentColumns patch
 * (expected values worked out from loreline-monaco's patched
 * monospaceLineBreaksComputer.js).
 */
class MonospaceLineBreaksComputerTest extends TestCase {

    static final BREAK_BEFORE = EditorViewOptions.DEFAULT_WORD_WRAP_BREAK_BEFORE_CHARACTERS;
    static final BREAK_AFTER = EditorViewOptions.DEFAULT_WORD_WRAP_BREAK_AFTER_CHARACTERS;

    static function parseAnnotatedText(annotatedText:String):{text:String, indices:Array<Int>} {
        var text = '';
        var currentLineIndex = 0;
        final indices:Array<Int> = [];
        for (i in 0...annotatedText.length) {
            if (annotatedText.charAt(i) == '|') {
                currentLineIndex++;
            } else {
                text += annotatedText.charAt(i);
                indices[text.length - 1] = currentLineIndex;
            }
        }
        return {text: text, indices: indices};
    }

    static function toAnnotatedText(text:String, lineBreakData:Null<ModelLineProjectionData>):String {
        // Insert line break markers again, according to algorithm
        var actualAnnotatedText = '';
        if (lineBreakData != null) {
            var previousLineIndex = 0;
            for (i in 0...text.length) {
                final r = lineBreakData.translateToOutputPosition(i);
                if (previousLineIndex != r.outputLineIndex) {
                    previousLineIndex = r.outputLineIndex;
                    actualAnnotatedText += '|';
                }
                actualAnnotatedText += text.charAt(i);
            }
        } else {
            // No wrapping
            actualAnnotatedText = text;
        }
        return actualAnnotatedText;
    }

    static function getLineBreakData(factory:ILineBreaksComputerFactory, tabSize:Int, breakAfter:Int, columnsForFullWidthChar:Float, wrappingIndent:WrappingIndent, wordBreak:String, text:String, previousLineBreakData:Null<ModelLineProjectionData>, wrappingIndentColumns:Int = -1):Null<ModelLineProjectionData> {
        final fontInfo = new FontInfo({
            pixelRatio: 1,
            fontFamily: 'testFontFamily',
            fontWeight: 'normal',
            fontSize: 14,
            fontFeatureSettings: '',
            fontVariationSettings: '',
            lineHeight: 19,
            letterSpacing: 0,
            isMonospace: true,
            typicalHalfwidthCharacterWidth: 7,
            typicalFullwidthCharacterWidth: 7 * columnsForFullWidthChar,
            canUseHalfwidthRightwardsArrow: true,
            spaceWidth: 7,
            middotWidth: 7,
            wsmiddotWidth: 7,
            maxDigitWidth: 7
        }, false);
        final lineBreaksComputer = factory.createLineBreaksComputer(fontInfo, tabSize, breakAfter, wrappingIndent, wordBreak, wrappingIndentColumns);
        final previousLineBreakDataClone = previousLineBreakData != null ? new ModelLineProjectionData(null, null, previousLineBreakData.breakOffsets.slice(0), previousLineBreakData.breakOffsetsVisibleColumn.slice(0), previousLineBreakData.wrappedTextIndentLength) : null;
        lineBreaksComputer.addRequest(text, null, previousLineBreakDataClone);
        return lineBreaksComputer.finalizeResult()[0];
    }

    function assertLineBreaks(factory:ILineBreaksComputerFactory, tabSize:Int, breakAfter:Int, annotatedText:String, wrappingIndent:WrappingIndent = WrappingIndent.None, wordBreak:String = 'normal', ?pos:haxe.PosInfos):Null<ModelLineProjectionData> {
        // Create version of `annotatedText` with line break markers removed
        final text = parseAnnotatedText(annotatedText).text;
        final lineBreakData = getLineBreakData(factory, tabSize, breakAfter, 2, wrappingIndent, wordBreak, text, null);
        final actualAnnotatedText = toAnnotatedText(text, lineBreakData);

        assertEquals(annotatedText, actualAnnotatedText, null, pos);

        return lineBreakData;
    }

    function assertLineBreakDataEqual(a:Null<ModelLineProjectionData>, b:Null<ModelLineProjectionData>, ?pos:haxe.PosInfos):Void {
        if (a == null || b == null) {
            assertTrue(a == null && b == null, 'both null', pos);
            return;
        }
        assertDeepEquals(a.breakOffsets, b.breakOffsets, null, pos);
        assertEquals(a.wrappedTextIndentLength, b.wrappedTextIndentLength, null, pos);
        for (i in 0...a.breakOffsetsVisibleColumn.length) {
            final diff = a.breakOffsetsVisibleColumn[i] - b.breakOffsetsVisibleColumn[i];
            assertTrue(diff < 0.001, null, pos);
        }
    }

    function assertIncrementalLineBreaks(factory:ILineBreaksComputerFactory, text:String, tabSize:Int, breakAfter1:Int, annotatedText1:String, breakAfter2:Int, annotatedText2:String, wrappingIndent:WrappingIndent = WrappingIndent.None, columnsForFullWidthChar:Float = 2, ?pos:haxe.PosInfos):Void {
        // sanity check the test
        assertEquals(text, parseAnnotatedText(annotatedText1).text, null, pos);
        assertEquals(text, parseAnnotatedText(annotatedText2).text, null, pos);

        // check that the direct mapping is ok for 1
        final directLineBreakData1 = getLineBreakData(factory, tabSize, breakAfter1, columnsForFullWidthChar, wrappingIndent, 'normal', text, null);
        assertEquals(annotatedText1, toAnnotatedText(text, directLineBreakData1), null, pos);

        // check that the direct mapping is ok for 2
        final directLineBreakData2 = getLineBreakData(factory, tabSize, breakAfter2, columnsForFullWidthChar, wrappingIndent, 'normal', text, null);
        assertEquals(annotatedText2, toAnnotatedText(text, directLineBreakData2), null, pos);

        // check that going from 1 to 2 is ok
        final lineBreakData2from1 = getLineBreakData(factory, tabSize, breakAfter2, columnsForFullWidthChar, wrappingIndent, 'normal', text, directLineBreakData1);
        assertEquals(annotatedText2, toAnnotatedText(text, lineBreakData2from1), null, pos);
        assertLineBreakDataEqual(lineBreakData2from1, directLineBreakData2, pos);

        // check that going from 2 to 1 is ok
        final lineBreakData1from2 = getLineBreakData(factory, tabSize, breakAfter1, columnsForFullWidthChar, wrappingIndent, 'normal', text, directLineBreakData2);
        assertEquals(annotatedText1, toAnnotatedText(text, lineBreakData1from2), null, pos);
        assertLineBreakDataEqual(lineBreakData1from2, directLineBreakData1, pos);
    }

    // test('MonospaceLineBreaksComputer')
    function testMonospaceLineBreaksComputer() {

        final factory = new MonospaceLineBreaksComputerFactory('(', '\t).');

        // Empty string
        assertLineBreaks(factory, 4, 5, '');

        // No wrapping if not necessary
        assertLineBreaks(factory, 4, 5, 'aaa');
        assertLineBreaks(factory, 4, 5, 'aaaaa');
        assertLineBreaks(factory, 4, -1, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

        // Acts like hard wrapping if no char found
        assertLineBreaks(factory, 4, 5, 'aaaaa|a');

        // Honors wrapping character
        assertLineBreaks(factory, 4, 5, 'aaaaa|.');
        assertLineBreaks(factory, 4, 5, 'aaaaa|a.|aaa.|aa');
        assertLineBreaks(factory, 4, 5, 'aaaaa|a..|aaa.|aa');
        assertLineBreaks(factory, 4, 5, 'aaaaa|a...|aaa.|aa');
        assertLineBreaks(factory, 4, 5, 'aaaaa|a....|aaa.|aa');

        // Honors tabs when computing wrapping position
        assertLineBreaks(factory, 4, 5, '\t');
        assertLineBreaks(factory, 4, 5, '\t|aaa');
        assertLineBreaks(factory, 4, 5, '\t|a\t|aa');
        assertLineBreaks(factory, 4, 5, 'aa\ta');
        assertLineBreaks(factory, 4, 5, 'aa\t|aa');

        // Honors wrapping before characters (& gives it priority)
        assertLineBreaks(factory, 4, 5, 'aaa.|aa');
        assertLineBreaks(factory, 4, 5, 'aaa(.|aa');

        // Honors wrapping after characters (& gives it priority)
        assertLineBreaks(factory, 4, 5, 'aaa))|).aaa');
        assertLineBreaks(factory, 4, 5, 'aaa))|).|aaaa');
        assertLineBreaks(factory, 4, 5, 'aaa)|().|aaa');
        assertLineBreaks(factory, 4, 5, 'aaa|(().|aaa');
        assertLineBreaks(factory, 4, 5, 'aa.|(().|aaa');
        assertLineBreaks(factory, 4, 5, 'aa.|(.).|aaa');
    }

    // test('MonospaceLineBreaksComputer incremental 1')
    function testMonospaceLineBreaksComputerIncremental1() {

        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);

        assertIncrementalLineBreaks(
            factory, 'just some text and more', 4,
            10, 'just some |text and |more',
            15, 'just some text |and more'
        );

        assertIncrementalLineBreaks(
            factory, 'Cu scripserit suscipiantur eos, in affert pericula contentiones sed, cetero sanctus et pro. Ius vidit magna regione te, sit ei elaboraret liberavisse. Mundi verear eu mea, eam vero scriptorem in, vix in menandri assueverit. Natum definiebas cu vim. Vim doming vocibus efficiantur id. In indoctum deseruisse voluptatum vim, ad debitis verterem sed.', 4,
            47, 'Cu scripserit suscipiantur eos, in affert |pericula contentiones sed, cetero sanctus et |pro. Ius vidit magna regione te, sit ei |elaboraret liberavisse. Mundi verear eu mea, |eam vero scriptorem in, vix in menandri |assueverit. Natum definiebas cu vim. Vim |doming vocibus efficiantur id. In indoctum |deseruisse voluptatum vim, ad debitis verterem |sed.',
            142, 'Cu scripserit suscipiantur eos, in affert pericula contentiones sed, cetero sanctus et pro. Ius vidit magna regione te, sit ei elaboraret |liberavisse. Mundi verear eu mea, eam vero scriptorem in, vix in menandri assueverit. Natum definiebas cu vim. Vim doming vocibus efficiantur |id. In indoctum deseruisse voluptatum vim, ad debitis verterem sed.',
        );

        assertIncrementalLineBreaks(
            factory, 'An his legere persecuti, oblique delicata efficiantur ex vix, vel at graecis officiis maluisset. Et per impedit voluptua, usu discere maiorum at. Ut assum ornatus temporibus vis, an sea melius pericula. Ea dicunt oblique phaedrum nam, eu duo movet nobis. His melius facilis eu, vim malorum temporibus ne. Nec no sale regione, meliore civibus placerat id eam. Mea alii fabulas definitionem te, agam volutpat ad vis, et per bonorum nonumes repudiandae.', 4,
            57, 'An his legere persecuti, oblique delicata efficiantur ex |vix, vel at graecis officiis maluisset. Et per impedit |voluptua, usu discere maiorum at. Ut assum ornatus |temporibus vis, an sea melius pericula. Ea dicunt |oblique phaedrum nam, eu duo movet nobis. His melius |facilis eu, vim malorum temporibus ne. Nec no sale |regione, meliore civibus placerat id eam. Mea alii |fabulas definitionem te, agam volutpat ad vis, et per |bonorum nonumes repudiandae.',
            58, 'An his legere persecuti, oblique delicata efficiantur ex |vix, vel at graecis officiis maluisset. Et per impedit |voluptua, usu discere maiorum at. Ut assum ornatus |temporibus vis, an sea melius pericula. Ea dicunt oblique |phaedrum nam, eu duo movet nobis. His melius facilis eu, |vim malorum temporibus ne. Nec no sale regione, meliore |civibus placerat id eam. Mea alii fabulas definitionem |te, agam volutpat ad vis, et per bonorum nonumes |repudiandae.'
        );

        assertIncrementalLineBreaks(
            factory, '\t\t"owner": "vscode",', 4,
            14, '\t\t"owner|": |"vscod|e",',
            16, '\t\t"owner":| |"vscode"|,',
            WrappingIndent.Same
        );

        assertIncrementalLineBreaks(
            factory, '🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇&👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬', 4,
            51, '🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇&|👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬',
            50, '🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇|&|👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬',
            WrappingIndent.Same
        );

        assertIncrementalLineBreaks(
            factory, '🐇👬&🌞🌖', 4,
            5, '🐇👬&|🌞🌖',
            4, '🐇👬|&|🌞🌖',
            WrappingIndent.Same
        );

        assertIncrementalLineBreaks(
            factory, '\t\tfunc(\'🌞🏇🍼🌞🏇🍼🐇&👬🌖🌞👬🌖🌞🏇🍼🐇👬\', WrappingIndent.Same);', 4,
            26, '\t\tfunc|(\'🌞🏇🍼🌞🏇🍼🐇&|👬🌖🌞👬🌖🌞🏇🍼🐇|👬\', |WrappingIndent.|Same);',
            27, '\t\tfunc|(\'🌞🏇🍼🌞🏇🍼🐇&|👬🌖🌞👬🌖🌞🏇🍼🐇|👬\', |WrappingIndent.|Same);',
            WrappingIndent.Same
        );

        assertIncrementalLineBreaks(
            factory, 'factory, "xtxtfunc(x"🌞🏇🍼🌞🏇🍼🐇&👬🌖🌞👬🌖🌞🏇🍼🐇👬x"', 4,
            16, 'factory, |"xtxtfunc|(x"🌞🏇🍼🌞🏇🍼|🐇&|👬🌖🌞👬🌖🌞🏇🍼|🐇👬x"',
            17, 'factory, |"xtxtfunc|(x"🌞🏇🍼🌞🏇🍼🐇|&👬🌖🌞👬🌖🌞🏇🍼|🐇👬x"',
            WrappingIndent.Same
        );
    }

    // test('issue #95686: CRITICAL: loop forever on the monospaceLineBreaksComputer')
    function testIssue95686CRITICALLoopForeverOnTheMonospaceLineBreaksComputer() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertIncrementalLineBreaks(
            factory,
            '\t\t\t\t\t\t<tr dmx-class:table-danger="(alt <= 50)" dmx-class:table-warning="(alt <= 200)" dmx-class:table-primary="(alt <= 400)" dmx-class:table-info="(alt <= 800)" dmx-class:table-success="(alt >= 400)">',
            4,
            179, '\t\t\t\t\t\t<tr dmx-class:table-danger="(alt <= 50)" dmx-class:table-warning="(alt <= 200)" dmx-class:table-primary="(alt <= 400)" dmx-class:table-info="(alt <= 800)" |dmx-class:table-success="(alt >= 400)">',
            1, '\t|\t|\t|\t|\t|\t|<|t|r| |d|m|x|-|c|l|a|s|s|:|t|a|b|l|e|-|d|a|n|g|e|r|=|"|(|a|l|t| |<|=| |5|0|)|"| |d|m|x|-|c|l|a|s|s|:|t|a|b|l|e|-|w|a|r|n|i|n|g|=|"|(|a|l|t| |<|=| |2|0|0|)|"| |d|m|x|-|c|l|a|s|s|:|t|a|b|l|e|-|p|r|i|m|a|r|y|=|"|(|a|l|t| |<|=| |4|0|0|)|"| |d|m|x|-|c|l|a|s|s|:|t|a|b|l|e|-|i|n|f|o|=|"|(|a|l|t| |<|=| |8|0|0|)|"| |d|m|x|-|c|l|a|s|s|:|t|a|b|l|e|-|s|u|c|c|e|s|s|=|"|(|a|l|t| |>|=| |4|0|0|)|"|>',
            WrappingIndent.Same
        );
    }

    // test('issue #110392: Occasional crash when resize with panel on the right')
    function testIssue110392OccasionalCrashWhenResizeWithPanelOnTheRight() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertIncrementalLineBreaks(
            factory,
            '你好 **hello** **hello** **hello-world** hey there!',
            4,
            15, '你好 **hello** |**hello** |**hello-world**| hey there!',
            1, '你|好| |*|*|h|e|l|l|o|*|*| |*|*|h|e|l|l|o|*|*| |*|*|h|e|l|l|o|-|w|o|r|l|d|*|*| |h|e|y| |t|h|e|r|e|!',
            WrappingIndent.Same,
            1.6605405405405405
        );
    }

    // test('MonospaceLineBreaksComputer - CJK and Kinsoku Shori')
    function testMonospaceLineBreaksComputerCJKAndKinsokuShori() {
        final factory = new MonospaceLineBreaksComputerFactory('(', '\t)');
        assertLineBreaks(factory, 4, 5, 'aa \u5b89|\u5b89');
        assertLineBreaks(factory, 4, 5, '\u3042 \u5b89|\u5b89');
        assertLineBreaks(factory, 4, 5, '\u3042\u3042|\u5b89\u5b89');
        assertLineBreaks(factory, 4, 5, 'aa |\u5b89)\u5b89|\u5b89');
        assertLineBreaks(factory, 4, 5, 'aa \u3042|\u5b89\u3042)|\u5b89');
        assertLineBreaks(factory, 4, 5, 'aa |(\u5b89aa|\u5b89');
    }

    // test('MonospaceLineBreaksComputer - WrappingIndent.Same')
    function testMonospaceLineBreaksComputerWrappingIndentSame() {
        final factory = new MonospaceLineBreaksComputerFactory('', '\t ');
        assertLineBreaks(factory, 4, 38, ' *123456789012345678901234567890123456|7890', WrappingIndent.Same);
    }

    // test('issue #16332: Scroll bar overlaying on top of text')
    function testIssue16332ScrollBarOverlayingOnTopOfText() {
        final factory = new MonospaceLineBreaksComputerFactory('', '\t ');
        assertLineBreaks(factory, 4, 24, 'a/ very/long/line/of/tex|t/that/expands/beyon|d/your/typical/line/|of/code/', WrappingIndent.Indent);
    }

    // test('issue #35162: wrappingIndent not consistently working')
    function testIssue35162WrappingIndentNotConsistentlyWorking() {
        final factory = new MonospaceLineBreaksComputerFactory('', '\t ');
        final mapper = assertLineBreaks(factory, 4, 24, '                t h i s |i s |a l |o n |g l |i n |e', WrappingIndent.Indent);
        assertEquals('                    '.length, mapper.wrappedTextIndentLength);
    }

    // test('issue #75494: surrogate pairs')
    function testIssue75494SurrogatePairs() {
        final factory = new MonospaceLineBreaksComputerFactory('\t', ' ');
        assertLineBreaks(factory, 4, 49, '🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼|🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼🐇👬🌖🌞🏇🍼|🐇👬', WrappingIndent.Same);
    }

    // test('issue #75494: surrogate pairs overrun 1')
    function testIssue75494SurrogatePairsOverrun1() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertLineBreaks(factory, 4, 4, '🐇👬|&|🌞🌖', WrappingIndent.Same);
    }

    // test('issue #75494: surrogate pairs overrun 2')
    function testIssue75494SurrogatePairsOverrun2() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertLineBreaks(factory, 4, 17, 'factory, |"xtxtfunc|(x"🌞🏇🍼🌞🏇🍼🐇|&👬🌖🌞👬🌖🌞🏇🍼|🐇👬x"', WrappingIndent.Same);
    }

    // test('MonospaceLineBreaksComputer - WrappingIndent.DeepIndent')
    function testMonospaceLineBreaksComputerWrappingIndentDeepIndent() {
        final factory = new MonospaceLineBreaksComputerFactory('', '\t ');
        final mapper = assertLineBreaks(factory, 4, 26, '        W e A r e T e s t |i n g D e |e p I n d |e n t a t |i o n', WrappingIndent.DeepIndent);
        assertEquals('                '.length, mapper.wrappedTextIndentLength);
    }

    // test('issue #33366: Word wrap algorithm behaves differently around punctuation')
    function testIssue33366WordWrapAlgorithmBehavesDifferentlyAroundPunctuation() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertLineBreaks(factory, 4, 23, 'this is a line of |text, text that sits |on a line', WrappingIndent.Same);
    }

    // test('issue #152773: Word wrap algorithm behaves differently with bracket followed by comma')
    function testIssue152773WordWrapAlgorithmBehavesDifferentlyWithBracketFollowedByComma() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertLineBreaks(factory, 4, 24, 'this is a line of |(text), text that sits |on a line', WrappingIndent.Same);
    }

    // test("issue #112382: Word wrap doesn\\'t work well with control characters")
    function testIssue112382WordWrapDoesntWorkWellWithControlCharacters() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertLineBreaks(factory, 4, 6, '\x06\x06\x06|\x06\x06\x06', WrappingIndent.Same);
    }

    // test('Word break work well with Chinese/Japanese/Korean (CJK) text when setting normal')
    function testWordBreakWorkWellWithChineseJapaneseKoreanCJKTextWhenSettingNormal() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertLineBreaks(factory, 4, 5, '你好|1111', WrappingIndent.Same, 'normal');
    }

    // test('Word break work well with Chinese/Japanese/Korean (CJK) text when setting keepAll')
    function testWordBreakWorkWellWithChineseJapaneseKoreanCJKTextWhenSettingKeepAll() {
        final factory = new MonospaceLineBreaksComputerFactory(BREAK_BEFORE, BREAK_AFTER);
        assertLineBreaks(factory, 4, 8, '你好1111', WrappingIndent.Same, 'keepAll');
    }

    // Cityscape: the [loreline] wrappingIndentColumns patch

    function testWrappingIndentColumnsIndent() {
        // With 'indent' and wrappingIndentColumns 1, wrapped lines get the
        // line's indent plus 1 column (instead of the next tab stop: 4 + 4)
        final factory = new MonospaceLineBreaksComputerFactory('', '\t ');
        final data = getLineBreakData(factory, 4, 24, 2, WrappingIndent.Indent, 'normal', '    aaa bbb ccc ddd eee fff ggg hhh', null, 1);
        assertNotNull(data);
        assertEquals(5, data.wrappedTextIndentLength);
        final data2 = getLineBreakData(factory, 4, 24, 2, WrappingIndent.Indent, 'normal', '    aaa bbb ccc ddd eee fff ggg hhh', null, -1);
        assertEquals(8, data2.wrappedTextIndentLength);
    }

    function testWrappingIndentColumnsDeepIndent() {
        // 'deepIndent' is 2 levels: 2 x wrappingIndentColumns
        final factory = new MonospaceLineBreaksComputerFactory('', '\t ');
        final data = getLineBreakData(factory, 2, 24, 2, WrappingIndent.DeepIndent, 'normal', '  aaa bbb ccc ddd eee fff ggg hhh', null, 1);
        assertEquals(4, data.wrappedTextIndentLength);
        final data0 = getLineBreakData(factory, 2, 24, 2, WrappingIndent.DeepIndent, 'normal', '  aaa bbb ccc ddd eee fff ggg hhh', null, 0);
        assertEquals(2, data0.wrappedTextIndentLength);
    }

}
