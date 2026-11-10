package scenarios;

import Scenario;
import glaze.AnyView;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseMoveEvent;
import glaze.Point;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.Window;
import glaze.kit.IconName;
import glaze.kit.badge.Badge;
import glaze.kit.base.input.InputState;
import glaze.kit.button.Button;
import glaze.kit.input.Input;

import glaze.Prelude.*;

/**
 * A large live UI with sparse state changes (the scenario of "A Critique of
 * GPUI", Nov 2026): `rowCount` rows (1000, 2000 or 3000, all live, not
 * virtualized) in a scroll container filling the standard kit window, each
 * row a small realistic row (an inbox icon in a kit `Badge` showing an
 * unread count, a title, a label, a small kit `Button`, a hover background).
 * One change per frame, the runner measures the frame (step, flush, draw).
 *
 * How the rows are built (`SparseRows`):
 *
 * - `PlainRows` (A): every row is plain elements of one view, rendered by one
 *   function (GPUI style), the state in one tracked model (`SparseStore`).
 * - `ViewRows` (B): one entity view per row reading its item model.
 *   Mode `full` is GPUI's pattern exactly: the window has no default view
 *   caching and each row is embedded with `.cached(style)` (the explicit
 *   row size). Mode `cached` is the same views without `.cached(style)`,
 *   under Glaze's default view caching.
 * - `ComponentRows` (C): persistent `glaze.Component` rows (`@persist`, the
 *   item as a `@prop`, its fields read and tracked in `render`). Mode `full`
 *   disables every view cache (every component renders each frame), mode
 *   `cached` is Glaze's default.
 *
 * What changes (`SparseChange`):
 *
 * - `ChangeLabel`: one row's label gets a new value (the row changes each frame).
 * - `EqualWrite`: one row's label is written with the value it holds.
 * - `HoverMove`: the mouse moves between two rows (one row's hover state).
 * - `TypeKey`: a keystroke in a kit `Input` above the list (alternately
 *   `a` and `backspace`), the list does not change.
 * - `FilterHalf`: the visible set alternates between all rows and the even rows
 *   (half of them torn down, then created again).
 * - `SharedRevision`: one global revision counter read by every row is incremented
 *   (the coarse case: every row depends on it).
 */
class Sparse extends BaseScenario {

    public static final SIZES:Array<Int> = [1000, 2000, 3000];

    public static inline final ROW_HEIGHT:Float = 32;

    /** Header height when the input is shown (`TypeKey`). */
    public static inline final HEADER_HEIGHT:Float = 48;

    /** The rows the mouse alternates between (`HoverMove`). */
    static inline final HOVER_ROW_A = 3;

    static inline final HOVER_ROW_B = 4;

    /** Every variant, for each size of `SIZES`. */
    public static function all():Array<Scenario> {
        final list:Array<Scenario> = [];
        for (n in SIZES) {
            list.push(new Sparse('a', PlainRows, ChangeLabel, n));
            list.push(new Sparse('b', ViewRows, ChangeLabel, n));
            list.push(new Sparse('c', ComponentRows, ChangeLabel, n));
            list.push(new Sparse('d', ComponentRows, EqualWrite, n));
            list.push(new Sparse('db', ViewRows, EqualWrite, n));
            list.push(new Sparse('e', ComponentRows, HoverMove, n));
            list.push(new Sparse('ea', PlainRows, HoverMove, n));
            list.push(new Sparse('eb', ViewRows, HoverMove, n));
            list.push(new Sparse('f', ComponentRows, TypeKey, n));
            list.push(new Sparse('fa', PlainRows, TypeKey, n));
            list.push(new Sparse('fb', ViewRows, TypeKey, n));
            list.push(new Sparse('g', ComponentRows, FilterHalf, n));
            list.push(new Sparse('ga', PlainRows, FilterHalf, n));
            list.push(new Sparse('gb', ViewRows, FilterHalf, n));
            list.push(new Sparse('h', ComponentRows, SharedRevision, n));
            list.push(new Sparse('ha', PlainRows, SharedRevision, n));
            list.push(new Sparse('hb', ViewRows, SharedRevision, n));
        }
        return list;
    }

    public final rows:SparseRows;

    public final change:SparseChange;

    public final rowCount:Int;

    var app:App;

    var window:Window;

    var store:Entity<SparseStore>;

    var items:Array<Entity<SparseItem>>;

    var shared:Entity<SparseShared>;

    var input:Null<Entity<InputState>> = null;

    /** The row views (`ViewRows`), created with the window. */
    var views:Array<AnyView>;

    final cachedStyle:StyleRefinement;

    /** Frame times (ms) of the removal and addition frames (`FilterHalf`). */
    final filterTimes:Array<Float> = [0, 0];

    final filterFrames:Array<Int> = [0, 0];

    var lastStepStart:Float = 0;

    public function new(letter:String, rows:SparseRows, change:SparseChange, rowCount:Int) {
        super('sparse-$letter-$rowCount');
        this.rows = rows;
        this.change = change;
        this.rowCount = rowCount;
        cachedStyle = glaze.StyleBuilder.build(s -> s.wFull().h(px(ROW_HEIGHT)).flexNone());
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        KitBench.initKit(app);
        final n = rowCount;
        app.update(cx -> {
            store = cx.newEntity((_:Context<SparseStore>) -> new SparseStore(n));
            shared = cx.newEntity((_:Context<SparseShared>) -> new SparseShared());
            items = [for (i in 0...n) cx.newEntity((_:Context<SparseItem>) -> new SparseItem(i))];
        });
        input = null;
        views = null;
        filterTimes[0] = filterTimes[1] = 0;
        filterFrames[0] = filterFrames[1] = 0;
        lastStepStart = 0;
        window = KitBench.openWindow(app, caching, (window, cx) -> {
            if (change == TypeKey) {
                input = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            }
            if (rows == ViewRows) {
                final readShared = change == SharedRevision;
                final shared = this.shared;
                views = [for (i in 0...n) {
                    final item = items[i];
                    (cx.newEntity((_:Context<SparseRowView>) -> new SparseRowView(item, readShared ? shared : null)) : AnyView);
                }];
            }
            return cx.newEntity((_:Context<BenchView>) -> new BenchView(renderRoot));
        });
        if (rows == ViewRows && !caching) {
            // GPUI: no default caching, the `.cached(style)` views are cached
            window.viewCachingDisabled = false;
            window.refresh();
            window.draw();
        }
        if (input != null) {
            final input = this.input;
            final window = this.window;
            app.update(cx -> input.update(cx, (state, scx) -> state.focus(window, cast scx)));
            KitBench.runUntilParked(app);
            window.drawIfDirty();
        }
        return window;
    }

    override function teardown():Void {
        if (change == FilterHalf && filterFrames[0] + filterFrames[1] > 0) {
            // Frame times by kind (the runner's statistics mix both)
            BenchRunner.print('  filter frames: remove half ' + fmtMs(filterTimes[0] / filterFrames[0]) + ' ms mean (' + filterFrames[0] + '), add half '
                + fmtMs(filterTimes[1] / filterFrames[1]) + ' ms mean (' + filterFrames[1] + ')');
        }
        this.items = null;
        this.store = null;
        this.shared = null;
        this.views = null;
        this.input = null;
    }

    override function step(frame:Int):Void {
        switch change {
            case ChangeLabel:
                setLabel(frame, 'Label $frame');
            case EqualWrite:
                setLabel(frame, null);
            case HoverMove:
                final row = frame % 2 == 0 ? HOVER_ROW_A : HOVER_ROW_B;
                final y = row * ROW_HEIGHT + ROW_HEIGHT / 2;
                KitBench.dispatch(app, window, new MouseMoveEvent(new Point(200, y), null, Modifiers.none()));
            case TypeKey:
                KitBench.keystroke(app, window, Keystroke.parse(frame % 2 == 0 ? 'a->a' : 'backspace'));
            case FilterHalf:
                // The previous frame ended about when this one starts:
                // record its time under its kind (even: removal, odd: addition)
                final now = haxe.Timer.stamp();
                if (frame > BenchRunner.WARMUP_FRAMES && lastStepStart > 0) {
                    final kind = (frame - 1) % 2;
                    filterTimes[kind] += (now - lastStepStart) * 1000;
                    filterFrames[kind]++;
                }
                lastStepStart = now;
                final filter = shared.read(app);
                filter.half = !filter.half;
            case SharedRevision:
                final state = shared.read(app);
                state.revision = state.revision + 1;
        }
    }

    /**
     * Writes the label of one row (the rows in turn, spread over the list),
     * `null` writes the value it already holds.
     */
    function setLabel(frame:Int, value:Null<String>):Void {
        final index = (frame * 7) % rowCount;
        if (rows == PlainRows) {
            final store = this.store.read(app);
            final labels = store.labels;
            if (value != null) {
                labels[index] = value;
                store.invalidateLabels();
            }
            else {
                // A tracked write of the same array: nothing changes
                store.labels = labels;
            }
        }
        else {
            final item = items[index].read(app);
            item.label = value != null ? value : item.label;
        }
    }

    static function fmtMs(ms:Float):String {
        return Std.string(Math.round(ms * 100) / 100);
    }

    function renderRoot(window:Window, cx:Context<Dynamic>):IntoElement {
        final half = change == FilterHalf && shared.read(cx).half;
        final step = half ? 2 : 1;
        final list = div().id('list').flex().flexCol().flex1().minH0().overflowYScroll();
        switch rows {
            case PlainRows:
                final store = this.store.read(cx);
                final labels = store.labels;
                final revision = change == SharedRevision ? shared.read(cx).revision : -1;
                var i = 0;
                while (i < rowCount) {
                    list.child(renderRow(i, store.titles[i], labels[i], store.counts[i], revision));
                    i += step;
                }
            case ViewRows:
                final gpui = !window.viewCaching;
                var i = 0;
                while (i < rowCount) {
                    final view = views[i];
                    list.child(gpui ? view.cached(cachedStyle) : (view : IntoElement));
                    i += step;
                }
            case ComponentRows:
                final readShared = change == SharedRevision;
                var i = 0;
                while (i < rowCount) {
                    list.child(SparseRow.component().at(i).item(items[i]).shared(readShared ? shared : null));
                    i += step;
                }
        }
        final root = div().id('sparse').sizeFull().flex().flexCol();
        if (input != null) {
            root.child(div().h(px(HEADER_HEIGHT)).flexNone().p2().child(Input.component(input)));
        }
        return root.child(list);
    }

    /**
     * One row: an inbox icon in a badge with the unread count, the title,
     * the label (and the shared revision when `revision` is not -1), a small
     * button, a hover background.
     */
    public static function renderRow(index:Int, title:String, label:String, count:Int, revision:Int):IntoElement {
        final text = revision >= 0 ? '$label (rev $revision)' : label;
        return div().id(index).h(px(ROW_HEIGHT)).flexNone().flex().itemsCenter().gap3().px3()
            .borderB1().borderColor(hsla(0.6, 0.15, 0.9, 1))
            .hover(s -> s.bg(hsla(0.6, 0.4, 0.96, 1)))
            .child(Badge.component().count(count).child(glaze.kit.Icon.component(IconName.Inbox)))
            .child(div().flex1().textSm().child(title))
            .child(div().w(px(220)).textXs().textColor(hsla(0, 0, 0.4, 1)).child(text))
            .child(Button.component('open').label('Open').ghost().withSize(glaze.kit.Size.Small));
    }

}

enum SparseRows {
    PlainRows;
    ViewRows;
    ComponentRows;
}

enum SparseChange {
    ChangeLabel;
    EqualWrite;
    HoverMove;
    TypeKey;
    FilterHalf;
    SharedRevision;
}

/** The data of every row in one tracked model (`PlainRows`, GPUI style). */
class SparseStore extends Model {

    @observe public var labels:Array<String>;

    public final titles:Array<String>;

    public final counts:Array<Int>;

    public function new(n:Int) {
        super();
        labels = [for (i in 0...n) SparseItem.initialLabel(i)];
        titles = [for (i in 0...n) SparseItem.initialTitle(i)];
        counts = [for (i in 0...n) SparseItem.initialCount(i)];
    }

}

/** The data of one row (`ViewRows` and `ComponentRows`). */
class SparseItem extends Model {

    @observe public var label:String;

    public final title:String;

    public final count:Int;

    public final index:Int;

    public function new(index:Int) {
        super();
        this.index = index;
        label = initialLabel(index);
        title = initialTitle(index);
        count = initialCount(index);
    }

    public static function initialLabel(i:Int):String {
        return 'Updated ${(i * 37) % 60} min ago';
    }

    public static function initialTitle(i:Int):String {
        return 'Conversation $i with the team about item ${(i * 7919) % 1000}';
    }

    public static function initialCount(i:Int):Int {
        return (i * 13) % 7;
    }

}

/** The global state: a revision read by every row (`SharedRevision`), the filter (`FilterHalf`). */
class SparseShared extends Model {

    @observe public var revision:Int = 0;

    @observe public var half:Bool = false;

    public function new() {
        super();
    }

}

/** One row as an entity view (`ViewRows`). */
class SparseRowView extends Model implements Render {

    final item:Entity<SparseItem>;

    final shared:Null<Entity<SparseShared>>;

    public function new(item:Entity<SparseItem>, shared:Null<Entity<SparseShared>>) {
        super();
        this.item = item;
        this.shared = shared;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final item = this.item.read(cx);
        return Sparse.renderRow(item.index, item.title, item.label, item.count, shared != null ? shared.read(cx).revision : -1);
    }

}

/** One row as a persistent component (`ComponentRows`): its reads are tracked. */
@persist
class SparseRow extends Component {

    @prop var item:Entity<SparseItem> = null;

    @prop var shared:Null<Entity<SparseShared>> = null;

    function render(window:Window, cx:App):IntoElement {
        final item = this.item.read(cx);
        return Sparse.renderRow(item.index, item.title, item.label, item.count, shared != null ? shared.read(cx).revision : -1);
    }

}
