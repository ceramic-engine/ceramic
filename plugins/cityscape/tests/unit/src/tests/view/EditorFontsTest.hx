// New code for Cityscape (not a port): the editor fonts, metrics and gutter
// layout of an editor rendered by Glaze, against values recorded from the
// real Monaco (loreline-monaco's recorder, Monaco 0.52.2 in Chromium on macOS).
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.view.EditorFontMeasurements;
import glaze.App;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.instantiateTextModel;

import glaze.Prelude.*;

class EditorFontsTestHost extends glaze.Component {

    final model:ITextModel;
    final options:IEditorOptions;
    final onEditor:(editor:CityscapeEditor) -> Void;

    public function new(model:ITextModel, options:IEditorOptions, onEditor:(editor:CityscapeEditor) -> Void) {
        super();
        this.model = model;
        this.options = options;
        this.onEditor = onEditor;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull().child(CityscapeEditor.component().model(model).options(options).onCreate(onEditor).flex1());
    }

}

/**
 * Two editors side by side, the left one with a long line.
 */
class EditorClipTestHost extends glaze.Component {

    final left:ITextModel;
    final right:ITextModel;
    final onLeft:(editor:CityscapeEditor) -> Void;

    public function new(left:ITextModel, right:ITextModel, onLeft:(editor:CityscapeEditor) -> Void) {
        super();
        this.left = left;
        this.right = right;
        this.onLeft = onLeft;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().flexRow().sizeFull()
            .child(CityscapeEditor.component().model(left).options({wordWrap: 'off'}).onCreate(onLeft).flex1())
            .child(CityscapeEditor.component().model(right).flex1());
    }

}

class EditorFontsTest extends TestCase {

    var app:App;
    var context:Cityscape;
    var window:Null<Window> = null;
    var editor:Null<CityscapeEditor> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
        context = new Cityscape();
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open(text:String, options:IEditorOptions):CityscapeEditor {
        final model = instantiateTextModel(context, text);
        window = Window.open(app, {width: 1000, height: 700, scaleFactor: 2, autoDraw: false, bindInput: false},
            EditorFontsTestHost.component(model, options, e -> editor = e));
        app.update(_ -> window.draw());
        return editor;
    }

    /**
     * The gutter of Monaco at font size 14 with the default options
     * (folding on): recorded by the chevrons probe of the recorder
     * (1000 x 700 editor): line numbers 0 to 42, decorations (folding) 42
     * to 68, content from 68, line height 21 (Monaco's golden ratio 1.5 on
     * macOS, 1.35 elsewhere). Monaco's default font is asked explicitly
     * (Cityscape's own default is the bundled JetBrains Mono).
     */
    function testGutterLayoutAtFontSize14() {
        final e = open('def first():\n    a = 1\n', {fontSize: 14, showFoldingControls: 'always', fontFamily: EditorOptions.EDITOR_FONT_DEFAULTS.fontFamily});
        final layout = e.getLayoutInfo();
        final fontInfo = e.getOption(EditorOption.fontInfo);
        trace('layout: lineNumbers ' + layout.lineNumbersLeft + '+' + layout.lineNumbersWidth + ' decorations ' + layout.decorationsLeft + '+' + layout.decorationsWidth + ' contentLeft ' + layout.contentLeft + ' lineHeight ' + fontInfo.lineHeight + ' n ' + fontInfo.typicalHalfwidthCharacterWidth + ' digit ' + fontInfo.maxDigitWidth);
        if (cityscape.base.common.Platform.isMacintosh) {
            assertEquals(21, fontInfo.lineHeight);
        }
        assertEquals(0.0, layout.lineNumbersLeft);
        assertEquals(42.0, layout.lineNumbersWidth);
        assertEquals(42.0, layout.decorationsLeft);
        assertEquals(26.0, layout.decorationsWidth);
        assertEquals(68.0, layout.contentLeft);
    }

    /**
     * Without a `fontFamily` from the host, the editor uses Glaze's bundled
     * monospace font on every target (owner decision 2026-11-10); a system
     * font is used when the host asks for it.
     */
    function testDefaultFontIsTheBundledMonospaceFont() {
        final e = open('a\n', {fontSize: 14});
        assertEquals(CityscapeEditor.DEFAULT_FONT_FAMILY, e.getOption(EditorOption.fontInfo).fontFamily);
        assertEquals('JetBrains Mono', e.getOption(EditorOption.fontInfo).fontFamily);
        final explicit = open('a\n', {fontSize: 14, fontFamily: 'Menlo, monospace'});
        assertEquals('Menlo, monospace', explicit.getOption(EditorOption.fontInfo).fontFamily);
    }

    function glyphIds(font:glaze.Font, text:String):Array<Int> {
        final ts = app.textSystem();
        final layout = ts.platformTextSystem.layoutLine(text, 14, [new glaze.FontRun(glaze.util.Utf8.byteLength(text), ts.resolveFont(font))]);
        return [for (run in layout.runs) for (g in run.glyphs) (g.id : Int)];
    }

    /**
     * `fontLigatures` reaches the shaper: the bundled JetBrains Mono joins
     * `//` through `calt` with ligatures on (`true`, Monaco's `'"liga" on,
     * "calt" on'`) or `'"liga" off, "calt" on'` (loreline-monaco's default
     * string, kept as given by Monaco's validation), and not with Monaco's
     * default (`'"liga" off, "calt" off'`).
     */
    function testLigaturesReachTheShaper() {
        final measurements = new EditorFontMeasurements(app.textSystem());
        final ligatures = new EditorFontLigatures();
        assertEquals('"liga" on, "calt" on', ligatures.validate(true));
        assertEquals('"liga" off, "calt" on', ligatures.validate('"liga" off, "calt" on'));
        assertEquals('"liga" off, "calt" off', ligatures.validate(false));
        final on = EditorFontMeasurements.parseFontFeatureSettings(ligatures.validate(true));
        final calt = EditorFontMeasurements.parseFontFeatureSettings(ligatures.validate('"liga" off, "calt" on'));
        final off = EditorFontMeasurements.parseFontFeatureSettings(ligatures.validate(false));
        final slash = glyphIds(measurements.resolveEditorFont('JetBrains Mono', 400, false, off), '/')[0];
        assertFalse(glyphIds(measurements.resolveEditorFont('JetBrains Mono', 400, false, on), '//').join(',') == slash + ',' + slash, 'ligatures on');
        assertFalse(glyphIds(measurements.resolveEditorFont('JetBrains Mono', 400, false, calt), '//').join(',') == slash + ',' + slash, 'calt on');
        assertEquals(slash + ',' + slash, glyphIds(measurements.resolveEditorFont('JetBrains Mono', 400, false, off), '//').join(','));
    }

    /**
     * Cityscape's `overviewRulerPosition: 'beside'`: the overview ruler in
     * its own column left of the vertical scrollbar, `overviewRulerGap`
     * apart. loreline-monaco moves Monaco's ruler with its style sheet
     * (`right: scrollbarSize + 2px`, the `verticalScrollbarSize` it gives):
     * in its J2 captures (1000 x 700) the cursor mark covers x 980 to 990,
     * the scrollbar 990 to 1000, and the layout (content width, wrapping
     * column) is Monaco's.
     */
    function testOverviewRulerBesideTheScrollbar() {
        final text = [for (i in 0...30) 'line $i with some words to wrap at the end of the viewport, line $i with some words'].join('\n');
        final scrollbar = {verticalScrollbarSize: 10, verticalSliderSize: 8, horizontalScrollbarSize: 10, horizontalSliderSize: 8};
        inline function rulerRight(e:CityscapeEditor):Float {
            return cityscape.common.config.EditorViewOptions.OverviewRulerPlacement.right(e.getOptions());
        }
        final overlay = open(text, {fontSize: 14, wordWrap: 'on', scrollbar: scrollbar});
        final overlayLayout = overlay.getLayoutInfo();
        assertEquals(0.0, rulerRight(overlay));
        assertEquals(0.0, overlayLayout.overviewRuler.right);
        assertEquals(10.0, overlayLayout.overviewRuler.width);
        assertEquals('overlay', overlay.getOption(EditorOption.overviewRulerPosition));
        assertEquals(0.0, overlay.getOption(EditorOption.overviewRulerGap));
        final overlayView:cityscape.view.CityscapeView = overlay.getView();
        final y = overlayView.elementBounds.origin.y + 5;
        assertTrue(overlayView.mouseTargetAt(point(overlayView.elementBounds.origin.x + 985, y)).type != cityscape.view.EditorBrowser.MouseTargetType.SCROLLBAR, 'text under x 985 by default');
        window.destroy();
        window = null;

        final beside = open(text, {fontSize: 14, wordWrap: 'on', scrollbar: scrollbar, overviewRulerPosition: 'beside'});
        final layout = beside.getLayoutInfo();
        assertEquals(10.0, rulerRight(beside));
        // Monaco's layout, its ruler field included
        assertEquals(0.0, layout.overviewRuler.right);
        assertEquals(10.0, layout.overviewRuler.width);
        assertEquals(overlayLayout.contentWidth, layout.contentWidth);
        assertEquals(overlayLayout.wrappingColumn, layout.wrappingColumn);
        assertEquals(overlayLayout.viewportColumn, layout.viewportColumn);
        final view:cityscape.view.CityscapeView = beside.getView();
        final target = view.mouseTargetAt(point(view.elementBounds.origin.x + 985, y));
        assertEquals(cityscape.view.EditorBrowser.MouseTargetType.SCROLLBAR, target.type);
        assertEquals(1, target.position.lineNumber);
        assertTrue(view.mouseTargetAt(point(view.elementBounds.origin.x + 975, y)).type != cityscape.view.EditorBrowser.MouseTargetType.SCROLLBAR);
        // the gap, validated
        beside.updateOptions({overviewRulerGap: 4});
        assertEquals(14.0, rulerRight(beside));
        beside.updateOptions({overviewRulerGap: -3});
        assertEquals(10.0, rulerRight(beside));
        beside.updateOptions({overviewRulerPosition: 'left'});
        assertEquals('overlay', beside.getOption(EditorOption.overviewRulerPosition));
        assertEquals(0.0, rulerRight(beside));
    }

    function testItalicFontsSynthesizeTheirStyle() {
        final measurements = new EditorFontMeasurements(app.textSystem());
        final italic = measurements.resolveEditorFont('Menlo, monospace', 400, true, new glaze.FontFeatures());
        assertTrue(italic.synthesizeStyle);
        // JetBrains Mono (bundled, upright only) drawn slanted: a font id of
        // its own, the same advances
        final upright = measurements.resolveEditorFont('Menlo, monospace', 400, false, new glaze.FontFeatures());
        final ts = app.textSystem();
        if (!ts.isFamilyAvailable('Menlo')) {
            assertTrue(ts.resolveFont(italic) != ts.resolveFont(upright));
        }
        assertFloatEquals(ts.advance(ts.resolveFont(upright), 14, 'm'.code).width, ts.advance(ts.resolveFont(italic), 14, 'm'.code).width, 0);
    }

    /**
     * The CSS font list after the first available family gives the
     * fallbacks, tried before the fonts of the system like a browser does.
     * With `preferColorEmoji: false`, a primary family that lacks `☕`
     * (U+2615, emoji presentation by default) lets the generic `monospace`
     * (Menlo on macOS) draw it with its text glyph, like Chromium (recorded:
     * a monochrome glyph in the token color, 8.4 px wide at 14 px,
     * loreline-monaco's Writer preset); a character no family of the list
     * has (`🌧`) comes from the emoji font.
     *
     * By default (`preferColorEmoji: true`, owner decision 2026-11-11, see
     * DEVIATIONS.md) every emoji (`Extended_Pictographic`) is drawn with the
     * color emoji font even when Menlo or JetBrains Mono has a text glyph
     * (`☕`, `☂` with or without U+FE0F, `©`), except when U+FE0E asks for
     * the text presentation; the other characters keep the font list.
     */
    function testFontListFallbacksBeforeTheSystemFonts() {
        final measurements = new EditorFontMeasurements(app.textSystem());
        final font = measurements.resolveEditorFont("'JetBrains Mono', 'No Such Font', monospace", 400, false, new glaze.FontFeatures(), false);
        assertEquals('JetBrains Mono', font.family);
        assertEquals('monospace', font.fallbacks.fallbackList().join(','));
        assertTrue(font.wholeRunShaping);
        assertFalse(font.preferColorEmoji);
        final colorFont = measurements.resolveEditorFont("'JetBrains Mono', 'No Such Font', monospace", 400, false, new glaze.FontFeatures());
        assertTrue(colorFont.preferColorEmoji);
        assertEquals('monospace', colorFont.fallbacks.fallbackList().join(','));
        final ts = app.textSystem();
        if (!ts.isFamilyAvailable('Menlo')) {
            // no system fonts (node, the web): nothing more to check
            return;
        }
        final menlo = ts.resolveFont(glaze.Font.of('Menlo'));
        function glyphAt(fontToUse:glaze.Font, text:String, index:Int):glaze.ShapedGlyph {
            final layout = ts.platformTextSystem.layoutLine(text, 14, [new glaze.FontRun(glaze.util.Utf8.byteLength(text), ts.resolveFont(fontToUse))]);
            return [for (run in layout.runs) for (g in run.glyphs) if (g.index == index) g][0];
        }

        // preferColorEmoji: false, the browser's order
        final text = 'a\u2615b\u{1F327}\uFE0F';
        final coffee = glyphAt(font, text, 1);
        assertFalse(coffee.isEmoji);
        assertEquals(ts.platformTextSystem.glyphForChar(menlo, 0x2615), coffee.id);
        assertFloatEquals(ts.advance(menlo, 14, 'm'.code).width, ts.advance(menlo, 14, 0x2615).width, 0.01);
        assertTrue(glyphAt(font, text, 5).isEmoji);

        // the default: color emoji
        assertTrue(glyphAt(colorFont, text, 1).isEmoji, 'coffee in color');
        assertTrue(glyphAt(colorFont, text, 5).isEmoji, 'rain in color');
        assertTrue(glyphAt(colorFont, 'a\u2602b', 1).isEmoji, 'umbrella in color');
        assertTrue(glyphAt(colorFont, 'a\u2602\uFE0Fb', 1).isEmoji, 'umbrella with VS16 in color');
        assertTrue(glyphAt(colorFont, 'a\u00A9b', 1).isEmoji, 'copyright sign in color');
        // text presentation asked
        final textCoffee = glyphAt(colorFont, 'a\u2615\uFE0Eb', 1);
        assertFalse(textCoffee.isEmoji, 'coffee with VS15 as text');
        assertEquals(ts.platformTextSystem.glyphForChar(menlo, 0x2615), textCoffee.id);
        // not emoji: the font list
        assertFalse(glyphAt(colorFont, 'a\u2192b', 1).isEmoji, 'arrow as text');
        assertFalse(glyphAt(colorFont, 'a\u00E9b', 1).isEmoji, 'accented letter as text');
    }

    /**
     * The text of an editor is clipped to its own bounds: no glyph of the
     * left editor draws over the right one.
     */
    function testTextIsClippedToTheEditor() {
        final long = [for (i in 0...40) 'word' + i].join(' ');
        final left = instantiateTextModel(context, long + '\n' + long);
        final right = instantiateTextModel(context, 'right');
        var leftEditor:Null<CityscapeEditor> = null;
        window = Window.open(app, {width: 600, height: 300, scaleFactor: 2, autoDraw: false, bindInput: false},
            EditorClipTestHost.component(left, right, e -> leftEditor = e));
        app.update(_ -> window.draw());
        final scene = window.renderedScene();
        // scene coordinates are device pixels: the left editor spans x 0 to
        // 600, and every glyph it paints is masked within it
        var leftGlyphs = 0;
        for (sprite in scene.monochromeSprites) {
            if (sprite.boundsX >= 600) {
                continue;
            }
            leftGlyphs++;
            assertTrue(sprite.contentMaskX + sprite.contentMaskWidth <= 600.001, 'glyph at ' + sprite.boundsX + ' masked within the left editor');
        }
        assertTrue(leftGlyphs > 0);
        assertEquals(300.0, leftEditor.getLayoutInfo().width);
    }

}
