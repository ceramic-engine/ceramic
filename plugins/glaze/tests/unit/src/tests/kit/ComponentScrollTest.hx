// Ported from gpui-kit 0.8.1: crates/component/src/scroll/scrollable.rs, scroll/mod.rs and
// virtual_list.rs (tests), crates/kit/tests/integration/interactions.rs (virtual list scrolling)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Div;
import glaze.Element;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.Size;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.Component;
import glaze.kit.VirtualList;
import glaze.kit.scroll.Scrollbar;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.scroll.Scrollable;

/**
 * The tests of gpui-component's `scroll` module (`Scrollable` and the
 * `overflow*Scrollbar` helpers), its re-exports, and the virtual list
 * scrolling test of gpui-kit's integration tests.
 *
 * Rust reads element bounds through `debug_selector` / `debug_bounds`; the
 * port records them with a `Probe` element wrapping the same `Div`.
 */
class ComponentScrollTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Component.init(cx));
        Probe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        Probe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        draw(opened.cx);
        return opened.cx;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    static function scroll(cx:VisualTestContext, x:Float, y:Float, dx:Float, dy:Float):Void {
        cx.simulateEvent(new ScrollEvent(new Point(x, y), Pixels(new Point(dx, dy))));
        draw(cx);
    }

    static function debugBounds(selector:String):Bounds {
        return Probe.bounds.get(selector);
    }

    static function row(selector:String, height:Float):IntoElement {
        return new Probe(selector, div().h(px(height)).flexShrink0());
    }

    static function plainRow(height:Float):Div {
        return div().h(px(height)).flexShrink0();
    }

    static function item(selector:String, width:Float):IntoElement {
        return new Probe(selector, div().w(px(width)).h(px(20.)).flexShrink0());
    }

    static function plainItem(width:Float):Div {
        return div().w(px(width)).h(px(20.)).flexShrink0();
    }

    function testUiScrollbarIsTheBaseType() {
        final handle = new ScrollHandle();
        final scrollbar:Scrollbar = Scrollbar.vertical(handle).styles(styles -> styles
            .track(style -> style.bg(transparentBlack()))
            .thumb(style -> style.bg(transparentBlack()))
            .thumbHover(style -> style.bg(transparentBlack()))
            .thumbActive(style -> style.bg(transparentBlack())));
        final base:glaze.kit.base.Scrollbar = scrollbar;
        assertTrue(base != null);
    }

    function testLegacyHandleIsTheBaseTypeAndAScrollbarHandle() {
        final handle:glaze.kit.VirtualList.VirtualListScrollHandle = new glaze.kit.base.VirtualList.VirtualListScrollHandle();
        final base:glaze.kit.base.VirtualList.VirtualListScrollHandle = handle;
        final asScrollbar:glaze.kit.scroll.Scrollbar.ScrollbarHandle = handle;
        assertTrue(base != null && asScrollbar != null);
    }

    function testVerticalScrollbarScrollsPastASizeFullChild() {
        final cx = open((_, _) -> div()
            .w(px(100.))
            .h(px(100.))
            .overflowYScrollbar()
            .child(div().sizeFull().child(vFlex().children([for (ix in 0...4) ix == 3 ? row('last-row', 50.) : plainRow(50.)]))));
        final initialY = debugBounds('last-row').origin.y;
        scroll(cx, 10., 10., 0., -50.);
        assertTrue(debugBounds('last-row').origin.y < initialY);
    }

    function testAutoHeightParentGetsContentHeight() {
        // Mimics Dialog: the panel height is auto (content-driven), the
        // body is flex_1 + overflow_hidden, and the scrollable content
        // should give the panel its intrinsic height.
        open((_, _) -> div().sizeFull().child(vFlex()
            .w(px(200.))
            .child(vFlex().flex1().overflowHidden().child(div().flex1().overflowHidden().child(vFlex()
                .sizeFull()
                .overflowYScrollbar()
                .child(plainRow(50.))
                .child(plainRow(50.)))))
            .child(row('auto-height-footer', 10.))));
        // The two 50px rows should push the footer down to y = 100.
        assertEquals(100., debugBounds('auto-height-footer').top());
    }

    function testMaxHeightParentClampsAndScrolls() {
        final cx = open((_, _) -> vFlex()
            .w(px(200.))
            .maxH(px(100.))
            .child(vFlex().flex1().overflowHidden().child(div().flex1().overflowHidden().child(vFlex()
                .sizeFull()
                .overflowYScrollbar()
                .child(plainRow(50.))
                .child(plainRow(50.))
                .child(row('max-height-last-row', 50.)))))
            .child(row('max-height-footer', 10.)));
        // Content (150) + footer (10) exceeds max_h(100): the footer is
        // pinned at the bottom and the body gets the remaining 90px viewport.
        assertEquals(90., debugBounds('max-height-footer').top());

        final lastInitialY = debugBounds('max-height-last-row').origin.y;
        scroll(cx, 10., 10., 0., -50.);
        assertTrue(debugBounds('max-height-last-row').origin.y < lastInitialY);
    }

    function testMaxHeightScrollableScrollsToItsLastRow() {
        final cx = open((_, _) -> hFlex().w(px(100.)).child(vFlex()
            .wFull()
            .child(plainRow(20.))
            .child(vFlex()
                .maxH(px(100.))
                .overflowYScrollbar()
                .child(row('max-size-first-row', 50.))
                .children([for (_ in 0...4) plainRow(50.)])
                .child(row('max-size-last-row', 50.)))
            .child(row('max-size-below', 20.))));

        final firstRow = debugBounds('max-size-first-row');
        final top = firstRow.top();
        // The area stops at its maximum height.
        assertEquals(100., debugBounds('max-size-below').top() - top);

        function scrollBy(dy:Float) {
            cx.simulateEvent(new ScrollEvent(firstRow.center(), Pixels(new Point(0., dy))));
            draw(cx);
        }
        // The rows past it scroll into view, down to the last one, which
        // ends at the area's bottom edge.
        scrollBy(-40.);
        assertEquals(-40., debugBounds('max-size-first-row').top() - top);
        scrollBy(-1000.);
        assertEquals(100., debugBounds('max-size-last-row').bottom() - top);
    }

    function testMaxWidthScrollableScrollsWhatOverflowsIt() {
        final cx = open((_, _) -> hFlex().h(px(20.)).child(hFlex()
            .maxW(px(100.))
            .overflowXScrollbar()
            .child(item('max-size-first-item', 50.))
            .children([for (_ in 0...5) plainItem(50.)])));
        final firstItem = debugBounds('max-size-first-item');
        cx.simulateEvent(new ScrollEvent(firstItem.center(), Pixels(new Point(-40., 0.))));
        draw(cx);
        assertEquals(-40., debugBounds('max-size-first-item').left() - firstItem.left());
    }

    function testScrollableFlexItemShrinksBelowItsContent() {
        final cx = open((_, _) -> vFlex()
            .w(px(100.))
            .h(px(100.))
            .child(row('flex-item-header', 20.))
            .child(vFlex()
                .flex1()
                .overflowYScrollbar()
                .children([for (ix in 0...6) ix == 0 ? row('flex-item-first-row', 50.) : plainRow(50.)]))
            .child(row('flex-item-footer', 20.)));
        // Header and footer stay inside the 100px column, so the area took
        // the 60px left over instead of its content height.
        assertEquals(0., debugBounds('flex-item-header').top());
        assertEquals(80., debugBounds('flex-item-footer').top());

        // And the shrunken area really scrolls.
        final initialY = debugBounds('flex-item-first-row').origin.y;
        scroll(cx, 10., 50., 0., -50.);
        assertTrue(debugBounds('flex-item-first-row').origin.y < initialY);
    }

    function horizontalFlexItem():VisualTestContext {
        return open((_, _) -> hFlex()
            .w(px(100.))
            .h(px(40.))
            .child(item('horizontal-flex-item-leading', 20.))
            .child(hFlex()
                .flex1()
                .overflowXScrollbar()
                .children([for (ix in 0...6) ix == 0
                    ? (new Probe('horizontal-flex-item-first-item', div().w(px(50.)).h(px(20.)).flexShrink0()) : IntoElement)
                    : div().w(px(50.)).h(px(20.)).flexShrink0()]))
            .child(item('horizontal-flex-item-trailing', 20.)));
    }

    function testHorizontalScrollableFlexItemShrinksBelowItsContent() {
        final cx = horizontalFlexItem();
        assertEquals(0., debugBounds('horizontal-flex-item-leading').left());
        assertEquals(80., debugBounds('horizontal-flex-item-trailing').left());

        final initialX = debugBounds('horizontal-flex-item-first-item').origin.x;
        scroll(cx, 50., 10., -50., 0.);
        assertTrue(debugBounds('horizontal-flex-item-first-item').origin.x < initialX);
    }

    function testHorizontalScrollableScrollsWithAVerticalMouseWheel() {
        final cx = horizontalFlexItem();
        final initialX = debugBounds('horizontal-flex-item-first-item').origin.x;
        cx.simulateEvent(new ScrollEvent(new Point(50., 10.), Lines(new Point(0., -1.))));
        draw(cx);
        assertTrue(debugBounds('horizontal-flex-item-first-item').origin.x < initialX);
    }

    function testExplicitMinSizeSurvivesTheScrollableWrapper() {
        open((_, _) -> vFlex()
            .w(px(100.))
            .h(px(100.))
            .child(row('explicit-min-header', 20.))
            .child(vFlex()
                .flex1()
                .minH(px(70.))
                .overflowYScrollbar()
                .children([for (_ in 0...6) plainRow(50.)]))
            .child(row('explicit-min-footer', 20.)));
        // The area cannot shrink past the requested 70px, so the footer is
        // pushed to 20 + 70 instead of being clamped into the column.
        assertEquals(0., debugBounds('explicit-min-header').top());
        assertEquals(90., debugBounds('explicit-min-footer').top());
    }

    function testScrollbarOverlayIgnoresContentPadding() {
        // The overlay is the `absolute().inset0()` div holding the
        // scrollbar; the port reads its bounds from the scrollbar's own
        // hitbox (its viewport from layout).
        var overlay:Null<Bounds> = null;
        final cx = open((_, _) -> vFlex()
            .w(px(100.))
            .h(px(100.))
            .p(px(20.))
            .overflowYScrollbar()
            .children([for (_ in 0...4) plainRow(50.)]));
        cx.update((window, _) -> {
            for (hitbox in @:privateAccess window.renderedFrame.hitboxes) {
                if (hitbox.bounds.size.width == 100. && hitbox.bounds.size.height == 100.) overlay = hitbox.bounds;
            }
            return null;
        });
        assertNotNull(overlay);
        assertTrue(overlay.origin.equals(new Point(0., 0.)));
        assertTrue(overlay.size.equals(new Size(100., 100.)));
    }

    function testVerticalScrollbarPreservesSourceGap() {
        open((_, _) -> vFlex()
            .w(px(100.))
            .h(px(100.))
            .gap(px(10.))
            .overflowYScrollbar()
            .child(row('first-row', 20.))
            .child(row('second-row', 20.)));
        assertEquals(10., debugBounds('second-row').top() - debugBounds('first-row').bottom());
    }

    function testOverflowYScrollbarPreservesGapForExactIssueChain() {
        final cx = open((_, _) -> div().w(px(100.)).h(px(100.)).child(vFlex()
            .flex1()
            .gap(px(30.))
            .overflowYScrollbar()
            .px(px(12.))
            .pb(px(16.))
            .children([for (ix in 0...5) switch ix {
                case 0: row('issue-first-card', 20.);
                case 1: row('issue-second-card', 20.);
                case 4: row('issue-last-card', 20.);
                case _: plainRow(20.);
            }])));
        final first = debugBounds('issue-first-card');
        final second = debugBounds('issue-second-card');
        final lastInitialY = debugBounds('issue-last-card').origin.y;
        assertEquals(30., second.top() - first.bottom());
        assertEquals(12., first.left());

        scroll(cx, 10., 10., 0., -50.);

        final firstAfter = debugBounds('issue-first-card');
        final secondAfter = debugBounds('issue-second-card');
        assertEquals(30., secondAfter.top() - firstAfter.bottom());
        assertEquals(12., firstAfter.left());
        assertTrue(debugBounds('issue-last-card').origin.y < lastInitialY);
    }

    function testHorizontalScrollbarPreservesSourceGapAndScrolls() {
        final cx = open((_, _) -> hFlex()
            .w(px(100.))
            .h(px(40.))
            .gap(px(10.))
            .overflowXScrollbar()
            .child(item('horizontal-first-item', 50.))
            .child(item('horizontal-second-item', 50.))
            .child(item('horizontal-last-item', 50.)));
        assertEquals(10., debugBounds('horizontal-second-item').left() - debugBounds('horizontal-first-item').right());
        final lastInitialX = debugBounds('horizontal-last-item').origin.x;

        scroll(cx, 10., 10., -50., 0.);

        assertEquals(10., debugBounds('horizontal-second-item').left() - debugBounds('horizontal-first-item').right());
        assertTrue(debugBounds('horizontal-last-item').origin.x < lastInitialX);
    }

    function testOverflowScrollbarPreservesVerticalSourceGap() {
        open((_, _) -> vFlex()
            .w(px(100.))
            .h(px(100.))
            .gap(px(10.))
            .overflowScrollbar()
            .child(row('both-axis-vertical-first-row', 50.))
            .child(row('both-axis-vertical-second-row', 50.))
            .child(row('both-axis-vertical-last-row', 50.)));
        assertEquals(10., debugBounds('both-axis-vertical-second-row').top() - debugBounds('both-axis-vertical-first-row').bottom());
    }

    function testOverflowScrollbarPreservesGapAndScrollsHorizontally() {
        final cx = open((_, _) -> hFlex()
            .w(px(100.))
            .h(px(40.))
            .gap(px(10.))
            .overflowScrollbar()
            .child(item('both-axis-horizontal-first-item', 50.))
            .child(item('both-axis-horizontal-second-item', 50.))
            .child(item('both-axis-horizontal-last-item', 50.)));
        assertEquals(10., debugBounds('both-axis-horizontal-second-item').left() - debugBounds('both-axis-horizontal-first-item').right());
        final lastInitialX = debugBounds('both-axis-horizontal-last-item').origin.x;

        scroll(cx, 10., 10., -50., 0.);

        assertEquals(10., debugBounds('both-axis-horizontal-second-item').left() - debugBounds('both-axis-horizontal-first-item').right());
        assertTrue(debugBounds('both-axis-horizontal-last-item').origin.x < lastInitialX);
    }

    function testMultipleScrollablesKeepIndependentScrollState() {
        final cx = open((_, _) -> hFlex()
            .w(px(220.))
            .h(px(100.))
            .gap(px(20.))
            .child(div().w(px(100.)).h(px(100.)).overflowYScrollbar().child(vFlex()
                .child(plainRow(50.))
                .child(plainRow(50.))
                .child(row('left-scrollable-last-row', 50.))))
            .child(div().w(px(100.)).h(px(100.)).overflowYScrollbar().child(vFlex()
                .child(plainRow(50.))
                .child(plainRow(50.))
                .child(row('right-scrollable-last-row', 50.)))));
        final leftInitial = debugBounds('left-scrollable-last-row');
        final rightInitial = debugBounds('right-scrollable-last-row');

        scroll(cx, 10., 10., 0., -50.);

        assertTrue(debugBounds('left-scrollable-last-row').top() < leftInitial.top());
        assertEquals(rightInitial.top(), debugBounds('right-scrollable-last-row').top());
    }

    function testVerticalScrollbarDoesNotScrollWhenContentDoesNotOverflow() {
        final cx = open((_, _) -> vFlex()
            .w(px(100.))
            .h(px(100.))
            .gap(px(10.))
            .overflowYScrollbar()
            .child(row('no-overflow-first-row', 20.))
            .child(row('no-overflow-second-row', 20.)));
        final first = debugBounds('no-overflow-first-row');
        final second = debugBounds('no-overflow-second-row');
        assertEquals(10., second.top() - first.bottom());

        scroll(cx, 10., 10., 0., -50.);

        assertEquals(first.top(), debugBounds('no-overflow-first-row').top());
        assertEquals(second.top(), debugBounds('no-overflow-second-row').top());
        assertEquals(10., debugBounds('no-overflow-second-row').top() - debugBounds('no-overflow-first-row').bottom());
    }

    function testHorizontalScrollbarDoesNotScrollWhenContentDoesNotOverflow() {
        final cx = open((_, _) -> hFlex()
            .w(px(100.))
            .h(px(40.))
            .gap(px(10.))
            .overflowXScrollbar()
            .child(item('no-overflow-first-item', 20.))
            .child(item('no-overflow-second-item', 20.))
            .child(plainItem(20.)));
        final first = debugBounds('no-overflow-first-item');
        final second = debugBounds('no-overflow-second-item');
        assertEquals(10., second.left() - first.right());

        scroll(cx, 10., 10., -50., 0.);

        assertEquals(first.left(), debugBounds('no-overflow-first-item').left());
        assertEquals(second.left(), debugBounds('no-overflow-second-item').left());
        assertEquals(10., debugBounds('no-overflow-second-item').left() - debugBounds('no-overflow-first-item').right());
    }

    function testDynamicScrollablesWithUniqueScrollIdsKeepIndependentState() {
        final cx = open((_, _) -> vFlex().w(px(100.)).children([for (ix in 0...2) hFlex()
            .w(px(100.))
            .h(px(40.))
            .overflowXScrollbar()
            .id('dynamic-scroll-$ix')
            .child(new Probe(ix == 0 ? 'dynamic-scroll-first' : 'dynamic-scroll-second', div().w(px(200.)).h(px(20.)).flexShrink0()))]));
        final firstInitial = debugBounds('dynamic-scroll-first');
        final secondInitial = debugBounds('dynamic-scroll-second');

        // Scroll horizontally inside the first row.
        scroll(cx, 10., 10., -50., 0.);

        assertTrue(debugBounds('dynamic-scroll-first').left() < firstInitial.left());
        assertEquals(secondInitial.left(), debugBounds('dynamic-scroll-second').left());
    }

    /**
     * `scrolling_a_real_virtual_list_registers_new_rows_and_releases_old_ones`
     * (crates/kit/tests/integration/interactions.rs): the test support query
     * API is not ported, so the rendered rows are read from the probes.
     */
    function testScrollingARealVirtualListRegistersNewRowsAndReleasesOldOnes() {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new VirtualRows(), 200, 200);
        contexts.push(opened.cx);
        final cx = opened.cx;
        draw(cx);
        assertTrue(Probe.bounds.exists('virtual-row-0'));
        assertFalse(Probe.bounds.exists('virtual-row-50'));
        Probe.bounds.clear();
        scroll(cx, 50., 30., 0., -1000.);
        assertTrue(Probe.bounds.exists('virtual-row-50'));
        assertFalse(Probe.bounds.exists('virtual-row-0'));
    }

}

/**
 * Records the bounds of the element it wraps under a selector (stands for
 * GPUI's test-only `debug_selector`).
 */
class Probe extends Element {

    public static final bounds:Map<String, Bounds> = new Map();

    final selector:String;

    final child:AnyElement;

    public function new(selector:String, child:IntoElement) {
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        Probe.bounds.set(selector, bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

private class VirtualRows extends Model implements Render {

    final scrollHandle = new glaze.kit.base.VirtualList.VirtualListScrollHandle();

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final entity:Entity<VirtualRows> = cx.entity();
        return div()
            .id('viewport')
            .w(px(100.))
            .h(px(60.))
            .child(VirtualList.vVirtualList(entity, 'rows', [for (_ in 0...1000) new Size(100., 20.)], (_, start, end, _, _) -> {
                return [for (index in start...end) (new Probe('virtual-row-$index', div().id('virtual-row-$index').h(px(20.)).child('Row $index')) : IntoElement)];
            }).trackScroll(scrollHandle));
    }

}
