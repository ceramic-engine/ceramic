// New code for Cityscape (not a port): tests of the view model with the test
// double model, and of hidden ranges inside lines (a Cityscape addition,
// docs/DEVIATIONS.md "Hidden text inside a line").
package tests.viewModel;

import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.viewModel.MonospaceLineBreaksComputer;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.view.config.EditorConfiguration;
import testing.TestCase;
import cityscape.common.model.TextModel;
import tests.TestTextModel.createTextModel;

class ViewModelHiddenRangesTest extends TestCase {

    static var nextEditorId = 1;

    static function createViewModel(model:TextModel, ?options:IEditorOptions):ViewModel {
        final configuration = new EditorConfiguration(false, options != null ? options : {}, {width: 1000, height: 400});
        final factory = MonospaceLineBreaksComputerFactory.create(EditorViewOptions.DEFAULT_WORD_WRAP_BREAK_BEFORE_CHARACTERS, EditorViewOptions.DEFAULT_WORD_WRAP_BREAK_AFTER_CHARACTERS);
        return new ViewModel(nextEditorId++, configuration, model, factory, factory);
    }

    function testLinesAsIs() {
        final model = createTextModel('line one\nline two\n\nline four');
        final viewModel = createViewModel(model);
        assertEquals(4, viewModel.getLineCount());
        assertEquals('line two', viewModel.getLineContent(2));
        assertEquals('', viewModel.getLineContent(3));
        viewModel.dispose();
    }

    function testHiddenRangeInsideALine() {
        final model = createTextModel('say hello #tag world\nnext');
        final viewModel = createViewModel(model);
        model.deltaDecorations([], [{range: new Range(1, 11, 1, 16), options: {description: 'hide', hidden: true}}]);
        assertEquals('say hello world', viewModel.getLineContent(1));
        // model positions inside the hidden range go to its start
        final converter = viewModel.coordinatesConverter;
        assertEquals('(1,11)', converter.convertModelPositionToViewPosition(new Position(1, 13)).toString());
        assertEquals('(1,11)', converter.convertModelPositionToViewPosition(new Position(1, 16)).toString());
        assertEquals('(1,12)', converter.convertModelPositionToViewPosition(new Position(1, 17)).toString());
        // view positions after it map after it in the model
        assertEquals('(1,17)', converter.convertViewPositionToModelPosition(new Position(1, 12)).toString());
        viewModel.dispose();
    }

    function testRevealOnCursorLine() {
        final model = createTextModel('say hello #tag world\nnext #x');
        final viewModel = createViewModel(model);
        model.deltaDecorations([], [
            {range: new Range(1, 11, 1, 16), options: {description: 'hide', hidden: true, revealOnCursorLine: true}},
            {range: new Range(2, 6, 2, 8), options: {description: 'hide', hidden: true, revealOnCursorLine: true}}
        ]);
        // the cursor is on line 1 (1,1): its hidden range shows
        assertEquals('say hello #tag world', viewModel.getLineContent(1));
        assertEquals('next ', viewModel.getLineContent(2));
        viewModel.setSelections('test', [new Selection(2, 1, 2, 1)]);
        assertEquals('say hello world', viewModel.getLineContent(1));
        assertEquals('next #x', viewModel.getLineContent(2));
        viewModel.dispose();
    }

    function testReplacement() {
        final model = createTextModel('a [long] b');
        final viewModel = createViewModel(model);
        final replacement:InjectedTextOptions = {content: '…'};
        model.deltaDecorations([], [{range: new Range(1, 3, 1, 9), options: {description: 'fold', replacement: replacement}}]);
        assertEquals('a … b', viewModel.getLineContent(1));
        viewModel.dispose();
    }

    function testModelInjectedTextBeforeTheView() {
        // decorations added before the view model exists, with a typed style
        // (an empty range needs `showIfCollapsed`, as in Monaco)
        final model = createTextModel('  hasCoffee: false\nnext');
        final after:InjectedTextOptions = {content: '  (bool)', inlineStyle: {color: '#5c6370'}};
        model.deltaDecorations([], [{range: new Range(1, 19, 1, 19), options: {description: 'hint', after: after, showIfCollapsed: true}}]);
        final viewModel = createViewModel(model);
        assertEquals('  hasCoffee: false  (bool)', viewModel.getLineContent(1));
        viewModel.dispose();
    }

    function testTwoEditorsHideIndependently() {
        final model = createTextModel('x #tag y');
        final a = createViewModel(model);
        final b = createViewModel(model);
        model.deltaDecorations([], [{range: new Range(1, 3, 1, 8), options: {description: 'hide', hidden: true, revealOnCursorLine: true}}]);
        // both cursors are on line 1
        assertEquals('x #tag y', a.getLineContent(1));
        assertEquals('x #tag y', b.getLineContent(1));
        model.applyEdits([{range: new Range(1, 9, 1, 9), text: '\nz'}]);
        a.setSelections('test', [new Selection(2, 1, 2, 1)]);
        assertEquals('x y', a.getLineContent(1));
        assertEquals('x #tag y', b.getLineContent(1));
        a.dispose();
        b.dispose();
    }

    function testWrappingWithHiddenRange() {
        final model = createTextModel('aaaa #hidden bbbb cccc dddd');
        final viewModel = createViewModel(model, {wordWrap: 'wordWrapColumn', wordWrapColumn: 10, wrappingIndent: 'none'});
        model.deltaDecorations([], [{range: new Range(1, 6, 1, 14), options: {description: 'hide', hidden: true}}]);
        // 'aaaa bbbb cccc dddd' wraps at 10 columns
        assertEquals(2, viewModel.getLineCount());
        assertEquals('aaaa bbbb ', viewModel.getLineContent(1));
        assertEquals('cccc dddd', viewModel.getLineContent(2));
        viewModel.dispose();
    }

    function testEditsMoveTheView() {
        final model = createTextModel('one\ntwo\nthree');
        final viewModel = createViewModel(model);
        model.applyEdits([{range: new Range(2, 1, 2, 4), text: 'TWO\nand a half'}]);
        assertEquals(4, viewModel.getLineCount());
        assertEquals('TWO', viewModel.getLineContent(2));
        assertEquals('and a half', viewModel.getLineContent(3));
        model.applyEdits([{range: new Range(1, 4, 3, 11), text: ''}]);
        assertEquals(2, viewModel.getLineCount());
        assertEquals('one', viewModel.getLineContent(1));
        viewModel.dispose();
    }

}
