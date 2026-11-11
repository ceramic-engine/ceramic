// New code for Cityscape (not a port): the content hover in a Glaze window
// (headless): its size against Monaco's ContentHoverWidget (as wide and high
// as its content up to `max(0.66 × width, 500)` and `max(height / 4, 250)`,
// scrolling beyond), its side (resizableContentWidget.ts
// `_findPositionPreference`, `hover.above`), its place against the line
// (contentWidgets.ts), the status bar with the keybindings of its actions,
// the `$(name)` codicons of markdown with `supportThemeIcons`.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Uri;
import cityscape.common.Languages.Hover;
import cityscape.common.Languages.HoverContext;
import cityscape.common.Languages.HoverProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.hover.view.ContentHoverController;
import cityscape.contrib.hover.view.HoverOperation;
import cityscape.platform.markers.common.Markers;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

private class FixedHover implements HoverProvider {

    final markdown:String;

    final themeIcons:Bool;

    public function new(markdown:String, themeIcons:Bool = false) {
        this.markdown = markdown;
        this.themeIcons = themeIcons;
    }

    public function provideHover(model:ITextModel, position:Position, token:CancellationToken, context:Null<HoverContext>, resolve:(hover:Null<Hover>) -> Void):Void {
        resolve({contents: [{value: markdown, supportHtml: true, supportThemeIcons: themeIcons}], range: new Range(position.lineNumber, 1, position.lineNumber, 5)});
    }

}

class HoverViewTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function draw():Void {
        app.update(_ -> window.draw());
    }

    function lines(count:Int):String {
        return [for (i in 0...count) 'line ' + (i + 1)].join('\n');
    }

    function open(markdown:Null<String>, width:Int, height:Int, ?options:Dynamic, themeIcons:Bool = false):CityscapeEditor {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'hovertest'});
        if (markdown != null) {
            context.registerHoverProvider('hovertest', new FixedHover(markdown, themeIcons));
        }
        final model = context.modelService.createModel(lines(60), 'hovertest', Uri.parse('file:///hover.test'));
        var editor:Null<CityscapeEditor> = null;
        if (window != null) {
            window.destroy();
        }
        window = Window.open(app, {width: width, height: height, scaleFactor: 2, autoDraw: false, bindInput: false},
            HoverEditorHost.component(context, model, options, e -> editor = e));
        draw();
        draw();
        return editor;
    }

    function showHover(editor:CityscapeEditor, lineNumber:Int):ContentHoverWidget {
        final controller = ContentHoverController.get(editor.getEditor());
        controller.showContentHover(new Range(lineNumber, 2, lineNumber, 2), HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
        controller.getContentWidget()._flushOperation();
        draw();
        draw();
        draw();
        final widget = controller.getContentWidget().getWidget();
        assertTrue(widget.isVisible);
        assertNotNull(widget.bounds);
        return widget;
    }

    function lineBox(editor:CityscapeEditor, lineNumber:Int):glaze.Bounds {
        return EditorWidgets.positionBounds(editor.getEditor(), new Position(lineNumber, 1));
    }

    function near(expected:Float, actual:Float, ?label:String):Void {
        assertTrue(Math.abs(expected - actual) <= 1, (label != null ? label + ': ' : '') + 'expected ' + expected + ', got ' + actual);
    }

    /**
     * A one line hover: as wide as its text, as high as a line with the
     * paddings, right above the line (its bottom on the line's top), its
     * left on the start of the hovered range.
     */
    function testShortHoverAboveTheLine() {
        final editor = open('**Bold** text', 800, 600);
        final widget = showHover(editor, 15);
        final lineHeight:Float = editor.getEditor().getOption(EditorOption.lineHeight);
        final b = widget.bounds;
        // border 1, padding 4, a line, padding 4, the 2 pixels of the content, border 1
        near(1 + 4 + lineHeight + 4 + 2 + 1, b.size.height, 'height');
        assertTrue(b.size.width < 200, 'width ' + b.size.width);
        assertEquals(ContentWidgetPositionPreference.ABOVE, widget.positionPreference);
        final line = lineBox(editor, 15);
        near(line.origin.y, b.origin.y + b.size.height, 'bottom on the line');
        near(line.origin.x, b.origin.x, 'left on the range');
        // not clipped: the whole content shows
        near(b.size.height - 2, widget.scrollHeight, 'scroll height');
    }

    /**
     * No room above the first line (its top minus 30 pixels): below it.
     */
    function testBelowWhenNoRoomAbove() {
        final editor = open('**Bold** text', 800, 600);
        final widget = showHover(editor, 1);
        assertEquals(ContentWidgetPositionPreference.BELOW, widget.positionPreference);
        final line = lineBox(editor, 1);
        near(line.origin.y + line.size.height, widget.bounds.origin.y, 'top on the line bottom');
    }

    /**
     * `hover.above: false`: below when it fits there.
     */
    function testHoverAboveOption() {
        final editor = open('**Bold** text', 800, 600, {hover: {above: false}});
        final widget = showHover(editor, 15);
        assertEquals(ContentWidgetPositionPreference.BELOW, widget.positionPreference);
    }

    /**
     * A long hover: Monaco's maximum width (`max(0.66 × the editor's width,
     * 500)`) and height (`max(the editor's height / 4, 250)`), the rest
     * scrolls.
     */
    function testMaximumSizesAndScroll() {
        final paragraphs = [for (i in 0...30) 'Paragraph ' + i + ' ' + [for (j in 0...40) 'word'].join(' ')];
        final editor = open(paragraphs.join('\n\n'), 1200, 900);
        final widget = showHover(editor, 50);
        final layoutInfo = editor.getEditor().getOption(EditorOption.layoutInfo);
        final b = widget.bounds;
        near(Math.max(layoutInfo.width * 0.66, 500), b.size.width, 'width');
        near(Math.max(layoutInfo.height / 4, 250), b.size.height, 'height');
        assertTrue(widget.scrollHeight > b.size.height * 3, 'scroll height ' + widget.scrollHeight);
        // a narrow editor: at least 500
        final narrow = open(paragraphs[0], 600, 900);
        final w2 = showHover(narrow, 50);
        near(500, w2.bounds.size.width, 'narrow width');
    }

    /**
     * Several parts with separators and a list: as high as all of them, no
     * clipping.
     */
    function testNoClipping() {
        final markdown = '**Barista** (character)\n\n---\n\n**Fields**  \n<small>[friendship](#4,3): `0` (number)</small>\n\n---\n\n**Speaks in**  \n<small>[CoffeeShop](#39,1) (5 lines), [BaristaChat](#287,1) (3 lines), [EnterCoffeeShop](#9,1) (1 line), [ProductiveMoment](#138,1) (1 line), [HighCaffeine](#191,1) (1 line), [EndDay](#459,1) (1 line)</small>';
        final editor = open(markdown, 1000, 800);
        final widget = showHover(editor, 30);
        final b = widget.bounds;
        near(b.size.height - 2, widget.scrollHeight, 'scroll height');
        assertTrue(b.size.height < Math.max(editor.getEditor().getOption(EditorOption.layoutInfo).height / 4, 250));
        // the header, two rules, three lines at least
        final lineHeight:Float = editor.getEditor().getOption(EditorOption.lineHeight);
        assertTrue(b.size.height > lineHeight * 5, 'height ' + b.size.height);
    }

    /**
     * The status bar of a marker: its actions with the label of their
     * keybinding in parentheses (`HoverAction`), 12 pixels high text on 22
     * pixels lines under the parts.
     */
    function testStatusBarWithKeybindings() {
        final editor = open(null, 800, 600);
        final model = editor.getModel();
        Cityscape.setModelMarkers(model, 'test', [{severity: MarkerSeverity.Warning, message: 'Careful', startLineNumber: 15, startColumn: 1, endLineNumber: 15, endColumn: 5}]);
        final widget = showHover(editor, 15);
        final rendered = widget.getRendered();
        assertEquals(1, rendered.statusBarActions.length);
        final action = rendered.statusBarActions[0];
        assertEquals('View Problem', action.label);
        final kb = editor.getEditor().context.keybindingService.lookupKeybinding('editor.action.marker.next');
        assertNotNull(kb);
        assertEquals(kb.getLabel(), action.keybindingLabel);
        assertEquals('View Problem (' + kb.getLabel() + ')', action.text);
        if (cityscape.base.common.Platform.isMacintosh) {
            assertEquals('View Problem (⌥F8)', action.text);
        }
        // the marker row, the status bar
        final lineHeight:Float = editor.getEditor().getOption(EditorOption.lineHeight);
        near(1 + 4 + lineHeight + 4 + 1 + 22 + 2 + 1, widget.bounds.size.height, 'height');
    }

    static function sameColor(q:glaze.scene.Quad, c:glaze.Hsla):Bool {
        return Math.abs(q.backgroundSolidH - c.h) < 0.0001 && Math.abs(q.backgroundSolidS - c.s) < 0.0001
            && Math.abs(q.backgroundSolidL - c.l) < 0.0001 && Math.abs(q.backgroundSolidA - c.a) < 0.0001;
    }

    /**
     * A hover higher than its maximum scrolls with Monaco's widget
     * scrollbar (real Monaco 0.52.2: a 10 pixel square slider against the
     * right of the hover, inside its border, in `scrollbarSlider.background`).
     */
    function testScrollbarLooksLikeMonacos() {
        glaze.kit.theme.Theme.setScrollbarMode(glaze.kit.base.theme.ScrollbarMode.Always, app);
        final paragraphs = [for (i in 0...30) 'Paragraph ' + i + ' ' + [for (j in 0...40) 'word'].join(' ')];
        final editor = open(paragraphs.join('\n\n'), 1200, 900);
        final widget = showHover(editor, 50);
        draw();
        final slider = EditorWidgets.color(editor.getEditor(), 'scrollbarSlider.background', hsla(0, 0, 0, 1));
        final b = widget.bounds;
        final found = [for (q in window.renderedScene().quads) if (sameColor(q, slider)) q];
        assertEquals(1, found.length, 'one slider');
        final q = found[0];
        near((b.origin.x + b.size.width - 1 - 10) * 2, q.boundsX, 'slider left');
        near(20, q.boundsWidth, 'slider width');
        near((b.origin.y + 1) * 2, q.boundsY, 'slider top');
        assertEquals(0.0, q.cornerRadiusTopLeft);
    }

    /**
     * The sprites drawn inside the hover (device pixels, scale 2).
     */
    function spritesIn(bounds:glaze.Bounds):Array<glaze.scene.MonochromeSprite> {
        return [for (sp in window.renderedScene().monochromeSprites) if (sp.boundsX >= bounds.origin.x * 2 && sp.boundsX + sp.boundsWidth <= (bounds.origin.x + bounds.size.width) * 2
            && sp.boundsY >= bounds.origin.y * 2 && sp.boundsY + sp.boundsHeight <= (bounds.origin.y + bounds.size.height) * 2) sp];
    }

    /**
     * Markdown with `supportThemeIcons`: `$(zap)` is the codicon, an em
     * square in the text's size (real Monaco 0.52.2: a 12 px box in a 12 px
     * hover), not the text `$(zap)`; without the option the text stays.
     */
    function testThemeIconsInMarkdown() {
        final editor = open('$(zap) Run', 800, 600, null, true);
        final widget = showHover(editor, 30);
        final fontSize:Float = editor.getEditor().getOption(EditorOption.fontInfo).fontSize;
        final sprites = spritesIn(widget.bounds);
        final squares = [for (sp in sprites) if (Math.abs(sp.boundsWidth - fontSize * 2) <= 1 && Math.abs(sp.boundsHeight - fontSize * 2) <= 1) sp];
        assertEquals(1, squares.length, 'one codicon of ' + fontSize + ' px among ' + [for (sp in sprites) sp.boundsWidth + 'x' + sp.boundsHeight].join(' '));
        final plain = open('$(zap) Run', 800, 600, null, false);
        final plainWidget = showHover(plain, 30);
        final plainSprites = spritesIn(plainWidget.bounds);
        // `$(zap)` as text: six glyphs instead of the icon (the other
        // sprites are the text of the editor under the hover, the same)
        assertEquals(sprites.length + 5, plainSprites.length);
        assertEquals(0, [for (sp in plainSprites) if (Math.abs(sp.boundsWidth - fontSize * 2) <= 1 && Math.abs(sp.boundsHeight - fontSize * 2) <= 1) sp].length);
    }

}

class HoverEditorHost extends glaze.Component {

    final context:Cityscape;
    final model:ITextModel;
    final options:Dynamic;
    final onEditor:(editor:CityscapeEditor) -> Void;

    public function new(context:Cityscape, model:ITextModel, options:Dynamic, onEditor:(editor:CityscapeEditor) -> Void) {
        super();
        this.context = context;
        this.model = model;
        this.options = options;
        this.onEditor = onEditor;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        final editor = CityscapeEditor.component().context(context).model(model).onCreate(onEditor).flex1();
        if (options != null) {
            editor.options(cast options);
        }
        return div().flex().sizeFull().child(editor);
    }

}
