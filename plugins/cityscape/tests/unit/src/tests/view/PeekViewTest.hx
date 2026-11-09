// New code for Cityscape (not a port): the references peek view in a Glaze
// window (headless): placed under the line, as wide as the text area and
// as high as Monaco's zone (18 lines by default, at most 80% of the editor),
// its preview editor on the reference, the colors of the peek view in the
// preview, the tree focused.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.gotoSymbol.view.peek.ReferencesController;
import cityscape.contrib.peekView.view.PeekView;
import cityscape.view.CityscapeView;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

private class LinesReferences implements ReferenceProvider {
    public function new() {}
    public function provideReferences(model:ITextModel, position:Position, context:ReferenceContext, token:CancellationToken, resolve:(locations:Null<Array<Location>>) -> Void):Void {
        resolve([
            {uri: model.uri, range: new Range(3, 1, 3, 5)},
            {uri: model.uri, range: new Range(10, 1, 10, 5)},
            {uri: model.uri, range: new Range(40, 1, 40, 5)}
        ]);
    }
}

class PeekViewTest extends TestCase {

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

    function testPeekReferencesInAWindow() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'peektest'});
        context.registerReferenceProvider('peektest', new LinesReferences());
        final model = context.modelService.createModel([for (i in 0...60) 'line ' + (i + 1)].join('\n'), 'peektest', Uri.parse('file:///peek.test'));
        var editor:Null<CityscapeEditor> = null;
        window = Window.open(app, {width: 900, height: 700, scaleFactor: 2, autoDraw: false, bindInput: false},
            tests.view.HoverViewTest.HoverEditorHost.component(context, model, null, e -> editor = e));
        draw();
        draw();
        final codeEditor = editor.getEditor();
        codeEditor.setPosition(new Position(3, 2));
        editor.trigger('keyboard', 'editor.action.referenceSearch.trigger', null);
        draw();
        draw();
        draw();
        final controller = ReferencesController.get(codeEditor);
        final widget = controller.getWidget();
        assertNotNull(widget);
        assertEquals('References (3)', widget.metaTitle);
        // the preview editor shows the selected reference, with the colors
        // of the peek view
        final preview = widget.preview;
        assertNotNull(preview, 'the preview editor is created');
        assertTrue(preview.getModel() == model);
        assertEquals(3, preview.getPosition().lineNumber);
        final previewView:CityscapeView = preview.getView();
        final expected = EditorWidgets.themeColor(codeEditor, PeekViewColors.peekViewEditorBackground);
        final background = previewView.theme.getColor('editor.background');
        assertTrue(expected != null && background != null && expected.toRgb().toHexString() == background.toRgb().toHexString(), 'peekViewEditor.background');
        // the preview is an editor of the peek view
        assertEquals(true, preview.getEditor().contextKeyService.getContextKeyValue('inReferenceSearchEditor'));
        // the preview's bounds: under line 3, the height of the zone
        final lineHeight:Float = codeEditor.getOption(EditorOption.lineHeight);
        final line = EditorWidgets.positionBounds(codeEditor, new Position(3, 1));
        final previewBounds = previewView.elementBounds;
        assertTrue(previewBounds.origin.y >= line.origin.y + line.size.height, 'the peek view is under the line');
        final layoutInfo = codeEditor.getOption(EditorOption.layoutInfo);
        final heightInLines = Math.min(18, Math.max(12, Math.round(layoutInfo.height / lineHeight * 0.8)));
        final headHeight = Math.ceil(lineHeight * 1.2);
        final bodyHeight = Math.round(heightInLines * lineHeight - (headHeight + 2));
        assertTrue(Math.abs(previewBounds.size.height - bodyHeight) <= 1, 'body height ' + previewBounds.size.height + ' expected ' + bodyHeight);
        // the next reference shows in the preview
        controller.goToNextOrPreviousReference(true);
        draw();
        draw();
        assertEquals(10, preview.getPosition().lineNumber);
        // closing removes it
        controller.closeWidget();
        draw();
        assertNull(controller.getWidget());
    }

}
