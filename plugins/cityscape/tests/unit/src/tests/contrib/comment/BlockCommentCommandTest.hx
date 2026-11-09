// Ported from vscode src/vs/editor/contrib/comment/test/browser/blockCommentCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.comment;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.core.Selection;
import cityscape.contrib.comment.view.BlockCommentCommand;
import testing.TestCase;
import testing.TestCommand;

/**
 * suite('Editor Contrib - Block Comment Command')
 */
class BlockCommentCommandTest extends TestCase {

    function _testCommentCommand(lines:Array<String>, selection:Selection, commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        final languageId = 'commentMode';
        final prepare = (accessor:Cityscape, disposables:DisposableStore) -> {
            final languageConfigurationService = accessor.languageConfigurationService;
            final languageService = accessor.languageService;
            disposables.add(languageService.registerLanguage({id: languageId}));
            disposables.add(languageConfigurationService.register(languageId, {
                comments: {lineComment: '!@#', blockComment: ['<0', '0>']}
            }));
        };
        TestCommand.testCommand(this, lines, languageId, selection, commandFactory, expectedLines, expectedSelection, null, prepare, pos);
    }

    function doTestBlockCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        _testCommentCommand(lines, selection, (accessor, sel) -> new BlockCommentCommand(sel, true, accessor.languageConfigurationService), expectedLines, expectedSelection, pos);
    }

    /**
     * test('empty selection wraps itself')
     */
    function testEmptySelectionWrapsItself() {
        doTestBlockCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 3),
            [
                'fi<0  0>rst',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 6, 1, 6)
        );
    }

    /**
     * test('invisible selection ignored')
     */
    function testInvisibleSelectionIgnored() {
        doTestBlockCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 1, 1),
            [
                '<0 first',
                ' 0>\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 4, 2, 1)
        );
    }

    /**
     * test('bug9511')
     */
    function testBug9511() {
        doTestBlockCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 6, 1, 1),
            [
                '<0 first 0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 4, 1, 9)
        );

        doTestBlockCommentCommand(
            [
                '<0first0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 8, 1, 3),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 6)
        );
    }

    /**
     * test('one line selection')
     */
    function testOneLineSelection() {
        doTestBlockCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 6, 1, 3),
            [
                'fi<0 rst 0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 6, 1, 9)
        );
    }

    /**
     * test('one line selection toggle')
     */
    function testOneLineSelectionToggle() {
        doTestBlockCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 6, 1, 3),
            [
                'fi<0 rst 0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 6, 1, 9)
        );

        doTestBlockCommentCommand(
            [
                'fi<0rst0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 8, 1, 5),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 6)
        );

        doTestBlockCommentCommand(
            [
                '<0 first 0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 10, 1, 1),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 6)
        );

        doTestBlockCommentCommand(
            [
                '<0 first0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 9, 1, 1),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 6)
        );

        doTestBlockCommentCommand(
            [
                '<0first 0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 9, 1, 1),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 6)
        );

        doTestBlockCommentCommand(
            [
                'fi<0rst0>',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 8, 1, 5),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 6)
        );
    }

    /**
     * test('multi line selection')
     */
    function testMultiLineSelection() {
        doTestBlockCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 1),
            [
                '<0 first',
                '\tse 0>cond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 4, 2, 4)
        );
    }

    /**
     * test('multi line selection toggle')
     */
    function testMultiLineSelectionToggle() {
        doTestBlockCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 1),
            [
                '<0 first',
                '\tse 0>cond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 4, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                '<0first',
                '\tse0>cond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 3),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                '<0 first',
                '\tse0>cond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 3),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                '<0first',
                '\tse 0>cond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 3),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                '<0 first',
                '\tse 0>cond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 3),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 2, 4)
        );
    }

    /**
     * test('fuzzy removes')
     */
    function testFuzzyRemoves() {
        doTestBlockCommentCommand(
            [
                'asd <0 qwe',
                'asd 0> qwe'
            ],
            new Selection(2, 5, 1, 7),
            [
                'asd qwe',
                'asd qwe'
            ],
            new Selection(1, 5, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                'asd <0 qwe',
                'asd 0> qwe'
            ],
            new Selection(2, 5, 1, 6),
            [
                'asd qwe',
                'asd qwe'
            ],
            new Selection(1, 5, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                'asd <0 qwe',
                'asd 0> qwe'
            ],
            new Selection(2, 5, 1, 5),
            [
                'asd qwe',
                'asd qwe'
            ],
            new Selection(1, 5, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                'asd <0 qwe',
                'asd 0> qwe'
            ],
            new Selection(2, 5, 1, 11),
            [
                'asd qwe',
                'asd qwe'
            ],
            new Selection(1, 5, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                'asd <0 qwe',
                'asd 0> qwe'
            ],
            new Selection(2, 1, 1, 11),
            [
                'asd qwe',
                'asd qwe'
            ],
            new Selection(1, 5, 2, 4)
        );

        doTestBlockCommentCommand(
            [
                'asd <0 qwe',
                'asd 0> qwe'
            ],
            new Selection(2, 7, 1, 11),
            [
                'asd qwe',
                'asd qwe'
            ],
            new Selection(1, 5, 2, 4)
        );
    }

    /**
     * test('bug #30358')
     */
    function testBug30358() {
        doTestBlockCommentCommand(
            [
                '<0 start 0> middle end',
            ],
            new Selection(1, 20, 1, 23),
            [
                '<0 start 0> middle <0 end 0>'
            ],
            new Selection(1, 23, 1, 26)
        );

        doTestBlockCommentCommand(
            [
                '<0 start 0> middle <0 end 0>'
            ],
            new Selection(1, 13, 1, 19),
            [
                '<0 start 0> <0 middle 0> <0 end 0>'
            ],
            new Selection(1, 16, 1, 22)
        );
    }

    /**
     * test('issue #34618')
     */
    function testIssue34618() {
        doTestBlockCommentCommand(
            [
                '<0  0> middle end',
            ],
            new Selection(1, 4, 1, 4),
            [
                ' middle end'
            ],
            new Selection(1, 1, 1, 1)
        );
    }

    /**
     * test('insertSpace false')
     */
    function testInsertSpaceFalse() {
        function doTestLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
            _testCommentCommand(lines, selection, (accessor, sel) -> new BlockCommentCommand(sel, false, accessor.languageConfigurationService), expectedLines, expectedSelection, pos);
        }

        doTestLineCommentCommand(
            [
                'some text'
            ],
            new Selection(1, 1, 1, 5),
            [
                '<0some0> text'
            ],
            new Selection(1, 3, 1, 7)
        );
    }

    /**
     * test('insertSpace false does not remove space')
     */
    function testInsertSpaceFalseDoesNotRemoveSpace() {
        function doTestLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
            _testCommentCommand(lines, selection, (accessor, sel) -> new BlockCommentCommand(sel, false, accessor.languageConfigurationService), expectedLines, expectedSelection, pos);
        }

        doTestLineCommentCommand(
            [
                '<0 some 0> text'
            ],
            new Selection(1, 4, 1, 8),
            [
                ' some  text'
            ],
            new Selection(1, 1, 1, 7)
        );
    }

}
