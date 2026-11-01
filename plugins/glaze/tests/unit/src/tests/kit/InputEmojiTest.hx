// Original code (not a port), written for ceramic-gpui: the behaviour of the
// input state of gpui-kit 0.8.1 (crates/base/src/input/base/state.rs,
// rope_ext.rs) on emoji sequences.
package tests.kit;

import gpui.Point;
import gpui.Range;
import gpui.base.input.InputActions;
import gpui.base.input.InputBaseState;
import gpui.util.Utf8;
import tests.kit.InputStateTestCase.InputView;

using gpui.base.input.InputMovement;

/**
 * Inputs and the code editor on emoji made of several code points (ZWJ
 * sequences, skin tones, flags, keycaps, variation selectors) and on
 * combining marks.
 *
 * gpui-kit moves the caret and deletes by Unicode scalar value, not by
 * grapheme: `previous_boundary` / `next_boundary` step one byte and clip to
 * the char boundary (`RopeExt::clip_offset`, `Rope::is_char_boundary`), so
 * `MoveRight` crosses "👨‍👩‍👧" in five steps and `Backspace` on "👍🏽" removes
 * the skin tone first. These tests check the port does the same, never
 * splits a code point (UTF-8 offsets, UTF-16 offsets of the platform input
 * handler, hit testing), and keeps the line height of the text.
 *
 * They run without an emoji font (the unit project disables system fonts):
 * emoji are `.notdef` glyphs of Inter here, which is enough for offsets.
 */
class InputEmojiTest extends InputStateTestCase {

    static final FAMILY = '👨‍👩‍👧';
    static final THUMB = '👍🏽';
    static final FLAG = '🇫🇷';
    static final KEYCAP = '1️⃣';
    static final HEART = '❤️';
    static final COMBINING = 'é';

    /** UTF-8 offsets of the code point boundaries of `text`, after `start` */
    static function codePointEnds(text:String, start:Int = 0):Array<Int> {
        final ends:Array<Int> = [];
        var offset = start;
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            offset += Utf8.codePointLength(c);
            ends.push(offset);
        }
        return ends;
    }

    function setText(view:InputView, text:String, cursor:Int):Void {
        view.update((state, window, cx) -> {
            state.setValue(text, window, cx);
            state.setSelectedRange(new Range(cursor, cursor), cx);
        });
    }

    function cursor(view:InputView):Int {
        return view.state().cursor();
    }

    function testMoveRightAndLeftStepByCodePoint() {
        for (make in [() -> build(), () -> buildEditor()]) {
            for (sequence in [FAMILY, THUMB, FLAG, KEYCAP, HEART, COMBINING]) {
                final view = make();
                final text = 'a' + sequence + 'b';
                setText(view, text, 0);
                final stops:Array<Int> = [];
                for (_ in 0...20) {
                    view.update((state, window, cx) -> state.right(new MoveRight(), window, cx));
                    if (stops.length > 0 && stops[stops.length - 1] == cursor(view))
                        break;
                    stops.push(cursor(view));
                }
                final expected = codePointEnds(text);
                assertEquals(expected.join(','), stops.join(','), 'right over $sequence');
                final back:Array<Int> = [];
                for (_ in 0...20) {
                    view.update((state, window, cx) -> state.left(new MoveLeft(), window, cx));
                    if (back.length > 0 && back[back.length - 1] == cursor(view))
                        break;
                    back.push(cursor(view));
                }
                expected.pop();
                expected.reverse();
                expected.push(0);
                assertEquals(expected.join(','), back.join(','), 'left over $sequence');
            }
        }
    }

    function testBackspaceAndDeleteRemoveOneCodePoint() {
        final view = buildEditor();
        // Backspace after the skin tone removes it, then the thumb
        setText(view, 'x' + THUMB + 'y', 1 + Utf8.byteLength(THUMB));
        view.update((state, window, cx) -> state.backspace(new Backspace(), window, cx));
        assertEquals('x👍y', view.state().text.toString());
        view.update((state, window, cx) -> state.backspace(new Backspace(), window, cx));
        assertEquals('xy', view.state().text.toString());
        assertEquals(1, cursor(view));
        // Delete before a flag removes its first regional indicator
        setText(view, FLAG + '!', 0);
        view.update((state, window, cx) -> state.delete(new Delete(), window, cx));
        assertEquals('🇷!', view.state().text.toString());
        // Backspace at the end of a family removes its last member
        setText(view, FAMILY, Utf8.byteLength(FAMILY));
        view.update((state, window, cx) -> state.backspace(new Backspace(), window, cx));
        assertEquals('👨‍👩‍', view.state().text.toString());
        // Undo restores the whole sequence
        view.update((state, window, cx) -> state.undo(new Undo(), window, cx));
        assertEquals(FAMILY, view.state().text.toString());
    }

    function testSelectionsExpandToCodePointBoundaries() {
        final view = build();
        final text = 'a' + FAMILY + THUMB;
        setText(view, text, 0);
        // A byte range inside the first emoji expands to whole code points
        view.update((state, window, cx) -> state.setSelectedRange(new Range(2, 7), cx));
        assertRange(1, 8, view.state().selectedRange());
        // The platform input handler sees UTF-16 offsets: 👨 is two code units
        view.update((state, window, cx) -> {
            final sel = state.selectedTextRange(false, window, cx);
            assertEquals('1..4', sel.range.start + '..' + sel.range.end);
            final adjusted = new gpui.util.Ref<Null<Range>>(null);
            assertEquals(THUMB, state.textForRange(new Range(9, 13), adjusted, window, cx));
        });
        // Selecting everything and typing replaces every sequence
        view.update((state, window, cx) -> {
            state.selectAll(window, cx);
            state.replaceTextInRange(null, 'ok ' + HEART, window, cx);
        });
        assertEquals('ok ' + HEART, view.state().text.toString());
        assertEquals(Utf8.byteLength('ok ' + HEART), cursor(view));
    }

    function testImeReplacementAfterAnEmoji() {
        final view = build();
        setText(view, THUMB + 'ab', 0);
        // Replace "a" (UTF-16 4..5, after the two surrogate pairs) with a family
        view.update((state, window, cx) -> state.replaceTextInRange(new Range(4, 5), FAMILY, window, cx));
        assertEquals(THUMB + FAMILY + 'b', view.state().text.toString());
        assertEquals(Utf8.byteLength(THUMB + FAMILY), cursor(view));
    }

    function testHitTestingLandsOnCodePointBoundaries() {
        final view = buildEditor();
        final text = 'a' + FAMILY + ' ' + THUMB + FLAG + KEYCAP + COMBINING;
        setText(view, text, 0);
        draw(view);
        final state = view.state();
        final layout = state.lastLayout;
        final origin = state.lastBounds.origin;
        final boundaries = [0].concat(codePointEnds(text));
        var x = 0.0;
        var hits = 0;
        while (x < 400) {
            final p = origin.add(new Point(layout.lineNumberWidth + x, layout.lineHeight * 0.5));
            final offset = state.indexForMousePosition(p).offset;
            assertTrue(boundaries.indexOf(offset) != -1, 'hit at x=$x gives $offset');
            hits++;
            x += 1.5;
        }
        assertTrue(hits > 100);
        // Every boundary is reachable by clicking its caret position
        for (offset in boundaries) {
            final local = layout.lines[0].positionForIndex(offset, layout, false);
            if (local == null)
                continue;
            final p = origin.add(new Point(layout.lineNumberWidth + local.x, layout.lineHeight * 0.5));
            final hit = state.indexForMousePosition(p).offset;
            assertTrue(boundaries.indexOf(hit) != -1);
        }
    }

    function testLineHeightDoesNotGrowWithEmoji() {
        final plain = buildEditor();
        setText(plain, 'plain text\nsecond line', 0);
        draw(plain);
        final emoji = buildEditor();
        setText(emoji, 'emoji ' + FAMILY + THUMB + FLAG + '\nsecond ' + KEYCAP + HEART, 0);
        draw(emoji);
        final a = plain.state().lastLayout;
        final b = emoji.state().lastLayout;
        assertEquals(a.lineHeight, b.lineHeight);
        // The second row starts one line height below the first in both
        final pa = a.lines[1].positionForIndex(0, a, false);
        final pb = b.lines[1].positionForIndex(0, b, false);
        assertEquals(pa == null ? null : pa.y, pb == null ? null : pb.y);
        final inputPlain = build();
        setText(inputPlain, 'plain', 0);
        draw(inputPlain);
        final inputEmoji = build();
        setText(inputEmoji, FAMILY + THUMB, 0);
        draw(inputEmoji);
        assertEquals(inputPlain.state().lastLayout.lineHeight, inputEmoji.state().lastLayout.lineHeight);
        assertEquals(inputPlain.state().lastBounds.size.height, inputEmoji.state().lastBounds.size.height);
    }

}
