// Ported from gpui-kit 0.8.1: crates/component/src/button/{button,button_icon,button_group,toggle}.rs,
// checkbox.rs, radio.rs, switch.rs, slider.rs and toolbar.rs (tests), and the control parts of
// crates/kit/tests/integration/{control_steps,slider_steps,semantic_controls,controls,interactions}.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Modifiers;
import glaze.Point;
import glaze.Render;
import glaze.RenderOnce;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Slider.SliderEvent;
import glaze.kit.base.Slider.SliderState;
import glaze.kit.base.Slider.SliderValue;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.button.ButtonGroup;
import glaze.kit.button.ButtonIcon;
import glaze.kit.button.Toggle;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.radio.Radio;
import glaze.kit.slider.Slider;
import glaze.kit.spinner.Spinner;
import glaze.kit.switch_.Switch;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeConfig;
import glaze.kit.toolbar.Toolbar;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.ClickEvent.ClickEventTools;
using glaze.kit.base.ElementExt;
using glaze.kit.base.Slider.SliderValueTools;
using glaze.kit.Size.SizeTools;

/**
 * The `#[cfg(test)]` tests of the wave 3 styled controls, and the control
 * steps of gpui-kit's integration tests (their UI queries by label become
 * bounds probed with `onPrepaint`).
 *
 * Not ported: the switch tests that read `debug_bounds` of the track inside
 * the component (`focus_ring_hugs_the_track...`, `long_labels_preserve...`,
 * `label_prepaints...`: the port has no debug selectors), the
 * `ProgressCircle` button icon (with the progress circle), the custom data
 * icon test (it needs the menu), and the accesskit queries (read on the
 * port's `A11y` record where the component exposes it).
 */
class ComponentControlsTest extends TestCase {

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

    function open(render:(Window, Context<Dynamic>) -> IntoElement, width:Float = 1920, height:Float = 1080):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), width, height);
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

    /// Button

    function testAnExplicitAccessibilityLabelReplacesTheVisibleOne() {
        final plain = glaze.kit.button.Button.component('save').label('Save');
        assertNull(plain.accessibilityLabelValue);
        assertEquals('Save', plain.labelValue);
        final named = glaze.kit.button.Button.component('row').label('Save').accessibilityLabel('Save the current document');
        assertEquals('Save the current document', named.accessibilityLabelValue);
        assertEquals('Save', named.labelValue);
    }

    function pointerHarness(make:(Array<Int>) -> Button):{cx:VisualTestContext, counts:Array<Int>} {
        final counts = [0, 0, 0]; // button clicks, parent clicks, keyboard clicks
        final cx = open((_, _) -> div()
            .id('parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> counts[1]++)
            .child(make(counts).sizeFull()));
        return {cx: cx, counts: counts};
    }

    function testDisabledLegacyButtonKeepsExistingPointerBlocking() {
        final h = pointerHarness(counts -> glaze.kit.button.Button.component('disabled-legacy').disabled(true).onClick((_, _, _) -> counts[0]++));
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.counts[0]);
        assertEquals(0, h.counts[1]);
        h.cx.update((window, app) -> assertNull(window.focused(app)));
    }

    function testEnabledButtonDelegatesPointerEnterAndSpaceOnce() {
        final h = pointerHarness(counts -> glaze.kit.button.Button.component('enabled-legacy').onClick((event, _, _) -> {
            counts[0]++;
            if (event.isKeyboard()) counts[2]++;
        }));
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.update((window, app) -> {
            assertNotNull(window.focused(app));
            window.draw();
        });
        for (key in ['enter', 'space']) activateKey(h.cx, key);
        assertEquals(3, h.counts[0]);
        assertEquals(2, h.counts[2]);
    }

    function testCallerOwnedFocusHandleDrivesFocusAndKeyboardActivation() {
        final focusHandle = app.focusHandle();
        final clicks = [0];
        final cx = open((_, _) -> div().size(px(100.)).child(glaze.kit.button.Button.component('details').label('Details').trackFocus(focusHandle).onClick((_, _, _) -> clicks[0]++)));
        cx.update((window, app) -> {
            focusHandle.focus(window, app);
            window.draw();
        });
        cx.update((window, _) -> assertTrue(focusHandle.isFocused(window)));
        activateKey(cx, 'enter');
        assertEquals(1, clicks[0]);
    }

    function testLoadingButtonKeepsExistingPointerBlocking() {
        final h = pointerHarness(counts -> glaze.kit.button.Button.component('loading-legacy').loading(true).onClick((_, _, _) -> counts[0]++));
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.counts[0]);
        assertEquals(0, h.counts[1]);
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
    }

    function testLoadingButtonWithoutCallbackStillBlocksParentActivation() {
        final h = pointerHarness(_ -> glaze.kit.button.Button.component('loading-without-callback').loading(true));
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.counts[1]);
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
    }

    function testBaseActivationIsPreservedAndBlockedWhileLoading() {
        final clicks = [0];
        final loading = [false];
        final cx = open((_, _) -> div().tabGroup().child(glaze.kit.button.Button.component('close')
            .withBase(glaze.kit.base.Button.component('close').onClick((_, _, _) -> clicks[0]++))
            .loading(loading[0])
            .size(px(100.))));
        click(cx);
        assertEquals(1, clicks[0]);
        loading[0] = true;
        cx.update((window, _) -> window.refresh());
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
        click(cx);
        cx.update((window, app) -> window.focusNext(app));
        cx.simulateKeystrokes('enter space');
        assertEquals(1, clicks[0]);
    }

    function testButtonBuilder() {
        final button = glaze.kit.button.Button.component('complex-button')
            .label('Save Changes')
            .primary()
            .outline()
            .large()
            .tooltip('Click to save')
            .tooltipShowDelay(0.1)
            .compact()
            .loading(false)
            .disabled(false)
            .selected(false)
            .tabIndex(1)
            .tabStop(true)
            .dropdownCaret(false)
            .rounded(Medium)
            .onClick((_, _, _) -> {});
        assertEquals('Save Changes', button.labelValue);
        assertTrue(button.variantValue.equals(Primary));
        assertTrue(button.outlineValue);
        assertTrue(button.sizeValue.equals(Large));
        assertEquals('Click to save', button.tooltipValue);
        assertEquals(0.1, button.tooltipShowDelayValue);
        assertTrue(button.compactValue);
        assertFalse(button.loadingValue);
        assertFalse(button.disabledValue);
        assertFalse(button.selectedValue);
        assertNull(button.toggledValue);
        assertNull(button.focusHandleValue);
        assertEquals(1, button.tabIndexValue);
        assertTrue(button.tabStopValue);
        assertFalse(button.dropdownCaretValue);
        assertTrue(button.roundedValue.match(Medium));
    }

    function testAnOpenTriggerIsStoredApartFromASelectedOne() {
        final open = glaze.kit.button.Button.component('trigger').open(true);
        assertTrue(open.isOpen());
        assertFalse(open.isSelected());
        assertTrue(open.showsSelectedStyle());
        final selected = glaze.kit.button.Button.component('trigger').selected(true);
        assertTrue(selected.isSelected());
        assertFalse(selected.isOpen());
        assertTrue(selected.showsSelectedStyle());
        assertFalse(glaze.kit.button.Button.component('trigger').showsSelectedStyle());
    }

    function testSelectedTriggerPresentationDoesNotImplyToggledAccessibility() {
        final selected = glaze.kit.button.Button.component('menu-trigger').selected(true);
        assertTrue(selected.selectedValue);
        assertNull(selected.toggledValue);
        final selectedToggle = glaze.kit.button.Button.component('explicit-toggle').selected(true).toggled(true);
        assertTrue(selectedToggle.selectedValue);
        assertEquals(true, selectedToggle.toggledValue);
    }

    function testButtonLoadingIsNotInteractive() {
        assertTrue(glaze.kit.button.Button.component('test').interactive());
        assertFalse(glaze.kit.button.Button.component('test').loading(true).interactive());
        assertFalse(glaze.kit.button.Button.component('test').disabled(true).interactive());
        assertFalse(glaze.kit.button.Button.component('test').loading(true).disabled(true).interactive());
        assertFalse(glaze.kit.button.Button.component('test').loading(true).onHover((_, _, _) -> {}).hoverable());
    }

    function testButtonVariantMethods() {
        assertTrue(ButtonVariant.Link.isLink());
        assertTrue(ButtonVariant.Text.isText());
        assertTrue(ButtonVariant.Ghost.isGhost());
        assertTrue(ButtonVariant.Link.noPadding());
        assertTrue(ButtonVariant.Text.noPadding());
        assertFalse(ButtonVariant.Ghost.noPadding());
    }

    function testLinkButtonPrepaintsItsChild() {
        var bounds:Null<Bounds> = null;
        open((_, _) -> glaze.kit.button.Button.component('link-button').link().child(div().onPrepaint((b, _, _) -> bounds = b).child('Visible link button')));
        assertNotNull(bounds);
        assertTrue(bounds.size.width > 0);
        assertTrue(bounds.size.height > 0);
    }

    function testBaseSlotPrepaintsCompleteButtonContent() {
        var bounds:Null<Bounds> = null;
        open((_, _) -> div()
            .child(glaze.kit.button.Button.component('complete-button')
                .icon(IconName.Plus)
                .label('Create')
                .child(div().onPrepaint((b, _, _) -> bounds = b).child('Details'))
                .dropdownCaret(true))
            .child(glaze.kit.button.Button.component('loading-button')
                .icon(IconName.Plus)
                .loadingIcon(IconName.Loader)
                .loading(true)
                .label('Creating')
                .dropdownCaret(true)));
        assertNotNull(bounds);
        assertTrue(bounds.size.width > 0);
        assertTrue(bounds.size.height > 0);
    }

    function testOutlineSelectedUsesOutlineActiveStyle() {
        app.update(cx -> {
            final variant = ButtonVariant.Danger;
            final activeStyle = variant.active(true, cx);
            final selectedStyle = variant.selected(true, cx);
            assertTrue(selectedStyle.bg.equals(activeStyle.bg));
            assertTrue(selectedStyle.border.equals(activeStyle.border));
            assertTrue(selectedStyle.fg.equals(Theme.global(cx).danger));
            assertFalse(selectedStyle.bg.equals(Theme.global(cx).tokens.dangerActive.background));
        });
    }

    function applyConfig(json:String):Void {
        app.update(cx -> Theme.globalMut(cx).applyConfig(ThemeConfig.parse(json)));
    }

    function testPrimaryButtonUsesGradientBackgroundTokens() {
        applyConfig('{"name": "Gradient", "mode": "light", "colors": {
            "button.primary.background": "linear-gradient(135deg, #4F46E5, #06B6D4)",
            "button.primary.hover.background": "linear-gradient(145deg, #4338CA, #0891B2)",
            "button.primary.active.background": "linear-gradient(155deg, #3730A3, #0E7490)"}}');
        app.update(cx -> {
            final tokens = Theme.global(cx).tokens;
            assertTrue(ButtonVariant.Primary.normal(false, cx).bg.equals(tokens.buttonPrimary.background));
            assertTrue(ButtonVariant.Primary.hovered(false, cx).bg.equals(tokens.buttonPrimaryHover.background));
            assertTrue(ButtonVariant.Primary.active(false, cx).bg.equals(tokens.buttonPrimaryActive.background));
        });
    }

    function testOutlinePrimaryKeepsOriginalDepth() {
        applyConfig('{"name": "Outline Depth", "mode": "light", "colors": {
            "primary.background": "linear-gradient(180deg, #111827, #020617)",
            "primary.hover.background": "linear-gradient(180deg, #1F2937, #111827)",
            "primary.active.background": "linear-gradient(180deg, #020617, #000000)"}}');
        app.update(cx -> {
            final tokens = Theme.global(cx).tokens;
            assertTrue(ButtonVariant.Primary.normal(true, cx).bg.equals(tokens.primary.background.opacity(0.1)));
            assertTrue(ButtonVariant.Primary.hovered(true, cx).bg.equals(tokens.primaryHover.background.opacity(0.2)));
            assertTrue(ButtonVariant.Primary.active(true, cx).bg.equals(tokens.primaryActive.background.opacity(0.4)));
        });
    }

    function testOutlineButtonsUseSemanticGradientTokens() {
        applyConfig('{"name": "Outline Gradient", "mode": "light", "colors": {
            "primary.background": "linear-gradient(180deg, #111827, #020617)",
            "primary.hover.background": "linear-gradient(180deg, #1F2937, #111827)",
            "primary.active.background": "linear-gradient(180deg, #020617, #000000)",
            "button.primary.background": "linear-gradient(180deg, #FFFFFF, #E5E7EB)",
            "button.primary.hover.background": "linear-gradient(180deg, #F9FAFB, #E5E7EB)",
            "button.primary.active.background": "linear-gradient(180deg, #E5E7EB, #D1D5DB)",
            "danger.background": "linear-gradient(180deg, #EF4444, #DC2626)",
            "danger.hover.background": "linear-gradient(180deg, #F87171, #EF4444)",
            "danger.active.background": "linear-gradient(180deg, #DC2626, #B91C1C)",
            "button.danger.background": "linear-gradient(180deg, #FEF2F2, #FEE2E2)",
            "button.danger.hover.background": "linear-gradient(180deg, #FEE2E2, #FECACA)",
            "button.danger.active.background": "linear-gradient(180deg, #FECACA, #FCA5A5)"}}');
        app.update(cx -> {
            final tokens = Theme.global(cx).tokens;
            assertTrue(ButtonVariant.Primary.normal(true, cx).bg.equals(tokens.primary.background.opacity(0.1)));
            assertTrue(ButtonVariant.Danger.normal(true, cx).bg.equals(tokens.danger.background.opacity(0.1)));
            assertTrue(ButtonVariant.Danger.hovered(true, cx).bg.equals(tokens.dangerHover.background.opacity(0.2)));
            assertTrue(ButtonVariant.Danger.active(true, cx).bg.equals(tokens.dangerActive.background.opacity(0.4)));
            assertTrue(ButtonVariant.Primary.normal(false, cx).bg.equals(tokens.buttonPrimary.background));
            assertTrue(ButtonVariant.Danger.normal(false, cx).bg.equals(glaze.kit.theme.Color.tryParseBackground('linear-gradient(180deg, #FEF2F2, #FEE2E2)')));
        });
    }

    function testDisabledOutlineButtonsKeepSemanticBackgrounds() {
        applyConfig('{"name": "Disabled Outline Gradient", "mode": "light", "colors": {
            "primary.background": "linear-gradient(180deg, #111827, #020617)",
            "button.primary.background": "linear-gradient(180deg, #FFFFFF, #E5E7EB)",
            "danger.background": "linear-gradient(180deg, #EF4444, #DC2626)",
            "button.danger.background": "linear-gradient(180deg, #E5E7EB, #D1D5DB)"}}');
        app.update(cx -> {
            final theme = Theme.global(cx);
            final tokens = theme.tokens;
            assertTrue(ButtonVariant.Primary.disabled(true, cx).bg.equals(tokens.primary.background.opacity(0.1).opacity(0.5)));
            assertTrue(ButtonVariant.Danger.disabled(true, cx).bg.equals(tokens.danger.background.opacity(0.1).opacity(0.5)));
            assertFalse(ButtonVariant.Danger.disabled(true, cx).bg.equals(glaze.Background.fromHsla(theme.inputBackground().opacity(0.5))));
            assertFalse(ButtonVariant.Danger.disabled(true, cx).bg.equals(tokens.buttonDanger.background.opacity(0.15)));
        });
    }

    /// ButtonIcon

    function testButtonIconBuilder() {
        final icon = (IconName.Plus:IntoButtonIcon);
        final built = (icon:ButtonIcon).loading(true).loadingIcon(glaze.kit.Icon.component(IconName.Loader)).large();
        assertTrue(built.loadingValue);
        assertNotNull(built.loadingIconValue);
        assertTrue(built.size.equals(Large));
    }

    function testButtonIconVariantTypes() {
        assertFalse(ButtonIcon.isSpinner(ButtonIconVariant.Icon(glaze.kit.Icon.component(IconName.Plus))));
        assertTrue(ButtonIcon.isSpinner(ButtonIconVariant.Spinner(glaze.kit.spinner.Spinner.component())));
    }

    /// ButtonGroup

    function groupHarness(multiple:Bool, installGroupCallback:Bool):{cx:VisualTestContext, childClicks:Array<Int>, changes:Array<Array<Int>>} {
        final childClicks = [0];
        final changes:Array<Array<Int>> = [];
        final cx = open((_, _) -> {
            final group = ButtonGroup.component('group')
                .multiple(multiple)
                .size(px(120.))
                .child(glaze.kit.button.Button.component('one').label('One').onClick((_, _, _) -> childClicks[0]++))
                .child(glaze.kit.button.Button.component('two').label('Two').selected(true));
            if (installGroupCallback) group.onClick((next, _, _) -> changes.push(next.copy()));
            return group;
        });
        return {cx: cx, childClicks: childClicks, changes: changes};
    }

    function testLegacyGroupCallbackOverridesTheChildCallback() {
        final h = groupHarness(false, true);
        click(h.cx, 10, 60);
        assertEquals(0, h.childClicks[0]);
        assertEquals('[[0]]', Std.string(h.changes));
    }

    function testLegacyChildCallbackSurvivesWithoutAGroupCallback() {
        final h = groupHarness(false, false);
        click(h.cx, 10, 60);
        assertEquals(1, h.childClicks[0]);
        assertEquals(0, h.changes.length);
    }

    function testLegacySingleAndMultipleResultsUseTheRenderedSelection() {
        final single = groupHarness(false, true);
        click(single.cx, 10, 60);
        assertEquals('[[0]]', Std.string(single.changes));
        final multiple = groupHarness(true, true);
        click(multiple.cx, 10, 60);
        assertEquals('[[1,0]]', Std.string(multiple.changes));
    }

    function testLegacyKeyboardClickDoesNotReachTheGroupCallback() {
        final h = groupHarness(false, true);
        h.cx.update((window, app) -> window.focusNext(app));
        activateKey(h.cx, 'enter');
        assertEquals(0, h.changes.length);
    }

    function testLegacyDisabledStateDependsOnBuilderOrder() {
        final clicks = [0];
        final cx = open((_, _) -> vFlex()
            .child(ButtonGroup.component('disabled-before-child')
                .size(px(120.))
                .disabled(true)
                .child(glaze.kit.button.Button.component('first').label('First').onClick((_, _, _) -> clicks[0]++)))
            .child(ButtonGroup.component('disabled-after-child')
                .size(px(120.))
                .child(glaze.kit.button.Button.component('second').label('Second').onClick((_, _, _) -> clicks[0]++))
                .disabled(true)));
        click(cx, 10, 60);
        assertEquals(0, clicks[0]);
        click(cx, 10, 180);
        assertEquals(1, clicks[0]);
    }

    function testButtonGroupBuilder() {
        final group = ButtonGroup.component('complex-group')
            .child(glaze.kit.button.Button.component('btn1').label('One'))
            .child(glaze.kit.button.Button.component('btn2').label('Two'))
            .child(glaze.kit.button.Button.component('btn3').label('Three'))
            .primary()
            .large()
            .outline()
            .compact()
            .multiple(true)
            .layout(Vertical)
            .disabled(false)
            .onClick((_, _, _) -> {});
        assertEquals(3, group.childButtons.length);
        assertTrue(group.variantValue.equals(Primary));
        assertTrue(group.sizeValue.equals(Large));
        assertTrue(group.outlineValue);
        assertTrue(group.compactValue);
        assertTrue(group.multipleValue);
        assertTrue(group.layoutValue == Vertical);
        assertFalse(group.disabledValue);
        assertNotNull(group.onClickHandler);
    }

    /// Toggle

    function toggleHarness(disabled:Bool):{cx:VisualTestContext, changes:Array<Bool>, parent:Array<Int>} {
        final changes:Array<Bool> = [];
        final parent = [0];
        final cx = open((_, _) -> hFlex()
            .id('toggle-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> parent[0]++)
            .child(Toggle.component('toggle').label('Bold').disabled(disabled).sizeFull().onClick((next, _, _) -> changes.push(next))));
        return {cx: cx, changes: changes, parent: parent};
    }

    function testCanonicalPointerActivationFiresOnceAndFocuses() {
        final h = toggleHarness(false);
        click(h.cx);
        assertEquals('[true]', Std.string(h.changes));
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
    }

    function testCanonicalToggleSupportsTabEnterAndSpace() {
        final h = toggleHarness(false);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
        activateKey(h.cx, 'enter');
        activateKey(h.cx, 'space');
        assertEquals('[true,true]', Std.string(h.changes));
    }

    function testCanonicalDisabledToggleIsInertAndBlocksParent() {
        final h = toggleHarness(true);
        click(h.cx);
        assertEquals(0, h.changes.length);
        assertEquals(0, h.parent[0]);
    }

    function toggleGroupHarness(installGroupCallback:Bool):{cx:VisualTestContext, childClicks:Array<Int>, changes:Array<Array<Bool>>} {
        final childClicks = [0];
        final changes:Array<Array<Bool>> = [];
        final cx = open((_, _) -> {
            final group = ToggleGroup.component('toggle-group')
                .w(px(120.))
                .child(Toggle.component('one').label('One').checked(true).onClick((_, _, _) -> childClicks[0]++))
                .child(Toggle.component('two').label('Two'));
            if (installGroupCallback) group.onClick((next, _, _) -> changes.push(next.copy()));
            return group;
        });
        return {cx: cx, childClicks: childClicks, changes: changes};
    }

    function testLegacyToggleGroupOverridesChildCallbackEvenWithoutGroupCallback() {
        final h = toggleGroupHarness(false);
        click(h.cx);
        assertEquals(0, h.childClicks[0]);
        assertEquals(0, h.changes.length);
    }

    function testLegacyToggleGroupPointerFlipsOnlyTheClickedRenderedValue() {
        final h = toggleGroupHarness(true);
        click(h.cx);
        assertEquals(0, h.childClicks[0]);
        assertEquals('[[false,false]]', Std.string(h.changes));
    }

    function testLegacyToggleGroupKeyboardClickDoesNotReachTheGroupCallback() {
        final h = toggleGroupHarness(true);
        h.cx.update((window, app) -> window.focusNext(app));
        activateKey(h.cx, 'enter');
        assertEquals(0, h.childClicks[0]);
        assertEquals(0, h.changes.length);
    }

    function testInstanceStyleRemainsTheFinalVisualOverride() {
        final toggle = Toggle.component('styled').checked(true).opacity(0.37);
        assertEquals(0.37, toggle.toggleStyle.opacity);
    }

    function testToggleBuilder() {
        final toggle = Toggle.component('complex-toggle')
            .label('Enable Feature')
            .icon(IconName.Check)
            .checked(true)
            .outline()
            .large()
            .disabled(false)
            .onClick((_, _, _) -> {});
        assertEquals(2, toggle.childElements.length);
        assertTrue(toggle.checkedValue);
        assertTrue(toggle.variantValue == Outline);
        assertTrue(toggle.sizeValue.equals(Large));
        assertFalse(toggle.disabledValue);
        assertNotNull(toggle.onClickHandler);
    }

    function testToggleGroupBuilder() {
        final group = ToggleGroup.component('complex-group')
            .child(Toggle.component('toggle1').label('Option 1'))
            .child(Toggle.component('toggle2').label('Option 2').checked(true))
            .child(Toggle.component('toggle3').label('Option 3'))
            .outline()
            .large()
            .segmented()
            .disabled(false)
            .onClick((_, _, _) -> {});
        assertEquals(3, group.items.length);
        assertTrue(group.variantValue == Outline);
        assertTrue(group.sizeValue.equals(Large));
        assertTrue(group.segmentedValue);
        assertFalse(group.disabledValue);
        assertNotNull(group.onClickHandler);
    }

    /// Checkbox

    function testCheckboxExplicitAccessibilityLabelReplacesTheVisibleOne() {
        final plain = Checkbox.component('remember').label('Remember me');
        assertNull(plain.accessibilityLabelValue);
        final named = Checkbox.component('remember').label('Remember me').accessibilityLabel('Remember this account');
        assertEquals('Remember this account', named.accessibilityLabelValue);
        assertEquals('Remember me', named.labelValue);
    }

    function checkboxHarness(disabled:Bool):{cx:VisualTestContext, clicks:Array<Int>, parent:Array<Int>} {
        final clicks = [0];
        final parent = [0];
        final cx = open((_, _) -> div()
            .id('checkbox-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> parent[0]++)
            .child(Checkbox.component('checkbox').disabled(disabled).sizeFull().onClick((checked, _, _) -> {
                assertTrue(checked);
                clicks[0]++;
            })));
        return {cx: cx, clicks: clicks, parent: parent};
    }

    function testFacadePointerActivationFiresOnceWithoutMovingFocus() {
        final h = checkboxHarness(false);
        click(h.cx);
        assertEquals(1, h.clicks[0]);
        h.cx.update((window, app) -> assertNull(window.focused(app)));
    }

    function testFacadeSupportsTabEnterAndSpace() {
        final h = checkboxHarness(false);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
        activateKey(h.cx, 'enter');
        activateKey(h.cx, 'space');
        assertEquals(2, h.clicks[0]);
    }

    function testFacadeDisabledIsInertAndPointerActivationBubbles() {
        final h = checkboxHarness(true);
        click(h.cx);
        assertEquals(0, h.clicks[0]);
        assertEquals(1, h.parent[0]);
        h.cx.update((window, app) -> assertNull(window.focused(app)));
    }

    function testFacadePrepaintsLabelAndCustomContentThroughTheBaseSlot() {
        var bounds:Null<Bounds> = null;
        open((_, _) -> Checkbox.component('content-checkbox').label('Remember me').child(div().onPrepaint((b, _, _) -> bounds = b).child('Additional detail')));
        assertNotNull(bounds);
        assertTrue(bounds.size.width > 0);
        assertTrue(bounds.size.height > 0);
    }

    function testTheCheckMarkAsksTheIconResolverForItsPath() {
        final asked:Array<String> = [];
        app.update(cx -> {
            cx.setReduceMotion(true);
            glaze.kit.Icon.setIconResolver(cx, (path, _) -> {
                asked.push(path);
                return null;
            });
        });
        open((_, _) -> Checkbox.component('checked').checked(true));
        assertTrue(asked.indexOf(IconName.Check.path()) >= 0, 'the check mark must be drawn from the resolved path');
    }

    /// Radio

    function testRadioExplicitAccessibilityLabelReplacesTheVisibleOne() {
        final plain = Radio.component('automatic').label('Automatic');
        assertNull(plain.accessibilityLabelValue);
        assertEquals('Automatic', plain.labelValue);
        final named = Radio.component('automatic').label('Automatic').accessibilityLabel('Choose automatic mode');
        assertEquals('Choose automatic mode', named.accessibilityLabelValue);
        assertEquals('Automatic', named.labelValue);
    }

    /// Switch

    function testSwitchExplicitAccessibilityLabelReplacesTheVisibleOne() {
        final plain = glaze.kit.switch_.Switch.component('wifi').label('Wi-Fi');
        assertNull(plain.accessibilityLabelProp);
        assertEquals('Wi-Fi', plain.labelProp);
        final named = glaze.kit.switch_.Switch.component('wifi').label('Wi-Fi').accessibilityLabel('Toggle Wi-Fi');
        assertEquals('Toggle Wi-Fi', named.accessibilityLabelProp);
        assertEquals('Wi-Fi', named.labelProp);
    }

    function switchHarness(disabled:Bool):{cx:VisualTestContext, toggles:Array<Int>, parent:Array<Int>} {
        final toggles = [0];
        final parent = [0];
        final cx = open((_, _) -> div()
            .id('switch-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> parent[0]++)
            .child(glaze.kit.switch_.Switch.component('switch').disabled(disabled).onClick((checked, _, _) -> {
                assertTrue(checked);
                toggles[0]++;
            })));
        return {cx: cx, toggles: toggles, parent: parent};
    }

    function testCanonicalSwitchPointerActivationFiresOnceAndFocuses() {
        final h = switchHarness(false);
        click(h.cx);
        assertEquals(1, h.toggles[0]);
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
    }

    function testCanonicalSwitchSupportsTabEnterAndSpace() {
        final h = switchHarness(false);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
        activateKey(h.cx, 'enter');
        activateKey(h.cx, 'space');
        assertEquals(2, h.toggles[0]);
    }

    function testCanonicalDisabledSwitchIsInertAndBlocksParent() {
        final h = switchHarness(true);
        click(h.cx);
        assertEquals(0, h.toggles[0]);
        assertEquals(0, h.parent[0]);
        h.cx.update((window, app) -> assertNull(window.focused(app)));
    }

    function testDisabledSwitchTakesNoFocus() {
        final cx = open((_, _) -> div().id('switch-parent').tabGroup().size(px(100.)).child(glaze.kit.switch_.Switch.component('switch').label('Airplane mode').disabled(true)));
        cx.update((window, app) -> window.focusNext(app));
        cx.update((window, app) -> assertNull(window.focused(app)));
    }

    /// Slider

    function sliderHarness(disabled:Bool):{cx:VisualTestContext, state:Entity<SliderState>} {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState());
        final cx = open((_, _) -> div().w(px(100.)).h(px(24.)).child(glaze.kit.slider.Slider.component(state).disabled(disabled)));
        return {cx: cx, state: state};
    }

    function testPointerUpdatesTheMigratedState() {
        final h = sliderHarness(false);
        click(h.cx, 50, 12);
        h.cx.update((_, app) -> assertTrue(Math.abs(h.state.read(app).value().end() - 50.) < 1.));
    }

    function testDisabledSliderIsInert() {
        final h = sliderHarness(true);
        click(h.cx, 50, 12);
        h.cx.update((_, app) -> assertTrue(h.state.read(app).value().equals(Single(0.))));
    }

    /// Toolbar

    function testToolbarBuilder() {
        final toolbar = glaze.kit.toolbar.Toolbar.component('toolbar').content('New').content('Open').content('Settings').small();
        assertEquals(3, toolbar.items.length);
        assertTrue(toolbar.sizeValue.equals(Small));
    }

    function testToolbarDefault() {
        final toolbar = glaze.kit.toolbar.Toolbar.component('toolbar');
        assertTrue(toolbar.sizeValue.equals(Small));
        assertFalse(toolbar.disabledValue);
        assertEquals(0, toolbar.items.length);
    }

    function testLargeSizeFallsBackToMedium() {
        assertTrue(glaze.kit.toolbar.Toolbar.component('toolbar').large().sizeValue.equals(Medium));
        assertTrue(new glaze.kit.toolbar.Toolbar.ToolbarGroup('group').large().sizeValue.equals(Medium));
    }

    function testToolbarPreparesButtonsAsCompactGhostCommands() {
        final button = glaze.kit.button.Button.component('command').prepareForToolbar();
        assertTrue(button.variant().equals(Ghost));
        assertTrue(button.isCompact());
    }

    function testToolbarSizePropagatesToItemsIndependentOfBuilderOrder() {
        final observed:Array<Null<Size>> = [null, null, null];
        open((_, _) -> glaze.kit.toolbar.Toolbar.component('toolbar').children([for (i in 0...3) SizeProbe.component(observed, i)]).small());
        for (size in observed) assertTrue(size != null && size.equals(Small));
    }

    function testToolbarGroupPropagatesItsSizeToItems() {
        final observed:Array<Null<Size>> = [null];
        open((_, _) -> new glaze.kit.toolbar.Toolbar.ToolbarGroup('group').child(SizeProbe.component(observed, 0)).small());
        assertTrue(observed[0] != null && observed[0].equals(Small));
    }

    /// Integration steps (crates/kit/tests/integration)

    /**
     * `control_steps.rs`: a pointer release outside the button cancels the
     * activation, the next click recovers.
     */
    function testButtonPointerReleaseOutsideCancelsActivationAndNextClickRecovers() {
        final controls = new Controls();
        final cx = open((_, cx) -> controls.render(cx), 400, 300);
        final inside = controls.bounds.get('save').center();
        final outside = controls.bounds.get('notifications').center();
        cx.simulateEvent(new MouseDownEvent(Left, inside, Modifiers.none(), 1, false));
        assertEquals(0, controls.buttonClicks);
        cx.simulateEvent(new MouseMoveEvent(outside, Left, Modifiers.none()));
        cx.simulateEvent(new MouseUpEvent(Left, outside, Modifiers.none(), 1));
        assertEquals(0, controls.buttonClicks);
        final inside = controls.bounds.get('save').center();
        cx.simulateEvent(new MouseDownEvent(Left, inside, Modifiers.none(), 1, false));
        assertEquals(0, controls.buttonClicks);
        cx.simulateEvent(new MouseUpEvent(Left, inside, Modifiers.none(), 1));
        assertEquals(1, controls.buttonClicks);
    }

    /**
     * `control_steps.rs`: a held space repeats, but the checkbox changes its
     * controlled value once, on release.
     */
    function testCheckboxSpaceRepeatChangesControlledValueOnceOnRelease() {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final controls = new Controls();
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> {
            final content = rootCx.newEntity((_:Context<ScriptView>) -> new ScriptView((_, cx) -> controls.render(cx)));
            return content;
        });
        final cx = opened.cx;
        contexts.push(cx);
        cx.update((window, app) -> {
            window.setActive(true);
            window.draw();
            window.focusNext(app);
            window.draw();
        });
        activateKey(cx, 'tab');
        final space = Keystroke.parse('space');
        cx.simulateEvent(new KeyDownEvent(space, false, false));
        cx.simulateEvent(new KeyDownEvent(space, true, false));
        cx.simulateEvent(new KeyDownEvent(space, true, false));
        assertEquals(0, controls.changes.length);
        cx.simulateEvent(new KeyUpEvent(space));
        assertEquals('[true]', Std.string(controls.changes));
        cx.simulateEvent(new KeyUpEvent(space));
        assertEquals('[true]', Std.string(controls.changes));
        cx.simulateEvent(new KeyDownEvent(space, false, false));
        cx.simulateEvent(new KeyUpEvent(space));
        assertEquals('[true,false]', Std.string(controls.changes));
    }

    /**
     * `control_steps.rs`: a switch disabled between the key down and the key
     * up of space cannot request a value.
     */
    function testSwitchDisabledBeforeKeyboardReleaseCannotRequestAValue() {
        final controls = new Controls();
        final cx = open((_, cx) -> controls.render(cx), 1920, 1080);
        click(cx, controls.bounds.get('notifications').center().x, controls.bounds.get('notifications').center().y);
        assertEquals('[true]', Std.string(controls.changes));
        final space = Keystroke.parse('space');
        cx.simulateEvent(new KeyDownEvent(space, false, false));
        assertEquals('[true]', Std.string(controls.changes));
        controls.disabled = true;
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        cx.simulateEvent(new KeyUpEvent(space));
        assertEquals('[true]', Std.string(controls.changes));
        controls.disabled = false;
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        cx.simulateEvent(new KeyDownEvent(space, false, false));
        cx.simulateEvent(new KeyUpEvent(space));
        assertEquals('[true,false]', Std.string(controls.changes));
    }

    function recordSlider(state:Entity<SliderState>):Array<String> {
        final events:Array<String> = [];
        app.subscribe(state, SliderEvent, (_, event, _) -> events.push(switch event {
            case Change(value): 'change ' + value.toDisplayString();
            case Release(value): 'release ' + value.toDisplayString();
        }));
        return events;
    }

    function volume(state:Entity<SliderState>, disabled:Bool, track:Array<Bounds>):VisualTestContext {
        return open((_, _) -> div().p8().w(px(264.)).child(div().onPrepaint((b, _, _) -> track[0] = b).child(glaze.kit.slider.Slider.component(state).disabled(disabled))), 400, 240);
    }

    /**
     * `slider_steps.rs`: a press on the track changes the value before the
     * release, which is reported once.
     */
    function testSliderTrackChangesBeforeReleaseAndReleasesOnlyOnce() {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState().step(10.).defaultValue(10.));
        final events = recordSlider(state);
        final track:Array<Bounds> = [null];
        final cx = volume(state, false, track);
        final position = new Point(track[0].left() + track[0].size.width * 0.6, track[0].center().y);
        cx.simulateMouseMove(position);
        cx.simulateMouseDown(position, Left);
        assertTrue(state.read(app).value().equals(Single(60.)));
        assertEquals('change 60', events.join(', '));
        cx.simulateMouseUp(position, Left);
        cx.simulateMouseUp(position, Left);
        assertEquals('change 60, release 60', events.join(', '));
    }

    /**
     * `slider_steps.rs`: dragging the thumb updates the value live and stops
     * after the release.
     */
    function testSliderThumbDragUpdatesLiveAndStopsAfterRelease() {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState().step(10.).defaultValue(20.));
        final events = recordSlider(state);
        final track:Array<Bounds> = [null];
        final cx = volume(state, false, track);
        // The thumb is centered on the value (20%) of the track.
        final thumb = new Point(track[0].left() + track[0].size.width * 0.2, track[0].center().y);
        final destination = new Point(track[0].left() + track[0].size.width * 0.8, track[0].center().y);
        cx.simulateMouseMove(thumb);
        cx.simulateMouseDown(thumb, Left);
        assertTrue(state.read(app).value().equals(Single(20.)));
        cx.simulateMouseMove(destination, Left);
        // The first motion starts the native drag; the next dispatch moves it.
        cx.simulateMouseMove(destination, Left);
        assertTrue(state.read(app).value().equals(Single(80.)));
        assertTrue(events.length > 0);
        for (event in events) assertTrue(StringTools.startsWith(event, 'change'));
        assertEquals('change 80', events[events.length - 1]);
        events.resize(0);
        cx.simulateMouseUp(destination, Left);
        cx.simulateMouseMove(new Point(360, 180));
        assertTrue(state.read(app).value().equals(Single(80.)));
        assertEquals('release 80', events.join(', '));
    }

    /** `touch_drag` (integration/disclosure.rs): a finger drag reaches elements as `TouchDragEvent`s. */
    static function touchDrag(cx:VisualTestContext, from:Point, to:Point):Void {
        cx.update((window, app) -> {
            window.dispatchEvent(new glaze.TouchDragEvent(Started, from, from), app);
            window.dispatchEvent(new glaze.TouchDragEvent(Moved, from, to), app);
            window.dispatchEvent(new glaze.TouchDragEvent(Ended, from, to), app);
            window.refresh();
            window.draw();
        });
    }

    /**
     * `slider_touch_drag_moves_the_actual_thumb` (integration/disclosure.rs),
     * read on the value: the thumb follows a touch drag both ways.
     */
    function testSliderTouchDragMovesTheActualThumb() {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState().defaultValue(20.));
        final track:Array<Bounds> = [null];
        final cx = volume(state, false, track);
        final thumb = new Point(track[0].left() + track[0].size.width * 0.2, track[0].center().y);
        final right = new Point(track[0].left() + track[0].size.width * 0.8, track[0].center().y);
        touchDrag(cx, thumb, right);
        final after = state.read(app).value().end();
        assertTrue(after > 20., 'moved right to $after');
        final left = new Point(track[0].left() + track[0].size.width * 0.3, track[0].center().y);
        touchDrag(cx, right, left);
        assertTrue(state.read(app).value().end() < after);
    }

    /**
     * `slider_drops_a_touch_drag_whose_end_never_arrived`
     * (integration/disclosure.rs): disabled mid-drag, the slider never sees
     * the end; a later drag another element claimed must not move it.
     */
    function testSliderDropsATouchDragWhoseEndNeverArrived() {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState().defaultValue(20.));
        final track:Array<Bounds> = [null];
        final disabled = [false];
        final cx = open((_, _) -> div().p8().w(px(264.)).child(div().onPrepaint((b, _, _) -> track[0] = b).child(glaze.kit.slider.Slider.component(state).disabled(disabled[0]))), 400, 240);
        final thumb = new Point(track[0].left() + track[0].size.width * 0.2, track[0].center().y);
        function dispatch(phase:glaze.TouchPhase, from:Point, to:Point) {
            cx.update((window, app) -> {
                window.dispatchEvent(new glaze.TouchDragEvent(phase, from, to), app);
                window.refresh();
                window.draw();
            });
        }
        function setDisabled(value:Bool) {
            disabled[0] = value;
            cx.update((window, _) -> {
                window.refresh();
                window.draw();
            });
        }
        dispatch(Started, thumb, thumb);
        setDisabled(true);
        dispatch(Ended, thumb, thumb);
        setDisabled(false);

        final before = state.read(app).value().end();
        final elsewhere = new Point(track[0].left(), track[0].bottom() + 200.);
        dispatch(Moved, elsewhere, new Point(track[0].right(), track[0].center().y));
        assertEquals(before, state.read(app).value().end());
    }

    /**
     * `disabled_slider_ignores_pointer_changes` (integration/disclosure.rs),
     * its touch drag.
     */
    function testDisabledSliderIgnoresTouchDrags() {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState().defaultValue(20.));
        final track:Array<Bounds> = [null];
        final cx = volume(state, true, track);
        final thumb = new Point(track[0].left() + track[0].size.width * 0.2, track[0].center().y);
        touchDrag(cx, thumb, new Point(track[0].right(), track[0].center().y));
        assertEquals(20., state.read(app).value().end());
    }

    /**
     * `slider_steps.rs`: a disabled slider's gesture neither changes the
     * value nor emits events.
     */
    function testDisabledSliderGestureNeitherChangesValueNorEmitsEvents() {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState().defaultValue(20.));
        final events = recordSlider(state);
        final track:Array<Bounds> = [null];
        final cx = volume(state, true, track);
        final start = new Point(track[0].left() + track[0].size.width * 0.4, track[0].center().y);
        final end = new Point(track[0].left() + track[0].size.width * 0.8, track[0].center().y);
        cx.simulateMouseMove(start);
        cx.simulateMouseDown(start, Left);
        cx.simulateMouseMove(end, Left);
        cx.simulateMouseMove(end, Left);
        cx.simulateMouseUp(end, Left);
        assertTrue(state.read(app).value().equals(Single(20.)));
        assertEquals(0, events.length);
    }

    /**
     * `semantic_controls.rs`: radio groups follow the controlled selection,
     * re-activating the current choice requests nothing, and disabled items
     * and groups are inert.
     */
    function testScopedRadioActivationRespectsItemAndGroupDisabledStates() {
        final prefs = new DeliveryPreferences();
        prefs.billingDisabled = true;
        final cx = open((_, cx) -> prefs.render(cx), 400, 400);
        // Shipping: overnight is disabled. Billing: the whole group is disabled.
        click(cx, prefs.bounds.get('shipping-2').center().x, prefs.bounds.get('shipping-2').center().y);
        click(cx, prefs.bounds.get('billing-1').center().x, prefs.bounds.get('billing-1').center().y);
        assertEquals(0, prefs.changes.length);
        prefs.billingDisabled = false;
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        click(cx, prefs.bounds.get('billing-1').center().x, prefs.bounds.get('billing-1').center().y);
        assertEquals('[1-1]', Std.string(prefs.changes));
        // Re-activating the current choice must not request another change.
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        click(cx, prefs.bounds.get('billing-1').center().x, prefs.bounds.get('billing-1').center().y);
        click(cx, prefs.bounds.get('shipping-1').center().x, prefs.bounds.get('shipping-1').center().y);
        assertEquals('[1-1,0-1]', Std.string(prefs.changes));
    }

}

/**
 * The view of `control_steps.rs`, with the bounds of each control probed.
 */
private class Controls {

    public var buttonClicks:Int = 0;

    public var checked:Bool = false;

    public final changes:Array<Bool> = [];

    public var disabled:Bool = false;

    public final bounds:Map<String, Bounds> = [];

    public function new() {}

    function probe(name:String, element:IntoElement):IntoElement {
        return div().onPrepaint((b, _, _) -> bounds.set(name, b)).child(element);
    }

    public function render(cx:Context<Dynamic>):IntoElement {
        return div()
            .id('controls')
            .tabGroup()
            .sizeFull()
            .flex()
            .flexCol()
            .gap4()
            .child(probe('save', glaze.kit.button.Button.component('save').label('Save').onClick((_, _, _) -> buttonClicks++)))
            .child(probe('remember', Checkbox.component('remember').label('Remember account').checked(checked).onChange((next, _, _) -> {
                changes.push(next);
                checked = next;
                cx.notify();
            })))
            .child(probe('notifications', glaze.kit.switch_.Switch.component('notifications').label('Notifications').checked(checked).disabled(disabled).onChange((next, _, _) -> {
                changes.push(next);
                checked = next;
                cx.notify();
            })));
    }

}

/**
 * The view of `semantic_controls.rs`, with the bounds of each radio probed.
 */
private class DeliveryPreferences {

    public final selected:Array<Null<Int>> = [0, 0];

    public final changes:Array<String> = [];

    public var billingDisabled:Bool = false;

    public final bounds:Map<String, Bounds> = [];

    public function new() {}

    public function render(cx:Context<Dynamic>):IntoElement {
        final column = div().flex().flexCol().gap4();
        for (group in 0...2) {
            final id = group == 0 ? 'shipping' : 'billing';
            final probe = (ix:Int) -> div().h(px(2.)).onPrepaint((b, _, _) -> bounds.set('$id-$ix', b));
            column.child(glaze.kit.radio.Radio.RadioGroup.vertical(id)
                .selectedIndex(selected[group])
                .disabled(group == 1 && billingDisabled)
                .child(Radio.component('standard').label('Standard').child(probe(0)))
                .child(Radio.component('express').label('Express').accessibilityLabel('Express delivery').child(probe(1)))
                .child(Radio.component('overnight').label('Overnight').disabled(true).child(probe(2)))
                .onChange((index, _, _) -> {
                    selected[group] = index;
                    changes.push('$group-$index');
                    cx.notify();
                }));
        }
        return column;
    }

}
