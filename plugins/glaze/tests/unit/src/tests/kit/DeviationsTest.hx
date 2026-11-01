package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.component.Component;
import gpui.component.IconName;
import gpui.component.badge.Badge;
import gpui.component.button.Button;
import gpui.Entity;
import gpui.ListSizingBehavior;
import gpui.Size;
import gpui.base.VirtualList;
import gpui.component.theme.Theme;
import gpui.scene.Quad;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputEvent;
import gpui.base.input.InputKeyBindings;
import gpui.base.input.InputState;
import gpui.component.I18n;
import gpui.component.accordion.Accordion;
import gpui.component.combobox.Combobox;
import gpui.component.combobox.ComboboxState;
import gpui.component.input.NumberInput;
import gpui.component.searchablelist.SearchableVec;
import gpui.Bounds;
import gpui.Point;
import gpui.base.Calendar.CalendarDate;
import gpui.base.Calendar.CalendarState;
import gpui.base.chrono.Local;
import gpui.base.chrono.NaiveDate;
import gpui.base.chrono.NaiveDateTime;
import gpui.base.chrono.NaiveTime;
import gpui.component.Icon;
import gpui.component.colorpicker.ColorPicker;
import gpui.component.select.Select;
import gpui.component.select.SelectState;
import gpui.component.tab.Tab;
import gpui.component.tab.TabBar;
import gpui.component.tab.TabVariant;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

/**
 * Keeps the deliberate deviations of DEVIATIONS.md in place on the port, so a
 * later change cannot silently bring a fixed defect back. The pixel level
 * checks (defect metric on the captures, scene equal to the original outside
 * the declared primitives) are in `reference/verify-deviations.js port`.
 */
class DeviationsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    /**
     * DEV-001: the icon badge ring is the padding of a disc in the background
     * color around the colored disc. No quad of the badge has a border (a
     * border quad over the disc is what let the badge color leak around the
     * ring), and the badge keeps the original size and place.
     */
    function testDev001IconBadgeRingIsNotABorderQuad() {
        final opened = VisualTestContext.addWindowView(app, dispatcher,
            (_, _:Context<Host>) -> new Host(() -> div().p(px(8.)).child(new Badge().icon(IconName.Check).child(div().size(px(32.))))), 64, 64);
        cx = opened.cx;
        cx.update((window, _) -> window.draw());
        final scale = cx.window.scaleFactor();
        final theme = Theme.global(app);
        final quads:Array<Quad> = @:privateAccess cx.window.renderedFrame.scene.quads;
        final isColor = (q:Quad, c:gpui.Hsla) -> Math.abs(q.backgroundSolidH - c.h) < 1e-4 && Math.abs(q.backgroundSolidS - c.s) < 1e-4
            && Math.abs(q.backgroundSolidL - c.l) < 1e-4 && q.backgroundSolidA == c.a;
        final ring = quads.filter(q -> isColor(q, theme.background) && q.boundsWidth == 16 * scale);
        final disc = quads.filter(q -> isColor(q, theme.red) && q.backgroundSolidA > 0);
        assertEquals(1, ring.length);
        assertEquals(1, disc.length);
        // Same place and size as the original badge: 16px, at the bottom right
        // of the badge element (as wide as the padded window, as tall as its child)
        assertFloatEquals((64 - 8 - 16) * scale, ring[0].boundsX, 1e-4);
        assertFloatEquals((8 + 32 - 16) * scale, ring[0].boundsY, 1e-4);
        assertFloatEquals(8 * scale, ring[0].cornerRadiusTopLeft, 1e-4);
        // The colored disc is inset by the 1px ring, fully rounded
        assertFloatEquals(ring[0].boundsX + scale, disc[0].boundsX, 1e-4);
        assertFloatEquals(ring[0].boundsY + scale, disc[0].boundsY, 1e-4);
        assertFloatEquals(14 * scale, disc[0].boundsWidth, 1e-4);
        assertFloatEquals(7 * scale, disc[0].cornerRadiusTopLeft, 1e-4);
        assertTrue(disc[0].order > ring[0].order);
        for (q in quads) {
            assertEquals(0., q.borderWidthTop + q.borderWidthRight + q.borderWidthBottom + q.borderWidthLeft);
        }
    }

    function drawQuads(build:() -> IntoElement, width:Float = 160, height:Float = 120):Array<Quad> {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<Host>) -> new Host(build), width, height);
        cx = opened.cx;
        cx.update((window, _) -> window.draw());
        return @:privateAccess cx.window.renderedFrame.scene.quads;
    }

    static function hasBorder(q:Quad):Bool {
        return q.borderWidthTop + q.borderWidthRight + q.borderWidthBottom + q.borderWidthLeft > 0;
    }

    /**
     * DEV-002: the background of a rounded element with an opaque solid border
     * of one width is inset by half the border width (whole device pixels),
     * with its radii reduced by the same amount; the border quad keeps the
     * element bounds. Translucent and dashed borders keep the original bounds.
     */
    function testDev002BackgroundStopsUnderOpaqueBorder() {
        final quads = drawQuads(() -> div().p(px(8.))
            .child(div().size(px(40.)).rounded(px(8.)).bg(hsla(0., 0., 1., 1.)).border2().borderColor(hsla(0.3, 0.6, 0.4, 1.))));
        final scale = cx.window.scaleFactor();
        final border = quads.filter(q -> hasBorder(q));
        final bg = quads.filter(q -> !hasBorder(q) && q.backgroundSolidL == 1.0);
        assertTrue(border.length > 0);
        assertEquals(1, bg.length);
        final inset = Math.ffloor(2 * scale / 2);
        assertFloatEquals(8 * scale, border[0].boundsX, 1e-4);
        assertFloatEquals(border[0].boundsX + inset, bg[0].boundsX, 1e-4);
        assertFloatEquals(border[0].boundsY + inset, bg[0].boundsY, 1e-4);
        assertFloatEquals(border[0].boundsWidth - 2 * inset, bg[0].boundsWidth, 1e-4);
        assertFloatEquals(8 * scale - inset, bg[0].cornerRadiusTopLeft, 1e-4);
        assertFloatEquals(8 * scale, border[0].cornerRadiusTopLeft, 1e-4);
        cx.destroy();
        cx = null;
        final builds:Array<() -> IntoElement> = [
            () -> div().p(px(8.)).child(div().size(px(40.)).rounded(px(8.)).bg(hsla(0., 0., 1., 1.)).border2().borderColor(hsla(0.3, 0.6, 0.4, 0.5))),
            () -> div().p(px(8.)).child(div().size(px(40.)).rounded(px(8.)).bg(hsla(0., 0., 1., 1.)).border2().borderDashed().borderColor(hsla(0.3, 0.6, 0.4, 1.))),
            () -> div().p(px(8.)).child(div().size(px(40.)).bg(hsla(0., 0., 1., 1.)).border2().borderColor(hsla(0.3, 0.6, 0.4, 1.)))
        ];
        for (build in builds) {
            final quads = drawQuads(build);
            final bg = quads.filter(q -> !hasBorder(q) && q.backgroundSolidL == 1.0);
            assertEquals(1, bg.length);
            assertFloatEquals(8 * scale, bg[0].boundsX, 1e-4);
            assertFloatEquals(40 * scale, bg[0].boundsWidth, 1e-4);
            cx.destroy();
            cx = null;
        }
    }

    /**
     * DEV-003: an icon button with a dropdown caret is sized like a normal
     * button (wider than high); without the caret it stays a square.
     */
    function testDev003IconButtonWithCaretIsNotSquare() {
        var quads = drawQuads(() -> div().p(px(8.)).child(new Button('caret').outline().small().icon(IconName.Ellipsis).dropdownCaret(true)));
        var border = quads.filter(q -> hasBorder(q));
        assertTrue(border.length > 0);
        assertTrue(border[0].boundsWidth > border[0].boundsHeight);
        cx.destroy();
        cx = null;
        quads = drawQuads(() -> div().p(px(8.)).child(new Button('square').outline().small().icon(IconName.Ellipsis)));
        border = quads.filter(q -> hasBorder(q));
        assertTrue(border.length > 0);
        assertFloatEquals(border[0].boundsHeight, border[0].boundsWidth, 1e-4);
    }

    /**
     * DEV-005: a disabled solid Secondary button fades its background to half
     * the enabled opacity (the original `opacity(1.5)` kept it unchanged).
     */
    function testDev005DisabledSecondaryFades() {
        final alphaOf = (disabled:Bool) -> {
            final quads = drawQuads(() -> div().p(px(8.)).child(new Button('secondary').secondary().label('Secondary').disabled(disabled)));
            final fills = quads.filter(q -> !hasBorder(q) && q.backgroundSolidA > 0 && q.boundsX > 0);
            assertEquals(1, fills.length);
            final alpha = fills[0].backgroundSolidA;
            cx.destroy();
            cx = null;
            return alpha;
        };
        final enabled = alphaOf(false);
        final disabled = alphaOf(true);
        assertTrue(enabled > 0);
        assertFloatEquals(enabled * 0.5, disabled, 1e-4);
    }

    /**
     * DEV-004: a horizontal virtual list with `Infer` sizing, a known width
     * and no height takes the available height (the 100px row), not its width.
     */
    function testDev004InferHorizontalListTakesTheKnownHeight() {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<InferHost>) -> new InferHost(), 400, 300);
        cx = opened.cx;
        cx.update((window, _) -> window.draw());
        final scale = cx.window.scaleFactor();
        final quads:Array<Quad> = @:privateAccess cx.window.renderedFrame.scene.quads;
        final list = quads.filter(q -> q.boundsWidth == 300 * scale);
        assertEquals(1, list.length);
        assertFloatEquals(100 * scale, list[0].boundsHeight, 1e-4);
    }

    /**
     * DEV-006: a Combobox without a placeholder shows the localized default
     * ("Please select", key `ComboBox.placeholder`), not the raw key: its
     * trigger draws the same glyphs as one given that text explicitly.
     */
    function testDev006ComboboxDefaultPlaceholderIsTranslated() {
        assertEquals("Please select", I18n.t("ComboBox.placeholder"));
        final glyphs = (explicit:Bool) -> {
            final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<Host>) -> {
                final state = cx.app.newEntity((c:Context<ComboboxState<String>>) -> new ComboboxState(new SearchableVec(["Rust", "Go"]), [], window, c));
                return new Host(() -> {
                    final combobox = new Combobox(state).w(px(200.));
                    if (explicit) combobox.placeholder("Please select");
                    return div().p(px(8.)).child(combobox);
                });
            }, 240, 80);
            cx = opened.cx;
            cx.update((window, _) -> window.draw());
            final sprites = @:privateAccess cx.window.renderedFrame.scene.monochromeSprites;
            final out = [for (s in sprites) [s.boundsX, s.boundsY, s.boundsWidth, s.boundsHeight].join(',')].join(' ');
            cx.destroy();
            cx = null;
            return out;
        };
        final byDefault = glyphs(false);
        assertTrue(byDefault.length > 0);
        assertEquals(glyphs(true), byDefault);
    }

    /**
     * DEV-007: the placeholder of a NumberInput reaches its input state (the
     * original stored it and never used it). Without one, the state keeps
     * its own.
     */
    function testDev007NumberInputPlaceholderIsUsed() {
        var withPlaceholder:Null<Entity<InputState>> = null;
        var without:Null<Entity<InputState>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<Host>) -> {
            final a = cx.app.newEntity((c:Context<InputState>) -> new InputState(window, c));
            final b = cx.app.newEntity((c:Context<InputState>) -> {
                final state = new InputState(window, c);
                state.placeholder = "Own";
                return state;
            });
            withPlaceholder = a;
            without = b;
            return new Host(() -> div().p(px(8.)).flex().flexCol().gap2()
                .child(new NumberInput(a).placeholder("Quantity"))
                .child(new NumberInput(b)));
        }, 240, 120);
        cx = opened.cx;
        cx.update((window, _) -> window.draw());
        assertEquals("Quantity", withPlaceholder.read(app).presentation().placeholder());
        assertEquals("Own", without.read(app).presentation().placeholder());
    }

    /**
     * DEV-008: `onToggleClick` of an Accordion is reported by the item that
     * toggled: a click on the content or on a disabled item reports nothing
     * (the original reported the unchanged list for any click inside).
     */
    function testDev008AccordionReportsOnlyToggles() {
        app.setReduceMotion(true);
        final reports:Array<String> = [];
        final state = {open: [0]};
        var view:Null<Entity<ScriptView>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> new Accordion('dev008')
            .w(px(240.))
            .item(item -> item.title(new tests.kit.DebugProbe('dev008-general', 'General'))
                .open(state.open.indexOf(0) != -1)
                .child(new tests.kit.DebugProbe('dev008-content', div().h(px(40.)).child('General options'))))
            .item(item -> item.title(new tests.kit.DebugProbe('dev008-locked', 'Locked')).disabled(true))
            .onToggleClick((open, _, cx) -> {
                final sorted = open.copy();
                sorted.sort((a, b) -> a - b);
                reports.push('[' + sorted.join(',') + ']');
                state.open = sorted;
                view.update(cx, (_, cx) -> cx.notify());
            })), 320, 240);
        cx = opened.cx;
        view = opened.view;
        final click = (selector:String) -> {
            tests.kit.DebugProbe.clear();
            cx.update((window, _) -> window.draw());
            cx.simulateClick(tests.kit.DebugProbe.bounds(selector).center());
        };
        click('dev008-content');
        click('dev008-locked');
        assertEquals('', reports.join(' '));
        click('dev008-general');
        assertEquals('[]', reports.join(' '));
        click('dev008-general');
        assertEquals('[] [0]', reports.join(' '));
        tests.kit.DebugProbe.clear();
    }

    /**
     * DEV-009: `InputEvent.Change` is emitted only when the value changed:
     * not for a newline dropped by a single-line input, nor for a character
     * rejected by the mask.
     */
    function testDev009NoChangeEventWithoutAChange() {
        var input:Null<Entity<InputBaseState>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ScriptView>) -> {
            InputKeyBindings.init(cx.app);
            input = cx.app.newEntity((c:Context<InputBaseState>) -> (new InputState(window, c).withMaskPattern("(999)-999") : InputBaseState));
            final child = input;
            return new ScriptView((_, _) -> div().sizeFull().child(child));
        }, 240, 80);
        cx = opened.cx;
        var changes = 0;
        final subscription = app.update(cx -> cx.subscribe(input, InputEvent, (_, event, _) -> {
            if (event == InputEvent.Change) changes++;
        }));
        final type = (text:String) -> cx.update((window, app) -> input.update(app, (state, cx) -> state.replaceTextInRange(null, text, window, cx)));
        type("5");
        assertEquals("(5", input.read(app).value());
        assertEquals(1, changes);
        type("a");
        assertEquals("(5", input.read(app).value());
        assertEquals(1, changes);
        type("\n");
        assertEquals("(5", input.read(app).value());
        assertEquals(1, changes);
        type("5");
        assertEquals(2, changes);
        subscription.dispose();
    }

    /**
     * DEV-010: a Select or a Combobox with a width of its own sizes and
     * places its menu from the trigger (border box), not from the wrapper
     * around it, which spans the parent.
     */
    function testDev010MenuIsMeasuredFromTheTrigger() {
        var select:Null<Entity<SelectState<String>>> = null;
        var combobox:Null<Entity<ComboboxState<String>>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<Host>) -> {
            select = cx.app.newEntity((c:Context<SelectState<String>>) -> new SelectState(new SearchableVec(["Rust", "Go"]), null, window, c));
            combobox = cx.app.newEntity((c:Context<ComboboxState<String>>) -> new ComboboxState(new SearchableVec(["Rust", "Go"]), [], window, c));
            final s = select;
            final c = combobox;
            return new Host(() -> div().p(px(8.)).w(px(488.)).flex().flexCol().gap2()
                .child(new tests.kit.DebugProbe('dev010-select', new Select(s).w(px(160.))))
                .child(new tests.kit.DebugProbe('dev010-combobox', new Combobox(c).w(px(160.)))));
        }, 520, 160);
        cx = opened.cx;
        cx.update((window, _) -> window.draw());
        cx.update((window, _) -> window.draw());
        final selectBounds:Bounds = @:privateAccess select.read(app).state.bounds;
        final comboboxBounds:Bounds = @:privateAccess combobox.read(app).state.bounds;
        for (b in [selectBounds, comboboxBounds]) {
            assertFloatEquals(160., b.size.width, 1e-3);
            assertFloatEquals(8., b.origin.x, 1e-3);
        }
        // The trigger is the first element of the wrapper, at the top of the
        // control (whose root is `size_full`, so taller), and both triggers
        // have the input height.
        final probe = tests.kit.DebugProbe.bounds('dev010-select');
        assertFloatEquals(probe.origin.y, selectBounds.origin.y, 1e-3);
        assertFloatEquals(selectBounds.size.height, comboboxBounds.size.height, 1e-3);
        assertTrue(selectBounds.size.height < 40.);
        tests.kit.DebugProbe.clear();
    }

    /**
     * DEV-011: the ColorPicker trigger and tooltip show the hex rounded like
     * the hex field; the theme's `toHex` keeps truncating.
     */
    function testDev011TriggerHexIsRounded() {
        final teal = hsla(0.5, 0.6, 0.4, 1.);
        assertEquals("#28A3A3", gpui.component.theme.Colorize.toHex(teal));
        assertEquals("#29A3A3", @:privateAccess ColorPicker.displayHex(teal));
        assertEquals(@:privateAccess gpui.base.ColorPicker.ColorPickerState.hexString(teal), @:privateAccess ColorPicker.displayHex(teal));
        final translucent = hsla(0.9, 0.7, 0.6, 0.5);
        assertEquals(@:privateAccess gpui.base.ColorPicker.ColorPickerState.hexString(translucent), @:privateAccess ColorPicker.displayHex(translucent));
    }

    /**
     * DEV-012: the year page of the Calendar follows the current year when
     * the date, the month (across a year) or the year changes.
     */
    function testDev012YearPageFollowsTheDate() {
        Local.fixAt(NaiveDateTime.of(NaiveDate.fromYmd(2026, 10, 30), NaiveTime.fromHms(12, 0, 0)));
        try {
            var state:Null<Entity<CalendarState>> = null;
            final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<Host>) -> {
                state = cx.app.newEntity((c:Context<CalendarState>) -> new CalendarState(window, c).yearRange(2000, 2026));
                return new Host(() -> div());
            }, 200, 100);
            cx = opened.cx;
            final firstYear = () -> state.read(app).yearsOnPage()[0];
            // The wall clock year (2026) is outside the range: page 0.
            assertEquals(2000, firstYear());
            state.update(app, (s, _) -> s.applyDate(CalendarDate.Single(NaiveDate.fromYmd(2025, 3, 14))));
            assertEquals(2020, firstYear());
            state.update(app, (s, _) -> s.applyDate(CalendarDate.Single(NaiveDate.fromYmd(2019, 12, 10))));
            assertEquals(2000, firstYear());
            state.update(app, (s, _) -> s.nextMonth());
            assertEquals(2020, firstYear());
            state.update(app, (s, _) -> s.prevMonth());
            assertEquals(2000, firstYear());
            state.update(app, (s, _) -> s.selectYear(2024));
            assertEquals(2020, firstYear());
        } catch (e:Dynamic) {
            Local.setClock(null);
            throw e;
        }
        Local.setClock(null);
    }

    /**
     * DEV-013: an icon-only tab keeps its intended width (1.25 times the
     * inner height: 30 for a Segmented tab), instead of shrinking to the icon.
     */
    function testDev013IconOnlyTabKeepsItsWidth() {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new Host(() -> hFlex().child(
            new tests.kit.DebugProbe('dev013-tab', new Tab().withVariant(Segmented).icon(new Icon(IconName.BookOpen))))), 200, 80);
        cx = opened.cx;
        cx.update((window, _) -> window.draw());
        final tab = tests.kit.DebugProbe.bounds('dev013-tab');
        assertNotNull(tab);
        assertTrue(tab.size.width >= 30., 'icon-only tab ${tab.size.width} wide');
        tests.kit.DebugProbe.clear();
    }

    /**
     * DEV-014: no sliding indicator under a disabled selected tab (Pill and
     * Underline paint their indicator in the primary color); an enabled
     * selected tab keeps it.
     */
    function testDev014NoIndicatorUnderADisabledSelectedTab() {
        final primaryQuads = (variant:TabVariant, disabled:Bool) -> {
            final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new Host(() -> new TabBar('dev014')
                .withVariant(variant)
                .selectedIndex(1)
                .child(new Tab().label('One'))
                .child(new Tab().label('Two').disabled(disabled))), 320, 80);
            final c = opened.cx;
            c.runUntilParked();
            c.update((window, _) -> window.draw());
            c.advanceClock(0.016);
            c.update((window, app) -> window.simulateNextFrame(app));
            c.runUntilParked();
            c.update((window, _) -> window.draw());
            final count = c.update((window, app) -> {
                final primary = Theme.global(app).primary;
                var n = 0;
                for (quad in window.renderedScene().quads) {
                    if (quad.backgroundTag != 0) continue;
                    if (quad.backgroundSolidH == primary.h && quad.backgroundSolidS == primary.s && quad.backgroundSolidL == primary.l && quad.backgroundSolidA == primary.a) n++;
                }
                return n;
            });
            c.destroy();
            return count;
        };
        for (variant in [TabVariant.Pill, TabVariant.Underline]) {
            assertTrue(primaryQuads(variant, false) > 0, 'enabled selected $variant tab has its indicator');
            assertEquals(0, primaryQuads(variant, true), 'disabled selected $variant tab has no indicator');
        }
    }

    /**
     * DEV-015: a character typed over the selection and the typing that
     * follows undo in one step (the original took two undos).
     */
    function testDev015TypingOverASelectionUndoesInOneStep() {
        var input:Null<Entity<InputBaseState>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ScriptView>) -> {
            InputKeyBindings.init(cx.app);
            input = cx.app.newEntity((c:Context<InputBaseState>) -> (new InputState(window, c) : InputBaseState));
            final child = input;
            return new ScriptView((_, _) -> div().sizeFull().child(child));
        }, 240, 80);
        cx = opened.cx;
        cx.update((window, app) -> input.update(app, (state, cx) -> {
            state.replaceTextInRange(null, "one to", window, cx);
            state.selectAll(window, cx);
            for (ch in ["n", "e", "w"]) state.replaceTextInRange(null, ch, window, cx);
            assertEquals("new", state.value());
            state.undo(new gpui.base.input.InputActions.Undo(), window, cx);
            assertEquals("one to", state.value());
            state.undo(new gpui.base.input.InputActions.Undo(), window, cx);
            assertEquals("", state.value());
        }));
    }

}

private class InferHost extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final entity:Entity<InferHost> = cx.entity();
        return hFlex().h(px(100.)).itemsStart().child(
            VirtualList.hVirtualList(entity, 'infer', [for (_ in 0...4) new Size(50., 40.)], (_, start, end, _, _) -> {
                return [for (ix in start...end) (div().w(px(50.)).h(px(40.)) : IntoElement)];
            })
                .withSizingBehavior(Infer)
                .w(px(300.))
                .hAuto()
                .bg(hsla(0., 0., 0.5, 1.))
        );
    }

}

private class Host extends Model implements Render {

    final build:() -> IntoElement;

    public function new(build:() -> IntoElement) {
        super();
        this.build = build;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return build();
    }

}
