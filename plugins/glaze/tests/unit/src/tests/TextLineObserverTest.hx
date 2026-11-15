// New code for the Haxe port of GPUI (no GPUI origin): tests of `TextPainter.lineObserver`.
package tests;

import glaze.DecorationRun;
import glaze.Font;
import glaze.HeadlessAtlas;
import glaze.Hsla;
import glaze.LineLayout;
import glaze.Point;
import glaze.Size;
import glaze.TextAlign;
import glaze.TextPainter;
import glaze.TextRun;
import glaze.WindowTextSystem;
import glaze.scene.Scene;
import glaze.util.Utf8;
import testing.TestCase;

/**
 * `TextPainter.lineObserver`: null by default, and when set it is told
 * every line that is painted, with its text, origin, layout and line
 * height. Painting is the same with and without it.
 */
class TextLineObserverTest extends TestCase {

    override public function teardown():Void {
        TextPainter.lineObserver = null;
    }

    static function painter(scene:Scene):TextPainter {
        return new TextPainter(scene, new HeadlessAtlas(), TextFixtures.textSystem(), 2.0, new glaze.Bounds(new Point(0, 0), new Size(512, 512)));
    }

    function testNullByDefault() {
        assertNull(TextPainter.lineObserver);
    }

    function testAShapedLineIsReportedWhenPainted() {
        final text = 'Hello';
        final system = new WindowTextSystem(TextFixtures.textSystem());
        final line = system.shapeLine(text, 16, [new TextRun(Utf8.byteLength(text), Font.of('Inter'), Hsla.black())]);
        final seen:Array<String> = [];
        var seenOrigin:Null<Point> = null;
        var seenLayout:Null<LineLayout> = null;
        var seenLineHeight = 0.0;
        var seenWraps = -1;
        var seenRuns:Null<Array<DecorationRun>> = null;
        TextPainter.lineObserver = (text, origin, layout, lineHeight, decorationRuns, wrapBoundaries, _) -> {
            seen.push(text);
            seenOrigin = origin;
            seenLayout = layout;
            seenLineHeight = lineHeight;
            seenWraps = wrapBoundaries;
            seenRuns = decorationRuns;
        };
        final scene = new Scene();
        line.paint(new Point(10, 20), 24, TextAlign.Left, null, painter(scene));
        assertEquals('Hello', seen.join('|'));
        assertFloatEquals(10, seenOrigin.x, 0);
        assertFloatEquals(20, seenOrigin.y, 0);
        assertTrue(seenLayout == line.layout);
        assertFloatEquals(24, seenLineHeight, 0);
        assertEquals(0, seenWraps);
        assertTrue(seenRuns == line.decorationRuns);
        final withObserver = scene.monochromeSprites.length;
        assertTrue(withObserver > 0);

        // The aligned form reports too
        line.paintAligned(new Point(10, 20), 24, TextAlign.Left, 200, painter(new Scene()));
        assertEquals('Hello|Hello', seen.join('|'));

        // Without an observer nothing is reported and the same glyphs are painted
        TextPainter.lineObserver = null;
        final plain = new Scene();
        line.paint(new Point(10, 20), 24, TextAlign.Left, null, painter(plain));
        assertEquals(2, seen.length);
        assertEquals(withObserver, plain.monochromeSprites.length);
    }

}
