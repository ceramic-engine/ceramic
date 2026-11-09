// Ported from vscode src/vs/editor/contrib/folding/test/browser/indentRangeProvider.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.folding;

import cityscape.base.common.RegExp;
import cityscape.common.languages.LanguageConfiguration.FoldingMarkers;
import cityscape.contrib.folding.view.IndentRangeProvider;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

typedef ExpectedIndentRange = {
    var startLineNumber:Int;
    var endLineNumber:Int;
    var parentIndex:Int;
}

class IndentRangeProviderTestUtils {

    public static function computeActual(lines:Array<String>, offside:Bool, ?markers:FoldingMarkers):Array<ExpectedIndentRange> {
        final model = createTextModel(lines.join('\n'));
        final actual = IndentRangeProviderUtils.computeRanges(model, offside, markers);

        final actualRanges:Array<ExpectedIndentRange> = [];
        for (i in 0...actual.length) {
            actualRanges[i] = r(actual.getStartLineNumber(i), actual.getEndLineNumber(i), actual.getParentIndex(i));
        }
        model.dispose();
        return actualRanges;
    }

    public static function r(startLineNumber:Int, endLineNumber:Int, parentIndex:Int, marker:Bool = false):ExpectedIndentRange {
        return {startLineNumber: startLineNumber, endLineNumber: endLineNumber, parentIndex: parentIndex};
    }

}

/**
 * Suite 'Indentation Folding' of indentRangeProvider.test.ts.
 */
class IndentRangeProviderTest extends TestCase {

    function assertRanges(lines:Array<String>, expected:Array<ExpectedIndentRange>, offside:Bool, ?markers:FoldingMarkers, ?pos:haxe.PosInfos):Void {
        assertDeepEquals(expected, IndentRangeProviderTestUtils.computeActual(lines, offside, markers), null, pos);
    }

    static inline function r(startLineNumber:Int, endLineNumber:Int, parentIndex:Int, marker:Bool = false):ExpectedIndentRange {
        return IndentRangeProviderTestUtils.r(startLineNumber, endLineNumber, parentIndex, marker);
    }

    function testFoldOneLevel() {
        final range = [
            'A',
            '  A',
            '  A',
            '  A'
        ];
        assertRanges(range, [r(1, 4, -1)], true);
        assertRanges(range, [r(1, 4, -1)], false);
    }

    function testFoldTwoLevels() {
        final range = [
            'A',
            '  A',
            '  A',
            '    A',
            '    A'
        ];
        assertRanges(range, [r(1, 5, -1), r(3, 5, 0)], true);
        assertRanges(range, [r(1, 5, -1), r(3, 5, 0)], false);
    }

    function testFoldThreeLevels() {
        final range = [
            'A',
            '  A',
            '    A',
            '      A',
            'A'
        ];
        assertRanges(range, [r(1, 4, -1), r(2, 4, 0), r(3, 4, 1)], true);
        assertRanges(range, [r(1, 4, -1), r(2, 4, 0), r(3, 4, 1)], false);
    }

    function testFoldDecreasingIndent() {
        final range = [
            '    A',
            '  A',
            'A'
        ];
        assertRanges(range, [], true);
        assertRanges(range, [], false);
    }

    function testFoldJava() {
        assertRanges([
        /* 1*/ 'class A {',
        /* 2*/ '  void foo() {',
        /* 3*/ '    console.log();',
        /* 4*/ '    console.log();',
        /* 5*/ '  }',
        /* 6*/ '',
        /* 7*/ '  void bar() {',
        /* 8*/ '    console.log();',
        /* 9*/ '  }',
        /*10*/ '}',
        /*11*/ 'interface B {',
        /*12*/ '  void bar();',
        /*13*/ '}',
        ], [r(1, 9, -1), r(2, 4, 0), r(7, 8, 0), r(11, 12, -1)], false);
    }

    function testFoldJavadoc() {
        assertRanges([
        /* 1*/ '/**',
        /* 2*/ ' * Comment',
        /* 3*/ ' */',
        /* 4*/ 'class A {',
        /* 5*/ '  void foo() {',
        /* 6*/ '  }',
        /* 7*/ '}',
        ], [r(1, 3, -1), r(4, 6, -1)], false);
    }

    function testFoldWhitespaceJava() {
        assertRanges([
        /* 1*/ 'class A {',
        /* 2*/ '',
        /* 3*/ '  void foo() {',
        /* 4*/ '     ',
        /* 5*/ '     return 0;',
        /* 6*/ '  }',
        /* 7*/ '      ',
        /* 8*/ '}',
        ], [r(1, 7, -1), r(3, 5, 0)], false);
    }

    function testFoldWhitespacePython() {
        assertRanges([
        /* 1*/ 'def a:',
        /* 2*/ '  pass',
        /* 3*/ '   ',
        /* 4*/ '  def b:',
        /* 5*/ '    pass',
        /* 6*/ '  ',
        /* 7*/ '      ',
        /* 8*/ 'def c: # since there was a deintent here'
        ], [r(1, 5, -1), r(4, 5, 0)], true);
    }

    function testFoldTabs() {
        assertRanges([
        /* 1*/ 'class A {',
        /* 2*/ '\t\t',
        /* 3*/ '\tvoid foo() {',
        /* 4*/ '\t \t//hello',
        /* 5*/ '\t    return 0;',
        /* 6*/ '  \t}',
        /* 7*/ '      ',
        /* 8*/ '}',
        ], [r(1, 7, -1), r(3, 5, 0)], false);
    }

}

/**
 * Suite 'Folding with regions' of indentRangeProvider.test.ts.
 */
class FoldingWithRegionsTest extends TestCase {

    static final markers:FoldingMarkers = {
        start: new RegExp('^\\s*#region\\b'),
        end: new RegExp('^\\s*#endregion\\b')
    };

    function assertRanges(lines:Array<String>, expected:Array<ExpectedIndentRange>, offside:Bool, ?markers:FoldingMarkers, ?pos:haxe.PosInfos):Void {
        assertDeepEquals(expected, IndentRangeProviderTestUtils.computeActual(lines, offside, markers), null, pos);
    }

    static inline function r(startLineNumber:Int, endLineNumber:Int, parentIndex:Int, marker:Bool = false):ExpectedIndentRange {
        return IndentRangeProviderTestUtils.r(startLineNumber, endLineNumber, parentIndex, marker);
    }

    function testInsideRegionIndented() {
        assertRanges([
        /* 1*/ 'class A {',
        /* 2*/ '  #region',
        /* 3*/ '  void foo() {',
        /* 4*/ '     ',
        /* 5*/ '     return 0;',
        /* 6*/ '  }',
        /* 7*/ '  #endregion',
        /* 8*/ '}',
        ], [r(1, 7, -1), r(2, 7, 0, true), r(3, 5, 1)], false, markers);
    }

    function testInsideRegionNotIndented() {
        assertRanges([
        /* 1*/ 'var x;',
        /* 2*/ '#region',
        /* 3*/ 'void foo() {',
        /* 4*/ '     ',
        /* 5*/ '     return 0;',
        /* 6*/ '  }',
        /* 7*/ '#endregion',
        /* 8*/ '',
        ], [r(2, 7, -1, true), r(3, 6, 0)], false, markers);
    }

    function testEmptyRegions() {
        assertRanges([
        /* 1*/ 'var x;',
        /* 2*/ '#region',
        /* 3*/ '#endregion',
        /* 4*/ '#region',
        /* 5*/ '',
        /* 6*/ '#endregion',
        /* 7*/ 'var y;',
        ], [r(2, 3, -1, true), r(4, 6, -1, true)], false, markers);
    }

    function testNestedRegions() {
        assertRanges([
        /* 1*/ 'var x;',
        /* 2*/ '#region',
        /* 3*/ '#region',
        /* 4*/ '',
        /* 5*/ '#endregion',
        /* 6*/ '#endregion',
        /* 7*/ 'var y;',
        ], [r(2, 6, -1, true), r(3, 5, 0, true)], false, markers);
    }

    function testNestedRegions2() {
        assertRanges([
        /* 1*/ 'class A {',
        /* 2*/ '  #region',
        /* 3*/ '',
        /* 4*/ '  #region',
        /* 5*/ '',
        /* 6*/ '  #endregion',
        /* 7*/ '  // comment',
        /* 8*/ '  #endregion',
        /* 9*/ '}',
        ], [r(1, 8, -1), r(2, 8, 0, true), r(4, 6, 1, true)], false, markers);
    }

    function testIncompleteRegions() {
        assertRanges([
        /* 1*/ 'class A {',
        /* 2*/ '#region',
        /* 3*/ '  // comment',
        /* 4*/ '}',
        ], [r(2, 3, -1)], false, markers);
    }

    function testIncompleteRegions2() {
        assertRanges([
        /* 1*/ '',
        /* 2*/ '#region',
        /* 3*/ '#region',
        /* 4*/ '#region',
        /* 5*/ '  // comment',
        /* 6*/ '#endregion',
        /* 7*/ '#endregion',
        /* 8*/ ' // hello',
        ], [r(3, 7, -1, true), r(4, 6, 0, true)], false, markers);
    }

    function testIndentedRegionBefore() {
        assertRanges([
        /* 1*/ 'if (x)',
        /* 2*/ '  return;',
        /* 3*/ '',
        /* 4*/ '#region',
        /* 5*/ '  // comment',
        /* 6*/ '#endregion',
        ], [r(1, 3, -1), r(4, 6, -1, true)], false, markers);
    }

    function testIndentedRegionBefore2() {
        assertRanges([
        /* 1*/ 'if (x)',
        /* 2*/ '  log();',
        /* 3*/ '',
        /* 4*/ '    #region',
        /* 5*/ '      // comment',
        /* 6*/ '    #endregion',
        ], [r(1, 6, -1), r(2, 6, 0), r(4, 6, 1, true)], false, markers);
    }

    function testIndentedRegionInBetween() {
        assertRanges([
        /* 1*/ '#region',
        /* 2*/ '  // comment',
        /* 3*/ '  if (x)',
        /* 4*/ '    return;',
        /* 5*/ '',
        /* 6*/ '#endregion',
        ], [r(1, 6, -1, true), r(3, 5, 0)], false, markers);
    }

    function testIndentedRegionAfter() {
        assertRanges([
        /* 1*/ '#region',
        /* 2*/ '  // comment',
        /* 3*/ '',
        /* 4*/ '#endregion',
        /* 5*/ '  if (x)',
        /* 6*/ '    return;',
        ], [r(1, 4, -1, true), r(5, 6, -1)], false, markers);
    }

    function testWithOffSide() {
        assertRanges([
        /* 1*/ '#region',
        /* 2*/ '  ',
        /* 3*/ '',
        /* 4*/ '#endregion',
        /* 5*/ '',
        ], [r(1, 4, -1, true)], true, markers);
    }

    function testNestedWithOffSide() {
        assertRanges([
        /* 1*/ '#region',
        /* 2*/ '  ',
        /* 3*/ '#region',
        /* 4*/ '',
        /* 5*/ '#endregion',
        /* 6*/ '',
        /* 7*/ '#endregion',
        /* 8*/ '',
        ], [r(1, 7, -1, true), r(3, 5, 0, true)], true, markers);
    }

    function testIssue35981() {
        assertRanges([
        /* 1*/ 'function thisFoldsToEndOfPage() {',
        /* 2*/ '  const variable = []',
        /* 3*/ '    // #region',
        /* 4*/ '    .reduce((a, b) => a,[]);',
        /* 5*/ '}',
        /* 6*/ '',
        /* 7*/ 'function thisFoldsProperly() {',
        /* 8*/ '  const foo = "bar"',
        /* 9*/ '}',
        ], [r(1, 4, -1), r(2, 4, 0), r(7, 8, -1)], false, markers);
    }

    function testMisspelledMarkers() {
        assertRanges([
        /* 1*/ '#Region',
        /* 2*/ '#endregion',
        /* 3*/ '#regionsandmore',
        /* 4*/ '#endregion',
        /* 5*/ '#region',
        /* 6*/ '#end region',
        /* 7*/ '#region',
        /* 8*/ '#endregionff',
        ], [], true, markers);
    }

    function testIssue79359() {
        assertRanges([
        /* 1*/ '#region',
        /* 2*/ '',
        /* 3*/ 'class A',
        /* 4*/ '  foo',
        /* 5*/ '',
        /* 6*/ 'class A',
        /* 7*/ '  foo',
        /* 8*/ '',
        /* 9*/ '#endregion',
        ], [r(1, 9, -1, true), r(3, 4, 0), r(6, 7, 0)], true, markers);
    }

}
