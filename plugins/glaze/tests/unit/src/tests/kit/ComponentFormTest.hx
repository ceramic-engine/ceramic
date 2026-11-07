// Ported from gpui-kit 0.8.1: crates/component/src/form/tests.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.component.Component;
import gpui.component.button.Button;
import gpui.component.form.Field;
import gpui.component.form.Form;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's `form` module. Element
 * bounds are read through `DebugProbe` (Rust `debug_selector`).
 */
class ComponentFormTest extends TestCase {

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
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    function open<V:Model & Render>(build:(Context<V>) -> V):VisualTestContext {
        DebugProbe.clear();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, cx:Context<V>) -> build(cx));
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    static inline function b(selector:String):Null<Bounds> {
        return DebugProbe.bounds(selector);
    }

    function testFormBuilder() {
        for (form in [new Form(), new Form(), Form.vertical()]) {
            assertEquals(Axis.Vertical, form.props.layout);
            assertEquals(1, form.props.columns);
            assertTrue(form.footerValue == null);
        }
        final form = new Form()
            .columns(2)
            .labelLayout(Horizontal)
            .child(new Field())
            .footer(new Button('save').label('Save'));
        assertEquals(Axis.Horizontal, form.props.layout);
        assertEquals(2, form.props.columns);
        assertEquals(1, form.fields.length);
        assertTrue(form.footerValue != null);
    }

    function testLabelLayoutIsIndependentOfFieldColumns() {
        for (width in [360., 800.]) {
            for (layout in [Axis.Horizontal, Axis.Vertical]) {
                open((_:Context<FormHarness>) -> new FormHarness(width, layout, false, null));
                final first = b('control-0');
                final second = b('control-1');
                final third = b('control-2');
                final label = b('label-0');
                assertEquals(first.top(), second.top());
                assertTrue(second.left() > first.right());
                assertEquals(first.left(), third.left());
                assertTrue(third.top() > first.bottom());
                switch layout {
                    case Horizontal: assertTrue(label.right() < first.left());
                    case Vertical:
                        assertEquals(label.left(), first.left());
                        assertTrue(label.bottom() < first.top());
                }
            }
        }
    }

    function testFooterSpansColumnsAfterFieldsAndAlignsActionsToTrailingEdge() {
        for (width in [360., 800.]) {
            for (layout in [Axis.Horizontal, Axis.Vertical]) {
                for (fullWidth in [true, false]) {
                    open((_:Context<FormHarness>) -> new FormHarness(width, layout, false, fullWidth));
                    final form = b('form-container');
                    final footer = b('footer-content');
                    final last = b('control-2');
                    assertTrue(footer.top() > last.bottom());
                    assertEquals(form.right(), footer.right());
                    assertTrue(footer.bottom() <= form.bottom());
                    if (fullWidth) {
                        assertEquals(form.left(), footer.left());
                        assertEquals(width, footer.size.width);
                    } else {
                        assertEquals(80., footer.size.width);
                    }
                }
            }
        }
    }

    function testDefaultWithoutFooterKeepsLegacyGeometry() {
        for (layout in [Axis.Horizontal, Axis.Vertical]) {
            final snapshots:Array<Array<Bounds>> = [];
            for (legacy in [true, false]) {
                open((_:Context<FormHarness>) -> new FormHarness(360., layout, legacy, null));
                snapshots.push([b('form-container'), b('label-0'), b('control-0'), b('control-1'), b('control-2')]);
                assertTrue(b('footer-content') == null);
            }
            for (i in 0...snapshots[0].length) {
                assertTrue(snapshots[0][i].equals(snapshots[1][i]));
            }
        }
    }

    function testFormAppliesStyledRefinements() {
        // Default form without custom styling
        open((_:Context<FormCompareHarness>) -> new FormCompareHarness(false));
        final defaultFirst = b('control-0');
        final defaultSecond = b('control-1');

        // Styled form with padding 20px and gap_y 30px
        open((_:Context<FormCompareHarness>) -> new FormCompareHarness(true));
        final styledFirst = b('control-0');
        final styledSecond = b('control-1');

        // Padding applied: top and left shifted by 20px
        assertEquals(20., styledFirst.left() - defaultFirst.left());
        assertEquals(20., styledFirst.top() - defaultFirst.top());

        // Custom gap applied: spacing between controls increased by (30px - 8px default) = 22px
        final defaultGap = defaultSecond.top() - defaultFirst.bottom();
        final styledGap = styledSecond.top() - styledFirst.bottom();
        assertEquals(22., styledGap - defaultGap);
    }

    function testHiddenFieldsAreNotRendered() {
        open((_:Context<HiddenFieldHarness>) -> new HiddenFieldHarness(false));
        final secondRowTop = b('control-1').top();

        open((_:Context<HiddenFieldHarness>) -> new HiddenFieldHarness(true));
        assertTrue(b('control-1') == null);
        // The hidden field leaves no grid row behind.
        assertEquals(secondRowTop, b('control-2').top());
    }

}

private class FormHarness extends Model implements Render {

    final width:Float;

    final layout:Axis;

    final legacy:Bool;

    final footer:Null<Bool>;

    public function new(width:Float, layout:Axis, legacy:Bool, footer:Null<Bool>) {
        super();
        this.width = width;
        this.layout = layout;
        this.legacy = legacy;
        this.footer = footer;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final form = legacy ? Form.vertical().layout(layout) : new Form().labelLayout(layout);
        form.columns(2)
            .labelWidth(80.)
            .children([for (ix in 0...3) new Field()
                .labelFn((_, _) -> new DebugProbe('label-$ix', div().w(px(40.)).h(px(20.))))
                .child(new DebugProbe('control-$ix', div().wFull().h(px(24.))))
            ]);
        if (footer != null) {
            final content = div().h(px(30.));
            if (footer) content.wFull();
            if (!footer) content.w(px(80.));
            form.footer(new DebugProbe('footer-content', content));
        }
        return new DebugProbe('form-container', div().w(px(width)).child(form));
    }

}

private class FormCompareHarness extends Model implements Render {

    final styled:Bool;

    public function new(styled:Bool) {
        super();
        this.styled = styled;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final form = styled ? Form.vertical().p(px(20.)).gapY(px(30.)) : Form.vertical();
        return div().w(px(400.)).child(
            form.child(new Field().child(new DebugProbe('control-0', div().wFull().h(px(20.)))))
                .child(new Field().child(new DebugProbe('control-1', div().wFull().h(px(20.)))))
        );
    }

}

private class HiddenFieldHarness extends Model implements Render {

    final hide:Bool;

    public function new(hide:Bool) {
        super();
        this.hide = hide;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final hide = this.hide;
        return div()
            .w(px(400.))
            .child(new Form().children([for (ix in 0...3) new Field().visible(!(hide && ix == 1)).child(
                new DebugProbe('control-$ix', div().wFull().h(px(20.)))
            )]));
    }

}
