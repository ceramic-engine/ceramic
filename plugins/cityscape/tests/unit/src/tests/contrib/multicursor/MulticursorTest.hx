// Ported from vscode src/vs/editor/contrib/multicursor/test/browser/multicursor.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.multicursor;

import cityscape.Cityscape;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.Handler;
import cityscape.common.Model;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.find.view.FindController;
import cityscape.contrib.multicursor.view.Multicursor;
import cityscape.platform.storage.common.Storage;
import cityscape.view.EditorExtensions.EditorContributionInstantiation;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

/**
 * suite('Multicursor') and suite('Multicursor selection'), plus Cityscape
 * tests of the actions vscode does not test (move last selection, cursors
 * at line ends, the selection highlighter).
 *
 * vscode's `serviceCollection` gives the editors of the second suite one
 * `InMemoryStorageService`; each test here gets its own (no test of the
 * suite depends on options stored by another one).
 */
class MulticursorTest extends TestCase {

    static function fromRange(rng:Range):Array<Int> {
        return [rng.startLineNumber, rng.startColumn, rng.endLineNumber, rng.endColumn];
    }

    static function rangesOf(selections:Null<Array<Selection>>):String {
        return haxe.Json.stringify([for (s in selections) fromRange(s)]);
    }

    static function selectionsOf(selections:Null<Array<Selection>>):String {
        return [for (s in selections) s.toString()].join(',');
    }

    // suite('Multicursor')

    function testIssue26393MultipleCursorsWordWrap() {
        TestCodeEditor.withTestCodeEditor([
            StringTools.lpad('', 'a', 20),
            StringTools.lpad('', 'a', 20),
        ], {wordWrap: 'wordWrapColumn', wordWrapColumn: 10}, (editor, viewModel) -> {
            final addCursorDownAction = new InsertCursorBelow();
            addCursorDownAction.run(null, editor, {});

            assertEquals(2, viewModel.getCursorStates().length);

            assertEquals(1, viewModel.getCursorStates()[0].viewState.position.lineNumber);
            assertEquals(3, viewModel.getCursorStates()[1].viewState.position.lineNumber);

            editor.setPosition({lineNumber: 4, column: 1});
            final addCursorUpAction = new InsertCursorAbove();
            addCursorUpAction.run(null, editor, {});

            assertEquals(2, viewModel.getCursorStates().length);

            assertEquals(4, viewModel.getCursorStates()[0].viewState.position.lineNumber);
            assertEquals(2, viewModel.getCursorStates()[1].viewState.position.lineNumber);
        });
    }

    function testIssue2205MultiCursorPastesInReverseOrder() {
        TestCodeEditor.withTestCodeEditor([
            'abc',
            'def'
        ], {}, (editor, viewModel) -> {
            final addCursorUpAction = new InsertCursorAbove();

            editor.setSelection(new Selection(2, 1, 2, 1));
            addCursorUpAction.run(null, editor, {});
            assertEquals(2, viewModel.getSelections().length);

            editor.trigger('test', Handler.Paste, {
                text: '1\n2',
                multicursorText: [
                    '1',
                    '2'
                ]
            });

            assertEquals('1abc', editor.getModel().getLineContent(1));
            assertEquals('2def', editor.getModel().getLineContent(2));
        });
    }

    function testIssue1336InsertCursorBelowOnLastLineAddsACursorToTheEndOfTheCurrentLine() {
        TestCodeEditor.withTestCodeEditor([
            'abc'
        ], {}, (editor, viewModel) -> {
            final addCursorDownAction = new InsertCursorBelow();
            addCursorDownAction.run(null, editor, {});
            assertEquals(1, viewModel.getSelections().length);
        });
    }

    // suite('Multicursor selection')

    /**
     * `withTestCodeEditor(text, {serviceCollection}, ...)` with
     * `editor.registerAndInstantiateContribution(CommonFindController.ID, CommonFindController)`
     * and `MultiCursorSelectionController`.
     */
    static function testMulticursor(text:Array<String>, callback:(editor:TestCodeEditor, findController:CommonFindController) -> Void, ?prepare:(model:ITextModel) -> Void):Void {
        final context = new Cityscape();
        final storage = new InMemoryStorageService();
        final model = TestTextModel.instantiateTextModel(context, text.join('\n'));
        if (prepare != null) {
            prepare(model);
        }
        final editor = new TestCodeEditor(context, model, {}, [{
            id: CommonFindController.ID,
            ctor: e -> new CommonFindController(e, storage),
            instantiation: EditorContributionInstantiation.Eager
        }, {
            id: MultiCursorSelectionController.ID,
            ctor: e -> new MultiCursorSelectionController(e),
            instantiation: EditorContributionInstantiation.Eager
        }]);
        editor.getViewModel().setHasFocus(true);
        try {
            callback(editor, CommonFindController.get(editor));
        }
        catch (e:Dynamic) {
            editor.dispose();
            model.dispose();
            throw e;
        }
        editor.dispose();
        model.dispose();
    }

    function testIssue8817CursorPositionChangesWhenYouCancelMulticursor() {
        testMulticursor([
            'var x = (3 * 5)',
            'var y = (3 * 5)',
            'var z = (3 * 5)',
        ], (editor, findController) -> {
            final selectHighlightsAction = new SelectHighlightsAction();

            editor.setSelection(new Selection(2, 9, 2, 16));

            selectHighlightsAction.run(null, editor, null);
            assertEquals(haxe.Json.stringify([
                [2, 9, 2, 16],
                [1, 9, 1, 16],
                [3, 9, 3, 16],
            ]), rangesOf(editor.getSelections()));

            editor.trigger('test', 'removeSecondaryCursors', null);

            assertEquals(haxe.Json.stringify([2, 9, 2, 16]), haxe.Json.stringify(fromRange(editor.getSelection())));
        });
    }

    function testIssue5400SelectAllOccurrencesOfFindMatchDoesNotSelectAllIfFindUsesRegex() {
        testMulticursor([
            'something',
            'someething',
            'someeething',
            'nothing'
        ], (editor, findController) -> {
            final selectHighlightsAction = new SelectHighlightsAction();

            editor.setSelection(new Selection(1, 1, 1, 1));
            findController.getState().change({searchString: 'some+thing', isRegex: true, isRevealed: true}, false);

            selectHighlightsAction.run(null, editor, null);
            assertEquals(haxe.Json.stringify([
                [1, 1, 1, 10],
                [2, 1, 2, 11],
                [3, 1, 3, 12],
            ]), rangesOf(editor.getSelections()));

            assertEquals('some+thing', findController.getState().searchString);
        });
    }

    function testAddSelectionToNextFindMatchActionCanWorkWithMultiline() {
        testMulticursor([
            '',
            'qwe',
            'rty',
            '',
            'qwe',
            '',
            'rty',
            'qwe',
            'rty'
        ], (editor, findController) -> {
            final addSelectionToNextFindMatch = new AddSelectionToNextFindMatchAction();

            editor.setSelection(new Selection(2, 1, 3, 4));

            addSelectionToNextFindMatch.run(null, editor, null);
            assertEquals(haxe.Json.stringify([
                [2, 1, 3, 4],
                [8, 1, 9, 4]
            ]), rangesOf(editor.getSelections()));

            editor.trigger('test', 'removeSecondaryCursors', null);

            assertEquals(haxe.Json.stringify([2, 1, 3, 4]), haxe.Json.stringify(fromRange(editor.getSelection())));
        });
    }

    function testIssue6661AddSelectionToNextFindMatchActionCanWorkWithTouchingRanges() {
        testMulticursor([
            'abcabc',
            'abc',
            'abcabc',
        ], (editor, findController) -> {
            final addSelectionToNextFindMatch = new AddSelectionToNextFindMatchAction();

            editor.setSelection(new Selection(1, 1, 1, 4));

            addSelectionToNextFindMatch.run(null, editor, null);
            assertEquals(haxe.Json.stringify([
                [1, 1, 1, 4],
                [1, 4, 1, 7]
            ]), rangesOf(editor.getSelections()));

            addSelectionToNextFindMatch.run(null, editor, null);
            addSelectionToNextFindMatch.run(null, editor, null);
            addSelectionToNextFindMatch.run(null, editor, null);
            assertEquals(haxe.Json.stringify([
                [1, 1, 1, 4],
                [1, 4, 1, 7],
                [2, 1, 2, 4],
                [3, 1, 3, 4],
                [3, 4, 3, 7]
            ]), rangesOf(editor.getSelections()));

            editor.trigger('test', Handler.Type, {text: 'z'});
            assertEquals(haxe.Json.stringify([
                [1, 2, 1, 2],
                [1, 3, 1, 3],
                [2, 2, 2, 2],
                [3, 2, 3, 2],
                [3, 3, 3, 3]
            ]), rangesOf(editor.getSelections()));
            assertEquals([
                'zz',
                'z',
                'zz',
            ].join('\n'), editor.getValue());
        });
    }

    function testIssue23541MultilineCtrlDDoesNotWorkInCRLFFiles() {
        testMulticursor([
            '',
            'qwe',
            'rty',
            '',
            'qwe',
            '',
            'rty',
            'qwe',
            'rty'
        ], (editor, findController) -> {
            final addSelectionToNextFindMatch = new AddSelectionToNextFindMatchAction();

            editor.setSelection(new Selection(2, 1, 3, 4));

            addSelectionToNextFindMatch.run(null, editor, null);
            assertEquals(haxe.Json.stringify([
                [2, 1, 3, 4],
                [8, 1, 9, 4]
            ]), rangesOf(editor.getSelections()));

            editor.trigger('test', 'removeSecondaryCursors', null);

            assertEquals(haxe.Json.stringify([2, 1, 3, 4]), haxe.Json.stringify(fromRange(editor.getSelection())));
        }, (model) -> {
            // vscode sets the EOL on the editor's model before creating the contributions
            model.setEOL(EndOfLineSequence.CRLF);
        });
    }

    static function testAddSelectionToNextFindMatchAction(text:Array<String>, callback:(editor:TestCodeEditor, action:AddSelectionToNextFindMatchAction, findController:CommonFindController) -> Void):Void {
        testMulticursor(text, (editor, findController) -> {
            final action = new AddSelectionToNextFindMatchAction();
            callback(editor, action, findController);
        });
    }

    function testAddSelectionToNextFindMatchActionStartingWithSingleCollapsedSelection() {
        final text = [
            'abc pizza',
            'abc house',
            'abc bar'
        ];
        testAddSelectionToNextFindMatchAction(text, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 2, 1, 2),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testAddSelectionToNextFindMatchActionStartingWithTwoSelectionsOneBeingCollapsed1() {
        final text = [
            'abc pizza',
            'abc house',
            'abc bar'
        ];
        testAddSelectionToNextFindMatchAction(text, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 4),
                new Selection(2, 2, 2, 2),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testAddSelectionToNextFindMatchActionStartingWithTwoSelectionsOneBeingCollapsed2() {
        final text = [
            'abc pizza',
            'abc house',
            'abc bar'
        ];
        testAddSelectionToNextFindMatchAction(text, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 2, 1, 2),
                new Selection(2, 1, 2, 4),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testAddSelectionToNextFindMatchActionStartingWithAllCollapsedSelections() {
        final text = [
            'abc pizza',
            'abc house',
            'abc bar'
        ];
        testAddSelectionToNextFindMatchAction(text, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 2, 1, 2),
                new Selection(2, 2, 2, 2),
                new Selection(3, 1, 3, 1),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
                new Selection(3, 1, 3, 4),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testAddSelectionToNextFindMatchActionStartingWithAllCollapsedSelectionsOnDifferentWords() {
        final text = [
            'abc pizza',
            'abc house',
            'abc bar'
        ];
        testAddSelectionToNextFindMatchAction(text, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 6, 1, 6),
                new Selection(2, 6, 2, 6),
                new Selection(3, 6, 3, 6),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 5, 1, 10),
                new Selection(2, 5, 2, 10),
                new Selection(3, 5, 3, 8),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 5, 1, 10),
                new Selection(2, 5, 2, 10),
                new Selection(3, 5, 3, 8),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testIssue20651AddSelectionToNextFindMatchActionCaseInsensitive() {
        final text = [
            'test',
            'testte',
            'Test',
            'testte',
            'test'
        ];
        testAddSelectionToNextFindMatchAction(text, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 5),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 5),
                new Selection(2, 1, 2, 5),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 5),
                new Selection(2, 1, 2, 5),
                new Selection(3, 1, 3, 5),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 5),
                new Selection(2, 1, 2, 5),
                new Selection(3, 1, 3, 5),
                new Selection(4, 1, 4, 5),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 5),
                new Selection(2, 1, 2, 5),
                new Selection(3, 1, 3, 5),
                new Selection(4, 1, 4, 5),
                new Selection(5, 1, 5, 5),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 5),
                new Selection(2, 1, 2, 5),
                new Selection(3, 1, 3, 5),
                new Selection(4, 1, 4, 5),
                new Selection(5, 1, 5, 5),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    // suite('Find state disassociation')

    static final DISASSOCIATION_TEXT = [
        'app',
        'apples',
        'whatsapp',
        'app',
        'App',
        ' app'
    ];

    function testFindStateDisassociationEntersMode() {
        testAddSelectionToNextFindMatchAction(DISASSOCIATION_TEXT, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 2, 1, 2),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(4, 1, 4, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(4, 1, 4, 4),
                new Selection(6, 2, 6, 5),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testFindStateDisassociationLeavesModeWhenSelectionChanges() {
        testAddSelectionToNextFindMatchAction(DISASSOCIATION_TEXT, (editor, action, findController) -> {
            editor.setSelections([
                new Selection(1, 2, 1, 2),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(4, 1, 4, 4),
            ]), selectionsOf(editor.getSelections()));

            // change selection
            editor.setSelections([
                new Selection(1, 1, 1, 4),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(2, 1, 2, 4),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testFindStateDisassociationSelectHighlightsRespectsMode() {
        testMulticursor(DISASSOCIATION_TEXT, (editor, findController) -> {
            final action = new SelectHighlightsAction();
            editor.setSelections([
                new Selection(1, 2, 1, 2),
            ]);

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(4, 1, 4, 4),
                new Selection(6, 2, 6, 5),
            ]), selectionsOf(editor.getSelections()));

            action.run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 1, 1, 4),
                new Selection(4, 1, 4, 4),
                new Selection(6, 2, 6, 5),
            ]), selectionsOf(editor.getSelections()));
        });
    }

    // ---- Cityscape tests (actions vscode's suite does not cover; expected values from Monaco's code)

    function testCityscapeMoveSelectionToNextFindMatch() {
        testMulticursor(DISASSOCIATION_TEXT, (editor, findController) -> {
            final add = new AddSelectionToNextFindMatchAction();
            final move = new MoveSelectionToNextFindMatchAction();
            editor.setSelections([new Selection(1, 2, 1, 2)]);
            add.run(null, editor, null);
            add.run(null, editor, null);
            assertEquals(selectionsOf([new Selection(1, 1, 1, 4), new Selection(4, 1, 4, 4)]), selectionsOf(editor.getSelections()));
            // Cmd+K Cmd+D: the last selection moves on, skipping `App` (match case of the disassociated mode)
            move.run(null, editor, null);
            assertEquals(selectionsOf([new Selection(1, 1, 1, 4), new Selection(6, 2, 6, 5)]), selectionsOf(editor.getSelections()));
        });
    }

    function testCityscapeAddAndMoveToPreviousFindMatch() {
        testMulticursor(DISASSOCIATION_TEXT, (editor, findController) -> {
            final addPrevious = new AddSelectionToPreviousFindMatchAction();
            final movePrevious = new MoveSelectionToPreviousFindMatchAction();
            editor.setSelections([new Selection(6, 3, 6, 3)]);
            addPrevious.run(null, editor, null);
            assertEquals(selectionsOf([new Selection(6, 2, 6, 5)]), selectionsOf(editor.getSelections()));
            addPrevious.run(null, editor, null);
            assertEquals(selectionsOf([new Selection(6, 2, 6, 5), new Selection(4, 1, 4, 4)]), selectionsOf(editor.getSelections()));
            movePrevious.run(null, editor, null);
            assertEquals(selectionsOf([new Selection(6, 2, 6, 5), new Selection(1, 1, 1, 4)]), selectionsOf(editor.getSelections()));
        });
    }

    function testCityscapeInsertCursorAtEndOfEachLineSelected() {
        TestCodeEditor.withTestCodeEditor([
            'first',
            'second',
            'third'
        ], {}, (editor, viewModel) -> {
            editor.setSelection(new Selection(1, 2, 3, 3));
            new InsertCursorAtEndOfEachLineSelected().run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 6, 1, 6),
                new Selection(2, 7, 2, 7),
                new Selection(3, 3, 3, 3)
            ]), selectionsOf(editor.getSelections()));
            // ending at column 1: no cursor on the last line
            editor.setSelection(new Selection(1, 2, 3, 1));
            new InsertCursorAtEndOfEachLineSelected().run(null, editor, null);
            assertEquals(selectionsOf([
                new Selection(1, 6, 1, 6),
                new Selection(2, 7, 2, 7)
            ]), selectionsOf(editor.getSelections()));
        });
    }

    function testCityscapeAddCursorsToBottomAndTopAndFocusCursors() {
        TestCodeEditor.withTestCodeEditor([
            'aaaa',
            'bbbb',
            'cccc'
        ], {}, (editor, viewModel) -> {
            editor.setSelection(new Selection(2, 2, 2, 3));
            new InsertCursorAtEndOfLineSelected().run(null, editor, null);
            assertEquals(selectionsOf([new Selection(2, 2, 2, 3), new Selection(3, 2, 3, 3)]), selectionsOf(editor.getSelections()));
            editor.setSelection(new Selection(2, 2, 2, 2));
            new InsertCursorAtTopOfLineSelected().run(null, editor, null);
            assertEquals(selectionsOf([new Selection(2, 2, 2, 2), new Selection(1, 2, 1, 2)]), selectionsOf(editor.getSelections()));
            new FocusNextCursor().run(null, editor, {});
            assertEquals(selectionsOf([new Selection(1, 2, 1, 2), new Selection(2, 2, 2, 2)]), selectionsOf(editor.getSelections()));
            new FocusPreviousCursor().run(null, editor, {});
            assertEquals(selectionsOf([new Selection(2, 2, 2, 2), new Selection(1, 2, 1, 2)]), selectionsOf(editor.getSelections()));
        });
    }

    function selectionHighlights(editor:TestCodeEditor):String {
        final result:Array<String> = [];
        for (d in editor.getModel().getAllDecorations()) {
            if (d.options.className == 'selectionHighlight') {
                result.push(Range.lift(d.range).toString());
            }
        }
        result.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return result.join(' ');
    }

    function testCityscapeSelectionHighlighter() {
        final context = new Cityscape();
        final model = TestTextModel.instantiateTextModel(context, ['foo bar', 'bar foo bar', '  ', 'xbar'].join('\n'));
        final editor = new TestCodeEditor(context, model, {}, context.editorExtensions.getSomeEditorContributions([CommonFindController.ID, MultiCursorSelectionController.ID, SelectionHighlighter.ID]));
        editor.getViewModel().setHasFocus(true);
        final highlighter = SelectionHighlighter.get(editor);

        // a selected word: the other occurrences (not the selection itself), no whole word
        editor.setSelections([new Selection(1, 5, 1, 8)], 'test', CursorChangeReason.Explicit);
        assertEquals('[2,1 -> 2,4] [2,9 -> 2,12] [4,2 -> 4,5]', selectionHighlights(editor));

        // an empty selection: no selection highlight (the word highlighter does that)
        editor.setSelections([new Selection(1, 5, 1, 5)], 'test', CursorChangeReason.Explicit);
        highlighter._flushPendingUpdate();
        assertEquals('', selectionHighlights(editor));

        // whitespace only: nothing
        editor.setSelections([new Selection(3, 1, 3, 3)], 'test', CursorChangeReason.Explicit);
        assertEquals('', selectionHighlights(editor));

        // multi-line: nothing
        editor.setSelections([new Selection(1, 5, 2, 2)], 'test', CursorChangeReason.Explicit);
        assertEquals('', selectionHighlights(editor));

        // option off
        editor.updateOptions({selectionHighlight: false});
        editor.setSelections([new Selection(1, 5, 1, 8)], 'test', CursorChangeReason.Explicit);
        assertEquals('', selectionHighlights(editor));

        editor.dispose();
        model.dispose();
    }

    function testCityscapeKeybindings() {
        final context = new Cityscape();
        // the contributions register their keybindings with the first use of the registry
        final registry = context.editorExtensions;
        final keys = context.keybindingService;
        function keysOf(id:String):Array<String> {
            return [for (k in keys.lookupKeybindings(id)) k.getUserSettingsLabel()];
        }
        // Monaco's default keybindings (as resolved on the platform the tests run on)
        assertTrue(keysOf('editor.action.addSelectionToNextFindMatch').length > 0);
        assertTrue(keysOf('editor.action.moveSelectionToNextFindMatch').length > 0);
        assertTrue(keysOf('editor.action.selectHighlights').length > 0);
        assertTrue(keysOf('editor.action.insertCursorAtEndOfEachLineSelected').indexOf('shift+alt+i') != -1);
        assertTrue(keysOf('editor.action.insertCursorAbove').length > 0);
        assertTrue(keysOf('editor.action.insertCursorBelow').length > 0);
        // the context menu item of `changeAll`
        assertTrue([for (i in registry.getMenuItems('EditorContext')) i.command.id].indexOf('editor.action.changeAll') != -1);
    }

}
