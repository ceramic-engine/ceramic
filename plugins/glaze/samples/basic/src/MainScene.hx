package;

import ceramic.Scene;
import gpui.Action;
import gpui.App;
import gpui.Context;
import gpui.Div;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Model;
import gpui.Render;
import gpui.ScrollHandle;
import gpui.Window;

import gpui.Prelude.*;

@:action(namespace = sample) class FocusNext implements Action {}
@:action(namespace = sample) class FocusPrev implements Action {}
@:action(namespace = sample) class Increment implements Action {}
@:action(namespace = sample) class Reset implements Action {}

/**
 * The value dragged from the palette to the drop zone.
 */
class DraggedColor {

    public final hue:Float;

    public function new(hue:Float) {
        this.hue = hue;
    }

}

/**
 * An interactive GPUI view:
 *
 * - cards with hover and active styles, focusable with tab / shift-tab
 *   (bound to actions), clicked with the mouse or enter / space;
 * - a scrollable list (mouse wheel), with buttons scrolling its handle;
 * - a counter changed by actions (`+` / `r` key bindings) and a timer. The
 *   counter is an `@observe` field: views are drawn again without `notify()`;
 * - colors dragged onto a drop zone, and a tooltip;
 * - text (Inter and JetBrains Mono, bundled with the plugin), Lucide icons
 *   tinted by the text color, an image and a virtualized list of 10000 rows.
 */
class MainScene extends Scene {

    var window:Window;

    var counter:Entity<CounterModel>;

    override function create() {

        final cx = App.current;

        cx.bindKeys([
            new KeyBinding('tab', new FocusNext(), null),
            new KeyBinding('shift-tab', new FocusPrev(), null),
            new KeyBinding('+', new Increment(), 'Sample'),
            new KeyBinding('=', new Increment(), 'Sample'),
            new KeyBinding('r', new Reset(), 'Sample'),
        ]);

        counter = cx.newEntity((_:Context<CounterModel>) -> new CounterModel());

        // `svg().path(...)` and `img(...)` read the app's asset source:
        // preload the files (synchronous file access is not available everywhere)
        App.defaultAssetSource().preload(SampleView.ICONS.concat(['ceramic.png']), _ -> {
            window = Window.open(cx, {width: width, height: height}, (window, cx) -> {
                return cx.newEntity((viewCx:Context<SampleView>) -> new SampleView(counter, viewCx));
            });
            add(window.renderable);
        });

        // Not inside a render: the timer never subscribes anything
        ceramic.Timer.interval(this, 1.0, () -> {
            counter.read(cx).ticks++;
        });

        log.success('GPUI window ready');

    }

    override function resize(width:Float, height:Float) {

        if (window != null) {
            window.resize(width, height);
        }

    }

    override function destroy() {

        if (window != null) {
            window.destroy();
            window = null;
        }

        super.destroy();

    }

}

class CounterModel extends Model {

    @observe public var count:Int = 0;

    @observe public var ticks:Int = 0;

    public function new() {
        super();
    }

}

class SampleView extends Model implements Render {

    final counter:Entity<CounterModel>;

    final root:FocusHandle;

    final cards:Array<FocusHandle>;

    final list:ScrollHandle = new ScrollHandle();

    @observe var dropped:Array<Float> = [];

    public static final ICONS:Array<String> = ['icons/heart.svg', 'icons/star.svg', 'icons/settings.svg', 'icons/search.svg', 'icons/bell.svg'];

    static final CARD_TITLES = ['Inbox', 'Starred', 'Settings', 'Search'];

    public function new(counter:Entity<CounterModel>, cx:Context<SampleView>) {
        super();
        this.counter = counter;
        root = cx.focusHandle();
        cards = [for (_ in 0...4) cx.focusHandle().tabStop(true)];
    }

    static inline function bg():gpui.Hsla {
        return hsla(0.61, 0.20, 0.13, 1.0);
    }

    function card(index:Int, hue:Float):Div {
        final color = hsla(hue, 0.7, 0.55, 1.0);
        return div()
            .id(ElementIdArgs.named('card', index))
            .trackFocus(cards[index])
            .flex()
            .flexCol()
            .w(px(120))
            .h(px(84))
            .p3()
            .gap2()
            .roundedXl()
            .bg(hsla(0.0, 0.0, 0.98, 1.0))
            .shadowMd()
            .border2()
            .borderColor(hsla(0, 0, 0, 0))
            .cursorPointer()
            .hover(s -> s.bg(hsla(hue, 0.4, 0.92, 1.0)).shadowLg())
            .active(s -> s.bg(hsla(hue, 0.5, 0.82, 1.0)))
            .focus(s -> s.borderColor(color))
            // Mouse clicks, or enter / space when focused (double clicks count twice)
            .onClick((event, window, cx) -> counter.read(cx).count += event.clickCount())
            .child(
                div().flex().itemsCenter().gap2()
                    .child(svg().path(ICONS[index]).size(px(16)).textColor(color))
                    .child(div().textSm().fontWeight(gpui.FontWeight.SEMIBOLD).textColor(hsla(0.0, 0.0, 0.2, 1.0)).child(CARD_TITLES[index]))
            )
            .child(div().h2().wFull().roundedFull().bg(color))
            .child(div().textXs().textColor(hsla(0.0, 0.0, 0.45, 1.0)).truncate().child('Click, or tab then enter'));
    }

    function button(id:String, hue:Float, onClick:() -> Void):Div {
        return div()
            .id(id)
            .w(px(36))
            .h(px(28))
            .roundedMd()
            .bg(hsla(hue, 0.5, 0.45, 1.0))
            .cursorPointer()
            .hover(s -> s.bg(hsla(hue, 0.6, 0.55, 1.0)))
            .active(s -> s.bg(hsla(hue, 0.7, 0.35, 1.0)))
            .onClick((_, _, _) -> onClick());
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final model = counter.read(cx);
        final count = model.count;
        final ticks = model.ticks;

        return div()
            .id('root')
            .textColor(hsla(0.0, 0.0, 0.92, 1.0))
            .fontFamily('Inter')
            .textSize(px(14))
            .keyContext('Sample')
            .trackFocus(root)
            .onAction(FocusNext, (_, window, cx) -> window.focusNext(cx))
            .onAction(FocusPrev, (_, window, cx) -> window.focusPrev(cx))
            .onAction(Increment, (_, _, cx) -> counter.read(cx).count++)
            .onAction(Reset, (_, _, cx) -> counter.read(cx).count = 0)
            .flex()
            .flexCol()
            .sizeFull()
            .gap6()
            .p8()
            .bg(bg())
            // Cards: hover, active, focus (tab / shift-tab), click
            .child(
                div().flex().flexWrap().gap6()
                    .child(card(0, 0.58))
                    .child(card(1, 0.33))
                    .child(card(2, 0.08))
                    .child(card(3, 0.83))
            )
            .child(
                div().flex().gap6().flex1()
                    // A scrollable list, with buttons driving its scroll handle
                    .child(
                        div().flex().flexCol().gap2()
                            .child(
                                div().id('list').w(px(220)).h(px(220)).roundedLg().bg(hsla(0.61, 0.2, 0.2, 1.0))
                                    .overflowYScroll().trackScroll(list).flex().flexCol().p2().gap2()
                                    .children([for (i in 0...20) {
                                        final hue = i / 20;
                                        div().id(ElementIdArgs.named('row', i)).flexNone().h(px(32)).roundedMd()
                                            .bg(hsla(hue, 0.45, 0.4, 1.0))
                                            .hover(s -> s.bg(hsla(hue, 0.6, 0.55, 1.0)))
                                            .when(i == count % 20, d -> d.border2().borderColor(hsla(0.13, 0.9, 0.6, 1.0)));
                                    }])
                            )
                            .child(
                                div().flex().gap2()
                                    .child(button('top', 0.58, () -> list.scrollToItem(0)))
                                    .child(button('current', 0.13, () -> list.scrollToItem(count % 20)))
                                    .child(button('bottom', 0.33, () -> list.scrollToItem(19)))
                            )
                    )
                    // Counter, drag and drop, tooltip
                    .child(
                        div().flex().flexCol().gap4().flex1()
                            .child(
                                // The counter: `count` (actions, clicks) and `ticks` (timer) are observed fields
                                div().flex().gap2().itemsCenter()
                                    .child(div().w(px(90)).child('Count: $count'))
                                    .children([for (i in 0...10) div().size(px(16)).roundedFull()
                                        .bg(i < count % 11 ? hsla(0.13, 0.9, 0.6, 1.0) : hsla(0, 0, 0.3, 1.0))])
                                    .child(div().w(px(8)).h(px(16)).bg(hsla((ticks % 10) / 10, 0.7, 0.55, 1.0)))
                            )
                            .child(
                                // Palette: drag a color onto the drop zone
                                div().flex().gap2().children([for (i in 0...5) {
                                    final hue = i / 5;
                                    div().id(ElementIdArgs.named('chip', i)).size(px(32)).roundedMd()
                                        .bg(hsla(hue, 0.7, 0.55, 1.0))
                                        .cursorGrab()
                                        .onDrag(new DraggedColor(hue), (value:DraggedColor, _, _, cx:App) -> {
                                            return cx.newEntity(_ -> new ChipView(value.hue));
                                        });
                                }])
                            )
                            .child(
                                div().id('drop').flex().gap1().p2().h(px(64)).roundedLg()
                                    .border2().borderDashed().borderColor(hsla(0, 0, 0.5, 1.0))
                                    .dragOver(DraggedColor, (s, value, _, _) -> s.borderColor(hsla(value.hue, 0.8, 0.6, 1.0)).bg(hsla(value.hue, 0.3, 0.25, 1.0)))
                                    .onDrop(DraggedColor, (value, _, _) -> dropped = dropped.concat([value.hue]))
                                    .children([for (hue in dropped) div().size(px(16)).roundedFull().bg(hsla(hue, 0.7, 0.55, 1.0))])
                            )
                            .child(
                                div().id('help').flex().itemsCenter().gap2().px3().w(px(160)).h(px(32)).roundedMd().bg(hsla(0.61, 0.2, 0.3, 1.0))
                                    .hover(s -> s.bg(hsla(0.61, 0.25, 0.38, 1.0)))
                                    .tooltip((_, cx) -> cx.newEntity(_ -> new TooltipView()))
                                    .child(svg().path('icons/bell.svg').size(px(16)).textColor(hsla(0.13, 0.9, 0.6, 1.0)))
                                    .child('Hover me')
                            )
                            .child(
                                div().fontFamily('JetBrains Mono').textXs().textColor(hsla(0.33, 0.6, 0.65, 1.0))
                                    .child('counter.read(cx).count += 1; // -> != =>')
                            )
                    )
                    // A virtualized list: only the visible rows are built
                    .child(
                        div().flex().flexCol().gap2().w(px(220))
                            .child(
                                div().flex().itemsCenter().gap2()
                                    // Decoded asynchronously from the asset bytes, shown when ready
                                    .child(img('ceramic.png').size(px(32)).roundedMd().objectFit(gpui.ObjectFit.Cover))
                                    .child(div().textSm().child('10000 rows (uniform_list)'))
                            )
                            .child(
                                uniformList('rows', 10000, (start, end, window, cx) -> [for (i in start...end) {
                                    div().id(ElementIdArgs.named('item', i)).flex().itemsCenter().gap2().px2().h(px(28))
                                        .bg(i % 2 == 0 ? hsla(0.61, 0.2, 0.18, 1.0) : hsla(0.61, 0.2, 0.22, 1.0))
                                        .hover(s -> s.bg(hsla(0.58, 0.4, 0.3, 1.0)))
                                        .child(svg().path(ICONS[i % ICONS.length]).size(px(14)).textColor(hsla((i % 12) / 12, 0.6, 0.65, 1.0)))
                                        .child('Row ${i + 1}');
                                }]).h(px(260)).roundedLg()
                            )
                    )
            );
    }

}

/**
 * The view following the mouse while a color is dragged.
 */
class ChipView extends Model implements Render {

    final hue:Float;

    public function new(hue:Float) {
        super();
        this.hue = hue;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(28)).roundedFull().bg(hsla(hue, 0.7, 0.55, 0.9)).shadowLg();
    }

}

class TooltipView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(140)).h(px(36)).p2().roundedMd().bg(hsla(0.12, 0.8, 0.6, 1.0)).shadowMd()
            .child(div().h2().wFull().roundedFull().bg(hsla(0, 0, 0.2, 1.0)));
    }

}

class ElementIdArgs {

    public static inline function named(name:String, index:Int):gpui.ElementIdArg {
        return gpui.ElementId.NamedInteger(name, index);
    }

}
