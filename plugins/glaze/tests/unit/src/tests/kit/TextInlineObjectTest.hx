// Ported from gpui-kit 0.8.1: crates/base/src/text/inline_object.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.Bounds;
import gpui.Size;
import gpui.TextStyle;
import gpui.base.text.InlineElement;
import gpui.base.text.InlineNode.SharedFlag;
import gpui.base.text.InlineObject;
import gpui.base.text.InlineObject.MeasuredInlineObject;
import tests.kit.TextInlineTest.TextTestDraw;
import testing.TestCase;


/**
 * The tests of inline_object.rs.
 *
 * `atomic_wrapper_does_not_mislabel_native_controls_as_images` checks the
 * accessibility node the element writes (role and label): the port has no
 * accessibility tree, so it only checks that the element keeps its label.
 */
@:access(gpui.base.text.MeasuredInlineObject)
@:access(gpui.base.text.InlineMetrics)
@:access(gpui.base.text.InlineObject)
class TextInlineObjectTest extends TestCase {

    static function sizeString(size:Size):String {
        return '${size.width}x${size.height}';
    }

    function testNativePaddingAndFixedSizeAreMeasuredWithoutFakeScaling() {
        final app = TextTestDraw.testApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            final native = new InlineElement(gpui.Prelude.div().px(gpui.Prelude.px(4.)).py(gpui.Prelude.px(2.)).child(gpui.Prelude.div().w(gpui.Prelude.px(40.)).h(gpui.Prelude.px(10.)))).withBaseline(10.);
            final measured = MeasuredInlineObject.measure("badge", native, new TextStyle(), window, cx);
            assertEquals('48x14', sizeString(measured.metrics.size));
            assertEquals(10., measured.metrics.baseline);
            final narrow = measured.fitText(20.);
            assertEquals('48x14', sizeString(narrow.metrics.size));
            return null;
        });
    }

    function testInvalidBaselineUsesTextFallbackAndZeroWidthRemainsFinite() {
        final app = TextTestDraw.testApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            for (baseline in [Math.NaN, -1., 30.]) {
                final native = new InlineElement(gpui.Prelude.div().w(gpui.Prelude.px(20.)).h(gpui.Prelude.px(20.))).withBaseline(baseline);
                final measured = MeasuredInlineObject.measure("fallback", native, new TextStyle(), window, cx);
                assertTrue(measured.content == null);
                assertTrue(measured.metrics.isValid());
                final zero = measured.fitText(0.);
                assertEquals('0x0', sizeString(zero.metrics.size));
                assertEquals(0., zero.metrics.baseline);
            }
            return null;
        });
    }

    function testAtomicWrapperDoesNotMislabelNativeControlsAsImages() {
        final app = TextTestDraw.testApp();
        final window = TextTestDraw.openWindow(app, (_, _) -> new gpui.Empty());
        app.update(cx -> {
            final measured = MeasuredInlineObject.measure("member", null, new TextStyle(), window, cx);
            final object = new InlineObject("member", "member", "Member profile", measured, new SharedFlag(), new Bounds(), new Bounds());
            assertEquals("Member profile", object.a11yLabel());
        });
        window.destroy();
    }

}
