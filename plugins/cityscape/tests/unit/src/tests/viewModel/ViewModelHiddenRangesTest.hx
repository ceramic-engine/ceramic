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

    /** The hidden decorations of a model: `line,column-line,column description`, sorted. */
    static function hiddenOf(model:TextModel, ?ownerId:Int):String {
        final out = [for (d in model.getHiddenDecorations(ownerId)) d.range.startLineNumber + ',' + d.range.startColumn + '-' + d.range.endLineNumber + ',' + d.range.endColumn + ' ' + d.options.description];
        out.sort(Reflect.compare);
        return out.join(' | ');
    }

    function testHiddenDecorationsAreReadWithoutTheOthers() {
        final lines = [for (i in 0...200) 'line $i has some text #tag'];
        final model = createTextModel(lines.join('\n'));
        final viewModel = createViewModel(model);
        // the decorations of the view model itself
        final own = model.getAllDecorations().length;
        // many decorations that hide nothing
        final plain = model.deltaDecorations([], [for (i in 0...200) {range: new Range(i + 1, 1, i + 1, 5), options: {description: 'plain', inlineClassName: 'word'}}]);
        assertEquals('', hiddenOf(model));
        assertEquals(own + 200, model.getAllDecorations().length);

        // three that do: a plain one, one that also shows in the overview
        // ruler, one that also injects text (Monaco keeps those two in
        // trees of their own)
        final hidden = model.deltaDecorations([], [
            {range: new Range(10, 22, 10, 26), options: {description: 'a', hidden: true}},
            {range: new Range(20, 22, 20, 26), options: {description: 'b', hidden: true, overviewRuler: {color: '#ff0000', position: cityscape.common.Model.OverviewRulerLane.Full}}},
            {range: new Range(30, 22, 30, 26), options: {description: 'c', replacement: {content: '*'}, after: {content: '!'}}}
        ], 7);
        assertEquals('10,22-10,26 a | 20,22-20,26 b | 30,22-30,26 c', hiddenOf(model));
        assertEquals('10,22-10,26 a | 20,22-20,26 b | 30,22-30,26 c', hiddenOf(model, 7));
        assertEquals('', hiddenOf(model, 8));
        // every decoration is still part of the whole
        assertEquals(own + 203, model.getAllDecorations().length);
        assertEquals(1, model.getOverviewRulerDecorations().length);
        assertEquals(1, model.getInjectedTextDecorations().length);
        assertEquals(2, model.getDecorationsInRange(new Range(10, 1, 10, 30)).length);
        assertEquals(2, model.getLineDecorations(20).length);

        // they follow the edits like the others
        model.applyEdits([{range: new Range(1, 1, 1, 1), text: 'new first line\n'}, {range: new Range(10, 1, 10, 1), text: '>> '}]);
        assertEquals('11,25-11,29 a | 21,22-21,26 b | 31,22-31,26 c', hiddenOf(model));
        assertEquals('[11,25 -> 11,29]', model.getDecorationRange(hidden[0]).toString());

        // options changed in place: a decoration starts or stops hiding
        model.changeDecorations(accessor -> {
            accessor.changeDecorationOptions(plain[4], {description: 'now hidden', hidden: true});
            accessor.changeDecorationOptions(hidden[0], {description: 'shown again', inlineClassName: 'word'});
            return null;
        });
        assertEquals('21,22-21,26 b | 31,22-31,26 c | 6,1-6,5 now hidden', hiddenOf(model));
        assertEquals(own + 203, model.getAllDecorations().length);
        assertEquals('[11,25 -> 11,29]', model.getDecorationRange(hidden[0]).toString());
        // moved, and its line edited
        model.changeDecorations(accessor -> {
            accessor.changeDecoration(plain[4], new Range(7, 1, 7, 6));
            return null;
        });
        model.applyEdits([{range: new Range(7, 1, 7, 1), text: 'x'}]);
        assertEquals('21,22-21,26 b | 31,22-31,26 c | 7,1-7,7 now hidden', hiddenOf(model));

        // removed with their owner, or one by one
        model.removeAllDecorationsWithOwnerId(7);
        assertEquals('7,1-7,7 now hidden', hiddenOf(model));
        model.deltaDecorations([plain[4]], []);
        assertEquals('', hiddenOf(model));
        assertEquals(own + 199, model.getAllDecorations().length);
        viewModel.dispose();
    }

    function testTheViewFollowsHiddenDecorationsAmongManyOthers() {
        final lines = [for (i in 0...300) 'word $i #t$i end'];
        final model = createTextModel(lines.join('\n'));
        final viewModel = createViewModel(model);
        model.deltaDecorations([], [for (i in 0...300) {range: new Range(i + 1, 1, i + 1, 5), options: {description: 'plain', inlineClassName: 'word'}}]);
        // nothing hidden: typing changes the line and nothing else
        model.applyEdits([{range: new Range(150, 1, 150, 1), text: 'A'}]);
        assertEquals('Aword 149 #t149 end', viewModel.getLineContent(150));
        // one tag hidden, then typing before it and on other lines
        final id = model.deltaDecorations([], [{range: new Range(150, 11, 150, 17), options: {description: 'hide', hidden: true}}]);
        assertEquals('Aword 149 end', viewModel.getLineContent(150));
        model.applyEdits([{range: new Range(150, 1, 150, 1), text: 'B'}]);
        assertEquals('BAword 149 end', viewModel.getLineContent(150));
        model.applyEdits([{range: new Range(10, 1, 10, 1), text: 'first\n'}]);
        assertEquals('BAword 149 end', viewModel.getLineContent(151));
        // shown again
        model.deltaDecorations(id, []);
        assertEquals('BAword 149 #t149 end', viewModel.getLineContent(151));
        model.applyEdits([{range: new Range(151, 1, 151, 1), text: 'C'}]);
        assertEquals('CBAword 149 #t149 end', viewModel.getLineContent(151));
        viewModel.dispose();
    }

}
