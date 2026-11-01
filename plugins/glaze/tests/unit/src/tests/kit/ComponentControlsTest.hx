// Ported from gpui-kit 0.8.1: crates/component/src/button/{button,button_icon,button_group,toggle}.rs,
// checkbox.rs, radio.rs, switch.rs, slider.rs and toolbar.rs (tests), and the control parts of
// crates/kit/tests/integration/{control_steps,slider_steps,semantic_controls,controls,interactions}.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyDownEvent;
import gpui.KeyUpEvent;
import gpui.Keystroke;
import gpui.Model;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.Modifiers;
import gpui.Point;
import gpui.Render;
import gpui.RenderOnce;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Slider.SliderEvent;
import gpui.base.Slider.SliderState;
import gpui.base.Slider.SliderValue;
import gpui.component.Component;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.button.Button;
import gpui.component.button.ButtonGroup;
import gpui.component.button.ButtonIcon;
import gpui.component.button.Toggle;
import gpui.component.checkbox.Checkbox;
import gpui.component.radio.Radio;
import gpui.component.slider.Slider;
import gpui.component.spinner.Spinner;
import gpui.component.switch_.Switch;
import gpui.component.theme.Theme;
import gpui.component.theme.ThemeConfig;
import gpui.component.toolbar.Toolbar;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.ClickEvent.ClickEventTools;
using gpui.base.ElementExt;
using gpui.base.Slider.SliderValueTools;
using gpui.component.Size.SizeTools;

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
        app.update(cx -> Component.init(cx));
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
        final plain = new Button('save').label('Save');
        assertNull(plain.accessibilityLabelValue);
        assertEquals('Save', plain.labelValue);
        final named = new Button('row').label('Save').accessibilityLabel('Save the current document');
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
        final h = pointerHarness(counts -> new Button('disabled-legacy').disabled(true).onClick((_, _, _) -> counts[0]++));
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.counts[0]);
        assertEquals(0, h.counts[1]);
        h.cx.update((window, app) -> assertNull(window.focused(app)));
    }

    function testEnabledButtonDelegatesPointerEnterAndSpaceOnce() {
        final h = pointerHarness(counts -> new Button('enabled-legacy').onClick((event, _, _) -> {
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
        final cx = open((_, _) -> div().size(px(100.)).child(new Button('details').label('Details').trackFocus(focusHandle).onClick((_, _, _) -> clicks[0]++)));
        cx.update((window, app) -> {
            focusHandle.focus(window, app);
            window.draw();
        });
        cx.update((window, _) -> assertTrue(focusHandle.isFocused(window)));
        activateKey(cx, 'enter');
        assertEquals(1, clicks[0]);
    }

    function testLoadingButtonKeepsExistingPointerBlocking() {
        final h = pointerHarness(counts -> new Button('loading-legacy').loading(true).onClick((_, _, _) -> counts[0]++));
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.counts[0]);
        assertEquals(0, h.counts[1]);
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
    }

    function testLoadingButtonWithoutCallbackStillBlocksParentActivation() {
        final h = pointerHarness(_ -> new Button('loading-without-callback').loading(true));
        click(h.cx);
        h.cx.update((window, app) -> window.focusNext(app));
        h.cx.simulateKeystrokes('enter space');
        assertEquals(0, h.counts[1]);
        h.cx.update((window, app) -> assertNotNull(window.focused(app)));
    }

    function testBaseActivationIsPreservedAndBlockedWhileLoading() {
        final clicks = [0];
        final loading = [false];
        final cx = open((_, _) -> div().tabGroup().child(new Button('close')
            .withBase(new gpui.base.Button('close').onClick((_, _, _) -> clicks[0]++))
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
        final button = new Button('complex-button')
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
        final open = new Button('trigger').open(true);
        assertTrue(open.isOpen());
        assertFalse(open.isSelected());
        assertTrue(open.showsSelectedStyle());
        final selected = new Button('trigger').selected(true);
        assertTrue(selected.isSelected());
        assertFalse(selected.isOpen());
        assertTrue(selected.showsSelectedStyle());
        assertFalse(new Button('trigger').showsSelectedStyle());
    }

    function testSelectedTriggerPresentationDoesNotImplyToggledAccessibility() {
        final selected = new Button('menu-trigger').selected(true);
        assertTrue(selected.selectedValue);
        assertNull(selected.toggledValue);
        final selectedToggle = new Button('explicit-toggle').selected(true).toggled(true);
        assertTrue(selectedToggle.selectedValue);
        assertEquals(true, selectedToggle.toggledValue);
    }

    function testButtonLoadingIsNotInteractive() {
        assertTrue(new Button('test').interactive());
        assertFalse(new Button('test').loading(true).interactive());
        assertFalse(new Button('test').disabled(true).interactive());
        assertFalse(new Button('test').loading(true).disabled(true).interactive());
        assertFalse(new Button('test').loading(true).onHover((_, _, _) -> {}).hoverable());
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
        open((_, _) -> new Button('link-button').link().child(div().onPrepaint((b, _, _) -> bounds = b).child('Visible link button')));
        assertNotNull(bounds);
        assertTrue(bounds.size.width > 0);
        assertTrue(bounds.size.height > 0);
    }

    function testBaseSlotPrepaintsCompleteButtonContent() {
        var bounds:Null<Bounds> = null;
        open((_, _) -> div()
            .child(new Button('complete-button')
                .icon(IconName.Plus)
                .label('Create')
                .child(div().onPrepaint((b, _, _) -> bounds = b).child('Details'))
                .dropdownCaret(true))
            .child(new Button('loading-button')
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
            assertTrue(ButtonVariant.Danger.normal(false, cx).bg.equals(gpui.component.theme.Color.tryParseBackground('linear-gradient(180deg, #FEF2F2, #FEE2E2)')));
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
            assertFalse(ButtonVariant.Danger.disabled(true, cx).bg.equals(gpui.Background.fromHsla(theme.inputBackground().opacity(0.5))));
            assertFalse(ButtonVariant.Danger.disabled(true, cx).bg.equals(tokens.buttonDanger.background.opacity(0.15)));
        });
    }

    /// ButtonIcon

    function testButtonIconBuilder() {
        final icon = (IconName.Plus:IntoButtonIcon);
        final built = (icon:ButtonIcon).loading(true).loadingIcon(new gpui.component.Icon(IconName.Loader)).large();
        assertTrue(built.loadingValue);
        assertNotNull(built.loadingIconValue);
        assertTrue(built.size.equals(Large));
    }

    function testButtonIconVariantTypes() {
        assertFalse(ButtonIcon.isSpinner(ButtonIconVariant.Icon(new gpui.component.Icon(IconName.Plus))));
        assertTrue(ButtonIcon.isSpinner(ButtonIconVariant.Spinner(new gpui.component.spinner.Spinner())));
    }

    /// ButtonGroup

    function groupHarness(multiple:Bool, installGroupCallback:Bool):{cx:VisualTestContext, childClicks:Array<Int>, changes:Array<Array<Int>>} {
        final childClicks = [0];
        final changes:Array<Array<Int>> = [];
        final cx = open((_, _) -> {
            final group = new ButtonGroup('group')
                .multiple(multiple)
                .size(px(120.))
                .child(new Button('one').label('One').onClick((_, _, _) -> childClicks[0]++))
                .child(new Button('two').label('Two').selected(true));
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
            .child(new ButtonGroup('disabled-before-child')
                .size(px(120.))
                .disabled(true)
                .child(new Button('first').label('First').onClick((_, _, _) -> clicks[0]++)))
            .child(new ButtonGroup('disabled-after-child')
                .size(px(120.))
                .child(new Button('second').label('Second').onClick((_, _, _) -> clicks[0]++))
                .disabled(true)));
        click(cx, 10, 60);
        assertEquals(0, clicks[0]);
        click(cx, 10, 180);
        assertEquals(1, clicks[0]);
    }

    function testButtonGroupBuilder() {
        final group = new ButtonGroup('complex-group')
            .child(new Button('btn1').label('One'))
            .child(new Button('btn2').label('Two'))
            .child(new Button('btn3').label('Three'))
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
            .child(new Toggle('toggle').label('Bold').disabled(disabled).sizeFull().onClick((next, _, _) -> changes.push(next))));
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
            final group = new ToggleGroup('toggle-group')
                .w(px(120.))
                .child(new Toggle('one').label('One').checked(true).onClick((_, _, _) -> childClicks[0]++))
                .child(new Toggle('two').label('Two'));
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
        final toggle = new Toggle('styled').checked(true).opacity(0.37);
        assertEquals(0.37, toggle.toggleStyle.opacity);
    }

    function testToggleBuilder() {
        final toggle = new Toggle('complex-toggle')
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
        final group = new ToggleGroup('complex-group')
            .child(new Toggle('toggle1').label('Option 1'))
            .child(new Toggle('toggle2').label('Option 2').checked(true))
            .child(new Toggle('toggle3').label('Option 3'))
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
        final plain = new Checkbox('remember').label('Remember me');
        assertNull(plain.accessibilityLabelValue);
        final named = new Checkbox('remember').label('Remember me').accessibilityLabel('Remember this account');
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
            .child(new Checkbox('checkbox').disabled(disabled).sizeFull().onClick((checked, _, _) -> {
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
        open((_, _) -> new Checkbox('content-checkbox').label('Remember me').child(div().onPrepaint((b, _, _) -> bounds = b).child('Additional detail')));
        assertNotNull(bounds);
        assertTrue(bounds.size.width > 0);
        assertTrue(bounds.size.height > 0);
    }

    function testTheCheckMarkAsksTheIconResolverForItsPath() {
        final asked:Array<String> = [];
        app.update(cx -> {
            cx.setReduceMotion(true);
            gpui.component.Icon.setIconResolver(cx, (path, _) -> {
                asked.push(path);
                return null;
            });
        });
        open((_, _) -> new Checkbox('checked').checked(true));
        assertTrue(asked.indexOf(IconName.Check.path()) >= 0, 'the check mark must be drawn from the resolved path');
    }

    /// Radio

    function testRadioExplicitAccessibilityLabelReplacesTheVisibleOne() {
        final plain = new Radio('automatic').label('Automatic');
        assertNull(plain.accessibilityLabelValue);
        assertEquals('Automatic', plain.labelValue);
        final named = new Radio('automatic').label('Automatic').accessibilityLabel('Choose automatic mode');
        assertEquals('Choose automatic mode', named.accessibilityLabelValue);
        assertEquals('Automatic', named.labelValue);
    }

    /// Switch

    function testSwitchExplicitAccessibilityLabelReplacesTheVisibleOne() {
        final plain = new Switch('wifi').label('Wi-Fi');
        assertNull(plain.accessibilityLabelValue);
        assertEquals('Wi-Fi', plain.labelValue);
        final named = new Switch('wifi').label('Wi-Fi').accessibilityLabel('Toggle Wi-Fi');
        assertEquals('Toggle Wi-Fi', named.accessibilityLabelValue);
        assertEquals('Wi-Fi', named.labelValue);
    }

    function switchHarness(disabled:Bool):{cx:VisualTestContext, toggles:Array<Int>, parent:Array<Int>} {
        final toggles = [0];
        final parent = [0];
        final cx = open((_, _) -> div()
            .id('switch-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> parent[0]++)
            .child(new Switch('switch').disabled(disabled).onClick((checked, _, _) -> {
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
        final cx = open((_, _) -> div().id('switch-parent').tabGroup().size(px(100.)).child(new Switch('switch').label('Airplane mode').disabled(true)));
        cx.update((window, app) -> window.focusNext(app));
        cx.update((window, app) -> assertNull(window.focused(app)));
    }

    /// Slider

    function sliderHarness(disabled:Bool):{cx:VisualTestContext, state:Entity<SliderState>} {
        final state = app.newEntity((_:Context<SliderState>) -> new SliderState());
        final cx = open((_, _) -> div().w(px(100.)).h(px(24.)).child(new Slider(state).disabled(disabled)));
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
        final toolbar = new Toolbar('toolbar').content('New').content('Open').content('Settings').small();
        assertEquals(3, toolbar.items.length);
        assertTrue(toolbar.sizeValue.equals(Small));
    }

    function testToolbarDefault() {
        final toolbar = new Toolbar('toolbar');
        assertTrue(toolbar.sizeValue.equals(Small));
        assertFalse(toolbar.disabledValue);
        assertEquals(0, toolbar.items.length);
    }

    function testLargeSizeFallsBackToMedium() {
        assertTrue(new Toolbar('toolbar').large().sizeValue.equals(Medium));
        assertTrue(new gpui.component.toolbar.Toolbar.ToolbarGroup('group').large().sizeValue.equals(Medium));
    }

    function testToolbarPreparesButtonsAsCompactGhostCommands() {
        final button = new Button('command').prepareForToolbar();
        assertTrue(button.variant().equals(Ghost));
        assertTrue(button.isCompact());
    }

    function testToolbarSizePropagatesToItemsIndependentOfBuilderOrder() {
        final observed:Array<Null<Size>> = [null, null, null];
        open((_, _) -> new Toolbar('toolbar').children([for (i in 0...3) new SizeProbe(observed, i)]).small());
        for (size in observed) assertTrue(size != null && size.equals(Small));
    }

    function testToolbarGroupPropagatesItsSizeToItems() {
        final observed:Array<Null<Size>> = [null];
        open((_, _) -> new gpui.component.toolbar.Toolbar.ToolbarGroup('group').child(new SizeProbe(observed, 0)).small());
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
        app.update(cx -> gpui.base.Base.init(cx));
        final controls = new Controls();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<gpui.base.Root>) -> {
            final content = rootCx.newEntity((_:Context<ScriptView>) -> new ScriptView((_, cx) -> controls.render(cx)));
            return new gpui.base.Root(content, window, rootCx);
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
        return open((_, _) -> div().p8().w(px(264.)).child(div().onPrepaint((b, _, _) -> track[0] = b).child(new Slider(state).disabled(disabled))), 400, 240);
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
            .child(probe('save', new Button('save').label('Save').onClick((_, _, _) -> buttonClicks++)))
            .child(probe('remember', new Checkbox('remember').label('Remember account').checked(checked).onChange((next, _, _) -> {
                changes.push(next);
                checked = next;
                cx.notify();
            })))
            .child(probe('notifications', new Switch('notifications').label('Notifications').checked(checked).disabled(disabled).onChange((next, _, _) -> {
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
            column.child(gpui.component.radio.Radio.RadioGroup.vertical(id)
                .selectedIndex(selected[group])
                .disabled(group == 1 && billingDisabled)
                .child(new Radio('standard').label('Standard').child(probe(0)))
                .child(new Radio('express').label('Express').accessibilityLabel('Express delivery').child(probe(1)))
                .child(new Radio('overnight').label('Overnight').disabled(true).child(probe(2)))
                .onChange((index, _, _) -> {
                    selected[group] = index;
                    changes.push('$group-$index');
                    cx.notify();
                }));
        }
        return column;
    }

}
