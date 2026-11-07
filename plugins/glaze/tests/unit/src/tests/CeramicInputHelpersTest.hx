package tests;

import ceramic.KeyRepeatTimer;
import ceramic.MouseScrollConverter;
import ceramic.ScrollUnit;
import ceramic.Utf16Joiner;
import testing.TestCase;

/**
 * Tests of the backend independent input helpers of Ceramic used by the Unity
 * backend (lot U6, docs/UNITY.md): the scroll unit rule of clay's macOS
 * runtime (`MouseScrollConverter`, same rule as `SDLRuntime`'s
 * `lastPreciseScrollTime`), the joining of UTF-16 surrogates reported one by
 * one (`Utf16Joiner`) and the key repeat timing (`KeyRepeatTimer`).
 */
class CeramicInputHelpersTest extends TestCase {

    // MouseScrollConverter, macOS rule (clay: SDLRuntime SDL_EVENT_MOUSE_WHEEL)

    function testMacWholeValuesAreLines() {

        final c = new MouseScrollConverter(true);
        c.convert(0, 1, 10.0);
        assertEquals(ScrollUnit.LINES, c.unit);
        assertFloatEquals(0, c.deltaX);
        assertFloatEquals(-1, c.deltaY);
        c.convert(-2, -3, 10.1);
        assertEquals(ScrollUnit.LINES, c.unit);
        assertFloatEquals(-2, c.deltaX);
        assertFloatEquals(3, c.deltaY);

    }

    function testMacFractionalValuesArePixelsTimesTen() {

        final c = new MouseScrollConverter(true);
        c.convert(0.25, -1.5, 3.0);
        assertEquals(ScrollUnit.PIXELS, c.unit);
        assertFloatEquals(2.5, c.deltaX);
        assertFloatEquals(15, c.deltaY);

    }

    function testMacPreciseDeviceStaysPixelsForHalfASecond() {

        final c = new MouseScrollConverter(true);
        c.convert(0, 0.3, 1.0);
        assertEquals(ScrollUnit.PIXELS, c.unit);
        // A whole value inside the precise gesture
        c.convert(0, 1, 1.2);
        assertEquals(ScrollUnit.PIXELS, c.unit);
        assertFloatEquals(-10, c.deltaY);
        c.convert(0, 2, 1.5);
        assertEquals(ScrollUnit.PIXELS, c.unit, 'exactly 0.5 s after: still pixels (clay: > 0.5)');
        assertFloatEquals(-20, c.deltaY);
        c.convert(0, 1, 1.51);
        assertEquals(ScrollUnit.LINES, c.unit);
        assertFloatEquals(-1, c.deltaY);
        // Every fractional value extends the window
        c.convert(0, 0.5, 2.0);
        c.convert(0, 0.5, 2.4);
        c.convert(0, 1, 2.8);
        assertEquals(ScrollUnit.PIXELS, c.unit);
        c.reset();
        c.convert(0, 1, 2.9);
        assertEquals(ScrollUnit.LINES, c.unit);

    }

    function testMacFirstWholeValueEarlyInTimeIsLines() {

        // Event times of Unity start near 0: no precise device seen yet
        final c = new MouseScrollConverter(true);
        c.convert(0, 1, 0.1);
        assertEquals(ScrollUnit.LINES, c.unit);

    }

    function testWindowsRawValuesAreLinesOf120() {

        final c = new MouseScrollConverter(false, 120);
        c.convert(0, 120, 1.0);
        assertEquals(ScrollUnit.LINES, c.unit);
        assertFloatEquals(-1, c.deltaY);
        // High resolution wheel, precision touchpad
        c.convert(30, -12, 1.01);
        assertEquals(ScrollUnit.LINES, c.unit);
        assertFloatEquals(0.25, c.deltaX);
        assertFloatEquals(0.1, c.deltaY);

    }

    function testLinuxValuesAreLines() {

        final c = new MouseScrollConverter(false);
        c.convert(0, 0.5, 1.0);
        assertEquals(ScrollUnit.LINES, c.unit);
        assertFloatEquals(-0.5, c.deltaY);
        c.convert(0, 0, 1.0);
        assertTrue(1 / c.deltaY > 0, 'no negative zero');

    }

    function testScrollConversionToGpuiDeltas() {

        final c = new MouseScrollConverter(true);
        c.convert(0, -0.4, 1.0);
        switch gpui.GpuiInput.scrollDeltaOf(c.deltaX, c.deltaY, c.unit) {
            case Pixels(delta):
                // GPUI's sign is the raw one: positive y moves the content down
                assertFloatEquals(0, (delta.x : Float));
                assertFloatEquals(-4, (delta.y : Float));
            case Lines(_):
                fail('expected pixels');
        }
        final w = new MouseScrollConverter(false, 120);
        w.convert(0, 240, 1.0);
        switch gpui.GpuiInput.scrollDeltaOf(w.deltaX, w.deltaY, w.unit) {
            case Lines(delta):
                assertFloatEquals(2, delta.y);
            case Pixels(_):
                fail('expected lines');
        }

    }

    // Utf16Joiner

    function testJoinerKeepsBmpCharacters() {

        final j = new Utf16Joiner();
        assertEquals('a', j.push('a'.code));
        assertEquals('é', j.push(0xE9));
        assertEquals('中', j.push(0x4E2D));
        assertFalse(j.hasPending());

    }

    function testJoinerJoinsSurrogatePairs() {

        final j = new Utf16Joiner();
        // U+1F600 GRINNING FACE: D83D DE00
        assertNull(j.push(0xD83D));
        assertTrue(j.hasPending());
        final text = j.push(0xDE00);
        assertEquals(String.fromCharCode(0x1F600), text);
        assertEquals('\u{1F600}', text);
        assertEquals('😀', text);
        assertFalse(j.hasPending());
        // U+10000, the first one, and U+10FFFF, the last one
        j.push(0xD800);
        assertEquals(String.fromCharCode(0x10000), j.push(0xDC00));
        j.push(0xDBFF);
        assertEquals(String.fromCharCode(0x10FFFF), j.push(0xDFFF));

    }

    function testJoinerDropsLoneSurrogates() {

        final j = new Utf16Joiner();
        assertNull(j.push(0xDE00), 'low surrogate alone');
        j.push(0xD83D);
        assertEquals('b', j.push('b'.code), 'high surrogate followed by a BMP character');
        assertFalse(j.hasPending());
        j.push(0xD83D);
        assertNull(j.push(0xD83D), 'a second high surrogate replaces the first');
        assertEquals(String.fromCharCode(0x1F601), j.push(0xDE01));
        j.push(0xD83D);
        j.reset();
        assertNull(j.push(0xDE00));

    }

    // KeyRepeatTimer

    // Dyadic values: exact sums on every target

    function testKeyRepeatDelayThenInterval() {

        final r = new KeyRepeatTimer(0.5, 0.125);
        r.press(7);
        assertEquals(7, r.key);
        assertEquals(0, r.update(0.25));
        assertEquals(0, r.update(0.125));
        assertEquals(1, r.update(0.125), 'first repeat at the delay');
        assertEquals(0, r.update(0.0625));
        assertEquals(1, r.update(0.0625));
        assertEquals(2, r.update(0.25));
        r.release(3);
        assertEquals(7, r.key, 'another key released: still repeating');
        r.release(7);
        assertEquals(-1, r.key);
        assertEquals(0, r.update(1.0));

    }

    function testKeyRepeatLastPressedKeyOnly() {

        final r = new KeyRepeatTimer(0.5, 0.125);
        r.press(1);
        r.update(0.375);
        r.press(2);
        assertEquals(0, r.update(0.125), 'the delay starts again for the new key');
        r.release(1);
        assertEquals(2, r.key);
        assertEquals(1, r.update(0.375));

    }

    function testKeyRepeatLongFrameIsCapped() {

        final r = new KeyRepeatTimer(0.5, 0.0078125);
        r.press(1);
        assertEquals(8, r.update(10.0));
        assertEquals(1, r.update(0.0078125), 'no backlog after a capped frame');
        r.stop();
        assertEquals(0, r.update(1.0));

    }

}
