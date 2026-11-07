// Ported from gpui-kit 0.8.1: crates/base/src/{global_state,state_style,actions,component_traits,observe,index_path,progress,avatar}.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.Actions;
import gpui.base.Avatar;
import gpui.base.ComponentTraits;
import gpui.base.GlobalState;
import gpui.base.IndexPath;
import gpui.base.StateStyle;
import gpui.StyleRefinement;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.base.ElementExt;
using gpui.base.Observe;

/**
 * The `#[cfg(test)]` tests of gpui-base's small foundation modules.
 *
 * Not ported: `focus_trap.rs` and `progress.rs` accessibility node tests
 * read accesskit nodes; the progress ones are ported on the port's `A11y`
 * record instead.
 */
class BaseFoundationsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    // global_state.rs

    function cell(x:Float):Bounds {
        return new Bounds(point(x, 0.), size(100., 30.));
    }

    function pair(result:Null<Array<gpui.Point>>):String {
        return result == null ? 'none' : result.map(p -> '${p.x},${p.y}').join(' ');
    }

    function testADragOutsideACellIsUnchanged() {
        final anchor = point(5., 5.);
        final cursor = point(250., 80.);
        assertEquals('5,5 250,80', pair(GlobalState.confineToCell(null, null, cell(0.), anchor, cursor)));
        // A cell from an older drag does not hold this anchor.
        assertEquals('5,5 250,80', pair(GlobalState.confineToCell(point(50., 10.), cell(0.), null, anchor, cursor)));
    }

    function testADragFromACellSelectsNothingOutsideIt() {
        final anchor = point(10., 10.);
        final cursor = point(150., 20.);
        assertEquals('none', pair(GlobalState.confineToCell(anchor, cell(0.), cell(100.), anchor, cursor)));
        assertEquals('none', pair(GlobalState.confineToCell(anchor, cell(0.), null, anchor, cursor)));
    }

    function testADragFromACellIsClampedToIt() {
        final anchor = point(10., 10.);
        assertEquals('10,10 100,30', pair(GlobalState.confineToCell(anchor, cell(0.), cell(0.), anchor, point(250., 80.))));
        assertEquals('10,10 0,0', pair(GlobalState.confineToCell(anchor, cell(0.), cell(0.), anchor, point(-20., -5.))));
        assertEquals('10,10 60,12', pair(GlobalState.confineToCell(anchor, cell(0.), cell(0.), anchor, point(60., 12.))));
    }

    function testInitializationIsIdempotentAndSuppressionCanBeReset() {
        app.update(cx -> {
            GlobalState.init(cx);
            GlobalState.suppressTextSelection(cx);
            GlobalState.init(cx);
            assertTrue(GlobalState.isTextSelectionSuppressed(cx));
            GlobalState.resetTextSelectionSuppression(cx);
            assertFalse(GlobalState.isTextSelectionSuppressed(cx));
            assertFalse(GlobalState.isInDeferredContext(cx));
            final popover = GlobalState.registerDeferredPopover(cx);
            assertTrue(GlobalState.isInDeferredContext(cx));
            popover.release();
            assertFalse(GlobalState.isInDeferredContext(cx));
        });
    }

    function testADroppedRegistrationClosesTheDeferredContext() {
        app.update(cx -> {
            GlobalState.init(cx);
            final outer = GlobalState.registerDeferredPopover(cx);
            final inner = GlobalState.registerDeferredPopover(cx);
            assertTrue(GlobalState.isInDeferredContext(cx));
            inner.release();
            assertTrue(GlobalState.isInDeferredContext(cx));
            outer.release();
            assertFalse(GlobalState.isInDeferredContext(cx));
            // Registering again must not resurrect the collected ones.
            final popover = GlobalState.registerDeferredPopover(cx);
            assertEquals(1, GlobalState.global(cx).deferredPopoverCount());
            popover.release();
            assertFalse(GlobalState.isInDeferredContext(cx));
        });
    }

    // state_style.rs

    function state(build:(StateStyle) -> StateStyle):StyleRefinement {
        return build(new StateStyle()).style();
    }

    function testInstanceStyleIsTheBaselineWhenNoStateIsActive() {
        final instance = state(s -> s.opacity(0.9));
        assertEquals(0.9, StateStyle.resolveStyle(instance, []).opacity);
    }

    function testAnActiveStateOverridesTheInstanceStyle() {
        final instance = state(s -> s.opacity(0.9));
        final checked = state(s -> s.opacity(0.8));
        assertEquals(0.8, StateStyle.resolveStyle(instance, [checked]).opacity);
    }

    function testLaterStatesOverrideEarlierStates() {
        final instance = state(s -> s.opacity(0.9));
        final checked = state(s -> s.opacity(0.8));
        final disabled = state(s -> s.opacity(0.5));
        assertEquals(0.5, StateStyle.resolveStyle(instance, [checked, disabled]).opacity);
    }

    function testStatesOnlyOverrideTheFieldsTheySet() {
        final instance = state(s -> s.opacity(0.9).border1());
        final disabled = state(s -> s.opacity(0.5));
        final resolved = StateStyle.resolveStyle(instance, [disabled]);
        assertEquals(0.5, resolved.opacity);
        assertTrue(Type.enumEq(instance.borderWidthTop, resolved.borderWidthTop));
        assertTrue(Type.enumEq(instance.borderWidthLeft, resolved.borderWidthLeft));
    }

    // actions.rs

    function testConfirmKeepsItsSecondaryPayload() {
        assertTrue(new Confirm(true).secondary);
        assertFalse(new Confirm(false).secondary);
    }

    // component_traits.rs

    function testOpenFallsBackToSelectedUnlessOverridden() {
        final trigger = new SelectedOnlyTrigger(false);
        trigger.setOpen(true);
        assertTrue(trigger.isSelected());
        assertTrue(trigger.isOpen());
        final trigger = new SelectedOnlyTrigger(true);
        trigger.setOpen(false);
        assertFalse(trigger.isSelected());
        assertFalse(trigger.isOpen());
    }

    function testFocusRingApiCarriesStateWithoutVisuals() {
        final control = new CustomControl(true);
        control.setFocusRing(false);
        assertFalse(control.isFocusRingEnabled());
    }

    // observe.rs

    function testObservationPreservesIdentityAndNativeTypeInNormalBuilds() {
        final element:gpui.Div = div().id('target').testSupport().testSupport();
        assertTrue(Type.enumEq(gpui.ElementId.Name('target'), element.elementId()));
    }

    // index_path.rs

    function testIntoElementId() {
        final path = new IndexPath(2).withSection(1).withColumn(3);
        assertTrue(Type.enumEq(gpui.ElementId.Name('index-path(1,2,3)'), path.toElementId()));
    }

    function testDisplay() {
        assertEquals('IndexPath(section: 1, row: 2, column: 3)', new IndexPath(2).withSection(1).withColumn(3).toString());
    }

    function testIndexPath() {
        var path = IndexPath.defaultValue();
        assertEquals(0, path.section);
        assertEquals(0, path.row);
        assertEquals(0, path.column);
        path = path.withSection(1).withRow(2).withColumn(3);
        assertEquals(1, path.section);
        assertEquals(2, path.row);
        assertEquals(3, path.column);
    }

    // progress.rs (accessibility properties on the A11y record)

    function renderOnce(component:gpui.RenderOnce):Void {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<Host>) -> new Host(() -> component));
        cx = opened.cx;
    }

    function testClampsAndProjectsNumericAccessibility() {
        final progress = new gpui.base.Progress('progress').value(120.);
        renderOnce(progress);
        assertEquals(100., progress.a11y.numericValue);
        assertEquals(0., progress.a11y.minNumericValue);
        assertEquals(100., progress.a11y.maxNumericValue);
    }

    function testIndeterminateProgressOmitsNumericValue() {
        final progress = new gpui.base.Progress('loading').value(40.).indeterminate(true);
        renderOnce(progress);
        assertNull(progress.a11y.numericValue);
    }

    function testProgressProjectsItsAccessibleName() {
        final progress = new gpui.base.Progress('download').accessibilityLabel('Downloading release');
        renderOnce(progress);
        assertEquals('Downloading release', progress.a11y.label);
    }

    // avatar.rs

    function avatarHarness(image:Bool):Map<String, Bounds> {
        final bounds = new Map<String, Bounds>();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<Host>) -> new Host(() -> {
            final avatar = new Avatar();
            if (image) {
                avatar.image(new AvatarImage('avatar.png').size(px(20.)));
            }
            avatar.fallback(new AvatarFallback().child(div().size(px(20.)).onPrepaint((b, _, _) -> bounds.set('avatar-fallback', b))));
            return avatar;
        }));
        cx = opened.cx;
        return bounds;
    }

    function testImageSlotTakesPrecedenceOverFallback() {
        final bounds = avatarHarness(true);
        assertFalse(bounds.exists('avatar-fallback'));
    }

    function testFallbackRendersWithoutAnImage() {
        final bounds = avatarHarness(false);
        assertTrue(bounds.exists('avatar-fallback'));
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

private class SelectedOnlyTrigger implements Selectable {

    var selected:Bool;

    public function new(selected:Bool) {
        this.selected = selected;
    }

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
    }

    // Defaults of the trait: open is selected
    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

}

private class CustomControl implements FocusableExt {

    var enabled:Bool;

    public function new(enabled:Bool) {
        this.enabled = enabled;
    }

    public function setFocusRing(enabled:Bool):Void {
        this.enabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return enabled;
    }

}
