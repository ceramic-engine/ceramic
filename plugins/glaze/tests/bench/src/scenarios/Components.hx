package scenarios;

import glaze.AnyView;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.RenderOnce;
import glaze.Window;

import glaze.Prelude.*;

/**
 * `glaze.Component` against the equivalent hand written code: a list of
 * `ROWS` rows showing an item of a model, one item changing per frame.
 *
 * - `components-persistent`: persistent components (`Row.component()`,
 *   each reading its item), against `components-views`: one entity view per
 *   row, created up front;
 * - `components-stateless`: stateless components rebuilt by their parent,
 *   which reads a frame counter, against `components-renderonce`: the same
 *   rows as `RenderOnce` builders.
 *
 * The frame times of each pair must be the same within noise.
 */
class Components extends BaseScenario {

    public static inline final ROWS = 200;

    public static inline final COLUMNS = 4;

    final kind:ComponentsKind;

    var app:App;

    var items:Array<Entity<BenchItem>> = [];

    var tick:Entity<BenchItem>;

    public function new(kind:ComponentsKind) {
        super('components-' + switch kind {
            case Persistent: 'persistent';
            case Views: 'views';
            case Stateless: 'stateless';
            case RenderOnceRows: 'renderonce';
        });
        this.kind = kind;
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        if (items.length == 0) {
            for (i in 0...ROWS) {
                items.push(app.newEntity(_ -> new BenchItem('Item $i', i)));
            }
            tick = app.newEntity(_ -> new BenchItem('tick', 0));
        }
        return BenchRunner.openWindow(app, caching, buildRoot);
    }

    override function step(frame:Int):Void {
        final item = items[frame % items.length].read(app);
        item.value = item.value + 1;
        if (kind == Stateless || kind == RenderOnceRows) {
            // The parent re-renders every frame (the stateless rows with it)
            final tick = this.tick.read(app);
            tick.value = tick.value + 1;
        }
    }

    function buildRoot():AnyView {
        final items = this.items;
        switch kind {
            case Persistent:
                return app.newEntity((_:Context<BenchView>) -> new BenchView((_, _) ->
                    grid().children([for (item in items) PersistentRow.component().at(item.read(app).index).item(item)])
                ));
            case Views:
                final rows = [for (item in items) app.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> renderRow(item.read(cx))))];
                return app.newEntity((_:Context<BenchView>) -> new BenchView((_, _) ->
                    grid().children([for (row in rows) (row : AnyView)])
                ));
            case Stateless:
                final tick = this.tick;
                return app.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> {
                    tick.read(cx).value;
                    return grid().children([for (item in items) StatelessRow.component().item(item.read(cx))]);
                }));
            case RenderOnceRows:
                final tick = this.tick;
                return app.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> {
                    tick.read(cx).value;
                    return grid().children([for (item in items) new RenderOnceRow().item(item.read(cx))]);
                }));
        }
    }

    static function grid() {
        return div().id('root').sizeFull().flex().flexWrap().gap1().p2().bg(hsla(0.6, 0.1, 0.96, 1));
    }

    /**
     * The row, shared by the four kinds: a label, a value and a bar.
     */
    public static function renderRow(item:BenchItem):IntoElement {
        final value = item.value;
        return div().id('row').w(px(300)).h(px(22)).flex().itemsCenter().gap2().px2()
            .bg(white()).border1().borderColor(hsla(0.6, 0.2, 0.8, 1)).roundedSm()
            .child(div().textSm().w(px(80)).child(item.title))
            .child(div().textXs().textColor(hsla(0, 0, 0.3, 1)).w(px(40)).child('$value'))
            .child(div().h(px(4)).w(px(120)).bg(hsla(0, 0, 0.9, 1)).roundedFull()
                .child(div().h(px(4)).w(px(10 + (value * 7) % 110)).bg(hsla(0.6, 0.7, 0.5, 1)).roundedFull()));
    }

}

enum ComponentsKind {
    Persistent;
    Views;
    Stateless;
    RenderOnceRows;
}

class BenchItem extends Model {

    @observe public var value:Int = 0;

    @observe public var title:String;

    public final index:Int;

    public function new(title:String, index:Int) {
        super();
        this.title = title;
        this.index = index;
    }

}

/**
 * A persistent component reading its item (an observable it reads changes:
 * only this component renders again).
 */
@persist
class PersistentRow extends Component {

    @prop var item:Entity<BenchItem> = null;

    function render(window:Window, cx:App):IntoElement {
        return Components.renderRow(item.read(cx));
    }

}

/**
 * A stateless component, rebuilt and rendered with its parent.
 */
class StatelessRow extends Component {

    @prop var item:BenchItem = null;

    function render(window:Window, cx:App):IntoElement {
        return Components.renderRow(item);
    }

}

/**
 * The hand written equivalent of `StatelessRow`.
 */
class RenderOnceRow implements RenderOnce {

    var itemValue:BenchItem = null;

    public function new() {}

    public function item(item:BenchItem):RenderOnceRow {
        itemValue = item;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return Components.renderRow(itemValue);
    }

}
