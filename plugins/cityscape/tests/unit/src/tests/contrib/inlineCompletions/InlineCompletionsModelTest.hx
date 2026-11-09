// Ported from vscode src/vs/editor/contrib/inlineCompletions/test/browser/inlineCompletionsModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.inlineCompletions;

import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextEdit.SingleTextEdit;
import cityscape.contrib.inlineCompletions.view.model.InlineCompletionsModel;
import testing.TestCase;
import tests.TestTextModel;

/**
 * suite('inlineCompletionModel').
 */
class InlineCompletionsModelTest extends TestCase {

    function testGetSecondaryEditsBasic() {
        final textModel = TestTextModel.createTextModel([
            'function fib(',
            'function fib('
        ].join('\n'));
        final positions = [
            new Position(1, 14),
            new Position(2, 14)
        ];
        final primaryEdit = new SingleTextEdit(new Range(1, 1, 1, 14), 'function fib() {');
        final secondaryEdits = InlineCompletionsModel.getSecondaryEdits(textModel, positions, primaryEdit);
        assertDeepEquals(secondaryEdits, [new SingleTextEdit(
            new Range(2, 14, 2, 14),
            ') {'
        )]);
        textModel.dispose();
    }

    function testGetSecondaryEditsCursorNotOnSameLineAsPrimaryEdit1() {
        final textModel = TestTextModel.createTextModel([
            'function fib(',
            '',
            'function fib(',
            ''
        ].join('\n'));
        final positions = [
            new Position(2, 1),
            new Position(4, 1)
        ];
        final primaryEdit = new SingleTextEdit(new Range(1, 1, 2, 1), [
            'function fib() {',
            '	return 0;',
            '}'
        ].join('\n'));
        final secondaryEdits = InlineCompletionsModel.getSecondaryEdits(textModel, positions, primaryEdit);
        assertDeepEquals(secondaryEdits, [new SingleTextEdit(
            new Range(4, 1, 4, 1), [
                '	return 0;',
                '}'
            ].join('\n')
        )]);
        textModel.dispose();
    }

    function testGetSecondaryEditsCursorNotOnSameLineAsPrimaryEdit2() {
        final textModel = TestTextModel.createTextModel([
            'class A {',
            '',
            'class B {',
            '',
            'function f() {}'
        ].join('\n'));
        final positions = [
            new Position(2, 1),
            new Position(4, 1)
        ];
        final primaryEdit = new SingleTextEdit(new Range(1, 1, 2, 1), [
            'class A {',
            '	public x: number = 0;',
            '   public y: number = 0;',
            '}'
        ].join('\n'));
        final secondaryEdits = InlineCompletionsModel.getSecondaryEdits(textModel, positions, primaryEdit);
        assertDeepEquals(secondaryEdits, [new SingleTextEdit(
            new Range(4, 1, 4, 1), [
                '	public x: number = 0;',
                '   public y: number = 0;',
                '}'
            ].join('\n')
        )]);
        textModel.dispose();
    }

}
