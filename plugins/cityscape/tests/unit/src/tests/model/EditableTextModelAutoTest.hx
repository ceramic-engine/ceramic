// Ported from vscode src/vs/editor/test/common/model/editableTextModelAuto.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Range;
import testing.TestCase;
import tests.model.EditableTextModelTestUtils.testApplyEditsWithSyncedModels;

// Classes of this module:
//   EditorModelAutoTestsTest

/**
 * suite('EditorModel Auto Tests')
 *
 * Not ported: the random test generator of the file (getRandomInt, getRandomString, generateFile,
 * generateEdits, class TestModel and the `if (GENERATE_TESTS)` loop): GENERATE_TESTS is false in
 * vscode, so it never runs; it is a tool to find new failing cases, not a test.
 */
class EditorModelAutoTestsTest extends TestCase {

    static function editOp(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, text:Array<String>):ISingleEditOperation {
        return {
            range: new Range(startLineNumber, startColumn, endLineNumber, endColumn),
            text: text.join('\n'),
            forceMoveMarkers: false
        };
    }

    // test('auto1')
    function testAuto1() {
        testApplyEditsWithSyncedModels(this,
            [
                'ioe',
                '',
                'yjct',
                '',
                '',
            ],
            [
                editOp(1, 2, 1, 2, ['b', 'r', 'fq']),
                editOp(1, 4, 2, 1, ['', '']),
            ],
            [
                'ib',
                'r',
                'fqoe',
                '',
                'yjct',
                '',
                '',
            ]
        );
    }

    // test('auto2')
    function testAuto2() {
        testApplyEditsWithSyncedModels(this,
            [
                'f',
                'littnhskrq',
                'utxvsizqnk',
                'lslqz',
                'jxn',
                'gmm',
            ],
            [
                editOp(1, 2, 1, 2, ['', 'o']),
                editOp(2, 4, 2, 4, ['zaq', 'avb']),
                editOp(2, 5, 6, 2, ['jlr', 'zl', 'j']),
            ],
            [
                'f',
                'o',
                'litzaq',
                'avbtjlr',
                'zl',
                'jmm',
            ]
        );
    }

    // test('auto3')
    function testAuto3() {
        testApplyEditsWithSyncedModels(this,
            [
                'ofw',
                'qsxmziuvzw',
                'rp',
                'qsnymek',
                'elth',
                'wmgzbwudxz',
                'iwsdkndh',
                'bujlbwb',
                'asuouxfv',
                'xuccnb',
            ],
            [
                editOp(4, 3, 4, 3, ['']),
            ],
            [
                'ofw',
                'qsxmziuvzw',
                'rp',
                'qsnymek',
                'elth',
                'wmgzbwudxz',
                'iwsdkndh',
                'bujlbwb',
                'asuouxfv',
                'xuccnb',
            ]
        );
    }

    // test('auto4')
    function testAuto4() {
        testApplyEditsWithSyncedModels(this,
            [
                'fefymj',
                'qum',
                'vmiwxxaiqq',
                'dz',
                'lnqdgorosf',
            ],
            [
                editOp(1, 3, 1, 5, ['hp']),
                editOp(1, 7, 2, 1, ['kcg', '', 'mpx']),
                editOp(2, 2, 2, 2, ['', 'aw', '']),
                editOp(2, 2, 2, 2, ['vqr', 'mo']),
                editOp(4, 2, 5, 3, ['xyc']),
            ],
            [
                'fehpmjkcg',
                '',
                'mpxq',
                'aw',
                'vqr',
                'moum',
                'vmiwxxaiqq',
                'dxycqdgorosf',
            ]
        );
    }
}
