// Ported from vscode src/vs/editor/contrib/folding/test/browser/foldingModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.folding;

import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.Model.IModelDecorationOptions;
import cityscape.common.Model.IModelDecorationsChangeAccessor;
import cityscape.common.Model.ITextModel;
import cityscape.common.Model.TrackedRangeStickiness;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.folding.view.Folding.FoldingController;
import cityscape.contrib.folding.view.FoldingModel;
import cityscape.contrib.folding.view.FoldingRanges;
import cityscape.contrib.folding.view.IndentRangeProvider;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

typedef ExpectedRegion = {
    var startLineNumber:Int;
    var endLineNumber:Int;
    var isCollapsed:Bool;
}

typedef ExpectedDecoration = {
    var line:Int;
    /**
     * `'hidden'`, `'collapsed'` or `'expanded'`.
     */
    var type:String;
}

class TestDecorationProvider implements IDecorationProvider {

    static final collapsedDecoration = ModelDecorationOptions.register({
        description: 'test',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        linesDecorationsClassName: 'folding'
    });

    static final expandedDecoration = ModelDecorationOptions.register({
        description: 'test',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        linesDecorationsClassName: 'folding'
    });

    static final hiddenDecoration = ModelDecorationOptions.register({
        description: 'test',
        stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        linesDecorationsClassName: 'folding'
    });

    final model:ITextModel;

    public function new(model:ITextModel) {
        this.model = model;
    }

    public function getDecorationOption(isCollapsed:Bool, isHidden:Bool, isManual:Bool):IModelDecorationOptions {
        if (isHidden) {
            return cast hiddenDecoration;
        }
        if (isCollapsed) {
            return cast collapsedDecoration;
        }
        return cast expandedDecoration;
    }

    public function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T> {
        return model.changeDecorations(callback);
    }

    public function removeDecorations(decorationIds:Array<String>):Void {
        model.changeDecorations((changeAccessor) -> {
            changeAccessor.deltaDecorations(decorationIds, []);
            return true;
        });
    }

    public function getDecorations():Array<ExpectedDecoration> {
        final decorations = model.getAllDecorations();
        final res:Array<ExpectedDecoration> = [];
        for (decoration in decorations) {
            final options:Any = decoration.options;
            if (options == (hiddenDecoration : Any)) {
                res.push({line: decoration.range.startLineNumber, type: 'hidden'});
            }
            else if (options == (collapsedDecoration : Any)) {
                res.push({line: decoration.range.startLineNumber, type: 'collapsed'});
            }
            else if (options == (expandedDecoration : Any)) {
                res.push({line: decoration.range.startLineNumber, type: 'expanded'});
            }
        }
        return res;
    }
}

/**
 * Suite 'Folding Model'. Filters taking a level use
 * `getRegionsInsideWithLevel` (Monaco checks the arity of the filter).
 */
class FoldingModelTest extends TestCase {

    static function r(startLineNumber:Int, endLineNumber:Int, isCollapsed:Bool = false):ExpectedRegion {
        return {startLineNumber: startLineNumber, endLineNumber: endLineNumber, isCollapsed: isCollapsed};
    }

    static function d(line:Int, type:String):ExpectedDecoration {
        return {line: line, type: type};
    }

    function assertRegion(actual:Null<FoldingRegion>, expected:Null<ExpectedRegion>, ?message:String, ?pos:haxe.PosInfos):Void {
        assertEquals(expected != null, actual != null, message, pos);
        if (actual != null && expected != null) {
            assertEquals(expected.startLineNumber, actual.startLineNumber, message, pos);
            assertEquals(expected.endLineNumber, actual.endLineNumber, message, pos);
            assertEquals(expected.isCollapsed, actual.isCollapsed, message, pos);
        }
    }

    function assertFoldedRanges(foldingModel:FoldingModel, expectedRegions:Array<ExpectedRegion>, ?message:String, ?pos:haxe.PosInfos):Void {
        final actualRanges:Array<ExpectedRegion> = [];
        final actual = foldingModel.regions;
        for (i in 0...actual.length) {
            if (actual.isCollapsed(i)) {
                actualRanges.push(r(actual.getStartLineNumber(i), actual.getEndLineNumber(i)));
            }
        }
        assertDeepEquals(expectedRegions, actualRanges, message, pos);
    }

    function assertRanges(foldingModel:FoldingModel, expectedRegions:Array<ExpectedRegion>, ?message:String, ?pos:haxe.PosInfos):Void {
        final actualRanges:Array<ExpectedRegion> = [];
        final actual = foldingModel.regions;
        for (i in 0...actual.length) {
            actualRanges.push(r(actual.getStartLineNumber(i), actual.getEndLineNumber(i), actual.isCollapsed(i)));
        }
        assertDeepEquals(expectedRegions, actualRanges, message, pos);
    }

    function assertDecorations(foldingModel:FoldingModel, expectedDecoration:Array<ExpectedDecoration>, ?message:String, ?pos:haxe.PosInfos):Void {
        final decorationProvider:TestDecorationProvider = cast foldingModel.decorationProvider;
        assertDeepEquals(expectedDecoration, decorationProvider.getDecorations(), message, pos);
    }

    function assertRegions(actual:Array<FoldingRegion>, expectedRegions:Array<ExpectedRegion>, ?message:String, ?pos:haxe.PosInfos):Void {
        assertDeepEquals(expectedRegions, [for (r in actual) {startLineNumber: r.startLineNumber, endLineNumber: r.endLineNumber, isCollapsed: r.isCollapsed}], message, pos);
    }

    static function markers(start:String, end:String) {
        return {start: new RegExp(start), end: new RegExp(end)};
    }

    function testGetRegionAtLine() {
        final lines = [
        /* 1*/ '/**',
        /* 2*/ ' * Comment',
        /* 3*/ ' */',
        /* 4*/ 'class A {',
        /* 5*/ '  void foo() {',
        /* 6*/ '    // comment {',
        /* 7*/ '  }',
        /* 8*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(1, 3, false);
        final r2 = r(4, 7, false);
        final r3 = r(5, 6, false);

        assertRanges(foldingModel, [r1, r2, r3]);

        assertRegion(foldingModel.getRegionAtLine(1), r1, '1');
        assertRegion(foldingModel.getRegionAtLine(2), r1, '2');
        assertRegion(foldingModel.getRegionAtLine(3), r1, '3');
        assertRegion(foldingModel.getRegionAtLine(4), r2, '4');
        assertRegion(foldingModel.getRegionAtLine(5), r3, '5');
        assertRegion(foldingModel.getRegionAtLine(6), r3, '5');
        assertRegion(foldingModel.getRegionAtLine(7), r2, '6');
        assertRegion(foldingModel.getRegionAtLine(8), null, '7');
        textModel.dispose();
    }

    function testCollapse() {
        final lines = [
        /* 1*/ '/**',
        /* 2*/ ' * Comment',
        /* 3*/ ' */',
        /* 4*/ 'class A {',
        /* 5*/ '  void foo() {',
        /* 6*/ '    // comment {',
        /* 7*/ '  }',
        /* 8*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(1, 3, false);
        final r2 = r(4, 7, false);
        final r3 = r(5, 6, false);

        assertRanges(foldingModel, [r1, r2, r3]);

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(1)]);
        foldingModel.update(ranges);

        assertRanges(foldingModel, [r(1, 3, true), r2, r3]);

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(5)]);
        foldingModel.update(ranges);

        assertRanges(foldingModel, [r(1, 3, true), r2, r(5, 6, true)]);

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(7)]);
        foldingModel.update(ranges);

        assertRanges(foldingModel, [r(1, 3, true), r(4, 7, true), r(5, 6, true)]);

        textModel.dispose();
    }

    function testUpdate() {
        final lines = [
        /* 1*/ '/**',
        /* 2*/ ' * Comment',
        /* 3*/ ' */',
        /* 4*/ 'class A {',
        /* 5*/ '  void foo() {',
        /* 6*/ '    // comment {',
        /* 7*/ '  }',
        /* 8*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(1, 3, false);
        final r2 = r(4, 7, false);
        final r3 = r(5, 6, false);

        assertRanges(foldingModel, [r1, r2, r3]);
        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(2), foldingModel.getRegionAtLine(5)]);

        textModel.applyEdits([EditOperation.insert(new Position(4, 1), '//hello\n')]);

        foldingModel.update(IndentRangeProviderUtils.computeRanges(textModel, false, null));

        assertRanges(foldingModel, [r(1, 3, true), r(5, 8, false), r(6, 7, true)]);
        textModel.dispose();
    }

    function testDelete() {
        final lines = [
        /* 1*/ 'function foo() {',
        /* 2*/ '  switch (x) {',
        /* 3*/ '    case 1:',
        /* 4*/ '      //hello1',
        /* 5*/ '      break;',
        /* 6*/ '    case 2:',
        /* 7*/ '      //hello2',
        /* 8*/ '      break;',
        /* 9*/ '    case 3:',
        /* 10*/ '      //hello3',
        /* 11*/ '      break;',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(1, 12, false);
        final r2 = r(2, 11, false);
        final r3 = r(3, 5, false);
        final r4 = r(6, 8, false);
        final r5 = r(9, 11, false);

        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);
        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(6)]);

        textModel.applyEdits([EditOperation.delete(new Range(6, 11, 9, 0))]);

        foldingModel.update(IndentRangeProviderUtils.computeRanges(textModel, true, null), FoldingController.toSelectedLines([new Selection(7, 1, 7, 1)]));

        assertRanges(foldingModel, [r(1, 9, false), r(2, 8, false), r(3, 5, false), r(6, 8, false)]);
        textModel.dispose();
    }

    function testGetRegionsInside() {
        final lines = [
        /* 1*/ '/**',
        /* 2*/ ' * Comment',
        /* 3*/ ' */',
        /* 4*/ 'class A {',
        /* 5*/ '  void foo() {',
        /* 6*/ '    // comment {',
        /* 7*/ '  }',
        /* 8*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(1, 3, false);
        final r2 = r(4, 7, false);
        final r3 = r(5, 6, false);

        assertRanges(foldingModel, [r1, r2, r3]);
        final region1 = foldingModel.getRegionAtLine(r1.startLineNumber);
        final region2 = foldingModel.getRegionAtLine(r2.startLineNumber);
        final region3 = foldingModel.getRegionAtLine(r3.startLineNumber);

        assertRegions(foldingModel.getRegionsInside(null), [r1, r2, r3], '1');
        assertRegions(foldingModel.getRegionsInside(region1), [], '2');
        assertRegions(foldingModel.getRegionsInside(region2), [r3], '3');
        assertRegions(foldingModel.getRegionsInside(region3), [], '4');
        textModel.dispose();
    }

    function testGetRegionsInsideWithLevel() {
        final lines = [
            /* 1*/ '//#region',
            /* 2*/ '//#endregion',
            /* 3*/ 'class A {',
            /* 4*/ '  void foo() {',
            /* 5*/ '    if (true) {',
            /* 6*/ '        return;',
            /* 7*/ '    }',
            /* 8*/ '    if (true) {',
            /* 9*/ '      return;',
            /* 10*/ '    }',
            /* 11*/ '  }',
            /* 12*/ '}'];

        final textModel = createTextModel(lines.join('\n'));

        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 2, false);
        final r2 = r(3, 11, false);
        final r3 = r(4, 10, false);
        final r4 = r(5, 6, false);
        final r5 = r(8, 9, false);

        final region1 = foldingModel.getRegionAtLine(r1.startLineNumber);
        final region2 = foldingModel.getRegionAtLine(r2.startLineNumber);
        final region3 = foldingModel.getRegionAtLine(r3.startLineNumber);

        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);

        assertRegions(foldingModel.getRegionsInsideWithLevel(null, (r, level) -> level == 1), [r1, r2], '1');
        assertRegions(foldingModel.getRegionsInsideWithLevel(null, (r, level) -> level == 2), [r3], '2');
        assertRegions(foldingModel.getRegionsInsideWithLevel(null, (r, level) -> level == 3), [r4, r5], '3');

        assertRegions(foldingModel.getRegionsInsideWithLevel(region2, (r, level) -> level == 1), [r3], '4');
        assertRegions(foldingModel.getRegionsInsideWithLevel(region2, (r, level) -> level == 2), [r4, r5], '5');
        assertRegions(foldingModel.getRegionsInsideWithLevel(region3, (r, level) -> level == 1), [r4, r5], '6');

        assertRegions(foldingModel.getRegionsInsideWithLevel(region2, (r, level) -> r.hidesLine(9)), [r3, r5], '7');

        assertRegions(foldingModel.getRegionsInsideWithLevel(region1, (r, level) -> level == 1), [], '8');
        textModel.dispose();
    }

    function testGetRegionAtLine2() {
        final lines = [
        /* 1*/ '//#region',
        /* 2*/ 'class A {',
        /* 3*/ '  void foo() {',
        /* 4*/ '    if (true) {',
        /* 5*/ '      //hello',
        /* 6*/ '    }',
        /* 7*/ '',
        /* 8*/ '  }',
        /* 9*/ '}',
        /* 10*/ '//#endregion',
        /* 11*/ ''];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 10, false);
        final r2 = r(2, 8, false);
        final r3 = r(3, 7, false);
        final r4 = r(4, 5, false);

        assertRanges(foldingModel, [r1, r2, r3, r4]);

        inline function rev(a:Array<ExpectedRegion>):Array<ExpectedRegion> {
            a.reverse();
            return a;
        }
        assertRegions(foldingModel.getAllRegionsAtLine(1), [r1], '1');
        assertRegions(foldingModel.getAllRegionsAtLine(2), rev([r1, r2]), '2');
        assertRegions(foldingModel.getAllRegionsAtLine(3), rev([r1, r2, r3]), '3');
        assertRegions(foldingModel.getAllRegionsAtLine(4), rev([r1, r2, r3, r4]), '4');
        assertRegions(foldingModel.getAllRegionsAtLine(5), rev([r1, r2, r3, r4]), '5');
        assertRegions(foldingModel.getAllRegionsAtLine(6), rev([r1, r2, r3]), '6');
        assertRegions(foldingModel.getAllRegionsAtLine(7), rev([r1, r2, r3]), '7');
        assertRegions(foldingModel.getAllRegionsAtLine(8), rev([r1, r2]), '8');
        assertRegions(foldingModel.getAllRegionsAtLine(9), [r1], '9');
        assertRegions(foldingModel.getAllRegionsAtLine(10), [r1], '10');
        assertRegions(foldingModel.getAllRegionsAtLine(11), [], '10');
        textModel.dispose();
    }

    function testSetCollapseStateRecursivly() {
        final lines = [
        /* 1*/ '//#region',
        /* 2*/ '//#endregion',
        /* 3*/ 'class A {',
        /* 4*/ '  void foo() {',
        /* 5*/ '    if (true) {',
        /* 6*/ '        return;',
        /* 7*/ '    }',
        /* 8*/ '',
        /* 9*/ '    if (true) {',
        /* 10*/ '      return;',
        /* 11*/ '    }',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 2, false);
        final r2 = r(3, 12, false);
        final r3 = r(4, 11, false);
        final r4 = r(5, 6, false);
        final r5 = r(9, 10, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true, FoldingModelUtils.MAX_LEVELS, [4]);
        assertFoldedRanges(foldingModel, [r3, r4, r5], '1');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false, FoldingModelUtils.MAX_LEVELS, [8]);
        assertFoldedRanges(foldingModel, [], '2');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true, FoldingModelUtils.MAX_LEVELS, [12]);
        assertFoldedRanges(foldingModel, [r2, r3, r4, r5], '1');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false, FoldingModelUtils.MAX_LEVELS, [7]);
        assertFoldedRanges(foldingModel, [r2], '1');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false);
        assertFoldedRanges(foldingModel, [], '1');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true);
        assertFoldedRanges(foldingModel, [r1, r2, r3, r4, r5], '1');
        textModel.dispose();
    }

    function testSetCollapseStateAtLevel() {
        final lines = [
        /* 1*/ '//#region',
        /* 2*/ '//#endregion',
        /* 3*/ 'class A {',
        /* 4*/ '  void foo() {',
        /* 5*/ '    if (true) {',
        /* 6*/ '        return;',
        /* 7*/ '    }',
        /* 8*/ '',
        /* 9*/ '    if (true) {',
        /* 10*/ '      return;',
        /* 11*/ '    }',
        /* 12*/ '  }',
        /* 13*/ '  //#region',
        /* 14*/ '  const bar = 9;',
        /* 15*/ '  //#endregion',
        /* 16*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\s*\\/\\/#region$', '^\\s*\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 2, false);
        final r2 = r(3, 15, false);
        final r3 = r(4, 11, false);
        final r4 = r(5, 6, false);
        final r5 = r(9, 10, false);
        final r6 = r(13, 15, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5, r6]);

        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, 1, true, []);
        assertFoldedRanges(foldingModel, [r1, r2], '1');

        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, 1, false, [5]);
        assertFoldedRanges(foldingModel, [r2], '2');

        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, 1, false, [1]);
        assertFoldedRanges(foldingModel, [], '3');

        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, 2, true, []);
        assertFoldedRanges(foldingModel, [r3, r6], '4');

        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, 2, false, [5, 6]);
        assertFoldedRanges(foldingModel, [r3], '5');

        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, 3, true, [4, 9]);
        assertFoldedRanges(foldingModel, [r3, r4], '6');

        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, 3, false, [4, 9]);
        assertFoldedRanges(foldingModel, [r3], '7');
        textModel.dispose();
    }

    function testSetCollapseStateLevelsDown() {
        final lines = [
        /* 1*/ '//#region',
        /* 2*/ '//#endregion',
        /* 3*/ 'class A {',
        /* 4*/ '  void foo() {',
        /* 5*/ '    if (true) {',
        /* 6*/ '        return;',
        /* 7*/ '    }',
        /* 8*/ '',
        /* 9*/ '    if (true) {',
        /* 10*/ '      return;',
        /* 11*/ '    }',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 2, false);
        final r2 = r(3, 12, false);
        final r3 = r(4, 11, false);
        final r4 = r(5, 6, false);
        final r5 = r(9, 10, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true, 1, [4]);
        assertFoldedRanges(foldingModel, [r3], '1');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true, 2, [4]);
        assertFoldedRanges(foldingModel, [r3, r4, r5], '2');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false, 2, [3]);
        assertFoldedRanges(foldingModel, [r4, r5], '3');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false, 2, [2]);
        assertFoldedRanges(foldingModel, [r4, r5], '4');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true, 4, [2]);
        assertFoldedRanges(foldingModel, [r1, r4, r5], '5');

        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false, 4, [2, 3]);
        assertFoldedRanges(foldingModel, [], '6');
        textModel.dispose();
    }

    function testSetCollapseStateLevelsUp() {
        final lines = [
        /* 1*/ '//#region',
        /* 2*/ '//#endregion',
        /* 3*/ 'class A {',
        /* 4*/ '  void foo() {',
        /* 5*/ '    if (true) {',
        /* 6*/ '        return;',
        /* 7*/ '    }',
        /* 8*/ '',
        /* 9*/ '    if (true) {',
        /* 10*/ '      return;',
        /* 11*/ '    }',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 2, false);
        final r2 = r(3, 12, false);
        final r3 = r(4, 11, false);
        final r4 = r(5, 6, false);
        final r5 = r(9, 10, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);

        FoldingModelUtils.setCollapseStateLevelsUp(foldingModel, true, 1, [4]);
        assertFoldedRanges(foldingModel, [r3], '1');

        FoldingModelUtils.setCollapseStateLevelsUp(foldingModel, true, 2, [4]);
        assertFoldedRanges(foldingModel, [r2, r3], '2');

        FoldingModelUtils.setCollapseStateLevelsUp(foldingModel, false, 4, [1, 3, 4]);
        assertFoldedRanges(foldingModel, [], '3');

        FoldingModelUtils.setCollapseStateLevelsUp(foldingModel, true, 2, [10]);
        assertFoldedRanges(foldingModel, [r3, r5], '4');
        textModel.dispose();
    }

    function testSetCollapseStateUp() {
        final lines = [
        /* 1*/ '//#region',
        /* 2*/ '//#endregion',
        /* 3*/ 'class A {',
        /* 4*/ '  void foo() {',
        /* 5*/ '    if (true) {',
        /* 6*/ '        return;',
        /* 7*/ '    }',
        /* 8*/ '',
        /* 9*/ '    if (true) {',
        /* 10*/ '      return;',
        /* 11*/ '    }',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 2, false);
        final r2 = r(3, 12, false);
        final r3 = r(4, 11, false);
        final r4 = r(5, 6, false);
        final r5 = r(9, 10, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);

        FoldingModelUtils.setCollapseStateUp(foldingModel, true, [5]);
        assertFoldedRanges(foldingModel, [r4], '1');

        FoldingModelUtils.setCollapseStateUp(foldingModel, true, [5]);
        assertFoldedRanges(foldingModel, [r3, r4], '2');

        FoldingModelUtils.setCollapseStateUp(foldingModel, true, [4]);
        assertFoldedRanges(foldingModel, [r2, r3, r4], '2');
        textModel.dispose();
    }

    function testSetCollapseStateForMatchingLines() {
        final lines = [
        /* 1*/ '/**',
        /* 2*/ ' * the class',
        /* 3*/ ' */',
        /* 4*/ 'class A {',
        /* 5*/ '  /**',
        /* 6*/ '   * the foo',
        /* 7*/ '   */',
        /* 8*/ '  void foo() {',
        /* 9*/ '    /*',
        /* 10*/ '     * the comment',
        /* 11*/ '     */',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 3, false);
        final r2 = r(4, 12, false);
        final r3 = r(5, 7, false);
        final r4 = r(8, 11, false);
        final r5 = r(9, 11, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);

        final regExp = new RegExp('^\\s*' + Strings.escapeRegExpCharacters('/*'));
        FoldingModelUtils.setCollapseStateForMatchingLines(foldingModel, regExp, true);
        assertFoldedRanges(foldingModel, [r1, r3, r5], '1');
        textModel.dispose();
    }

    function testSetCollapseStateForRest() {
        final lines = [
        /* 1*/ '//#region',
        /* 2*/ '//#endregion',
        /* 3*/ 'class A {',
        /* 4*/ '  void foo() {',
        /* 5*/ '    if (true) {',
        /* 6*/ '        return;',
        /* 7*/ '    }',
        /* 8*/ '',
        /* 9*/ '    if (true) {',
        /* 10*/ '      return;',
        /* 11*/ '    }',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, markers('^\\/\\/#region$', '^\\/\\/#endregion$'));
        foldingModel.update(ranges);

        final r1 = r(1, 2, false);
        final r2 = r(3, 12, false);
        final r3 = r(4, 11, false);
        final r4 = r(5, 6, false);
        final r5 = r(9, 10, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5]);

        FoldingModelUtils.setCollapseStateForRest(foldingModel, true, [5]);
        assertFoldedRanges(foldingModel, [r1, r5], '1');

        FoldingModelUtils.setCollapseStateForRest(foldingModel, false, [5]);
        assertFoldedRanges(foldingModel, [], '2');

        FoldingModelUtils.setCollapseStateForRest(foldingModel, true, [1]);
        assertFoldedRanges(foldingModel, [r2, r3, r4, r5], '3');

        FoldingModelUtils.setCollapseStateForRest(foldingModel, true, [3]);
        assertFoldedRanges(foldingModel, [r1, r2, r3, r4, r5], '3');
        textModel.dispose();
    }

    function testFoldingDecoration() {
        final lines = [
        /* 1*/ 'class A {',
        /* 2*/ '  void foo() {',
        /* 3*/ '    if (true) {',
        /* 4*/ '      hoo();',
        /* 5*/ '    }',
        /* 6*/ '  }',
        /* 7*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(1, 6, false);
        final r2 = r(2, 5, false);
        final r3 = r(3, 4, false);

        assertRanges(foldingModel, [r1, r2, r3]);
        assertDecorations(foldingModel, [d(1, 'expanded'), d(2, 'expanded'), d(3, 'expanded')]);

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(2)]);

        assertRanges(foldingModel, [r1, r(2, 5, true), r3]);
        assertDecorations(foldingModel, [d(1, 'expanded'), d(2, 'collapsed'), d(3, 'hidden')]);

        foldingModel.update(ranges);

        assertRanges(foldingModel, [r1, r(2, 5, true), r3]);
        assertDecorations(foldingModel, [d(1, 'expanded'), d(2, 'collapsed'), d(3, 'hidden')]);

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(1)]);

        assertRanges(foldingModel, [r(1, 6, true), r(2, 5, true), r3]);
        assertDecorations(foldingModel, [d(1, 'collapsed'), d(2, 'hidden'), d(3, 'hidden')]);

        foldingModel.update(ranges);

        assertRanges(foldingModel, [r(1, 6, true), r(2, 5, true), r3]);
        assertDecorations(foldingModel, [d(1, 'collapsed'), d(2, 'hidden'), d(3, 'hidden')]);

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(1), foldingModel.getRegionAtLine(3)]);

        assertRanges(foldingModel, [r1, r(2, 5, true), r(3, 4, true)]);
        assertDecorations(foldingModel, [d(1, 'expanded'), d(2, 'collapsed'), d(3, 'hidden')]);

        foldingModel.update(ranges);

        assertRanges(foldingModel, [r1, r(2, 5, true), r(3, 4, true)]);
        assertDecorations(foldingModel, [d(1, 'expanded'), d(2, 'collapsed'), d(3, 'hidden')]);

        textModel.dispose();
    }

    function testFoldJumping() {
        final lines = [
            /* 1*/ 'class A {',
            /* 2*/ '  void foo() {',
            /* 3*/ '    if (1) {',
            /* 4*/ '      a();',
            /* 5*/ '    } else if (2) {',
            /* 6*/ '      if (true) {',
            /* 7*/ '        b();',
            /* 8*/ '      }',
            /* 9*/ '    } else {',
            /* 10*/ '      c();',
            /* 11*/ '    }',
            /* 12*/ '  }',
            /* 13*/ '}'
        ];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(1, 12, false);
        final r2 = r(2, 11, false);
        final r3 = r(3, 4, false);
        final r4 = r(5, 8, false);
        final r5 = r(6, 7, false);
        final r6 = r(9, 10, false);
        assertRanges(foldingModel, [r1, r2, r3, r4, r5, r6]);

        // Test jump to parent.
        assertEquals(6, FoldingModelUtils.getParentFoldLine(7, foldingModel));
        assertEquals(5, FoldingModelUtils.getParentFoldLine(6, foldingModel));
        assertEquals(2, FoldingModelUtils.getParentFoldLine(5, foldingModel));
        assertEquals(1, FoldingModelUtils.getParentFoldLine(2, foldingModel));
        assertEquals(null, FoldingModelUtils.getParentFoldLine(1, foldingModel));

        // Test jump to previous.
        assertEquals(9, FoldingModelUtils.getPreviousFoldLine(10, foldingModel));
        assertEquals(5, FoldingModelUtils.getPreviousFoldLine(9, foldingModel));
        assertEquals(3, FoldingModelUtils.getPreviousFoldLine(5, foldingModel));
        assertEquals(null, FoldingModelUtils.getPreviousFoldLine(3, foldingModel));
        // Test when not on a folding region start line.
        assertEquals(3, FoldingModelUtils.getPreviousFoldLine(4, foldingModel));
        assertEquals(6, FoldingModelUtils.getPreviousFoldLine(7, foldingModel));
        assertEquals(6, FoldingModelUtils.getPreviousFoldLine(8, foldingModel));

        // Test jump to next.
        assertEquals(5, FoldingModelUtils.getNextFoldLine(3, foldingModel));
        assertEquals(9, FoldingModelUtils.getNextFoldLine(5, foldingModel));
        assertEquals(null, FoldingModelUtils.getNextFoldLine(9, foldingModel));
        // Test when not on a folding region start line.
        assertEquals(5, FoldingModelUtils.getNextFoldLine(4, foldingModel));
        assertEquals(9, FoldingModelUtils.getNextFoldLine(7, foldingModel));
        assertEquals(9, FoldingModelUtils.getNextFoldLine(8, foldingModel));
        textModel.dispose();
    }

    function testFoldJumpingIssue129503() {
        final lines = [
            /* 1*/ '',
            /* 2*/ 'if True:',
            /* 3*/ '  print(1)',
            /* 4*/ 'if True:',
            /* 5*/ '  print(1)',
            /* 6*/ ''
        ];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        final r1 = r(2, 3, false);
        final r2 = r(4, 6, false);
        assertRanges(foldingModel, [r1, r2]);

        // Test jump to next.
        assertEquals(2, FoldingModelUtils.getNextFoldLine(1, foldingModel));
        assertEquals(4, FoldingModelUtils.getNextFoldLine(2, foldingModel));
        assertEquals(4, FoldingModelUtils.getNextFoldLine(3, foldingModel));
        assertEquals(null, FoldingModelUtils.getNextFoldLine(4, foldingModel));
        assertEquals(null, FoldingModelUtils.getNextFoldLine(5, foldingModel));
        assertEquals(null, FoldingModelUtils.getNextFoldLine(6, foldingModel));

        // Test jump to previous.
        assertEquals(null, FoldingModelUtils.getPreviousFoldLine(1, foldingModel));
        assertEquals(null, FoldingModelUtils.getPreviousFoldLine(2, foldingModel));
        assertEquals(2, FoldingModelUtils.getPreviousFoldLine(3, foldingModel));
        assertEquals(2, FoldingModelUtils.getPreviousFoldLine(4, foldingModel));
        assertEquals(4, FoldingModelUtils.getPreviousFoldLine(5, foldingModel));
        assertEquals(4, FoldingModelUtils.getPreviousFoldLine(6, foldingModel));
        textModel.dispose();
    }
}
