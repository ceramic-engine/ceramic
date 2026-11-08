// Ported from gpui-kit 0.8.1: crates/base/src/button.rs, toggle.rs, checkbox.rs, radio.rs,
// switch.rs, slider.rs and toolbar.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Base;
import glaze.kit.base.Button;
import glaze.kit.base.Checkbox;
import glaze.kit.base.Radio;
import glaze.kit.base.Root;
import glaze.kit.base.Slider;
import glaze.kit.base.Switch;
import glaze.kit.base.Toggle;
import glaze.kit.base.Toolbar;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.ClickEvent.ClickEventTools;
using glaze.kit.base.ElementExt;
using glaze.kit.base.Slider.SliderValueTools;

/**
 * The tests of gpui-base's controls: `button.rs`, `toggle.rs`,
 * `checkbox.rs`, `radio.rs`, `switch.rs`, `slider.rs` and `toolbar.rs`.
 *
 * The accessibility tests read the `A11y` data the controls export (the
 * port has no accesskit tree): role, label, toggled state, click action,
 * disabled state.
 */
class BaseControlsTest extends TestCase {

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

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    static function click(cx:VisualTestContext, x:Float = 10, y:Float = 10):Void {
        cx.simulateClick(new Point(x, y));
    }

    static function activateKey(cx:VisualTestContext, key:String):Void {
        final keystroke = Keystroke.parse(key);
        cx.simulateEvent(new KeyDownEvent(keystroke, false, false));
        cx.simulateEvent(new KeyUpEvent(keystroke));
    }

    static function opacityOf(style:StyleRefinement):Null<Float> {
        return style.has(StyleRefinement.OPACITY) ? style.opacity : null;
    }

    static function solidBackground(style:StyleRefinement):Null<Hsla> {
        return style.background != null ? style.background.asSolid() : null;
    }

    static function sameColor(expected:Hsla, actual:Null<Hsla>):Bool {
        return actual != null && expected.equals(actual);
    }

    /// Button

    function buttonHarness(disabled:Bool):{cx:VisualTestContext, clicks:Array<Int>} {
        final counts = [0, 0, 0]; // button clicks, parent clicks, keyboard events
        final cx = open((_, _) -> div()
            .id('button-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> counts[1]++)
            .child(glaze.kit.base.Button.component('button')
                .disabled(disabled)
                .sizeFull()
                .onClick((event, _, _) -> {
                    counts[0]++;
                    if (event.isKeyboard()) counts[2]++;
                })));
        return {cx: cx, clicks: counts};
    }

    function testButtonPointerActivationFiresOnce() {
        final h = buttonHarness(false);
        click(h.cx);
        assertEquals(1, h.clicks[0]);
        assertEquals(0, h.clicks[2]);
    }

    function testButtonEnterAndSpaceUseOneNativeKeyboardClickEach() {
        final h = buttonHarness(false);
        click(h.cx);
        h.clicks[0] = 0;
        h.cx.update((window, app) -> {
            assertNotNull(window.focused(app));
            window.draw();
        });
        for (key in ['enter', 'space']) activateKey(h.cx, key);
        assertEquals(2, h.clicks[0]);
        assertEquals(2, h.clicks[2]);
    }

    function testDisabledButtonIsInertAndBlocksParentActivation() {
        final h = buttonHarness(true);
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.clicks[0]);
        assertEquals(0, h.clicks[1]);
    }

    function pressTransitionKey(cx:VisualTestContext, key:String):Void {
        activateKey(cx, key);
        cx.update((window, _) -> window.draw());
    }

    function testDisablingFocusedButtonPreservesBidirectionalTraversal() {
        app.update(cx -> Base.init(cx));
        for (spec in [{key: 'tab', expected: 2, back: 'shift-tab', opposite: 0}, {key: 'shift-tab', expected: 0, back: 'tab', opposite: 2}]) {
            final handles = [for (_ in 0...3) app.focusHandle()];
            final controls = app.newEntity((_:Context<DisableDuringFocus>) -> new DisableDuringFocus(handles));
            final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> controls);
            final cx = opened.cx;
            contexts.push(cx);
            cx.update((window, app) -> {
                window.setActive(true);
                window.draw();
                handles[0].focus(window, app);
                window.draw();
            });
            pressTransitionKey(cx, 'tab');
            cx.update((window, app) -> {
                window.draw();
                assertTrue(window.focused(app) == handles[1]);
            });
            pressTransitionKey(cx, 'space');
            cx.update((window, app) -> {
                window.draw();
                assertTrue(controls.read(app).isDisabled);
                assertEquals(1, controls.read(app).activations);
            });
            pressTransitionKey(cx, 'enter');
            pressTransitionKey(cx, 'space');
            cx.update((_, app) -> assertEquals(1, controls.read(app).activations, 'disabled stays inert'));
            pressTransitionKey(cx, spec.key);
            cx.update((window, app) -> {
                window.draw();
                assertTrue(window.focused(app) == handles[spec.expected]);
            });
            pressTransitionKey(cx, spec.back);
            cx.update((window, app) -> {
                window.draw();
                assertTrue(window.focused(app) == handles[spec.opposite]);
            });
            controls.update(app, (this_, _) -> this_.isDisabled = false);
            cx.update((window, _) -> window.draw());
            pressTransitionKey(cx, spec.key);
            cx.update((window, app) -> {
                window.draw();
                assertTrue(window.focused(app) == handles[1]);
            });
        }
    }

    function testFixedHeightButtonCentersOrdinaryChildGeometry() {
        var root:Null<Bounds> = null;
        var child:Null<Bounds> = null;
        final cx = open((_, _) -> glaze.kit.base.Button.component('alignment-button')
            .w(px(120.))
            .h(px(40.))
            .child(div().w(px(48.)).h(px(12.)).onPrepaint((bounds, _, _) -> child = bounds))
            .onPrepaint((bounds, _, _) -> root = bounds));
        cx.update((window, _) -> window.draw());
        assertNotNull(root);
        assertNotNull(child);
        assertTrue(child.center().equals(root.center()));
    }

    function testButtonStateStylingMethodsAreAvailableToApplications() {
        final button = glaze.kit.base.Button.component('states')
            .styles(styles -> styles.disabled(style -> style
                .opacity(0.5)
                .when(true, style -> style.border1())
                .when(true, style -> style.opacity(0.4))
                .when(true, style -> style.roundedSm())))
            .hover(style -> style.opacity(0.9))
            .active(style -> style.opacity(0.8))
            .focusVisible(style -> style.opacity(0.7));
        assertNotNull(button);
    }

    function testDisabledStyleAppliesOnlyWhileDisabledAndThenWins() {
        final enabled = glaze.kit.base.Button.component('enabled').opacity(0.9).styles(styles -> styles.disabled(style -> style.opacity(0.5)));
        assertFloatEquals(0.9, opacityOf(enabled.resolvedStyle()));

        final disabled = glaze.kit.base.Button.component('disabled').styles(styles -> styles.disabled(style -> style.opacity(0.5))).opacity(0.9).disabled(true);
        assertFloatEquals(0.5, opacityOf(disabled.resolvedStyle()));

        final semanticOnly = glaze.kit.base.Button.component('semantic-only').styles(styles -> styles.disabled(style -> style.opacity(0.5))).disabled(true);
        assertFloatEquals(0.5, opacityOf(semanticOnly.resolvedStyle()));
    }

    function testSelectedDisabledAndInstanceStylesFollowTheSharedPriority() {
        final selectedColor = hsla(0.6, 0.7, 0.5, 1.0);
        final disabledColor = hsla(0.1, 0.2, 0.3, 0.5);
        final button = (selected:Bool, disabled:Bool) -> glaze.kit.base.Button.component('button')
            .selected(selected)
            .disabled(disabled)
            .styles(styles -> styles.selected(style -> style.bg(selectedColor)).disabled(style -> style.bg(disabledColor)));

        assertNull(button(false, false).resolvedStyle().background);
        assertTrue(sameColor(selectedColor, solidBackground(button(true, false).resolvedStyle())));
        assertTrue(sameColor(disabledColor, solidBackground(button(true, true).resolvedStyle())));
        assertTrue(sameColor(disabledColor, solidBackground(button(true, true).bg(selectedColor).resolvedStyle())));
    }

    function testButtonAccessibilityRoleLabelAndDisabledActionSurface() {
        final enabled = glaze.kit.base.Button.component('enabled').accessibilityLabel('Save').onClick((_, _, _) -> {});
        final disabled = glaze.kit.base.Button.component('disabled').disabled(true).accessibilityLabel('Save').onClick((_, _, _) -> {});
        open((_, _) -> div().child(enabled).child(disabled));
        assertEquals(Role.Button, enabled.a11y.role);
        assertEquals('Save', enabled.a11y.label);
        assertTrue(enabled.a11y.clickable);
        assertEquals(Role.Button, disabled.a11y.role);
        assertFalse(disabled.a11y.clickable);
        assertFalse(enabled.a11y.disabled);
        assertTrue(disabled.a11y.disabled);
    }

    /// Toggle

    function toggleHarness(pressed:Bool, disabled:Bool):{cx:VisualTestContext, changes:Array<Bool>, keyboard:Array<Int>} {
        final changes:Array<Bool> = [];
        final keyboard = [0];
        final cx = open((_, _) -> Toggle.component('toggle')
            .pressed(pressed)
            .disabled(disabled)
            .size(px(100.))
            .onChange((value, event, _, _) -> {
                changes.push(value);
                if (event.isKeyboard()) keyboard[0]++;
            }));
        return {cx: cx, changes: changes, keyboard: keyboard};
    }

    function testTogglePointerRequestsInverseControlledStateOnce() {
        for (spec in [{pressed: false, expected: true}, {pressed: true, expected: false}]) {
            final h = toggleHarness(spec.pressed, false);
            click(h.cx);
            assertEquals(1, h.changes.length);
            assertEquals(spec.expected, h.changes[0]);
        }
    }

    function testToggleEnterAndSpaceUseOneNativeKeyboardClickEach() {
        final h = toggleHarness(false, false);
        click(h.cx);
        h.changes.resize(0);
        h.cx.update((window, _) -> window.draw());
        for (key in ['enter', 'space']) activateKey(h.cx, key);
        assertEquals('true,true', h.changes.join(','));
        assertEquals(2, h.keyboard[0]);
    }

    function testDisabledToggleIsInert() {
        final h = toggleHarness(false, true);
        click(h.cx);
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.changes.length);
    }

    function testFixedHeightToggleCentersOrdinaryChildGeometry() {
        var root:Null<Bounds> = null;
        var child:Null<Bounds> = null;
        final cx = open((_, _) -> Toggle.component('alignment-toggle')
            .w(px(120.))
            .h(px(40.))
            .child(div().w(px(48.)).h(px(12.)).onPrepaint((bounds, _, _) -> child = bounds))
            .onPrepaint((bounds, _, _) -> root = bounds));
        cx.update((window, _) -> window.draw());
        assertTrue(child.center().equals(root.center()));
    }

    function testToggleSemanticRootStylesFollowTogglePriority() {
        final styled = (toggle:Toggle) -> toggle.styles(styles -> styles.pressed(style -> style.opacity(0.8)).disabled(style -> style.opacity(0.5)));
        assertNull(opacityOf(styled(Toggle.component('normal')).resolvedStyle()));
        assertFloatEquals(0.8, opacityOf(styled(Toggle.component('pressed').pressed(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styled(Toggle.component('pressed-disabled').pressed(true).disabled(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styled(Toggle.component('state-over-instance').pressed(true).disabled(true).opacity(0.9)).resolvedStyle()));
    }

    function testToggleAccessibilityExposesButtonRoleToggledStateAndAction() {
        final enabled = Toggle.component('enabled').pressed(true).accessibilityLabel('Bold').onChange((_, _, _, _) -> {});
        final disabled = Toggle.component('disabled').disabled(true).onChange((_, _, _, _) -> {});
        open((_, _) -> div().child(enabled).child(disabled));
        assertEquals(Role.Button, enabled.a11y.role);
        assertEquals('Bold', enabled.a11y.label);
        assertEquals(Toggled.True, enabled.a11y.toggled);
        assertTrue(enabled.a11y.clickable);
        assertEquals(Toggled.False, disabled.a11y.toggled);
        assertFalse(disabled.a11y.clickable);
    }

    /// Checkbox

    function testCheckboxIndicatorProjectsStateStylesOverTheInstanceLayer() {
        final checkedColor = hsla(0.6, 0.7, 0.5, 1.0);
        final disabledColor = hsla(0.1, 0.2, 0.3, 0.5);
        final indicator = (state:CheckboxState, disabled:Bool) -> CheckboxIndicator.component()
            .state(state)
            .disabled(disabled)
            .styles(styles -> styles
                .checked(style -> style.borderColor(checkedColor))
                .indeterminate(style -> style.opacity(0.7))
                .disabled(style -> style.borderColor(disabledColor)));

        assertTrue(sameColor(checkedColor, indicator(Checked, false).resolvedStyle().borderColor));
        assertTrue(sameColor(disabledColor, indicator(Checked, true).resolvedStyle().borderColor));
        assertFloatEquals(0.7, opacityOf(indicator(Indeterminate, false).resolvedStyle()));
        assertTrue(sameColor(disabledColor, indicator(Checked, true).borderColor(checkedColor).resolvedStyle().borderColor));
    }

    function checkboxHarness(state:CheckboxState, disabled:Bool):{cx:VisualTestContext, changes:Array<CheckboxState>, parent:Array<Int>} {
        final changes:Array<CheckboxState> = [];
        final parent = [0];
        final cx = open((_, _) -> div()
            .id('checkbox-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> parent[0]++)
            .child(Checkbox.component('checkbox')
                .state(state)
                .disabled(disabled)
                .sizeFull()
                .onChange((state, _, _, _) -> changes.push(state))));
        return {cx: cx, changes: changes, parent: parent};
    }

    function testCheckboxPointerActivationEmitsTheNextStateOnce() {
        final h = checkboxHarness(Unchecked, false);
        click(h.cx);
        assertEquals(1, h.changes.length);
        assertTrue(h.changes[0] == Checked);
    }

    function testIndeterminateActivationBecomesChecked() {
        final h = checkboxHarness(Indeterminate, false);
        click(h.cx);
        assertEquals(1, h.changes.length);
        assertTrue(h.changes[0] == Checked);
    }

    function testCheckboxEnterAndSpaceEachEmitOnce() {
        final h = checkboxHarness(Checked, false);
        click(h.cx);
        h.changes.resize(0);
        h.cx.update((window, app) -> {
            assertNotNull(window.focused(app));
            window.draw();
        });
        for (key in ['enter', 'space']) activateKey(h.cx, key);
        assertEquals(2, h.changes.length);
        assertTrue(h.changes[0] == Unchecked && h.changes[1] == Unchecked);
    }

    function testDisabledCheckboxIsInertAndAllowsPointerEventsToBubble() {
        final h = checkboxHarness(Unchecked, true);
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.changes.length);
        assertEquals(1, h.parent[0]);
    }

    function testCheckboxSemanticRootStylesFollowCheckboxPriority() {
        final styles = (checkbox:Checkbox) -> checkbox.styles(styles -> styles
            .checked(style -> style.opacity(0.8))
            .indeterminate(style -> style.opacity(0.7))
            .disabled(style -> style.opacity(0.5)));
        assertNull(opacityOf(styles(Checkbox.component('normal')).resolvedStyle()));
        assertFloatEquals(0.8, opacityOf(styles(Checkbox.component('checked').checked(true)).resolvedStyle()));
        assertFloatEquals(0.7, opacityOf(styles(Checkbox.component('indeterminate').indeterminate(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styles(Checkbox.component('disabled').disabled(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styles(Checkbox.component('checked-disabled').checked(true).disabled(true)).resolvedStyle()));

        final checkedColor = hsla(0.6, 0.7, 0.5, 1.0);
        final combined = Checkbox.component('combined')
            .checked(true)
            .disabled(true)
            .styles(styles -> styles.checked(style -> style.borderColor(checkedColor)).disabled(style -> style.opacity(0.5)))
            .resolvedStyle();
        assertTrue(sameColor(checkedColor, combined.borderColor));
        assertFloatEquals(0.5, opacityOf(combined));

        final stateOverInstance = styles(Checkbox.component('state-over-instance').checked(true).disabled(true).opacity(0.9));
        assertFloatEquals(0.5, opacityOf(stateOverInstance.resolvedStyle()));
    }

    function testCheckboxAccessibilityExposesRoleLabelAndAllToggleStates() {
        final unchecked = Checkbox.component('unchecked').accessibilityLabel('Remember me').onChange((_, _, _, _) -> {});
        final checked = Checkbox.component('checked').checked(true).onChange((_, _, _, _) -> {});
        final mixed = Checkbox.component('mixed').indeterminate(true).onChange((_, _, _, _) -> {});
        final disabled = Checkbox.component('disabled').disabled(true).onChange((_, _, _, _) -> {});
        open((_, _) -> div().child(unchecked).child(checked).child(mixed).child(disabled));
        assertEquals(Role.CheckBox, unchecked.a11y.role);
        assertEquals('Remember me', unchecked.a11y.label);
        assertEquals(Toggled.False, unchecked.a11y.toggled);
        assertEquals(Toggled.True, checked.a11y.toggled);
        assertEquals(Toggled.Mixed, mixed.a11y.toggled);
        assertTrue(unchecked.a11y.clickable);
        assertFalse(disabled.a11y.clickable);
    }

    /// Radio

    function testRadioSemanticRootStylesFollowRadioPriority() {
        final styled = (radio:Radio) -> radio.styles(styles -> styles.checked(style -> style.opacity(0.8)).disabled(style -> style.opacity(0.5)));
        assertNull(opacityOf(styled(Radio.component('normal')).resolvedStyle()));
        assertFloatEquals(0.8, opacityOf(styled(Radio.component('checked').checked(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styled(Radio.component('checked-disabled').checked(true).disabled(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styled(Radio.component('state-over-instance').checked(true).disabled(true).opacity(0.9)).resolvedStyle()));
    }

    function radioHarness(checked:Bool, disabled:Bool):{cx:VisualTestContext, changes:Array<Int>} {
        final counts = [0, 0];
        final cx = open((_, _) -> Radio.component('radio')
            .checked(checked)
            .disabled(disabled)
            .size(px(100.))
            .onChange((value, event, _, _) -> {
                assertTrue(value);
                counts[0]++;
                if (event.isKeyboard()) counts[1]++;
            }));
        return {cx: cx, changes: counts};
    }

    function testRadioPointerAndKeyboardActivationFireOnce() {
        final h = radioHarness(false, false);
        click(h.cx);
        assertEquals(1, h.changes[0]);
        h.changes[0] = 0;
        h.cx.update((window, _) -> window.draw());
        for (key in ['enter', 'space']) activateKey(h.cx, key);
        assertEquals(2, h.changes[0]);
        assertEquals(2, h.changes[1]);
    }

    function testCheckedAndDisabledRadiosAreInert() {
        for (spec in [{checked: true, disabled: false}, {checked: false, disabled: true}]) {
            final h = radioHarness(spec.checked, spec.disabled);
            click(h.cx);
            h.cx.simulateKeystrokes('enter space');
            assertEquals(0, h.changes[0]);
        }
    }

    function testRadioAccessibilityExposesRoleStateAndAction() {
        final radio = Radio.component('probe').checked(true).accessibilityLabel('Choice');
        open((_, _) -> div().child(radio));
        assertEquals(Role.RadioButton, radio.a11y.role);
        assertEquals('Choice', radio.a11y.label);
        assertEquals(Toggled.True, radio.a11y.toggled);
        assertFalse(radio.a11y.clickable);
    }

    /// Switch

    function testSwitchTrackProjectsCheckedDisabledAndInstanceStylePriority() {
        final normalColor = hsla(0.0, 0.0, 0.2, 1.0);
        final checkedColor = hsla(0.6, 0.7, 0.5, 1.0);
        final disabledColor = hsla(0.6, 0.7, 0.5, 0.5);
        final track = (checked:Bool, disabled:Bool) -> {
            final track = SwitchTrack.component(ElementId.NamedInteger('track', (checked ? 2 : 0) + (disabled ? 1 : 0))).checked(checked).disabled(disabled);
            if (!checked) track.bg(normalColor);
            return track.styles(styles -> styles
                .checked(style -> style.bg(checkedColor))
                .disabled(style -> style.when(checked, style -> style.bg(disabledColor))));
        };
        assertTrue(sameColor(normalColor, solidBackground(track(false, false).resolvedStyle())));
        assertTrue(sameColor(normalColor, solidBackground(track(false, true).resolvedStyle())));
        assertTrue(sameColor(checkedColor, solidBackground(track(true, false).resolvedStyle())));
        assertTrue(sameColor(disabledColor, solidBackground(track(true, true).resolvedStyle())));
        // Semantic states layer over the instance chain, so an instance
        // background does not defeat the disabled state.
        assertTrue(sameColor(disabledColor, solidBackground(track(true, true).bg(normalColor).resolvedStyle())));
    }

    function testSwitchTrackIdentityIsScopedToItsSwitch() {
        final first = SwitchTrack.component(ElementId.NamedChild(Name('first-switch'), 'track'));
        final second = SwitchTrack.component(ElementId.NamedChild(Name('second-switch'), 'track'));
        assertTrue(Type.enumEq(first.trackId, ElementId.NamedChild(Name('first-switch'), 'track')));
        assertTrue(Type.enumEq(second.trackId, ElementId.NamedChild(Name('second-switch'), 'track')));
        assertFalse(Type.enumEq(first.trackId, second.trackId));
    }

    function testSwitchThumbProjectsCheckedDisabledAndInstanceStylePriority() {
        final checkedColor = hsla(0.6, 0.7, 0.5, 1.0);
        final disabledColor = hsla(0.1, 0.2, 0.3, 0.5);
        final thumb = (checked:Bool, disabled:Bool) -> SwitchThumb.component(checked)
            .disabled(disabled)
            .styles(styles -> styles.checked(style -> style.bg(checkedColor)).disabled(style -> style.bg(disabledColor)));
        assertTrue(sameColor(checkedColor, solidBackground(thumb(true, false).resolvedStyle())));
        assertTrue(sameColor(disabledColor, solidBackground(thumb(true, true).resolvedStyle())));
        assertTrue(sameColor(disabledColor, solidBackground(thumb(true, true).bg(checkedColor).resolvedStyle())));
    }

    function switchHarness(checked:Bool, disabled:Bool):{cx:VisualTestContext, counts:Array<Int>, last:Array<Bool>} {
        final counts = [0, 0, 0]; // toggles, keyboard events, parent clicks
        final last = [checked];
        final cx = open((_, _) -> div()
            .id('switch-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> counts[2]++)
            .child(glaze.kit.base.Switch.component('switch')
                .checked(checked)
                .disabled(disabled)
                .sizeFull()
                .onChange((value, event, _, _) -> {
                    counts[0]++;
                    last[0] = value;
                    if (event.isKeyboard()) counts[1]++;
                })));
        return {cx: cx, counts: counts, last: last};
    }

    function testSwitchPointerReportsTheNextValueOnce() {
        final h = switchHarness(false, false);
        click(h.cx);
        assertEquals(1, h.counts[0]);
        assertEquals(0, h.counts[1]);
        assertTrue(h.last[0]);
    }

    function testSwitchEnterAndSpaceReportOneNativeKeyboardActivationEach() {
        final h = switchHarness(false, false);
        click(h.cx);
        h.counts[0] = 0;
        h.cx.update((window, app) -> {
            assertNotNull(window.focused(app));
            window.draw();
        });
        activateKey(h.cx, 'enter');
        activateKey(h.cx, 'space');
        assertEquals(2, h.counts[0]);
        assertEquals(2, h.counts[1]);
        assertTrue(h.last[0]);
    }

    function testDisabledSwitchIsInertAndBlocksParentActivation() {
        final h = switchHarness(false, true);
        click(h.cx);
        activateKey(h.cx, 'enter');
        activateKey(h.cx, 'space');
        assertEquals(0, h.counts[0]);
        assertEquals(0, h.counts[2]);
    }

    function testSwitchSemanticRootStylesFollowSwitchPriority() {
        final styled = (s:Switch) -> s.styles(styles -> styles.checked(style -> style.opacity(0.8)).disabled(style -> style.opacity(0.5)));
        assertNull(opacityOf(styled(glaze.kit.base.Switch.component('normal')).resolvedStyle()));
        assertFloatEquals(0.8, opacityOf(styled(glaze.kit.base.Switch.component('checked').checked(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styled(glaze.kit.base.Switch.component('checked-disabled').checked(true).disabled(true)).resolvedStyle()));
        assertFloatEquals(0.5, opacityOf(styled(glaze.kit.base.Switch.component('state-over-instance').checked(true).disabled(true).opacity(0.9)).resolvedStyle()));
    }

    function testSwitchAccessibilityExposesSwitchRoleLabelAndToggledState() {
        final enabled = glaze.kit.base.Switch.component('enabled').checked(true).accessibilityLabel('Airplane mode').onChange((_, _, _, _) -> {});
        final disabled = glaze.kit.base.Switch.component('disabled').checked(false).disabled(true).accessibilityLabel('Airplane mode').onChange((_, _, _, _) -> {});
        open((_, _) -> div().child(enabled).child(disabled));
        assertEquals(Role.Switch, enabled.a11y.role);
        assertEquals('Airplane mode', enabled.a11y.label);
        assertEquals(Toggled.True, enabled.a11y.toggled);
        assertTrue(enabled.a11y.clickable);
        assertEquals(Role.Switch, disabled.a11y.role);
        assertEquals(Toggled.False, disabled.a11y.toggled);
        assertFalse(disabled.a11y.clickable);
        assertFalse(enabled.a11y.disabled);
        assertTrue(disabled.a11y.disabled);
    }

    /// Slider

    function testLegacyValueConversionsAndClampingArePreserved() {
        final single:IntoSliderValue = 5.;
        assertTrue((single:SliderValue).equals(Single(5.)));
        final range:IntoSliderValue = [2., 8.];
        assertTrue((range:SliderValue).equals(Range(2., 8.)));
        assertTrue(Range(-1., 12.).clamp(0., 10.).equals(Range(0., 10.)));
    }

    function testLegacyLinearStateKeepsPercentageAndRangeOrdering() {
        final state = new SliderState().min(0.).max(200.).defaultValue([50., 150.]);
        assertTrue(state.value().equals(Range(50., 150.)));
        assertEquals(0.25, state.percentage().start);
        assertEquals(0.75, state.percentage().end);
    }

    function testLegacyLogarithmicStateKeepsMapping() {
        final state = new SliderState().min(1.).max(1000.).scale(Logarithmic).defaultValue(10.);
        assertTrue(Math.abs(state.percentage().end - 1. / 3.) < 0.0001);
    }

    function testLegacyLogarithmicValidationIsPreserved() {
        var message:String = null;
        try {
            new SliderState().scale(Logarithmic);
        } catch (e:Dynamic) {
            message = Std.string(e);
        }
        assertTrue(message != null && message.indexOf('`min` must be greater than 0') >= 0);
    }

    /**
     * Drawing a slider's bar again where it was changes nothing in the
     * slider's state: a view beside it that reads the state is not built
     * again for it (Rust's `retained` test, with the port's view caching).
     */
    function testDrawingASliderAgainLeavesItsReadersRetained() {
        final renders = [0];
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState());
        final bar = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> div().w(px(120.)).h(px(24.)).child(SliderIndicator.component(state).sizeFull())));
        final readout = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, cx) -> {
            renders[0]++;
            return div().child(state.read(cx).value().toDisplayString());
        }));
        final cx = open((_, _) -> div().flex().child(bar).child(readout));
        cx.update((window, _) -> window.draw());
        cx.update((window, _) -> window.draw());
        final rendered = renders[0];
        // An explicit draw of a clean window renders every view (GPUI's
        // uncached views): the bar's notifications are drawn by the app as
        // it flushes its effects, like retained views drawing a dirty window.
        for (_ in 0...3) {
            bar.update(app, (_, barCx) -> barCx.notify());
            cx.runUntilParked();
        }
        assertEquals(rendered, renders[0], 'the readout was built again');
    }

    /// Toolbar

    function testToolbarBuilder() {
        final toolbar = glaze.kit.base.Toolbar.component('toolbar').disabled(true).child(div());
        assertTrue(toolbar.disabledValue);
        assertEquals(1, toolbar.childElements.length);
    }

    function testToolbarDefaults() {
        final toolbar = glaze.kit.base.Toolbar.component('toolbar');
        assertFalse(toolbar.disabledValue);
        assertEquals(0, toolbar.childElements.length);
    }

    function testToolbarGroupBuilder() {
        final group = ToolbarGroup.component('history-group').label('History').child(div()).child(div());
        assertEquals('History', group.labelValue);
        assertEquals(2, group.childElements.length);
    }

    function navHarness(count:Int, disabled:Bool):{cx:VisualTestContext, items:Array<FocusHandle>} {
        final items = [for (_ in 0...count) app.focusHandle().tabStop(true)];
        final names = ['first', 'second', 'third'];
        final cx = open((window, cx) -> {
            final toolbar = glaze.kit.base.Toolbar.component('nav-toolbar').disabled(disabled);
            for (i in 0...count) toolbar.child(div().id(names[i]).size(px(20.)).trackFocus(items[i]));
            return toolbar;
        });
        cx.update((window, app) -> {
            items[0].focus(window, app);
            window.draw();
        });
        return {cx: cx, items: items};
    }

    function assertFocused(cx:VisualTestContext, expected:FocusHandle, label:String, ?pos:haxe.PosInfos):Void {
        cx.update((window, _) -> assertTrue(expected.isFocused(window), 'expected $label to be focused', pos));
    }

    function testArrowKeysRoveFocusAcrossItems() {
        final h = navHarness(3, false);
        h.cx.simulateKeystrokes('right');
        assertFocused(h.cx, h.items[1], 'second');
        h.cx.simulateKeystrokes('right');
        assertFocused(h.cx, h.items[2], 'third');
        // Wrapping: past the last item, focus returns to the first.
        h.cx.simulateKeystrokes('right');
        assertFocused(h.cx, h.items[0], 'first (wrapped)');
        h.cx.simulateKeystrokes('left');
        assertFocused(h.cx, h.items[2], 'third (wrapped back)');
    }

    function testToolbarWithASingleItemKeepsFocusOnIt() {
        final h = navHarness(1, false);
        h.cx.simulateKeystrokes('right left right');
        assertFocused(h.cx, h.items[0], 'the only item');
    }

    function testGroupExposesGroupRoleAndAccessibleName() {
        var group:ToolbarGroup = null;
        open((_, _) -> div().child(group = ToolbarGroup.component('history').label('History').child(div().size(px(20.)))));
        assertEquals(Role.Group, group.a11y.role);
        assertEquals('History', group.a11y.label);
    }

    function testDisabledToolbarIgnoresArrowKeys() {
        final h = navHarness(2, true);
        h.cx.simulateKeystrokes('right');
        assertFocused(h.cx, h.items[0], 'first (disabled toolbar)');
    }

    function testClickingBlankToolbarSpaceKeepsFocusOutside() {
        final outside = app.focusHandle().tabStop(true);
        final item = app.focusHandle().tabStop(true);
        final cx = open((_, _) -> div()
            .child(div().id('outside').size(px(20.)).trackFocus(outside))
            .child(glaze.kit.base.Toolbar.component('click-toolbar')
                .flex()
                .w(px(100.))
                .h(px(20.))
                .child(div().id('item').size(px(20.)).trackFocus(item))));
        cx.update((window, app) -> {
            outside.focus(window, app);
            window.draw();
        });
        // Blank space to the right of the item: focus stays where it was.
        click(cx, 80, 30);
        assertFocused(cx, outside, 'outside (blank toolbar click)');
        // A focusable item still takes focus when clicked.
        click(cx, 10, 30);
        assertFocused(cx, item, 'item (clicked)');
    }

}

private class DisableDuringFocus extends Model implements Render {

    public final handles:Array<FocusHandle>;

    @observe public var isDisabled:Bool = false;

    @observe public var activations:Int = 0;

    public function new(handles:Array<FocusHandle>) {
        super();
        this.handles = handles;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .flex()
            .tabGroup()
            .child(glaze.kit.base.Button.component('before').trackFocus(handles[0]).child('Before'))
            .child(glaze.kit.base.Button.component('disable-self')
                .trackFocus(handles[1])
                .disabled(isDisabled)
                .child('Disable self')
                .onClick(cx.listener((this_:DisableDuringFocus, _, _, _) -> {
                    this_.isDisabled = true;
                    this_.activations++;
                })))
            .child(glaze.kit.base.Button.component('after').trackFocus(handles[2]).child('After'));
    }

}
