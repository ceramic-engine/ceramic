package tests;

import glaze.App;
import glaze.AvailableSpace;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Size;
import glaze.SizeOf;
import glaze.TestDispatcher;
import glaze.VisualElement;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Computed sizes (specific to the Haxe port): `canvas().measure(fn)`,
 * `visual(v).measure(fn)`, and Ceramic views (plugin `ui`) measured by the
 * layout through `visual(view)`.
 *
 * A frame is played like Ceramic does: the layout pass of the views
 * (`ViewSystem`, order 7000), then the Glaze window (`GlazeSystem`, order
 * 10000), then the immediate callbacks (where `View.requestLayout()` runs
 * its pass), before anything is drawn.
 */
class VisualMeasureTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    var host:Null<glaze.Glaze> = null;

    var view:Null<MeasureTestView> = null;

    final created:Array<ceramic.Entity> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (host != null) {
            host.destroy();
            host = null;
        }
        else if (window != null) {
            window.destroy();
        }
        window = null;
        view = null;
        for (entity in created) {
            if (!entity.destroyed) entity.destroy();
        }
        created.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(width:Float, height:Float, render:(Window, Context<Dynamic>) -> IntoElement):Window {
        // Views created by the test can be laid out (`canLayout`)
        ceramic.App.app.flushImmediate();
        host = new glaze.Glaze((window, cx) -> {
            final entity = cx.newEntity((_:Context<MeasureTestView>) -> new MeasureTestView(render));
            view = entity;
            return entity;
        }, {width: width, height: height, autoDraw: false, scaleFactor: 1, renderToTexture: true}, app);
        host.pos(0, 0);
        ceramic.App.app.screen.add(host);
        window = host.window;
        window.draw();
        ceramic.App.app.flushImmediate();
        return window;
    }

    /** One Ceramic frame, up to the drawing */
    function frame():Void {
        #if plugin_ui
        @:privateAccess ceramic.View._updateViewsLayout(0);
        #end
        ceramic.App.app.flushImmediate();
        window.drawIfDirty();
        ceramic.App.app.flushImmediate();
    }

    function refresh():Void {
        final entity:Entity<MeasureTestView> = view;
        entity.update(app, (_, cx) -> cx.notify());
    }

    function quad(width:Float, height:Float):ceramic.Quad {
        final q = new ceramic.Quad();
        q.size(width, height);
        created.push(q);
        return q;
    }

/// canvas().measure(fn)

    function testCanvasMeasureGetsTheConstraintsAndItsSizeIsUsed() {
        final knownWidths:Array<Null<Float>> = [];
        final availableWidths:Array<AvailableSpace> = [];
        var painted:Null<Bounds> = null;
        open(300, 200, (_, _) -> div().flex().flexCol().itemsStart().w(px(300.)).h(px(200.))
            .child(canvas((_, _, _) -> null, (bounds, _, _, _) -> painted = bounds)
                .measure((known, available, window, cx) -> {
                    knownWidths.push(known.width);
                    availableWidths.push(available.width);
                    return size(px(120.), px(48.));
                })));
        assertTrue(knownWidths.length > 0, 'the measure is called');
        // Nothing imposed: a free width, at most the 300 pixels of the column
        for (known in knownWidths) assertTrue(known == null);
        var definite = false;
        for (space in availableWidths) {
            switch space {
                case Definite(n): if (n == 300) definite = true;
                case _:
            }
        }
        assertTrue(definite, 'asked with the available width of the column: $availableWidths');
        assertEquals(120.0, painted.size.width);
        assertEquals(48.0, painted.size.height);
    }

    function testCanvasMeasureInARowIsAskedItsContentSizes() {
        final availableWidths:Array<AvailableSpace> = [];
        var painted:Null<Bounds> = null;
        open(300, 200, (_, _) -> div().flex().itemsStart().w(px(300.)).h(px(200.))
            .child(canvas((_, _, _) -> null, (bounds, _, _, _) -> painted = bounds)
                .measure((known, available, window, cx) -> {
                    availableWidths.push(available.width);
                    return size(px(120.), px(48.));
                })));
        // A row asks the ideal and the smallest widths of its children
        assertTrue(availableWidths.indexOf(MaxContent) != -1, '$availableWidths');
        assertTrue(availableWidths.indexOf(MinContent) != -1, '$availableWidths');
        assertEquals(120.0, painted.size.width);
        assertEquals(48.0, painted.size.height);
    }

    function testCanvasMeasureKnowsTheWidthOfItsStyle() {
        final knownWidths:Array<Null<Float>> = [];
        var painted:Null<Bounds> = null;
        open(300, 200, (_, _) -> div().flex().itemsStart().w(px(300.)).h(px(200.))
            .child(canvas((_, _, _) -> null, (bounds, _, _, _) -> painted = bounds)
                .w(px(200.))
                .measure((known, available, window, cx) -> {
                    knownWidths.push(known.width);
                    final width:Float = known.width != null ? known.width : 400;
                    // Half as high as wide
                    return size(px(width), px(width / 2));
                })));
        assertTrue(knownWidths.indexOf(200.0) != -1, 'asked with the width of the style: $knownWidths');
        assertEquals(200.0, painted.size.width);
        assertEquals(100.0, painted.size.height);
    }

    function testCanvasMeasuredAgainWhenItsViewRendersAgain() {
        var rows = 2;
        var painted:Null<Bounds> = null;
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull()
            .child(canvas((_, _, _) -> null, (bounds, _, _, _) -> painted = bounds)
                .measure((known, available, window, cx) -> size(px(50.), px(rows * 24.)))));
        assertEquals(48.0, painted.size.height);
        rows = 5;
        refresh();
        frame();
        assertEquals(120.0, painted.size.height);
    }

/// visual(v).measure(fn)

    function testVisualMeasureComputesTheSizeOfAnyVisual() {
        final content = quad(30, 12);
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull()
            .child(visual(content).measure((known, available, window, cx) -> {
                final width:Float = known.width != null ? known.width : 120;
                return size(px(width), px(80.));
            })));
        assertEquals(120.0, VisualElement.contentWidth(content));
        assertEquals(80.0, VisualElement.contentHeight(content));
        // The visual itself is left as it is
        assertEquals(30.0, content.width);
    }

    function testVisualWithoutMeasureKeepsItsOwnSize() {
        final content = quad(30, 12);
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull().child(visual(content)));
        assertEquals(30.0, VisualElement.contentWidth(content));
        assertEquals(12.0, VisualElement.contentHeight(content));
    }

#if plugin_ui
/// Ceramic views measured by the layout

    function texture(width:Float, height:Float):ceramic.RenderTexture {
        final texture = new ceramic.RenderTexture(width, height, 1);
        created.push(texture);
        return texture;
    }

    function imageView(width:Float, height:Float):ceramic.ImageView {
        final image = new ceramic.ImageView();
        image.setImageTexture(texture(width, height));
        created.push(image);
        return image;
    }

    function textView(content:String):CountingTextView {
        final text = new CountingTextView();
        text.content = content;
        text.pointSize = 20;
        created.push(text);
        return text;
    }

    function box(width:Float, height:Float):ceramic.View {
        final box = new ceramic.View();
        box.viewSize(width, height);
        return box;
    }

    static final SHORT = 'Short';

    static final LONG = 'A much longer text that does not fit in one line of the column and wraps into several lines of it';

    function testImageViewWithAWidthFollowsItsRatio() {
        final image = imageView(40, 20);
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull().child(visual(image).w(px(200.))));
        assertEquals(200.0, VisualElement.contentWidth(image));
        assertEquals(100.0, VisualElement.contentHeight(image));
        assertEquals(200.0, image.width);
        assertEquals(100.0, image.height);
    }

    function testImageViewWithAHeightFollowsItsRatio() {
        final image = imageView(40, 20);
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull().child(visual(image).h(px(50.))));
        assertEquals(100.0, VisualElement.contentWidth(image));
        assertEquals(50.0, VisualElement.contentHeight(image));
    }

    function testImageViewWithItsOwnSizeKeepsIt() {
        final image = imageView(40, 20);
        image.viewSize(40, 20);
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull().child(visual(image)));
        assertEquals(40.0, VisualElement.contentWidth(image));
        assertEquals(20.0, VisualElement.contentHeight(image));
        assertEquals(40.0, image.width);
        assertEquals(20.0, image.height);
    }

    /**
     * Documented limit: Ceramic's `ImageView` has no natural size of its
     * own (`autoComputeSize()` gives 0 x 0 whatever its texture): it needs
     * one dimension, from the Glaze style or from `viewSize()`.
     */
    function testImageViewWithoutAnyDimensionHasNoNaturalSize() {
        final image = imageView(40, 20);
        image.autoComputeSizeIfNeeded();
        assertEquals(0.0, image.computedSize.computedWidth);
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull().child(visual(image)));
        assertEquals(0.0, VisualElement.contentWidth(image));
    }

    function testLinearLayoutTakesTheSizeOfItsChildren() {
        final layout = new ceramic.LinearLayout();
        created.push(layout);
        layout.direction = VERTICAL;
        layout.itemSpacing = 4;
        layout.add(box(80, 30));
        layout.add(box(120, 30));
        var label:Null<Bounds> = null;
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull()
            .child(visual(layout))
            .child(canvas((_, _, _) -> null, (bounds, _, _, _) -> label = bounds).w(px(10.)).h(px(10.))));
        // As wide as its widest child, as high as the sum
        assertEquals(120.0, VisualElement.contentWidth(layout));
        assertEquals(64.0, VisualElement.contentHeight(layout));
        // The Glaze element next to it starts after it
        assertEquals(120.0, label.origin.x);
        // Its children are placed (laid out in the same frame)
        assertEquals(34.0, layout.subviews[1].y);
    }

    function testNarrowTextKeepsItsNaturalWidthAndWideTextWraps() {
        final narrow = textView(SHORT);
        final wide = textView(LONG);
        open(600, 400, (_, _) -> div().flex().flexCol().itemsStart().w(px(300.))
            .child(visual(narrow))
            .child(visual(wide)));
        final lineHeight = VisualElement.contentHeight(narrow);
        assertTrue(lineHeight > 0);
        final narrowWidth = VisualElement.contentWidth(narrow);
        assertTrue(narrowWidth > 0 && narrowWidth < 300, 'the narrow text keeps its natural width: $narrowWidth');
        assertEquals(300.0, VisualElement.contentWidth(wide));
        assertTrue(VisualElement.contentHeight(wide) >= lineHeight * 2, 'the wide text wraps: ${VisualElement.contentHeight(wide)} for lines of $lineHeight');
        // The text of the view wraps in the width of the element, in this frame
        assertEquals(300.0, wide.text.fitWidth);
        assertEquals(300.0, wide.width);
        assertTrue(wide.text.height >= lineHeight * 2);
    }

    function testTextInABlockColumnWrapsInItsWidth() {
        final wide = textView(LONG);
        open(600, 400, (_, _) -> div().w(px(300.)).child(visual(wide)));
        assertEquals(300.0, VisualElement.contentWidth(wide));
        assertEquals(300.0, wide.text.fitWidth);
        assertTrue(VisualElement.contentHeight(wide) >= 40);
    }

    function testRepeatedQuestionsUseTheCacheOfTheView() {
        final text = textView(LONG);
        open(600, 400, (_, _) -> div().flex().flexCol().itemsStart().w(px(300.)).child(visual(text)));
        frame();
        final host = @:privateAccess glaze.VisualHost.hosts.get(text);
        final known = new SizeOf<Null<Float>>(250., null);
        final available = new SizeOf<AvailableSpace>(MaxContent, MaxContent);
        final computes = text.computes;
        final first:Size = @:privateAccess host.viewMeasure(known, available, window, app);
        assertEquals(computes + 1, text.computes);
        final second:Size = @:privateAccess host.viewMeasure(known, available, window, app);
        final third:Size = @:privateAccess host.viewMeasure(known, available, window, app);
        // Asked once, answered from the cache then
        assertEquals(computes + 1, text.computes);
        assertEquals(250.0, first.width);
        assertEquals(first.height, second.height);
        assertEquals(first.height, third.height);
        frame();
    }

    function testNoLoopAfterAStableFrame() {
        final text = textView(LONG);
        final layout = new ceramic.LinearLayout();
        created.push(layout);
        layout.add(box(80, 30));
        final inner = textView(SHORT);
        layout.add(inner);
        var layouts = 0;
        text.onLayout(null, () -> layouts++);
        layout.onLayout(null, () -> layouts++);
        countsRenders();
        open(600, 400, (_, _) -> div().flex().flexCol().itemsStart().w(px(300.))
            .child(visual(text))
            .child(visual(layout)));
        frame();
        frame();
        final draws = window.drawCount;
        final passes = layouts;
        final computes = text.computes + inner.computes;
        final relayouts = @:privateAccess glaze.VisualHost.viewRelayoutCount;
        for (_ in 0...5) frame();
        // Nothing left to do: no Ceramic layout pass, no size computed, no Glaze draw
        assertEquals(passes, layouts);
        assertEquals(computes, text.computes + inner.computes);
        assertEquals(draws, window.drawCount);
        assertEquals(relayouts, @:privateAccess glaze.VisualHost.viewRelayoutCount);
        assertFalse(window.dirty);
        assertFalse(text.layoutDirty);
        assertFalse(layout.layoutDirty);
        assertFalse(inner.layoutDirty);
    }

    function testGlazeLayoutAloneRequestsNoRelayout() {
        final text = textView(LONG);
        open(600, 400, (_, _) -> div().flex().flexCol().itemsStart().w(px(300.)).child(visual(text)));
        frame();
        final relayouts = @:privateAccess glaze.VisualHost.viewRelayoutCount;
        // The Glaze view renders again with the same sizes: its measures and
        // the final size run a Ceramic pass, which changes nothing
        for (_ in 0...3) {
            refresh();
            frame();
            frame();
        }
        assertEquals(relayouts, @:privateAccess glaze.VisualHost.viewRelayoutCount);
        assertFalse(window.dirty);
        assertEquals(300.0, text.text.fitWidth);
    }

    function testContentLaidOutInTheFrameOfTheResize() {
        final layout = new ceramic.LinearLayout();
        created.push(layout);
        final child = new ceramic.View();
        child.viewSize(ceramic.ViewSize.fill(), 30);
        layout.add(child);
        final text = textView(LONG);
        var width = 200.0;
        open(600, 400, (_, _) -> div().flex().flexCol().itemsStart().sizeFull()
            .child(visual(layout).w(px(width)))
            .child(visual(text).w(px(width))));
        assertEquals(200.0, layout.width);
        assertEquals(200.0, child.width);
        assertEquals(200.0, text.text.fitWidth);
        final height = VisualElement.contentHeight(text);
        width = 320;
        refresh();
        frame();
        // One frame: the element, the view and its content have the new width
        assertEquals(320.0, VisualElement.contentWidth(layout));
        assertEquals(320.0, layout.width);
        assertEquals(320.0, child.width);
        assertEquals(320.0, text.width);
        assertEquals(320.0, text.text.fitWidth);
        assertTrue(VisualElement.contentHeight(text) < height, 'fewer lines in a wider column');
        assertFalse(layout.layoutDirty);
        assertFalse(child.layoutDirty);
    }

    function testLongerTextLaysOutItsBranchAgainOnly() {
        final text = textView(SHORT);
        var innerRenders = 0;
        var siblingRenders = 0;
        var inner:Null<Entity<MeasureTestView>> = null;
        var sibling:Null<Entity<MeasureTestView>> = null;
        var below:Null<Bounds> = null;
        countsRenders();
        open(600, 400, (window, cx) -> {
            if (inner == null) inner = cx.newEntity((_:Context<MeasureTestView>) -> new MeasureTestView((_, _) -> {
                innerRenders++;
                return div().flex().flexCol().itemsStart().w(px(300.))
                    .child(visual(text))
                    .child(canvas((_, _, _) -> null, (bounds, _, _, _) -> below = bounds).w(px(10.)).h(px(10.)));
            }));
            if (sibling == null) sibling = cx.newEntity((_:Context<MeasureTestView>) -> new MeasureTestView((_, _) -> {
                siblingRenders++;
                return div().w(px(50.)).h(px(20.));
            }));
            return div().sizeFull().flex().itemsStart().child(inner).child(sibling);
        });
        frame();
        final lineHeight = VisualElement.contentHeight(text);
        assertEquals(lineHeight, below.origin.y);
        final inners = innerRenders;
        final siblings = siblingRenders;
        final relayouts = @:privateAccess glaze.VisualHost.viewRelayoutCount;

        // Ceramic content changes: nothing tells Glaze but the layout of the view
        text.content = LONG;
        frame();
        assertEquals(relayouts + 1, @:privateAccess glaze.VisualHost.viewRelayoutCount);
        assertEquals(inners + 1, innerRenders);
        assertEquals(siblings, siblingRenders);
        assertEquals(300.0, VisualElement.contentWidth(text));
        final height = VisualElement.contentHeight(text);
        assertTrue(height >= lineHeight * 2);
        // What follows it in Glaze moved down
        assertEquals(height, below.origin.y);
        assertEquals(300.0, text.text.fitWidth);

        // Settled: nothing more
        for (_ in 0...3) frame();
        assertEquals(relayouts + 1, @:privateAccess glaze.VisualHost.viewRelayoutCount);
        assertEquals(inners + 1, innerRenders);
        assertEquals(siblings, siblingRenders);
    }

    function testChildAddedToALayoutGrowsTheElement() {
        final layout = new ceramic.LinearLayout();
        created.push(layout);
        layout.add(box(80, 30));
        open(300, 200, (_, _) -> div().flex().itemsStart().sizeFull().child(visual(layout)));
        frame();
        assertEquals(30.0, VisualElement.contentHeight(layout));
        layout.add(box(100, 20));
        ceramic.App.app.flushImmediate();
        frame();
        frame();
        assertEquals(100.0, VisualElement.contentWidth(layout));
        assertEquals(50.0, VisualElement.contentHeight(layout));
        assertEquals(50.0, layout.height);
    }

    function testViewInAShrinkingRowKeepsItsNaturalWidth() {
        final text = textView(LONG);
        final other = textView(LONG);
        var natural = 0.0;
        open(900, 400, (_, _) -> div().flex().flexCol().itemsStart().sizeFull()
            // A row of 200 pixels shrinking its children: the view does not shrink (documented limit)
            .child(div().flex().w(px(200.)).child(visual(text)))
            // With a width from the Glaze style, it does
            .child(div().flex().w(px(200.)).child(visual(other).flex1().minW0())));
        text.autoComputeSizeIfNeeded();
        natural = text.computedSize.computedWidth;
        frame();
        assertTrue(natural > 200, 'the text is wider than the row: $natural');
        assertEquals(natural, VisualElement.contentWidth(text));
        assertEquals(200.0, VisualElement.contentWidth(other));
        assertEquals(200.0, other.text.fitWidth);
    }

    function testTallViewOverflowsAScrollArea() {
        final layout = new ceramic.LinearLayout();
        created.push(layout);
        layout.add(box(80, 150));
        layout.add(box(80, 150));
        open(300, 200, (_, _) -> div().id('scroll').w(px(200.)).h(px(100.)).overflowYScroll().child(visual(layout)));
        // The height is not limited to the area (it scrolls), like the height of a text
        assertEquals(300.0, VisualElement.contentHeight(layout));
    }

    function testNativeResolutionKeepsTheFixedSize() {
        final text = textView(LONG);
        text.size(64, 32);
        open(600, 400, (_, _) -> div().flex().itemsStart().sizeFull().child(visual(text).nativeResolution()));
        assertEquals(64.0, VisualElement.contentWidth(text));
        assertEquals(32.0, VisualElement.contentHeight(text));
        assertFalse(text.listensLayout());
    }

    function testListenerUnboundWhenTheElementIsDropped() {
        final text = textView(SHORT);
        var show = true;
        open(600, 400, (_, _) -> div().flex().itemsStart().sizeFull().child(show ? visual(text) : div()));
        frame();
        assertTrue(text.listensLayout());
        final hosts = VisualElement.hostCount();
        show = false;
        refresh();
        frame();
        assertFalse(text.listensLayout());
        final relayouts = @:privateAccess glaze.VisualHost.viewRelayoutCount;
        // Changes of a view not shown anymore reach nobody
        text.content = LONG;
        frame();
        frame();
        assertEquals(relayouts, @:privateAccess glaze.VisualHost.viewRelayoutCount);
        assertEquals(hosts, VisualElement.hostCount());
        // Shown again: listening again, with the new size
        show = true;
        refresh();
        frame();
        assertTrue(text.listensLayout());
        assertTrue(VisualElement.contentWidth(text) > 100);
    }

    function testHostOfAMeasuredViewNeverPaintedIsReleased() {
        final text = textView(SHORT);
        final initialGrace = VisualElement.gracePeriodFrames;
        VisualElement.gracePeriodFrames = 2;
        final hosts = VisualElement.hostCount();
        // Laid out, never painted (no element id reaches prepaint without a view): measured by hand
        final host = @:privateAccess glaze.VisualHost.obtainForMeasure(text);
        assertEquals(hosts + 1, VisualElement.hostCount());
        for (_ in 0...4) @:privateAccess glaze.VisualHost.tick();
        assertEquals(hosts, VisualElement.hostCount());
        assertFalse(text.destroyed);
        VisualElement.gracePeriodFrames = initialGrace;
    }

    function testCachedViewKeepsTheMeasuredViewVerified() {
        final text = textView(LONG);
        var inner:Null<Entity<MeasureTestView>> = null;
        var width = 60.0;
        open(600, 400, (window, cx) -> {
            if (inner == null) inner = cx.newEntity((_:Context<MeasureTestView>) -> new MeasureTestView((_, _) ->
                div().flex().flexCol().itemsStart().w(px(300.)).child(visual(text))));
            return div().sizeFull().flex().itemsStart().child(inner).child(div().w(px(width)).h(px(10.)));
        });
        frame();
        final height = VisualElement.contentHeight(text);
        // The root renders again, the inner view comes from the cache (and is
        // compared with a real rendering by the cache check of the suite)
        for (i in 0...3) {
            width = 30 + i;
            refresh();
            frame();
            frame();
        }
        assertEquals(300.0, VisualElement.contentWidth(text));
        assertEquals(height, VisualElement.contentHeight(text));
        assertEquals(300.0, text.text.fitWidth);
        assertTrue(text.listensLayout());
    }

    #if glaze_verify_layout
    function testIncrementalLayoutCheckFindsNoDifference() {
        final errors = glaze.TaffyLayoutEngine.verifyLayoutErrors;
        final text = textView(SHORT);
        var inner:Null<Entity<MeasureTestView>> = null;
        open(600, 400, (window, cx) -> {
            if (inner == null) inner = cx.newEntity((_:Context<MeasureTestView>) -> new MeasureTestView((_, _) ->
                div().flex().flexCol().itemsStart().w(px(300.)).child(visual(text)).child(div().w(px(10.)).h(px(10.)))));
            return div().sizeFull().flex().itemsStart().child(inner).child(div().w(px(20.)).h(px(10.)));
        });
        frame();
        text.content = LONG;
        frame();
        frame();
        text.content = SHORT;
        frame();
        frame();
        assertEquals(errors, glaze.TaffyLayoutEngine.verifyLayoutErrors);
    }
    #end
#end

}

class MeasureTestView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}

#if plugin_ui
/** A `TextView` counting the sizes it really computes */
class CountingTextView extends ceramic.TextView {

    public var computes:Int = 0;

    override function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ceramic.ViewLayoutMask, persist:Bool) {
        computes++;
        super.computeSize(parentWidth, parentHeight, layoutMask, persist);
    }

}
#end
