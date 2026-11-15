// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the rich text component of the kit and the
// additions to `InlineFlow` behind it (G12). See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.IntoElement;
import glaze.Point;
import glaze.Range;
import glaze.Size;
import glaze.StyleBuilder;
import glaze.TestDispatcher;
import glaze.TextStyle;
import glaze.Transformation;
import glaze.Window;
import glaze.kit.base.motion.Easing;
import glaze.kit.base.motion.Keyframes.Keyframe;
import glaze.kit.base.motion.MotionTransform;
import glaze.kit.base.motion.Stagger;
import glaze.kit.base.motion.Timing;
import glaze.kit.base.text.InlineFlow;
import glaze.kit.base.text.InlineFlow.InlineFlowLayout;
import glaze.kit.base.text.InlineFlow.MeasureItemTools;
import glaze.kit.base.text.InlineFlow.PositionedFragment;
import glaze.kit.base.text.InlineHighlight;
import glaze.kit.base.text.InlineMotion;
import glaze.kit.base.text.InlineMotion.InlineMotionFragment;
import glaze.kit.base.text.RangedHighlight;
import glaze.kit.text.RichText;
import glaze.kit.text.RichText.RichSpan;
import glaze.kit.text.RichText.RichTextAnimation;
import glaze.kit.text.RichText.RichTextStyle;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * `RichText` and the rich text fields of `InlineHighlight`: sizes mixed on
 * one baseline, boxes, letter spacing, case, alignment, the `pre-wrap` rule,
 * and spans animated without a new layout.
 */
class RichTextTest extends TestCase {

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
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), 800, 600);
        contexts.push(opened.cx);
        draw(opened.cx);
        return opened.cx;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    /** `seconds` later: the next frame callbacks, then a draw. Returns how many callbacks ran. */
    static function frame(cx:VisualTestContext, seconds:Float = 0.016):Int {
        cx.advanceClock(seconds);
        final ran = cx.update((window, app) -> window.simulateNextFrame(app));
        draw(cx);
        return ran;
    }

    /** The layout of `rich` wrapped at `wrapWidth`, in the window's text style. */
    function layout(rich:RichText, wrapWidth:Null<Float>, preWrap:Bool = false):InlineFlowLayout {
        final cx = contexts.length > 0 ? contexts[0] : open((_, _) -> div());
        return cx.update((window, app) -> {
            final items = [for (item in @:privateAccess rich.build()) MeasureItemTools.from(item)];
            final style = window.textStyle();
            final objects = @:privateAccess InlineFlow.prepareObjects(items, style, window, app);
            return @:privateAccess InlineFlow.layoutMeasuredFlow(items, [for (_ in items) null], objects, style, wrapWidth, window, app, preWrap);
        });
    }

    /** The text fragments of a layout: text, origin, size, font size, box. */
    static function texts(layout:InlineFlowLayout):Array<{text:String, origin:Point, size:Size, fontSize:Float, box:Null<Bounds>}> {
        return [for (fragment in @:privateAccess layout.fragments) switch fragment {
            case Text(_, origin, size, _, fontSize, text, _, _, _, box): {text: text, origin: origin, size: size, fontSize: fontSize, box: box != null ? box.bounds : null};
            case _: continue;
        }];
    }

    function bodyStyle():TextStyle {
        final cx = contexts.length > 0 ? contexts[0] : open((_, _) -> div());
        return cx.update((window, _) -> window.textStyle());
    }

    /** Width of `text` shaped alone in the body style at `fontSize`, with `letterSpacing` pixels after each character. */
    function shapedWidth(text:String, fontSize:Float, letterSpacing:Float = 0.):Float {
        final cx = contexts.length > 0 ? contexts[0] : open((_, _) -> div());
        return cx.update((window, _) -> {
            var run = window.textStyle().toRun(glaze.util.Utf8.byteLength(text));
            if (letterSpacing != 0.) run = run.withLetterSpacing(letterSpacing);
            return (window.textSystem().shapeLine(text, fontSize, [run]).width() : Float);
        });
    }

    static function near(a:Float, b:Float, epsilon:Float = 0.01):Bool {
        return Math.abs(a - b) <= epsilon;
    }

/// layout

    function testSizesMixedInOneLineShareTheBaseline() {
        final rich = RichText.component('sizes').spans([
            RichSpan.text('small '),
            RichSpan.text('BIG', new RichTextStyle().fontSize(Relative(2.))),
            RichSpan.text(' px', new RichTextStyle().fontSize(Absolute(10.))),
        ]);
        final fragments = texts(layout(rich, null));
        assertEquals('small |BIG| px', [for (f in fragments) f.text].join('|'));
        final body:Float = fragments[0].fontSize;
        assertEquals(body * 2., fragments[1].fontSize);
        assertEquals(10., fragments[2].fontSize);
        // The baseline of a fragment: its glyphs are centered in its box.
        final cx = contexts[0];
        final baselines = [for (f in fragments) cx.update((window, _) -> {
            final line = window.textSystem().shapeLine(f.text, f.fontSize, [window.textStyle().toRun(glaze.util.Utf8.byteLength(f.text))]);
            final ascent:Float = line.ascent();
            final descent:Float = line.descent();
            return f.origin.y + (f.size.height - ascent - descent) / 2. + ascent;
        })];
        assertTrue(near(baselines[0], baselines[1]) && near(baselines[0], baselines[2]), 'baselines $baselines');
        // One after the other, on one line as tall as its biggest glyphs need.
        assertTrue(near(fragments[1].origin.x, fragments[0].origin.x + fragments[0].size.width));
        assertTrue(fragments[1].size.width > shapedWidth('BIG', body) * 1.9);
    }

    function testABoxSurroundsItsTextWithPaddingBorderAndMargin() {
        final box = StyleBuilder.build(s -> s.px(px(6.)).py(px(2.)).border1().ml(px(4.)).mr(px(8.)).rounded(px(5.)));
        final rich = RichText.component('pill').spans([
            RichSpan.text('a '),
            RichSpan.box('tag', new RichTextStyle().box(box).background(hsla(0.5, 0.5, 0.5, 1.))),
            RichSpan.text(' b'),
        ]);
        final fragments = texts(layout(rich, null));
        assertEquals('a |tag| b', [for (f in fragments) f.text].join('|'));
        final pill = fragments[1];
        final textWidth = shapedWidth('tag', pill.fontSize);
        // margin 4 + border 1 + padding 6, text, padding 6 + border 1 + margin 8
        assertTrue(near(pill.size.width, textWidth + 26.), 'pill width ${pill.size.width} for a text of $textWidth');
        assertNotNull(pill.box);
        // The box is inside the margins, around paddings and borders.
        assertTrue(near(pill.box.left(), pill.origin.x + 4.));
        assertTrue(near(pill.box.size.width, textWidth + 14.));
        final cx = contexts[0];
        final glyphHeight = cx.update((window, _) -> {
            final line = window.textSystem().shapeLine('tag', pill.fontSize, [window.textStyle().toRun(3)]);
            return (line.ascent() : Float) + (line.descent() : Float);
        });
        assertTrue(near(pill.box.size.height, glyphHeight + 6.), 'box height ${pill.box.size.height} for glyphs of $glyphHeight');
        // The text after the pill starts after its right margin.
        assertTrue(near(fragments[2].origin.x, pill.origin.x + pill.size.width));
    }

    function testABoxIsNeverBrokenAcrossLines() {
        final box = StyleBuilder.build(s -> s.px(px(4.)));
        final rich = RichText.component('pill').spans([
            RichSpan.text('one two three '),
            RichSpan.box('a pill of several words', new RichTextStyle().box(box)),
        ]);
        final fragments = texts(layout(rich, 150.));
        final pill = fragments[fragments.length - 1];
        assertEquals('a pill of several words', pill.text);
        assertTrue(pill.origin.y > fragments[0].origin.y, 'the pill goes to its own line');
        // The same words without a box wrap.
        final plain = texts(layout(RichText.component('plain').spans([RichSpan.text('one two three a pill of several words')]), 150.));
        assertTrue(plain.length >= 2);
        assertFalse(Lambda.exists(plain, f -> f.text.indexOf('a pill of several words') != -1));
    }

    function testLetterSpacingWidensASpan() {
        final spaced = (spacing:Null<glaze.kit.text.RichText.RichLength>) -> {
            final style = new RichTextStyle().fontWeight(glaze.FontWeight.NORMAL);
            if (spacing != null) style.letterSpacing(spacing);
            return texts(layout(RichText.component('spaced').spans([RichSpan.text('spaced', style)]), null))[0];
        };
        final plain = spaced(null);
        final px3 = spaced(Absolute(3.));
        assertTrue(near(px3.size.width, plain.size.width + 6 * 3.), 'spaced ${px3.size.width}, plain ${plain.size.width}');
        final em = spaced(Em(0.25));
        assertTrue(near(em.size.width, plain.size.width + 6 * 0.25 * plain.fontSize), 'em ${em.size.width}');
        // The em follows the span's own size.
        final big = texts(layout(RichText.component('big').spans([
            RichSpan.text('spaced', new RichTextStyle().fontSize(Relative(2.)).letterSpacing(Em(0.25)))]), null))[0];
        assertTrue(near(big.size.width, shapedWidth('spaced', plain.fontSize * 2., 0.25 * plain.fontSize * 2.)), 'big ${big.size.width}');
    }

    function testASpacedSpanIsMeasuredForWrapping() {
        // Wide letter spacing makes a line that fits as plain text overflow: it has to wrap.
        final width = shapedWidth('aaaa bbbb cccc', 16.) + 4.;
        final plain = texts(layout(RichText.component('plain').spans([RichSpan.text('aaaa bbbb cccc')]), width));
        assertEquals(1, plain.length);
        final spaced = texts(layout(RichText.component('spaced').spans([
            RichSpan.text('aaaa bbbb cccc', new RichTextStyle().letterSpacing(Absolute(6.)))]), width));
        assertTrue(spaced.length > 1, 'the spaced line wraps');
        for (fragment in spaced) assertTrue(fragment.size.width <= width + 6.5, 'a line of ${fragment.size.width} in $width');
        // And so does a bigger size.
        final big = texts(layout(RichText.component('big').spans([
            RichSpan.text('aaaa bbbb cccc', new RichTextStyle().fontSize(Relative(2.)))]), width));
        assertTrue(big.length > 1, 'the bigger line wraps');
    }

    function testTextTransformChangesTheTextAndItsLength() {
        assertEquals('STRASSE ÉTÉ ΑΒΓ', InlineMotion.transformText('straße été αβγ', Uppercase));
        assertEquals('straße été', InlineMotion.transformText('STRAßE ÉTÉ', Lowercase));
        assertEquals('Hello Wide World', InlineMotion.transformText('hello wide world', Capitalize));
        assertEquals('same', InlineMotion.transformText('same', None));

        final rich = RichText.component('upper').spans([
            RichSpan.text('die '),
            RichSpan.text('straße', new RichTextStyle().textTransform(Uppercase).fontWeight(glaze.FontWeight.BOLD)),
            RichSpan.text(' ist ', new RichTextStyle().color(hsla(0., 1., 0.5, 1.))),
            RichSpan.text('lang'),
        ]);
        assertEquals('die STRASSE ist lang', rich.plainText());
        // The ranges of the styles follow the longer text.
        final item = @:privateAccess rich.build()[0];
        switch item {
            case Text(_, _, _, highlights, _, _):
                assertEquals('4..11,11..16', [for (h in highlights) '${h.range.start}..${h.range.end}'].join(','));
            case _:
                fail('one text item expected');
        }
    }

    function testWhiteSpaceRules() {
        final spans = [RichSpan.text('  two   words \n'), RichSpan.text('  and more  '), RichSpan.lineBreak(), RichSpan.text(' next')];
        assertEquals('two words and more \nnext', RichText.component('normal').spans(spans).plainText());
        assertEquals('  two   words \n  and more  \n next', RichText.component('pre').whiteSpace(PreWrap).spans(spans).plainText());
    }

    function testPreWrapLetsTheSpacesThatEndALineHang() {
        // "aaaa bbbb" fits the width exactly, the two spaces after it do not.
        final width = shapedWidth('aaaa bbbb', 16.) + 1.;
        final rich = RichText.component('pre').whiteSpace(PreWrap).spans([RichSpan.text('aaaa bbbb  cccc')]);
        final hanging = texts(layout(rich, width, true));
        assertEquals('aaaa bbbb  |cccc', [for (f in hanging) f.text].join('|'));
    }

    function testTextAlignMovesTheLines() {
        final lefts = (align:glaze.TextAlign) -> {
            final cx = open((_, _) -> div().w(px(300.)).child(RichText.component('aligned').textAlign(align).spans([
                RichSpan.text('short'),
                RichSpan.lineBreak(),
                RichSpan.text('a longer line'),
            ])));
            // The left edge of the glyphs of each line.
            return cx.update((window, _) -> {
                final scale = window.scaleFactor();
                final byLine = new Map<Int, Float>();
                for (sprite in window.renderedScene().monochromeSprites) {
                    final line = Math.round(sprite.boundsY / scale / 10.);
                    final x = sprite.boundsX / scale;
                    if (!byLine.exists(line) || x < byLine.get(line)) byLine.set(line, x);
                }
                final keys = [for (key in byLine.keys()) key];
                keys.sort((a, b) -> a - b);
                return [byLine.get(keys[0]), byLine.get(keys[keys.length - 1])];
            });
        };
        final shortWidth = shapedWidth('short', 16.);
        final longWidth = shapedWidth('a longer line', 16.);
        final left = lefts(Left);
        final center = lefts(Center);
        final right = lefts(Right);
        assertTrue(near(left[0], left[1], 1.5), 'left $left');
        assertTrue(near(center[0] - left[0], (300. - shortWidth) / 2., 1.5), 'center $center');
        assertTrue(near(center[1] - left[1], (300. - longWidth) / 2., 1.5), 'center $center');
        assertTrue(near(right[0] - left[0], 300. - shortWidth, 1.5), 'right $right');
        assertTrue(near(right[1] - left[1], 300. - longWidth, 1.5), 'right $right');
    }

/// animation

    static function wave():RichTextAnimation {
        return RichTextAnimation.of([
            new Keyframe(0., MotionTransform.identity()),
            new Keyframe(0.5, new MotionTransform(new Point(0., -0.25), new Point(1., 1.), 0.1, 1.)),
            new Keyframe(1., MotionTransform.identity()),
        ], new Timing(1.).ease(Easing.Linear).iterations(Infinite)).translationInEm();
    }

    function testAWordAnimatedPerCharacterIsNotBroken() {
        final style = new RichTextStyle().animation(wave().perCharacter(new Stagger(0.05, First)));
        final word = 'unbreakableword';
        final width = shapedWidth(word, 16.) * 0.6;
        final animated = texts(layout(RichText.component('wave').spans([RichSpan.text('go ' + word + ' on', style)]), width));
        assertTrue(Lambda.exists(animated, f -> f.text.indexOf(word) != -1), 'the word stays whole: ${[for (f in animated) f.text]}');
        // Without the animation the word is cut where the line ends.
        final plain = texts(layout(RichText.component('plain').spans([RichSpan.text('go ' + word + ' on')]), width));
        assertFalse(Lambda.exists(plain, f -> f.text.indexOf(word) != -1));
    }

    function animatedWindow(animation:RichTextAnimation):VisualTestContext {
        return open((_, _) -> div().w(px(400.)).child(RichText.component('animated').spans([
            RichSpan.text('before '),
            RichSpan.text('wave', new RichTextStyle().animation(animation)),
            RichSpan.text(' after'),
        ])));
    }

    function testAnAnimatedSpanMovesWithoutANewLayout() {
        final cx = animatedWindow(wave().perCharacter(new Stagger(0.1, First)));
        draw(cx);
        final layouts = InlineFlow.FLOW_LAYOUTS;
        final seen:Array<String> = [];
        var transformed = InlineMotionFragment.TRANSFORMED_GLYPHS;
        for (_ in 0...8) {
            assertTrue(frame(cx, 0.05) > 0, 'the animated span asks for the next frame');
            final samples = InlineMotionFragment.LAST_SAMPLES;
            assertEquals(4, samples.length);
            seen.push([for (sample in samples) Math.round(sample.translation.y * 100) / 100].join(','));
        }
        assertEquals(layouts, InlineFlow.FLOW_LAYOUTS);
        assertTrue(InlineMotionFragment.TRANSFORMED_GLYPHS > transformed);
        // The frames differ, and the characters are out of phase.
        assertTrue(seen[1] != seen[3], 'frames $seen');
        final last = InlineMotionFragment.LAST_SAMPLES;
        assertTrue(last[0].translation.y != last[1].translation.y);
        // Translations are in em of the 16 px text: a quarter of an em at most.
        for (sample in last) assertTrue(sample.translation.y <= 0. && sample.translation.y >= -4.);
    }

    function testARunAnimatedAsAWholeTakesOneTransform() {
        final cx = animatedWindow(wave());
        draw(cx);
        final layouts = InlineFlow.FLOW_LAYOUTS;
        frame(cx, 0.25);
        assertEquals(1, InlineMotionFragment.LAST_SAMPLES.length);
        assertTrue(near(InlineMotionFragment.LAST_SAMPLES[0].translation.y, -2., 0.3), '${InlineMotionFragment.LAST_SAMPLES[0]}');
        assertEquals(layouts, InlineFlow.FLOW_LAYOUTS);
    }

    function testTheBoxOfARunAnimatedAsAWholeMovesWithIt() {
        final fill = hsla(0.6, 0.8, 0.5, 1.);
        final rise = RichTextAnimation.of([
            new Keyframe(0., MotionTransform.identity()),
            new Keyframe(0.5, new MotionTransform(new Point(0., -4.), new Point(1., 1.), 0., 1.)),
            new Keyframe(1., MotionTransform.identity()),
        ], new Timing(1.).ease(Easing.Linear).iterations(Infinite));
        final cx = open((_, _) -> div().w(px(400.)).child(RichText.component('pill').spans([
            RichSpan.text('a '),
            RichSpan.box('pill', new RichTextStyle().box(StyleBuilder.build(s -> s.px(px(4.)).bg(fill).rounded(px(3.)))).animation(rise)),
        ])));
        final boxTop = () -> cx.update((window, _) -> {
            for (quad in window.renderedScene().quads) {
                if (quad.backgroundTag == 0 && Math.abs(quad.backgroundSolidH - fill.h) < 0.001 && Math.abs(quad.backgroundSolidL - fill.l) < 0.001
                    && quad.backgroundSolidA > 0.9) {
                    return quad.boundsY / window.scaleFactor();
                }
            }
            return Math.NaN;
        });
        draw(cx);
        final rest = boxTop();
        assertFalse(Math.isNaN(rest));
        frame(cx, 0.5);
        assertTrue(near(boxTop(), rest - 4., 0.6), 'the box went from $rest to ${boxTop()}');
        frame(cx, 0.5);
        assertTrue(near(boxTop(), rest, 0.6), 'the box is back at ${boxTop()}');
    }

    function testAnotherAnimationOfTheSameShapeKeepsTheLayout() {
        var animation = wave();
        final cx = open((_, _) -> div().w(px(400.)).child(RichText.component('swap').spans([
            RichSpan.text('wave', new RichTextStyle().animation(animation)),
        ])));
        draw(cx);
        final layouts = InlineFlow.FLOW_LAYOUTS;
        // A new descriptor on every render, as an application building its spans does.
        animation = wave();
        cx.update((window, app) -> window.refresh());
        draw(cx);
        assertEquals(layouts, InlineFlow.FLOW_LAYOUTS);
    }

    function testAFiniteAnimationStopsAskingForFrames() {
        final once = RichTextAnimation.of([
            new Keyframe(0., MotionTransform.identity()),
            new Keyframe(1., new MotionTransform(new Point(0., -4.), new Point(1., 1.), 0., 1.)),
        ], new Timing(0.2));
        final cx = animatedWindow(once);
        draw(cx);
        assertTrue(frame(cx, 0.1) > 0);
        frame(cx, 0.2);
        assertEquals(0, frame(cx, 0.1));
    }

    function testReducedMotionShowsTheTextStill() {
        app.update(cx -> cx.setReduceMotion(true));
        final cx = animatedWindow(wave().perCharacter(new Stagger(0.1, First)));
        final transformed = InlineMotionFragment.TRANSFORMED_GLYPHS;
        draw(cx);
        assertEquals(0, frame(cx, 0.3));
        assertEquals(transformed, InlineMotionFragment.TRANSFORMED_GLYPHS);
        // The glyphs of the animated word are painted all the same.
        final glyphs = cx.update((window, _) -> window.renderedScene().monochromeSprites.length);
        assertEquals('beforewaveafter'.length, glyphs);
    }

    function testAFixedTransformationDoesNotMoveTheTextAroundIt() {
        final build = (transformed:Bool) -> {
            final style = new RichTextStyle().color(hsla(0.3, 1., 0.4, 1.));
            if (transformed) style.transformation(Transformation.translated(new Point(0., -5.)));
            return texts(layout(RichText.component('fixed').spans([RichSpan.text('a '), RichSpan.text('up', style), RichSpan.text(' b')]), null));
        };
        final plain = build(false);
        final moved = build(true);
        assertEquals('a |up| b', [for (f in moved) f.text].join('|'));
        // The line is as wide as without the transformation (the span is shaped apart, so kerning aside).
        final width = (fragments:Array<{text:String, origin:Point, size:Size, fontSize:Float, box:Null<Bounds>}>) -> {
            final last = fragments[fragments.length - 1];
            return last.origin.x + last.size.width;
        };
        assertTrue(near(width(plain), width(moved), 1.), 'plain ${width(plain)}, moved ${width(moved)}');
        assertTrue(near(plain[0].origin.y, moved[1].origin.y, 0.01));
    }

    /**
     * The engine's rule for inline objects, unchanged: an object is rendered
     * anew every frame, so a flow holding one is laid out on every frame it
     * is drawn (twice: taffy measures it at two widths).
     */
    function testAParagraphWithAnInlineElementIsLaidOutOnEveryFrame() {
        final cx = open((_, _) -> div().w(px(400.)).child(RichText.component('element').wFull().spans([
            RichSpan.text('a '),
            RichSpan.element(div().size(px(10.))),
            RichSpan.text(' b'),
        ])));
        draw(cx);
        final layouts = InlineFlow.FLOW_LAYOUTS;
        for (_ in 0...5) {
            cx.update((window, _) -> window.refresh());
            draw(cx);
        }
        assertEquals(10, InlineFlow.FLOW_LAYOUTS - layouts);
    }

/// the gallery page

    function testTheGalleryPageDrawsAndAnimatesWithoutANewLayout() {
        var page:Null<glaze.Entity<story.stories.RichTextStory>> = null;
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, cx) -> {
            page = story.stories.RichTextStory.view(window, cx);
            return page;
        }, 900, 2400);
        contexts.push(opened.cx);
        final cx = opened.cx;
        draw(cx);
        draw(cx);
        final glyphs = cx.update((window, _) -> window.renderedScene().monochromeSprites.length);
        assertTrue(glyphs > 300, '$glyphs glyphs');
        final layouts = InlineFlow.FLOW_LAYOUTS;
        final transformed = InlineMotionFragment.TRANSFORMED_GLYPHS;
        for (_ in 0...5) assertTrue(frame(cx, 0.05) > 0);
        // The engine never reuses the layout of a flow holding an inline
        // object (the paragraph with the icon, see the test above). The
        // animated paragraph and the others add none.
        assertEquals(10, InlineFlow.FLOW_LAYOUTS - layouts);
        assertTrue(InlineMotionFragment.TRANSFORMED_GLYPHS > transformed);
        assertEquals(glyphs, cx.update((window, _) -> window.renderedScene().monochromeSprites.length));
    }

/// the markdown code chip is untouched

    function testAHighlightWithoutRichFieldsIsUnchanged() {
        final highlight = new InlineHighlight(null, 'Menlo', 0.875);
        assertFalse(@:privateAccess highlight.isRich());
        assertFalse(@:privateAccess highlight.measuresApart());
        assertTrue(highlight.equals(highlight.clone()));
        // The code chip keeps its own insets: 4 px on each side, none above or below.
        final insets = @:privateAccess highlight.codeInsets(14., 16.);
        assertEquals('0,4,0,4', '${insets.top},${insets.right},${insets.bottom},${insets.left}');
        final ranges = InlineHighlight.textSizeRanges(10, [new RangedHighlight(new Range(2, 5), highlight), new RangedHighlight(new Range(5, 8), highlight.clone())], 16., 16.);
        // Two adjacent code spans of one size still make one fragment.
        assertEquals('0..2,2..8,8..10', [for (r in ranges) '${r.range.start}..${r.range.end}'].join(','));
    }

}
