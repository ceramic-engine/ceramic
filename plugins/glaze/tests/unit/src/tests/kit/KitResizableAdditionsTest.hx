// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Context;
import glaze.Entity;
import glaze.Point;
import glaze.kit.base.resizable.PixelsRange;
import glaze.kit.base.resizable.ResizablePanel;
import glaze.kit.base.resizable.ResizableState;
import glaze.kit.resizable.Resizable;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The resizable additions without upstream equivalent (KIT-003): shrink
 * priorities, no handle before the first visible panel, the handle index
 * given to an appearance, and the callback during a drag.
 */
class KitResizableAdditionsTest extends KitAdditionsTestCase {

    function newState():Entity<ResizableState> {
        return app.update(cx -> cx.newEntity((_:Context<ResizableState>) -> new ResizableState()));
    }

    /**
     * A tree, an editor and a player side by side: the tree and the player
     * keep their widths, the editor takes the rest.
     */
    function workspace(width:Array<Float>, priorities:Bool, state:Entity<ResizableState>):VisualTestContext {
        return open((_, _) -> {
            final tree = Resizable.resizablePanel().size(px(200.)).fixed().sizeRange(new PixelsRange(px(100.), px(400.))).child(probe('tree', div().sizeFull()));
            final editor = Resizable.resizablePanel().sizeRange(new PixelsRange(px(200.), px(4000.))).child(probe('editor', div().sizeFull()));
            final player = Resizable.resizablePanel().size(px(300.)).fixed().sizeRange(new PixelsRange(px(150.), px(600.))).child(probe('player', div().sizeFull()));
            if (priorities) {
                tree.shrinkPriority(0);
                editor.shrinkPriority(2);
                player.shrinkPriority(1);
            }
            return div().w(px(width[0])).h(px(300.)).child(Resizable.hResizable('workspace').withState(state).children([tree, editor, player]));
        }, 1400, 400);
    }

    function widths(cx:VisualTestContext):String {
        return [for (selector in ['tree', 'editor', 'player']) Math.round(boundsOf(cx, selector).size.width * 100) / 100].join(',');
    }

    function resize(cx:VisualTestContext, width:Array<Float>, to:Float):String {
        width[0] = to;
        rerender(cx);
        for (_ in 0...3) draw(cx);
        return widths(cx);
    }

    function testPanelsShrinkInTheOrderOfTheirPriorities() {
        final width = [1000.];
        final state = newState();
        final cx = workspace(width, true, state);
        for (_ in 0...3) draw(cx);
        assertEquals('200,500,300', widths(cx));
        // The editor gives first, down to its minimum.
        assertEquals('200,300,300', resize(cx, width, 800.));
        assertEquals('200,200,300', resize(cx, width, 700.));
        // Then the player, then the tree.
        assertEquals('200,200,200', resize(cx, width, 600.));
        assertEquals('200,200,150', resize(cx, width, 550.));
        assertEquals('150,200,150', resize(cx, width, 500.));
        // Growing gives the tree and the player their widths back, the
        // panel that shrank last first, then the editor takes the rest.
        assertEquals('200,200,150', resize(cx, width, 550.));
        assertEquals('200,200,300', resize(cx, width, 700.));
        assertEquals('200,500,300', resize(cx, width, 1000.));
        assertEquals('200,700,300', resize(cx, width, 1200.));
    }

    function testADragKeepsTheNewSizesWhenTheContainerGrowsBack() {
        final width = [600.];
        final state = newState();
        final cx = workspace(width, true, state);
        for (_ in 0...3) draw(cx);
        assertEquals('200,200,200', widths(cx));
        // The user resizes while the player is squeezed: nothing is owed after that.
        cx.update((window, cx) -> state.update(cx, (state, cx) -> state.resizePanel(0, 150., window, cx)));
        for (_ in 0...3) draw(cx);
        assertEquals('150,250,200', widths(cx));
        assertEquals('150,650,200', resize(cx, width, 1000.));
    }

    function testWithoutPrioritiesTheFixedPanelsKeepTheirSizes() {
        final width = [1000.];
        final cx = workspace(width, false, newState());
        for (_ in 0...3) draw(cx);
        assertEquals('200,500,300', widths(cx));
        assertEquals('200,300,300', resize(cx, width, 800.));
        // gpui-kit's rule: the editor alone absorbs the change, here down to
        // its minimum, and the fixed panels are never taken from.
        resize(cx, width, 600.);
        assertEquals(200., boundsOf(cx, 'tree').size.width);
        assertEquals(300., boundsOf(cx, 'player').size.width);
        assertEquals('200,500,300', resize(cx, width, 1000.));
    }

    function handles(showFirst:Array<Bool>):{cx:VisualTestContext, indices:Array<Null<Int>>} {
        final indices:Array<Null<Int>> = [];
        final cx = open((_, _) -> {
            indices.resize(0);
            return div().w(px(600.)).h(px(200.)).child(Resizable.hResizable('group')
                .withHandleAppearance((handle, _, _) -> {
                    indices.push(handle.index());
                    return null;
                })
                .children([
                    Resizable.resizablePanel().visible(showFirst[0]).size(px(200.)).child(probe('first', div().sizeFull())),
                    Resizable.resizablePanel().size(px(200.)).child(probe('second', div().sizeFull())),
                    Resizable.resizablePanel().child(probe('third', div().sizeFull())),
                ]));
        });
        return {cx: cx, indices: indices};
    }

    function testAnAppearanceIsToldTheIndexOfItsHandle() {
        final h = handles([true]);
        rerender(h.cx);
        assertEquals('0,1', h.indices.join(','));
    }

    function testAHiddenFirstPanelLeavesNoHandleBehind() {
        final showFirst = [true];
        final h = handles(showFirst);
        showFirst[0] = false;
        rerender(h.cx);
        assertEquals('1', h.indices.join(','));
        // Nothing answers the pointer on the leading edge of the group.
        final second = boundsOf(h.cx, 'second');
        final sizes = (cx:VisualTestContext) -> [for (selector in ['second', 'third']) boundsOf(cx, selector).size.width].join(',');
        final before = sizes(h.cx);
        h.cx.simulateMouseDown(new Point(second.left() + 2., 50.), Left);
        h.cx.simulateMouseMove(new Point(second.left() + 20., 50.), Left);
        h.cx.simulateMouseMove(new Point(second.left() + 60., 50.), Left);
        h.cx.simulateMouseUp(new Point(second.left() + 60., 50.), Left);
        for (_ in 0...3) draw(h.cx);
        assertEquals(before, sizes(h.cx));

        showFirst[0] = true;
        rerender(h.cx);
        assertEquals('0,1', h.indices.join(','));
    }

    // KIT-013, KIT-014

    /** Two panels, 200 px then the rest of 400 px; `size` is the handle size (`null`: the default). */
    function pair(size:Null<Float>, width:Array<Float>, ?reported:Array<String>):VisualTestContext {
        final cx = open((_, _) -> {
            final group = Resizable.hResizable('group');
            if (size != null) group.handleSize(px(size));
            if (reported != null) group.onLayoutSizes((state, _, cx) -> reported.push(state.read(cx).sizes().join('/')));
            return div().w(px(width[0])).h(px(100.)).child(group.children([
                Resizable.resizablePanel().size(px(200.)).child(probe('first', div().sizeFull())),
                Resizable.resizablePanel().child(probe('second', div().sizeFull())),
            ]));
        });
        for (_ in 0...3) draw(cx);
        return cx;
    }

    /** The quads of the handle line: full height, starting at the boundary. */
    function lines(cx:VisualTestContext):Array<Float> {
        final border = cx.update((_, app) -> glaze.kit.theme.Theme.global(app).border);
        return [for (entry in quadsFilled(cx, border)) if (entry.bounds.size.height == 100. && entry.bounds.left() == 200.) entry.bounds.size.width];
    }

    function testHandleSizeSetsTheThicknessOfTheLine() {
        assertEquals('1', lines(pair(null, [400.])).join(','));
        assertEquals('1', lines(pair(1., [400.])).join(','));
        assertEquals(sceneSignature(pair(null, [400.])), sceneSignature(pair(1., [400.])));
        assertEquals('3', lines(pair(3., [400.])).join(','));
        // Zero: nothing is drawn
        final none = pair(0., [400.]);
        assertEquals('', lines(none).join(','));
        // The panels are where they were
        assertEquals(200., boundsOf(none, 'second').left());
        assertEquals(200., boundsOf(none, 'second').size.width);
    }

    function testAHandleOfSizeZeroStillResizes() {
        final cx = pair(0., [400.]);
        // The band is the 4 px on each side of the boundary
        for (start in [197., 203.]) {
            final boundary = boundsOf(cx, 'second').left();
            final from = boundary + (start - 200.);
            cx.simulateMouseDown(new Point(from, 50.), Left);
            cx.simulateMouseMove(new Point(from + 10., 50.), Left);
            cx.simulateMouseMove(new Point(boundary + 30., 50.), Left);
            cx.simulateMouseUp(new Point(boundary + 30., 50.), Left);
            for (_ in 0...3) draw(cx);
            assertEquals(boundary + 30., boundsOf(cx, 'second').left(), 'dragged from ${start}');
        }
        // Outside the band nothing moves
        final boundary = boundsOf(cx, 'second').left();
        cx.simulateMouseDown(new Point(boundary + 6., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 20., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 40., 50.), Left);
        cx.simulateMouseUp(new Point(boundary + 40., 50.), Left);
        for (_ in 0...3) draw(cx);
        assertEquals(boundary, boundsOf(cx, 'second').left());
    }

    function testOnLayoutSizesReportsAContainerResize() {
        final reported:Array<String> = [];
        final width = [400.];
        final cx = pair(null, width, reported);
        // Once for the first layout
        assertEquals(1, reported.length);
        // Nothing while nothing changes
        rerender(cx);
        for (_ in 0...3) draw(cx);
        assertEquals(1, reported.length);
        // The container grows: the sizes follow and are reported
        width[0] = 600.;
        rerender(cx);
        for (_ in 0...3) draw(cx);
        assertEquals(2, reported.length);
        final sizes = cx.update((_, _) -> [for (selector in ['first', 'second']) boundsOf(cx, selector).size.width].join('/'));
        assertEquals(sizes, reported[1]);
        assertEquals(600., boundsOf(cx, 'first').size.width + boundsOf(cx, 'second').size.width);
        // A drag is reported by `onResize`, not here
        final boundary = boundsOf(cx, 'second').left();
        cx.simulateMouseDown(new Point(boundary - 2., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 10., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 30., 50.), Left);
        cx.simulateMouseUp(new Point(boundary + 30., 50.), Left);
        for (_ in 0...3) draw(cx);
        assertEquals(2, reported.length);
    }

    function testOnResizingIsCalledDuringTheDrag() {
        final resizing:Array<String> = [];
        final resized = [0];
        final cx = open((_, _) -> div().w(px(400.)).h(px(100.)).child(Resizable.hResizable('group')
            .onResizing((state, _, cx) -> resizing.push(state.read(cx).sizes().join('/')))
            .onResize((_, _, _) -> resized[0]++)
            .children([
                Resizable.resizablePanel().size(px(200.)).child(probe('first', div().sizeFull())),
                Resizable.resizablePanel().child(probe('second', div().sizeFull())),
            ])));
        for (_ in 0...3) draw(cx);
        final boundary = boundsOf(cx, 'second').left();
        assertEquals(200., boundary);

        cx.simulateMouseDown(new Point(boundary - 2., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 10., 50.), Left);
        cx.simulateMouseMove(new Point(230., 50.), Left);
        cx.simulateMouseMove(new Point(250., 50.), Left);
        assertEquals(0, resized[0]);
        assertTrue(resizing.length >= 2, 'reported ${resizing.length} times');
        assertEquals('250/150', resizing[resizing.length - 1]);
        final during = resizing.length;
        cx.simulateMouseUp(new Point(250., 50.), Left);
        assertEquals(1, resized[0]);
        assertEquals(during, resizing.length);
        // Not without a drag.
        cx.simulateMouseMove(new Point(300., 50.));
        assertEquals(during, resizing.length);
    }

}
