// Ported from vscode src/vs/editor/test/common/model/textModelWithTokens.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - TextModelGetLineIndentGuideTest
//
// Only suite('TextModel.getLineIndentGuide') of the vscode file is ported here. Not ported (they need tokens,
// brackets from a language configuration, or registered languages with a tokenization support):
// - suite('TextModelWithTokens'): test('brackets1')
// - suite('TextModelWithTokens - bracket matching'): test('bracket matching 1'), test('bracket matching 2')
// - suite('TextModelWithTokens 2'): test('bracket matching 3'), test('bracket matching 4'),
//   test('issue #95843: Highlighting of closing braces is indicating wrong brace when cursor is behind opening brace'),
//   test('issue #88075: TypeScript brace matching is incorrect in `${}` strings')
// - suite('TextModelWithTokens regression tests'):
//   test('microsoft/monaco-editor#122: Unhandled Exception: TypeError: Unable to get property \'replace\' of undefined or null reference'),
//   test('microsoft/monaco-editor#133: Error: Cannot read property \'modeId\' of undefined'),
//   test('issue #11856: Bracket matching does not work as expected if the opening brace symbol is contained in the closing brace symbol'),
//   test('issue #63822: Wrong embedded language detected for empty lines')

import testing.TestCase;
import tests.TestTextModel.createTextModel;

/**
 * suite('TextModel.getLineIndentGuide')
 *
 * vscode registers a language 'testLang' without configuration: it is not off-side (no `foldingRules.offSide`),
 * which is the default of `GuidesTextModelPart.isOffSide`, so a model with the language id 'testLang' behaves the same.
 */
class TextModelGetLineIndentGuideTest extends TestCase {

    /**
     * Each line is `[indent, activeStartLineNumber, activeEndLineNumber, activeIndent, content]`.
     */
    function assertIndentGuides(lines:Array<Array<Any>>, indentSize:Int):Void {
        final languageId = 'testLang';

        final text = lines.map(l -> (cast l[4] : String)).join('\n');
        final model = createTextModel(text, languageId);
        model.updateOptions({indentSize: indentSize});

        final actualIndents = model.guides.getLinesIndentGuides(1, model.getLineCount());

        final actual:Array<Array<Any>> = [];
        for (line in 1...model.getLineCount() + 1) {
            final activeIndentGuide = model.guides.getActiveIndentGuide(line, 1, model.getLineCount());
            actual[line - 1] = [actualIndents[line - 1], activeIndentGuide.startLineNumber, activeIndentGuide.endLineNumber, activeIndentGuide.indent, model.getLineContent(line)];
        }

        assertDeepEquals(actual, lines);

        model.dispose();
    }

    function testGetLineIndentGuideOneLevel2() {
        assertIndentGuides([
            [0, 2, 4, 1, 'A'],
            [1, 2, 4, 1, '  A'],
            [1, 2, 4, 1, '  A'],
            [1, 2, 4, 1, '  A'],
        ], 2);
    }

    function testGetLineIndentGuideTwoLevels() {
        assertIndentGuides([
            [0, 2, 5, 1, 'A'],
            [1, 2, 5, 1, '  A'],
            [1, 4, 5, 2, '  A'],
            [2, 4, 5, 2, '    A'],
            [2, 4, 5, 2, '    A'],
        ], 2);
    }

    function testGetLineIndentGuideThreeLevels() {
        assertIndentGuides([
            [0, 2, 4, 1, 'A'],
            [1, 3, 4, 2, '  A'],
            [2, 4, 4, 3, '    A'],
            [3, 4, 4, 3, '      A'],
            [0, 5, 5, 0, 'A'],
        ], 2);
    }

    function testGetLineIndentGuideDecreasingIndent() {
        assertIndentGuides([
            [2, 1, 1, 2, '    A'],
            [1, 1, 1, 2, '  A'],
            [0, 1, 2, 1, 'A'],
        ], 2);
    }

    function testGetLineIndentGuideJava() {
        assertIndentGuides([
            /* 1*/[0, 2, 9, 1, 'class A {'],
            /* 2*/[1, 3, 4, 2, '  void foo() {'],
            /* 3*/[2, 3, 4, 2, '    console.log(1);'],
            /* 4*/[2, 3, 4, 2, '    console.log(2);'],
            /* 5*/[1, 3, 4, 2, '  }'],
            /* 6*/[1, 2, 9, 1, ''],
            /* 7*/[1, 8, 8, 2, '  void bar() {'],
            /* 8*/[2, 8, 8, 2, '    console.log(3);'],
            /* 9*/[1, 8, 8, 2, '  }'],
            /*10*/[0, 2, 9, 1, '}'],
            /*11*/[0, 12, 12, 1, 'interface B {'],
            /*12*/[1, 12, 12, 1, '  void bar();'],
            /*13*/[0, 12, 12, 1, '}'],
        ], 2);
    }

    function testGetLineIndentGuideJavadoc() {
        assertIndentGuides([
            [0, 2, 3, 1, '/**'],
            [1, 2, 3, 1, ' * Comment'],
            [1, 2, 3, 1, ' */'],
            [0, 5, 6, 1, 'class A {'],
            [1, 5, 6, 1, '  void foo() {'],
            [1, 5, 6, 1, '  }'],
            [0, 5, 6, 1, '}'],
        ], 2);
    }

    function testGetLineIndentGuideWhitespace() {
        assertIndentGuides([
            [0, 2, 7, 1, 'class A {'],
            [1, 2, 7, 1, ''],
            [1, 4, 5, 2, '  void foo() {'],
            [2, 4, 5, 2, '    '],
            [2, 4, 5, 2, '    return 1;'],
            [1, 4, 5, 2, '  }'],
            [1, 2, 7, 1, '      '],
            [0, 2, 7, 1, '}']
        ], 2);
    }

    function testGetLineIndentGuideTabs() {
        assertIndentGuides([
            [0, 2, 7, 1, 'class A {'],
            [1, 2, 7, 1, '\t\t'],
            [1, 4, 5, 2, '\tvoid foo() {'],
            [2, 4, 5, 2, '\t \t//hello'],
            [2, 4, 5, 2, '\t    return 2;'],
            [1, 4, 5, 2, '  \t}'],
            [1, 2, 7, 1, '      '],
            [0, 2, 7, 1, '}']
        ], 4);
    }

    function testGetLineIndentGuideCheckerTs() {
        assertIndentGuides([
            /* 1*/[0, 1, 1, 0, '/// <reference path="binder.ts"/>'],
            /* 2*/[0, 2, 2, 0, ''],
            /* 3*/[0, 3, 3, 0, '/* @internal */'],
            /* 4*/[0, 5, 16, 1, 'namespace ts {'],
            /* 5*/[1, 5, 16, 1, '    var nextSymbolId = 1;'],
            /* 6*/[1, 5, 16, 1, '    var nextNodeId = 1;'],
            /* 7*/[1, 5, 16, 1, '    var nextMergeId = 1;'],
            /* 8*/[1, 5, 16, 1, '    var nextFlowId = 1;'],
            /* 9*/[1, 5, 16, 1, ''],
            /*10*/[1, 11, 15, 2, '    export function getNodeId(node: Node): number {'],
            /*11*/[2, 12, 13, 3, '        if (!node.id) {'],
            /*12*/[3, 12, 13, 3, '            node.id = nextNodeId;'],
            /*13*/[3, 12, 13, 3, '            nextNodeId++;'],
            /*14*/[2, 12, 13, 3, '        }'],
            /*15*/[2, 11, 15, 2, '        return node.id;'],
            /*16*/[1, 11, 15, 2, '    }'],
            /*17*/[0, 5, 16, 1, '}']
        ], 4);
    }

    function testIssue8425MissingIndentationLinesForFirstLevelIndentation() {
        assertIndentGuides([
            [1, 2, 3, 2, '\tindent1'],
            [2, 2, 3, 2, '\t\tindent2'],
            [2, 2, 3, 2, '\t\tindent2'],
            [1, 2, 3, 2, '\tindent1']
        ], 4);
    }

    function testIssue8952IndentationGuideLinesGoingThroughTextOnYmlFile() {
        assertIndentGuides([
            [0, 2, 5, 1, 'properties:'],
            [1, 3, 5, 2, '    emailAddress:'],
            [2, 3, 5, 2, '        - bla'],
            [2, 5, 5, 3, '        - length:'],
            [3, 5, 5, 3, '            max: 255'],
            [0, 6, 6, 0, 'getters:']
        ], 4);
    }

    function testIssue11892IndentGuidesLookFunny() {
        assertIndentGuides([
            [0, 2, 7, 1, 'function test(base) {'],
            [1, 3, 6, 2, '\tswitch (base) {'],
            [2, 4, 4, 3, '\t\tcase 1:'],
            [3, 4, 4, 3, '\t\t\treturn 1;'],
            [2, 6, 6, 3, '\t\tcase 2:'],
            [3, 6, 6, 3, '\t\t\treturn 2;'],
            [1, 2, 7, 1, '\t}'],
            [0, 2, 7, 1, '}']
        ], 4);
    }

    function testIssue12398ProblemInIndentGuidelines() {
        assertIndentGuides([
            [2, 2, 2, 3, '\t\t.bla'],
            [3, 2, 2, 3, '\t\t\tlabel(for)'],
            [0, 3, 3, 0, 'include script']
        ], 4);
    }

    function testIssue49173() {
        final model = createTextModel([
            'class A {',
            '\tpublic m1(): void {',
            '\t}',
            '\tpublic m2(): void {',
            '\t}',
            '\tpublic m3(): void {',
            '\t}',
            '\tpublic m4(): void {',
            '\t}',
            '\tpublic m5(): void {',
            '\t}',
            '}',
        ].join('\n'));

        final actual = model.guides.getActiveIndentGuide(2, 4, 9);
        assertDeepEquals(actual, { startLineNumber: 2, endLineNumber: 9, indent: 1 });
        model.dispose();
    }

    function testTweaksNoActive() {
        assertIndentGuides([
            [0, 1, 1, 0, 'A'],
            [0, 2, 2, 0, 'A']
        ], 2);
    }

    function testTweaksInsideScope() {
        assertIndentGuides([
            [0, 2, 2, 1, 'A'],
            [1, 2, 2, 1, '  A']
        ], 2);
    }

    function testTweaksScopeStart() {
        assertIndentGuides([
            [0, 2, 2, 1, 'A'],
            [1, 2, 2, 1, '  A'],
            [0, 2, 2, 1, 'A']
        ], 2);
    }

    function testTweaksEmptyLine() {
        assertIndentGuides([
            [0, 2, 4, 1, 'A'],
            [1, 2, 4, 1, '  A'],
            [1, 2, 4, 1, ''],
            [1, 2, 4, 1, '  A'],
            [0, 2, 4, 1, 'A']
        ], 2);
    }

}
