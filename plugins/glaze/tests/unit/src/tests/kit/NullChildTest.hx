package tests.kit;

import glaze.AnyElement;
import glaze.AnyView;
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
import glaze.Render;
import glaze.RenderOnce;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.button.Button;
import glaze.kit.statusbar.StatusBar;
import glaze.kit.table.Table;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * `child(null)` and null entries of `children([...])` are skipped: the
 * same as not calling `child()` or not passing the entry (a convenience of
 * the port, Rust passes an `Option` through `children` or `when_some`).
 * Every implicit `IntoElement` conversion turns a null source into a null
 * `IntoElement`, without calling anything on it.
 *
 * Each test renders a tree with nulls and the same tree without them, and
 * compares what probes record at prepaint: their order, their global
 * element ids (positional ids such as the table heads' included) and their
 * bounds.
 */
class NullChildTest extends TestCase {

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
        ceramic.App.app.flushImmediate();
    }

    function renderLog(build:(Array<String>) -> IntoElement):Array<String> {
        final log:Array<String> = [];
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            final content = rootCx.newEntity((c:Context<NullChildView>) -> new NullChildView(log, build));
            return new Root(content, window, rootCx);
        }, 400, 300);
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        return log;
    }

    function assertSameLog(expected:Array<String>, actual:Array<String>) {
        assertTrue(expected.length > 0, 'the reference tree records probes');
        // Each window has its own root views (`view-N` ids): compare the rest
        final views = ~/view-[0-9]+/g;
        assertEquals(views.replace(expected.join('\n'), 'view'), views.replace(actual.join('\n'), 'view'));
    }

    /** A null of any type, not folded by the compiler */
    static function none<T>():Null<T> {
        return null;
    }

    function testIntoElementConversionsOfNullGiveNull() {
        final element:Null<Div> = none();
        final text:Null<String> = none();
        final render:Null<Render> = none();
        final anyView:Null<AnyView> = none();
        final entity:Null<Entity<NullChildView>> = none();
        final component:Null<RenderOnce> = none();
        final anyElement:Null<AnyElement> = none();
        assertTrue((element : IntoElement) == null);
        assertTrue((text : IntoElement) == null);
        assertTrue((render : IntoElement) == null);
        assertTrue((anyView : IntoElement) == null);
        assertTrue((entity : IntoElement) == null);
        assertTrue((component : IntoElement) == null);
        assertTrue((anyElement : IntoElement) == null);
        assertTrue((div() : IntoElement) != null);
        assertTrue(("text" : IntoElement) != null);
    }

    function testChildNullIsSkipped() {
        final element:Null<Div> = none();
        final text:Null<String> = none();
        final render:Null<Render> = none();
        final anyView:Null<AnyView> = none();
        final entity:Null<Entity<NullChildView>> = none();
        final component:Null<RenderOnce> = none();
        final button:Null<Button> = none();
        final anyElement:Null<AnyElement> = none();
        final into:Null<IntoElement> = none();
        final hidden = false;

        final expected = renderLog(log -> div().id('root').flex().flexCol()
            .child(probe(log, 'a', true))
            .child(div().id('inner').flex().child(probe(log, 'b', false)).child(probe(log, 'c', true)))
            .child('text')
            .child(probe(log, 'd', true))
        );
        final actual = renderLog(log -> div().id('root').flex().flexCol()
            .child(null)
            .child(probe(log, 'a', true))
            .child(element)
            .child(text)
            .child(div().id('inner').flex().child(null).child(probe(log, 'b', false)).child(entity).child(probe(log, 'c', true)).child(anyView))
            .child(render)
            .child(component)
            .child('text')
            .child(button)
            .child(anyElement)
            .child(into)
            .child(hidden ? div() : null)
            .child(probe(log, 'd', true))
            .child(hidden ? 'shown' : null)
        );
        assertSameLog(expected, actual);
    }

    function testChildrenSkipsNullEntries() {
        final element:Null<Div> = none();
        final text:Null<String> = none();
        final entity:Null<Entity<NullChildView>> = none();
        final component:Null<RenderOnce> = none();

        final expected = renderLog(log -> div().id('root').flex()
            .children([probe(log, 'a', true), probe(log, 'b', false), 'text', probe(log, 'c', true)])
        );
        final actual = renderLog(log -> div().id('root').flex()
            .children([null, probe(log, 'a', true), element, probe(log, 'b', false), text, entity, 'text', null, component, probe(log, 'c', true), null])
        );
        assertSameLog(expected, actual);
    }

    function testElementsAndComponentsSkipNullChildren() {
        final element:Null<Div> = none();
        final text:Null<String> = none();

        final expected = renderLog(log -> div().id('root').flex().flexCol()
            .child(anchored().child(probe(log, 'anchored', true)))
            .child(div().withAnimation('anim', new glaze.Animation(1.0), (d, _) -> d).child(probe(log, 'animated', true)))
            .child(StatusBar.component().left(probe(log, 'left', true)).right(probe(log, 'right', true)).child(probe(log, 'bar', true)))
            .child(Table.component()
                .child(TableHeader.component().child(TableRow.component()
                    .child(TableHead.component().child(probe(log, 'h0', true)))
                    .child(TableHead.component().child(probe(log, 'h1', true)))
                ))
                .child(TableBody.component().children([
                    TableRow.component().child(TableCell.component().child(probe(log, 'r0', true))),
                    TableRow.component().child(TableCell.component().child(probe(log, 'r1', true)))
                ]))
            )
        );
        final actual = renderLog(log -> div().id('root').flex().flexCol()
            .child(anchored().child(null).child(probe(log, 'anchored', true)).child(element))
            .child(div().withAnimation('anim', new glaze.Animation(1.0), (d, _) -> d).child(text).child(probe(log, 'animated', true)).child(null))
            .child(StatusBar.component().left(null).left(probe(log, 'left', true)).right(element).right(probe(log, 'right', true)).child(null).child(probe(log, 'bar', true)))
            .child(Table.component()
                .child(null)
                .child(TableHeader.component().child(TableRow.component()
                    .child(null)
                    .child(TableHead.component().child(probe(log, 'h0', true)).child(null))
                    .children([null])
                    .child(TableHead.component().child(text).child(probe(log, 'h1', true)))
                ))
                .child(TableBody.component().children([
                    null,
                    TableRow.component().child(TableCell.component().child(probe(log, 'r0', true))),
                    null,
                    TableRow.component().children([null, TableCell.component().child(probe(log, 'r1', true))])
                ]))
            )
        );
        assertSameLog(expected, actual);
    }

    /** A sized element recording its global id and bounds at prepaint */
    static function probe(log:Array<String>, name:String, withId:Bool):NullChildProbe {
        return new NullChildProbe(log, name, withId);
    }

}

private class NullChildView extends Model implements Render {

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

private class NullChildProbe extends Element {

    final log:Array<String>;

    final name:String;

    final withId:Bool;

    final child:AnyElement;

    public function new(log:Array<String>, name:String, withId:Bool) {
        this.log = log;
        this.name = name;
        this.withId = withId;
        child = div().w(px(10)).h(px(10)).intoAnyElement();
    }

    override function elementId():Null<ElementId> {
        return withId ? ElementId.Name(name) : null;
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
