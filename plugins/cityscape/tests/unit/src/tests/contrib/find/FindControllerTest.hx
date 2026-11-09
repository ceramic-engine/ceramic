// Ported from vscode src/vs/editor/contrib/find/test/browser/findController.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.find;

import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.find.view.FindController;
import cityscape.contrib.find.view.FindState;
import cityscape.platform.storage.common.Storage;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;
import cityscape.Cityscape;
import cityscape.contrib.find.view.FindModel;
import cityscape.view.EditorExtensions.EditorContributionInstantiation;

class TestFindController extends CommonFindController {

    public var hasFocus:Bool;

    final _findInputFocused:cityscape.platform.contextkey.common.ContextKey.IContextKey<Bool>;

    public function new(editor:cityscape.view.EditorBrowser.ICodeEditor, storageService:IStorageService) {
        super(editor, storageService);
        this._findInputFocused = FindModel.CONTEXT_FIND_INPUT_FOCUSED.bindTo(editor.contextKeyService);
        this.hasFocus = false;
    }

    override function _start(opts:IFindStartOptions, ?newState:INewFindReplaceState):Void {
        super._start(opts, newState);

        if (opts.shouldFocus != FindStartFocusAction.NoFocusChange) {
            this.hasFocus = true;
        }

        final inputFocused = opts.shouldFocus == FindStartFocusAction.FocusFindInput;
        this._findInputFocused.set(inputFocused);
    }

}

/**
 * suite('FindController') and suite('FindController query options
 * persistence').
 *
 * vscode's suites share one storage service between their tests and run
 * them in order: options toggled by a test are read by the next ones (the
 * query options are kept in the storage). The runner here runs each test
 * alone, in name order: each test starts with the storage its suite has
 * when vscode runs it (`storageBefore`).
 *
 * The three tests of the global find clipboard are commented out in vscode
 * (and the clipboard is not ported). The editors are synchronous here
 * (`withAsyncTestCodeEditor` is `withTestCodeEditor`, the actions return
 * when done). `MoveToMatchFindAction` (a quick input) is not ported.
 */
class FindControllerTest extends TestCase {

    static function fromSelection(slc:Selection):Array<Int> {
        return [slc.startLineNumber, slc.startColumn, slc.endLineNumber, slc.endColumn];
    }

    static function scopeStrings(scope:Null<Array<Range>>):Null<Array<String>> {
        return scope == null ? null : [for (r in scope) r.toString()];
    }

    /**
     * The storage of the suite before a test, as vscode's suites leave it
     * when they run their tests in order.
     */
    static function storageBefore(values:Null<Map<String, Bool>>):InMemoryStorageService {
        final storage = new InMemoryStorageService();
        if (values == null) {
            return storage;
        }
        for (key => value in values) {
            storage.store(key, value, StorageScope.WORKSPACE, StorageTarget.USER);
        }
        return storage;
    }

    /**
     * vscode's `withAsyncTestCodeEditor` and
     * `editor.registerAndInstantiateContribution(TestFindController.ID, TestFindController)`:
     * the test editor with a `TestFindController` reading `storageService`.
     */
    static function withEditor(text:Array<String>, options:IEditorOptions, storageService:IStorageService, callback:(editor:TestCodeEditor) -> Void):Void {
        final context = new Cityscape();
        final model = TestTextModel.instantiateTextModel(context, text.join('\n'));
        final editor = new TestCodeEditor(context, model, options, [{
            id: CommonFindController.ID,
            ctor: e -> new TestFindController(e, storageService),
            instantiation: EditorContributionInstantiation.Eager
        }]);
        editor.getViewModel().setHasFocus(true);
        try {
            callback(editor);
        }
        catch (e:Dynamic) {
            editor.dispose();
            model.dispose();
            throw e;
        }
        editor.dispose();
        model.dispose();
    }

    // suite('FindController')

    function testIssue1857F3FindNextActsLikeFindUnderCursor() {
        withEditor([
            'ABC',
            'ABC',
            'XYZ',
            'ABC'
        ], {}, storageBefore(null), (editor) -> {
            // The cursor is at the very top, of the file, at the first ABC
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final findState = findController.getState();
            final nextMatchFindAction = new NextMatchFindAction(editor.context.editorExtensions);

            // I hit Ctrl+F to show the Find dialog
            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            // I type ABC.
            findState.change({searchString: 'A'}, true);
            findState.change({searchString: 'AB'}, true);
            findState.change({searchString: 'ABC'}, true);

            // The first ABC is highlighted.
            assertDeepEquals([1, 1, 1, 4], fromSelection(editor.getSelection()));

            // I hit Esc to exit the Find dialog.
            findController.closeFindWidget();
            findController.hasFocus = false;

            // The cursor is now at end of the first line, with ABC on that line highlighted.
            assertDeepEquals([1, 1, 1, 4], fromSelection(editor.getSelection()));

            // I hit delete to remove it and change the text to XYZ.
            editor.pushUndoStop();
            editor.executeEdits('test', [EditOperation.delete(new Range(1, 1, 1, 4))]);
            editor.executeEdits('test', [EditOperation.insert(new Position(1, 1), 'XYZ')]);
            editor.pushUndoStop();

            // At this point the text editor looks like this:
            //   XYZ
            //   ABC
            //   XYZ
            //   ABC
            assertEquals('XYZ', editor.getModel().getLineContent(1));

            // The cursor is at end of the first line.
            assertDeepEquals([1, 4, 1, 4], fromSelection(editor.getSelection()));

            // I hit F3 to "Find Next" to find the next occurrence of ABC, but instead it searches for XYZ.
            nextMatchFindAction.run(editor.context, editor, null);

            assertEquals('ABC', findState.searchString);
            assertEquals(false, findController.hasFocus);

            findController.dispose();
        });
    }

    function testIssue3090F3DoesNotLoopWithTwoMatchesOnASingleLine() {
        withEditor([
            'import nls = require(\'vs/nls\');'
        ], {}, storageBefore(null), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final nextMatchFindAction = new NextMatchFindAction(editor.context.editorExtensions);

            editor.setPosition({
                lineNumber: 1,
                column: 9
            });

            nextMatchFindAction.run(editor.context, editor, null);
            assertDeepEquals([1, 26, 1, 29], fromSelection(editor.getSelection()));

            nextMatchFindAction.run(editor.context, editor, null);
            assertDeepEquals([1, 8, 1, 11], fromSelection(editor.getSelection()));

            findController.dispose();
        });
    }

    function testIssue6149AutoEscapeHighlightedTextForSearchAndReplaceRegexMode() {
        withEditor([
            'var x = (3 * 5)',
            'var y = (3 * 5)',
            'var z = (3  * 5)',
        ], {}, storageBefore(null), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final nextMatchFindAction = new NextMatchFindAction(editor.context.editorExtensions);

            editor.setSelection(new Selection(1, 9, 1, 13));

            findController.toggleRegex();
            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            nextMatchFindAction.run(editor.context, editor, null);
            assertDeepEquals([2, 9, 2, 13], fromSelection(editor.getSelection()));

            nextMatchFindAction.run(editor.context, editor, null);
            assertDeepEquals([1, 9, 1, 13], fromSelection(editor.getSelection()));

            findController.dispose();
        });
    }

    function testIssue41027DontReplaceFindInputValueOnReplaceActionIfFindInputIsActive() {
        withEditor([
            'test',
        ], {}, storageBefore(['editor.isRegex' => true]), (editor) -> {
            final testRegexString = 'tes.';
            // the previous test of the suite left `isRegex` on
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final nextMatchFindAction = new NextMatchFindAction(editor.context.editorExtensions);

            findController.toggleRegex();
            findController.setSearchString(testRegexString);
            findController.start({
                forceRevealReplace: false,
                seedSearchStringFromSelection: 'none',
                seedSearchStringFromNonEmptySelection: false,
                seedSearchStringFromGlobalClipboard: false,
                shouldFocus: FindStartFocusAction.FocusFindInput,
                shouldAnimate: false,
                updateSearchScope: false,
                loop: true
            });
            nextMatchFindAction.run(editor.context, editor, null);
            new StartFindReplaceAction(editor.context.editorExtensions).run(editor.context, editor, null);

            assertEquals(testRegexString, findController.getState().searchString);

            findController.dispose();
        });
    }

    function testIssue9043ClearSearchScopeWhenFindWidgetIsHidden() {
        withEditor([
            'var x = (3 * 5)',
            'var y = (3 * 5)',
            'var z = (3 * 5)',
        ], {}, storageBefore(null), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            findController.start({
                forceRevealReplace: false,
                seedSearchStringFromSelection: 'none',
                seedSearchStringFromNonEmptySelection: false,
                seedSearchStringFromGlobalClipboard: false,
                shouldFocus: FindStartFocusAction.NoFocusChange,
                shouldAnimate: false,
                updateSearchScope: false,
                loop: true
            });

            assertEquals(null, findController.getState().searchScope);

            findController.getState().change({
                searchScope: [new Range(1, 1, 1, 5)]
            }, false);

            assertDeepEquals(scopeStrings([new Range(1, 1, 1, 5)]), scopeStrings(findController.getState().searchScope));

            findController.closeFindWidget();
            assertEquals(null, findController.getState().searchScope);
            findController.dispose();
        });
    }

    function testIssue18111RegexReplaceWithSingleSpaceReplacesWithNoSpace() {
        withEditor([
            'HRESULT OnAmbientPropertyChange(DISPID   dispid);'
        ], {}, storageBefore(null), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);

            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            findController.getState().change({searchString: '\\b\\s{3}\\b', replaceString: ' ', isRegex: true}, false);
            findController.moveToNextMatch();

            assertDeepEquals([
                [1, 39, 1, 42]
            ], [for (s in editor.getSelections()) fromSelection(s)]);

            findController.replace();

            assertEquals('HRESULT OnAmbientPropertyChange(DISPID dispid);', editor.getValue());

            findController.dispose();
        });
    }

    function testIssue24714RegularExpressionWithCaretInSearchReplace() {
        withEditor([
            '',
            'line2',
            'line3'
        ], {}, storageBefore(['editor.isRegex' => true]), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);

            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            findController.getState().change({searchString: '^', replaceString: 'x', isRegex: true}, false);
            findController.moveToNextMatch();

            assertDeepEquals([
                [2, 1, 2, 1]
            ], [for (s in editor.getSelections()) fromSelection(s)]);

            findController.replace();

            assertEquals('\nxline2\nline3', editor.getValue());

            findController.dispose();
        });
    }

    function testIssue38232FindNextSelectionRegexEnabled() {
        withEditor([
            '([funny]',
            '',
            '([funny]'
        ], {}, storageBefore(['editor.isRegex' => true]), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final nextSelectionMatchFindAction = new NextSelectionMatchFindAction(editor.context.editorExtensions);

            // toggle regex
            findController.getState().change({isRegex: true}, false);

            // change selection
            editor.setSelection(new Selection(1, 1, 1, 9));

            // cmd+f3
            nextSelectionMatchFindAction.run(editor.context, editor, null);

            assertDeepEquals([
                [3, 1, 3, 9]
            ], [for (s in editor.getSelections()) fromSelection(s)]);

            findController.dispose();
        });
    }

    function testIssue38232FindNextSelectionRegexEnabledFindWidgetOpen() {
        withEditor([
            '([funny]',
            '',
            '([funny]'
        ], {}, storageBefore(['editor.isRegex' => true]), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final nextSelectionMatchFindAction = new NextSelectionMatchFindAction(editor.context.editorExtensions);

            // cmd+f - open find widget
            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            // toggle regex
            findController.getState().change({isRegex: true}, false);

            // change selection
            editor.setSelection(new Selection(1, 1, 1, 9));

            // cmd+f3
            nextSelectionMatchFindAction.run(editor.context, editor, null);

            assertDeepEquals([
                [3, 1, 3, 9]
            ], [for (s in editor.getSelections()) fromSelection(s)]);

            findController.dispose();
        });
    }

    function testIssue47400CMDESupportsFeedingMultipleLineOfTextIntoTheFindWidget() {
        withEditor([
            'ABC',
            'ABC',
            'XYZ',
            'ABC',
            'ABC'
        ], {}, storageBefore(['editor.isRegex' => true]), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);

            // change selection
            editor.setSelection(new Selection(1, 1, 1, 1));

            // cmd+f - open find widget
            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            editor.setSelection(new Selection(1, 1, 2, 4));
            final startFindWithSelectionAction = new StartFindWithSelectionAction(editor.context.editorExtensions);
            startFindWithSelectionAction.run(editor.context, editor, null);
            final findState = findController.getState();

            assertDeepEquals(['ABC', 'ABC'], ~/\r\n|\r|\n/g.split(findState.searchString));

            editor.setSelection(new Selection(3, 1, 3, 1));
            startFindWithSelectionAction.run(editor.context, editor, null);

            findController.dispose();
        });
    }

    function testIssue109756CMDEWithEmptyCursorShouldAlwaysWork() {
        withEditor([
            'ABC',
            'ABC',
            'XYZ',
            'ABC',
            'ABC'
        ], {}, storageBefore(['editor.isRegex' => true]), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            editor.setSelection(new Selection(1, 2, 1, 2));

            final startFindWithSelectionAction = new StartFindWithSelectionAction(editor.context.editorExtensions);
            startFindWithSelectionAction.run(editor.context, editor, null);

            final findState = findController.getState();
            assertDeepEquals('ABC', findState.searchString);
            findController.dispose();
        });
    }

    // suite('FindController query options persistence')

    /**
     * The storage of the second suite: `isRegex`, `matchCase` and
     * `wholeWord` stored false, then `matchCase` false and `wholeWord` true
     * (the suite body runs before its tests), then what the earlier tests
     * stored.
     */
    static function matchCaseStorage():InMemoryStorageService {
        final storageService = persistenceStorage(null);
        storageService.store('editor.matchCase', true, StorageScope.WORKSPACE, StorageTarget.USER);
        return storageService;
    }

    static function persistenceStorage(extra:Null<Map<String, Bool>>):InMemoryStorageService {
        final storage = storageBefore(['editor.isRegex' => false, 'editor.matchCase' => false, 'editor.wholeWord' => true]);
        if (extra == null) {
            return storage;
        }
        for (key => value in extra) {
            storage.store(key, value, StorageScope.WORKSPACE, StorageTarget.USER);
        }
        return storage;
    }

    function testPersistenceMatchCase() {
        withEditor([
            'abc',
            'ABC',
            'XYZ',
            'ABC'
        ], {}, matchCaseStorage(), (editor) -> {
            // storageService.store('editor.matchCase', true) before the controller is created (matchCaseStorage)
            // The cursor is at the very top, of the file, at the first ABC
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final findState = findController.getState();

            // I hit Ctrl+F to show the Find dialog
            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            // I type ABC.
            findState.change({searchString: 'ABC'}, true);
            // The second ABC is highlighted as matchCase is true.
            assertDeepEquals([2, 1, 2, 4], fromSelection(editor.getSelection()));

            findController.dispose();
        });
    }

    function testPersistenceWholeWord() {
        withEditor([
            'ABC',
            'AB',
            'XYZ',
            'ABC'
        ], {}, persistenceStorage(['editor.matchCase' => true]), (editor) -> {
            // The cursor is at the very top, of the file, at the first ABC
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final findState = findController.getState();

            // I hit Ctrl+F to show the Find dialog
            new StartFindAction(editor.context.editorExtensions).run(editor.context, editor, null);

            // I type AB.
            findState.change({searchString: 'AB'}, true);
            // The second AB is highlighted as wholeWord is true.
            assertDeepEquals([2, 1, 2, 3], fromSelection(editor.getSelection()));

            findController.dispose();
        });
    }

    function testPersistenceTogglingOptionsIsSaved() {
        withEditor([
            'ABC',
            'AB',
            'XYZ',
            'ABC'
        ], {}, persistenceStorage(['editor.matchCase' => true]), (editor) -> {
            final storageService = @:privateAccess (editor.getContribution(CommonFindController.ID) : TestFindController)._storageService;
            // The cursor is at the very top, of the file, at the first ABC
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            findController.toggleRegex();
            assertEquals(true, storageService.getBoolean('editor.isRegex', StorageScope.WORKSPACE));

            findController.dispose();
        });
    }

    function testPersistenceIssue27083UpdateSearchScopeOnceFindWidgetBecomesVisible() {
        withEditor([
            'var x = (3 * 5)',
            'var y = (3 * 5)',
            'var z = (3 * 5)',
        ], {find: {autoFindInSelection: 'always', globalFindClipboard: false}}, persistenceStorage(['editor.matchCase' => true, 'editor.isRegex' => true]), (editor) -> {
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);
            final findConfig:IFindStartOptions = {
                forceRevealReplace: false,
                seedSearchStringFromSelection: 'none',
                seedSearchStringFromNonEmptySelection: false,
                seedSearchStringFromGlobalClipboard: false,
                shouldFocus: FindStartFocusAction.NoFocusChange,
                shouldAnimate: false,
                updateSearchScope: true,
                loop: true
            };

            editor.setSelection(new Range(1, 1, 2, 1));
            findController.start(findConfig);
            assertDeepEquals(scopeStrings([new Selection(1, 1, 2, 1)]), scopeStrings(findController.getState().searchScope));

            findController.closeFindWidget();

            editor.setSelections([new Selection(1, 1, 2, 1), new Selection(2, 1, 2, 5)]);
            findController.start(findConfig);
            assertDeepEquals(scopeStrings([new Selection(1, 1, 2, 1), new Selection(2, 1, 2, 5)]), scopeStrings(findController.getState().searchScope));
            findController.dispose();
        });
    }

    function testPersistenceIssue58604DoNotUpdateSearchScopeIfItIsEmpty() {
        withEditor([
            'var x = (3 * 5)',
            'var y = (3 * 5)',
            'var z = (3 * 5)',
        ], {find: {autoFindInSelection: 'always', globalFindClipboard: false}}, persistenceStorage(['editor.matchCase' => true, 'editor.isRegex' => true]), (editor) -> {
            editor.setSelection(new Range(1, 2, 1, 2));
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);

            findController.start({
                forceRevealReplace: false,
                seedSearchStringFromSelection: 'none',
                seedSearchStringFromNonEmptySelection: false,
                seedSearchStringFromGlobalClipboard: false,
                shouldFocus: FindStartFocusAction.NoFocusChange,
                shouldAnimate: false,
                updateSearchScope: true,
                loop: true
            });

            assertEquals(null, findController.getState().searchScope);
            findController.dispose();
        });
    }

    function testPersistenceIssue58604UpdateSearchScopeIfItIsNotEmpty() {
        withEditor([
            'var x = (3 * 5)',
            'var y = (3 * 5)',
            'var z = (3 * 5)',
        ], {find: {autoFindInSelection: 'always', globalFindClipboard: false}}, persistenceStorage(['editor.matchCase' => true, 'editor.isRegex' => true]), (editor) -> {
            editor.setSelection(new Range(1, 2, 1, 3));
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);

            findController.start({
                forceRevealReplace: false,
                seedSearchStringFromSelection: 'none',
                seedSearchStringFromNonEmptySelection: false,
                seedSearchStringFromGlobalClipboard: false,
                shouldFocus: FindStartFocusAction.NoFocusChange,
                shouldAnimate: false,
                updateSearchScope: true,
                loop: true
            });

            assertDeepEquals(scopeStrings([new Selection(1, 2, 1, 3)]), scopeStrings(findController.getState().searchScope));
            findController.dispose();
        });
    }

    function testPersistenceIssue27083FindInSelectionWhenMultipleLinesAreSelected() {
        withEditor([
            'var x = (3 * 5)',
            'var y = (3 * 5)',
            'var z = (3 * 5)',
        ], {find: {autoFindInSelection: 'multiline', globalFindClipboard: false}}, persistenceStorage(['editor.matchCase' => true, 'editor.isRegex' => true]), (editor) -> {
            editor.setSelection(new Range(1, 6, 2, 1));
            final findController:TestFindController = editor.getContribution(CommonFindController.ID);

            findController.start({
                forceRevealReplace: false,
                seedSearchStringFromSelection: 'none',
                seedSearchStringFromNonEmptySelection: false,
                seedSearchStringFromGlobalClipboard: false,
                shouldFocus: FindStartFocusAction.NoFocusChange,
                shouldAnimate: false,
                updateSearchScope: true,
                loop: true
            });

            assertDeepEquals(scopeStrings([new Selection(1, 6, 2, 1)]), scopeStrings(findController.getState().searchScope));
            findController.dispose();
        });
    }

}
