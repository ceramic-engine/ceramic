package tests.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Div;
import glaze.Element;
import glaze.ElementId;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.base.resizable.Resizable;
import glaze.kit.base.resizable.ResizablePanelGroup;
import glaze.kit.base.resizable.ResizablePanelGroup.IntoResizablePanel;
import glaze.kit.base.resizable.ResizablePanelGroup.ResizablePanelEvent;
import glaze.kit.base.resizable.ResizableState;
import glaze.kit.breadcrumb.Breadcrumb;
import glaze.kit.breadcrumb.Breadcrumb.BreadcrumbItem;
import glaze.kit.breadcrumb.Breadcrumb.IntoBreadcrumbItem;
import glaze.kit.chart.RadarChart;
import glaze.kit.chart.RadarChart.RadarLabel;
import glaze.kit.chart.RadarChart.RadarLabelKind;
import glaze.kit.descriptionlist.DescriptionList;
import glaze.kit.descriptionlist.DescriptionList.DescriptionItem;
import glaze.kit.descriptionlist.DescriptionList.DescriptionText;
import glaze.kit.hovercard.HoverCard;
import glaze.kit.message.Message;
import glaze.kit.text.Text;
import glaze.scene.SceneDump;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * Null in the slot APIs beyond `child()` (see `NullChildTest`): a null slot
 * builds the same tree as the one built without it (order, layout, element
 * ids, scene).
 *
 * - `IntoBreadcrumbItem`: a null item is skipped.
 * - `IntoResizablePanel`: a null panel is skipped (sizes, handles, resize
 *   events and stored sizes are those of the group without it).
 * - `Message.avatar(null)`: no avatar.
 * - `DescriptionText`: a null label or value is the empty text, like the
 *   value `DescriptionItem.create` leaves unset (the cell stays).
 * - `RadarLabel`: a null label draws nothing for its dimension and gives
 *   no tooltip title, like a chart without `label()`.
 * - `HoverCard.trigger(null)` throws: the trigger is mandatory.
 */
class NullSlotTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    /** A null of any type, not folded by the compiler */
    static function none<T>():Null<T> {
        return null;
    }

    function open(build:(Array<String>) -> IntoElement):{cx:VisualTestContext, log:Array<String>} {
        final log:Array<String> = [];
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            final content = rootCx.newEntity((c:Context<NullSlotView>) -> new NullSlotView(log, build));
            return new Root(content, window, rootCx);
        }, 600, 400);
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        return {cx: opened.cx, log: log};
    }

    static function scene(cx:VisualTestContext):String {
        return cx.update((window, _) -> SceneDump.toJson(window.renderedScene(), 1200, 800));
    }

    /** The probes log (view ids aside, they differ per window) and the scene */
    function rendered(build:(Array<String>) -> IntoElement):String {
        final opened = open(build);
        final views = ~/view-[0-9]+/g;
        return views.replace(opened.log.join('\n'), 'view') + '\n' + scene(opened.cx);
    }

    function assertSameRendering(expected:String, actual:String, ?pos:haxe.PosInfos) {
        assertTrue(expected.length > 0, 'the reference renders', pos);
        if (expected != actual) {
            final a = expected.split('\n');
            final b = actual.split('\n');
            var line = 0;
            while (line < a.length && line < b.length && a[line] == b[line]) line++;
            fail('renderings differ at line $line: expected=${a[line]} actual=${b[line]}', pos);
        }
        assertEquals(expected, actual, pos);
    }

    // Breadcrumb

    function testNullBreadcrumbLabelConvertsToNull() {
        final label:Null<String> = none();
        assertTrue((label : IntoBreadcrumbItem) == null);
        assertTrue(("Home" : IntoBreadcrumbItem) != null);
    }

    function testBreadcrumbSkipsNullItems() {
        final label:Null<String> = none();
        final item:Null<BreadcrumbItem> = none();
        final into:Null<IntoBreadcrumbItem> = none();
        final hidden = false;

        final expectedCrumb = Breadcrumb.component().children(['Home', 'Docs', BreadcrumbItem.component('Page')]);
        final actualCrumb = Breadcrumb.component()
            .child(null)
            .child(label)
            .child('Home')
            .children([null, label, item, 'Docs', into])
            .child(hidden ? 'Hidden' : null)
            .child(BreadcrumbItem.component('Page'))
            .child(item)
            .children([label, null]);
        final labels = (crumb:Breadcrumb) -> [for (item in @:privateAccess crumb.items) @:privateAccess item.label].join(',');
        assertEquals('Home,Docs,Page', labels(expectedCrumb));
        assertEquals('Home,Docs,Page', labels(actualCrumb));

        // The last real item gets the foreground color and every item its
        // positional id: the scenes match.
        final expected = rendered(_ -> div().id('root').child(expectedCrumb));
        final actual = rendered(_ -> div().id('root').child(actualCrumb));
        assertSameRendering(expected, actual);
    }

    // Resizable

    function testNullResizablePanelConvertsToNull() {
        final element:Null<Div> = none();
        final into:Null<IntoElement> = none();
        final group:Null<ResizablePanelGroup> = none();
        assertTrue(((element : IntoElement) : IntoResizablePanel) == null);
        assertTrue((into : IntoResizablePanel) == null);
        assertTrue((group : IntoResizablePanel) == null);
        assertTrue(((div() : IntoElement) : IntoResizablePanel) != null);
    }

    /**
     * Draws a three panel group, drags the second handle, and reports the
     * probes (panel and handle global ids and bounds), the stored sizes and
     * the resize events before and after the drag.
     */
    function resizableRun(build:(Array<String>, Entity<ResizableState>, Array<Int>) -> IntoElement):String {
        final state = app.update(cx -> cx.newEntity((_:Context<ResizableState>) -> new ResizableState()));
        final resizes = [0];
        final events = [0];
        final subscription = app.subscribe(state, ResizablePanelEvent, (_, event, _) -> switch event {
            case Resized: events[0] = events[0] + 1;
        });
        final opened = open(log -> build(log, state, resizes));
        final cx = opened.cx;
        cx.update((window, _) -> window.draw());
        final report:Array<String> = [];
        final views = ~/view-[0-9]+/g;
        final snapshot = (step:String) -> {
            report.push('$step:');
            report.push(views.replace(opened.log.join('\n'), 'view'));
            report.push('panels=' + cx.update((_, cx) -> state.read(cx).panels.length));
            report.push('sizes=' + cx.update((_, cx) -> state.read(cx).sizes().join(',')));
            report.push('resizes=' + resizes[0] + ' events=' + events[0]);
        };
        snapshot('initial');

        // The second handle sits at the left edge of the third panel.
        final third = DebugProbe.bounds('null-slots-panel-c');
        assertNotNull(third, 'the third panel is laid out');
        final boundary:Float = third.left();
        assertTrue(boundary > 0);
        cx.simulateMouseDown(new Point(boundary - 2., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 10., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 30., 50.), Left);
        cx.simulateMouseUp(new Point(boundary + 30., 50.), Left);
        cx.update((window, _) -> window.draw());
        snapshot('dragged');
        report.push(scene(cx));
        subscription.dispose();
        return report.join('\n');
    }

    static function panelProbe(log:Array<String>, name:String):IntoElement {
        return new SlotProbe(log, name, new DebugProbe('null-slots-' + name, div().sizeFull()));
    }

    static function group(state:Entity<ResizableState>, resizes:Array<Int>, log:Array<String>):ResizablePanelGroup {
        return Resizable.hResizable('null-slots')
            .withState(state)
            .onResize((_, _, _) -> resizes[0] = resizes[0] + 1)
            .withHandleAppearance((_, _, _) -> new SlotProbe(log, 'handle', div().sizeFull()).intoAnyElement());
    }

    static function frame(content:IntoElement):Div {
        return div().w(px(400.)).h(px(100.)).child(content);
    }

    function testResizableGroupSkipsNullPanels() {
        final element:Null<Div> = none();
        final into:Null<IntoElement> = none();
        final nested:Null<ResizablePanelGroup> = none();
        final panel:Null<glaze.kit.base.resizable.ResizablePanel> = none();
        final hidden = false;

        final expected = resizableRun((log, state, resizes) -> frame(group(state, resizes, log)
            .child(Resizable.resizablePanel().size(120.).child(panelProbe(log, 'panel-a')))
            .child(panelProbe(log, 'panel-b'))
            .child(Resizable.resizablePanel().child(panelProbe(log, 'panel-c')))
        ));
        final actual = resizableRun((log, state, resizes) -> frame(group(state, resizes, log)
            .child(null)
            .child((element : IntoElement))
            .child(Resizable.resizablePanel().size(120.).child(panelProbe(log, 'panel-a')))
            .child(into)
            .child(nested)
            .child(panel)
            .child(panelProbe(log, 'panel-b'))
            .child(hidden ? (div() : IntoElement) : null)
            .child(Resizable.resizablePanel().child(panelProbe(log, 'panel-c')))
            .child((element : IntoElement))
        ));
        assertSameRendering(expected, actual);
        // Two handles, between the three real panels, and one drag event.
        assertTrue(expected.indexOf('panels=3') != -1);
        assertTrue(expected.indexOf('resizable-handle-0') != -1);
        assertTrue(expected.indexOf('resizable-handle-1') != -1);
        assertTrue(expected.indexOf('resizable-handle-2') == -1);
        assertTrue(expected.indexOf('resizes=1 events=1') != -1);
    }

    function testResizableGroupChildrenSkipNullPanels() {
        final element:Null<Div> = none();
        final nested:Null<ResizablePanelGroup> = none();

        final expected = resizableRun((log, state, resizes) -> frame(group(state, resizes, log).children([
            Resizable.resizablePanel().size(120.).child(panelProbe(log, 'panel-a')),
            panelProbe(log, 'panel-b'),
            Resizable.resizablePanel().child(panelProbe(log, 'panel-c'))
        ])));
        final actual = resizableRun((log, state, resizes) -> frame(group(state, resizes, log).children([
            null,
            Resizable.resizablePanel().size(120.).child(panelProbe(log, 'panel-a')),
            (element : IntoElement),
            nested,
            panelProbe(log, 'panel-b'),
            null,
            Resizable.resizablePanel().child(panelProbe(log, 'panel-c')),
            (element : IntoElement)
        ])));
        assertSameRendering(expected, actual);
        assertTrue(expected.indexOf('panels=3') != -1);
        assertTrue(expected.indexOf('resizes=1 events=1') != -1);
    }

    // Message

    function testMessageNullAvatarIsNoAvatar() {
        final element:Null<Div> = none();
        final text:Null<String> = none();
        assertNull(Message.component().avatar(null).avatarValue);
        assertNull(Message.component().avatar(element).avatarValue);
        assertNull(Message.component().avatar(text).avatarValue);
        assertNull(Message.component().avatar('ME').avatar(null).avatarValue);
        assertNotNull(Message.component().avatar('ME').avatarValue);

        final message = (log:Array<String>, avatar:Bool, withNull:Null<IntoElement>) -> {
            final m = Message.component()
                .header(MessageHeader.component().child(new SlotProbe(log, 'header', div().w(px(40.)).h(px(10.)))))
                .content(MessageContent.component().child(new SlotProbe(log, 'content', div().w(px(80.)).h(px(20.)))))
                .footer(MessageFooter.component().child(new SlotProbe(log, 'footer', div().w(px(60.)).h(px(10.)))));
            if (avatar) m.avatar(withNull);
            return m;
        };
        for (alignment in [MessageAlignment.Start, MessageAlignment.End]) {
            final expected = rendered(log -> div().id('root').w(px(400.)).child(message(log, false, null).alignment(alignment)));
            for (value in [null, (element : IntoElement), (text : IntoElement)]) {
                final actual = rendered(log -> div().id('root').w(px(400.)).child(message(log, true, value).alignment(alignment)));
                assertSameRendering(expected, actual);
            }
            // Sanity: a real avatar moves the footer.
            final withAvatar = rendered(log -> div().id('root').w(px(400.)).child(message(log, true, div().size8()).alignment(alignment)));
            assertTrue(withAvatar != expected);
        }
    }

    // DescriptionList

    function testNullDescriptionTextConvertsToNull() {
        final text:Null<String> = none();
        final rich:Null<Text> = none();
        final into:Null<IntoElement> = none();
        assertTrue((text : DescriptionText) == null);
        assertTrue((rich : DescriptionText) == null);
        assertTrue((into : DescriptionText) == null);
        assertTrue(('x' : DescriptionText) != null);
    }

    function testNullDescriptionTextIsTheEmptyText() {
        final text:Null<String> = none();
        final rich:Null<Text> = none();
        final into:Null<IntoElement> = none();
        final list = (columns:Int) -> DescriptionList.component().columns(columns);

        for (layout in [glaze.Axis.Horizontal, glaze.Axis.Vertical]) {
            for (bordered in [true, false]) {
                final shape = (l:DescriptionList) -> l.layout(layout).bordered(bordered);
                // A null value is the value `DescriptionItem.create` leaves unset.
                final expected = rendered(_ -> div().id('root').w(px(500.)).child(shape(list(2))
                    .child(DescriptionItem.create('Name'))
                    .child(DescriptionItem.create('Role').span(1))
                    .child(DescriptionItem.create('').value('Label-less'))
                    .child(DescriptionItem.create('Team'))
                    .child(DescriptionItem.create('Desk'))
                    .child(DescriptionItem.create(''))
                ));
                final actual = rendered(_ -> div().id('root').w(px(500.)).child(shape(list(2))
                    .child(DescriptionItem.create('Name').value(null))
                    .item('Role', text, 1)
                    .item(null, 'Label-less', 1)
                    .child(DescriptionItem.create('Team').value(rich))
                    .child(DescriptionItem.create('Desk').value('Old').value(into))
                    .child(DescriptionItem.create(text).value(null))
                ));
                assertSameRendering(expected, actual);
            }
        }
        // The cell stays: an item whose label and value are null still takes
        // its row (one empty text line), unlike no item at all.
        final empty = rendered(_ -> div().id('root').w(px(500.)).child(DescriptionList.component().item(null, null, 1)));
        final noItem = rendered(_ -> div().id('root').w(px(500.)).child(DescriptionList.component()));
        assertTrue(empty != noItem);
    }

    // RadarChart

    static final DIMENSIONS = ['Speed', 'Power', 'Range', 'Armor', 'Agility'];

    static function radar(label:Null<(String) -> RadarLabel>):Div {
        final chart = new RadarChart(DIMENSIONS)
            .id('radar')
            .value(d -> d.length * 10.)
            .name('A');
        if (label != null) chart.label(label);
        return div().id('root').w(px(300.)).h(px(300.)).child(chart);
    }

    function testNullRadarLabelConvertsToNull() {
        final text:Null<String> = none();
        final element:Null<AnyElement> = none();
        assertTrue((text : RadarLabel) == null);
        assertTrue((element : RadarLabel) == null);
        assertTrue(('x' : RadarLabel) != null);
    }

    function testNullRadarLabelsDrawLikeAChartWithoutLabels() {
        final text:Null<String> = none();
        final element:Null<AnyElement> = none();
        final expected = rendered(_ -> radar(null));
        assertSameRendering(expected, rendered(_ -> radar(_ -> null)));
        assertSameRendering(expected, rendered(_ -> radar(_ -> text)));
        assertSameRendering(expected, rendered(_ -> radar(_ -> element)));
        assertSameRendering(expected, rendered(_ -> radar(_ -> RadarLabelKind.Text(null))));
        assertSameRendering(expected, rendered(_ -> radar(_ -> RadarLabelKind.Element(null))));
        // Sanity: real labels draw text.
        assertTrue(rendered(_ -> radar(d -> d)) != expected);
    }

    function testANullRadarLabelLeavesItsDimensionUnlabelled() {
        final text:Null<String> = none();
        final element:Null<AnyElement> = none();
        final kinds:Array<(String) -> RadarLabel> = [
            d -> d == 'Power' ? null : d,
            d -> d == 'Power' ? text : d,
            d -> d == 'Power' ? element : (d : RadarLabel),
            d -> d == 'Power' ? RadarLabelKind.Element(null) : (d : RadarLabel)
        ];
        final expected = rendered(_ -> radar(d -> d == 'Power' ? RadarLabelKind.Text(null) : (d : RadarLabel)));
        for (kind in kinds) {
            assertSameRendering(expected, rendered(_ -> radar(kind)));
        }
        assertTrue(expected != rendered(_ -> radar(d -> d)));

        // No label title for the dimension in its tooltip.
        final chart = new RadarChart(DIMENSIONS).value(d -> d.length * 10.).label(d -> d == 'Power' ? null : d);
        open(_ -> div().w(px(300.)).h(px(300.)).child(chart));
        final texts = @:privateAccess chart.labelTexts;
        assertEquals('Speed,-,Range,Armor,Agility', [for (text in texts) text == null ? '-' : text].join(','));
    }

    // HoverCard

    function testHoverCardNullTriggerThrows() {
        final element:Null<Div> = none();
        final text:Null<String> = none();
        final into:Null<IntoElement> = none();
        final message = 'HoverCard.trigger: the trigger element must not be null';
        assertEquals(message, HoverCard.NULL_TRIGGER_ERROR);
        for (trigger in [null, (element : IntoElement), (text : IntoElement), into]) {
            var thrown:Null<String> = null;
            try {
                HoverCard.component('card').trigger(trigger);
            }
            catch (e:Dynamic) {
                thrown = Std.string(e);
            }
            assertEquals(message, thrown);
            thrown = null;
            try {
                glaze.kit.base.HoverCard.component('card').trigger(trigger);
            }
            catch (e:Dynamic) {
                thrown = Std.string(e);
            }
            assertEquals(message, thrown);
        }
        // A real trigger is accepted.
        HoverCard.component('card').trigger('Hover me');
        glaze.kit.base.HoverCard.component('card').trigger(div());
    }

}

private class NullSlotView extends Model implements Render {

    final log:Array<String>;

    final build:(Array<String>) -> IntoElement;

    public function new(log:Array<String>, build:(Array<String>) -> IntoElement) {
        super();
        this.log = log;
        this.build = build;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        log.resize(0);
        return build(log);
    }

}

/** Records its name, global element id and bounds at prepaint */
private class SlotProbe extends Element {

    final log:Array<String>;

    final name:String;

    final child:AnyElement;

    public function new(log:Array<String>, name:String, child:IntoElement) {
        this.log = log;
        this.name = name;
        this.child = child.intoAnyElement();
    }

    override function elementId():Null<ElementId> {
        return ElementId.Name(name);
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        log.push(name + ' id=' + (id == null ? '-' : id.toString()) + ' bounds=' + bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}
