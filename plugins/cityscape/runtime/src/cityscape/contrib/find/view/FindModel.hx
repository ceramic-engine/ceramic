// Ported from vscode src/vs/editor/contrib/find/browser/findModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.find.view;

import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Async.TimeoutTimer;
import cityscape.base.common.Lifecycle.DisposableStore;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.RegExp;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Model;
import cityscape.common.commands.ReplaceCommand;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModelSearch.SearchParams;
import cityscape.base.common.KeyCodes;
import cityscape.platform.contextkey.common.ContextKey.RawContextKey;
import cityscape.platform.contextkey.common.ContextKey.ContextKeyExpression;
import cityscape.platform.keybinding.common.KeybindingsRegistry.IKeybindings;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.contrib.find.view.FindState;
import cityscape.contrib.find.view.ReplacePattern;

/**
 * The constants of findModel.ts: the context keys, the default keybindings
 * of the find toggles, the match limit.
 */
class FindModel {

    static var _findWidgetVisible:Null<RawContextKey<Bool>> = null;
    static var _findInputFocused:Null<RawContextKey<Bool>> = null;
    static var _replaceInputFocused:Null<RawContextKey<Bool>> = null;

    /**
     * Context key: the find widget of the editor is visible.
     */
    public static var CONTEXT_FIND_WIDGET_VISIBLE(get, never):RawContextKey<Bool>;
    static function get_CONTEXT_FIND_WIDGET_VISIBLE():RawContextKey<Bool> {
        if (_findWidgetVisible == null) {
            _findWidgetVisible = new RawContextKey<Bool>('findWidgetVisible', false);
        }
        return _findWidgetVisible;
    }

    public static var CONTEXT_FIND_WIDGET_NOT_VISIBLE(get, never):ContextKeyExpression;
    static function get_CONTEXT_FIND_WIDGET_NOT_VISIBLE():ContextKeyExpression {
        return CONTEXT_FIND_WIDGET_VISIBLE.toNegated();
    }

    // Keep ContextKey use of 'Focussed' to not break when clauses
    /**
     * Context key: the find input of the find widget has the focus.
     */
    public static var CONTEXT_FIND_INPUT_FOCUSED(get, never):RawContextKey<Bool>;
    static function get_CONTEXT_FIND_INPUT_FOCUSED():RawContextKey<Bool> {
        if (_findInputFocused == null) {
            _findInputFocused = new RawContextKey<Bool>('findInputFocussed', false);
        }
        return _findInputFocused;
    }

    /**
     * Context key: the replace input of the find widget has the focus.
     */
    public static var CONTEXT_REPLACE_INPUT_FOCUSED(get, never):RawContextKey<Bool>;
    static function get_CONTEXT_REPLACE_INPUT_FOCUSED():RawContextKey<Bool> {
        if (_replaceInputFocused == null) {
            _replaceInputFocused = new RawContextKey<Bool>('replaceInputFocussed', false);
        }
        return _replaceInputFocused;
    }

    public static final ToggleCaseSensitiveKeybinding:IKeybindings = {
        primary: KeyMod.Alt | KeyCode.KeyC,
        mac: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyC}
    };
    public static final ToggleWholeWordKeybinding:IKeybindings = {
        primary: KeyMod.Alt | KeyCode.KeyW,
        mac: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyW}
    };
    public static final ToggleRegexKeybinding:IKeybindings = {
        primary: KeyMod.Alt | KeyCode.KeyR,
        mac: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyR}
    };
    public static final ToggleSearchScopeKeybinding:IKeybindings = {
        primary: KeyMod.Alt | KeyCode.KeyL,
        mac: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyL}
    };
    public static final TogglePreserveCaseKeybinding:IKeybindings = {
        primary: KeyMod.Alt | KeyCode.KeyP,
        mac: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyP}
    };

    /**
     * Only the first `MATCHES_LIMIT` matches are decorated; the find
     * operations still work on the whole text.
     */
    public static inline final MATCHES_LIMIT = 19999;

    /**
     * The delay before searching again in a model too large to search
     * synchronously, in milliseconds.
     */
    public static inline final RESEARCH_DELAY = 240;

}

/**
 * Monaco's `FIND_IDS`: the ids of the find commands and actions.
 */
class FIND_IDS {
    public static inline final StartFindAction = 'actions.find';
    public static inline final StartFindWithSelection = 'actions.findWithSelection';
    public static inline final StartFindWithArgs = 'editor.actions.findWithArgs';
    public static inline final NextMatchFindAction = 'editor.action.nextMatchFindAction';
    public static inline final PreviousMatchFindAction = 'editor.action.previousMatchFindAction';
    public static inline final GoToMatchFindAction = 'editor.action.goToMatchFindAction';
    public static inline final NextSelectionMatchFindAction = 'editor.action.nextSelectionMatchFindAction';
    public static inline final PreviousSelectionMatchFindAction = 'editor.action.previousSelectionMatchFindAction';
    public static inline final StartFindReplaceAction = 'editor.action.startFindReplaceAction';
    public static inline final CloseFindWidgetCommand = 'closeFindWidget';
    public static inline final ToggleCaseSensitiveCommand = 'toggleFindCaseSensitive';
    public static inline final ToggleWholeWordCommand = 'toggleFindWholeWord';
    public static inline final ToggleRegexCommand = 'toggleFindRegex';
    public static inline final ToggleSearchScopeCommand = 'toggleFindInSelection';
    public static inline final TogglePreserveCaseCommand = 'togglePreserveCase';
    public static inline final ReplaceOneAction = 'editor.action.replaceOne';
    public static inline final ReplaceAllAction = 'editor.action.replaceAll';
    public static inline final SelectAllMatchesAction = 'editor.action.selectAllMatches';
}

/**
 * The find model of an editor while its find widget is open: searches the
 * model when the search changes (and again 100 ms after an edit), keeps the
 * match decorations, moves to the next and previous matches, replaces one
 * or all, selects all matches.
 */
class FindModelBoundToEditorModel implements IDisposable {

    final _editor:ICodeEditor;
    final _state:FindReplaceState;
    final _toDispose = new DisposableStore();
    final _decorations:FindDecorations;
    var _ignoreModelContentChanged:Bool;
    final _startSearchingTimer:TimeoutTimer;

    final _updateDecorationsScheduler:RunOnceScheduler;
    var _isDisposed:Bool;

    public function new(editor:ICodeEditor, state:FindReplaceState) {
        this._editor = editor;
        this._state = state;
        this._isDisposed = false;
        this._startSearchingTimer = new TimeoutTimer();

        this._decorations = new FindDecorations(editor);
        this._toDispose.add(this._decorations);

        this._updateDecorationsScheduler = new RunOnceScheduler(() -> {
            if (!this._editor.hasModel()) {
                return;
            }
            this.research(false);
        }, 100);
        this._toDispose.add(this._updateDecorationsScheduler);

        this._toDispose.add(this._editor.onDidChangeCursorPosition((e:ICursorPositionChangedEvent) -> {
            if (
                e.reason == CursorChangeReason.Explicit
                || e.reason == CursorChangeReason.Undo
                || e.reason == CursorChangeReason.Redo
            ) {
                this._decorations.setStartPosition(this._editor.getPosition());
            }
        }));

        this._ignoreModelContentChanged = false;
        this._toDispose.add(this._editor.onDidChangeModelContent((e) -> {
            if (this._ignoreModelContentChanged) {
                return;
            }
            if (e.isFlush) {
                // a model.setValue() was called
                this._decorations.reset();
            }
            this._decorations.setStartPosition(this._editor.getPosition());
            this._updateDecorationsScheduler.schedule();
        }));

        this._toDispose.add(this._state.onFindReplaceStateChange((e) -> this._onStateChanged(e)));

        this.research(false, this._state.searchScope, true);
    }

    public function dispose():Void {
        this._isDisposed = true;
        this._startSearchingTimer.dispose();
        this._toDispose.dispose();
    }

    function _onStateChanged(e:FindReplaceStateChangedEvent):Void {
        if (this._isDisposed) {
            // The find model is disposed during a find state changed event
            return;
        }
        if (!this._editor.hasModel()) {
            // The find model will be disposed momentarily
            return;
        }
        if (e.searchString || e.isReplaceRevealed || e.isRegex || e.wholeWord || e.matchCase || e.searchScope) {
            final model = this._editor.getModel();

            if (model.isTooLargeForSyncing()) {
                this._startSearchingTimer.cancel();

                this._startSearchingTimer.setIfNotSet(() -> {
                    if (e.searchScope) {
                        this.research(e.moveCursor, this._state.searchScope, true);
                    } else {
                        this.research(e.moveCursor);
                    }
                }, FindModel.RESEARCH_DELAY);
            } else {
                if (e.searchScope) {
                    this.research(e.moveCursor, this._state.searchScope, true);
                } else {
                    this.research(e.moveCursor);
                }
            }
        }
    }

    static function _getSearchRange(model:ITextModel, findScope:Null<Range>):Range {
        // If we have set now or before a find scope, use it for computing the search range
        if (findScope != null) {
            return findScope;
        }

        return model.getFullModelRange();
    }

    /**
     * `hasNewFindScope` false is Monaco's `newFindScope === undefined`: the
     * find scopes of the decorations are kept.
     */
    function research(moveCursor:Bool, ?newFindScope:Null<Array<Range>>, hasNewFindScope:Bool = false):Void {
        var findScopes:Null<Array<Range>> = null;
        if (hasNewFindScope) {
            if (newFindScope != null) {
                findScopes = newFindScope;
            }
        } else {
            findScopes = this._decorations.getFindScopes();
        }
        if (findScopes != null) {
            findScopes = [for (findScope in findScopes) {
                if (findScope.startLineNumber != findScope.endLineNumber) {
                    var endLineNumber = findScope.endLineNumber;

                    if (findScope.endColumn == 1) {
                        endLineNumber = endLineNumber - 1;
                    }

                    new Range(findScope.startLineNumber, 1, endLineNumber, this._editor.getModel().getLineMaxColumn(endLineNumber));
                } else {
                    findScope;
                }
            }];
        }

        final findMatches = this._findMatches(findScopes, false, FindModel.MATCHES_LIMIT);
        this._decorations.set(findMatches, findScopes);

        final editorSelection = this._editor.getSelection();
        var currentMatchesPosition = this._decorations.getCurrentMatchesPosition(editorSelection);
        if (currentMatchesPosition == 0 && findMatches.length > 0) {
            // current selection is not on top of a match
            // try to find its nearest result from the top of the document
            final matchAfterSelection = findFirstIdxMonotonousOrArrLen(findMatches, match -> Range.compareRangesUsingStarts(match.range, editorSelection) >= 0);
            currentMatchesPosition = matchAfterSelection > 0 ? matchAfterSelection - 1 + 1 /** match position is one based */ : currentMatchesPosition;
        }

        this._state.changeMatchInfo(
            currentMatchesPosition,
            this._decorations.getCount(),
            null,
            false
        );

        if (moveCursor && this._editor.getOption(EditorOption.find).cursorMoveOnType) {
            this._moveToNextMatch(this._decorations.getStartPosition());
        }
    }

    /**
     * arraysFind.ts `findFirstIdxMonotonousOrArrLen`: the first index where
     * the (monotonous) predicate is true, or the length of the array.
     */
    static function findFirstIdxMonotonousOrArrLen(array:Array<FindMatch>, predicate:(match:FindMatch) -> Bool):Int {
        var startIdx = 0;
        var endIdxEx = array.length;
        while (startIdx < endIdxEx) {
            final k = Math.floor((startIdx + endIdxEx) / 2);
            if (predicate(array[k])) {
                endIdxEx = k;
            } else {
                startIdx = k + 1;
            }
        }
        return startIdx;
    }

    function _hasMatches():Bool {
        return (this._state.matchesCount > 0);
    }

    function _cannotFind():Bool {
        if (!this._hasMatches()) {
            final findScope = this._decorations.getFindScope();
            if (findScope != null) {
                // Reveal the selection so user is reminded that 'selection find' is on.
                this._editor.revealRangeInCenterIfOutsideViewport(findScope, ScrollType.Smooth);
            }
            return true;
        }
        return false;
    }

    function _setCurrentFindMatch(match:Range):Void {
        final matchesPosition = this._decorations.setCurrentFindMatch(match);
        this._state.changeMatchInfo(
            matchesPosition,
            this._decorations.getCount(),
            match
        );

        this._editor.setSelection(match);
        this._editor.revealRangeInCenterIfOutsideViewport(match, ScrollType.Smooth);
    }

    function _prevSearchPosition(before:Position):Position {
        final isUsingLineStops = this._state.isRegex && (
            this._state.searchString.indexOf('^') >= 0
            || this._state.searchString.indexOf('$') >= 0
        );
        var lineNumber = before.lineNumber;
        var column = before.column;
        final model = this._editor.getModel();

        if (isUsingLineStops || column == 1) {
            if (lineNumber == 1) {
                lineNumber = model.getLineCount();
            } else {
                lineNumber--;
            }
            column = model.getLineMaxColumn(lineNumber);
        } else {
            column--;
        }

        return new Position(lineNumber, column);
    }

    function _wordSeparators():Null<String> {
        return this._state.wholeWord ? this._editor.getOption(EditorOption.wordSeparators) : null;
    }

    function _moveToPrevMatch(before:Position, isRecursed:Bool = false):Void {
        if (!this._state.canNavigateBack()) {
            // we are beyond the first matched find result
            // instead of doing nothing, we should refocus the first item
            final nextMatchRange = this._decorations.matchAfterPosition(before);

            if (nextMatchRange != null) {
                this._setCurrentFindMatch(nextMatchRange);
            }
            return;
        }
        if (this._decorations.getCount() < FindModel.MATCHES_LIMIT) {
            var prevMatchRange = this._decorations.matchBeforePosition(before);

            if (prevMatchRange != null && prevMatchRange.isEmpty() && prevMatchRange.getStartPosition().equals(before)) {
                before = this._prevSearchPosition(before);
                prevMatchRange = this._decorations.matchBeforePosition(before);
            }

            if (prevMatchRange != null) {
                this._setCurrentFindMatch(prevMatchRange);
            }

            return;
        }

        if (this._cannotFind()) {
            return;
        }

        final findScope = this._decorations.getFindScope();
        final searchRange = FindModelBoundToEditorModel._getSearchRange(this._editor.getModel(), findScope);

        // ...(----)...|...
        if (searchRange.getEndPosition().isBefore(before)) {
            before = searchRange.getEndPosition();
        }

        // ...|...(----)...
        if (before.isBefore(searchRange.getStartPosition())) {
            before = searchRange.getEndPosition();
        }

        final model = this._editor.getModel();

        var position = new Position(before.lineNumber, before.column);

        var prevMatch = model.findPreviousMatch(this._state.searchString, position, this._state.isRegex, this._state.matchCase, this._wordSeparators(), false);

        if (prevMatch != null && prevMatch.range.isEmpty() && prevMatch.range.getStartPosition().equals(position)) {
            // Looks like we're stuck at this position, unacceptable!
            position = this._prevSearchPosition(position);
            prevMatch = model.findPreviousMatch(this._state.searchString, position, this._state.isRegex, this._state.matchCase, this._wordSeparators(), false);
        }

        if (prevMatch == null) {
            // there is precisely one match and selection is on top of it
            return;
        }

        if (!isRecursed && !searchRange.containsRange(prevMatch.range)) {
            this._moveToPrevMatch(prevMatch.range.getStartPosition(), true);
            return;
        }

        this._setCurrentFindMatch(prevMatch.range);
    }

    public function moveToPrevMatch():Void {
        this._moveToPrevMatch(this._editor.getSelection().getStartPosition());
    }

    function _nextSearchPosition(after:Position):Position {
        final isUsingLineStops = this._state.isRegex && (
            this._state.searchString.indexOf('^') >= 0
            || this._state.searchString.indexOf('$') >= 0
        );

        var lineNumber = after.lineNumber;
        var column = after.column;
        final model = this._editor.getModel();

        if (isUsingLineStops || column == model.getLineMaxColumn(lineNumber)) {
            if (lineNumber == model.getLineCount()) {
                lineNumber = 1;
            } else {
                lineNumber++;
            }
            column = 1;
        } else {
            column++;
        }

        return new Position(lineNumber, column);
    }

    function _moveToNextMatch(after:Position):Void {
        if (!this._state.canNavigateForward()) {
            // we are beyond the last matched find result
            // instead of doing nothing, we should refocus the last item
            final prevMatchRange = this._decorations.matchBeforePosition(after);

            if (prevMatchRange != null) {
                this._setCurrentFindMatch(prevMatchRange);
            }
            return;
        }
        if (this._decorations.getCount() < FindModel.MATCHES_LIMIT) {
            var nextMatchRange = this._decorations.matchAfterPosition(after);

            if (nextMatchRange != null && nextMatchRange.isEmpty() && nextMatchRange.getStartPosition().equals(after)) {
                // Looks like we're stuck at this position, unacceptable!
                after = this._nextSearchPosition(after);
                nextMatchRange = this._decorations.matchAfterPosition(after);
            }
            if (nextMatchRange != null) {
                this._setCurrentFindMatch(nextMatchRange);
            }

            return;
        }

        final nextMatch = this._getNextMatch(after, false, true);
        if (nextMatch != null) {
            this._setCurrentFindMatch(nextMatch.range);
        }
    }

    function _getNextMatch(after:Position, captureMatches:Bool, forceMove:Bool, isRecursed:Bool = false):Null<FindMatch> {
        if (this._cannotFind()) {
            return null;
        }

        final findScope = this._decorations.getFindScope();
        final searchRange = FindModelBoundToEditorModel._getSearchRange(this._editor.getModel(), findScope);

        // ...(----)...|...
        if (searchRange.getEndPosition().isBefore(after)) {
            after = searchRange.getStartPosition();
        }

        // ...|...(----)...
        if (after.isBefore(searchRange.getStartPosition())) {
            after = searchRange.getStartPosition();
        }

        final model = this._editor.getModel();

        var position = new Position(after.lineNumber, after.column);

        var nextMatch = model.findNextMatch(this._state.searchString, position, this._state.isRegex, this._state.matchCase, this._wordSeparators(), captureMatches);

        if (forceMove && nextMatch != null && nextMatch.range.isEmpty() && nextMatch.range.getStartPosition().equals(position)) {
            // Looks like we're stuck at this position, unacceptable!
            position = this._nextSearchPosition(position);
            nextMatch = model.findNextMatch(this._state.searchString, position, this._state.isRegex, this._state.matchCase, this._wordSeparators(), captureMatches);
        }

        if (nextMatch == null) {
            // there is precisely one match and selection is on top of it
            return null;
        }

        if (!isRecursed && !searchRange.containsRange(nextMatch.range)) {
            return this._getNextMatch(nextMatch.range.getEndPosition(), captureMatches, forceMove, true);
        }

        return nextMatch;
    }

    public function moveToNextMatch():Void {
        this._moveToNextMatch(this._editor.getSelection().getEndPosition());
    }

    function _moveToMatch(index:Int):Void {
        final decorationRange = this._decorations.getDecorationRangeAt(index);
        if (decorationRange != null) {
            this._setCurrentFindMatch(decorationRange);
        }
    }

    public function moveToMatch(index:Int):Void {
        this._moveToMatch(index);
    }

    function _getReplacePattern():ReplacePattern {
        if (this._state.isRegex) {
            return ReplacePatternParser.parseReplaceString(this._state.replaceString);
        }
        return ReplacePattern.fromStaticValue(this._state.replaceString);
    }

    public function replace():Void {
        if (!this._hasMatches()) {
            return;
        }

        final replacePattern = this._getReplacePattern();
        final selection = this._editor.getSelection();
        final nextMatch = this._getNextMatch(selection.getStartPosition(), true, false);
        if (nextMatch != null) {
            if (selection.equalsRange(nextMatch.range)) {
                // selection sits on a find match => replace it!
                final replaceString = replacePattern.buildReplaceString(nextMatch.matches, this._state.preserveCase);

                final command = new ReplaceCommand(selection, replaceString);

                this._executeEditorCommand('replace', command);

                this._decorations.setStartPosition(new Position(selection.startLineNumber, selection.startColumn + replaceString.length));
                this.research(true);
            } else {
                this._decorations.setStartPosition(this._editor.getPosition());
                this._setCurrentFindMatch(nextMatch.range);
            }
        }
    }

    function _findMatches(findScopes:Null<Array<Range>>, captureMatches:Bool, limitResultCount:Int):Array<FindMatch> {
        final model = this._editor.getModel();
        final searchRanges:Array<IRange> = findScopes == null
            ? [FindModelBoundToEditorModel._getSearchRange(model, null)]
            : [for (scope in findScopes) FindModelBoundToEditorModel._getSearchRange(model, scope)];

        return model.findMatches(this._state.searchString, cast searchRanges, this._state.isRegex, this._state.matchCase, this._wordSeparators(), captureMatches, limitResultCount);
    }

    public function replaceAll():Void {
        if (!this._hasMatches()) {
            return;
        }

        final findScopes = this._decorations.getFindScopes();

        if (findScopes == null && this._state.matchesCount >= FindModel.MATCHES_LIMIT) {
            // Doing a replace on the entire file that is over ${MATCHES_LIMIT} matches
            this._largeReplaceAll();
        } else {
            this._regularReplaceAll(findScopes);
        }

        this.research(false);
    }

    function _largeReplaceAll():Void {
        final searchParams = new SearchParams(this._state.searchString, this._state.isRegex, this._state.matchCase, this._wordSeparators());
        final searchData = searchParams.parseSearchRequest();
        if (searchData == null) {
            return;
        }

        var searchRegex = searchData.regex;
        if (!searchRegex.multiline) {
            var mod = 'mu';
            if (searchRegex.ignoreCase) {
                mod += 'i';
            }
            if (searchRegex.global) {
                mod += 'g';
            }
            searchRegex = new RegExp(searchRegex.source, mod);
        }

        final model = this._editor.getModel();
        final modelText = model.getValue(EndOfLinePreference.LF);
        final fullModelRange = model.getFullModelRange();

        final replacePattern = this._getReplacePattern();
        var resultText:String;
        final preserveCase = this._state.preserveCase;

        if (replacePattern.hasReplacementPatterns || preserveCase) {
            resultText = jsReplace(modelText, searchRegex, (args) -> replacePattern.buildReplaceString(args, preserveCase));
        } else {
            // A replacement string given to `String.replace` (`$&`, `$1`...
            // are expanded by JavaScript too)
            final value = replacePattern.buildReplaceString(null, preserveCase);
            resultText = jsReplace(modelText, searchRegex, (args) -> expandJsReplacement(value, args));
        }

        final command = new ReplaceCommandThatPreservesSelection(fullModelRange, resultText, this._editor.getSelection());
        this._executeEditorCommand('replaceAll', command);
    }

    /**
     * JavaScript's `text.replace(regex, fn)`: `fn` gets the arguments of a
     * replacer function (the match, the groups, the offset and the string,
     * the offset as a string, and an empty string for a group that did not
     * take part, like `arguments` read by `buildReplaceString`).
     */
    static function jsReplace(text:String, regex:RegExp, fn:(args:Array<String>) -> String):String {
        final buf = new StringBuf();
        var last = 0;
        regex.lastIndex = 0;
        while (true) {
            final m = regex.exec(text);
            if (m == null) {
                break;
            }
            final args:Array<String> = [];
            for (i in 0...m.length) {
                final g = m[i];
                args.push(g);
            }
            args.push(m.index == 0 ? null : Std.string(m.index));
            args.push(text);
            buf.add(text.substring(last, m.index));
            buf.add(fn(args));
            final matched = m[0];
            last = m.index + matched.length;
            if (!regex.global) {
                break;
            }
            if (matched.length == 0) {
                // AdvanceStringIndex (by code point with the `u` flag)
                var next = regex.lastIndex + 1;
                if (regex.unicode && regex.lastIndex < text.length - 1) {
                    final c = StringTools.fastCodeAt(text, regex.lastIndex);
                    final d = StringTools.fastCodeAt(text, regex.lastIndex + 1);
                    if (c >= 0xD800 && c <= 0xDBFF && d >= 0xDC00 && d <= 0xDFFF) {
                        next = regex.lastIndex + 2;
                    }
                }
                if (next > text.length) {
                    break;
                }
                regex.lastIndex = next;
            }
        }
        buf.add(text.substr(last));
        return buf.toString();
    }

    /**
     * JavaScript's expansion of a replacement string (`$$`, `$&`, `` $` ``,
     * `$'`, `$n`, `$nn`) for one match.
     */
    static function expandJsReplacement(value:String, args:Array<String>):String {
        if (value.indexOf('$') < 0) {
            return value;
        }
        final groupCount = args.length - 3;
        final match = args[0];
        final position = args[args.length - 2] == null ? 0 : Std.parseInt(args[args.length - 2]);
        final str = args[args.length - 1];
        final buf = new StringBuf();
        var i = 0;
        while (i < value.length) {
            final c = StringTools.fastCodeAt(value, i);
            if (c != '$'.code || i + 1 >= value.length) {
                buf.addChar(c);
                i++;
                continue;
            }
            final n = StringTools.fastCodeAt(value, i + 1);
            if (n == '$'.code) {
                buf.addChar('$'.code);
                i += 2;
            } else if (n == '&'.code) {
                buf.add(match);
                i += 2;
            } else if (n == '`'.code) {
                buf.add(str.substring(0, position));
                i += 2;
            } else if (n == '\''.code) {
                buf.add(str.substr(position + match.length));
                i += 2;
            } else if (n >= '0'.code && n <= '9'.code) {
                final d1 = n - '0'.code;
                final n2 = i + 2 < value.length ? StringTools.fastCodeAt(value, i + 2) : -1;
                if (n2 >= '0'.code && n2 <= '9'.code && d1 * 10 + (n2 - '0'.code) >= 1 && d1 * 10 + (n2 - '0'.code) <= groupCount) {
                    final g = args[d1 * 10 + (n2 - '0'.code)];
                    buf.add(g != null ? g : '');
                    i += 3;
                } else if (d1 >= 1 && d1 <= groupCount) {
                    final g = args[d1];
                    buf.add(g != null ? g : '');
                    i += 2;
                } else {
                    buf.addChar('$'.code);
                    i++;
                }
            } else {
                buf.addChar('$'.code);
                i++;
            }
        }
        return buf.toString();
    }

    function _regularReplaceAll(findScopes:Null<Array<Range>>):Void {
        final replacePattern = this._getReplacePattern();
        // Get all the ranges (even more than the highlighted ones)
        final matches = this._findMatches(findScopes, replacePattern.hasReplacementPatterns || this._state.preserveCase, EditorOptions.MAX_SAFE_SMALL_INTEGER);

        final replaceStrings:Array<String> = [];
        for (i in 0...matches.length) {
            replaceStrings[i] = replacePattern.buildReplaceString(matches[i].matches, this._state.preserveCase);
        }

        final command = new ReplaceAllCommand(this._editor.getSelection(), [for (m in matches) m.range], replaceStrings);
        this._executeEditorCommand('replaceAll', command);
    }

    public function selectAllMatches():Void {
        if (!this._hasMatches()) {
            return;
        }

        final findScopes = this._decorations.getFindScopes();

        // Get all the ranges (even more than the highlighted ones)
        final matches = this._findMatches(findScopes, false, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        var selections = [for (m in matches) new Selection(m.range.startLineNumber, m.range.startColumn, m.range.endLineNumber, m.range.endColumn)];

        // If one of the ranges is the editor selection, then maintain it as primary
        final editorSelection = this._editor.getSelection();
        for (i in 0...selections.length) {
            final sel = selections[i];
            if (sel.equalsRange(editorSelection)) {
                selections = [editorSelection].concat(selections.slice(0, i)).concat(selections.slice(i + 1));
                break;
            }
        }

        this._editor.setSelections(cast selections);
    }

    function _executeEditorCommand(source:String, command:ICommand):Void {
        try {
            this._ignoreModelContentChanged = true;
            this._editor.pushUndoStop();
            this._editor.executeCommand(source, command);
            this._editor.pushUndoStop();
        }
        catch (e:Dynamic) {
            this._ignoreModelContentChanged = false;
            throw e;
        }
        this._ignoreModelContentChanged = false;
    }

}
