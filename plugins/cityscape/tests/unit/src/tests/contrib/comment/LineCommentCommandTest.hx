// Ported from vscode src/vs/editor/contrib/comment/test/browser/lineCommentCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.comment;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfiguration.CommentRule;
import cityscape.common.languages.NullTokenize;
import cityscape.contrib.comment.view.LineCommentCommand;
import haxe.io.UInt32Array;
import testing.TestCase;
import testing.TestCommand;
import testing.TestLanguageConfigurationService;
import testing.TestTokenizationSupport;

/**
 * vscode's `createTestCommandHelper`.
 */
private class LineCommentTestHelper {

    public static function createTestCommandHelper(test:TestCase, commentsConfig:CommentRule, commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand):(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection) -> Void {
        return (lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection) -> {
            final languageId = 'commentMode';
            final prepare = (accessor:Cityscape, disposables:DisposableStore) -> {
                final languageConfigurationService = accessor.languageConfigurationService;
                final languageService = accessor.languageService;
                disposables.add(languageService.registerLanguage({id: languageId}));
                disposables.add(languageConfigurationService.register(languageId, {
                    comments: commentsConfig
                }));
            };
            TestCommand.testCommand(test, lines, languageId, selection, commandFactory, expectedLines, expectedSelection, false, prepare);
        };
    }

}

/**
 * suite('Editor Contrib - Line Comment Command')
 */
class LineCommentCommandTest extends TestCase {

    function createTestCommandHelper(commentsConfig:CommentRule, commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand):(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection) -> Void {
        return LineCommentTestHelper.createTestCommandHelper(this, commentsConfig, commandFactory);
    }

    function doTestLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection):Void {
        createTestCommandHelper(
            {lineComment: '!@#', blockComment: ['<!@#', '#@!>']},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, true, true)
        )(lines, selection, expectedLines, expectedSelection);
    }

    function doTestAddLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection):Void {
        createTestCommandHelper(
            {lineComment: '!@#', blockComment: ['<!@#', '#@!>']},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.ForceAdd, true, true)
        )(lines, selection, expectedLines, expectedSelection);
    }

    static function createSimpleModel(lines:Array<String>):ISimpleModel {
        return {
            getLineContent: (lineNumber:Int) -> {
                return lines[lineNumber - 1];
            }
        };
    }

    static function createBasicLinePreflightData(commentTokens:Array<String>):Array<ILinePreflightData> {
        return commentTokens.map((commentString) -> {
            final r:ILinePreflightData = {
                ignore: false,
                commentStr: commentString,
                commentStrOffset: 0,
                commentStrLength: commentString.length
            };
            return r;
        });
    }

    /**
     * test('comment single line')
     */
    function testCommentSingleLine() {
        doTestLineCommentCommand(
            [
                'some text',
                '\tsome more text'
            ],
            new Selection(1, 1, 1, 1),
            [
                '!@# some text',
                '\tsome more text'
            ],
            new Selection(1, 5, 1, 5)
        );
   }

    /**
     * test('case insensitive')
     */
    function testCaseInsensitive() {
        final doTestLineCommentCommand = createTestCommandHelper(
            {lineComment: 'rem'},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, true, true)
        );

        doTestLineCommentCommand(
            [
                'REM some text'
            ],
            new Selection(1, 1, 1, 1),
            [
                'some text'
            ],
            new Selection(1, 1, 1, 1)
        );
   }

    /**
     * test('_analyzeLines')
     */
    function testAnalyzeLines() {
        final disposable = new DisposableStore();
        var r:IPreflightData;

        r = LineCommentCommand._analyzeLines(Type.Toggle, true, createSimpleModel([
            '\t\t',
            '    ',
            '    c',
            '\t\td'
        ]), createBasicLinePreflightData(['//', 'rem', '!@#', '!@#']), 1, true, false, disposable.add(new TestLanguageConfigurationService()));
        if (!r.supported) {
            throw 'unexpected';
       }

        assertEquals(r.shouldRemoveComments, false);

        // Does not change `commentStr`
        assertEquals(r.lines[0].commentStr, '//');
        assertEquals(r.lines[1].commentStr, 'rem');
        assertEquals(r.lines[2].commentStr, '!@#');
        assertEquals(r.lines[3].commentStr, '!@#');

        // Fills in `isWhitespace`
        assertEquals(r.lines[0].ignore, true);
        assertEquals(r.lines[1].ignore, true);
        assertEquals(r.lines[2].ignore, false);
        assertEquals(r.lines[3].ignore, false);

        // Fills in `commentStrOffset`
        assertEquals(r.lines[0].commentStrOffset, 2);
        assertEquals(r.lines[1].commentStrOffset, 4);
        assertEquals(r.lines[2].commentStrOffset, 4);
        assertEquals(r.lines[3].commentStrOffset, 2);


        r = LineCommentCommand._analyzeLines(Type.Toggle, true, createSimpleModel([
            '\t\t',
            '    rem ',
            '    !@# c',
            '\t\t!@#d'
        ]), createBasicLinePreflightData(['//', 'rem', '!@#', '!@#']), 1, true, false, disposable.add(new TestLanguageConfigurationService()));
        if (!r.supported) {
            throw 'unexpected';
       }

        assertEquals(r.shouldRemoveComments, true);

        // Does not change `commentStr`
        assertEquals(r.lines[0].commentStr, '//');
        assertEquals(r.lines[1].commentStr, 'rem');
        assertEquals(r.lines[2].commentStr, '!@#');
        assertEquals(r.lines[3].commentStr, '!@#');

        // Fills in `isWhitespace`
        assertEquals(r.lines[0].ignore, true);
        assertEquals(r.lines[1].ignore, false);
        assertEquals(r.lines[2].ignore, false);
        assertEquals(r.lines[3].ignore, false);

        // Fills in `commentStrOffset`
        assertEquals(r.lines[0].commentStrOffset, 2);
        assertEquals(r.lines[1].commentStrOffset, 4);
        assertEquals(r.lines[2].commentStrOffset, 4);
        assertEquals(r.lines[3].commentStrOffset, 2);

        // Fills in `commentStrLength`
        assertEquals(r.lines[0].commentStrLength, 2);
        assertEquals(r.lines[1].commentStrLength, 4);
        assertEquals(r.lines[2].commentStrLength, 4);
        assertEquals(r.lines[3].commentStrLength, 3);

        disposable.dispose();
   }

    /**
     * test('_normalizeInsertionPoint')
     */
    function testNormalizeInsertionPoint() {

        final runTest = (mixedArr:Array<Any>, tabSize:Int, expected:Array<Int>, testName:String) -> {
            final model = createSimpleModel([for (idx in 0...mixedArr.length) if (idx % 2 == 0) (mixedArr[idx] : String)]);
            final offsets:Array<IInsertionPoint> = [for (idx in 0...mixedArr.length) if (idx % 2 == 1) {
                commentStrOffset: (mixedArr[idx] : Int),
                ignore: false
            }];
            LineCommentCommand._normalizeInsertionPoint(model, offsets, 1, tabSize);
            final actual = offsets.map(item -> item.commentStrOffset);
            assertDeepEquals(expected, actual, testName);
        };

        // Bug 16696:[comment] comments not aligned in this case
        runTest([
            '  XX', 2,
            '    YY', 4
        ], 4, [0, 0], 'Bug 16696');

        runTest([
            '\t\t\tXX', 3,
            '    \tYY', 5,
            '        ZZ', 8,
            '\t\tTT', 2
        ], 4, [2, 5, 8, 2], 'Test1');

        runTest([
            '\t\t\t   XX', 6,
            '    \t\t\t\tYY', 8,
            '        ZZ', 8,
            '\t\t    TT', 6
        ], 4, [2, 5, 8, 2], 'Test2');

        runTest([
            '\t\t', 2,
            '\t\t\t', 3,
            '\t\t\t\t', 4,
            '\t\t\t', 3
        ], 4, [2, 2, 2, 2], 'Test3');

        runTest([
            '\t\t', 2,
            '\t\t\t', 3,
            '\t\t\t\t', 4,
            '\t\t\t', 3,
            '    ', 4
        ], 2, [2, 2, 2, 2, 4], 'Test4');

        runTest([
            '\t\t', 2,
            '\t\t\t', 3,
            '\t\t\t\t', 4,
            '\t\t\t', 3,
            '    ', 4
        ], 4, [1, 1, 1, 1, 4], 'Test5');

        runTest([
            ' \t', 2,
            '  \t', 3,
            '   \t', 4,
            '    ', 4,
            '\t', 1
        ], 4, [2, 3, 4, 4, 1], 'Test6');

        runTest([
            ' \t\t', 3,
            '  \t\t', 4,
            '   \t\t', 5,
            '    \t', 5,
            '\t', 1
        ], 4, [2, 3, 4, 4, 1], 'Test7');

        runTest([
            '\t', 1,
            '    ', 4
        ], 4, [1, 4], 'Test8:4');
        runTest([
            '\t', 1,
            '   ', 3
        ], 4, [0, 0], 'Test8:3');
        runTest([
            '\t', 1,
            '  ', 2
        ], 4, [0, 0], 'Test8:2');
        runTest([
            '\t', 1,
            ' ', 1
        ], 4, [0, 0], 'Test8:1');
        runTest([
            '\t', 1,
            '', 0
        ], 4, [0, 0], 'Test8:0');
   }

    /**
     * test('detects indentation')
     */
    function testDetectsIndentation() {
        doTestLineCommentCommand(
            [
                '\tsome text',
                '\tsome more text'
            ],
            new Selection(2, 2, 1, 1),
            [
                '\t!@# some text',
                '\t!@# some more text'
            ],
            new Selection(2, 2, 1, 1)
        );
   }

    /**
     * test('detects mixed indentation')
     */
    function testDetectsMixedIndentation() {
        doTestLineCommentCommand(
            [
                '\tsome text',
                '    some more text'
            ],
            new Selection(2, 2, 1, 1),
            [
                '\t!@# some text',
                '    !@# some more text'
            ],
            new Selection(2, 2, 1, 1)
        );
   }

    /**
     * test('ignores whitespace lines')
     */
    function testIgnoresWhitespaceLines() {
        doTestLineCommentCommand(
            [
                '\tsome text',
                '\t   ',
                '',
                '\tsome more text'
            ],
            new Selection(4, 2, 1, 1),
            [
                '\t!@# some text',
                '\t   ',
                '',
                '\t!@# some more text'
            ],
            new Selection(4, 2, 1, 1)
        );
   }

    /**
     * test('removes its own')
     */
    function testRemovesItsOwn() {
        doTestLineCommentCommand(
            [
                '\t!@# some text',
                '\t   ',
                '\t\t!@# some more text'
            ],
            new Selection(3, 2, 1, 1),
            [
                '\tsome text',
                '\t   ',
                '\t\tsome more text'
            ],
            new Selection(3, 2, 1, 1)
        );
   }

    /**
     * test('works in only whitespace')
     */
    function testWorksInOnlyWhitespace() {
        doTestLineCommentCommand(
            [
                '\t    ',
                '\t',
                '\t\tsome more text'
            ],
            new Selection(3, 1, 1, 1),
            [
                '\t!@#     ',
                '\t!@# ',
                '\t\tsome more text'
            ],
            new Selection(3, 1, 1, 1)
        );
   }

    /**
     * test('bug 9697 - whitespace before comment token')
     */
    function testBug9697WhitespaceBeforeCommentToken() {
        doTestLineCommentCommand(
            [
                '\t !@#first',
                '\tsecond line'
            ],
            new Selection(1, 1, 1, 1),
            [
                '\t first',
                '\tsecond line'
            ],
            new Selection(1, 1, 1, 1)
        );
   }

    /**
     * test('bug 10162 - line comment before caret')
     */
    function testBug10162LineCommentBeforeCaret() {
        doTestLineCommentCommand(
            [
                'first!@#',
                '\tsecond line'
            ],
            new Selection(1, 1, 1, 1),
            [
                '!@# first!@#',
                '\tsecond line'
            ],
            new Selection(1, 5, 1, 5)
        );
   }

    /**
     * test('comment single line - leading whitespace')
     */
    function testCommentSingleLineLeadingWhitespace() {
        doTestLineCommentCommand(
            [
                'first!@#',
                '\tsecond line'
            ],
            new Selection(2, 3, 2, 1),
            [
                'first!@#',
                '\t!@# second line'
            ],
            new Selection(2, 7, 2, 1)
        );
   }

    /**
     * test('ignores invisible selection')
     */
    function testIgnoresInvisibleSelection() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 1, 1),
            [
                '!@# first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 1, 5)
        );
   }

    /**
     * test('multiple lines')
     */
    function testMultipleLines() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 1),
            [
                '!@# first',
                '!@# \tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 8, 1, 5)
        );
   }

    /**
     * test('multiple modes on multiple lines')
     */
    function testMultipleModesOnMultipleLines() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(4, 4, 3, 1),
            [
                'first',
                '\tsecond line',
                '!@# third line',
                '!@# fourth line',
                'fifth'
            ],
            new Selection(4, 8, 3, 5)
        );
   }

    /**
     * test('toggle single line')
     */
    function testToggleSingleLine() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1),
            [
                '!@# first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5)
        );

        doTestLineCommentCommand(
            [
                '!@# first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 4, 1, 4),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1)
        );
   }

    /**
     * test('toggle multiple lines')
     */
    function testToggleMultipleLines() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 1, 1),
            [
                '!@# first',
                '!@# \tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 8, 1, 5)
        );

        doTestLineCommentCommand(
            [
                '!@# first',
                '!@# \tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 7, 1, 4),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 3, 1, 1)
        );
   }

    /**
     * test('issue #5964: Ctrl+/ to create comment when cursor is at the beginning of the line puts the cursor in a strange position')
     */
    function testIssue5964CtrlToCreateCommentWhenCursorIsAtTheBeginningOfTheLinePutsTheCursorInAStrangePosition() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1),
            [
                '!@# first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5)
        );
   }

    /**
     * test('issue #35673: Comment hotkeys throws the cursor before the comment')
     */
    function testIssue35673CommentHotkeysThrowsTheCursorBeforeTheComment() {
        doTestLineCommentCommand(
            [
                'first',
                '',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 2, 1),
            [
                'first',
                '!@# ',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 5, 2, 5)
        );

        doTestLineCommentCommand(
            [
                'first',
                '\t',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 2, 2, 2),
            [
                'first',
                '\t!@# ',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 6, 2, 6)
        );
   }

    /**
     * test('issue #2837 "Add Line Comment" fault when blank lines involved')
     */
    function testIssue2837AddLineCommentFaultWhenBlankLinesInvolved() {
        doTestAddLineCommentCommand(
            [
                '    if displayName == "":',
                '        displayName = groupName',
                '    description = getAttr(attributes, "description")',
                '    mailAddress = getAttr(attributes, "mail")',
                '',
                '    print "||Group name|%s|" % displayName',
                '    print "||Description|%s|" % description',
                '    print "||Email address|[mailto:%s]|" % mailAddress`',
            ],
            new Selection(1, 1, 8, 56),
            [
                '    !@# if displayName == "":',
                '    !@#     displayName = groupName',
                '    !@# description = getAttr(attributes, "description")',
                '    !@# mailAddress = getAttr(attributes, "mail")',
                '',
                '    !@# print "||Group name|%s|" % displayName',
                '    !@# print "||Description|%s|" % description',
                '    !@# print "||Email address|[mailto:%s]|" % mailAddress`',
            ],
            new Selection(1, 1, 8, 60)
        );
   }

    /**
     * test('issue #47004: Toggle comments shouldn\'t move cursor')
     */
    function testIssue47004ToggleCommentsShouldnTMoveCursor() {
        doTestAddLineCommentCommand(
            [
                '    A line',
                '    Another line'
            ],
            new Selection(2, 7, 1, 1),
            [
                '    !@# A line',
                '    !@# Another line'
            ],
            new Selection(2, 11, 1, 1)
        );
   }

    /**
     * test('insertSpace false')
     */
    function testInsertSpaceFalse() {
        final doTestLineCommentCommand = createTestCommandHelper(
            {lineComment: '!@#'},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, false, true)
        );

        doTestLineCommentCommand(
            [
                'some text'
            ],
            new Selection(1, 1, 1, 1),
            [
                '!@#some text'
            ],
            new Selection(1, 4, 1, 4)
        );
   }

    /**
     * test('insertSpace false does not remove space')
     */
    function testInsertSpaceFalseDoesNotRemoveSpace() {
        final doTestLineCommentCommand = createTestCommandHelper(
            {lineComment: '!@#'},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, false, true)
        );

        doTestLineCommentCommand(
            [
                '!@#    some text'
            ],
            new Selection(1, 1, 1, 1),
            [
                '    some text'
            ],
            new Selection(1, 1, 1, 1)
        );
   }

}

/**
 * suite('ignoreEmptyLines false')
 */
class IgnoreEmptyLinesFalseTest extends TestCase {

    function createTestCommandHelper(commentsConfig:CommentRule, commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand):(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection) -> Void {
        return LineCommentTestHelper.createTestCommandHelper(this, commentsConfig, commandFactory);
    }

    function doTestLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection):Void {
        createTestCommandHelper(
            {lineComment: '!@#', blockComment: ['<!@#', '#@!>']},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, true, false)
        )(lines, selection, expectedLines, expectedSelection);
    }

    /**
     * test('does not ignore whitespace lines')
     */
    function testDoesNotIgnoreWhitespaceLines() {
        doTestLineCommentCommand(
            [
                '\tsome text',
                '\t   ',
                '',
                '\tsome more text'
            ],
            new Selection(4, 2, 1, 1),
            [
                '!@# \tsome text',
                '!@# \t   ',
                '!@# ',
                '!@# \tsome more text'
            ],
            new Selection(4, 6, 1, 5)
        );
   }

    /**
     * test('removes its own')
     */
    function testRemovesItsOwn() {
        doTestLineCommentCommand(
            [
                '\t!@# some text',
                '\t   ',
                '\t\t!@# some more text'
            ],
            new Selection(3, 2, 1, 1),
            [
                '\tsome text',
                '\t   ',
                '\t\tsome more text'
            ],
            new Selection(3, 2, 1, 1)
        );
   }

    /**
     * test('works in only whitespace')
     */
    function testWorksInOnlyWhitespace() {
        doTestLineCommentCommand(
            [
                '\t    ',
                '\t',
                '\t\tsome more text'
            ],
            new Selection(3, 1, 1, 1),
            [
                '\t!@#     ',
                '\t!@# ',
                '\t\tsome more text'
            ],
            new Selection(3, 1, 1, 1)
        );
   }

    /**
     * test('comments single line')
     */
    function testCommentsSingleLine() {
        doTestLineCommentCommand(
            [
                'some text',
                '\tsome more text'
            ],
            new Selection(1, 1, 1, 1),
            [
                '!@# some text',
                '\tsome more text'
            ],
            new Selection(1, 5, 1, 5)
        );
   }

    /**
     * test('detects indentation')
     */
    function testDetectsIndentation() {
        doTestLineCommentCommand(
            [
                '\tsome text',
                '\tsome more text'
            ],
            new Selection(2, 2, 1, 1),
            [
                '\t!@# some text',
                '\t!@# some more text'
            ],
            new Selection(2, 2, 1, 1)
        );
   }

}

/**
 * suite('Editor Contrib - Line Comment As Block Comment')
 */
class EditorContribLineCommentAsBlockCommentTest extends TestCase {

    function createTestCommandHelper(commentsConfig:CommentRule, commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand):(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection) -> Void {
        return LineCommentTestHelper.createTestCommandHelper(this, commentsConfig, commandFactory);
    }

    function doTestLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection):Void {
        createTestCommandHelper(
            {lineComment: '', blockComment: ['(', ')']},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, true, true)
        )(lines, selection, expectedLines, expectedSelection);
    }

    /**
     * test('fall back to block comment command')
     */
    function testFallBackToBlockCommentCommand() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1),
            [
                '( first )',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 3)
        );
   }

    /**
     * test('fall back to block comment command - toggle')
     */
    function testFallBackToBlockCommentCommandToggle() {
        doTestLineCommentCommand(
            [
                '(first)',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 7, 1, 2),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 6, 1, 1)
        );
   }

    /**
     * test('bug 9513 - expand single line to uncomment auto block')
     */
    function testBug9513ExpandSingleLineToUncommentAutoBlock() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1),
            [
                '( first )',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 3)
        );
   }

    /**
     * test('bug 9691 - always expand selection to line boundaries')
     */
    function testBug9691AlwaysExpandSelectionToLineBoundaries() {
        doTestLineCommentCommand(
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 2, 1, 3),
            [
                '( first',
                '\tsecond line',
                'third line )',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 2, 1, 5)
        );

        doTestLineCommentCommand(
            [
                '(first',
                '\tsecond line',
                'third line)',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 11, 1, 2),
            [
                'first',
                '\tsecond line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 11, 1, 1)
        );
   }

}

/**
 * suite('Editor Contrib - Line Comment As Block Comment 2')
 */
class EditorContribLineCommentAsBlockComment2Test extends TestCase {

    function createTestCommandHelper(commentsConfig:CommentRule, commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand):(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection) -> Void {
        return LineCommentTestHelper.createTestCommandHelper(this, commentsConfig, commandFactory);
    }

    function doTestLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection):Void {
        createTestCommandHelper(
            {lineComment: null, blockComment: ['<!@#', '#@!>']},
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, true, true)
        )(lines, selection, expectedLines, expectedSelection);
    }

    /**
     * test('no selection => uses indentation')
     */
    function testNoSelectionUsesIndentation() {
        doTestLineCommentCommand(
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(1, 1, 1, 1),
            [
                '\t\t<!@# first\t     #@!>',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(1, 1, 1, 1)
        );

        doTestLineCommentCommand(
            [
                '\t\t<!@#first\t    #@!>',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(1, 1, 1, 1),
            [
                '\t\tfirst\t   ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(1, 1, 1, 1)
        );
   }

    /**
     * test('can remove')
     */
    function testCanRemove() {
        doTestLineCommentCommand(
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(5, 1, 5, 1),
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\tfifth\t\t'
            ],
            new Selection(5, 1, 5, 1)
        );

        doTestLineCommentCommand(
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(5, 3, 5, 3),
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\tfifth\t\t'
            ],
            new Selection(5, 3, 5, 3)
        );

        doTestLineCommentCommand(
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(5, 4, 5, 4),
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\tfifth\t\t'
            ],
            new Selection(5, 3, 5, 3)
        );

        doTestLineCommentCommand(
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(5, 16, 5, 3),
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\tfifth\t\t'
            ],
            new Selection(5, 8, 5, 3)
        );

        doTestLineCommentCommand(
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(5, 12, 5, 7),
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\tfifth\t\t'
            ],
            new Selection(5, 8, 5, 3)
        );

        doTestLineCommentCommand(
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\t<!@#fifth#@!>\t\t'
            ],
            new Selection(5, 18, 5, 18),
            [
                '\t\tfirst\t    ',
                '\t\tsecond line',
                '\tthird line',
                'fourth line',
                '\t\tfifth\t\t'
            ],
            new Selection(5, 10, 5, 10)
        );
   }

    /**
     * test('issue #993: Remove comment does not work consistently in HTML')
     */
    function testIssue993RemoveCommentDoesNotWorkConsistentlyInHTML() {
        doTestLineCommentCommand(
            [
                '     asd qwe',
                '     asd qwe',
                ''
            ],
            new Selection(1, 1, 3, 1),
            [
                '     <!@# asd qwe',
                '     asd qwe #@!>',
                ''
            ],
            new Selection(1, 1, 3, 1)
        );

        doTestLineCommentCommand(
            [
                '     <!@#asd qwe',
                '     asd qwe#@!>',
                ''
            ],
            new Selection(1, 1, 3, 1),
            [
                '     asd qwe',
                '     asd qwe',
                ''
            ],
            new Selection(1, 1, 3, 1)
        );
   }

}

/**
 * suite('Editor Contrib - Line Comment in mixed modes')
 */
class EditorContribLineCommentInMixedModesTest extends TestCase {

    static inline final OUTER_LANGUAGE_ID = 'outerMode';
    static inline final INNER_LANGUAGE_ID = 'innerMode';

    static function outerMode(commentsConfig:CommentRule, accessor:Cityscape):IDisposable {
        final store = new DisposableStore();
        final languageService = accessor.languageService;
        final languageConfigurationService = accessor.languageConfigurationService;
        final languageId = OUTER_LANGUAGE_ID;
        store.add(languageService.registerLanguage({id: languageId}));
        store.add(languageConfigurationService.register(languageId, {
            comments: commentsConfig
        }));

        store.add(accessor.tokenizationRegistry.register(languageId, new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line:String, hasEOL:Bool, state:IState) -> {
                final languageId = (StringTools.startsWith(line, '  ') ? INNER_LANGUAGE_ID : OUTER_LANGUAGE_ID);
                final encodedLanguageId = languageService.languageIdCodec.encodeLanguageId(languageId);

                final tokens = new UInt32Array(1 << 1);
                tokens[(0 << 1)] = 0;
                tokens[(0 << 1) + 1] = (
                    (ColorId.DefaultForeground << MetadataConsts.FOREGROUND_OFFSET)
                    | (encodedLanguageId << MetadataConsts.LANGUAGEID_OFFSET)
                );
                return new EncodedTokenizationResult(tokens, state);
            }
        )));
        return store;
    }

    static function innerMode(commentsConfig:CommentRule, accessor:Cityscape):IDisposable {
        final store = new DisposableStore();
        final languageId = INNER_LANGUAGE_ID;
        store.add(accessor.languageService.registerLanguage({id: languageId}));
        store.add(accessor.languageConfigurationService.register(languageId, {
            comments: commentsConfig
        }));
        return store;
    }

    function doTestLineCommentCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {

        final setup = (accessor:Cityscape, disposables:DisposableStore) -> {
            disposables.add(outerMode({lineComment: '//', blockComment: ['/*', '*/']}, accessor));
            disposables.add(innerMode({lineComment: null, blockComment: ['{/*', '*/}']}, accessor));
        };

        TestCommand.testCommand(
            this,
            lines,
            OUTER_LANGUAGE_ID,
            selection,
            (accessor, sel) -> new LineCommentCommand(accessor.languageConfigurationService, sel, 4, Type.Toggle, true, true),
            expectedLines,
            expectedSelection,
            true,
            setup,
            pos
        );
    }

    /**
     * test('issue #24047 (part 1): Commenting code in JSX files')
     */
    function testIssue24047Part1CommentingCodeInJSXFiles() {
        doTestLineCommentCommand(
            [
                'import React from \'react\';',
                'const Loader = () => (',
                '  <div>',
                '    Loading...',
                '  </div>',
                ');',
                'export default Loader;'
            ],
            new Selection(1, 1, 7, 22),
            [
                '// import React from \'react\';',
                '// const Loader = () => (',
                '//   <div>',
                '//     Loading...',
                '//   </div>',
                '// );',
                '// export default Loader;'
            ],
            new Selection(1, 4, 7, 25),
        );
   }

    /**
     * test('issue #24047 (part 2): Commenting code in JSX files')
     */
    function testIssue24047Part2CommentingCodeInJSXFiles() {
        doTestLineCommentCommand(
            [
                'import React from \'react\';',
                'const Loader = () => (',
                '  <div>',
                '    Loading...',
                '  </div>',
                ');',
                'export default Loader;'
            ],
            new Selection(3, 4, 3, 4),
            [
                'import React from \'react\';',
                'const Loader = () => (',
                '  {/* <div> */}',
                '    Loading...',
                '  </div>',
                ');',
                'export default Loader;'
            ],
            new Selection(3, 8, 3, 8),
        );
   }

    /**
     * test('issue #36173: Commenting code in JSX tag body')
     */
    function testIssue36173CommentingCodeInJSXTagBody() {
        doTestLineCommentCommand(
            [
                '<div>',
                '  {123}',
                '</div>',
            ],
            new Selection(2, 4, 2, 4),
            [
                '<div>',
                '  {/* {123} */}',
                '</div>',
            ],
            new Selection(2, 8, 2, 8),
        );
   }

}
