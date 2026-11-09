// Ported from vscode src/vs/editor/test/browser/commands/shiftCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.commands;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.commands.ShiftCommand;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import testing.TestCase;
import testing.TestCommand;
import testing.TestLanguageConfigurationService;
import tests.TestTextModel;
import tests.modes.supports.OnEnterRules;

/**
 * suite('Editor Commands - ShiftCommand')
 */
class ShiftCommandTest extends TestCase {

    static inline final DocBlockCommentModeLanguageId = 'commentMode';

    /**
     * Create single edit operation
     */
    static function createSingleEditOp(text:String, positionLineNumber:Int, positionColumn:Int, ?selectionLineNumber:Int, ?selectionColumn:Int):ISingleEditOperation {
        return {
            range: new Range(selectionLineNumber != null ? selectionLineNumber : positionLineNumber, selectionColumn != null ? selectionColumn : positionColumn, positionLineNumber, positionColumn),
            text: text,
            forceMoveMarkers: false
        };
    }

    /**
     * Monaco's `DocBlockCommentMode`.
     */
    static function prepareDocBlockCommentLanguage(accessor:Cityscape, disposables:DisposableStore):Void {
        final languageConfigurationService = accessor.languageConfigurationService;
        final languageService = accessor.languageService;
        disposables.add(languageService.registerLanguage({id: DocBlockCommentModeLanguageId}));
        disposables.add(languageConfigurationService.register(DocBlockCommentModeLanguageId, {
            brackets: [
                ['(', ')'],
                ['{', '}'],
                ['[', ']']
            ],

            onEnterRules: OnEnterRules.javascriptOnEnterRules
        }));
    }

    function doTestCommand(lines:Array<String>, languageId:Null<String>, selection:Selection, commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand, expectedLines:Array<String>, expectedSelection:Selection, ?forceTokenization:Bool, ?prepare:(accessor:Cityscape, disposables:DisposableStore) -> Void, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(this, lines, languageId, selection, commandFactory, expectedLines, expectedSelection, forceTokenization, prepare, pos);
    }

    function doTestShiftCommand(lines:Array<String>, languageId:Null<String>, useTabStops:Bool, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?prepare:(accessor:Cityscape, disposables:DisposableStore) -> Void, ?pos:haxe.PosInfos):Void {
        doTestCommand(lines, languageId, selection, (accessor, sel) -> new ShiftCommand(sel, {
            isUnshift: false,
            tabSize: 4,
            indentSize: 4,
            insertSpaces: false,
            useTabStops: useTabStops,
            autoIndent: EditorAutoIndentStrategy.Full,
        }, accessor.languageConfigurationService), expectedLines, expectedSelection, null, prepare, pos);
    }

    function doTestUnshiftCommand(lines:Array<String>, languageId:Null<String>, useTabStops:Bool, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?prepare:(accessor:Cityscape, disposables:DisposableStore) -> Void, ?pos:haxe.PosInfos):Void {
        doTestCommand(lines, languageId, selection, (accessor, sel) -> new ShiftCommand(sel, {
            isUnshift: true,
            tabSize: 4,
            indentSize: 4,
            insertSpaces: false,
            useTabStops: useTabStops,
            autoIndent: EditorAutoIndentStrategy.Full,
        }, accessor.languageConfigurationService), expectedLines, expectedSelection, null, prepare, pos);
    }

    function _assertUnshiftCommand(tabSize:Int, indentSize:Int, insertSpaces:Bool, text:Array<String>, expected:Array<ISingleEditOperation>):Void {
        TestTextModel.withEditorModel(text, (model) -> {
            final testLanguageConfigurationService = new TestLanguageConfigurationService();
            final op = new ShiftCommand(new Selection(1, 1, text.length + 1, 1), {
                isUnshift: true,
                tabSize: tabSize,
                indentSize: indentSize,
                insertSpaces: insertSpaces,
                useTabStops: true,
                autoIndent: EditorAutoIndentStrategy.Full,
            }, testLanguageConfigurationService);
            final actual = TestCommand.getEditOperation(model, op);
            assertDeepEquals(expected, actual);
            testLanguageConfigurationService.dispose();
        });
    }

    function _assertShiftCommand(tabSize:Int, indentSize:Int, insertSpaces:Bool, text:Array<String>, expected:Array<ISingleEditOperation>):Void {
        TestTextModel.withEditorModel(text, (model) -> {
            final testLanguageConfigurationService = new TestLanguageConfigurationService();
            final op = new ShiftCommand(new Selection(1, 1, text.length + 1, 1), {
                isUnshift: false,
                tabSize: tabSize,
                indentSize: indentSize,
                insertSpaces: insertSpaces,
                useTabStops: true,
                autoIndent: EditorAutoIndentStrategy.Full,
            }, testLanguageConfigurationService);
            final actual = TestCommand.getEditOperation(model, op);
            assertDeepEquals(expected, actual);
            testLanguageConfigurationService.dispose();
        });

    /**
     * test('Bug 9503: Shifting without any selection')
     */
    function testBug9503ShiftingWithoutAnySelection() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 1, 1),
            [
                '\tMy First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 2, 1, 2)
        );
    }

    /**
     * test('shift on single line selection 1')
     */
    function testShiftOnSingleLineSelection1() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 3, 1, 1),
            [
                '\tMy First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 4, 1, 1)
        );
    }

    /**
     * test('shift on single line selection 2')
     */
    function testShiftOnSingleLineSelection2() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 1, 3),
            [
                '\tMy First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 1, 1, 4)
        );
    }

    /**
     * test('simple shift')
     */
    function testSimpleShift() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 2, 1),
            [
                '\tMy First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 1, 2, 1)
        );
    }

    /**
     * test('shifting on two separate lines')
     */
    function testShiftingOnTwoSeparateLines() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 2, 1),
            [
                '\tMy First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 1, 2, 1)
        );

        doTestShiftCommand(
            [
                '\tMy First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(2, 1, 3, 1),
            [
                '\tMy First Line',
                '\t\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(2, 1, 3, 1)
        );
    }

    /**
     * test('shifting on two lines')
     */
    function testShiftingOnTwoLines() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 2, 2, 2),
            [
                '\tMy First Line',
                '\t\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 3, 2, 2)
        );
    }

    /**
     * test('shifting on two lines again')
     */
    function testShiftingOnTwoLinesAgain() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(2, 2, 1, 2),
            [
                '\tMy First Line',
                '\t\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(2, 2, 1, 3)
        );
    }

    /**
     * test('shifting at end of file')
     */
    function testShiftingAtEndOfFile() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(4, 1, 5, 2),
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '\t123'
            ],
            new Selection(4, 1, 5, 3)
        );
    }

    /**
     * test('issue #1120 TAB should not indent empty lines in a multi-line selection')
     */
    function testIssue1120TABShouldNotIndentEmptyLinesInAMultiLineSelection() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 5, 2),
            [
                '\tMy First Line',
                '\t\t\tMy Second Line',
                '\t\tThird Line',
                '',
                '\t123'
            ],
            new Selection(1, 1, 5, 3)
        );

        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(4, 1, 5, 1),
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '\t',
                '123'
            ],
            new Selection(4, 1, 5, 1)
        );
    }

    /**
     * test('unshift on single line selection 1')
     */
    function testUnshiftOnSingleLineSelection1() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(2, 3, 2, 1),
            [
                'My First Line',
                '\t\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(2, 3, 2, 1)
        );
    }

    /**
     * test('unshift on single line selection 2')
     */
    function testUnshiftOnSingleLineSelection2() {
        doTestShiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(2, 1, 2, 3),
            [
                'My First Line',
                '\t\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(2, 1, 2, 3)
        );
    }

    /**
     * test('simple unshift')
     */
    function testSimpleUnshift() {
        doTestUnshiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 2, 1),
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 1, 2, 1)
        );
    }

    /**
     * test('unshifting on two lines 1')
     */
    function testUnshiftingOnTwoLines1() {
        doTestUnshiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 2, 2, 2),
            [
                'My First Line',
                '\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(1, 2, 2, 2)
        );
    }

    /**
     * test('unshifting on two lines 2')
     */
    function testUnshiftingOnTwoLines2() {
        doTestUnshiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(2, 3, 2, 1),
            [
                'My First Line',
                '\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(2, 2, 2, 1)
        );
    }

    /**
     * test('unshifting at the end of the file')
     */
    function testUnshiftingAtTheEndOfTheFile() {
        doTestUnshiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(4, 1, 5, 2),
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(4, 1, 5, 2)
        );
    }

    /**
     * test('unshift many times + shift')
     */
    function testUnshiftManyTimesShift() {
        doTestUnshiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 5, 4),
            [
                'My First Line',
                '\tMy Second Line',
                'Third Line',
                '',
                '123'
            ],
            new Selection(1, 1, 5, 4)
        );

        doTestUnshiftCommand(
            [
                'My First Line',
                '\tMy Second Line',
                'Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 5, 4),
            [
                'My First Line',
                'My Second Line',
                'Third Line',
                '',
                '123'
            ],
            new Selection(1, 1, 5, 4)
        );

        doTestShiftCommand(
            [
                'My First Line',
                'My Second Line',
                'Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(1, 1, 5, 4),
            [
                '\tMy First Line',
                '\tMy Second Line',
                '\tThird Line',
                '',
                '\t123'
            ],
            new Selection(1, 1, 5, 5)
        );
    }

    /**
     * test('Bug 9119: Unshift from first column doesn\'t work')
     */
    function testBug9119UnshiftFromFirstColumnDoesnTWork() {
        doTestUnshiftCommand(
            [
                'My First Line',
                '\t\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            null,
            true,
            new Selection(2, 1, 2, 1),
            [
                'My First Line',
                '\tMy Second Line',
                '    Third Line',
                '',
                '123'
            ],
            new Selection(2, 1, 2, 1)
        );
    }

    /**
     * test('issue #348: indenting around doc block comments')
     */
    function testIssue348IndentingAroundDocBlockComments() {
        doTestShiftCommand(
            [
                '',
                '/**',
                ' * a doc comment',
                ' */',
                'function hello() {}'
            ],
            DocBlockCommentModeLanguageId,
            true,
            new Selection(1, 1, 5, 20),
            [
                '',
                '\t/**',
                '\t * a doc comment',
                '\t */',
                '\tfunction hello() {}'
            ],
            new Selection(1, 1, 5, 21),
            prepareDocBlockCommentLanguage
        );

        doTestUnshiftCommand(
            [
                '',
                '/**',
                ' * a doc comment',
                ' */',
                'function hello() {}'
            ],
            DocBlockCommentModeLanguageId,
            true,
            new Selection(1, 1, 5, 20),
            [
                '',
                '/**',
                ' * a doc comment',
                ' */',
                'function hello() {}'
            ],
            new Selection(1, 1, 5, 20),
            prepareDocBlockCommentLanguage
        );

        doTestUnshiftCommand(
            [
                '\t',
                '\t/**',
                '\t * a doc comment',
                '\t */',
                '\tfunction hello() {}'
            ],
            DocBlockCommentModeLanguageId,
            true,
            new Selection(1, 1, 5, 21),
            [
                '',
                '/**',
                ' * a doc comment',
                ' */',
                'function hello() {}'
            ],
            new Selection(1, 1, 5, 20),
            prepareDocBlockCommentLanguage
        );
    }

    /**
     * test('issue #1609: Wrong indentation of block comments')
     */
    function testIssue1609WrongIndentationOfBlockComments() {
        doTestShiftCommand(
            [
                '',
                '/**',
                ' * test',
                ' *',
                ' * @type {number}',
                ' */',
                'var foo = 0;'
            ],
            DocBlockCommentModeLanguageId,
            true,
            new Selection(1, 1, 7, 13),
            [
                '',
                '\t/**',
                '\t * test',
                '\t *',
                '\t * @type {number}',
                '\t */',
                '\tvar foo = 0;'
            ],
            new Selection(1, 1, 7, 14),
            prepareDocBlockCommentLanguage
        );
    }

    /**
     * test('issue #1620: a) Line indent doesn\'t handle leading whitespace properly')
     */
    function testIssue1620ALineIndentDoesnTHandleLeadingWhitespaceProperly() {
        doTestCommand(
            [
                '   Written | Numeric',
                '       one | 1',
                '       two | 2',
                '     three | 3',
                '      four | 4',
                '      five | 5',
                '       six | 6',
                '     seven | 7',
                '     eight | 8',
                '      nine | 9',
                '       ten | 10',
                '    eleven | 11',
                '',
            ],
            null,
            new Selection(1, 1, 13, 1),
            (accessor, sel) -> new ShiftCommand(sel, {
                isUnshift: false,
                tabSize: 4,
                indentSize: 4,
                insertSpaces: true,
                useTabStops: false,
                autoIndent: EditorAutoIndentStrategy.Full,
            }, accessor.languageConfigurationService),
            [
                '       Written | Numeric',
                '           one | 1',
                '           two | 2',
                '         three | 3',
                '          four | 4',
                '          five | 5',
                '           six | 6',
                '         seven | 7',
                '         eight | 8',
                '          nine | 9',
                '           ten | 10',
                '        eleven | 11',
                '',
            ],
            new Selection(1, 1, 13, 1)
        );
    }

    /**
     * test('issue #1620: b) Line indent doesn\'t handle leading whitespace properly')
     */
    function testIssue1620BLineIndentDoesnTHandleLeadingWhitespaceProperly() {
        doTestCommand(
            [
                '       Written | Numeric',
                '           one | 1',
                '           two | 2',
                '         three | 3',
                '          four | 4',
                '          five | 5',
                '           six | 6',
                '         seven | 7',
                '         eight | 8',
                '          nine | 9',
                '           ten | 10',
                '        eleven | 11',
                '',
            ],
            null,
            new Selection(1, 1, 13, 1),
            (accessor, sel) -> new ShiftCommand(sel, {
                isUnshift: true,
                tabSize: 4,
                indentSize: 4,
                insertSpaces: true,
                useTabStops: false,
                autoIndent: EditorAutoIndentStrategy.Full,
            }, accessor.languageConfigurationService),
            [
                '   Written | Numeric',
                '       one | 1',
                '       two | 2',
                '     three | 3',
                '      four | 4',
                '      five | 5',
                '       six | 6',
                '     seven | 7',
                '     eight | 8',
                '      nine | 9',
                '       ten | 10',
                '    eleven | 11',
                '',
            ],
            new Selection(1, 1, 13, 1)
        );
    }

    /**
     * test('issue #1620: c) Line indent doesn\'t handle leading whitespace properly')
     */
    function testIssue1620CLineIndentDoesnTHandleLeadingWhitespaceProperly() {
        doTestCommand(
            [
                '       Written | Numeric',
                '           one | 1',
                '           two | 2',
                '         three | 3',
                '          four | 4',
                '          five | 5',
                '           six | 6',
                '         seven | 7',
                '         eight | 8',
                '          nine | 9',
                '           ten | 10',
                '        eleven | 11',
                '',
            ],
            null,
            new Selection(1, 1, 13, 1),
            (accessor, sel) -> new ShiftCommand(sel, {
                isUnshift: true,
                tabSize: 4,
                indentSize: 4,
                insertSpaces: false,
                useTabStops: false,
                autoIndent: EditorAutoIndentStrategy.Full,
            }, accessor.languageConfigurationService),
            [
                '   Written | Numeric',
                '       one | 1',
                '       two | 2',
                '     three | 3',
                '      four | 4',
                '      five | 5',
                '       six | 6',
                '     seven | 7',
                '     eight | 8',
                '      nine | 9',
                '       ten | 10',
                '    eleven | 11',
                '',
            ],
            new Selection(1, 1, 13, 1)
        );
    }

    /**
     * test('issue #1620: d) Line indent doesn\'t handle leading whitespace properly')
     */
    function testIssue1620DLineIndentDoesnTHandleLeadingWhitespaceProperly() {
        doTestCommand(
            [
                '\t   Written | Numeric',
                '\t       one | 1',
                '\t       two | 2',
                '\t     three | 3',
                '\t      four | 4',
                '\t      five | 5',
                '\t       six | 6',
                '\t     seven | 7',
                '\t     eight | 8',
                '\t      nine | 9',
                '\t       ten | 10',
                '\t    eleven | 11',
                '',
            ],
            null,
            new Selection(1, 1, 13, 1),
            (accessor, sel) -> new ShiftCommand(sel, {
                isUnshift: true,
                tabSize: 4,
                indentSize: 4,
                insertSpaces: true,
                useTabStops: false,
                autoIndent: EditorAutoIndentStrategy.Full,
            }, accessor.languageConfigurationService),
            [
                '   Written | Numeric',
                '       one | 1',
                '       two | 2',
                '     three | 3',
                '      four | 4',
                '      five | 5',
                '       six | 6',
                '     seven | 7',
                '     eight | 8',
                '      nine | 9',
                '       ten | 10',
                '    eleven | 11',
                '',
            ],
            new Selection(1, 1, 13, 1)
        );
    }

    /**
     * test('issue microsoft/monaco-editor#443: Indentation of a single row deletes selected text in some cases')
     */
    function testIssueMicrosoftMonacoEditor443IndentationOfASingleRowDeletesSelectedTextInSomeCases() {
        doTestCommand(
            [
                'Hello world!',
                'another line'
            ],
            null,
            new Selection(1, 1, 1, 13),
            (accessor, sel) -> new ShiftCommand(sel, {
                isUnshift: false,
                tabSize: 4,
                indentSize: 4,
                insertSpaces: false,
                useTabStops: true,
                autoIndent: EditorAutoIndentStrategy.Full,
            }, accessor.languageConfigurationService),
            [
                '\tHello world!',
                'another line'
            ],
            new Selection(1, 1, 1, 14)
        );
    }

    /**
     * test('bug #16815:Shift+Tab doesn\'t go back to tabstop')
     */
    function testBug16815ShiftTabDoesnTGoBackToTabstop() {

        final repeatStr = (str:String, cnt:Int) -> {
            var r = '';
            for (i in 0...cnt) {
                r += str;
            }
            return r;
        };

        final testOutdent = (tabSize:Int, indentSize:Int, insertSpaces:Bool, lineText:String, expectedIndents:Int) -> {
            final oneIndent = insertSpaces ? repeatStr(' ', indentSize) : '\t';
            final expectedIndent = repeatStr(oneIndent, expectedIndents);
            if (lineText.length > 0) {
                _assertUnshiftCommand(tabSize, indentSize, insertSpaces, [lineText + 'aaa'], [createSingleEditOp(expectedIndent, 1, 1, 1, lineText.length + 1)]);
            } else {
                _assertUnshiftCommand(tabSize, indentSize, insertSpaces, [lineText + 'aaa'], []);
            }
        };

        final testIndent = (tabSize:Int, indentSize:Int, insertSpaces:Bool, lineText:String, expectedIndents:Int) -> {
            final oneIndent = insertSpaces ? repeatStr(' ', indentSize) : '\t';
            final expectedIndent = repeatStr(oneIndent, expectedIndents);
            _assertShiftCommand(tabSize, indentSize, insertSpaces, [lineText + 'aaa'], [createSingleEditOp(expectedIndent, 1, 1, 1, lineText.length + 1)]);
        };

        final testIndentation = (tabSize:Int, indentSize:Int, lineText:String, expectedOnOutdent:Int, expectedOnIndent:Int) -> {
            testOutdent(tabSize, indentSize, true, lineText, expectedOnOutdent);
            testOutdent(tabSize, indentSize, false, lineText, expectedOnOutdent);

            testIndent(tabSize, indentSize, true, lineText, expectedOnIndent);
            testIndent(tabSize, indentSize, false, lineText, expectedOnIndent);
        };

        // insertSpaces: true
        // 0 -> 0
        testIndentation(4, 4, '', 0, 1);

        // 1 -> 0
        testIndentation(4, 4, '\t', 0, 2);
        testIndentation(4, 4, ' ', 0, 1);
        testIndentation(4, 4, ' \t', 0, 2);
        testIndentation(4, 4, '  ', 0, 1);
        testIndentation(4, 4, '  \t', 0, 2);
        testIndentation(4, 4, '   ', 0, 1);
        testIndentation(4, 4, '   \t', 0, 2);
        testIndentation(4, 4, '    ', 0, 2);

        // 2 -> 1
        testIndentation(4, 4, '\t\t', 1, 3);
        testIndentation(4, 4, '\t ', 1, 2);
        testIndentation(4, 4, '\t \t', 1, 3);
        testIndentation(4, 4, '\t  ', 1, 2);
        testIndentation(4, 4, '\t  \t', 1, 3);
        testIndentation(4, 4, '\t   ', 1, 2);
        testIndentation(4, 4, '\t   \t', 1, 3);
        testIndentation(4, 4, '\t    ', 1, 3);
        testIndentation(4, 4, ' \t\t', 1, 3);
        testIndentation(4, 4, ' \t ', 1, 2);
        testIndentation(4, 4, ' \t \t', 1, 3);
        testIndentation(4, 4, ' \t  ', 1, 2);
        testIndentation(4, 4, ' \t  \t', 1, 3);
        testIndentation(4, 4, ' \t   ', 1, 2);
        testIndentation(4, 4, ' \t   \t', 1, 3);
        testIndentation(4, 4, ' \t    ', 1, 3);
        testIndentation(4, 4, '  \t\t', 1, 3);
        testIndentation(4, 4, '  \t ', 1, 2);
        testIndentation(4, 4, '  \t \t', 1, 3);
        testIndentation(4, 4, '  \t  ', 1, 2);
        testIndentation(4, 4, '  \t  \t', 1, 3);
        testIndentation(4, 4, '  \t   ', 1, 2);
        testIndentation(4, 4, '  \t   \t', 1, 3);
        testIndentation(4, 4, '  \t    ', 1, 3);
        testIndentation(4, 4, '   \t\t', 1, 3);
        testIndentation(4, 4, '   \t ', 1, 2);
        testIndentation(4, 4, '   \t \t', 1, 3);
        testIndentation(4, 4, '   \t  ', 1, 2);
        testIndentation(4, 4, '   \t  \t', 1, 3);
        testIndentation(4, 4, '   \t   ', 1, 2);
        testIndentation(4, 4, '   \t   \t', 1, 3);
        testIndentation(4, 4, '   \t    ', 1, 3);
        testIndentation(4, 4, '    \t', 1, 3);
        testIndentation(4, 4, '     ', 1, 2);
        testIndentation(4, 4, '     \t', 1, 3);
        testIndentation(4, 4, '      ', 1, 2);
        testIndentation(4, 4, '      \t', 1, 3);
        testIndentation(4, 4, '       ', 1, 2);
        testIndentation(4, 4, '       \t', 1, 3);
        testIndentation(4, 4, '        ', 1, 3);

        // 3 -> 2
        testIndentation(4, 4, '         ', 2, 3);

    }
    }

}
