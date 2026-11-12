// New code for Cityscape (not a port): the track and thumb of the vertical
// scrollbar (the Cityscape options `scrollbar.trackColor`, `thumbColor` and
// `thumbRadius`).
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import glaze.App;
import glaze.Hsla;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Scrollbar;
import testing.TestCase;
import tests.TestTextModel.instantiateTextModel;
import tests.view.EditorFontsTest.EditorFontsTestHost;

import glaze.Prelude.*;

/**
 * The track of the vertical scrollbar is opaque by default (owner decision
 * 2026-11-11: the line backgrounds stop at the scrollbar track): filled with
 * `editor.background` over the text and the whole line backgrounds (current
 * line highlight, whole line decorations, selections), under the overview
 * ruler and the thumb. Monaco's track is transparent (`trackColor:
 * 'transparent'` gives it back); loreline-monaco paints it with the
 * `trackColor` of its `scrollbar` option (main.js).
 */
class ScrollbarTrackTest extends TestCase {

    var app:App;
    var context:Cityscape;
    var window:Null<Window> = null;
    var editor:Null<CityscapeEditor> = null;

    static final HIGHLIGHT = '#ff0000';
    static final LINE_STYLE = '#0000ff';
    static final SELECTION = '#ffff00';

    override public function setup():Void {
        app = new App(new TestDispatcher());
        context = new Cityscape();
        context.themeService.defineTheme('trackTest', {base: 'vs', inherit: true, rules: [], colors: {
            'editor.background': '#202020',
            'editor.lineHighlightBackground': HIGHLIGHT,
            'editor.selectionBackground': SELECTION,
            'editor.inactiveSelectionBackground': SELECTION
        }});
        context.themeService.setTheme('trackTest');
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open(options:IEditorOptions):CityscapeEditor {
        if (window != null) {
            window.destroy();
            window = null;
        }
        final text = [for (i in 0...200) 'line $i ' + [for (_ in 0...30) 'word'].join(' ')].join('\n');
        final model = instantiateTextModel(context, text);
        window = Window.open(app, {width: 1000, height: 700, scaleFactor: 2, autoDraw: false, bindInput: false},
            EditorFontsTestHost.component(model, options, e -> editor = e));
        app.update(_ -> window.draw());
        return editor;
    }

    function draw():Void {
        app.update(_ -> window.draw());
    }

    static inline function bg(c:Hsla):glaze.Background {
        return (c : glaze.IntoBackground);
    }

    static function color(hex:String):Hsla {
        return cityscape.view.ViewTheme.parseColor(hex);
    }

    /** A color of the editor's theme, as the scrollbar reads it. */
    static function themed(e:CityscapeEditor, key:String):Hsla {
        return cityscape.view.EditorWidgets.color(e.getEditor(), key, hsla(0, 0, 0, 0));
    }

    function near(expected:Hsla, actual:Hsla, ?pos:haxe.PosInfos):Void {
        assertTrue(Math.abs(expected.h - actual.h) < 0.001 && Math.abs(expected.s - actual.s) < 0.001
            && Math.abs(expected.l - actual.l) < 0.001 && Math.abs(expected.a - actual.a) < 0.001, 'expected ' + expected + ', got ' + actual, pos);
    }

    static function sameColor(q:glaze.scene.Quad, c:Hsla):Bool {
        return Math.abs(q.backgroundSolidH - c.h) < 0.0001 && Math.abs(q.backgroundSolidS - c.s) < 0.0001
            && Math.abs(q.backgroundSolidL - c.l) < 0.0001 && Math.abs(q.backgroundSolidA - c.a) < 0.0001;
    }

    /** The quads of a color (device pixels at scale 2), in paint order. */
    function quadsOf(c:Hsla):Array<glaze.scene.Quad> {
        return [for (q in window.renderedScene().quads) if (sameColor(q, c)) q];
    }

    /** The quads of a color that reach the column from `x` (CSS px) to the right edge. */
    function quadsReaching(c:Hsla, x:Float):Array<glaze.scene.Quad> {
        return [for (q in quadsOf(c)) if (q.boundsX + q.boundsWidth > x * 2) q];
    }

    /** The one quad of the track: `x` to the right edge, the editor's height. */
    function track(c:Hsla, x:Float):glaze.scene.Quad {
        final found = [for (q in quadsOf(c)) if (q.boundsX == x * 2 && q.boundsWidth == (1000 - x) * 2 && q.boundsY == 0 && q.boundsHeight == 1400) q];
        assertEquals(1, found.length, 'one track quad from x ' + x);
        return found[0];
    }

    /**
     * Without `trackColor`, the track (the 10 px band of
     * `verticalScrollbarSize`) is `editor.background`, painted over the
     * current line highlight, a whole line decoration and a selection of
     * whole lines that reach it, under the overview ruler (Monaco's ruler
     * under the scrollbar, its cursor mark at 990 to 1000).
     */
    function testWholeLineBackgroundsStopAtTheTrack() {
        final e = open({fontSize: 14, wordWrap: 'off', stickyScroll: {enabled: false}, scrollbar: {verticalScrollbarSize: 10}});
        e.deltaDecorations([], [
            {range: new Range(3, 1, 3, 1), options: {description: 'whole', isWholeLine: true, lineStyle: {background: LINE_STYLE}}}
        ]);
        e.setSelection(new Selection(5, 1, 8, 1));
        e.setSelections([new Selection(1, 1, 1, 1), new Selection(5, 1, 8, 1)]);
        draw();
        final v:cityscape.view.CityscapeView = e.getView();
        final background = v.theme.getColor('editor.background');
        final trackQuad = track(background, 990);
        final under = quadsReaching(color(HIGHLIGHT), 990).concat(quadsReaching(color(LINE_STYLE), 990)).concat(quadsReaching(color(SELECTION), 990));
        assertTrue(quadsReaching(color(HIGHLIGHT), 990).length > 0, 'the line highlight reaches the track');
        assertTrue(quadsReaching(color(LINE_STYLE), 990).length > 0, 'the whole line style reaches the track');
        assertTrue(quadsReaching(color(SELECTION), 990).length > 0, 'the selection of long lines reaches the track');
        for (q in under) {
            assertTrue(trackQuad.order > q.order, 'the track over a line background');
        }
        // the overview ruler's cursor mark, over the track
        final cursor = v.theme.getColor('editorCursor.foreground').opacity(0.7);
        final marks = [for (q in window.renderedScene().quads) if (q.boundsX >= 1980 && sameColor(q, cursor)) q];
        assertTrue(marks.length > 0, 'the cursor mark of the ruler');
        for (q in marks) {
            assertTrue(q.order > trackQuad.order, 'the ruler over the track');
        }
    }

    /**
     * `trackColor: 'transparent'` is Monaco's scrollbar: no track, the line
     * highlight goes on under the scrollbar to the editor's right edge.
     */
    function testTransparentTrackIsMonacos() {
        final e = open({fontSize: 14, stickyScroll: {enabled: false}, scrollbar: {verticalScrollbarSize: 10, trackColor: 'transparent'}});
        final v:cityscape.view.CityscapeView = e.getView();
        final background = v.theme.getColor('editor.background');
        assertEquals(0, [for (q in quadsOf(background)) if (q.boundsX == 1980) q].length);
        final highlight = quadsOf(color(HIGHLIGHT));
        assertEquals(1, highlight.length);
        assertEquals(2000.0, highlight[0].boundsX + highlight[0].boundsWidth);
    }

    /**
     * A track color of the host (loreline-monaco's `trackColor`), changed
     * at run time; a value that is not a color is the default.
     */
    function testTrackColorOption() {
        final e = open({fontSize: 14, stickyScroll: {enabled: false}, scrollbar: {verticalScrollbarSize: 10, trackColor: '#00ff0080'}});
        final trackQuad = track(color('#00ff0080'), 990);
        for (q in quadsReaching(color(HIGHLIGHT), 990)) {
            assertTrue(trackQuad.order > q.order);
        }
        e.updateOptions({scrollbar: {trackColor: 'rgb(0, 0, 255)'}});
        draw();
        track(color('#0000ff'), 990);
        e.updateOptions({scrollbar: {trackColor: 'not a color'}});
        draw();
        final v:cityscape.view.CityscapeView = e.getView();
        track(v.theme.getColor('editor.background'), 990);
    }

    /**
     * With `overviewRulerPosition: 'beside'`, the ruler's column (and the gap)
     * is part of the track, like loreline-monaco's style sheet gives the
     * moved ruler the track's background: the track from 980 (ruler 980 to
     * 990, scrollbar 990 to 1000), from 976 with a gap of 4; the ruler's
     * marks over it.
     */
    function testTrackUnderTheRulerBesideTheScrollbar() {
        final e = open({fontSize: 14, stickyScroll: {enabled: false}, overviewRulerPosition: 'beside', scrollbar: {verticalScrollbarSize: 10}});
        final v:cityscape.view.CityscapeView = e.getView();
        final background = v.theme.getColor('editor.background');
        assertEquals(20.0, cityscape.view.CityscapeViewElement.scrollbarTrackWidth(e.getOptions()));
        final trackQuad = track(background, 980);
        final cursor = v.theme.getColor('editorCursor.foreground').opacity(0.7);
        final marks = [for (q in window.renderedScene().quads) if (q.boundsX >= 1960 && q.boundsX < 1980 && sameColor(q, cursor)) q];
        assertEquals(1, marks.length);
        assertTrue(marks[0].order > trackQuad.order, 'the ruler over the track');
        for (q in quadsReaching(color(HIGHLIGHT), 980)) {
            assertTrue(trackQuad.order > q.order);
        }
        e.updateOptions({overviewRulerGap: 4});
        draw();
        assertEquals(24.0, cityscape.view.CityscapeViewElement.scrollbarTrackWidth(e.getOptions()));
        track(background, 976);
        // no ruler: the scrollbar's band only
        e.updateOptions({overviewRulerLanes: 0});
        draw();
        assertEquals(10.0, cityscape.view.CityscapeViewElement.scrollbarTrackWidth(e.getOptions()));
        track(background, 990);
    }

    /**
     * The validation of the additions: colors are non empty strings (kept
     * as given, trimmed), the radius a number clamped to 0..1000; anything
     * else is the default (null).
     */
    function testScrollbarAdditionsValidation() {
        final option = new EditorScrollbar();
        final defaults = option.validate(null);
        assertEquals(null, defaults.trackColor);
        assertEquals(null, defaults.thumbColor);
        assertEquals(null, defaults.thumbRadius);
        final given = option.validate({trackColor: ' #191D2D ', thumbColor: '#3A4458FF', thumbRadius: 4});
        assertEquals('#191D2D', given.trackColor);
        assertEquals('#3A4458FF', given.thumbColor);
        assertEquals(4.0, given.thumbRadius);
        // Monaco's fields are unchanged by the additions
        assertEquals(14, given.verticalScrollbarSize);
        final wrong:Dynamic = {trackColor: 12, thumbColor: '', thumbRadius: '4'};
        final invalid = option.validate(wrong);
        assertEquals(null, invalid.trackColor);
        assertEquals(null, invalid.thumbColor);
        assertEquals(null, invalid.thumbRadius);
        assertEquals(0.0, option.validate({thumbRadius: -3}).thumbRadius);
        assertEquals(1000.0, option.validate({thumbRadius: 5000}).thumbRadius);
        assertEquals(null, option.validate({thumbRadius: Math.NaN}).thumbRadius);
        // through the editor, with updateOptions
        final e = open({scrollbar: {verticalScrollbarSize: 10, thumbRadius: 2}});
        assertEquals(2.0, e.getOption(EditorOption.scrollbar).thumbRadius);
        e.updateOptions({scrollbar: {thumbColor: '#ff00ff'}});
        assertEquals('#ff00ff', e.getOption(EditorOption.scrollbar).thumbColor);
        assertEquals(2.0, e.getOption(EditorOption.scrollbar).thumbRadius);
        assertEquals(10, e.getOption(EditorOption.scrollbar).verticalScrollbarSize);
    }

    /**
     * `thumbColor` and `thumbRadius` give the kit scrollbar's thumb its
     * color and corner radius in every state (normal, hovered, dragged),
     * like loreline-monaco's `.slider { border-radius; background-color }`;
     * without them the thumb is the kit's.
     */
    function testThumbColorAndRadius() {
        final e = open({scrollbar: {verticalScrollbarSize: 10, verticalSliderSize: 8, thumbColor: '#3A445899', thumbRadius: 4}});
        final v:cityscape.view.CityscapeView = e.getView();
        final thumbColor = color('#3A445899');
        app.update(cx -> {
            final scrollbar = @:privateAccess CityscapeEditor.styledScrollbar(Scrollbar.vertical(v.scrollHandle), @:privateAccess e.widget, v);
            for (style in [@:privateAccess scrollbar.styleForNormal(cx), @:privateAccess scrollbar.styleForHoveredBar(cx),
                @:privateAccess scrollbar.styleForHoveredThumb(cx), @:privateAccess scrollbar.styleForActive(cx)]) {
                assertTrue(style.thumb.equals(bg(thumbColor)), 'thumb color');
                assertEquals(4.0, style.radius);
            }
            return null;
        });
        e.updateOptions({scrollbar: {thumbColor: null, thumbRadius: null}});
        draw();
        app.update(cx -> {
            final plain = @:privateAccess CityscapeEditor.styledScrollbar(Scrollbar.vertical(v.scrollHandle), @:privateAccess e.widget, v);
            final kit = new Scrollbar(v.scrollHandle);
            assertEquals((@:privateAccess kit.styleForNormal(cx)).radius, (@:privateAccess plain.styleForNormal(cx)).radius, 'the kit radius');
            return null;
        });
    }

    /**
     * Without `thumbColor` the thumb takes the colors of the editor's theme
     * (owner decision 2026-11-11): `scrollbarSlider.background` at rest and
     * over the track, `scrollbarSlider.hoverBackground` over the thumb,
     * `scrollbarSlider.activeBackground` while dragged, without the kit's
     * track fill and drag border; its shape stays the kit's (rounded, 6
     * pixels, 4 from the edge in the kit's 16 pixel band).
     */
    function testThumbTakesTheThemeColors() {
        context.themeService.defineTheme('sliderTest', {base: 'vs-dark', inherit: true, rules: [], colors: {
            'scrollbarSlider.background': '#11223344',
            'scrollbarSlider.hoverBackground': '#55667788',
            'scrollbarSlider.activeBackground': '#99aabbcc'
        }});
        context.themeService.setTheme('sliderTest');
        final e = open({scrollbar: {verticalScrollbarSize: 16}});
        final v:cityscape.view.CityscapeView = e.getView();
        app.update(cx -> {
            final scrollbar = @:privateAccess CityscapeEditor.styledScrollbar(Scrollbar.vertical(v.scrollHandle), @:privateAccess e.widget, v);
            final kit = new Scrollbar(v.scrollHandle);
            final normal = @:privateAccess scrollbar.styleForNormal(cx);
            assertTrue(normal.thumb.equals(bg(themed(e, 'scrollbarSlider.background'))), 'rest');
            assertTrue((@:privateAccess scrollbar.styleForHoveredBar(cx)).thumb.equals(bg(themed(e, 'scrollbarSlider.background'))), 'over the track');
            assertTrue((@:privateAccess scrollbar.styleForHoveredThumb(cx)).thumb.equals(bg(themed(e, 'scrollbarSlider.hoverBackground'))), 'over the thumb');
            near(color('#55667788'), themed(e, 'scrollbarSlider.hoverBackground'));
            final active = @:privateAccess scrollbar.styleForActive(cx);
            assertTrue(active.thumb.equals(bg(themed(e, 'scrollbarSlider.activeBackground'))), 'dragged');
            near(color('#99aabbcc'), themed(e, 'scrollbarSlider.activeBackground'));
            near(color('#11223344'), themed(e, 'scrollbarSlider.background'));
            assertEquals(0.0, active.track.a, 'no track fill');
            assertEquals(0.0, active.border.a, 'no drag border');
            final kitNormal = @:privateAccess kit.styleForNormal(cx);
            assertEquals(kitNormal.width, normal.width, 'kit width');
            assertEquals(kitNormal.inset, normal.inset, 'kit inset');
            assertEquals(kitNormal.radius, normal.radius, 'kit radius');
            return null;
        });
        // the look is resolved again when the theme changes
        context.themeService.defineTheme('sliderTest2', {base: 'vs', inherit: true, rules: [], colors: {'scrollbarSlider.background': '#123456'}});
        context.themeService.setTheme('sliderTest2');
        draw();
        app.update(cx -> {
            final scrollbar = @:privateAccess CityscapeEditor.styledScrollbar(Scrollbar.vertical(v.scrollHandle), @:privateAccess e.widget, v);
            assertTrue((@:privateAccess scrollbar.styleForNormal(cx)).thumb.equals(bg(themed(e, 'scrollbarSlider.background'))), 'new theme');
            near(color('#123456'), themed(e, 'scrollbarSlider.background'));
            return null;
        });
    }

    /**
     * In the kit theme (`KitTheme`, Glaze's inspector) the scrollbar keeps
     * the kit's look entirely, colors included: the same resolved styles as
     * a plain kit scrollbar in every state.
     */
    function testKitThemeKeepsTheKitScrollbar() {
        app.update(cx -> {
            cityscape.kit.KitTheme.apply(context, glaze.kit.theme.Theme.global(cx));
            return null;
        });
        final e = open({scrollbar: {verticalScrollbarSize: 16}});
        final v:cityscape.view.CityscapeView = e.getView();
        app.update(cx -> {
            final scrollbar = @:privateAccess CityscapeEditor.styledScrollbar(Scrollbar.vertical(v.scrollHandle), @:privateAccess e.widget, v);
            final kit = new Scrollbar(v.scrollHandle);
            final pairs = [
                [@:privateAccess scrollbar.styleForNormal(cx), @:privateAccess kit.styleForNormal(cx)],
                [@:privateAccess scrollbar.styleForHoveredBar(cx), @:privateAccess kit.styleForHoveredBar(cx)],
                [@:privateAccess scrollbar.styleForHoveredThumb(cx), @:privateAccess kit.styleForHoveredThumb(cx)],
                [@:privateAccess scrollbar.styleForActive(cx), @:privateAccess kit.styleForActive(cx)]
            ];
            for (p in pairs) {
                assertTrue(p[0].thumb.equals(p[1].thumb), 'thumb');
                assertTrue(p[0].track.equals(p[1].track), 'track');
                assertTrue(p[0].border.equals(p[1].border), 'border');
                assertEquals(p[1].width, p[0].width);
                assertEquals(p[1].inset, p[0].inset);
                assertEquals(p[1].radius, p[0].radius);
                assertEquals(p[1].minLength, p[0].minLength);
            }
            return null;
        });
    }


    /**
     * In a band of its own (`verticalScrollbarSize` other than the kit's 16
     * pixels) the thumb follows the kit's `ScrollbarAppearance`: by default
     * Loreline Writer's 8 pixel thumb (loreline-monaco's 10 pixel band with an
     * 8 pixel slider, 1 pixel from the edge), gpui-kit's 6 pixels with
     * `ScrollbarAppearance.gpuiKit()`, never wider than `verticalSliderSize`.
     */
    function testTheThumbFollowsTheKitAppearanceWidth() {
        app.update(cx -> {
            glaze.kit.theme.Theme.init(cx);
            return null;
        });
        final e = open({scrollbar: {verticalScrollbarSize: 10, verticalSliderSize: 8}});
        final v:cityscape.view.CityscapeView = e.getView();
        function check(width:Float, inset:Float, label:String) {
            app.update(cx -> {
                final scrollbar = @:privateAccess CityscapeEditor.styledScrollbar(Scrollbar.vertical(v.scrollHandle), @:privateAccess e.widget, v);
                final normal = @:privateAccess scrollbar.styleForNormal(cx);
                assertEquals(width, normal.width, label);
                assertEquals(inset, normal.inset, label);
                return null;
            });
        }
        check(8., 1., 'the default 8 px thumb');
        app.update(cx -> {
            glaze.kit.theme.Theme.setScrollbarAppearance(glaze.kit.base.ScrollbarAppearance.gpuiKit(), cx);
            return null;
        });
        draw();
        check(6., 2., "gpui-kit's 6 px thumb");
        e.updateOptions({scrollbar: {verticalScrollbarSize: 14, verticalSliderSize: 14}});
        app.update(cx -> {
            glaze.kit.theme.Theme.setScrollbarAppearance(null, cx);
            return null;
        });
        draw();
        check(8., 3., 'the default thumb in the 14 px band');
        e.updateOptions({scrollbar: {verticalScrollbarSize: 10, verticalSliderSize: 5}});
        draw();
        check(5., 2., 'no wider than the slider');
    }

}
