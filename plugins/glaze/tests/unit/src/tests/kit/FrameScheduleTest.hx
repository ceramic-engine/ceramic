package tests.kit;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.PlatformInput;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.StyleBuilder;
import glaze.Subscription;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import glaze.kit.input.Editor;
import glaze.kit.input.Input;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Frames drawn and views rendered per frame, compared with the real GPUI.
 *
 * The kit tests drive the page of the golden scene `kit-input-scroll-follow`
 * (`reference/src/kit_scenes13_input_scroll.rs`) like the reference
 * harness: a page view `P` under gpui-kit's `Root` (not cached: it renders
 * in every frame, so each `P render` starts a frame), a cached sidebar view
 * `S` and cached field views `F1` (Input A), `F2` (Input B) and `F3`
 * (Editor C). The app draws a dirty window when its effects are flushed
 * (GPUI's test mode). The expected logs are those of the real GPUI (the
 * reference harness logging every render).
 */
@:access(glaze.App)
class FrameScheduleTest extends TestCase {

    static final FULL = ['P render', 'S render', 'F1 render', 'F2 render', 'F3 render'];

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    var log:Array<String> = [];

    var page:Null<SchedulePage> = null;

    override function setup() {
        log = [];
        page = null;
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

/// Harness

    /**
     * Rust `HeadlessAppContext::update`: runs `f` on the app without
     * flushing the effects (the next update flushes them).
     */
    function headlessUpdate(f:(App) -> Void):Void {
        app.startUpdate();
        f(app);
        app.pendingUpdates--;
    }

    /** Rust `kit_scenes6_inputs::init` and the mono font of the scene, in headless updates. */
    function init():Void {
        headlessUpdate(cx -> {
            cx.setReduceMotion(true);
            Theme.change(ThemeMode.Light, null, cx);
            Theme.setScrollbarMode(Always, cx);
        });
        headlessUpdate(cx -> {
            Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            Theme.syncBase(cx);
        });
    }

    /**
     * Rust `Script::open`: `App::open_window` (one update: build, draw,
     * then the effects are flushed), activate, run until parked, refresh
     * and draw.
     */
    function open():Void {
        app.update(cx -> {
            window = Window.open(cx, {width: 512, height: 512, scaleFactor: 2, autoDraw: false, active: false, bindInput: false, viewCaching: false}, (window, cx) -> {
                final entity = cx.newEntity((c:Context<SchedulePage>) -> page = new SchedulePage(window, c, log));
                return cx.newEntity((rootCx:Context<Root>) -> new Root(entity, window, rootCx));
            });
            window.draw();
        });
        app.update(_ -> window.setActive(true));
        dispatcher.runUntilParked();
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
    }

    function update(fn:(Window, App) -> Void):Void {
        app.update(cx -> fn(window, cx));
        dispatcher.runUntilParked();
    }

    function step(desc:String, fn:(Window, App) -> Void):Void {
        log.push('> $desc');
        update(fn);
    }

    /** Move, down, up, each in its own update (`  event` before each). */
    function click(name:String, x:Float, y:Float):Void {
        log.push('> click $name');
        final position = new Point(x, y);
        final events:Array<PlatformInput> = [
            new MouseMoveEvent(position, null, Modifiers.none()),
            new MouseDownEvent(MouseButton.Left, position, Modifiers.none(), 1, false),
            new MouseUpEvent(MouseButton.Left, position, Modifiers.none(), 1),
        ];
        for (input in events) {
            log.push('  event');
            update((window, cx) -> window.dispatchEvent(input, cx));
        }
    }

    function scroll(dy:Float):Void {
        step('scroll', (window, cx) -> window.dispatchEvent(new ScrollEvent(new Point(490, 300), ScrollDelta.Pixels(new Point(0, dy)), Modifiers.none()), cx));
    }

    function notifySidebar():Void {
        step('notify S', (_, cx) -> page.sidebar.update(cx, (_, cx) -> cx.notify()));
    }

    function scrollPhase():Void {
        scroll(-24);
        scroll(-24);
        notifySidebar();
        scroll(24);
        notifySidebar();
    }

    function key(ks:String):Void {
        step('key $ks', (window, cx) -> window.dispatchKeystroke(Keystroke.parse(ks), cx));
    }

    /** The log lines from `marker` (excluded) to the next step. */
    function segment(marker:String):Array<String> {
        final start = log.indexOf(marker);
        assertTrue(start != -1, 'step $marker logged');
        final result = [];
        var i = start + 1;
        while (i < log.length && !StringTools.startsWith(log[i], '> ')) {
            result.push(log[i]);
            i++;
        }
        return result;
    }

    function assertLines(expected:Array<String>, actual:Array<String>, what:String, ?pos:haxe.PosInfos):Void {
        assertEquals(expected.join(' | '), actual.join(' | '), what, pos);
    }

    static function frames(count:Int):Array<String> {
        final result = [];
        for (_ in 0...count) {
            for (line in FULL) result.push(line);
        }
        return result;
    }

/// Opening

    /**
     * GPUI draws four full frames when the harness opens the window: the
     * draw of `open_window`, the frame its effect flush draws (the
     * `RefreshWindows` effects of the key bindings and theme changes of the
     * kit's init are still pending: `HeadlessAppContext::update` does not
     * flush), the activation (`refresh`) and the harness's refresh + draw.
     */
    function testFramesOnOpen() {
        init();
        open();
        assertLines(frames(4), log, 'frames on open');
        assertEquals(4, window.drawCount, 'frames drawn on open');
    }

/// Focus changes

    /**
     * A click that moves the focus from one input to another draws the
     * frame of the mouse down (focus moved: refresh) and the one of the
     * mouse up, like GPUI. The blurred input's blink cursor hides and
     * notifies while the window draws (focus listeners): the cursor was
     * read by the last frame, so the notify reaches no observer, and the
     * input does not draw an extra frame of the blurred and focused fields.
     */
    function testFocusChangeDrawsNoExtraFrame() {
        init();
        open();
        final a:Entity<InputBaseState> = cast page.a;

        // Phase 1 of the scene: A focused, IME marked text, committed.
        click('A', 400., 134.);
        step('ime compose', (window, cx) -> a.update(cx, (s, cx) -> s.replaceAndMarkTextInRange(null, 'かな', new Range(2, 2), window, cx)));
        scrollPhase();
        step('ime commit', (window, cx) -> {
            a.update(cx, (s, cx) -> s.replaceTextInRange(null, '仮名', window, cx));
        });
        update((window, cx) -> a.update(cx, (s, cx) -> s.unmarkText(window, cx)));

        // Phase 2: B focused, keys move its caret (keyboard modality).
        click('B', 400., 162.);
        key('end');
        key('alt-shift-left');
        scrollPhase();

        // Phase 3: C focused (the mouse after the keyboard: refresh on move).
        click('C', 400., 200.);

        final focusFrames = ['  event', '  event'].concat(FULL).concat(['  event']).concat(FULL);
        assertLines(focusFrames, segment('> click A'), 'click on A');
        assertLines(focusFrames, segment('> click B'), 'click on B (focus moved from A)');
        assertLines(['  event'].concat(FULL).concat(['  event']).concat(FULL).concat(['  event']).concat(FULL), segment('> click C'), 'click on C (focus moved from B)');
        assertLines(FULL.concat(['P render', 'F2 render']), segment('> key end'), 'first key after the click on B (keyboard modality: refresh)');
    }

/// Notify while drawing

    /**
     * GPUI (`App::notify`, `WindowInvalidator::invalidate_view`): an entity
     * that the window accessed during its last draw, notified while the
     * window draws, pushes no `Notify` effect, so its observers are not
     * called; an entity no window accessed notifies its observers.
     */
    function testNotifyWhileDrawingReachesObserversOfEntitiesNotAccessed() {
        var renders = 0;
        var observedRead = 0;
        var observedOther = 0;
        var view:Null<NotifyView> = null;
        var viewEntity:Null<Entity<NotifyView>> = null;
        window = Window.open(app, {width: 100, height: 100, scaleFactor: 1, autoDraw: false, active: true, bindInput: false, viewCaching: false}, (window, cx) -> {
            viewEntity = cx.newEntity((c:Context<NotifyView>) -> view = new NotifyView(c, () -> renders++));
            return viewEntity;
        });
        final subscriptions:Array<Subscription> = [];
        app.update(cx -> {
            subscriptions.push(cx.observe(view.read, (_, cx) -> {
                observedRead++;
                viewEntity.update(cx, (_, cx) -> cx.notify());
            }));
            subscriptions.push(cx.observe(view.other, (_, _) -> observedOther++));
        });
        app.update(_ -> window.draw());
        assertTrue(window.drawCount > 0, 'drawn');
        final frames = window.drawCount;
        final rendered = renders;

        // The view's render notifies both models while the window draws.
        view.notifyWhileRendering = true;
        app.update(cx -> viewEntity.update(cx, (_, cx) -> cx.notify()));
        assertEquals(frames + 1, window.drawCount, 'the notify of the view drew one frame');
        assertEquals(rendered + 1, renders, 'the view rendered again once');
        assertEquals(0, observedRead, 'the model read by the last frame notified no observer');
        assertEquals(1, observedOther, 'the model the window never accessed notified its observer');
        assertFalse(window.dirty, 'no frame is pending');
        for (subscription in subscriptions) subscription.dispose();
    }

}

/** A model the views read. */
private class NotifyModel extends Model {

    public function new() {
        super();
    }

}

/** A view reading `read` while it renders, and notifying `read` and `other` from its render when asked. */
private class NotifyView extends Model implements Render {

    public final read:Entity<NotifyModel>;

    public final other:Entity<NotifyModel>;

    public var notifyWhileRendering:Bool = false;

    final onRender:() -> Void;

    public function new(cx:Context<NotifyView>, onRender:() -> Void) {
        super();
        this.onRender = onRender;
        read = cx.newEntity((_:Context<NotifyModel>) -> new NotifyModel());
        other = cx.newEntity((_:Context<NotifyModel>) -> new NotifyModel());
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        onRender();
        read.read(cx);
        if (notifyWhileRendering) {
            notifyWhileRendering = false;
            read.update(cx, (_, cx) -> cx.notify());
            other.update(cx, (_, cx) -> cx.notify());
        }
        return div().size(px(10));
    }

}

/** A cached field: one input, its renders logged. */
private class ScheduleField extends Model implements Render {

    final name:String;

    final log:Array<String>;

    final input:Null<Entity<InputState>>;

    final editor:Null<Entity<EditorState>>;

    public function new(name:String, log:Array<String>, input:Null<Entity<InputState>>, editor:Null<Entity<EditorState>>) {
        super();
        this.name = name;
        this.log = log;
        this.input = input;
        this.editor = editor;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        log.push('$name render');
        final field = div().sizeFull();
        return input != null ? field.child(Input.component(input)) : field.child(Editor.component(editor).hFull());
    }

}

/** The cached sidebar, its renders logged. */
private class ScheduleSidebar extends Model implements Render {

    final log:Array<String>;

    public function new(log:Array<String>) {
        super();
        this.log = log;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        log.push('S render');
        return div().sizeFull().bg(hsla(0.6, 0.3, 0.85, 1));
    }

}

/** The page of `kit-input-scroll-follow`, its renders logged (one per frame). */
private class SchedulePage extends Model implements Render {

    public final a:Entity<InputState>;

    public final b:Entity<InputState>;

    public final c:Entity<EditorState>;

    public final sidebar:Entity<ScheduleSidebar>;

    public final fields:Array<Entity<ScheduleField>>;

    public final scroll:ScrollHandle = new ScrollHandle();

    final log:Array<String>;

    public function new(window:Window, cx:Context<SchedulePage>, log:Array<String>) {
        super();
        this.log = log;
        a = cx.newEntity((ic:Context<InputState>) -> (new InputState(window, ic).defaultValue('Scroll follows') : InputState));
        b = cx.newEntity((ic:Context<InputState>) -> (new InputState(window, ic).defaultValue('Selected words stay') : InputState));
        c = cx.newEntity((ec:Context<EditorState>) -> (new EditorState(window, ec).defaultValue('let x = 1;\n') : EditorState));
        fields = [
            cx.newEntity((_:Context<ScheduleField>) -> new ScheduleField('F1', log, a, null)),
            cx.newEntity((_:Context<ScheduleField>) -> new ScheduleField('F2', log, b, null)),
            cx.newEntity((_:Context<ScheduleField>) -> new ScheduleField('F3', log, null, c)),
        ];
        sidebar = cx.newEntity((_:Context<ScheduleSidebar>) -> new ScheduleSidebar(log));
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        log.push('P render');
        final heights = [36., 36., 120.];
        final column = div().flex().flexCol().gap(px(16)).px(px(16)).child(div().h(px(100)));
        for (i => field in fields) {
            column.child(div().w(px(300)).h(px(heights[i])).child((field : AnyView).cached(StyleBuilder.build(s -> s.sizeFull()))));
        }
        column.child(div().h(px(600)));
        return div()
            .sizeFull()
            .flex()
            .flexRow()
            .child(div().w(px(120)).hFull().flexNone().child((sidebar : AnyView).cached(StyleBuilder.build(s -> s.sizeFull()))))
            .child(div().id('page').flex1().hFull().overflowYScroll().trackScroll(scroll).child(column));
    }

}
