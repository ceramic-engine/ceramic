package tests.kit;

import gpui.AnyView;
import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Keystroke;
import gpui.Model;
import gpui.Modifiers;
import gpui.Point;
import gpui.Range;
import gpui.Render;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.ScrollHandle;
import gpui.StyleBuilder;
import gpui.Task;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.Root;
import gpui.base.input.CompletionContext;
import gpui.base.input.CompletionItem;
import gpui.base.input.EditorState;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputState;
import gpui.base.input.LspHover;
import gpui.component.Component;
import gpui.component.input.Editor;
import gpui.component.input.Input;
import gpui.component.theme.Theme;
import gpui.component.theme.ThemeMode;
import gpui.scene.SceneDump;
import ropey.Rope;
import testing.TestCase;

import gpui.Prelude.*;

using gpui.base.input.InputLspExt;

/**
 * Deliberate deviation DEV-016 (see DEVIATIONS.md): gpui-kit's input element
 * no longer notifies its view from `paint` when the input only moved.
 *
 * Each test drives a page like the golden scene `kit-input-scroll-follow`
 * (`reference/src/kit_scenes13_input_scroll.rs`): a sidebar view S and a
 * scrolled column of field views (F1: Input A, F2: Input B, F3: Editor C
 * with a completion provider), every render of them counted, in a window
 * caching views (GPUI's `.cached(style)` alone, or the port's default view
 * caching) and in a reference window built the same way that renders every
 * view again after each step (`refresh`). Steps are applied to both pages in
 * one update; the app draws the dirty windows when its effects are flushed,
 * like the golden scenes. After every step both frames must be identical.
 */
@:access(gpui.base.input.InputBaseState)
class InputMoveNotifyTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    var pages:Array<MovePage> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            for (window in windows) {
                if (window.dirty && !window.isDestroyed()) window.draw();
            }
        };
        app.update(cx -> {
            Component.init(cx);
            cx.setReduceMotion(true);
            Theme.change(ThemeMode.Light, null, cx);
            Theme.setScrollbarMode(Always, cx);
            // The port's text system only has Inter and JetBrains Mono.
            Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            Theme.syncBase(cx);
        });
    }

    override function teardown() {
        for (window in windows) {
            window.destroy();
        }
        windows.resize(0);
        pages = [];
        ceramic.App.app.flushImmediate();
    }

/// Fixture

    /**
     * Opens the page in a window. `explicit`: the fields and the sidebar are
     * embedded with `.cached(style)` (GPUI), otherwise as plain views.
     * The window caches views (`.cached(style)` and, without `explicit`,
     * the port's default caching). `reference`: it also renders every view
     * again after each step.
     */
    function open(explicit:Bool, reference:Bool):MovePage {
        var page:Null<MovePage> = null;
        final window = Window.open(app, {width: 512, height: 512, scaleFactor: 2, autoDraw: false, active: false, bindInput: false, viewCaching: !explicit}, (window, cx) -> {
            final entity = cx.newEntity((c:Context<MovePage>) -> page = new MovePage(window, c, explicit));
            page.entity = entity;
            return cx.newEntity((rootCx:Context<Root>) -> new Root(entity, window, rootCx));
        });
        windows.push(window);
        page.window = window;
        page.reference = reference;
        window.draw();
        app.update(_ -> window.setActive(true));
        dispatcher.runUntilParked();
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
        pages.push(page);
        return page;
    }

    /** The caching page and its reference, `explicit` like `open`. */
    function openPair(explicit:Bool):MovePage {
        final page = open(explicit, false);
        open(explicit, true);
        return page;
    }

    /** One step on every page, in one update, then run until parked (the app draws the dirty windows). */
    function each(fn:(MovePage, App) -> Void):Void {
        app.update(cx -> {
            for (page in pages) fn(page, cx);
        });
        dispatcher.runUntilParked();
        for (page in pages) {
            if (page.reference) {
                app.update(_ -> {
                    page.window.refresh();
                    page.window.draw();
                });
                dispatcher.runUntilParked();
            }
        }
    }

    function scroll(dy:Float):Void {
        each((page, cx) -> page.window.dispatchEvent(new ScrollEvent(new Point(490, 300), ScrollDelta.Pixels(new Point(0, dy)), Modifiers.none()), cx));
    }

    function notifySidebar():Void {
        each((page, cx) -> page.sidebar.update(cx, (_, cx) -> cx.notify()));
    }

    function key(ks:String):Void {
        each((page, cx) -> page.window.dispatchKeystroke(Keystroke.parse(ks), cx));
    }

    function typeText(text:String):Void {
        for (ch in new haxe.iterators.StringIteratorUnicode(text)) {
            final buf = new StringBuf();
            buf.addChar(ch);
            final key = ch == ' '.code ? 'space' : buf.toString();
            each((page, cx) -> page.window.dispatchKeystroke(new Keystroke(Modifiers.none(), key, null), cx));
        }
    }

    function focus(state:MovePage->Entity<InputBaseState>):Void {
        each((page, cx) -> state(page).update(cx, (s, cx) -> s.focus(page.window, cx)));
    }

    static function dump(window:Window):String {
        return SceneDump.toJson(window.renderedScene(), 1024, 1024);
    }

    /** The frame of the caching window equals the frame of its reference. */
    function assertSameFrames(step:String, ?pos:haxe.PosInfos):Void {
        assertTrue(dump(windows[0]) == dump(windows[1]), '$step: same frame as when every view renders again', pos);
    }

    static function ys(bounds:Null<Bounds>):Float {
        return bounds != null ? bounds.origin.y : Math.NaN;
    }

/// Renders

    /**
     * GPUI's view cache: after a scroll, a frame caused by the sidebar alone
     * reuses the cached fields. The original input notified from the paint
     * of the scroll, so the fields rendered again.
     */
    function testMovedInputsDoNotDirtyTheirCachedViews() {
        final page = openPair(true);
        focus(p -> cast p.a);
        for (dy in [-24., -24., 24.]) {
            scroll(dy);
            assertSameFrames('scroll $dy');
            final before = page.renders();
            final sidebar = page.sidebarRenders;
            notifySidebar();
            assertSameFrames('notify S');
            assertEquals(sidebar + 1, page.sidebarRenders, 'the sidebar rendered');
            assertEquals(before, page.renders(), 'after a scroll of $dy, a frame of the sidebar alone renders no field');
        }
    }

    /**
     * The port's default view caching (the gallery): the input views moved
     * by a scroll are clean, so the frame of the sidebar alone reuses them
     * and their fields.
     */
    function testMovedInputsStayCleanWithDefaultViewCaching() {
        final page = openPair(false);
        focus(p -> cast p.a);
        for (dy in [-24., -24., 24.]) {
            scroll(dy);
            assertSameFrames('scroll $dy');
            final before = page.renders();
            notifySidebar();
            assertSameFrames('notify S');
            assertEquals(before, page.renders(), 'after a scroll of $dy, a frame of the sidebar alone renders no field');
        }
    }

    /** A resized input still notifies: the next frame renders its field again. */
    function testResizedInputsStillNotify() {
        final page = openPair(true);
        each((p, cx) -> {
            p.fieldWidth = 280;
            p.notifyPage(cx);
        });
        assertSameFrames('resize');
        final before = page.renders();
        notifySidebar();
        assertSameFrames('notify S');
        assertEquals(before + 3, page.renders(), 'the three resized inputs notified from their paint');
    }

    /**
     * A shown hover popover lays out from the editor's last painted
     * position (in the frame of the scroll, it is still where the editor
     * was), so the editor keeps notifying when it moved: the next frame,
     * here caused by the sidebar alone, renders its field again and puts
     * the popover at the moved editor.
     */
    function testMovedEditorWithHoverPopoverStillNotifies() {
        final page = openPair(true);
        each((p, cx) -> {
            final c:Entity<InputBaseState> = cast p.c;
            c.update(cx, (s, cx) -> s.presentHover(new Range(4, 5), new LspHover('**x**: a symbol'), cx));
        });
        // The frame of the scroll itself lays the popover out from the
        // position of the previous paint, as in gpui-kit: not compared.
        scroll(-24);
        final f1 = page.fieldRenders[0], f2 = page.fieldRenders[1], f3 = page.fieldRenders[2];
        notifySidebar();
        assertSameFrames('notify S');
        assertEquals(f1, page.fieldRenders[0], 'Input A moved without notifying');
        assertEquals(f2, page.fieldRenders[1], 'Input B moved without notifying');
        assertEquals(f3 + 1, page.fieldRenders[2], 'the editor showing a hover popover notified');
    }

/// What is anchored to the fields

    /**
     * The caret and the IME bounds of A, the selection of B and the
     * completion menu of C move with their field by the scrolled amount,
     * and every frame equals the reference frame.
     */
    function testCaretSelectionCompletionAndImeFollowTheField() {
        final page = openPair(true);
        final a:Entity<InputBaseState> = cast page.a;
        final b:Entity<InputBaseState> = cast page.b;
        final c:Entity<InputBaseState> = cast page.c;

        // A: caret and IME marked text
        focus(p -> cast p.a);
        each((p, cx) -> {
            final pa:Entity<InputBaseState> = cast p.a;
            pa.update(cx, (s, cx) -> s.replaceAndMarkTextInRange(null, 'かな', new Range(2, 2), p.window, cx));
        });
        assertSameFrames('ime compose');
        var caret = ys(a.read(app).cursorLayout().bounds);
        var ime = ys(page.ime());
        var field = a.read(app).inputBounds.origin.y;
        for (dy in [-24., -24., 24.]) {
            scroll(dy);
            assertSameFrames('A: scroll $dy');
            final s = a.read(app);
            assertFloatEquals(field + dy, s.inputBounds.origin.y, 0.01, 'A moved by $dy');
            assertFloatEquals(caret + dy, ys(s.cursorLayout().bounds), 0.01, 'the caret of A follows');
            assertFloatEquals(ime + dy, ys(page.ime()), 0.01, 'the IME bounds of A follow');
            field += dy;
            caret += dy;
            ime += dy;
            notifySidebar();
            assertSameFrames('A: notify S');
        }

        // B: selection of its last word
        focus(p -> cast p.b);
        key('end');
        key('alt-shift-left');
        assertFalse(b.read(app).selectedRange().isEmpty(), 'B has a selection');
        var sel = ys(b.read(app).rangeToBounds(b.read(app).selectedRange()));
        for (dy in [-24., -24., 24.]) {
            scroll(dy);
            assertSameFrames('B: scroll $dy');
            final s = b.read(app);
            assertFloatEquals(sel + dy, ys(s.rangeToBounds(s.selectedRange())), 0.01, 'the selection of B follows');
            sel += dy;
            notifySidebar();
            assertSameFrames('B: notify S');
        }

        // C: completion menu
        focus(p -> cast p.c);
        key('cmd-up');
        key('end');
        typeText(' fo');
        assertTrue(c.read(app).completionMenuState().open, 'the completion menu of C is open');
        var popup = page.popupY();
        var menu = page.menuTop();
        assertTrue(Math.isFinite(menu), 'the completion menu is drawn');
        for (dy in [-24., -24., 24.]) {
            scroll(dy);
            assertSameFrames('C: scroll $dy');
            assertFloatEquals(popup + dy, page.popupY(), 0.01, 'the completion popup origin follows');
            assertFloatEquals(menu + dy * 2, page.menuTop(), 0.01, 'the drawn completion menu follows');
            popup += dy;
            menu += dy * 2;
            notifySidebar();
            assertSameFrames('C: notify S');
            assertFloatEquals(menu, page.menuTop(), 0.01, 'the completion menu stays at the field');
        }
    }

}

/** A field: one input, its renders counted. */
private class MoveField extends Model implements Render {

    final page:MovePage;

    final index:Int;

    final input:Null<Entity<InputState>>;

    final editor:Null<Entity<EditorState>>;

    public function new(page:MovePage, index:Int, input:Null<Entity<InputState>>, editor:Null<Entity<EditorState>>) {
        super();
        this.page = page;
        this.index = index;
        this.input = input;
        this.editor = editor;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        page.fieldRenders[index]++;
        final field = div().sizeFull();
        return input != null ? field.child(new Input(input)) : field.child(new Editor(editor).hFull());
    }

}

/** The sidebar, its renders counted. */
private class MoveSidebar extends Model implements Render {

    final page:MovePage;

    public function new(page:MovePage) {
        super();
        this.page = page;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        page.sidebarRenders++;
        return div().sizeFull().bg(hsla(0.6, 0.3, 0.85, 1));
    }

}

/**
 * The page of `kit-input-scroll-follow`: sidebar (0, 0) 120 x 512, then the
 * scrolled column (120, 0) 392 x 512: top space 100, the fields (300 wide;
 * 36, 36 and 120 high), bottom space 600, at x 16 with a gap of 16.
 */
private class MovePage extends Model implements Render {

    public var window:Window;

    public final explicit:Bool;

    public var reference:Bool = false;

    public final sidebar:Entity<MoveSidebar>;

    public final fields:Array<Entity<MoveField>>;

    public final scroll:ScrollHandle = new ScrollHandle();

    public final a:Entity<InputState>;

    public final b:Entity<InputState>;

    public final c:Entity<EditorState>;

    public final fieldRenders:Array<Int> = [0, 0, 0];

    public var sidebarRenders:Int = 0;

    public var fieldWidth:Float = 300;

    public var entity:Null<Entity<MovePage>> = null;

    public function new(window:Window, cx:Context<MovePage>, explicit:Bool) {
        super();
        this.window = window;
        this.explicit = explicit;
        a = cx.newEntity((ic:Context<InputState>) -> (new InputState(window, ic).defaultValue('Scroll follows') : InputState));
        b = cx.newEntity((ic:Context<InputState>) -> (new InputState(window, ic).defaultValue('Selected words stay') : InputState));
        c = cx.newEntity((ec:Context<EditorState>) -> (new EditorState(window, ec).defaultValue('let x = 1;\n') : EditorState));
        c.update(cx, (state, _) -> state.lsp().completionProvider = new MoveWords());
        fields = [
            cx.newEntity((_:Context<MoveField>) -> new MoveField(this, 0, a, null)),
            cx.newEntity((_:Context<MoveField>) -> new MoveField(this, 1, b, null)),
            cx.newEntity((_:Context<MoveField>) -> new MoveField(this, 2, null, c)),
        ];
        sidebar = cx.newEntity((_:Context<MoveSidebar>) -> new MoveSidebar(this));
    }

    public function renders():Int {
        return fieldRenders[0] + fieldRenders[1] + fieldRenders[2];
    }

    public function notifyPage(cx:App):Void {
        entity.update(cx, (_, cx) -> cx.notify());
    }

    /** The IME bounds of A's marked range, as the platform asks them. */
    public function ime():Null<Bounds> {
        var result:Null<Bounds> = null;
        final state:Entity<InputBaseState> = cast a;
        window.app.update(cx -> state.update(cx, (s, cx) -> {
            final marked = s.markedTextRange(window, cx);
            final textBounds = s.textBounds();
            result = marked != null && textBounds != null ? s.boundsForRange(marked, textBounds, window, cx) : null;
        }));
        return result;
    }

    /** The origin y of C's completion popup (`caret_popup_anchor`). */
    public function popupY():Float {
        final s:InputBaseState = cast c.read(window.app);
        final g = s.prepaintCaretGeometry;
        return g.cursorBounds().origin.y + g.scrollOffset().y + (g.lineHeight() : Float) + 4;
    }

    /** Top of the completion menu as drawn (the element of its shadow, the tallest one), in device pixels. */
    public function menuTop():Float {
        final scene = window.renderedScene();
        var top = Math.POSITIVE_INFINITY;
        var height = 0.;
        for (shadow in scene.shadows) {
            if (shadow.elementBoundsHeight > height) {
                height = shadow.elementBoundsHeight;
                top = shadow.elementBoundsY;
            }
        }
        return top;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        final heights = [36., 36., 120.];
        final column = div().flex().flexCol().gap(px(16)).px(px(16)).child(div().h(px(100)));
        for (i => field in fields) {
            final h = heights[i];
            final w = fieldWidth;
            column.child(explicit
                ? (field : AnyView).cached(StyleBuilder.build(s -> s.w(px(w)).h(px(h))))
                : div().w(px(w)).h(px(h)).flexNone().child((field : AnyView)));
        }
        column.child(div().h(px(600)));
        final sidebarElement:IntoElement = explicit ? (sidebar : AnyView).cached(StyleBuilder.build(s -> s.sizeFull())) : (sidebar : AnyView);
        return div()
            .sizeFull()
            .flex()
            .flexRow()
            .child(div().w(px(120)).hFull().flexNone().child(sidebarElement))
            .child(div().id('page').flex1().hFull().overflowYScroll().trackScroll(scroll).child(column));
    }

}

/** Completion words for C. */
private class MoveWords extends gpui.base.input.CompletionProvider.CompletionProviderBase {

    static final WORDS:Array<Array<String>> = [["format", "fn"], ["for_each", "method"], ["fold", "method"]];

    public function new() {}

    static function isWordChar(c:Int):Bool {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code;
    }

    public function completions(text:Rope, offset:Int, _:CompletionContext, _:Window, _:App):Task<Array<CompletionItem>> {
        final before = text.slice(0, offset).toString();
        var start = before.length;
        while (start > 0 && isWordChar(StringTools.fastCodeAt(before, start - 1)))
            start--;
        final word = before.substr(start);
        final items = [for (w in WORDS) if (StringTools.startsWith(w[0], word)) new CompletionItem(w[0], null, w[1])];
        return Task.ready(items);
    }

    public function isCompletionTrigger(_:Int, newText:String, _:App):Bool {
        if (newText.length == 0)
            return false;
        for (i in 0...newText.length) {
            if (!isWordChar(StringTools.fastCodeAt(newText, i)))
                return false;
        }
        return true;
    }

}
