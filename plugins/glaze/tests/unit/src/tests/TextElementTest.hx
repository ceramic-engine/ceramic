package tests;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.HighlightStyle;
import gpui.HighlightStyle.TextHighlight;
import gpui.InteractiveText;
import gpui.IntoElement;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseUpEvent;
import gpui.StyledText;
import gpui.TestDispatcher;
import gpui.Text;
import gpui.TextLayout;
import gpui.Window;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Tests of the text elements (`src/elements/text.rs`): strings as elements,
 * `text()` ids, `StyledText` runs and highlights, `TextLayout` hit testing,
 * text style inheritance, truncation and `InteractiveText` clicks.
 */
class TextElementTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):Entity<TextTestView> {
        var view:Entity<TextTestView> = null;
        window = Window.open(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
            view = cx.newEntity((_:Context<TextTestView>) -> new TextTestView(render));
            return view;
        });
        return view;
    }

    /** Rust `test_into_element_for` */
    function testIntoElementFor() {
        final _ = div().child('static str');
        final _ = div().child('String' + '');
        final element:IntoElement = 'SharedString';
        assertTrue(element != null);
    }

    /** Rust `text_macro_id` */
    function testTextMacroId() {
        // one call to `text()` = one id
        function makeTextStableId(happy:Bool):Text {
            return text(happy ? 'happy' : 'sad');
        }

        // two calls to `text()` = two ids
        function makeTextUnstableId(happy:Bool):Text {
            if (happy)
                return text('happy');
            else
                return text('sad');
        }

        assertTrue(Type.enumEq(makeTextStableId(false).textId(), makeTextStableId(true).textId()));
        assertFalse(Type.enumEq(makeTextUnstableId(false).textId(), makeTextUnstableId(true).textId()));
    }

    function testStringChildPaintsGlyphsWithInheritedStyle() {
        open((window, cx) -> div().textColor(red()).fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child('Hello'));
        window.draw();
        final sprites = window.renderedScene().monochromeSprites;
        // H, e, l, l, o
        assertEquals(5, sprites.length);
        for (sprite in sprites) {
            assertEquals(1.0, sprite.colorA);
            assertEquals(0.0, sprite.colorH);
            assertEquals(1.0, sprite.colorS);
            // the baseline of a 20px line at 16px is below the top
            assertTrue(sprite.boundsY > 0 && sprite.boundsY < 40);
        }
        // glyphs advance left to right
        for (i in 1...sprites.length) {
            assertTrue(sprites[i].boundsX > sprites[i - 1].boundsX);
        }
    }

    function testTextWrapsAtTheWidthOfItsParent() {
        var layout:TextLayout = null;
        open((window, cx) -> {
            final styled = new StyledText('The quick brown fox jumps over the lazy dog.');
            layout = styled.layout();
            return div().w(px(100)).fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child(styled);
        });
        window.draw();
        assertTrue(layout.measured);
        assertEquals(20.0, layout.lineHeight());
        final wrapped = layout.wrappedText();
        assertTrue(wrapped.indexOf('\n') > 0, 'wrapped: $wrapped');
        final lines = wrapped.split('\n');
        assertEquals(layout.bounds().size.height, lines.length * 20.0);
        assertTrue(layout.bounds().size.width <= 100);
        assertEquals('The quick brown fox jumps over the lazy dog.', layout.text());
    }

    function testHitTestingMapsPositionsAndIndices() {
        var layout:TextLayout = null;
        open((window, cx) -> {
            final styled = new StyledText('first line\nsecond');
            layout = styled.layout();
            return div().p(px(10)).fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child(styled);
        });
        window.draw();
        final bounds = layout.bounds();
        assertEquals(10.0, bounds.origin.x);
        assertEquals(10.0, bounds.origin.y);
        // Start of the first line
        assertTrue(layout.indexForPosition(point(10.5, 15)).match(Ok(0)));
        // Above the text
        assertTrue(layout.indexForPosition(point(20, 0)).match(Err(0)));
        // Start of the second line (byte 11, after the newline)
        assertTrue(layout.indexForPosition(point(10.5, 35)).match(Ok(11)));
        // Below the text: end
        assertTrue(layout.indexForPosition(point(20, 200)).match(Err(17)));
        // Positions
        final p0 = layout.positionForIndex(0);
        assertEquals(10.0, p0.x);
        assertEquals(10.0, p0.y);
        final p11 = layout.positionForIndex(11);
        assertEquals(10.0, p11.x);
        assertEquals(30.0, p11.y);
        final p5 = layout.positionForIndex(5);
        assertTrue(p5.x > 10.0);
        assertEquals(10.0, p5.y);
        assertEquals(null, layout.positionForIndex(100));
        assertTrue(layout.lineLayoutForIndex(13) != null);
        assertEquals(2, layout.lineLayouts().length);
        assertEquals(17, layout.len());
    }

    function testTruncateEndsWithAnEllipsis() {
        var layout:TextLayout = null;
        open((window, cx) -> {
            final styled = new StyledText('This line is truncated with an ellipsis at the end');
            layout = styled.layout();
            return div().w(px(120)).truncate().fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child(styled);
        });
        window.draw();
        final shown = layout.text();
        assertTrue(StringTools.endsWith(shown, '…'), shown);
        assertTrue(shown.length < 30);
        assertEquals(20.0, layout.bounds().size.height);
    }

    function testLineClampLimitsTheNumberOfLines() {
        var layout:TextLayout = null;
        open((window, cx) -> {
            final styled = new StyledText('A long paragraph limited to two lines with line clamp, the rest of it is cut off here.');
            layout = styled.layout();
            return div().w(px(150)).lineClamp(2).textEllipsis().fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child(styled);
        });
        window.draw();
        assertEquals(2, layout.wrappedText().split('\n').length);
        assertTrue(StringTools.endsWith(layout.text(), '…'));
    }

    function testHighlightsComputeRunsOverTheInheritedStyle() {
        open((window, cx) -> div().textColor(white()).fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child(
            new StyledText('Hello world').withHighlights([
                new TextHighlight(0, 5, HighlightStyle.ofColor(red())),
                new TextHighlight(6, 11, {underline: new gpui.UnderlineStyle(1.0, blue(), false)})
            ])
        ));
        window.draw();
        final scene = window.renderedScene();
        final sprites = scene.monochromeSprites;
        assertEquals(10, sprites.length);
        // "Hello" is red (white blended with opaque red)
        assertEquals(1.0, sprites[0].colorS);
        assertEquals(0.5, sprites[0].colorL);
        // "world" is white
        assertEquals(1.0, sprites[9].colorL);
        assertEquals(1, scene.underlines.length);
        // blue
        assertTrue(Math.abs(scene.underlines[0].colorH - 2 / 3) < 1e-3);
    }

    function testCombineHighlights() {
        final a = [new TextHighlight(0, 10, HighlightStyle.ofColor(red()))];
        final b = [new TextHighlight(5, 15, HighlightStyle.ofFontWeight(gpui.FontWeight.BOLD))];
        final combined = HighlightStyle.combineHighlights(a, b);
        assertEquals(3, combined.length);
        assertEquals(0, combined[0].start);
        assertEquals(5, combined[0].end);
        assertEquals(null, combined[0].style.fontWeight);
        assertEquals(5, combined[1].start);
        assertEquals(10, combined[1].end);
        assertTrue(combined[1].style.color != null);
        assertEquals((gpui.FontWeight.BOLD:Float), (combined[1].style.fontWeight:Float));
        assertEquals(10, combined[2].start);
        assertEquals(15, combined[2].end);
        assertEquals(null, combined[2].style.color);
    }

    function testFontFamilyOverrides() {
        var layout:TextLayout = null;
        open((window, cx) -> {
            // Overrides apply to whole runs: the highlight splits the text in two runs
            final styled = new StyledText('abc def')
                .withHighlights([new TextHighlight(4, 7, HighlightStyle.ofColor(red()))])
                .withFontFamilyOverrides([new gpui.StyledText.FontFamilyOverride(4, 7, 'JetBrains Mono')]);
            layout = styled.layout();
            return div().fontFamily('Inter').textSize(px(16)).child(styled);
        });
        window.draw();
        final runs = layout.lineLayouts()[0].unwrappedLayout.runs;
        assertEquals(2, runs.length);
        assertEquals('Inter', TextFixtures.familyOf(runs[0].fontId));
        assertEquals('JetBrains Mono', TextFixtures.familyOf(runs[1].fontId));
    }

    function testInteractiveTextClickOnRanges() {
        final clicks:Array<Int> = [];
        open((window, cx) -> div().fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child(
            new InteractiveText('links', new StyledText('one two three')).onClick([new gpui.InteractiveText.TextRange(0, 3), new gpui.InteractiveText.TextRange(8, 13)], (ix, window, cx) -> clicks.push(ix))
        ));
        window.draw();
        // Click on "one"
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(5, 10)), app);
        window.draw();
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(5, 10)), app);
        window.draw();
        assertEquals('0', clicks.join(','));
        // Click on "two": no range
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(40, 10)), app);
        window.draw();
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(40, 10)), app);
        window.draw();
        assertEquals('0', clicks.join(','));
    }

}

class TextTestView extends gpui.Model implements gpui.Render {

    public var renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}
