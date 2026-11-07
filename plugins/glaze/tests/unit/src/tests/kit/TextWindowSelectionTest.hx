// Ported from gpui-kit 0.8.1: crates/component/src/text/window_selection.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

#if !macro
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Element;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.GlobalElementId;
import glaze.Hitbox;
import glaze.HitboxBehavior;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.ListOffset;
import glaze.Model;
import glaze.Modifiers;
import glaze.Point;
import glaze.Render;
import glaze.ScrollEvent;
import glaze.Style;
import glaze.StyleBuilder;
import glaze.StyledText;
import glaze.Window;
import glaze.kit.base.AutoScroll;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.GlobalState;
import glaze.kit.base.Root;
import glaze.kit.base.TextSelection;
import glaze.kit.base.TextSelectionHandle;
import glaze.kit.base.TextSelectionRegistration;
import glaze.kit.base.TextSelectionRun;
import glaze.kit.base.text.SelectionFormat;
import glaze.kit.base.text.TextViewState;
import glaze.kit.Component;
import glaze.kit.text.TextView;
import glaze.kit.text.TextViewStyle;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.WindowExt;

/** Rust `PlainSelectableText`: a `StyledText` registered as a window selection participant. */
private class PlainSelectableText extends Element {
    final selection:TextSelectionHandle;
    final text:String;
    final styledText:StyledText;
    var order:Int = 0;

    public function new(selection:TextSelectionHandle, text:String) {
        this.selection = selection;
        this.text = text;
        this.styledText = new StyledText(text);
    }

    public function documentOrder(documentOrder:Int):PlainSelectableText {
        this.order = documentOrder;
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return styledText.requestLayout(id, window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        styledText.prepaint(id, bounds, window, cx);
        final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        selection.register(new TextSelectionRegistration(hitbox, bounds).withDocumentOrder(order).withTextBounds([bounds]), window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final layout = styledText.layout();
        selection.updateRuns([new TextSelectionRun(text, layout, bounds).withDocumentOrder(0)], cx);
        styledText.paint(id, bounds, window, cx);
    }
}

private class MixedAdapterView extends Model implements Render {
    final plainSelection:TextSelectionHandle;
    final textView:Entity<TextViewState>;

    public function new(cx:Context<MixedAdapterView>) {
        super();
        plainSelection = TextSelectionHandle.create("", cx.app);
        textView = cx.newEntity(cx -> TextViewState.markdown("TextView adapter", cx));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .pt(px(10.))
            .child(div().h(px(40.)).child(new PlainSelectableText(plainSelection, "Plain adapter")))
            .child(div().h(px(40.)).child(TextView.create(textView).selectable(true)));
    }
}

private class CrossRendererVirtualView extends Model implements Render {
    final topSelection:TextSelectionHandle;
    final bottomSelection:TextSelectionHandle;
    public final textView:Entity<TextViewState>;
    final format:SelectionFormat;

    public function new(format:SelectionFormat, cx:Context<CrossRendererVirtualView>) {
        super();
        final source = [for (ix in 0...20) '**Paragraph$ix**'].join("\n\n");
        topSelection = TextSelectionHandle.create("", cx.app);
        bottomSelection = TextSelectionHandle.create("", cx.app);
        textView = cx.newEntity(cx -> TextViewState.markdown(source, cx));
        this.format = format;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .pt(px(10.))
            .child(div().h(px(40.)).child(new PlainSelectableText(topSelection, "Top plain").documentOrder(0)))
            .child(div().h(px(80.)).child(TextView.create(textView).selectable(true).scrollable(true).selectionFormat(format)))
            .child(div().h(px(40.)).child(new PlainSelectableText(bottomSelection, "Bottom plain").documentOrder(2)));
    }
}

private enum CrossRendererVirtualScenario {
    PlainToVirtualTail;
    VirtualHeadToPlain;
    VirtualInMiddle;
}

private class BaseOwnedTextViewSelection extends Model implements Render {
    public final textView:Entity<TextViewState>;

    public function new(cx:Context<BaseOwnedTextViewSelection>) {
        super();
        textView = cx.newEntity(cx -> TextViewState.markdown("Single authority", cx));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().pt(px(10.)).child(div().h(px(40.)).child(TextView.create(textView).selectable(true)));
    }
}

private class ChatTestView extends Model implements Render {
    final focusHandle:FocusHandle;
    public final first:Entity<TextViewState>;
    public final second:Entity<TextViewState>;
    final secondSelectable:Bool;
    /**
     * Top padding above the views. Bumping it shifts the whole content down,
     * which is the layout-level equivalent of an outer container scrolling.
     */
    public var topOffset:Float = 10.;
    /** Blank gap between the two views (the proxy-anchored endpoint path). */
    public var midGap:Float = 0.;
    public final firstStyle:TextViewStyle = TextViewStyle.defaultValue();

    public function new(secondSelectable:Bool, cx:Context<ChatTestView>) {
        super();
        focusHandle = cx.focusHandle();
        first = cx.newEntity(cx -> TextViewState.markdown("Hello world", cx));
        second = cx.newEntity(cx -> TextViewState.markdown("Second message", cx));
        this.secondSelectable = secondSelectable;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        // `trackFocus` makes the root a focusable container, so GPUI's
        // focus-on-mouse-down marks every press inside it default-prevented.
        return div()
            .trackFocus(focusHandle)
            .sizeFull()
            .pt(px(topOffset))
            .child(div().h(px(40.)).child(TextView.create(first).selectable(true).withStyle(firstStyle.clone())))
            .child(div().h(px(midGap)))
            .child(div().h(px(40.)).child(TextView.create(second).selectable(secondSelectable)))
            // A 20px row that owns its press the way Input/Button do.
            .child(div().h(px(20.)).onMouseDown(Left, (_, _, cx) -> GlobalState.suppressTextSelection(cx)));
    }
}

private class ScrollableTextViewTest extends Model implements Render {
    public final textView:Entity<TextViewState>;
    final format:Null<SelectionFormat>;

    public function new(textView:Entity<TextViewState>, ?format:SelectionFormat) {
        super();
        this.textView = textView;
        this.format = format;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        var view = TextView.create(textView).selectable(true).scrollable(true);
        if (format != null) view = view.selectionFormat(format);
        return div().sizeFull().child(div().h(px(60.)).child(view));
    }
}

private class AutoScrollTextViewTest extends Model implements Render {
    public final textView:Entity<TextViewState>;

    public function new(textView:Entity<TextViewState>) {
        super();
        this.textView = textView;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(new DebugProbe("scrollable-text-view", div()
            .h(px(300.))
            .overflowHidden()
            .child(TextView.create(textView).flexNone().px5().selectable(true).scrollable(true))));
    }
}

/**
 * The reader layout from the field report: a clipping row that centers a
 * vertically padded, full-height scrollable TextView.
 */
private class PaddedReaderAutoScrollTest extends Model implements Render {
    public final textView:Entity<TextViewState>;

    public function new(textView:Entity<TextViewState>) {
        super();
        this.textView = textView;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(new DebugProbe("reader", div()
            .flex()
            .flexRow()
            .h(px(300.))
            .minW(px(0.))
            .overflowHidden()
            .justifyCenter()
            .child(TextView.create(textView)
                .scrollable(true)
                .selectable(true)
                .px5()
                .py3()
                .hFull()
                .wFull()
                .maxW(relative(0.85))
                .mxAuto())));
    }
}

/** A TextView taller than its clipping ancestor. */
private class ClippedReaderAutoScrollTest extends Model implements Render {
    public final textView:Entity<TextViewState>;

    public function new(textView:Entity<TextViewState>) {
        super();
        this.textView = textView;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(new DebugProbe("reader", div()
            .flex()
            .flexRow()
            .h(px(300.))
            .minW(px(0.))
            .overflowHidden()
            .justifyCenter()
            .child(TextView.create(textView)
                .scrollable(true)
                .selectable(true)
                .h(px(600.))
                .flexNone()
                .wFull()
                .maxW(relative(0.85))
                .mxAuto())));
    }
}

private class PaddedScrollableTextViewTest extends Model implements Render {
    public final textView:Entity<TextViewState>;

    public function new(textView:Entity<TextViewState>) {
        super();
        this.textView = textView;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(TextView.create(textView).selectable(true).scrollable(true).h(px(300.)).p(px(100.)));
    }
}

/** Rust `InlineImageSourceTestView`. */
private class InlineImageSourceTestView extends Model implements Render {
    public final textView:Entity<TextViewState>;

    public function new(textView:Entity<TextViewState>) {
        super();
        this.textView = textView;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().pt(px(10.)).child(div().h(px(80.)).child(TextView.create(textView).selectable(true).selectionFormat(Source)));
    }
}

/**
 * Samples, from inside the panel and before the TextView paints, whether the
 * window still holds the selection the TextView is about to draw from.
 */
private class SelectionPaintProbe extends Element {
    final samples:Array<Bool>;

    public function new(samples:Array<Bool>) {
        this.samples = samples;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.requestLayout(new Style(), null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {}

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        samples.push(TextSelection.hasSelection(window, cx));
    }
}

private class CachedInnerPanel extends Model implements Render {
    final textView:Entity<TextViewState>;
    final renders:{value:Int};
    final samples:Array<Bool>;

    public function new(textView:Entity<TextViewState>, renders:{value:Int}, samples:Array<Bool>) {
        super();
        this.textView = textView;
        this.renders = renders;
        this.samples = samples;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders.value++;
        return new DebugProbe("cached-text-view", div()
            .sizeFull()
            .child(new SelectionPaintProbe(samples))
            .child(TextView.create(textView).selectable(true)));
    }
}

private class CachedPanelRoot extends Model implements Render {
    final inner:Entity<CachedInnerPanel>;

    public function new(inner:Entity<CachedInnerPanel>) {
        super();
        this.inner = inner;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(inner.cached(StyleBuilder.build(s -> s.sizeFull())));
    }
}

/**
 * A view with a selectable TextView used as Root content. Root mounts the
 * Dialog/Sheet layers automatically, so a real modal can be opened above it.
 */
private class ModalScopeTestView extends Model implements Render {
    final focusHandle:FocusHandle;
    public final base:Entity<TextViewState>;

    public function new(cx:Context<ModalScopeTestView>) {
        super();
        focusHandle = cx.focusHandle();
        base = cx.newEntity(cx -> TextViewState.markdown("Hello world", cx));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().trackFocus(focusHandle).sizeFull().child(div().h(px(40.)).child(TextView.create(base).selectable(true)));
    }
}
#end

/**
 * Tests of the window-level text selection across plain selectable text and
 * component TextViews (Rust `component/src/text/window_selection.rs`, a
 * test-only module).
 *
 * Rust reads element bounds through `debug_selector` / `debug_bounds`; the
 * port wraps the same element in a `DebugProbe`. Rust's `root.view().downcast()`
 * is the content entity kept when the root is built.
 */
@:access(glaze.kit.base.text)
class TextWindowSelectionTest #if !macro extends KitTestCase #end {

    #if !macro

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        super.setup();
        DebugProbe.clear();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        DebugProbe.clear();
        super.teardown();
    }

    /** `cx.update(crate::init)` then a window whose Root shows the view built by `build`. */
    function openRoot<V:Model & Render>(build:(Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        app.update(cx -> {
            Component.init(cx);
            // The test fonts have no `Menlo` (the macOS monospace family of the theme).
            glaze.kit.base.theme.Theme.globalMut(cx).tokens.typography.mono = 'JetBrains Mono';
        });
        var content:Entity<V> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            content = rootCx.newEntity(build);
            return new Root(content, window, rootCx);
        });
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        draw(opened.cx);
        return {view: content, cx: opened.cx};
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
    }

    static function drag(cx:VisualTestContext, from:Point, to:Point):Void {
        dragThrough(cx, [from, to]);
    }

    static function dragThrough(cx:VisualTestContext, points:Array<Point>):Void {
        final from = points[0];
        final to = points[points.length - 1];
        cx.simulateMouseDown(from, Left);
        draw(cx);
        for (i in 1...points.length) {
            cx.simulateMouseMove(points[i], Left);
            draw(cx);
        }
        cx.simulateMouseUp(to, Left);
        draw(cx);
    }

    static function windowSelectedText(cx:VisualTestContext):String {
        return cx.update((window, cx) -> TextSelection.selectedText(window, cx));
    }

    static function click(cx:VisualTestContext, position:Point, modifiers:Modifiers):Void {
        cx.simulateMouseDown(position, Left, modifiers);
        cx.simulateMouseUp(position, Left, modifiers);
        draw(cx);
    }

    static function shiftModifiers():Modifiers {
        return Modifiers.none().withShift(true);
    }

    static function trim(text:String):String {
        return StringTools.trim(text);
    }

    static function paragraphs(count:Int, format:(Int) -> String):String {
        return [for (ix in 0...count) format(ix)].join("\n\n");
    }

    function newTextView(source:String):Entity<TextViewState> {
        return app.update(cx -> cx.newEntity(cx -> TextViewState.markdown(source, cx)));
    }

    /** Scroll offset in pixels from the top of the list (positive = scrolled down). */
    static function listScrollPx(textView:Entity<TextViewState>, cx:VisualTestContext):Float {
        return -textView.read(cx.app).listState.scrollPxOffsetForScrollbar().y;
    }

    /**
     * Drags from `start` to `edge`, holds for `ticks` auto-scroll frames, and
     * returns how far the list moved.
     */
    static function dragAndHold(textView:Entity<TextViewState>, start:Point, edge:Point, ticks:Int, cx:VisualTestContext):Float {
        final before = listScrollPx(textView, cx);
        cx.simulateMouseDown(start, Left);
        cx.simulateMouseMove(edge, Left);
        cx.advanceClock(0.016 * ticks);
        cx.runUntilParked();
        final after = listScrollPx(textView, cx);
        cx.simulateMouseUp(edge, Left);
        return after - before;
    }

    function assertAutoScrollMagnitude(moved:Float, perTick:Float, ticks:Int, label:String):Void {
        final max = perTick * ticks;
        if (perTick > 0.) {
            assertTrue(moved > 0. && moved <= max, '$label: moved $moved, expected within (0, $max] for $ticks ticks of $perTick');
        }
        else {
            assertTrue(moved < 0. && moved >= max, '$label: moved $moved, expected within [$max, 0) for $ticks ticks of $perTick');
        }
    }

    // Cross renderer virtual selection

    function assertCrossRendererVirtualExport(format:SelectionFormat, scenario:CrossRendererVirtualScenario):Void {
        final opened = openRoot(cx -> new CrossRendererVirtualView(format, cx));
        final content = opened.view;
        final cx = opened.cx;
        final state = content.read(app).textView.read(app);
        final bounds = state.bounds();
        final listState = state.listState;
        final topPlain = point(px(1.), bounds.origin.y - 20.);
        final bottomPlain = point(px(1.), bounds.bottom() + 20.);

        switch scenario {
            case PlainToVirtualTail:
                listState.scrollTo(new ListOffset(19, 0.));
                draw(cx);
                drag(cx, topPlain, point(bounds.right() - 1., bounds.bottom() - 1.));
            case VirtualHeadToPlain:
                drag(cx, bounds.origin.add(point(px(1.), px(1.))), bottomPlain);
            case VirtualInMiddle:
                drag(cx, topPlain, bottomPlain);
        }

        final text = windowSelectedText(cx);
        for (ix in 0...20) {
            final expected = format == Source ? '**Paragraph$ix**' : 'Paragraph$ix';
            assertTrue(text.indexOf(expected) != -1, 'missing $expected for cross-selection virtual selection: $text');
        }
    }

    function testPlainToVirtualTailExportsUnpaintedPlainBlocks() {
        assertCrossRendererVirtualExport(Plain, PlainToVirtualTail);
    }

    function testPlainToVirtualTailExportsUnpaintedSourceBlocks() {
        assertCrossRendererVirtualExport(Source, PlainToVirtualTail);
    }

    function testVirtualHeadToPlainExportsUnpaintedPlainBlocks() {
        assertCrossRendererVirtualExport(Plain, VirtualHeadToPlain);
    }

    function testVirtualHeadToPlainExportsUnpaintedSourceBlocks() {
        assertCrossRendererVirtualExport(Source, VirtualHeadToPlain);
    }

    function testMiddleVirtualRendererExportsAllPlainBlocks() {
        assertCrossRendererVirtualExport(Plain, VirtualInMiddle);
    }

    function testMiddleVirtualRendererExportsAllSourceBlocks() {
        assertCrossRendererVirtualExport(Source, VirtualInMiddle);
    }

    // Base state ownership

    function testBasePlainSelectionAndTextViewShareOneCrossRendererSelection() {
        final cx = openRoot(cx -> new MixedAdapterView(cx)).cx;

        cx.simulateMouseDown(point(px(1.), px(15.)), Left);
        cx.simulateMouseMove(point(px(300.), px(70.)), Left);
        cx.simulateMouseUp(point(px(300.), px(70.)), Left);
        draw(cx);

        final selected = windowSelectedText(cx);
        assertEquals("Plain adapter\nTextView adapter", trim(selected));
    }

    function testClearingBaseStateLeavesNoRootOwnedTextViewSelection() {
        final opened = openRoot(cx -> new BaseOwnedTextViewSelection(cx));
        final content = opened.view;
        final cx = opened.cx;

        cx.simulateMouseDown(point(px(1.), px(15.)), Left);
        cx.simulateMouseMove(point(px(300.), px(15.)), Left);
        cx.simulateMouseUp(point(px(300.), px(15.)), Left);
        draw(cx);
        assertEquals("Single authority", trim(content.read(app).textView.read(app).selectedText()));

        cx.update((window, cx) -> {
            TextSelection.clear(window, cx);
            window.draw();
            return true;
        });

        final selected = content.read(app).textView.read(app).selectedText();
        assertTrue(selected == "", 'TextView retained selection outside the window selection state: $selected');
    }

    function testBaseClearResetsTextViewBeforeReturning() {
        final opened = openRoot(cx -> new BaseOwnedTextViewSelection(cx));
        final textView = opened.view.read(app).textView;
        final cx = opened.cx;
        cx.update((window, cx) -> {
            window.draw();
            textView.update(cx, (state, cx) -> state.selectAll(cx));
            TextSelection.clear(window, cx);
            assertEquals("", textView.read(cx).selectedText());
            return true;
        });
    }

    function testBaseClearThenSelectAllInOneEffectKeepsTheNewSelection() {
        final opened = openRoot(cx -> new BaseOwnedTextViewSelection(cx));
        final textView = opened.view.read(app).textView;
        final cx = opened.cx;
        cx.update((window, cx) -> {
            window.draw();
            textView.update(cx, (state, cx) -> state.selectAll(cx));
            TextSelection.clear(window, cx);
            textView.update(cx, (state, cx) -> state.selectAll(cx));
            return true;
        });
        cx.runUntilParked();

        final hasSelection = cx.update((window, cx) -> TextSelection.hasSelection(window, cx));
        final selected = windowSelectedText(cx);
        assertTrue(hasSelection);
        assertEquals("Single authority", trim(selected));
    }

    // Auto scroll

    static function longParagraphs():String {
        return paragraphs(100, ix -> 'Paragraph $ix with enough text to select');
    }

    function testHeldTextViewDragAutoScrollExtendsSelection() {
        final source = longParagraphs();
        final opened = openRoot(cx -> new AutoScrollTextViewTest(cx.newEntity(cx -> TextViewState.markdown(source, cx))));
        final textView = opened.view.read(app).textView;
        final cx = opened.cx;

        final bounds = DebugProbe.bounds("scrollable-text-view");
        assertTrue(bounds != null, 'scrollable TextView bounds');
        // On the first paragraph's line: a drag that neither starts nor
        // lands on text selects nothing, and the edge may sit in a gap.
        final start = point(bounds.left() + 30., bounds.top() + 10.);
        final edge = point(bounds.left() + 60., bounds.bottom() - 2.);
        cx.simulateMouseDown(start, Left);
        cx.simulateMouseMove(edge, Left);
        draw(cx);
        final before = windowSelectedText(cx);
        assertTrue(before != "", 'the drag must start a text selection');
        // Each tick paints the newly scrolled blocks, with no further mouse moves.
        for (_ in 0...12) {
            cx.advanceClock(0.016);
            cx.runUntilParked();
            draw(cx);
        }
        final after = windowSelectedText(cx);
        cx.simulateMouseUp(edge, Left);
        assertTrue(glaze.util.Utf8.byteLength(after) > glaze.util.Utf8.byteLength(before), 'holding at edge must expand selection: before=$before, after=$after');
        final stoppedAt = listScrollPx(textView, cx);
        cx.advanceClock(0.064);
        cx.runUntilParked();
        draw(cx);
        assertEquals(stoppedAt, listScrollPx(textView, cx));
        assertEquals(after, windowSelectedText(cx));
    }

    function testCompatibilityTextViewDragSelectionAutoScrollsBothDirections() {
        final source = longParagraphs();
        final opened = openRoot(cx -> new AutoScrollTextViewTest(cx.newEntity(cx -> TextViewState.markdown(source, cx))));
        final view = opened.view;
        final cx = opened.cx;

        final bounds = DebugProbe.bounds("scrollable-text-view");
        assertTrue(bounds != null, 'scrollable TextView bounds');
        // The TextView fills the viewport, so the per-frame delta the drag
        // requests is the one measured against the viewport edge.
        final ticks = 4;
        var start = point(bounds.left() + 30., bounds.top() + 30.);
        var edge = point(bounds.left() + 60., bounds.bottom() - 2.);
        var perTick = AutoScroll.computeDelta(edge.y, bounds);
        assertTrue(perTick != null, 'edge zone');
        final textView = view.read(app).textView;
        var moved = dragAndHold(textView, start, edge, ticks, cx);
        assertAutoScrollMagnitude(moved, perTick, ticks, "downward");

        final listState = textView.read(app).listState;
        listState.scrollTo(new ListOffset(99, 0.));
        draw(cx);
        start = point(bounds.left() + 30., bounds.bottom() - 30.);
        edge = point(bounds.left() + 60., bounds.top() + 2.);
        perTick = AutoScroll.computeDelta(edge.y, bounds);
        assertTrue(perTick != null, 'edge zone');
        moved = dragAndHold(textView, start, edge, ticks, cx);
        assertAutoScrollMagnitude(moved, perTick, ticks, "upward");
    }

    function testPaddedReaderTextViewAutoScrollsAtTheClippingEdge() {
        final source = longParagraphs();
        final opened = openRoot(cx -> new PaddedReaderAutoScrollTest(cx.newEntity(cx -> TextViewState.markdown(source, cx))));
        final cx = opened.cx;

        final reader = DebugProbe.bounds("reader");
        assertTrue(reader != null, 'reader bounds');
        final textView = opened.view.read(app).textView;
        final listBounds = textView.read(app).listState.viewportBounds();
        assertTrue(listBounds.bottom() < reader.bottom() - 2., 'the list must end inside the padding: list $listBounds, reader $reader');

        // Below the list but inside the clipping ancestor: the synthetic wheel
        // is clamped to this band and misses the list hitbox.
        final start = point(reader.center().x, reader.top() + 40.);
        final edge = point(reader.center().x, reader.bottom() - 2.);
        final moved = dragAndHold(textView, start, edge, 4, cx);
        assertTrue(moved > 0., 'dragging to the clipping edge must scroll the padded list, moved $moved');
    }

    function testClippedReaderTextViewAutoScrollsAtTheVisibleEdge() {
        final source = longParagraphs();
        final opened = openRoot(cx -> new ClippedReaderAutoScrollTest(cx.newEntity(cx -> TextViewState.markdown(source, cx))));
        final cx = opened.cx;

        final reader = DebugProbe.bounds("reader");
        assertTrue(reader != null, 'reader bounds');
        final textView = opened.view.read(app).textView;
        final listBounds = textView.read(app).listState.viewportBounds();
        assertTrue(listBounds.bottom() > reader.bottom() + 100.);

        // The visible edge is well above the TextView's own bottom.
        final start = point(reader.center().x, reader.top() + 40.);
        final edge = point(reader.center().x, reader.bottom() - 2.);
        final moved = dragAndHold(textView, start, edge, 4, cx);
        assertTrue(moved > 0., 'dragging to the clipping edge must scroll the clipped list, moved $moved');
    }

    // Virtualized blocks

    function testPaddedScrollableTextViewUsesContentOriginForVirtualBlocks() {
        final blocks = 20;
        final source = paragraphs(blocks, ix -> 'Paragraph$ix');
        final opened = openRoot(cx -> new PaddedScrollableTextViewTest(cx.newEntity(cx -> TextViewState.markdown(source, cx))));
        final cx = opened.cx;
        final textView = opened.view.read(app).textView;
        final bounds = textView.read(app).bounds();

        cx.simulateMouseDown(bounds.origin.add(point(px(1.), px(1.))), Left);
        final listState = textView.read(app).listState;
        listState.scrollTo(new ListOffset(blocks - 1, 0.));
        draw(cx);
        cx.simulateMouseMove(point(bounds.right() - 1., bounds.bottom() - 1.), Left);
        cx.simulateMouseUp(point(bounds.right() - 1., bounds.bottom() - 1.), Left);
        draw(cx);

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Paragraph0") != -1, 'first block was skipped: $text');
        assertTrue(text.indexOf("Paragraph18") != -1, 'drag did not reach the tail: $text');
    }

    function testSelectionSpansBlocksScrolledPast() {
        final blocks = 20;
        final source = paragraphs(blocks, ix -> 'Paragraph$ix');
        final cx = openRoot(cx -> new ScrollableTextViewTest(cx.newEntity(cx -> TextViewState.markdown(source, cx)))).cx;

        // Press inside the first block, then wheel-scroll to the end. The
        // blocks scrolled past are never painted while the drag is active.
        cx.simulateMouseDown(point(px(0.), px(1.)), Left);
        draw(cx);
        for (_ in 0...blocks) {
            cx.simulateEvent(new ScrollEvent(point(px(10.), px(30.)), Pixels(point(px(0.), px(-40.)))));
            draw(cx);
        }

        // Release over the last visible block.
        cx.simulateMouseMove(point(px(150.), px(58.)), Left);
        draw(cx);
        cx.simulateMouseUp(point(px(150.), px(58.)), Left);
        draw(cx);

        final text = windowSelectedText(cx);
        final missing = [for (ix in 0...blocks) if (text.indexOf('Paragraph$ix') == -1) ix];
        assertTrue(missing.length == 0, 'blocks scrolled past were dropped: $missing in $text');
    }

    /**
     * Source mode has the same gap to bridge as plain text: a block the
     * selection spans but that scrolled past without painting must still be
     * copied, with its markup.
     */
    function testSourceSelectionSpansBlocksScrolledPast() {
        final blocks = 20;
        final source = paragraphs(blocks, ix -> '**Paragraph$ix**');
        final cx = openRoot(cx -> new ScrollableTextViewTest(cx.newEntity(cx -> TextViewState.markdown(source, cx)), Source)).cx;

        cx.simulateMouseDown(point(px(0.), px(1.)), Left);
        draw(cx);
        // Jump the whole document in one go, so the blocks in between never
        // paint at all and cannot leave a stale selection behind.
        cx.simulateEvent(new ScrollEvent(point(px(10.), px(30.)), Pixels(point(px(0.), px(-40.) * blocks))));
        draw(cx);

        cx.simulateMouseMove(point(px(150.), px(58.)), Left);
        draw(cx);
        cx.simulateMouseUp(point(px(150.), px(58.)), Left);
        draw(cx);

        final text = windowSelectedText(cx);
        final missing = [for (ix in 0...blocks) if (text.indexOf('**Paragraph$ix**') == -1) ix];
        assertTrue(missing.length == 0, 'blocks scrolled past were dropped or lost their markup: $missing in $text');
    }

    function testShrinkingVirtualSelectionDropsBlocksBeyondTheNewCursor() {
        final blocks = 20;
        final source = paragraphs(blocks, ix -> 'Paragraph$ix');
        final opened = openRoot(cx -> new ScrollableTextViewTest(cx.newEntity(cx -> TextViewState.markdown(source, cx))));
        final cx = opened.cx;

        cx.simulateMouseDown(point(px(0.), px(1.)), Left);
        final listState = opened.view.read(app).textView.read(app).listState;
        listState.scrollTo(new ListOffset(blocks - 1, 0.));
        draw(cx);
        cx.simulateMouseMove(point(px(150.), px(30.)), Left);
        draw(cx);
        final expanded = windowSelectedText(cx);
        assertTrue(expanded.indexOf("Paragraph18") != -1, 'failed to expand near the last block: $expanded');

        listState.scrollTo(new ListOffset(5, 0.));
        draw(cx);
        cx.simulateMouseMove(point(px(150.), px(10.)), Left);
        cx.simulateMouseUp(point(px(150.), px(10.)), Left);
        draw(cx);

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Paragraph5") != -1, 'got: $text');
        assertTrue(text.indexOf("Paragraph18") == -1, 'stale blocks beyond the new cursor were copied: $text');
    }

    /** A multi-click selection has to come back as source too. */
    function testSourceMultiClickSelectionKeepsItsMarkup() {
        final cx = openRoot(cx -> new ScrollableTextViewTest(cx.newEntity(cx -> TextViewState.markdown("**Hello** world", cx)), Source)).cx;

        final position = point(px(10.), px(10.));
        cx.simulateEvent(new glaze.MouseDownEvent(Left, position, Modifiers.none(), 2, false));
        cx.simulateEvent(new glaze.MouseUpEvent(Left, position, Modifiers.none(), 2));
        draw(cx);

        final text = windowSelectedText(cx);
        assertEquals("**Hello**", trim(text));
    }

    function testSelectionInsideOneBlockLeavesTheRest() {
        final source = paragraphs(20, ix -> 'Paragraph$ix');
        final cx = openRoot(cx -> new ScrollableTextViewTest(cx.newEntity(cx -> TextViewState.markdown(source, cx)))).cx;

        // Stay inside the first block. The blocks below are on screen and
        // simply not selected, so none of them may be filled in.
        drag(cx, point(px(2.), px(4.)), point(px(40.), px(4.)));

        final text = windowSelectedText(cx);
        assertTrue(trim(text) != "", 'nothing selected');
        assertTrue(text.indexOf("Paragraph1") == -1, 'unselected block was filled in: $text');
    }

    function testSourceFormatMapsOffsetsPerRenderedRun() {
        final cx = openRoot(cx -> new InlineImageSourceTestView(cx.newEntity(cx -> TextViewState.markdown("Build **status** ![img](https://example.com/i.svg) after text", cx)))).cx;

        drag(cx, point(px(0.), px(11.)), point(px(600.), px(80.)));

        final text = windowSelectedText(cx);
        assertEquals("Build **status** ![img](https://example.com/i.svg) after text", trim(text));
    }

    // Cached views

    /**
     * A dock panel renders its content through `Entity.cached`, which replays
     * the recorded frame whenever nothing in it changed. The selection painted
     * inside it must not blink, and the panel must stay cached.
     */
    function testSelectionInsideACachedViewSurvivesReplayedFrames() {
        final source = paragraphs(20, ix -> 'Paragraph $ix with enough text to select');
        final renders = {value: 0};
        final samples:Array<Bool> = [];
        final cx = openRoot(cx -> new CachedPanelRoot(cx.newEntity(cx -> new CachedInnerPanel(cx.newEntity(cx -> TextViewState.markdown(source, cx)), renders, samples)))).cx;
        final bounds = DebugProbe.bounds("cached-text-view");
        assertTrue(bounds != null, 'cached TextView bounds');

        final start = bounds.origin.add(point(px(30.), px(8.)));
        drag(cx, start, start.add(point(px(60.), px(40.))));
        cx.runUntilParked();

        final selected = windowSelectedText(cx);
        assertTrue(selected != "", 'the drag must select text');
        final settled = renders.value;
        samples.resize(0);

        for (frame in 0...8) {
            draw(cx);
            cx.runUntilParked();
            assertEquals(selected, windowSelectedText(cx), 'frame $frame lost the selection painted inside the cached panel');
        }
        // Every frame the panel did repaint must have had the selection to
        // paint; a `false` here is the blink itself.
        assertTrue(samples.indexOf(false) == -1, 'the panel repainted without a selection: $samples');
        assertEquals(settled, renders.value, 'a settled selection must let the cached panel stay cached');
    }

    // Chat views: shift click, content replacement, drags

    function setupChat(secondSelectable:Bool):{view:Entity<ChatTestView>, cx:VisualTestContext} {
        return openRoot(cx -> new ChatTestView(secondSelectable, cx));
    }

    function testShiftClickExtendsFromPreviousPlainClick() {
        final cx = setupChat(true).cx;

        click(cx, point(px(0.), px(15.)), Modifiers.none());
        click(cx, point(px(300.), px(15.)), shiftModifiers());

        assertEquals("Hello world", trim(windowSelectedText(cx)));
    }

    function testShiftClickReusesAnchorForRepeatedExtension() {
        final cx = setupChat(true).cx;
        final anchor = point(px(0.), px(15.));

        click(cx, anchor, Modifiers.none());
        click(cx, point(px(300.), px(15.)), shiftModifiers());
        assertEquals("Hello world", trim(windowSelectedText(cx)));

        click(cx, anchor, shiftModifiers());
        assertEquals("", windowSelectedText(cx));
    }

    function testShiftClickKeepsAnchorWhenCursorCrossesIt() {
        final cx = setupChat(true).cx;
        final anchor = point(px(20.), px(15.));

        click(cx, anchor, Modifiers.none());
        click(cx, point(px(300.), px(15.)), shiftModifiers());
        assertEquals("llo world", trim(windowSelectedText(cx)));

        click(cx, point(px(0.), px(15.)), shiftModifiers());
        assertEquals("He", trim(windowSelectedText(cx)));
    }

    function testShiftDragKeepsPreviousPlainClickAsAnchor() {
        final cx = setupChat(true).cx;
        final modifiers = shiftModifiers();

        click(cx, point(px(0.), px(15.)), Modifiers.none());
        cx.simulateMouseDown(point(px(20.), px(15.)), Left, modifiers);
        cx.simulateMouseMove(point(px(300.), px(70.)), Left, modifiers);
        cx.simulateMouseUp(point(px(300.), px(70.)), Left, modifiers);
        draw(cx);

        assertEquals("Hello world\n\nSecond message", trim(windowSelectedText(cx)));
    }

    function testShiftClickUsesAnchorEstablishedByLatestPlainClick() {
        final cx = setupChat(true).cx;
        final start = point(px(0.), px(15.));
        final end = point(px(300.), px(15.));
        final newAnchor = point(px(20.), px(15.));

        click(cx, start, Modifiers.none());
        click(cx, end, shiftModifiers());
        assertEquals("Hello world", trim(windowSelectedText(cx)));

        click(cx, newAnchor, Modifiers.none());
        click(cx, start, shiftModifiers());
        assertEquals("He", trim(windowSelectedText(cx)));
    }

    function testShiftClickWithoutAnchorFallsBackToPlainClick() {
        final cx = setupChat(true).cx;

        click(cx, point(px(20.), px(15.)), shiftModifiers());

        assertEquals("", windowSelectedText(cx));
    }

    function testShiftClickExtendsAcrossTextViews() {
        final opened = setupChat(true);
        final chat = opened.view;
        final cx = opened.cx;

        click(cx, point(px(0.), px(15.)), Modifiers.none());
        click(cx, point(px(300.), px(70.)), shiftModifiers());

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Hello world") != -1, 'got: $text');
        assertTrue(text.indexOf("Second message") != -1, 'got: $text');
        assertFalse(chat.read(app).first.read(app).isSelecting());
        assertFalse(chat.read(app).second.read(app).isSelecting());
    }

    function testShiftClickFocusesTheNewEndpointView() {
        final opened = setupChat(true);
        final chat = opened.view;
        final cx = opened.cx;

        click(cx, point(px(0.), px(15.)), Modifiers.none());
        click(cx, point(px(300.), px(70.)), shiftModifiers());

        final secondIsFocused = cx.update((window, cx) -> chat.read(cx).second.read(cx).focusHandle.isFocused(window));
        assertTrue(secondIsFocused, 'Shift-click left focus on the anchor view');
    }

    function testSameSizeContentReplacementInvalidatesFinishedSelection() {
        final opened = setupChat(true);
        final cx = opened.cx;

        drag(cx, point(px(0.), px(15.)), point(px(300.), px(15.)));
        assertEquals("Hello world", trim(windowSelectedText(cx)));

        final first = opened.view.read(app).first;
        cx.update((_, cx) -> first.update(cx, (state, cx) -> state.setText("Other words", cx)));
        cx.runUntilParked();
        draw(cx);

        assertEquals("", windowSelectedText(cx));
    }

    function testActiveDragReplacementInvalidatesAfterMouseUp() {
        final opened = setupChat(true);
        final cx = opened.cx;
        final first = opened.view.read(app).first;

        cx.simulateMouseDown(point(px(0.), px(15.)), Left);
        cx.simulateMouseMove(point(px(300.), px(15.)), Left);
        cx.update((_, cx) -> first.update(cx, (state, cx) -> state.setText("Other words", cx)));
        cx.runUntilParked();
        draw(cx);
        cx.simulateMouseUp(point(px(300.), px(15.)), Left);
        draw(cx);

        assertEquals("", windowSelectedText(cx));
    }

    function testActiveDragAppendKeepsCompatibleSelection() {
        final opened = setupChat(true);
        final cx = opened.cx;
        final first = opened.view.read(app).first;

        cx.simulateMouseDown(point(px(0.), px(15.)), Left);
        cx.simulateMouseMove(point(px(300.), px(15.)), Left);
        cx.update((_, cx) -> first.update(cx, (state, cx) -> state.pushStr(" again", cx)));
        cx.runUntilParked();
        cx.simulateMouseUp(point(px(300.), px(15.)), Left);
        draw(cx);

        final selected = windowSelectedText(cx);
        assertTrue(selected.indexOf("Hello world") != -1, 'selected=$selected');
    }

    function testSameSizeStyleReflowKeepsFinishedSelection() {
        final opened = setupChat(true);
        final chat = opened.view;
        final cx = opened.cx;
        drag(cx, point(px(0.), px(15.)), point(px(300.), px(15.)));
        assertEquals("Hello world", trim(windowSelectedText(cx)));

        chat.update(app, (chat, cx) -> {
            chat.firstStyle.headingBaseFontSize = px(28.);
            cx.notify();
        });
        draw(cx);

        assertEquals("Hello world", trim(windowSelectedText(cx)));
    }

    function testShiftClickOnSuppressingControlClearsTextViewSelection() {
        final cx = setupChat(true).cx;

        drag(cx, point(px(0.), px(15.)), point(px(300.), px(70.)));
        assertTrue(windowSelectedText(cx) != "");

        click(cx, point(px(20.), px(100.)), shiftModifiers());

        assertEquals("", windowSelectedText(cx));
    }

    function testCrossViewDragMergesTextTopToBottom() {
        final cx = setupChat(true).cx;

        // From the very start of the first view down into the second view.
        drag(cx, point(px(0.), px(15.)), point(px(300.), px(70.)));

        final text = windowSelectedText(cx);
        final first = text.indexOf("Hello world");
        final second = text.indexOf("Second message");
        assertTrue(first != -1, 'first view text missing');
        assertTrue(second != -1, 'second view text missing');
        assertTrue(first < second, 'wrong order: $text');
        assertTrue(text.indexOf('\n') != -1, 'expected newline separator: $text');
    }

    function testDragFromBlankSpaceSelectsViewsBelow() {
        final cx = setupChat(true).cx;

        // Start in the blank padding above the first view, enter the second
        // view's rendered text, then drag past its end.
        dragThrough(cx, [point(px(5.), px(2.)), point(px(20.), px(70.)), point(px(300.), px(70.))]);

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Hello world") != -1, 'got: $text');
        assertTrue(text.indexOf("Second message") != -1, 'got: $text');
    }

    function testDragEntirelyInBlankGapSelectsNothing() {
        final opened = setupChat(true);
        final cx = opened.cx;

        // Layout: first [10,50], gap [50,110], second [110,150].
        opened.view.update(app, (chat, cx) -> {
            chat.midGap = px(60.);
            cx.notify();
        });
        draw(cx);

        // Drag only inside the gap. The selection never enters either TextView.
        drag(cx, point(px(5.), px(70.)), point(px(300.), px(90.)));

        final text = windowSelectedText(cx);
        assertEquals("", text, 'blank-only drag selected text: $text');
    }

    function testDragEntirelyInRightGutterSelectsNothing() {
        final cx = setupChat(true).cx;

        // x=300 is far to the right of the rendered text. Dragging vertically
        // through only that blank gutter must not select nearby TextViews.
        drag(cx, point(px(300.), px(2.)), point(px(300.), px(70.)));

        final text = windowSelectedText(cx);
        assertEquals("", text, 'right-gutter drag selected text: $text');
    }

    function testSelectionFollowsContentWhenLayoutShifts() {
        final opened = setupChat(true);
        final chat = opened.view;
        final cx = opened.cx;

        // Layout: first [10,50], gap [50,110], second [110,150].
        chat.update(app, (chat, cx) -> {
            chat.midGap = px(60.);
            cx.notify();
        });
        draw(cx);

        // Anchor in the gap (blank space) and drag down-right into the second
        // view, ending past the end of its text so the whole line is selected.
        dragThrough(cx, [point(px(0.), px(80.)), point(px(20.), px(120.)), point(px(300.), px(120.))]);
        final before = windowSelectedText(cx);
        assertTrue(before.indexOf("Second message") != -1 && before.indexOf("Hello world") == -1, 'expected only the second view selected, got: $before');

        // Shift the whole content down by 80px, the equivalent of an outer
        // container scrolling. A proxy-anchored endpoint moves with the
        // content and the selection stays stable.
        chat.update(app, (chat, cx) -> {
            chat.topOffset = px(90.);
            cx.notify();
        });
        draw(cx);

        final after = windowSelectedText(cx);
        assertEquals(before, after, 'selection drifted after layout shift');
    }

    function testSuppressedMouseDownDoesNotStartSelection() {
        final cx = setupChat(true).cx;

        // The suppress row sits below the two views (y in [90, 110)).
        drag(cx, point(px(20.), px(100.)), point(px(20.), px(15.)));

        final text = windowSelectedText(cx);
        assertTrue(text == "", 'expected no selection, got: $text');
    }

    function testNonSelectableViewIsExcluded() {
        final cx = setupChat(false).cx;

        dragThrough(cx, [point(px(5.), px(2.)), point(px(20.), px(15.)), point(px(300.), px(15.))]);

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Hello world") != -1, 'got: $text');
        assertTrue(text.indexOf("Second message") == -1, 'got: $text');
    }

    function testDragWithinSingleViewExcludesOthers() {
        final cx = setupChat(true).cx;

        // Entirely inside the first view.
        drag(cx, point(px(5.), px(15.)), point(px(60.), px(15.)));

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Second message") == -1, 'got: $text');
        assertTrue(trim(text) != "", 'expected some selection');
    }

    function testMouseDownClearsPreviousSelection() {
        final cx = setupChat(true).cx;

        drag(cx, point(px(5.), px(15.)), point(px(300.), px(70.)));
        assertTrue(windowSelectedText(cx) != "");

        // A plain click clears the selection.
        cx.simulateClick(point(px(300.), px(100.)), Modifiers.none());
        draw(cx);

        assertEquals("", windowSelectedText(cx));
    }

    function testDoubleClickSelectsWordUnderRoot() {
        final cx = setupChat(true).cx;

        // Double-click inside the first view: must trigger the per-view word
        // selection, not a window-level drag selection.
        final position = point(px(10.), px(15.));
        cx.simulateEvent(new glaze.MouseDownEvent(Left, position, Modifiers.none(), 2, false));
        cx.simulateEvent(new glaze.MouseUpEvent(Left, position, Modifiers.none(), 2));
        draw(cx);

        final text = windowSelectedText(cx);
        assertEquals("Hello", trim(text), 'expected word selection: $text');
        assertTrue(text.indexOf("Second message") == -1, 'got: $text');
    }

    function testDragBackIntoAnchorViewClearsOtherViews() {
        final opened = setupChat(true);
        final cx = opened.cx;
        final second = opened.view.read(app).second;

        // Drag from view A down into view B: this is a cross-view selection,
        // so B paints a highlight and `selectedText` reports it.
        cx.simulateMouseDown(point(px(0.), px(15.)), Left);
        draw(cx);
        cx.simulateMouseMove(point(px(300.), px(70.)), Left);
        draw(cx);

        final text = second.read(app).selectedText();
        assertTrue(text.indexOf("Second message") != -1, 'precondition: B should be selected, got $text');

        // Observe B's re-render requests: a view only drops a stale highlight
        // when it is notified and repaints.
        var bNotified = false;
        final subscription = cx.update((_, cx) -> cx.observe(second, (_, _) -> bNotified = true));
        bNotified = false;

        // Drag back up inside view A. It must still notify B (whose old band
        // crossed B) so B can clear its now-stale highlight. Checked on the
        // in-drag frame, not after mouse-up.
        cx.simulateMouseMove(point(px(60.), px(15.)), Left);
        cx.runUntilParked();

        assertTrue(bNotified, 'view B was not notified when the drag returned to the anchor view, so its stale highlight would never be repainted away');
        subscription.dispose();
    }

    // Dialog and sheet selection scopes

    function setupModal():{view:Entity<ModalScopeTestView>, cx:VisualTestContext} {
        return openRoot(cx -> new ModalScopeTestView(cx));
    }

    /**
     * Advance past the modal open animation so it reaches its resting
     * position, then redraw so its TextViews register.
     */
    static function settle(cx:VisualTestContext):Void {
        cx.advanceClock(0.5);
        draw(cx);
        draw(cx);
    }

    function openDialogWithText(cx:VisualTestContext, text:String):Entity<TextViewState> {
        final state = newTextView(text);
        cx.update((window, cx) -> {
            window.openDialog(cx, (dialog, _, _) -> dialog.child(TextView.create(state).selectable(true)));
            return true;
        });
        settle(cx);
        return state;
    }

    function openSheetWithText(cx:VisualTestContext, text:String):Entity<TextViewState> {
        final state = newTextView(text);
        cx.update((window, cx) -> {
            window.openSheetAt(Placement.Right, cx, (sheet, _, _) -> sheet.child(TextView.create(state).selectable(true)));
            return true;
        });
        settle(cx);
        return state;
    }

    function testDragInsideDialogStillSelectsItsText() {
        final cx = setupModal().cx;
        final dialogState = openDialogWithText(cx, "Dialog text");

        // A drag entirely within the dialog's TextView must still select.
        final b = dialogState.read(app).bounds();
        drag(cx, point(b.origin.x + 1., b.center().y), point(b.origin.x + b.size.width + 80., b.center().y));

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Dialog text") != -1, 'dialog text was not selectable: $text');
    }

    function testDragInsideSheetStillSelectsItsText() {
        final cx = setupModal().cx;
        final sheetState = openSheetWithText(cx, "Sheet text");

        final bounds = sheetState.read(app).bounds();
        drag(cx, point(bounds.origin.x + 1., bounds.center().y), point(bounds.right() + 80., bounds.center().y));

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Sheet text") != -1, 'sheet text was not selectable: $text');
    }

    function testOpeningDialogClearsBaseSelection() {
        final opened = setupModal();
        final view = opened.view;
        final cx = opened.cx;

        final b = view.read(app).base.read(app).bounds();
        drag(cx, point(b.origin.x + 1., b.center().y), point(b.origin.x + b.size.width + 80., b.center().y));
        assertTrue(windowSelectedText(cx).indexOf("Hello world") != -1);

        openDialogWithText(cx, "Dialog text");

        final text = windowSelectedText(cx);
        assertTrue(text.indexOf("Hello world") == -1, 'base selection was not cleared when the dialog opened: $text');
    }

    /**
     * With a dialog open, a drag that starts in the dialog's text and leaves
     * it over the overlay must not select the TextView behind the overlay.
     */
    function testSelectionBehindActiveDialogIsExcluded() {
        final opened = setupModal();
        final view = opened.view;
        final cx = opened.cx;
        final dialogState = openDialogWithText(cx, "Dialog text");

        final from = dialogState.read(app).bounds().center();
        final b = view.read(app).base.read(app).bounds();
        final to = point(b.origin.x + 4., b.center().y);
        drag(cx, from, to);

        final behind = view.read(app).base.read(app).selectedText();
        assertTrue(trim(behind) == "", 'view behind the dialog overlay was selected: $behind');
    }

    /** The same guard for a Sheet. */
    function testSelectionBehindActiveSheetIsExcluded() {
        final opened = setupModal();
        final view = opened.view;
        final cx = opened.cx;
        final sheetState = openSheetWithText(cx, "Sheet text");

        final from = sheetState.read(app).bounds().center();
        final b = view.read(app).base.read(app).bounds();
        final to = point(b.origin.x + 4., b.center().y);
        drag(cx, from, to);

        final behind = view.read(app).base.read(app).selectedText();
        assertTrue(trim(behind) == "", 'view behind the sheet overlay was selected: $behind');
    }

    #end

}
