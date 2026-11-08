// Ported from gpui-kit 0.8.1: crates/base/src/color_picker.rs, crates/component/src/color_picker.rs
// and crates/base/src/tabs.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.ColorPicker.ColorPickerEvent;
import glaze.kit.base.ColorPicker.ColorPickerState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.colorpicker.ColorPicker;
import glaze.kit.colorpicker.ColorPicker.ColorSelect;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.Slider.SliderValueTools;

/**
 * The `#[cfg(test)]` tests of the color picker (Base and Component) and of
 * Base `Tabs` (the color picker's palette and HSLA panels sit in a tab bar).
 *
 * The accesskit queries read the elements' `A11y` records instead.
 */
class ColorPickerTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        // The Base key bindings come with the initialization, which the
        // unstyled color picker (no Root, no kit theme) does not trigger
        app.update(cx -> glaze.kit.Kit.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement, width:Float = 1920, height:Float = 1080):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), width, height);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    static function parseHex(value:String):Null<Hsla> {
        return @:privateAccess ColorPickerState.parseHex(value);
    }

    static function hexString(color:Hsla):String {
        return @:privateAccess ColorPickerState.hexString(color);
    }

    /** A picker state in its own window (Rust `state(cx)`). */
    function pickerState(?build:(Window, Context<ColorPickerState>) -> ColorPickerState):{state:Entity<ColorPickerState>, cx:VisualTestContext} {
        var state:Entity<ColorPickerState> = null;
        final cx = open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<ColorPickerState>) -> build != null ? build(window, c) : new ColorPickerState(window, c));
            return div();
        });
        return {state: state, cx: cx};
    }

    /// Base

    function testParsesEverySupportedHexWidth() {
        final white = parseHex('#fff');
        assertEquals('#FFFFFF', hexString(white));
        assertTrue(parseHex('ffffff').equals(white));

        final half = parseHex('#ff000080');
        assertTrue(Math.abs(half.a - 0.5) < 0.01);
        assertEquals(half.h, parseHex('#f008').h);
    }

    function testRejectsMalformedHex() {
        for (value in ['#nope', '#12', '#1234567', '', '#+f0000', '#-fffff']) {
            assertNull(parseHex(value), '$value should not parse');
        }
    }

    function testFormatsAlphaOnlyWhenTranslucent() {
        assertEquals('#FF0000', hexString(hsla(0., 1., 0.5, 1.)));
        assertEquals('#FF000080', hexString(hsla(0., 1., 0.5, 0.5)));
    }

    function testDefaultValueReachesTheHexFieldAndSliders() {
        final p = pickerState((window, cx) -> new ColorPickerState(window, cx).defaultValue(hsla(0., 1., 0.5, 1.)));
        p.cx.update((window, app) -> p.state.update(app, (state, cx) -> state.syncPendingValue(window, cx)));
        final state = p.state.read(app);
        assertEquals('#FF0000', state.hexInput().read(app).value());
        assertEquals(0.5, state.sliders().lightness().read(app).value().start());
    }

    function testPreviewDoesNotChangeTheCommittedValue() {
        final p = pickerState();
        final committed = hsla(0.1, 0.2, 0.3, 1.);
        final previewed = hsla(0.6, 0.7, 0.8, 1.);
        p.cx.update((window, app) -> p.state.update(app, (state, cx) -> {
            state.setValue(committed, window, cx);
            state.previewColor(previewed, window, cx);
        }));
        assertTrue(p.state.read(app).value().equals(committed));
        assertTrue(p.state.read(app).displayedColor().equals(previewed));
        p.cx.update((window, app) -> p.state.update(app, (state, cx) -> state.clearPreview(window, cx)));
        assertTrue(p.state.read(app).displayedColor().equals(committed));
    }

    function testFirstHexEditAfterSetValuePreviews() {
        final p = pickerState();
        p.cx.update((window, app) -> {
            p.state.update(app, (state, cx) -> state.setValue(hsla(0., 1., 0.5, 1.), window, cx));
            // A typed edit: new text and the change event it brings.
            final input:Entity<InputBaseState> = cast p.state.read(app).hexInput();
            input.update(app, (input, cx) -> {
                input.setValue('#00FF00', window, cx);
                cx.emit(InputEvent.Change);
            });
        });
        p.cx.runUntilParked();
        assertEquals('#00FF00', hexString(p.state.read(app).preview()));
    }

    function testInvalidHexLeavesPreviewAndValueAlone() {
        final p = pickerState();
        final color = hsla(0.1, 0.2, 0.3, 1.);
        p.cx.update((window, app) -> p.state.update(app, (state, cx) -> {
            state.setValue(color, window, cx);
            assertFalse(state.previewHex('#nope', window, cx));
            assertNull(state.commitHex('#12', window, cx));
        }));
        assertTrue(p.state.read(app).preview().equals(color));
        assertTrue(p.state.read(app).value().equals(color));
    }

    function testPaletteSelectionClosesButASliderUpdateStaysOpen() {
        final p = pickerState();
        final changes:Array<Null<Hsla>> = [];
        final subscription = app.subscribe(p.state, ColorPickerEvent, (_, event, _) -> switch event {
            case Change(color): changes.push(color);
        });
        p.cx.update((window, app) -> p.state.update(app, (state, cx) -> {
            state.setOpen(true, cx);
            state.updateColor(hsla(0.2, 0.3, 0.4, 1.), window, cx);
        }));
        assertTrue(p.state.read(app).isOpen());
        p.cx.update((window, app) -> p.state.update(app, (state, cx) -> state.selectColor(hsla(0.5, 0.6, 0.7, 1.), window, cx)));
        assertFalse(p.state.read(app).isOpen());
        p.cx.runUntilParked();
        assertEquals(2, changes.length);
        subscription.dispose();
    }

    function testCommittingHexUpdatesTheValueAndCloses() {
        final p = pickerState();
        var committed:Null<Hsla> = null;
        p.cx.update((window, app) -> p.state.update(app, (state, cx) -> {
            state.setOpen(true, cx);
            committed = state.commitHex('#ff0000', window, cx);
        }));
        final state = p.state.read(app);
        assertTrue(state.value().equals(committed));
        assertTrue(state.preview().equals(committed));
        assertFalse(state.isOpen());
    }

    function testOpenAndActivePanelAreControlled() {
        final p = pickerState();
        p.cx.update((_, app) -> p.state.update(app, (state, cx) -> {
            state.toggleOpen(cx);
            state.setActiveTab(1, cx);
        }));
        assertTrue(p.state.read(app).isOpen());
        assertEquals(1, p.state.read(app).activeTab());
    }

    function testConfirmTogglesAndCancelDismisses() {
        final changes:Array<Bool> = [];
        var open = false;
        var focusHandle:FocusHandle = null;
        final cx = open_((window, cx) -> {
            if (focusHandle == null) focusHandle = cx.focusHandle();
            final view = cx.entityId();
            return new glaze.kit.base.ColorPicker('picker')
                .open(open)
                .trackFocus(focusHandle)
                .size(px(20.))
                .onOpenChange((next, _, cx) -> {
                    changes.push(next);
                    open = next;
                    cx.notify(view);
                });
        });
        cx.update((window, app) -> {
            focusHandle.focus(window, app);
            window.draw();
        });
        cx.simulateKeystrokes('enter');
        assertTrue(open);
        cx.simulateKeystrokes('enter');
        assertFalse(open);
        cx.simulateKeystrokes('enter escape');
        assertFalse(open);
        assertEquals('true,false,true,false', changes.join(','));
    }

    inline function open_(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        return open(render);
    }

    /// Component

    function testRepeatedPaletteColorsHaveIndependentFocusStops() {
        var state:Entity<ColorPickerState> = null;
        final cx = open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<ColorPickerState>) -> new ColorPickerState(window, c));
            final color = @:privateAccess ColorPicker.colorPalettes()[0][0];
            return @:privateAccess new ColorPicker(state).featuredColors([color, color]).renderPalettePanel(cx.app);
        });
        var swatchCount = 2;
        for (palette in @:privateAccess ColorPicker.colorPalettes()) swatchCount += palette.length;
        cx.update((window, app) -> {
            window.draw();
            final focused:Array<FocusHandle> = [];
            for (_ in 0...swatchCount) {
                window.focusNext(app);
                final handle = window.focused(app);
                assertNotNull(handle, 'each swatch is focusable');
                assertFalse(focused.indexOf(handle) != -1, 'equal colors must not share element identity or a focus stop');
                focused.push(handle);
            }
            window.focusNext(app);
            assertTrue(window.focused(app) == focused[0]);
        });
    }

    function testAnExplicitAccessibilityLabelReplacesTheVisibleOne() {
        final p = pickerState();
        final plain = new ColorPicker(p.state).label('Color');
        assertNull(plain.accessibilityLabelValue);
        assertEquals('Color', plain.labelValue);
        final named = new ColorPicker(p.state).label('Color').accessibilityLabel('Text color');
        assertEquals('Text color', named.accessibilityLabelValue, 'an explicit name must win over the visible label');
        assertEquals('Color', named.labelValue, 'and must not change what is drawn');
    }

    function testColorSelectBuilder() {
        final p = pickerState();
        final select = new ColorSelect(p.state)
            .large()
            .placeholder('Pick a color')
            .accessibilityLabel('Theme color')
            .featuredColors([hsla(0., 1., 0.5, 1.)]);
        assertTrue(select.picker.field);
        assertTrue(select.picker.size.match(Large));
        assertEquals('Pick a color', select.picker.placeholderValue);
        assertEquals('Theme color', select.picker.accessibilityLabelValue);
        assertEquals(1, select.picker.featuredColorsValue.length);
    }

    function testAClickAnywhereOnTheColorSelectOpensThePicker() {
        var state:Entity<ColorPickerState> = null;
        final cx = open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<ColorPickerState>) -> new ColorPickerState(window, c));
            return div().w(px(400.)).child(new ColorSelect(state));
        });
        assertFalse(state.read(app).isOpen(), 'the picker starts closed');
        // Far from the swatch, where only the field frame can take the click.
        cx.simulateClick(new Point(300., 16.));
        cx.update((window, _) -> window.draw());
        assertTrue(state.read(app).isOpen(), 'the whole field is the trigger, like a Select');
    }

    /// Base tabs

    function testPointerActivationAndDisabledGatingMatchTabs() {
        for (disabled in [false, true]) {
            final clicks = [0];
            final cx = open((_, _) -> new glaze.kit.base.Tabs.BaseTab('tab').disabled(disabled).size(px(100.)).onClick((_, _, _) -> clicks[0]++));
            cx.simulateClick(new Point(10., 10.));
            assertEquals(disabled ? 0 : 1, clicks[0]);
        }
    }

    function testFixedHeightTabCentersOrdinaryChildGeometry() {
        var root:Null<Bounds> = null;
        var child:Null<Bounds> = null;
        open((_, _) -> new glaze.kit.base.Tabs.BaseTab('alignment-tab')
            .w(px(120.))
            .h(px(40.))
            .child(div().w(px(48.)).h(px(12.)).onPrepaint((bounds, _, _) -> child = bounds))
            .onPrepaint((bounds, _, _) -> root = bounds));
        assertTrue(child.center().equals(root.center()));
    }

    function testExposesTabAccessibilityState() {
        final selected = new glaze.kit.base.Tabs.BaseTab('selected').selected(true).accessibilityLabel('Account').onClick((_, _, _) -> {});
        final disabled = new glaze.kit.base.Tabs.BaseTab('disabled').disabled(true).onClick((_, _, _) -> {});
        open((_, _) -> div().child(selected).child(disabled));
        assertEquals(Role.Tab, selected.a11y.role);
        assertEquals('Account', selected.a11y.label);
        assertEquals(true, selected.a11y.selected);
        assertTrue(selected.a11y.clickable);
        assertFalse(disabled.a11y.clickable);
    }

    function testSemanticStylesPreserveTheLegacyStatePriority() {
        final expected = hsla(0.3, 0.4, 0.5, 1.0);
        final tab = new glaze.kit.base.Tabs.BaseTab('tab')
            .selected(true)
            .disabled(true)
            .styles(styles -> styles
                .selected(style -> style.opacity(0.8))
                .disabled(style -> style.opacity(0.5)))
            .opacity(0.9);
        assertEquals(0.5, @:privateAccess tab.resolvedStyle().opacity);
        tab.bg(expected);
        assertTrue(Std.string(@:privateAccess tab.resolvedStyle().background) == Std.string(glaze.Background.fromHsla(expected)));
    }

    function testTabsExposesTabListRole() {
        assertEquals(Role.TabList, new glaze.kit.base.Tabs('tabs').a11y.role);
    }

}
