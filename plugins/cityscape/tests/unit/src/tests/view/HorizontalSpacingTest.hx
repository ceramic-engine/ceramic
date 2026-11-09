// New code for Cityscape (not a port): the horizontal padding and fixed
// widths of decoration styles (the inlay hints' padding and spacers), laid
// out by the view (step 7, cs7-rest-inlay).
package tests.view;

import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Entity;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;
import tests.view.CityscapeEditorTest.TwoEditors;

class HorizontalSpacingTest extends TestCase {

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

    function openTwo(model:TextModel, modelB:TextModel):{a:Entity<CityscapeView>, b:Entity<CityscapeView>} {
        var a:Null<Entity<CityscapeView>> = null;
        var b:Null<Entity<CityscapeView>> = null;
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, TwoEditors.component(model, modelB, v -> a = v, v -> b = v));
        draw();
        return {a: a, b: b};
    }

    function testPaddingMovesTheTextAfter() {
        final padded = createTextModel('ab cd');
        final plain = createTextModel('ab cd');
        padded.deltaDecorations([], [{range: new Range(1, 4, 1, 4), options: {description: 'hint', showIfCollapsed: true, before: {content: 'X', inlineStyle: {background: '#335', paddingLeft: 3, paddingRight: 5}}}}]);
        plain.deltaDecorations([], [{range: new Range(1, 4, 1, 4), options: {description: 'hint', showIfCollapsed: true, before: {content: 'X', inlineStyle: {background: '#335'}}}}]);
        final views = openTwo(padded, plain);
        final a:CityscapeView = views.a;
        final b:CityscapeView = views.b;
        final lineA = a.renderViewLine(1);
        final lineB = b.renderViewLine(1);
        assertEquals('ab Xcd', a.viewModel.getLineContent(1));
        // the text before is not moved
        assertFloatEquals(lineB.columnToX(3), lineA.columnToX(3));
        // the injected text moves by its left padding, the text after by both
        assertFloatEquals(lineB.columnToX(4) + 3, lineA.columnToX(4));
        assertFloatEquals(lineB.columnToX(5) + 8, lineA.columnToX(5));
        assertFloatEquals(lineB.layout.width + 8, lineA.layout.width);
        // the box includes the padding
        assertNull(lineB.partBoxStarts);
        assertNotNull(lineA.partBoxStarts);
        var boxPart = -1;
        for (p in 0...lineA.partStyles.length) {
            if (lineA.partStyles[p].box != null) {
                boxPart = p;
            }
        }
        assertTrue(boxPart >= 0);
        assertFloatEquals(lineB.columnToX(4), lineA.partBoxStarts[boxPart]);
        assertFloatEquals(lineB.columnToX(5) + 8, lineA.partBoxEnds[boxPart]);
        // the mouse finds the columns back
        assertEquals(5, lineA.xToColumn(lineA.columnToX(5) + 0.5));
        draw();
    }

    function testFixedWidth() {
        final spaced = createTextModel('ab cd');
        final plain = createTextModel('ab cd');
        final hair = String.fromCharCode(0x200a);
        spaced.deltaDecorations([], [{range: new Range(1, 4, 1, 4), options: {description: 'spacer', showIfCollapsed: true, before: {content: hair, inlineStyle: {width: 7}}}}]);
        final views = openTwo(spaced, plain);
        final a:CityscapeView = views.a;
        final b:CityscapeView = views.b;
        final lineA = a.renderViewLine(1);
        final lineB = b.renderViewLine(1);
        // the spacer is 7 pixels wide whatever its glyph
        assertFloatEquals(lineA.columnToX(4) + 7, lineA.columnToX(5));
        assertFloatEquals(lineB.columnToX(4) + 7, lineA.columnToX(5));
        draw();
    }

}
