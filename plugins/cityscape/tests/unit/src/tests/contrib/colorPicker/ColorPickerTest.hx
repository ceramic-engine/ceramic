// New code for Cityscape (not a port): the color decorators and the color
// picker (contrib/colorPicker) with the default colors computer and with a
// provider of the test: the swatches, the limit, the click and hover
// activation, picking a color writing the presentation, the standalone
// picker. vscode has no test of these files; the expected values follow
// defaultDocumentColorsComputer.ts, defaultDocumentColorProvider.ts
// (`Color.Format.CSS`), colorDetector.ts and colorHoverParticipant.ts.
package tests.contrib.colorPicker;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Color;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.DefaultDocumentColorsComputer;
import cityscape.contrib.colorPicker.view.ColorContributions;
import cityscape.contrib.colorPicker.view.ColorDetector;
import cityscape.contrib.colorPicker.view.DefaultDocumentColorProvider;
import cityscape.contrib.colorPicker.view.StandaloneColorPickerActions;
import cityscape.view.EditorBrowser;
import haxe.PosInfos;
import testing.TestCase;
import testing.TestCodeEditor;

private class TestColorProvider implements DocumentColorProvider {

    final colors:Array<IColorInformation>;
    final presentations:Array<IColorPresentation>;

    public function new(colors:Array<IColorInformation>, presentations:Array<IColorPresentation>) {
        this.colors = colors;
        this.presentations = presentations;
    }

    public function provideDocumentColors(model:ITextModel, token:CancellationToken, resolve:(colors:Null<Array<IColorInformation>>) -> Void):Void {
        resolve(colors);
    }

    public function provideColorPresentations(model:ITextModel, colorInfo:IColorInformation, token:CancellationToken, resolve:(presentations:Null<Array<IColorPresentation>>) -> Void):Void {
        resolve(presentations);
    }
}

class ColorPickerTest extends TestCase {

    static inline final TEXT = 'x = #ff0000;\ny = rgb(0, 128, 255);\nz = hsl(120, 100%, 50%);\nw = rgba(10, 20, 30, 0.5);\nv = #abc;';

    var context:Cityscape;
    var model:Null<ITextModel> = null;
    final editors:Array<TestCodeEditor> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.editorExtensions;
    }

    override public function teardown():Void {
        for (editor in editors) {
            editor.dispose();
        }
        editors.resize(0);
        if (model != null) {
            model.dispose();
            model = null;
        }
    }

    function newEditor(text:String, options:cityscape.common.config.EditorOptions.IEditorOptions):TestCodeEditor {
        model = context.modelService.createModel(text, 'plaintext', Uri.parse('file:///project/colors.txt'));
        final ids = [ColorDetector.ID, ColorContribution.ID, StandaloneColorPickerController.ID];
        final editor = new TestCodeEditor(context, cast model, options, context.editorExtensions.getSomeEditorContributions(ids));
        editor.getViewModel().setHasFocus(true);
        editors.push(editor);
        return editor;
    }

    function assertColor(red:Float, green:Float, blue:Float, alpha:Float, color:IColor, ?pos:PosInfos):Void {
        assertFloatEquals(red, color.red, 0.00001, 'red', pos);
        assertFloatEquals(green, color.green, 0.00001, 'green', pos);
        assertFloatEquals(blue, color.blue, 0.00001, 'blue', pos);
        assertFloatEquals(alpha, color.alpha, 0.00001, 'alpha', pos);
    }

    function assertRange(expected:Range, actual:IRange, ?pos:PosInfos):Void {
        assertTrue(expected.equalsRange(actual), 'expected ' + expected.toString() + ' got ' + Range.lift(actual).toString(), pos);
    }

    /**
     * The mouse target of the swatch of a line, found like the view's hit
     * test (`getInjectedTextAt` on the view columns of the line).
     */
    static function swatchTarget(editor:TestCodeEditor, lineNumber:Int):MouseTarget {
        final viewModel = editor.getViewModel();
        for (column in 1...viewModel.getLineMaxColumn(lineNumber) + 1) {
            final viewPosition = new Position(lineNumber, column);
            final injected = viewModel.getInjectedTextAt(viewPosition);
            if (injected != null) {
                final position = viewModel.coordinatesConverter.convertViewPositionToModelPosition(viewPosition);
                final target = new MouseTarget(MouseTargetType.CONTENT_TEXT, position, column, Range.fromPositions(position, position));
                target.injectedText = injected;
                return target;
            }
        }
        return null;
    }

    static function textTarget(lineNumber:Int, column:Int):MouseTarget {
        final position = new Position(lineNumber, column);
        return new MouseTarget(MouseTargetType.CONTENT_TEXT, position, column, Range.fromPositions(position, position));
    }

    static function fire(editor:TestCodeEditor, kind:String, target:MouseTarget):Void {
        final e = new EditorMouseEvent(new EditorMouseEventData(true, false, false, false, false, false, false, 1), target);
        switch kind {
            case 'move': @:privateAccess editor._fireMouseMove(e);
            case 'down': @:privateAccess editor._fireMouseDown(e);
            case 'up': @:privateAccess editor._fireMouseUp(e);
            case _:
        }
    }

    // ---- defaultDocumentColorsComputer.ts

    function testDefaultColorsComputer() {
        final m = context.modelService.createModel(TEXT, 'plaintext');
        final colors = DefaultDocumentColorsComputer.computeDefaultDocumentColors(new TextModelDocumentColorComputerTarget(m));
        assertEquals(5, colors.length);
        assertRange(new Range(1, 5, 1, 12), colors[0].range);
        assertColor(1, 0, 0, 1, colors[0].color);
        assertRange(new Range(2, 5, 2, 21), colors[1].range);
        assertColor(0, 128 / 255, 1, 1, colors[1].color);
        assertRange(new Range(3, 5, 3, 24), colors[2].range);
        assertColor(0, 1, 0, 1, colors[2].color);
        assertRange(new Range(4, 5, 4, 26), colors[3].range);
        assertColor(10 / 255, 20 / 255, 30 / 255, 0.5, colors[3].color);
        assertRange(new Range(5, 5, 5, 9), colors[4].range);
        assertColor(0xaa / 255, 0xbb / 255, 0xcc / 255, 1, colors[4].color);
        m.dispose();
    }

    function testDefaultColorsComputerSkipsInvalidColorsAndTheFirstOffset() {
        final m = context.modelService.createModel('#fff rgb(300, 0, 0) hsl(10, 20, 30) #12345 #fff', 'plaintext');
        final colors = DefaultDocumentColorsComputer.computeDefaultDocumentColors(new TextModelDocumentColorComputerTarget(m));
        // Monaco's `_findRange` skips a match at offset 0 (`if (!index)`);
        // rgb(300...) and hsl without % fail the parameter checks; #12345
        // is not a hex color
        assertEquals(1, colors.length);
        assertRange(new Range(1, 44, 1, 48), colors[0].range);
        m.dispose();
    }

    // ---- defaultDocumentColorProvider.ts

    function testDefaultColorPresentations() {
        final provider = new DefaultDocumentColorProvider();
        final range:IRange = {startLineNumber: 1, startColumn: 1, endLineNumber: 1, endColumn: 8};
        var presentations:Array<IColorPresentation> = null;
        provider.provideColorPresentations(null, {range: range, color: {red: 1, green: 0, blue: 0, alpha: 1}}, CancellationTokens.None, p -> presentations = p);
        assertEquals(3, presentations.length);
        assertEquals('rgb(255, 0, 0)', presentations[0].label);
        assertEquals('hsl(0, 100.00%, 50.00%)', presentations[1].label);
        assertEquals('#ff0000', presentations[2].label);
        assertEquals('#ff0000', presentations[2].textEdit.text);
        provider.provideColorPresentations(null, {range: range, color: {red: 0, green: 0, blue: 1, alpha: 0.5}}, CancellationTokens.None, p -> presentations = p);
        assertEquals('rgba(0, 0, 255, 0.5)', presentations[0].label);
        assertEquals('hsla(240, 100.00%, 50.00%, 0.50)', presentations[1].label);
        assertEquals('#0000ff', presentations[2].label);
    }

    // ---- colorDetector.ts

    function testDefaultColorDecoratorsAreOffByDefault() {
        final editor = newEditor(TEXT, {});
        assertEquals(0, ColorDetector.get(editor).getColorDatas().length);
        assertEquals(0, ColorDetector.get(editor).getSwatchRanges().length);
        editor.updateOptions({defaultColorDecorators: true});
        assertEquals(5, ColorDetector.get(editor).getColorDatas().length);
    }

    function testSwatchesOfTheDefaultColors() {
        final editor = newEditor(TEXT, {defaultColorDecorators: true});
        final detector = ColorDetector.get(editor);
        final swatches = detector.getSwatchRanges();
        assertEquals(5, swatches.length);
        assertRange(new Range(1, 5, 1, 12), swatches[0]);
        var found = 0;
        for (d in model.getLineDecorations(1)) {
            final before = d.options.before;
            if (before == null) {
                continue;
            }
            found++;
            assertEquals(' ', before.content);
            assertEquals('colorpicker-color-decoration', before.inlineClassName);
            assertTrue(before.attachedData == ColorDecorationInjectedTextMarker.INSTANCE);
            assertEquals('rgba(255, 0, 0, 1)', (cast before.inlineStyle.background : String));
        }
        assertEquals(1, found);
        for (d in model.getLineDecorations(4)) {
            if (d.options.before != null) {
                assertEquals('rgba(10, 20, 30, 0.5)', (cast d.options.before.inlineStyle.background : String));
            }
        }
        assertEquals(5, detector.limitReporter.computed);
        assertEquals(null, detector.limitReporter.limited);
    }

    function testColorDecoratorsLimit() {
        final editor = newEditor(TEXT, {defaultColorDecorators: true, colorDecoratorsLimit: 2});
        final detector = ColorDetector.get(editor);
        assertEquals(5, detector.getColorDatas().length);
        assertEquals(2, detector.getSwatchRanges().length);
        assertEquals(5, detector.limitReporter.computed);
        assertEquals(2, detector.limitReporter.limited);
    }

    function testTheColorsOfAProviderReplaceTheDefaultOnes() {
        context.registerColorProvider('plaintext', new TestColorProvider([
            {range: new Range(1, 1, 1, 2), color: {red: 0, green: 0, blue: 1, alpha: 1}}
        ], [{label: 'blue'}]));
        final editor = newEditor(TEXT, {defaultColorDecorators: true});
        final datas = ColorDetector.get(editor).getColorDatas();
        assertEquals(1, datas.length);
        assertColor(0, 0, 1, 1, datas[0].colorInfo.color);
    }

    function testColorsAreComputedAgainAfterAnEdit() {
        final editor = newEditor('a = #ff0000;', {defaultColorDecorators: true});
        final detector = ColorDetector.get(editor);
        assertEquals(1, detector.getColorDatas().length);
        editor.executeEdits('test', [{range: new Range(1, 13, 1, 13), text: ' b = #00ff00;'}]);
        detector._flushPendingUpdate();
        assertEquals(2, detector.getColorDatas().length);
        editor.updateOptions({colorDecorators: false});
        assertEquals(0, detector.getSwatchRanges().length);
    }

    // ---- colorContributions.ts, colorHoverParticipant.ts

    function testClickOnASwatchOpensThePickerAndPickingWritesThePresentation() {
        final editor = newEditor(TEXT, {defaultColorDecorators: true});
        final contribution = ColorContribution.get(editor);
        final target = swatchTarget(editor, 1);
        assertNotNull(target);

        fire(editor, 'down', target);
        assertTrue(contribution.isColorPickerVisible);
        final session = contribution.getSession();
        final pickerModel = session.colorHover.model;
        // the presentation of the text is guessed: the hex one
        assertEquals('#ff0000', pickerModel.presentation.label);
        assertEquals(3, pickerModel.colorPresentations.length);

        // picking a color writes it with the presentation shown, undoable
        pickerModel.color = new Color(new RGBA(0, 255, 0, 1));
        pickerModel.flushColor();
        assertEquals('x = #00ff00;', model.getLineContent(1));
        assertTrue(contribution.isColorPickerVisible);

        // a click on the label of the header: the next presentation
        pickerModel.selectNextColorPresentation();
        assertEquals('x = rgb(0, 255, 0);', model.getLineContent(1));
        assertRange(new Range(1, 5, 1, 19), session.getRange());

        model.undo();
        assertEquals('x = #00ff00;', model.getLineContent(1));
        // an edit made elsewhere closes the picker
        assertFalse(contribution.isColorPickerVisible);
        model.undo();
        assertEquals('x = #ff0000;', model.getLineContent(1));
    }

    function testAProviderPresentationWithEditsAndAdditionalEdits() {
        context.registerColorProvider('plaintext', new TestColorProvider([
            {range: new Range(1, 1, 1, 4), color: {red: 1, green: 0, blue: 0, alpha: 1}}
        ], [
            {label: 'RED'},
            {label: 'Red', textEdit: {range: new Range(1, 1, 1, 4), text: 'Rouge'}, additionalTextEdits: [{range: new Range(2, 1, 2, 1), text: '// red\n'}]}
        ]));
        final editor = newEditor('red apple\nend', {});
        final contribution = ColorContribution.get(editor);
        fire(editor, 'down', swatchTarget(editor, 1));
        final pickerModel = contribution.getSession().colorHover.model;
        // `red` starts like the label `RED` (guessColorPresentation)
        assertEquals('RED', pickerModel.presentation.label);
        pickerModel.flushColor();
        assertEquals('RED apple', model.getLineContent(1));
        pickerModel.selectNextColorPresentation();
        assertEquals('Rouge apple\n// red\nend', model.getValue());
    }

    function testClickActivationOnly() {
        final editor = newEditor(TEXT, {defaultColorDecorators: true, colorDecoratorsActivatedOn: 'click'});
        final contribution = ColorContribution.get(editor);
        final target = swatchTarget(editor, 2);
        fire(editor, 'move', target);
        contribution._flushHover();
        assertFalse(contribution.isColorPickerVisible);
        fire(editor, 'down', target);
        assertTrue(contribution.isColorPickerVisible);
        // a click elsewhere closes it
        fire(editor, 'down', textTarget(5, 1));
        assertFalse(contribution.isColorPickerVisible);
    }

    function testHoverActivationOnly() {
        final editor = newEditor(TEXT, {defaultColorDecorators: true, colorDecoratorsActivatedOn: 'hover'});
        final contribution = ColorContribution.get(editor);
        final target = swatchTarget(editor, 2);
        fire(editor, 'down', target);
        assertFalse(contribution.isColorPickerVisible);
        fire(editor, 'move', target);
        assertFalse(contribution.isColorPickerVisible);
        contribution._flushHover();
        assertTrue(contribution.isColorPickerVisible);
        assertEquals(128, contribution.getSession().colorHover.model.color.rgba.g);
        // the mouse leaves the color: the picker closes
        fire(editor, 'move', textTarget(5, 1));
        assertFalse(contribution.isColorPickerVisible);
    }

    function testHoverOnTheTextOfAColor() {
        final editor = newEditor(TEXT, {defaultColorDecorators: true, colorDecoratorsActivatedOn: 'click'});
        final contribution = ColorContribution.get(editor);
        fire(editor, 'move', textTarget(1, 7));
        contribution._flushHover();
        assertTrue(contribution.isColorPickerVisible);
        assertEquals('#ff0000', contribution.getSession().colorHover.model.presentation.label);
    }

    // ---- standaloneColorPickerActions.ts

    function testStandalonePickerInsertsTheColor() {
        final editor = newEditor(TEXT, {defaultColorDecorators: true});
        editor.setSelection(new Range(1, 7, 1, 7));
        editor.trigger('keyboard', ShowOrFocusStandaloneColorPicker.ID, null);
        final controller = StandaloneColorPickerController.get(editor);
        final session = controller.getSession();
        assertNotNull(session);
        final pickerModel = session.colorHover.model;
        // the color of the editor at the selection
        assertEquals(255, pickerModel.color.rgba.r);
        pickerModel.color = new Color(new RGBA(0, 0, 255, 1));
        pickerModel.flushColor();
        // nothing written before Enter
        assertEquals('x = #ff0000;', model.getLineContent(1));
        editor.trigger('keyboard', InsertColorWithStandaloneColorPicker.ID, null);
        assertEquals('x = #0000ff;', model.getLineContent(1));
        assertNull(controller.getSession());
    }

    function testStandalonePickerHides() {
        final editor = newEditor('plain text', {});
        editor.setSelection(new Range(1, 3, 1, 3));
        editor.trigger('keyboard', ShowOrFocusStandaloneColorPicker.ID, null);
        final controller = StandaloneColorPickerController.get(editor);
        assertNotNull(controller.getSession());
        // the default color: black
        assertEquals(0, controller.getSession().colorHover.model.color.rgba.r);
        editor.trigger('keyboard', HideStandaloneColorPicker.ID, null);
        assertNull(controller.getSession());
    }

}
