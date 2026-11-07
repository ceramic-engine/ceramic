// Ported from gpui-kit 0.8.1: crates/base/src/text/inline_flow.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.AbsoluteLength;
import gpui.App;
import gpui.HighlightStyle;
import gpui.ImageSource;
import gpui.Point;
import gpui.Range;
import gpui.Size;
import gpui.StyleBuilder;
import gpui.TextStyle;
import gpui.Window;
import gpui.base.text.InlineFlow;
import gpui.base.text.InlineFlow.CodeBox;
import gpui.base.text.InlineFlow.InlineFlowLayout;
import gpui.base.text.InlineFlow.MeasureItem;
import gpui.base.text.InlineFlow.PositionedFragment;
import gpui.base.text.InlineHighlight;
import gpui.base.text.RangedHighlight;
import gpui.util.Utf8;
import tests.kit.TextInlineTest.TextTestDraw;
import tests.kit.TextInlineTest.TextTestFonts;
import testing.TestCase;

using gpui.AbsoluteLengthTools;

/**
 * The tests of inline_flow.rs.
 */
@:access(gpui.base.text.InlineFlow)
@:access(gpui.base.text.InlineFlowLayout)
@:access(gpui.base.text.MeasuredInlineObject)
class TextInlineFlowTest extends TestCase {

    static inline function f32(value:Float):Float {
        return TextTestFonts.f32(value);
    }

    static function bodyStyle(fontSize:Float):TextStyle {
        final style = new TextStyle();
        style.fontFamily = TextTestFonts.BODY;
        style.fontSize = AbsoluteLength.Pixels(fontSize);
        return style;
    }

    static function textItem(text:String, ?highlights:Array<RangedHighlight>):MeasureItem {
        return MeasureItem.Text(text, [], highlights != null ? highlights : []);
    }

    static function imageItem(uri:String):MeasureItem {
        return MeasureItem.Image(ImageSource.Resource(gpui.Resource.Uri(uri)), null, null);
    }

    static function texts(layout:InlineFlowLayout):Array<{text:String, origin:Point, size:Size, fontSize:Float, codeBackground:Null<CodeBox>}> {
        final result = [];
        for (fragment in layout.fragments) {
            switch fragment {
                case Text(_, origin, size, _, fontSize, text, _, _, _, codeBackground):
                    result.push({text: text, origin: origin, size: size, fontSize: (fontSize : Float), codeBackground: codeBackground});
                case _:
            }
        }
        return result;
    }

    /** Opens an empty window and runs `f` in an update of it (Rust `window.update(|_, window, cx| ...)`). */
    static function withWindow<R>(app:App, f:(Window, App) -> R):R {
        final window = TextTestDraw.openWindow(app, (_, _) -> new gpui.Empty());
        final result = app.update(cx -> f(window, cx));
        window.destroy();
        return result;
    }

/// frames

    static function layouts():Int {
        return InlineFlow.FLOW_LAYOUTS;
    }

    static function draw(cx:testing.VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    /**
     * Scrolling redraws every visible paragraph each frame; a flow whose
     * text, style and width are unchanged has nothing to wrap or shape.
     */
    function testAnUnchangedFlowIsNotLaidOutAgain() {
        final cx = @:privateAccess TextInlineTest.openTextViews("Call `foo` now.", 1).cx;
        draw(cx);
        final afterFirstFrame = layouts();
        assertTrue(afterFirstFrame >= 1, "the first frame lays the flow out");

        for (_ in 0...3) {
            draw(cx);
        }

        assertEquals(afterFirstFrame, layouts(), "a frame that changes nothing");
        cx.destroy();
    }

    function testAFlowIsLaidOutAgainAtAnotherWidth() {
        final opened = @:privateAccess TextInlineTest.openTextViews("Call `foo` now.", 1);
        final cx = opened.cx;
        draw(cx);
        final before = layouts();

        opened.view.update(cx.app, (answer, cx) -> {
            answer.width = 120.;
            cx.notify();
        });
        draw(cx);

        assertTrue(layouts() > before, "a narrower flow wraps differently");
        cx.destroy();
    }

    function testAFlowIsLaidOutAgainWhenItsTextChanges() {
        final opened = @:privateAccess TextInlineTest.openTextViews("Call `foo` now.", 1);
        final cx = opened.cx;
        draw(cx);
        final before = layouts();

        opened.view.update(cx.app, (answer, cx) -> {
            answer.state.update(cx.app, (state, cx) -> state.setText("Call `foo` and `bar` now.", cx));
        });
        cx.runUntilParked();
        draw(cx);

        assertTrue(layouts() > before, "a new text has a new layout");
        cx.destroy();
    }

    function testAtomicObjectsWrapAndShareABaselineAtMultipleFontSizes() {
        final app = TextTestDraw.wideMonoApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            for (scale in [1., 1.5, 2.]) {
                final style = bodyStyle(16. * scale);
                final items = [
                    textItem("中文 "),
                    MeasureItem.Object("x²", 0, (_, _, _) -> null, new HighlightStyle()),
                    MeasureItem.Object("y²", 1, (_, _, _) -> null, new HighlightStyle()),
                    textItem(" English"),
                ];
                for (width in [1., 30., 80., 500.]) {
                    final layout = InlineFlow.layoutFlow(items, [null, null, null, null], style, width, window, cx);
                    final objects = [];
                    for (fragment in layout.fragments) {
                        switch fragment {
                            case Object(_, origin, object, _):
                                objects.push({origin: origin, object: object});
                            case _:
                        }
                    }
                    assertEquals(2, objects.length);
                    for (o in objects) {
                        assertTrue(o.object.metrics.size.width <= width);
                        assertTrue(o.origin.y >= 0.);
                        assertTrue(f32(o.origin.y + o.object.metrics.size.height) <= layout.size.height);
                    }
                    if (width == 500.) {
                        assertEquals(f32(objects[0].origin.y + objects[0].object.metrics.baseline), f32(objects[1].origin.y + objects[1].object.metrics.baseline));
                    }
                }
            }
            return null;
        });
    }

    function testInlineImageWithoutExplicitSizeScalesIntrinsicRatioToLineHeight() {
        final measured = InlineFlow.inlineImageSizeForLine(new Size(160., 40.), 20.);
        assertTrue(measured.equals(new Size(60., 15.)), '$measured');
    }

    function testInlineImageWithoutIntrinsicSizeUsesCompactSquareFallback() {
        final measured = InlineFlow.inlineImageSizeForLine(null, 20.);
        assertTrue(measured.equals(new Size(15., 15.)), '$measured');
    }

    /**
     * Line breaking must see the width of an inline code span in its own
     * family. With a body-font-only wrapper the span below is measured at
     * half its shaped width, the line is kept whole, and the flow reports a
     * width past `wrapWidth`.
     */
    function testInlineCodeNearTheWrapWidthDoesNotOverflowTheFlow() {
        final app = TextTestDraw.wideMonoApp();
        final fontSize = 10.;
        final textStyle = bodyStyle(fontSize);
        final lead = "See ";
        final tailText = " with code_span_here end";
        final code = tailText.indexOf("code_span_here");
        final codeRange = new Range(code, code + "code_span_here".length);
        final codeHighlight = new InlineHighlight(new HighlightStyle(), TextTestFonts.MONO);
        final items = [
            textItem(lead),
            imageItem("https://example.com/badge.png"),
            textItem(tailText, [new RangedHighlight(codeRange, codeHighlight)]),
        ];
        final imageSize = new Size(10., 10.);
        final imageSizes:Array<Null<Size>> = [null, imageSize, null];
        // Body text, the image and the mono span fill the wrap width exactly;
        // the trailing "end" only fits if the span is under-measured.
        final wrapWidth = f32(f32(TextTestFonts.widthOf("See  with  ", TextTestFonts.BODY, fontSize) + imageSize.width)
            + TextTestFonts.widthOf("code_span_here", TextTestFonts.MONO, fontSize));

        final layout = withWindow(app, (window, cx) -> InlineFlow.layoutFlow(items, imageSizes, textStyle, wrapWidth, window, cx));

        assertTrue(layout.size.width <= wrapWidth, 'flow width ${layout.size.width} exceeds wrap width $wrapWidth');
        var monoFragmentWidth:Null<Float> = null;
        for (t in texts(layout)) {
            if (t.text.indexOf("code_span_here") >= 0) {
                monoFragmentWidth = t.size.width;
                break;
            }
        }
        assertTrue(monoFragmentWidth != null, "the code span is laid out as a text fragment");
        assertTrue(monoFragmentWidth >= TextTestFonts.widthOf("code_span_here", TextTestFonts.MONO, fontSize), "the code span fragment is shaped in the mono family");
        // The image sits vertically centred in its line, so line membership is
        // read off the text fragments only.
        final textLines = [for (t in texts(layout)) {text: StringTools.trim(t.text), y: t.origin.y}];
        final firstY = textLines[0].y;
        assertTrue(Lambda.exists(textLines, l -> l.text.indexOf("code_span_here") >= 0 && l.y == firstY), 'the span stays on the first line: $textLines');
        assertTrue(Lambda.exists(textLines, l -> l.text == "end" && l.y > firstY), 'the trailing word wraps to a second line: $textLines');
    }

    function testLongInlineCodeWrapsInMixedFlow() {
        final app = TextTestDraw.wideMonoApp();
        final style = bodyStyle(10.);
        for (text in [
            "one two three four five six",
            "very_long_unbroken_identifier",
            "你好世界你好世界你好世界",
            "éééééé",
        ]) {
            final items = [
                imageItem("https://example.com/icon.png"),
                textItem(text, [new RangedHighlight(new Range(0, Utf8.byteLength(text)), new InlineHighlight(null, TextTestFonts.MONO))]),
            ];
            final imageSizes:Array<Null<Size>> = [new Size(10., 10.), null];
            final layout = withWindow(app, (window, cx) -> InlineFlow.layoutFlow(items, imageSizes, style, 100., window, cx));
            assertTrue(layout.size.width <= 100., '"$text": ${layout.size}');
            final reconstructed = [for (t in texts(layout)) t.text].join('');
            assertEquals(text, reconstructed);
        }
    }

    function testInlineCodeLineIsAsTallAsAPlainLineWhenGlyphsOverflowIt() {
        final app = TextTestDraw.wideMonoApp();
        final style = bodyStyle(40.);
        style.lineHeight = gpui.DefiniteLength.Absolute(AbsoluteLength.Pixels(30.));
        final items = [textItem("a code z", [new RangedHighlight(new Range(2, 6), new InlineHighlight(null, TextTestFonts.MONO, 0.875))])];
        // The 40px glyphs are taller than the 30px line. A plain text line
        // keeps the line height and lets them overflow, so a line with
        // inline code must not grow to fit them.
        withWindow(app, (window, cx) -> {
            final layout = InlineFlow.layoutFlow(items, [null], style, null, window, cx);
            assertEquals(window.pixelSnap(30.), layout.size.height);
            return null;
        });
    }

    function testInlineCodeStyleKeepsEqualSizeProseSeparateAndMeasuresItsBox() {
        final app = TextTestDraw.wideMonoApp();
        final window = TextTestDraw.openWindow(app, (_, _) -> new gpui.Empty());
        for (remSize in [14., 28.]) {
            app.update(cx -> {
                window.setRemSize(remSize);
                final textStyle = bodyStyle(remSize);
                final codeStyle = StyleBuilder.build(s -> s.textSize(gpui.Prelude.rems(1.))
                    .px(gpui.Prelude.rems(0.25))
                    .py(gpui.Prelude.rems(0.125))
                    .bg(gpui.Prelude.red())
                    .border1()
                    .borderColor(gpui.Prelude.blue())
                    .rounded(gpui.Prelude.rems(0.25)));
                final highlight = new InlineHighlight(new HighlightStyle(null, null, null, gpui.Prelude.green()), TextTestFonts.MONO, 0.875, codeStyle.clone());
                final items = [textItem("before code after", [new RangedHighlight(new Range(7, 11), highlight)])];
                final layout = InlineFlow.layoutFlow(items, [null], textStyle, null, window, cx);
                assertEquals(3, layout.fragments.length);
                for (t in texts(layout)) {
                    assertEquals(remSize, t.fontSize);
                    if (t.text == "code") {
                        final code = t.codeBackground;
                        assertTrue(code != null, "code box");
                        assertTrue(code.style.background.equals(codeStyle.background));
                        assertTrue(code.style.borderColor.equals(gpui.Prelude.blue()));
                        assertTrue(gpui.RefinementEq.absolute(code.style.cornerRadiusTopLeft, codeStyle.cornerRadiusTopLeft)
                            && gpui.RefinementEq.absolute(code.style.cornerRadiusBottomRight, codeStyle.cornerRadiusBottomRight));
                        assertEquals(t.size.width, code.bounds.size.width);
                        assertEquals(f32(f32(TextTestFonts.widthOf("code", TextTestFonts.MONO, remSize) + f32(remSize * 0.5)) + 2.), t.size.width);
                    }
                    else {
                        assertTrue(t.codeBackground == null);
                        assertEquals(TextTestFonts.widthOf(t.text, TextTestFonts.BODY, remSize), t.size.width);
                    }
                }
                // The same insets must be included by wrapping, not just drawing.
                final wrapWidth = f32(f32(f32(TextTestFonts.widthOf("before ", TextTestFonts.BODY, remSize)
                    + TextTestFonts.widthOf("code", TextTestFonts.MONO, remSize))
                    + f32(remSize * 0.5))
                    + 1.);
                final wrapped = InlineFlow.layoutFlow(items, [null], textStyle, wrapWidth, window, cx);
                assertTrue(wrapped.size.height > layout.size.height);
                assertTrue(wrapped.size.width <= wrapWidth);
                final reconstructed = [for (t in texts(wrapped)) t.text].join('');
                assertEquals("before code after", reconstructed);
            });
        }
        window.destroy();
    }

    function testInlineCodeSizeIsRelativeAndUsesTheNativeBodyBaseline() {
        final app = TextTestDraw.wideMonoApp();
        final window = TextTestDraw.openWindow(app, (_, _) -> new gpui.Empty());
        // These are the 16px body size and the example-markdown preview's
        // 1.25x/1.5x inherited text-size zooms.
        for (bodySize in [16., 20., 24.]) {
            final style = bodyStyle(bodySize);
            final code = () -> new InlineHighlight(null, TextTestFonts.MONO, 0.875);
            final items = [textItem("a code z", [new RangedHighlight(new Range(2, 6), code())])];
            app.update(cx -> {
                final layout = InlineFlow.layoutFlow(items, [null], style, null, window, cx);
                final textFragments = texts(layout);
                assertEquals(3, textFragments.length);
                assertEquals(bodySize, textFragments[0].fontSize);
                assertEquals("code", textFragments[1].text);
                assertEquals(f32(bodySize * 0.875), textFragments[1].fontSize);
                // The code run's box stays inside the line, so whatever it
                // paints over its box cannot reach a neighboring line.
                assertTrue(textFragments[1].origin.y >= 0.);
                assertTrue(f32(textFragments[1].origin.y + textFragments[1].size.height) <= layout.size.height);
                assertEquals(f32(TextTestFonts.widthOf("code", TextTestFonts.MONO, f32(bodySize * 0.875)) + InlineFlow.INLINE_CODE_PADDING * 2.),
                    textFragments[1].size.width);

                // GPUI paints shaped lines with positive `LineLayout.descent`.
                // Derive the ordinary body glyph baseline directly from that
                // native-compatible shaped line, rather than `baselineOffset`,
                // whose FontMetrics descent is intentionally signed.
                final bodyRuns = InlineHighlight.textRuns(1, style, []);
                final bodyLine = InlineFlow.shapeLine("a", bodySize, bodyRuns, window);
                final bodyLineHeight = InlineFlow.plainLineHeight(style, window.remSize(), window);
                final bodyAscent:Float = bodyLine.ascent();
                final bodyDescent:Float = bodyLine.descent();
                final plainBodyBaseline = f32(f32(f32(f32((bodyLineHeight : Float) - bodyAscent) - bodyDescent) / 2.) + bodyAscent);
                // The smaller code run fits inside the body line, so the
                // line must be exactly as tall as a plain one.
                assertEquals(bodyLineHeight, layout.size.height, '${bodySize}px line height');
                function paintedGlyphBaseline(fragment:{text:String, origin:Point, size:Size, fontSize:Float, codeBackground:Null<CodeBox>}):Float {
                    final runs = fragment.text == "code" ? InlineHighlight.textRuns(Utf8.byteLength(fragment.text), style,
                        [new RangedHighlight(new Range(0, Utf8.byteLength(fragment.text)), code())]) : InlineHighlight.textRuns(Utf8.byteLength(fragment.text),
                            style, []);
                    final shaped = InlineFlow.shapeLine(fragment.text, fragment.fontSize, runs, window);
                    final ascent:Float = shaped.ascent();
                    final descent:Float = shaped.descent();
                    return f32(f32(fragment.origin.y + f32(f32(f32(fragment.size.height - ascent) - descent) / 2.)) + ascent);
                }

                // `origin` is passed unchanged to `Inline.paintOrigin`, so this
                // checks the first body glyph's painted row position, not only
                // the enclosing paragraph height. It must agree with a normal
                // body line and with the adjacent inline-code glyph baseline.
                assertEquals(0., textFragments[0].origin.y, '${bodySize}px body origin');
                assertEquals(plainBodyBaseline, paintedGlyphBaseline(textFragments[0]), '${bodySize}px body glyph baseline');
                assertEquals(plainBodyBaseline, paintedGlyphBaseline(textFragments[1]), '${bodySize}px code glyph baseline');
            });
        }
        window.destroy();
    }

}
