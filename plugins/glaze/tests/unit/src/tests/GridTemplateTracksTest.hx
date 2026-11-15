package tests;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.GridTemplate;
import glaze.GridTrack;
import glaze.IntoElement;
import glaze.TestDispatcher;
import glaze.Window;
import testing.InteractionScript.ScriptView;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Port addition (no GPUI equivalent): explicit grid track lists
 * (`gridTemplateCols([...])`, `gridTemplateRows([...])`, `GridTrack`).
 *
 * The expected sizes are computed by hand from the CSS grid rules (CSS Grid
 * Layout Module Level 2, track sizing) for simple cases with fixed size
 * items: fixed tracks take their length, `auto`, `min-content` and
 * `max-content` tracks take the size of their (fixed size) items, and the
 * `fr` tracks share what is left after the gaps.
 */
class GridTemplateTracksTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    final cells:Array<Bounds> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (window in windows) window.destroy();
        windows.resize(0);
        ceramic.App.app.flushImmediate();
    }

    /** A grid item that records its bounds (stretched unless sized). */
    function cell(index:Int):glaze.Canvas<Int> {
        return canvas((bounds, _, _) -> {
            cells[index] = bounds;
            return 0;
        }, (_, _, _, _) -> {});
    }

    /**
     * Draws the grid in a block at the top left of a 600x400 window (scale
     * factor 2), so its height is the height of its rows, and returns the
     * cells as `x,y wxh` joined by ` | `.
     */
    function layout(render:() -> IntoElement, remSize:Float = 16):String {
        cells.resize(0);
        final root:glaze.AnyView = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> div().child(render())));
        final window = Window.open(app, {width: 600, height: 400, scaleFactor: 2, autoDraw: false, active: false, bindInput: false}, (_, _) -> root);
        windows.push(window);
        if (remSize != 16) window.setRemSize(remSize);
        app.update(_ -> window.draw());
        ceramic.App.app.flushImmediate();
        return [for (b in cells) '${b.origin.x},${b.origin.y} ${b.size.width}x${b.size.height}'].join(' | ');
    }

    function testFixedAndFraction() {
        // grid-template-columns: 140px 1fr, in 600 px
        assertEquals('0,0 140x30 | 140,0 460x30', layout(() -> div().grid().w(px(600)).gridTemplateCols([px(140), fr(1)])
            .child(cell(0).h(px(30))).child(cell(1).h(px(30)))));
    }

    function testFractionsShareTheFreeSpace() {
        // 1fr 2fr: 200 and 400; with a 30 px gap: 190 and 380
        assertEquals('0,0 200x30 | 200,0 400x30', layout(() -> div().grid().w(px(600)).gridTemplateCols([fr(1), fr(2)])
            .child(cell(0).h(px(30))).child(cell(1).h(px(30)))));
        assertEquals('0,0 190x30 | 220,0 380x30', layout(() -> div().grid().w(px(600)).gapX(px(30)).gridTemplateCols([fr(1), fr(2)])
            .child(cell(0).h(px(30))).child(cell(1).h(px(30)))));
    }

    function testAutoTakesTheContentWidth() {
        // auto 1fr with an 80 px item in the first column: 80 and 520
        assertEquals('0,0 80x30 | 80,0 520x30', layout(() -> div().grid().w(px(600)).gridTemplateCols([auto(), fr(1)])
            .child(cell(0).w(px(80)).h(px(30))).child(cell(1).h(px(30)))));
        // The widest item of the column decides (two rows): 120 and 480; the
        // 80 px item keeps its width at the start of its 120 px column
        assertEquals('0,0 80x30 | 120,0 480x30 | 0,30 120x30 | 120,30 480x30', layout(() -> div().grid().w(px(600)).gridTemplateCols([auto(), fr(1)])
            .child(cell(0).w(px(80)).h(px(30))).child(cell(1).h(px(30)))
            .child(cell(2).w(px(120)).h(px(30))).child(cell(3).h(px(30)))));
    }

    function testRemsMinmaxMaxContentAndAuto() {
        // 6rem minmax(0, 1fr) max-content auto, in 600 px, items of 50 and 30 px in
        // the last two columns: 96, 600 - 96 - 50 - 30 = 424, 50, 30
        final render:() -> IntoElement = () -> div().grid().w(px(600)).gridTemplateCols([rems(6), minmax(px(0), fr(1)), maxContent(), auto()])
            .child(cell(0).h(px(20))).child(cell(1).h(px(20))).child(cell(2).w(px(50)).h(px(20))).child(cell(3).w(px(30)).h(px(20)));
        assertEquals('0,0 96x20 | 96,0 424x20 | 520,0 50x20 | 570,0 30x20', layout(render));
        // Rems follow the rem size of the window: 6 x 20 = 120, 600 - 120 - 50 - 30 = 400
        assertEquals('0,0 120x20 | 120,0 400x20 | 520,0 50x20 | 570,0 30x20', layout(render, 20));
        // With a 10 px gap between the 4 columns: 600 - 96 - 50 - 30 - 30 = 394
        assertEquals('0,0 96x20 | 106,0 394x20 | 510,0 50x20 | 570,0 30x20', layout(() -> div().grid().w(px(600)).gapX(px(10))
            .gridTemplateCols([rems(6), minmax(px(0), fr(1)), maxContent(), auto()])
            .child(cell(0).h(px(20))).child(cell(1).h(px(20))).child(cell(2).w(px(50)).h(px(20))).child(cell(3).w(px(30)).h(px(20)))));
    }

    function testMinContentAndPercent() {
        // min-content 25% 1fr with a 70 px item: 70, 150, 380
        assertEquals('0,0 70x20 | 70,0 150x20 | 220,0 380x20', layout(() -> div().grid().w(px(600))
            .gridTemplateCols([minContent(), relative(0.25), fr(1)])
            .child(cell(0).w(px(70)).h(px(20))).child(cell(1).h(px(20))).child(cell(2).h(px(20)))));
    }

    function testMinmaxKeepsItsMinimum() {
        // minmax(100px, 1fr) twice in 150 px: the minimum wins, the grid overflows
        assertEquals('0,0 100x20 | 100,0 100x20', layout(() -> div().grid().w(px(150))
            .gridTemplateCols([minmax(px(100), fr(1)), minmax(px(100), fr(1))])
            .child(cell(0).h(px(20))).child(cell(1).h(px(20)))));
        // minmax(100px, 200px) and 1fr in 600 px: the first grows to its maximum
        assertEquals('0,0 200x20 | 200,0 400x20', layout(() -> div().grid().w(px(600))
            .gridTemplateCols([minmax(px(100), px(200)), fr(1)])
            .child(cell(0).h(px(20))).child(cell(1).h(px(20)))));
    }

    function testRows() {
        // grid-template-rows: 30px 1fr, in 200 px of height, one column
        assertEquals('0,0 600x30 | 0,30 600x170', layout(() -> div().grid().w(px(600)).h(px(200)).gridTemplateRows([px(30), fr(1)])
            .child(cell(0)).child(cell(1))));
        // Columns and rows together
        assertEquals('0,0 100x40 | 100,0 500x40 | 0,40 100x160 | 100,40 500x160', layout(() -> div().grid().w(px(600)).h(px(200))
            .gridTemplateCols([px(100), fr(1)]).gridTemplateRows([px(40), fr(1)])
            .child(cell(0)).child(cell(1)).child(cell(2)).child(cell(3))));
    }

    function testColSpanFull() {
        // A full width item, then a row of two
        assertEquals('0,0 600x20 | 0,20 140x20 | 140,20 460x20', layout(() -> div().grid().w(px(600)).gridTemplateCols([px(140), fr(1)])
            .child(cell(0).colSpanFull().h(px(20))).child(cell(1).h(px(20))).child(cell(2).h(px(20)))));
    }

    function testMoreItemsThanTracksWrapToNewRows() {
        assertEquals('0,0 140x20 | 140,0 460x20 | 0,20 140x20', layout(() -> div().grid().w(px(600)).gridTemplateCols([px(140), fr(1)])
            .child(cell(0).h(px(20))).child(cell(1).h(px(20))).child(cell(2).h(px(20)))));
    }

    function testTheRepeatFormIsUnchanged() {
        // GPUI's gridCols(3): repeat(3, minmax(0, 1fr))
        assertEquals('0,0 200x20 | 200,0 200x20 | 400,0 200x20', layout(() -> div().grid().w(px(600)).gridCols(3)
            .child(cell(0).h(px(20))).child(cell(1).h(px(20))).child(cell(2).h(px(20)))));
        final repeat = new GridTemplate(3);
        assertNull(repeat.tracks);
        assertTrue(repeat.equals(new GridTemplate(3)));
        assertFalse(repeat.equals(new GridTemplate(3, MinContent)));
    }

    function testTemplateEquality() {
        final a = GridTemplate.ofTracks([px(140), fr(1)]);
        assertEquals(2, a.repeat);
        assertTrue(a.equals(GridTemplate.ofTracks([px(140), fr(1)])));
        assertFalse(a.equals(GridTemplate.ofTracks([px(141), fr(1)])));
        assertFalse(a.equals(GridTemplate.ofTracks([px(140), fr(2)])));
        assertFalse(a.equals(GridTemplate.ofTracks([px(140), fr(1), auto()])));
        assertFalse(a.equals(new GridTemplate(2)));
        assertFalse(new GridTemplate(2).equals(a));
        assertTrue(GridTemplate.ofTracks([minmax(px(0), fr(1)), maxContent()]).equals(GridTemplate.ofTracks([minmax(px(0), fr(1)), maxContent()])));
        assertFalse(GridTemplate.ofTracks([minmax(px(0), fr(1))]).equals(GridTemplate.ofTracks([minmax(px(1), fr(1))])));
        // Conversions
        assertTrue((px(3):GridTrack).equals(GridTrack.px(3)));
        assertTrue((rems(2):GridTrack).equals(GridTrack.rems(2)));
        assertTrue((relative(0.5):GridTrack).equals(GridTrack.percent(0.5)));
        assertTrue((auto():GridTrack).equals(GridTrack.auto()));
        // The style refinement compares templates by value
        final x = div().gridTemplateCols([px(140), fr(1)]);
        final y = div().gridTemplateCols([px(140), fr(1)]);
        final z = div().gridTemplateCols([px(140), fr(2)]);
        assertTrue(x.style().equals(y.style()));
        assertFalse(x.style().equals(z.style()));
    }

}
