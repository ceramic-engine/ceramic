// Ported from vscode src/vs/editor/contrib/multicursor/browser/multicursor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.multicursor.view;

import cityscape.Cityscape;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.base.common.Lifecycle;
import cityscape.common.CursorCommon.CursorState;
import cityscape.common.CursorCommon.PartialCursorState;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon;
import cityscape.common.EditorContextKeys;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.CursorMoveCommands;
import cityscape.contrib.find.view.FindController;
import cityscape.contrib.find.view.FindState;
import cityscape.contrib.wordHighlighter.view.HighlightDecorations;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * Not ported: `announceCursorChange` (an aria status message for screen
 * readers; Cityscape has no accessibility support yet).
 */

class InsertCursorAbove extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.insertCursorAbove',
            label: r != null ? r.localize('mutlicursor.insertAbove', "Add Cursor Above") : "Add Cursor Above",
            alias: 'Add Cursor Above',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.UpArrow,
                linux: {
                    primary: KeyMod.Shift | KeyMod.Alt | KeyCode.UpArrow,
                    secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.UpArrow]
                },
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '3_multi',
                title: r != null ? r.localize('miInsertCursorAbove', "&&Add Cursor Above") : "&&Add Cursor Above",
                order: 2
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        var useLogicalLine = true;
        if (JsValues.truthy(args) && JsValues.strictEquals(JsValues.field(args, 'logicalLine'), false)) {
            useLogicalLine = false;
        }
        final viewModel = editor._getViewModel();

        if (viewModel.cursorConfig.readOnly) {
            return;
        }

        final source:Null<String> = JsValues.field(args, 'source');
        viewModel.model.pushStackElement();
        final previousCursorState = viewModel.getCursorStates();
        viewModel.setCursorStates(
            source,
            CursorChangeReason.Explicit,
            CursorMoveCommands.addCursorUp(viewModel, previousCursorState, useLogicalLine)
        );
        viewModel.revealTopMostCursor(source);
    }

}

class InsertCursorBelow extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.insertCursorBelow',
            label: r != null ? r.localize('mutlicursor.insertBelow', "Add Cursor Below") : "Add Cursor Below",
            alias: 'Add Cursor Below',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.DownArrow,
                linux: {
                    primary: KeyMod.Shift | KeyMod.Alt | KeyCode.DownArrow,
                    secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.DownArrow]
                },
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '3_multi',
                title: r != null ? r.localize('miInsertCursorBelow', "A&&dd Cursor Below") : "A&&dd Cursor Below",
                order: 3
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        var useLogicalLine = true;
        if (JsValues.truthy(args) && JsValues.strictEquals(JsValues.field(args, 'logicalLine'), false)) {
            useLogicalLine = false;
        }
        final viewModel = editor._getViewModel();

        if (viewModel.cursorConfig.readOnly) {
            return;
        }

        final source:Null<String> = JsValues.field(args, 'source');
        viewModel.model.pushStackElement();
        final previousCursorState = viewModel.getCursorStates();
        viewModel.setCursorStates(
            source,
            CursorChangeReason.Explicit,
            CursorMoveCommands.addCursorDown(viewModel, previousCursorState, useLogicalLine)
        );
        viewModel.revealBottomMostCursor(source);
    }

}

class InsertCursorAtEndOfEachLineSelected extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.insertCursorAtEndOfEachLineSelected',
            label: r != null ? r.localize('mutlicursor.insertAtEndOfEachLineSelected', "Add Cursors to Line Ends") : "Add Cursors to Line Ends",
            alias: 'Add Cursors to Line Ends',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Shift | KeyMod.Alt | KeyCode.KeyI,
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '3_multi',
                title: r != null ? r.localize('miInsertCursorAtEndOfEachLineSelected', "Add C&&ursors to Line Ends") : "Add C&&ursors to Line Ends",
                order: 4
            }
        });
    }

    function getCursorsForSelection(selection:Selection, model:ITextModel, result:Array<Selection>):Void {
        if (selection.isEmpty()) {
            return;
        }

        for (i in selection.startLineNumber...selection.endLineNumber) {
            final currentLineMaxColumn = model.getLineMaxColumn(i);
            result.push(new Selection(i, currentLineMaxColumn, i, currentLineMaxColumn));
        }
        if (selection.endColumn > 1) {
            result.push(new Selection(selection.endLineNumber, selection.endColumn, selection.endLineNumber, selection.endColumn));
        }
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final model = editor.getModel();
        final selections = editor.getSelections();
        final newSelections:Array<Selection> = [];
        for (sel in selections) {
            this.getCursorsForSelection(sel, model, newSelections);
        }

        if (newSelections.length > 0) {
            editor.setSelections(cast newSelections);
        }
    }

}

class InsertCursorAtEndOfLineSelected extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.addCursorsToBottom',
            label: r != null ? r.localize('mutlicursor.addCursorsToBottom', "Add Cursors To Bottom") : "Add Cursors To Bottom",
            alias: 'Add Cursors To Bottom',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final selections = editor.getSelections();
        final lineCount = editor.getModel().getLineCount();

        final newSelections:Array<Selection> = [];
        for (i in selections[0].startLineNumber...lineCount + 1) {
            newSelections.push(new Selection(i, selections[0].startColumn, i, selections[0].endColumn));
        }

        if (newSelections.length > 0) {
            editor.setSelections(cast newSelections);
        }
    }

}

class InsertCursorAtTopOfLineSelected extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.addCursorsToTop',
            label: r != null ? r.localize('mutlicursor.addCursorsToTop', "Add Cursors To Top") : "Add Cursors To Top",
            alias: 'Add Cursors To Top',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final selections = editor.getSelections();

        final newSelections:Array<Selection> = [];
        var i = selections[0].startLineNumber;
        while (i >= 1) {
            newSelections.push(new Selection(i, selections[0].startColumn, i, selections[0].endColumn));
            i--;
        }

        if (newSelections.length > 0) {
            editor.setSelections(cast newSelections);
        }
    }

}

class MultiCursorSessionResult {

    public final selections:Array<Selection>;
    public final revealRange:Range;
    public final revealScrollType:ScrollType;

    public function new(selections:Array<Selection>, revealRange:Range, revealScrollType:ScrollType) {
        this.selections = selections;
        this.revealRange = revealRange;
        this.revealScrollType = revealScrollType;
    }

}

class MultiCursorSession {

    public static function create(editor:ICodeEditor, findController:CommonFindController):Null<MultiCursorSession> {
        if (!editor.hasModel()) {
            return null;
        }
        final findState = findController.getState();

        // Find widget owns entirely what we search for if:
        //  - focus is not in the editor (i.e. it is in the find widget)
        //  - and the search widget is visible
        //  - and the search string is non-empty
        if (!editor.hasTextFocus() && findState.isRevealed && findState.searchString.length > 0) {
            // Find widget owns what is searched for
            return new MultiCursorSession(editor, findController, false, findState.searchString, findState.wholeWord, findState.matchCase, null);
        }

        // Otherwise, the selection gives the search text, and the find widget gives the search settings
        // The exception is the find state disassociation case: when beginning with a single, collapsed selection
        var isDisconnectedFromFindController = false;
        var wholeWord:Bool;
        var matchCase:Bool;
        final selections = editor.getSelections();
        if (selections.length == 1 && selections[0].isEmpty()) {
            isDisconnectedFromFindController = true;
            wholeWord = true;
            matchCase = true;
        }
        else {
            wholeWord = findState.wholeWord;
            matchCase = findState.matchCase;
        }

        // Selection owns what is searched for
        final s = editor.getSelection();

        var searchText:String;
        var currentMatch:Null<Selection> = null;

        if (s.isEmpty()) {
            // selection is empty => expand to current word
            final word = editor.getConfiguredWordAtPosition(s.getStartPosition());
            if (word == null) {
                return null;
            }
            searchText = word.word;
            currentMatch = new Selection(s.startLineNumber, word.startColumn, s.startLineNumber, word.endColumn);
        }
        else {
            searchText = StringTools.replace(editor.getModel().getValueInRange(s), '\r\n', '\n');
        }

        return new MultiCursorSession(editor, findController, isDisconnectedFromFindController, searchText, wholeWord, matchCase, currentMatch);
    }

    final _editor:ICodeEditor;
    public final findController:CommonFindController;
    public final isDisconnectedFromFindController:Bool;
    public final searchText:String;
    public final wholeWord:Bool;
    public final matchCase:Bool;
    public var currentMatch:Null<Selection>;

    public function new(editor:ICodeEditor, findController:CommonFindController, isDisconnectedFromFindController:Bool, searchText:String, wholeWord:Bool, matchCase:Bool, currentMatch:Null<Selection>) {
        this._editor = editor;
        this.findController = findController;
        this.isDisconnectedFromFindController = isDisconnectedFromFindController;
        this.searchText = searchText;
        this.wholeWord = wholeWord;
        this.matchCase = matchCase;
        this.currentMatch = currentMatch;
    }

    public function addSelectionToNextFindMatch():Null<MultiCursorSessionResult> {
        if (!this._editor.hasModel()) {
            return null;
        }

        final nextMatch = this._getNextMatch();
        if (nextMatch == null) {
            return null;
        }

        final allSelections = this._editor.getSelections();
        return new MultiCursorSessionResult(allSelections.concat([nextMatch]), nextMatch, ScrollType.Smooth);
    }

    public function moveSelectionToNextFindMatch():Null<MultiCursorSessionResult> {
        if (!this._editor.hasModel()) {
            return null;
        }

        final nextMatch = this._getNextMatch();
        if (nextMatch == null) {
            return null;
        }

        final allSelections = this._editor.getSelections();
        return new MultiCursorSessionResult(allSelections.slice(0, allSelections.length - 1).concat([nextMatch]), nextMatch, ScrollType.Smooth);
    }

    function _getNextMatch():Null<Selection> {
        if (!this._editor.hasModel()) {
            return null;
        }

        if (this.currentMatch != null) {
            final result = this.currentMatch;
            this.currentMatch = null;
            return result;
        }

        this.findController.highlightFindOptions();

        final allSelections = this._editor.getSelections();
        final lastAddedSelection = allSelections[allSelections.length - 1];
        final nextMatch = this._editor.getModel().findNextMatch(this.searchText, lastAddedSelection.getEndPosition(), false, this.matchCase, this.wholeWord ? this._editor.getOption(EditorOption.wordSeparators) : null, false);

        if (nextMatch == null) {
            return null;
        }
        return new Selection(nextMatch.range.startLineNumber, nextMatch.range.startColumn, nextMatch.range.endLineNumber, nextMatch.range.endColumn);
    }

    public function addSelectionToPreviousFindMatch():Null<MultiCursorSessionResult> {
        if (!this._editor.hasModel()) {
            return null;
        }

        final previousMatch = this._getPreviousMatch();
        if (previousMatch == null) {
            return null;
        }

        final allSelections = this._editor.getSelections();
        return new MultiCursorSessionResult(allSelections.concat([previousMatch]), previousMatch, ScrollType.Smooth);
    }

    public function moveSelectionToPreviousFindMatch():Null<MultiCursorSessionResult> {
        if (!this._editor.hasModel()) {
            return null;
        }

        final previousMatch = this._getPreviousMatch();
        if (previousMatch == null) {
            return null;
        }

        final allSelections = this._editor.getSelections();
        return new MultiCursorSessionResult(allSelections.slice(0, allSelections.length - 1).concat([previousMatch]), previousMatch, ScrollType.Smooth);
    }

    function _getPreviousMatch():Null<Selection> {
        if (!this._editor.hasModel()) {
            return null;
        }

        if (this.currentMatch != null) {
            final result = this.currentMatch;
            this.currentMatch = null;
            return result;
        }

        this.findController.highlightFindOptions();

        final allSelections = this._editor.getSelections();
        final lastAddedSelection = allSelections[allSelections.length - 1];
        final previousMatch = this._editor.getModel().findPreviousMatch(this.searchText, lastAddedSelection.getStartPosition(), false, this.matchCase, this.wholeWord ? this._editor.getOption(EditorOption.wordSeparators) : null, false);

        if (previousMatch == null) {
            return null;
        }
        return new Selection(previousMatch.range.startLineNumber, previousMatch.range.startColumn, previousMatch.range.endLineNumber, previousMatch.range.endColumn);
    }

    public function selectAll(searchScope:Null<Array<Range>>):Array<FindMatch> {
        if (!this._editor.hasModel()) {
            return [];
        }

        this.findController.highlightFindOptions();

        final editorModel = this._editor.getModel();
        if (searchScope != null) {
            return editorModel.findMatches(this.searchText, cast searchScope, false, this.matchCase, this.wholeWord ? this._editor.getOption(EditorOption.wordSeparators) : null, false, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        }
        return editorModel.findMatches(this.searchText, true, false, this.matchCase, this.wholeWord ? this._editor.getOption(EditorOption.wordSeparators) : null, false, EditorOptions.MAX_SAFE_SMALL_INTEGER);
    }

}

class MultiCursorSelectionController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.multiCursorController';

    final _editor:ICodeEditor;
    var _ignoreSelectionChange:Bool;
    var _session:Null<MultiCursorSession>;
    final _sessionDispose:DisposableStore;

    public static function get(editor:ICodeEditor):Null<MultiCursorSelectionController> {
        return editor.getContribution(ID);
    }

    public function new(editor:ICodeEditor) {
        super();
        this._sessionDispose = this._register(new DisposableStore());
        this._editor = editor;
        this._ignoreSelectionChange = false;
        this._session = null;
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    override public function dispose():Void {
        this._endSession();
        super.dispose();
    }

    function _beginSessionIfNeeded(findController:CommonFindController):Void {
        if (this._session == null) {
            // Create a new session
            final session = MultiCursorSession.create(this._editor, findController);
            if (session == null) {
                return;
            }

            this._session = session;

            final newState:INewFindReplaceState = {searchString: this._session.searchText};
            if (this._session.isDisconnectedFromFindController) {
                newState.wholeWordOverride = FindOptionOverride.True;
                newState.matchCaseOverride = FindOptionOverride.True;
                newState.isRegexOverride = FindOptionOverride.False;
            }
            findController.getState().change(newState, false);

            this._sessionDispose.add(this._editor.onDidChangeCursorSelection((e) -> {
                if (this._ignoreSelectionChange) {
                    return;
                }
                this._endSession();
            }));
            this._sessionDispose.add(this._editor.onDidBlurEditorText(() -> {
                this._endSession();
            }));
            this._sessionDispose.add(findController.getState().onFindReplaceStateChange((e) -> {
                if (e.matchCase || e.wholeWord) {
                    this._endSession();
                }
            }));
        }
    }

    function _endSession():Void {
        this._sessionDispose.clear();
        if (this._session != null && this._session.isDisconnectedFromFindController) {
            final newState:INewFindReplaceState = {
                wholeWordOverride: FindOptionOverride.NotSet,
                matchCaseOverride: FindOptionOverride.NotSet,
                isRegexOverride: FindOptionOverride.NotSet,
            };
            this._session.findController.getState().change(newState, false);
        }
        this._session = null;
    }

    function _setSelections(selections:Array<Selection>):Void {
        this._ignoreSelectionChange = true;
        this._editor.setSelections(cast selections);
        this._ignoreSelectionChange = false;
    }

    function _expandEmptyToWord(model:ITextModel, selection:Selection):Selection {
        if (!selection.isEmpty()) {
            return selection;
        }
        final word = this._editor.getConfiguredWordAtPosition(selection.getStartPosition());
        if (word == null) {
            return selection;
        }
        return new Selection(selection.startLineNumber, word.startColumn, selection.startLineNumber, word.endColumn);
    }

    function _applySessionResult(result:Null<MultiCursorSessionResult>):Void {
        if (result == null) {
            return;
        }
        this._setSelections(result.selections);
        if (result.revealRange != null) {
            this._editor.revealRangeInCenterIfOutsideViewport(result.revealRange, result.revealScrollType);
        }
    }

    public function getSession(findController:CommonFindController):Null<MultiCursorSession> {
        return this._session;
    }

    public function addSelectionToNextFindMatch(findController:CommonFindController):Void {
        if (!this._editor.hasModel()) {
            return;
        }
        if (this._session == null) {
            // If there are multiple cursors, handle the case where they do not all select the same text.
            final allSelections = this._editor.getSelections();
            if (allSelections.length > 1) {
                final findState = findController.getState();
                final matchCase = findState.matchCase;
                final selectionsContainSameText = MulticursorUtils.modelRangesContainSameText(this._editor.getModel(), allSelections, matchCase);
                if (!selectionsContainSameText) {
                    final model = this._editor.getModel();
                    final resultingSelections:Array<Selection> = [];
                    for (i in 0...allSelections.length) {
                        resultingSelections[i] = this._expandEmptyToWord(model, allSelections[i]);
                    }
                    this._editor.setSelections(cast resultingSelections);
                    return;
                }
            }
        }
        this._beginSessionIfNeeded(findController);
        if (this._session != null) {
            this._applySessionResult(this._session.addSelectionToNextFindMatch());
        }
    }

    public function addSelectionToPreviousFindMatch(findController:CommonFindController):Void {
        this._beginSessionIfNeeded(findController);
        if (this._session != null) {
            this._applySessionResult(this._session.addSelectionToPreviousFindMatch());
        }
    }

    public function moveSelectionToNextFindMatch(findController:CommonFindController):Void {
        this._beginSessionIfNeeded(findController);
        if (this._session != null) {
            this._applySessionResult(this._session.moveSelectionToNextFindMatch());
        }
    }

    public function moveSelectionToPreviousFindMatch(findController:CommonFindController):Void {
        this._beginSessionIfNeeded(findController);
        if (this._session != null) {
            this._applySessionResult(this._session.moveSelectionToPreviousFindMatch());
        }
    }

    public function selectAll(findController:CommonFindController):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        var matches:Null<Array<FindMatch>> = null;

        final findState = findController.getState();

        // Special case: find widget owns entirely what we search for if:
        // - focus is not in the editor (i.e. it is in the find widget)
        // - and the search widget is visible
        // - and the search string is non-empty
        // - and we're searching for a regex
        if (findState.isRevealed && findState.searchString.length > 0 && findState.isRegex) {
            final editorModel = this._editor.getModel();
            if (findState.searchScope != null) {
                matches = editorModel.findMatches(findState.searchString, cast findState.searchScope, findState.isRegex, findState.matchCase, findState.wholeWord ? this._editor.getOption(EditorOption.wordSeparators) : null, false, EditorOptions.MAX_SAFE_SMALL_INTEGER);
            }
            else {
                matches = editorModel.findMatches(findState.searchString, true, findState.isRegex, findState.matchCase, findState.wholeWord ? this._editor.getOption(EditorOption.wordSeparators) : null, false, EditorOptions.MAX_SAFE_SMALL_INTEGER);
            }
        }
        else {

            this._beginSessionIfNeeded(findController);
            if (this._session == null) {
                return;
            }

            matches = this._session.selectAll(findState.searchScope);
        }

        if (matches.length > 0) {
            final editorSelection = this._editor.getSelection();
            // Have the primary cursor remain the one where the action was invoked
            for (i in 0...matches.length) {
                final match = matches[i];
                final intersection = Range.lift(match.range).intersectRanges(editorSelection);
                if (intersection != null) {
                    // bingo!
                    matches[i] = matches[0];
                    matches[0] = match;
                    break;
                }
            }

            this._setSelections([for (m in matches) new Selection(m.range.startLineNumber, m.range.startColumn, m.range.endLineNumber, m.range.endColumn)]);
        }
    }

    public function selectAllUsingSelections(selections:Array<Selection>):Void {
        if (selections.length > 0) {
            this._setSelections(selections);
        }
    }

}

abstract class MultiCursorSelectionControllerAction extends EditorAction {

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final multiCursorController = MultiCursorSelectionController.get(editor);
        if (multiCursorController == null) {
            return;
        }
        final viewModel = editor._getViewModel();
        if (viewModel != null) {
            final findController = CommonFindController.get(editor);
            if (findController != null) {
                this._run(multiCursorController, findController);
            }
            else {
                final context = accessor != null ? accessor : editor.context;
                final newFindController = new CommonFindController(editor, context.storageService);
                this._run(multiCursorController, newFindController);
                newFindController.dispose();
            }
        }
    }

    abstract function _run(multiCursorController:MultiCursorSelectionController, findController:CommonFindController):Void;

}

class AddSelectionToNextFindMatchAction extends MultiCursorSelectionControllerAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.addSelectionToNextFindMatch',
            label: r != null ? r.localize('addSelectionToNextFindMatch', "Add Selection To Next Find Match") : "Add Selection To Next Find Match",
            alias: 'Add Selection To Next Find Match',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.CtrlCmd | KeyCode.KeyD,
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '3_multi',
                title: r != null ? r.localize('miAddSelectionToNextFindMatch', "Add &&Next Occurrence") : "Add &&Next Occurrence",
                order: 5
            }
        });
    }

    function _run(multiCursorController:MultiCursorSelectionController, findController:CommonFindController):Void {
        multiCursorController.addSelectionToNextFindMatch(findController);
    }

}

class AddSelectionToPreviousFindMatchAction extends MultiCursorSelectionControllerAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.addSelectionToPreviousFindMatch',
            label: r != null ? r.localize('addSelectionToPreviousFindMatch', "Add Selection To Previous Find Match") : "Add Selection To Previous Find Match",
            alias: 'Add Selection To Previous Find Match',
            precondition: null,
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '3_multi',
                title: r != null ? r.localize('miAddSelectionToPreviousFindMatch', "Add P&&revious Occurrence") : "Add P&&revious Occurrence",
                order: 6
            }
        });
    }

    function _run(multiCursorController:MultiCursorSelectionController, findController:CommonFindController):Void {
        multiCursorController.addSelectionToPreviousFindMatch(findController);
    }

}

class MoveSelectionToNextFindMatchAction extends MultiCursorSelectionControllerAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.moveSelectionToNextFindMatch',
            label: r != null ? r.localize('moveSelectionToNextFindMatch', "Move Last Selection To Next Find Match") : "Move Last Selection To Next Find Match",
            alias: 'Move Last Selection To Next Find Match',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyD),
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    function _run(multiCursorController:MultiCursorSelectionController, findController:CommonFindController):Void {
        multiCursorController.moveSelectionToNextFindMatch(findController);
    }

}

class MoveSelectionToPreviousFindMatchAction extends MultiCursorSelectionControllerAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.moveSelectionToPreviousFindMatch',
            label: r != null ? r.localize('moveSelectionToPreviousFindMatch', "Move Last Selection To Previous Find Match") : "Move Last Selection To Previous Find Match",
            alias: 'Move Last Selection To Previous Find Match',
            precondition: null
        });
    }

    function _run(multiCursorController:MultiCursorSelectionController, findController:CommonFindController):Void {
        multiCursorController.moveSelectionToPreviousFindMatch(findController);
    }

}

class SelectHighlightsAction extends MultiCursorSelectionControllerAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.selectHighlights',
            label: r != null ? r.localize('selectAllOccurrencesOfFindMatch', "Select All Occurrences of Find Match") : "Select All Occurrences of Find Match",
            alias: 'Select All Occurrences of Find Match',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyL,
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '3_multi',
                title: r != null ? r.localize('miSelectHighlights', "Select All &&Occurrences") : "Select All &&Occurrences",
                order: 7
            }
        });
    }

    function _run(multiCursorController:MultiCursorSelectionController, findController:CommonFindController):Void {
        multiCursorController.selectAll(findController);
    }

}

class CompatChangeAll extends MultiCursorSelectionControllerAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.changeAll',
            label: r != null ? r.localize('changeAll.label', "Change All Occurrences") : "Change All Occurrences",
            alias: 'Change All Occurrences',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.editorTextFocus),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.F2,
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {
                group: '1_modification',
                order: 1.2
            }
        });
    }

    function _run(multiCursorController:MultiCursorSelectionController, findController:CommonFindController):Void {
        multiCursorController.selectAll(findController);
    }

}

class SelectionHighlighterState {

    final _model:ITextModel;
    final _searchText:String;
    final _matchCase:Bool;
    final _wordSeparators:Null<String>;
    final _modelVersionId:Int;
    var _cachedFindMatches:Null<Array<Range>> = null;

    public function new(model:ITextModel, searchText:String, matchCase:Bool, wordSeparators:Null<String>, prevState:Null<SelectionHighlighterState>) {
        this._model = model;
        this._searchText = searchText;
        this._matchCase = matchCase;
        this._wordSeparators = wordSeparators;
        this._modelVersionId = model.getVersionId();
        if (prevState != null
            && this._model == prevState._model
            && this._searchText == prevState._searchText
            && this._matchCase == prevState._matchCase
            && this._wordSeparators == prevState._wordSeparators
            && this._modelVersionId == prevState._modelVersionId
        ) {
            this._cachedFindMatches = prevState._cachedFindMatches;
        }
    }

    public function findMatches():Array<Range> {
        if (this._cachedFindMatches == null) {
            this._cachedFindMatches = [for (m in this._model.findMatches(this._searchText, true, false, this._matchCase, this._wordSeparators, false)) Range.lift(m.range)];
            haxe.ds.ArraySort.sort(this._cachedFindMatches, Range.compareRangesUsingStarts);
        }
        return this._cachedFindMatches;
    }

}

class SelectionHighlighter extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.selectionHighlighter';

    final editor:ICodeEditor;
    var _isEnabled:Bool;
    final _decorations:IEditorDecorationsCollection;
    final updateSoon:RunOnceScheduler;
    var state:Null<SelectionHighlighterState>;

    public static function get(editor:ICodeEditor):Null<SelectionHighlighter> {
        return editor.getContribution(ID);
    }

    public function new(editor:ICodeEditor) {
        super();
        this.editor = editor;
        this._isEnabled = editor.getOption(EditorOption.selectionHighlight);
        this._decorations = editor.createDecorationsCollection();
        this.updateSoon = this._register(new RunOnceScheduler(() -> this._update(), 300));
        this.state = null;

        this._register(editor.onDidChangeConfiguration((e) -> {
            this._isEnabled = editor.getOption(EditorOption.selectionHighlight);
        }));
        this._register(editor.onDidChangeCursorSelection((e:ICursorSelectionChangedEvent) -> {

            if (!this._isEnabled) {
                // Early exit if nothing needs to be done!
                // Leave some form of early exit check here if you wish to continue being a cursor position change listener ;)
                return;
            }

            if (e.selection.isEmpty()) {
                if (e.reason == CursorChangeReason.Explicit) {
                    if (this.state != null) {
                        // no longer valid
                        this._setState(null);
                    }
                    this.updateSoon.schedule();
                }
                else {
                    this._setState(null);
                }
            }
            else {
                this._update();
            }
        }));
        this._register(editor.onDidChangeModel((e) -> {
            this._setState(null);
        }));
        this._register(editor.onDidChangeModelContent((e) -> {
            if (this._isEnabled) {
                this.updateSoon.schedule();
            }
        }));
        final findController = CommonFindController.get(editor);
        if (findController != null) {
            this._register(findController.getState().onFindReplaceStateChange((e) -> {
                this._update();
            }));
        }
        this.updateSoon.schedule();
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * Runs the pending update now (tests; Monaco waits 300 ms).
     */
    public function _flushPendingUpdate():Void {
        this.updateSoon.flush();
    }

    function _update():Void {
        this._setState(SelectionHighlighter._createState(this.state, this._isEnabled, this.editor));
    }

    static function isWhitespaceOnly(text:String):Bool {
        // /^[ \t]+$/
        if (text.length == 0) {
            return false;
        }
        for (i in 0...text.length) {
            final c = StringTools.fastCodeAt(text, i);
            if (c != ' '.code && c != '\t'.code) {
                return false;
            }
        }
        return true;
    }

    static function _createState(oldState:Null<SelectionHighlighterState>, isEnabled:Bool, editor:ICodeEditor):Null<SelectionHighlighterState> {
        if (!isEnabled) {
            return null;
        }
        if (!editor.hasModel()) {
            return null;
        }
        final s = editor.getSelection();
        if (s.startLineNumber != s.endLineNumber) {
            // multiline forbidden for perf reasons
            return null;
        }
        final multiCursorController = MultiCursorSelectionController.get(editor);
        if (multiCursorController == null) {
            return null;
        }
        final findController = CommonFindController.get(editor);
        if (findController == null) {
            return null;
        }
        var r = multiCursorController.getSession(findController);
        if (r == null) {
            final allSelections = editor.getSelections();
            if (allSelections.length > 1) {
                final findState = findController.getState();
                final matchCase = findState.matchCase;
                final selectionsContainSameText = MulticursorUtils.modelRangesContainSameText(editor.getModel(), allSelections, matchCase);
                if (!selectionsContainSameText) {
                    return null;
                }
            }

            r = MultiCursorSession.create(editor, findController);
        }
        if (r == null) {
            return null;
        }

        if (r.currentMatch != null) {
            // This is an empty selection
            // Do not interfere with semantic word highlighting in the no selection case
            return null;
        }
        if (isWhitespaceOnly(r.searchText)) {
            // whitespace only selection
            return null;
        }
        if (r.searchText.length > 200) {
            // very long selection
            return null;
        }

        // TODO: better handling of this case
        final findState = findController.getState();
        final caseSensitive = findState.matchCase;

        // Return early if the find widget shows the exact same matches
        if (findState.isRevealed) {
            var findStateSearchString = findState.searchString;
            if (!caseSensitive) {
                findStateSearchString = findStateSearchString.toLowerCase();
            }

            var mySearchString = r.searchText;
            if (!caseSensitive) {
                mySearchString = mySearchString.toLowerCase();
            }

            if (findStateSearchString == mySearchString && r.matchCase == findState.matchCase && r.wholeWord == findState.wholeWord && !findState.isRegex) {
                return null;
            }
        }

        return new SelectionHighlighterState(editor.getModel(), r.searchText, r.matchCase, r.wholeWord ? editor.getOption(EditorOption.wordSeparators) : null, oldState);
    }

    function _setState(newState:Null<SelectionHighlighterState>):Void {
        this.state = newState;

        if (this.state == null) {
            this._decorations.clear();
            return;
        }

        if (!this.editor.hasModel()) {
            return;
        }

        final model = this.editor.getModel();
        if (model.isTooLargeForTokenization()) {
            // the file is too large, so searching word under cursor in the whole document would be blocking the UI.
            return;
        }

        final allMatches = this.state.findMatches();

        final selections = this.editor.getSelections();
        haxe.ds.ArraySort.sort(selections, Range.compareRangesUsingStarts);

        // do not overlap with selection (issue #64 and #512)
        final matches:Array<Range> = [];
        var i = 0;
        var j = 0;
        final len = allMatches.length;
        final lenJ = selections.length;
        while (i < len) {
            final match = allMatches[i];

            if (j >= lenJ) {
                // finished all editor selections
                matches.push(match);
                i++;
            }
            else {
                final cmp = Range.compareRangesUsingStarts(match, selections[j]);
                if (cmp < 0) {
                    // match is before sel
                    if (selections[j].isEmpty() || !Range.areIntersecting(match, selections[j])) {
                        matches.push(match);
                    }
                    i++;
                }
                else if (cmp > 0) {
                    // sel is before match
                    j++;
                }
                else {
                    // sel is equal to match
                    i++;
                    j++;
                }
            }
        }

        final occurrenceHighlighting:Bool = this.editor.getOption(EditorOption.occurrencesHighlight) != 'off';
        final hasSemanticHighlights = this.editor.context.languageFeaturesService.documentHighlightProvider.has(model) && occurrenceHighlighting;
        final options = HighlightDecorations.getSelectionHighlightDecorationOptions(hasSemanticHighlights);
        final decorations:Array<IModelDeltaDecoration> = [for (r in matches) {
            range: r,
            options: cast options
        }];

        this._decorations.set(decorations);
    }

    override public function dispose():Void {
        this._setState(null);
        super.dispose();
    }

}

class MulticursorUtils {

    public static function modelRangesContainSameText(model:ITextModel, ranges:Array<Selection>, matchCase:Bool):Bool {
        final selectedText = getValueInRange(model, ranges[0], !matchCase);
        for (i in 1...ranges.length) {
            final range = ranges[i];
            if (range.isEmpty()) {
                return false;
            }
            final thisSelectedText = getValueInRange(model, range, !matchCase);
            if (selectedText != thisSelectedText) {
                return false;
            }
        }
        return true;
    }

    static function getValueInRange(model:ITextModel, range:Range, toLowerCase:Bool):String {
        final text = model.getValueInRange(range);
        return (toLowerCase ? text.toLowerCase() : text);
    }

}

class FocusNextCursor extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.focusNextCursor',
            label: r != null ? r.localize('mutlicursor.focusNextCursor', "Focus Next Cursor") : "Focus Next Cursor",
            metadata: {
                description: r != null ? r.localize('mutlicursor.focusNextCursor.description', "Focuses the next cursor") : "Focuses the next cursor",
                args: [],
            },
            alias: 'Focus Next Cursor',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final viewModel = editor._getViewModel();

        if (viewModel.cursorConfig.readOnly) {
            return;
        }

        final source:Null<String> = JsValues.field(args, 'source');
        viewModel.model.pushStackElement();
        final previousCursorState:Array<PartialCursorState> = cast viewModel.getCursorStates().copy();
        final firstCursor = previousCursorState.shift();
        if (firstCursor == null) {
            return;
        }
        previousCursorState.push(firstCursor);

        viewModel.setCursorStates(source, CursorChangeReason.Explicit, previousCursorState);
        viewModel.revealPrimaryCursor(source, true);
    }

}

class FocusPreviousCursor extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.focusPreviousCursor',
            label: r != null ? r.localize('mutlicursor.focusPreviousCursor', "Focus Previous Cursor") : "Focus Previous Cursor",
            metadata: {
                description: r != null ? r.localize('mutlicursor.focusPreviousCursor.description', "Focuses the previous cursor") : "Focuses the previous cursor",
                args: [],
            },
            alias: 'Focus Previous Cursor',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final viewModel = editor._getViewModel();

        if (viewModel.cursorConfig.readOnly) {
            return;
        }

        final source:Null<String> = JsValues.field(args, 'source');
        viewModel.model.pushStackElement();
        final previousCursorState:Array<PartialCursorState> = cast viewModel.getCursorStates().copy();
        final firstCursor = previousCursorState.pop();
        if (firstCursor == null) {
            return;
        }
        previousCursorState.unshift(firstCursor);

        viewModel.setCursorStates(source, CursorChangeReason.Explicit, previousCursorState);
        viewModel.revealPrimaryCursor(source, true);
    }

}

/**
 * The module level code of multicursor.ts.
 */
class MulticursorRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(MultiCursorSelectionController.ID, editor -> new MultiCursorSelectionController(editor), EditorContributionInstantiation.Lazy);
        r.registerEditorContribution(SelectionHighlighter.ID, editor -> new SelectionHighlighter(editor), EditorContributionInstantiation.AfterFirstRender);

        r.registerEditorAction(new InsertCursorAbove(r));
        r.registerEditorAction(new InsertCursorBelow(r));
        r.registerEditorAction(new InsertCursorAtEndOfEachLineSelected(r));
        r.registerEditorAction(new AddSelectionToNextFindMatchAction(r));
        r.registerEditorAction(new AddSelectionToPreviousFindMatchAction(r));
        r.registerEditorAction(new MoveSelectionToNextFindMatchAction(r));
        r.registerEditorAction(new MoveSelectionToPreviousFindMatchAction(r));
        r.registerEditorAction(new SelectHighlightsAction(r));
        r.registerEditorAction(new CompatChangeAll(r));
        r.registerEditorAction(new InsertCursorAtEndOfLineSelected(r));
        r.registerEditorAction(new InsertCursorAtTopOfLineSelected(r));
        r.registerEditorAction(new FocusNextCursor(r));
        r.registerEditorAction(new FocusPreviousCursor(r));

        // The look of `selectionHighlight` (highlightDecorations.css)
        HighlightDecorations.registerStyles(r.context);
    }

}
