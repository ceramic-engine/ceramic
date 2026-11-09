// Ported from vscode src/vs/editor/contrib/find/test/browser/findModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.find;

import cityscape.base.common.Lifecycle.DisposableStore;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeTextBufferBuilder;
import cityscape.contrib.find.view.FindModel;
import cityscape.contrib.find.view.FindState;
import testing.TestCase;
import testing.TestCodeEditor;
import cityscape.view.CoreCommands;
import tests.TestTextModel;

/**
 * suite('FindModel'): all of vscode's tests, each run on a model made from
 * the text and on one made from a piece tree built in three chunks.
 *
 * `editor.trigger('mouse', CoreNavigationCommands.MoveTo.id, {position})` is
 * `moveTo(editor, position)` (the core command with the source `'mouse'`,
 * like `trigger`).
 */
class FindModelTest extends TestCase {

    var disposables:DisposableStore;

    override function setup():Void {
        disposables = new DisposableStore();
    }

    override function teardown():Void {
        disposables.dispose();
    }

    function findTest(callback:(editor:TestCodeEditor) -> Void):Void {
        final textArr = [
            '// my cool header',
            '#include "cool.h"',
            '#include <iostream>',
            '',
            'int main() {',
            '    cout << "hello world, Hello!" << endl;',
            '    cout << "hello world again" << endl;',
            '    cout << "Hello world again" << endl;',
            '    cout << "helloworld again" << endl;',
            '}',
            '// blablablaciao',
            ''
        ];
        TestCodeEditor.withTestCodeEditor(textArr, {}, (editor, _) -> runWithFindEditor(editor, callback));

        final text = textArr.join('\n');
        final ptBuilder = new PieceTreeTextBufferBuilder();
        ptBuilder.acceptChunk(text.substr(0, 94));
        ptBuilder.acceptChunk(text.substr(94, 101));
        ptBuilder.acceptChunk(text.substr(195, 59));
        final factory = ptBuilder.finish();
        final model = TestTextModel.createTextModel(factory);
        TestCodeEditor.withTestCodeEditor(model, {}, (editor, _) -> runWithFindEditor(editor, callback));
        model.dispose();
    }

    function runWithFindEditor(editor:TestCodeEditor, callback:(editor:TestCodeEditor) -> Void):Void {
        callback(editor);
    }

    /**
     * `editor.trigger('mouse', CoreNavigationCommands.MoveTo.id, {position})`.
     */
    function moveTo(editor:TestCodeEditor, position:Position):Void {
        CoreNavigationCommands.MoveTo.runCoreEditorCommand(editor._getViewModel(), {source: 'mouse', position: position});
    }

    static function fromRange(rng:Range):Array<Int> {
        return [rng.startLineNumber, rng.startColumn, rng.endLineNumber, rng.endColumn];
    }

    static function _getFindState(editor:TestCodeEditor):{highlighted:Array<Array<Int>>, findDecorations:Array<Array<Int>>} {
        final model = editor.getModel();
        final currentFindMatches:Array<Range> = [];
        final allFindMatches:Array<Range> = [];

        for (dec in model.getAllDecorations()) {
            if (dec.options.className == 'currentFindMatch') {
                currentFindMatches.push(dec.range);
                allFindMatches.push(dec.range);
            } else if (dec.options.className == 'findMatch') {
                allFindMatches.push(dec.range);
            }
        }

        haxe.ds.ArraySort.sort(currentFindMatches, Range.compareRangesUsingStarts);
        haxe.ds.ArraySort.sort(allFindMatches, Range.compareRangesUsingStarts);

        return {
            highlighted: [for (r in currentFindMatches) fromRange(r)],
            findDecorations: [for (r in allFindMatches) fromRange(r)]
        };
    }

    function assertFindState(editor:TestCodeEditor, cursor:Array<Int>, highlighted:Null<Array<Int>>, findDecorations:Array<Array<Int>>, ?pos:haxe.PosInfos):Void {
        assertDeepEquals(cursor, fromRange(editor.getSelection()), 'cursor', pos);

        final expectedState = {
            highlighted: highlighted != null ? [highlighted] : [],
            findDecorations: findDecorations
        };
        final state = _getFindState(editor);
        assertDeepEquals(expectedState.highlighted, state.highlighted, 'state (highlighted)', pos);
        assertDeepEquals(expectedState.findDecorations, state.findDecorations, 'state (findDecorations)', pos);
    }

    /**
     * findTest('incremental find from beginning of file')
     */
    function testIncrementalFindFromBeginningOfFile() {
        findTest((editor) -> {
            editor.setPosition({ lineNumber: 1, column: 1 });
            final findState = disposables.add(new FindReplaceState());
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            // simulate typing the search string
            findState.change({ searchString: "H" }, true);
            assertFindState(
                editor,
                [1, 12, 1, 13],
                [1, 12, 1, 13],
                [
                    [1, 12, 1, 13],
                    [2, 16, 2, 17],
                    [6, 14, 6, 15],
                    [6, 27, 6, 28],
                    [7, 14, 7, 15],
                    [8, 14, 8, 15],
                    [9, 14, 9, 15]
                ]
            );

            // simulate typing the search string
            findState.change({ searchString: "He" }, true);
            assertFindState(
                editor,
                [1, 12, 1, 14],
                [1, 12, 1, 14],
                [
                    [1, 12, 1, 14],
                    [6, 14, 6, 16],
                    [6, 27, 6, 29],
                    [7, 14, 7, 16],
                    [8, 14, 8, 16],
                    [9, 14, 9, 16]
                ]
            );

            // simulate typing the search string
            findState.change({ searchString: "Hello" }, true);
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            // simulate toggling on `matchCase`
            findState.change({ matchCase: true }, true);
            assertFindState(
                editor,
                [6, 27, 6, 32],
                [6, 27, 6, 32],
                [
                    [6, 27, 6, 32],
                    [8, 14, 8, 19]
                ]
            );

            // simulate typing the search string
            findState.change({ searchString: "hello" }, true);
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [9, 14, 9, 19]
                ]
            );

            // simulate toggling on `wholeWord`
            findState.change({ wholeWord: true }, true);
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19]
                ]
            );

            // simulate toggling off `matchCase`
            findState.change({ matchCase: false }, true);
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            // simulate toggling off `wholeWord`
            findState.change({ wholeWord: false }, true);
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            // simulate adding a search scope
            findState.change({ searchScope: [new Range(8, 1, 10, 1)] }, true);
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            // simulate removing the search scope
            findState.change({ searchScope: null }, true);
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model removes its decorations')
     */
    function testFindModelRemovesItsDecorations() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertEquals(5, findState.matchesCount);
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );
        });
    }

    /**
     * findTest('find model updates state matchesCount')
     */
    function testFindModelUpdatesStateMatchesCount() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertEquals(5, findState.matchesCount);
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            findState.change({ searchString: "helloo" }, false);
            assertEquals(0, findState.matchesCount);
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model reacts to position change')
     */
    function testFindModelReactsToPositionChange() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            moveTo(editor, new Position(6, 20));

            assertFindState(
                editor,
                [6, 20, 6, 20],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            findState.change({ searchString: "Hello" }, true);
            assertFindState(
                editor,
                [6, 27, 6, 32],
                [6, 27, 6, 32],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model next')
     */
    function testFindModelNext() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [6, 27, 6, 32],
                [6, 27, 6, 32],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model next stays in scope')
     */
    function testFindModelNextStaysInScope() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", wholeWord: true, searchScope: [new Range(7, 1, 9, 1)] }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('multi-selection find model next stays in scope (overlap)')
     */
    function testMultiSelectionFindModelNextStaysInScopeOverlap() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", wholeWord: true, searchScope: [new Range(7, 1, 8, 2), new Range(8, 1, 9, 1)] }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('multi-selection find model next stays in scope')
     */
    function testMultiSelectionFindModelNextStaysInScope() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", matchCase: true, wholeWord: false, searchScope: [new Range(6, 1, 7, 38), new Range(9, 3, 9, 38)] }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    // `matchCase: false` would
                    // find this match as well:
                    // [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    // `wholeWord: true` would
                    // exclude this match:
                    [9, 14, 9, 19],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [9, 14, 9, 19],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [9, 14, 9, 19],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [9, 14, 9, 19],
                [9, 14, 9, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [9, 14, 9, 19],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [9, 14, 9, 19],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model prev')
     */
    function testFindModelPrev() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [6, 27, 6, 32],
                [6, 27, 6, 32],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model prev stays in scope')
     */
    function testFindModelPrevStaysInScope() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", wholeWord: true, searchScope: [new Range(7, 1, 9, 1)] }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model next/prev with no matches')
     */
    function testFindModelNextPrevWithNoMatches() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "helloo", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find model next/prev respects cursor position')
     */
    function testFindModelNextPrevRespectsCursorPosition() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            moveTo(editor, new Position(6, 20));
            assertFindState(
                editor,
                [6, 20, 6, 20],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [6, 27, 6, 32],
                [6, 27, 6, 32],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find ^')
     */
    function testFindCaret() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "^", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [1, 1, 1, 1],
                    [2, 1, 2, 1],
                    [3, 1, 3, 1],
                    [4, 1, 4, 1],
                    [5, 1, 5, 1],
                    [6, 1, 6, 1],
                    [7, 1, 7, 1],
                    [8, 1, 8, 1],
                    [9, 1, 9, 1],
                    [10, 1, 10, 1],
                    [11, 1, 11, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [2, 1, 2, 1],
                [2, 1, 2, 1],
                [
                    [1, 1, 1, 1],
                    [2, 1, 2, 1],
                    [3, 1, 3, 1],
                    [4, 1, 4, 1],
                    [5, 1, 5, 1],
                    [6, 1, 6, 1],
                    [7, 1, 7, 1],
                    [8, 1, 8, 1],
                    [9, 1, 9, 1],
                    [10, 1, 10, 1],
                    [11, 1, 11, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [3, 1, 3, 1],
                [3, 1, 3, 1],
                [
                    [1, 1, 1, 1],
                    [2, 1, 2, 1],
                    [3, 1, 3, 1],
                    [4, 1, 4, 1],
                    [5, 1, 5, 1],
                    [6, 1, 6, 1],
                    [7, 1, 7, 1],
                    [8, 1, 8, 1],
                    [9, 1, 9, 1],
                    [10, 1, 10, 1],
                    [11, 1, 11, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find $')
     */
    function testFindDollar() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "$", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [1, 18, 1, 18],
                    [2, 18, 2, 18],
                    [3, 20, 3, 20],
                    [4, 1, 4, 1],
                    [5, 13, 5, 13],
                    [6, 43, 6, 43],
                    [7, 41, 7, 41],
                    [8, 41, 8, 41],
                    [9, 40, 9, 40],
                    [10, 2, 10, 2],
                    [11, 17, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [1, 18, 1, 18],
                [1, 18, 1, 18],
                [
                    [1, 18, 1, 18],
                    [2, 18, 2, 18],
                    [3, 20, 3, 20],
                    [4, 1, 4, 1],
                    [5, 13, 5, 13],
                    [6, 43, 6, 43],
                    [7, 41, 7, 41],
                    [8, 41, 8, 41],
                    [9, 40, 9, 40],
                    [10, 2, 10, 2],
                    [11, 17, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [2, 18, 2, 18],
                [2, 18, 2, 18],
                [
                    [1, 18, 1, 18],
                    [2, 18, 2, 18],
                    [3, 20, 3, 20],
                    [4, 1, 4, 1],
                    [5, 13, 5, 13],
                    [6, 43, 6, 43],
                    [7, 41, 7, 41],
                    [8, 41, 8, 41],
                    [9, 40, 9, 40],
                    [10, 2, 10, 2],
                    [11, 17, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [3, 20, 3, 20],
                [3, 20, 3, 20],
                [
                    [1, 18, 1, 18],
                    [2, 18, 2, 18],
                    [3, 20, 3, 20],
                    [4, 1, 4, 1],
                    [5, 13, 5, 13],
                    [6, 43, 6, 43],
                    [7, 41, 7, 41],
                    [8, 41, 8, 41],
                    [9, 40, 9, 40],
                    [10, 2, 10, 2],
                    [11, 17, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find next ^$')
     */
    function testFindNextCaretDollar() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "^$", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [4, 1, 4, 1],
                [4, 1, 4, 1],
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [12, 1, 12, 1],
                [12, 1, 12, 1],
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [4, 1, 4, 1],
                [4, 1, 4, 1],
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find .*')
     */
    function testFindDotStar() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: ".*", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [1, 1, 1, 18],
                    [2, 1, 2, 18],
                    [3, 1, 3, 20],
                    [4, 1, 4, 1],
                    [5, 1, 5, 13],
                    [6, 1, 6, 43],
                    [7, 1, 7, 41],
                    [8, 1, 8, 41],
                    [9, 1, 9, 40],
                    [10, 1, 10, 2],
                    [11, 1, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find next ^.*$')
     */
    function testFindNextCaretDotStarDollar() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "^.*$", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [1, 1, 1, 18],
                    [2, 1, 2, 18],
                    [3, 1, 3, 20],
                    [4, 1, 4, 1],
                    [5, 1, 5, 13],
                    [6, 1, 6, 43],
                    [7, 1, 7, 41],
                    [8, 1, 8, 41],
                    [9, 1, 9, 40],
                    [10, 1, 10, 2],
                    [11, 1, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [1, 1, 1, 18],
                [1, 1, 1, 18],
                [
                    [1, 1, 1, 18],
                    [2, 1, 2, 18],
                    [3, 1, 3, 20],
                    [4, 1, 4, 1],
                    [5, 1, 5, 13],
                    [6, 1, 6, 43],
                    [7, 1, 7, 41],
                    [8, 1, 8, 41],
                    [9, 1, 9, 40],
                    [10, 1, 10, 2],
                    [11, 1, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [2, 1, 2, 18],
                [2, 1, 2, 18],
                [
                    [1, 1, 1, 18],
                    [2, 1, 2, 18],
                    [3, 1, 3, 20],
                    [4, 1, 4, 1],
                    [5, 1, 5, 13],
                    [6, 1, 6, 43],
                    [7, 1, 7, 41],
                    [8, 1, 8, 41],
                    [9, 1, 9, 40],
                    [10, 1, 10, 2],
                    [11, 1, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find prev ^.*$')
     */
    function testFindPrevCaretDotStarDollar() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "^.*$", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [1, 1, 1, 18],
                    [2, 1, 2, 18],
                    [3, 1, 3, 20],
                    [4, 1, 4, 1],
                    [5, 1, 5, 13],
                    [6, 1, 6, 43],
                    [7, 1, 7, 41],
                    [8, 1, 8, 41],
                    [9, 1, 9, 40],
                    [10, 1, 10, 2],
                    [11, 1, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [12, 1, 12, 1],
                [12, 1, 12, 1],
                [
                    [1, 1, 1, 18],
                    [2, 1, 2, 18],
                    [3, 1, 3, 20],
                    [4, 1, 4, 1],
                    [5, 1, 5, 13],
                    [6, 1, 6, 43],
                    [7, 1, 7, 41],
                    [8, 1, 8, 41],
                    [9, 1, 9, 40],
                    [10, 1, 10, 2],
                    [11, 1, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [11, 1, 11, 17],
                [11, 1, 11, 17],
                [
                    [1, 1, 1, 18],
                    [2, 1, 2, 18],
                    [3, 1, 3, 20],
                    [4, 1, 4, 1],
                    [5, 1, 5, 13],
                    [6, 1, 6, 43],
                    [7, 1, 7, 41],
                    [8, 1, 8, 41],
                    [9, 1, 9, 40],
                    [10, 1, 10, 2],
                    [11, 1, 11, 17],
                    [12, 1, 12, 1],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('find prev ^$')
     */
    function testFindPrevCaretDollar() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "^$", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [12, 1, 12, 1],
                [12, 1, 12, 1],
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [4, 1, 4, 1],
                [4, 1, 4, 1],
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.moveToPrevMatch();
            assertFindState(
                editor,
                [12, 1, 12, 1],
                [12, 1, 12, 1],
                [
                    [4, 1, 4, 1],
                    [12, 1, 12, 1],
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replace hello')
     */
    function testReplaceHello() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", replaceString: "hi", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            moveTo(editor, new Position(6, 20));
            assertFindState(
                editor,
                [6, 20, 6, 20],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hello world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [6, 27, 6, 32],
                [6, 27, 6, 32],
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hello world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hello world, hi!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [6, 14, 6, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(7));

            findModel.replace();
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19]
                ]
            );
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(8));

            findModel.replace();
            assertFindState(
                editor,
                [6, 16, 6, 16],
                null,
                []
            );
            assertEquals("    cout << \"hi world, hi!\" << endl;", editor.getModel().getLineContent(6));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replace bla')
     */
    function testReplaceBla() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "bla", replaceString: "ciao" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [11, 4, 11, 7],
                    [11, 7, 11, 10],
                    [11, 10, 11, 13]
                ]
            );

            findModel.replace();
            assertFindState(
                editor,
                [11, 4, 11, 7],
                [11, 4, 11, 7],
                [
                    [11, 4, 11, 7],
                    [11, 7, 11, 10],
                    [11, 10, 11, 13]
                ]
            );
            assertEquals("// blablablaciao", editor.getModel().getLineContent(11));

            findModel.replace();
            assertFindState(
                editor,
                [11, 8, 11, 11],
                [11, 8, 11, 11],
                [
                    [11, 8, 11, 11],
                    [11, 11, 11, 14]
                ]
            );
            assertEquals("// ciaoblablaciao", editor.getModel().getLineContent(11));

            findModel.replace();
            assertFindState(
                editor,
                [11, 12, 11, 15],
                [11, 12, 11, 15],
                [
                    [11, 12, 11, 15]
                ]
            );
            assertEquals("// ciaociaoblaciao", editor.getModel().getLineContent(11));

            findModel.replace();
            assertFindState(
                editor,
                [11, 16, 11, 16],
                null,
                []
            );
            assertEquals("// ciaociaociaociao", editor.getModel().getLineContent(11));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll hello')
     */
    function testReplaceAllHello() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", replaceString: "hi", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            moveTo(editor, new Position(6, 20));
            assertFindState(
                editor,
                [6, 20, 6, 20],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hello world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replaceAll();
            assertFindState(
                editor,
                [6, 17, 6, 17],
                null,
                []
            );
            assertEquals("    cout << \"hi world, hi!\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(7));
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(8));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll two spaces with one space')
     */
    function testReplaceAllTwoSpacesWithOneSpace() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "  ", replaceString: " " }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 1, 6, 3],
                    [6, 3, 6, 5],
                    [7, 1, 7, 3],
                    [7, 3, 7, 5],
                    [8, 1, 8, 3],
                    [8, 3, 8, 5],
                    [9, 1, 9, 3],
                    [9, 3, 9, 5]
                ]
            );

            findModel.replaceAll();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 1, 6, 3],
                    [7, 1, 7, 3],
                    [8, 1, 8, 3],
                    [9, 1, 9, 3]
                ]
            );
            assertEquals("  cout << \"hello world, Hello!\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("  cout << \"hello world again\" << endl;", editor.getModel().getLineContent(7));
            assertEquals("  cout << \"Hello world again\" << endl;", editor.getModel().getLineContent(8));
            assertEquals("  cout << \"helloworld again\" << endl;", editor.getModel().getLineContent(9));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll bla')
     */
    function testReplaceAllBla() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "bla", replaceString: "ciao" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [11, 4, 11, 7],
                    [11, 7, 11, 10],
                    [11, 10, 11, 13]
                ]
            );

            findModel.replaceAll();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );
            assertEquals("// ciaociaociaociao", editor.getModel().getLineContent(11));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll bla with \\t\\n')
     */
    function testReplaceAllBlaWithTN() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "bla", replaceString: "<\\n\\t>", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [11, 4, 11, 7],
                    [11, 7, 11, 10],
                    [11, 10, 11, 13]
                ]
            );

            findModel.replaceAll();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );
            assertEquals("// <", editor.getModel().getLineContent(11));
            assertEquals("\t><", editor.getModel().getLineContent(12));
            assertEquals("\t><", editor.getModel().getLineContent(13));
            assertEquals("\t>ciao", editor.getModel().getLineContent(14));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #3516: "replace all" moves page/cursor/focus/scroll to the place of the last replacement')
     */
    function testIssue3516ReplaceAllMovesPageCursorFocusScrollToThePlaceOfTheLastReplacement() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "include", replaceString: "bar" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [2, 2, 2, 9],
                    [3, 2, 3, 9]
                ]
            );

            findModel.replaceAll();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            assertEquals("#bar \"cool.h\"", editor.getModel().getLineContent(2));
            assertEquals("#bar <iostream>", editor.getModel().getLineContent(3));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('listens to model content changes')
     */
    function testListensToModelContentChanges() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", replaceString: "hi", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            editor.getModel().setValue("hello\nhi");
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('selectAllMatches')
     */
    function testSelectAllMatches() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", replaceString: "hi", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.selectAllMatches();

            assertDeepEquals([
                new Selection(6, 14, 6, 19).toString(),
                new Selection(6, 27, 6, 32).toString(),
                new Selection(7, 14, 7, 19).toString(),
                new Selection(8, 14, 8, 19).toString()
            ], [for (s in editor.getSelections()) s.toString()]);

            assertFindState(
                editor,
                [6, 14, 6, 19],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #14143 selectAllMatches should maintain primary cursor if feasible')
     */
    function testIssue14143SelectAllMatchesShouldMaintainPrimaryCursorIfFeasible() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", replaceString: "hi", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            editor.setSelection(new Range(7, 14, 7, 19));

            findModel.selectAllMatches();

            assertDeepEquals([
                new Selection(7, 14, 7, 19).toString(),
                new Selection(6, 14, 6, 19).toString(),
                new Selection(6, 27, 6, 32).toString(),
                new Selection(8, 14, 8, 19).toString()
            ], [for (s in editor.getSelections()) s.toString()]);

            assertDeepEquals(new Selection(7, 14, 7, 19).toString(), editor.getSelection().toString());

            assertFindState(
                editor,
                [7, 14, 7, 19],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #1914: NPE when there is only one find match')
     */
    function testIssue1914NPEWhenThereIsOnlyOneFindMatch() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "cool.h" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [2, 11, 2, 17]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [2, 11, 2, 17],
                [2, 11, 2, 17],
                [
                    [2, 11, 2, 17]
                ]
            );

            findModel.moveToNextMatch();
            assertFindState(
                editor,
                [2, 11, 2, 17],
                [2, 11, 2, 17],
                [
                    [2, 11, 2, 17]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replace when search string has look ahed regex')
     */
    function testReplaceWhenSearchStringHasLookAhedRegex() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello(?=\\sworld)", replaceString: "hi", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.replace();

            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hello world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hi world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(7));

            findModel.replace();
            assertFindState(
                editor,
                [8, 16, 8, 16],
                null,
                []
            );
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(8));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replace when search string has look ahed regex and cursor is at the last find match')
     */
    function testReplaceWhenSearchStringHasLookAhedRegexAndCursorIsAtTheLastFindMatch() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello(?=\\sworld)", replaceString: "hi", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            moveTo(editor, new Position(8, 14));

            assertFindState(
                editor,
                [8, 14, 8, 14],
                null,
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.replace();

            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            assertEquals("    cout << \"Hello world again\" << endl;", editor.getModel().getLineContent(8));

            findModel.replace();
            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                ]
            );
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(8));

            findModel.replace();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19]
                ]
            );
            assertEquals("    cout << \"hi world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [7, 16, 7, 16],
                null,
                []
            );
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(7));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll when search string has look ahed regex')
     */
    function testReplaceAllWhenSearchStringHasLookAhedRegex() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello(?=\\sworld)", replaceString: "hi", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.replaceAll();

            assertEquals("    cout << \"hi world, Hello!\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(7));
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(8));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replace when search string has look ahed regex and replace string has capturing groups')
     */
    function testReplaceWhenSearchStringHasLookAhedRegexAndReplaceStringHasCapturingGroups() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hel(lo)(?=\\sworld)", replaceString: "hi$1", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.replace();

            assertFindState(
                editor,
                [6, 14, 6, 19],
                [6, 14, 6, 19],
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hello world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [7, 14, 7, 19],
                [7, 14, 7, 19],
                [
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hilo world, Hello!\" << endl;", editor.getModel().getLineContent(6));

            findModel.replace();
            assertFindState(
                editor,
                [8, 14, 8, 19],
                [8, 14, 8, 19],
                [
                    [8, 14, 8, 19]
                ]
            );
            assertEquals("    cout << \"hilo world again\" << endl;", editor.getModel().getLineContent(7));

            findModel.replace();
            assertFindState(
                editor,
                [8, 18, 8, 18],
                null,
                []
            );
            assertEquals("    cout << \"hilo world again\" << endl;", editor.getModel().getLineContent(8));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll when search string has look ahed regex and replace string has capturing groups')
     */
    function testReplaceAllWhenSearchStringHasLookAhedRegexAndReplaceStringHasCapturingGroups() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "wo(rl)d(?=.*;$)", replaceString: "gi$1", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 20, 6, 25],
                    [7, 20, 7, 25],
                    [8, 20, 8, 25],
                    [9, 19, 9, 24]
                ]
            );

            findModel.replaceAll();

            assertEquals("    cout << \"hello girl, Hello!\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("    cout << \"hello girl again\" << endl;", editor.getModel().getLineContent(7));
            assertEquals("    cout << \"Hello girl again\" << endl;", editor.getModel().getLineContent(8));
            assertEquals("    cout << \"hellogirl again\" << endl;", editor.getModel().getLineContent(9));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll when search string is multiline and has look ahed regex and replace string has capturing groups')
     */
    function testReplaceAllWhenSearchStringIsMultilineAndHasLookAhedRegexAndReplaceStringHasCapturingGroups() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "wo(rl)d(.*;\\n)(?=.*hello)", replaceString: "gi$1$2", isRegex: true, matchCase: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 20, 7, 1],
                    [8, 20, 9, 1]
                ]
            );

            findModel.replaceAll();

            assertEquals("    cout << \"hello girl, Hello!\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("    cout << \"Hello girl again\" << endl;", editor.getModel().getLineContent(8));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('replaceAll preserving case')
     */
    function testReplaceAllPreservingCase() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", replaceString: "goodbye", isRegex: false, matchCase: false, preserveCase: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19],
                    [9, 14, 9, 19],
                ]
            );

            findModel.replaceAll();

            assertEquals("    cout << \"goodbye world, Goodbye!\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("    cout << \"goodbye world again\" << endl;", editor.getModel().getLineContent(7));
            assertEquals("    cout << \"Goodbye world again\" << endl;", editor.getModel().getLineContent(8));
            assertEquals("    cout << \"goodbyeworld again\" << endl;", editor.getModel().getLineContent(9));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #18711 replaceAll with empty string')
     */
    function testIssue18711ReplaceAllWithEmptyString() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", replaceString: "", wholeWord: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [6, 27, 6, 32],
                    [7, 14, 7, 19],
                    [8, 14, 8, 19]
                ]
            );

            findModel.replaceAll();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );
            assertEquals("    cout << \" world, !\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("    cout << \" world again\" << endl;", editor.getModel().getLineContent(7));
            assertEquals("    cout << \" world again\" << endl;", editor.getModel().getLineContent(8));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #32522 replaceAll with ^ on more than 1000 matches')
     */
    function testIssue32522ReplaceAllWithCaretOnMoreThan1000Matches() {
        findTest((editor) -> {
            var initialText = "";
            for (i in 0...1100) {
                initialText += "line" + i + "\n";
            }
            editor.getModel().setValue(initialText);
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "^", replaceString: "a ", isRegex: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            findModel.replaceAll();

            var expectedText = "";
            for (i in 0...1100) {
                expectedText += "a line" + i + "\n";
            }
            expectedText += "a ";
            assertEquals(expectedText, editor.getModel().getValue());

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #19740 Find and replace capture group/backreference inserts `undefined` instead of empty string')
     */
    function testIssue19740FindAndReplaceCaptureGroupBackreferenceInsertsUndefinedInsteadOfEmptyString() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello(z)?", replaceString: "hi$1", isRegex: true, matchCase: true }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [6, 14, 6, 19],
                    [7, 14, 7, 19],
                    [9, 14, 9, 19]
                ]
            );

            findModel.replaceAll();
            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                []
            );
            assertEquals("    cout << \"hi world, Hello!\" << endl;", editor.getModel().getLineContent(6));
            assertEquals("    cout << \"hi world again\" << endl;", editor.getModel().getLineContent(7));
            assertEquals("    cout << \"hiworld again\" << endl;", editor.getModel().getLineContent(9));

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #27083. search scope works even if it is a single line')
     */
    function testIssue27083SearchScopeWorksEvenIfItIsASingleLine() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", wholeWord: true, searchScope: [new Range(7, 1, 8, 1)] }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertFindState(
                editor,
                [1, 1, 1, 1],
                null,
                [
                    [7, 14, 7, 19]
                ]
            );

            findModel.dispose();
            findState.dispose();
        });
    }

    /**
     * findTest('issue #3516: Control behavior of "Next" operations (not looping back to beginning)')
     */
    function testIssue3516ControlBehaviorOfNextOperationsNotLoopingBackToBeginning() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello", loop: false }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertEquals(5, findState.matchesCount);

            // Test next operations
            assertEquals(0, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(false, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(2, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(3, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(4, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(5, findState.matchesPosition);
            assertEquals(false, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(5, findState.matchesPosition);
            assertEquals(false, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(5, findState.matchesPosition);
            assertEquals(false, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            // Test previous operations
            findModel.moveToPrevMatch();
            assertEquals(4, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(3, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(2, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(false, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(false, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(false, findState.canNavigateBack());

        });
    }

    /**
     * findTest('issue #3516: Control behavior of "Next" operations (looping back to beginning)')
     */
    function testIssue3516ControlBehaviorOfNextOperationsLoopingBackToBeginning() {
        findTest((editor) -> {
            final findState = disposables.add(new FindReplaceState());
            findState.change({ searchString: "hello" }, false);
            final findModel = disposables.add(new FindModelBoundToEditorModel(editor, findState));

            assertEquals(5, findState.matchesCount);

            // Test next operations
            assertEquals(0, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(2, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(3, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(4, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(5, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToNextMatch();
            assertEquals(2, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            // Test previous operations
            findModel.moveToPrevMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(5, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(4, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(3, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(2, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

            findModel.moveToPrevMatch();
            assertEquals(1, findState.matchesPosition);
            assertEquals(true, findState.canNavigateForward());
            assertEquals(true, findState.canNavigateBack());

        });
    }

}
