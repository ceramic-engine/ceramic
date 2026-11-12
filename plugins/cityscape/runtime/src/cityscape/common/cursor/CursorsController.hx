// Ported from vscode src/vs/editor/common/cursor/cursor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.base.common.Errors;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Strings;
import cityscape.common.CursorCommon;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon;
import cityscape.common.Model;
import cityscape.common.TextModelEvents;
import cityscape.common.ViewEvents;
import cityscape.common.ViewModel.ICoordinatesConverter;
import cityscape.common.ViewModelEventDispatcher;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.CursorCollection;
import cityscape.common.cursor.CursorDeleteOperations;
import cityscape.common.cursor.CursorTypeEditOperations;
import cityscape.common.cursor.CursorTypeOperations;
import haxe.extern.EitherType;

/**
 * The cursors of an editor: Monaco's `CursorsController`, owned by the view
 * model of an editor (one per editor; several editors on a shared model
 * each have their own).
 */
// This module is named after its main type (Monaco's cursor.ts holds it): a
// module named `Cursor` and the class `Cursor` of `OneCursor` share one C#
// file name on the Unity target, and one of them was lost.
class CursorsController extends Disposable {

    final _model:ITextModel;
    var _knownModelVersionId:Int;
    final _viewModel:ICursorSimpleModel;
    final _coordinatesConverter:ICoordinatesConverter;
    public var context:CursorContext;
    var _cursors:CursorCollection;

    var _hasFocus:Bool;
    var _isHandling:Bool;
    var _compositionState:Null<CompositionState>;
    var _columnSelectData:Null<IColumnSelectData>;
    var _autoClosedActions:Array<AutoClosedAction>;
    var _prevEditOperationType:EditOperationType;

    public function new(model:ITextModel, viewModel:ICursorSimpleModel, coordinatesConverter:ICoordinatesConverter, cursorConfig:CursorConfiguration) {
        super();
        this._model = model;
        this._knownModelVersionId = this._model.getVersionId();
        this._viewModel = viewModel;
        this._coordinatesConverter = coordinatesConverter;
        this.context = new CursorContext(this._model, this._viewModel, this._coordinatesConverter, cursorConfig);
        this._cursors = new CursorCollection(this.context);

        this._hasFocus = false;
        this._isHandling = false;
        this._compositionState = null;
        this._columnSelectData = null;
        this._autoClosedActions = [];
        this._prevEditOperationType = EditOperationType.Other;
    }

    override public function dispose():Void {
        this._cursors.dispose();
        for (action in this._autoClosedActions) {
            action.dispose();
        }
        this._autoClosedActions = [];
        super.dispose();
    }

    public function updateConfiguration(cursorConfig:CursorConfiguration):Void {
        this.context = new CursorContext(this._model, this._viewModel, this._coordinatesConverter, cursorConfig);
        this._cursors.updateContext(this.context);
    }

    public function onLineMappingChanged(eventsCollector:ViewModelEventsCollector):Void {
        if (this._knownModelVersionId != this._model.getVersionId()) {
            // There are model change events that I didn't yet receive.
            //
            // This can happen when editing the model, and the view model receives the change events first,
            // and the view model emits line mapping changed events, all before the cursor gets a chance to
            // recover from markers.
            //
            // The model change listener above will be called soon and we'll ensure a valid cursor state there.
            return;
        }
        // Ensure valid state
        this.setStates(eventsCollector, 'viewModel', CursorChangeReason.NotSet, cast this.getCursorStates());
    }

    public function setHasFocus(hasFocus:Bool):Void {
        this._hasFocus = hasFocus;
    }

    function _validateAutoClosedActions():Void {
        if (this._autoClosedActions.length > 0) {
            final selections:Array<Range> = cast this._cursors.getSelections();
            var i = 0;
            while (i < this._autoClosedActions.length) {
                final autoClosedAction = this._autoClosedActions[i];
                if (!autoClosedAction.isValid(selections)) {
                    autoClosedAction.dispose();
                    this._autoClosedActions.splice(i, 1);
                    i--;
                }
                i++;
            }
        }
    }

    // ------ some getters/setters

    public function getPrimaryCursorState():CursorState {
        return this._cursors.getPrimaryCursor();
    }

    public function getLastAddedCursorIndex():Int {
        return this._cursors.getLastAddedCursorIndex();
    }

    public function getCursorStates():Array<CursorState> {
        return this._cursors.getAll();
    }

    public function setStates(eventsCollector:ViewModelEventsCollector, source:Null<String>, reason:CursorChangeReason, states:Null<Array<PartialCursorState>>):Bool {
        var reachedMaxCursorCount = false;
        final multiCursorLimit = this.context.cursorConfig.multiCursorLimit;
        if (states != null && states.length > multiCursorLimit) {
            states = states.slice(0, multiCursorLimit);
            reachedMaxCursorCount = true;
        }

        final oldState = CursorModelState.from(this._model, this);

        this._cursors.setStates(states);
        this._cursors.normalize();
        this._columnSelectData = null;

        this._validateAutoClosedActions();

        return this._emitStateChangedIfNecessary(eventsCollector, source, reason, oldState, reachedMaxCursorCount);
    }

    public function setCursorColumnSelectData(columnSelectData:IColumnSelectData):Void {
        this._columnSelectData = columnSelectData;
    }

    public function revealAll(eventsCollector:ViewModelEventsCollector, source:Null<String>, minimalReveal:Bool, verticalType:VerticalRevealType, revealHorizontal:Bool, scrollType:ScrollType):Void {
        final viewPositions = this._cursors.getViewPositions();

        var revealViewRange:Null<Range> = null;
        var revealViewSelections:Null<Array<Selection>> = null;
        if (viewPositions.length > 1) {
            revealViewSelections = this._cursors.getViewSelections();
        }
        else {
            revealViewRange = Range.fromPositions(viewPositions[0], viewPositions[0]);
        }

        eventsCollector.emitViewEvent(new ViewRevealRangeRequestEvent(source, minimalReveal, revealViewRange, revealViewSelections, verticalType, revealHorizontal, scrollType));
    }

    public function revealPrimary(eventsCollector:ViewModelEventsCollector, source:Null<String>, minimalReveal:Bool, verticalType:VerticalRevealType, revealHorizontal:Bool, scrollType:ScrollType):Void {
        final primaryCursor = this._cursors.getPrimaryCursor();
        final revealViewSelections = [primaryCursor.viewState.selection];
        eventsCollector.emitViewEvent(new ViewRevealRangeRequestEvent(source, minimalReveal, null, revealViewSelections, verticalType, revealHorizontal, scrollType));
    }

    public function saveState():Array<ICursorState> {

        final result:Array<ICursorState> = [];

        final selections = this._cursors.getSelections();
        for (i in 0...selections.length) {
            final selection = selections[i];

            result.push({
                inSelectionMode: !selection.isEmpty(),
                selectionStart: {
                    lineNumber: selection.selectionStartLineNumber,
                    column: selection.selectionStartColumn,
                },
                position: {
                    lineNumber: selection.positionLineNumber,
                    column: selection.positionColumn,
                }
            });
        }

        return result;
    }

    public function restoreState(eventsCollector:ViewModelEventsCollector, states:Array<ICursorState>):Void {

        final desiredSelections:Array<Selection> = [];

        for (i in 0...states.length) {
            final state = states[i];

            var positionLineNumber = 1;
            var positionColumn = 1;

            // Avoid missing properties on the literal (the state may come from JSON)
            final position:Dynamic = state.position;
            final selectionStart:Dynamic = state.selectionStart;
            if (position != null && JsValues.truthy(position.lineNumber)) {
                positionLineNumber = position.lineNumber;
            }
            if (position != null && JsValues.truthy(position.column)) {
                positionColumn = position.column;
            }

            var selectionStartLineNumber = positionLineNumber;
            var selectionStartColumn = positionColumn;

            // Avoid missing properties on the literal
            if (selectionStart != null && JsValues.truthy(selectionStart.lineNumber)) {
                selectionStartLineNumber = selectionStart.lineNumber;
            }
            if (selectionStart != null && JsValues.truthy(selectionStart.column)) {
                selectionStartColumn = selectionStart.column;
            }

            desiredSelections.push(new Selection(selectionStartLineNumber, selectionStartColumn, positionLineNumber, positionColumn));
        }

        this.setStates(eventsCollector, 'restoreState', CursorChangeReason.NotSet, CursorState.fromSelections(desiredSelections));
        this.revealAll(eventsCollector, 'restoreState', false, VerticalRevealType.Simple, true, ScrollType.Immediate);
    }

    /**
     * `event` is an `InternalModelContentChangeEvent` or a
     * `ModelInjectedTextChangedEvent`.
     */
    public function onModelContentChanged(eventsCollector:ViewModelEventsCollector, event:EitherType<InternalModelContentChangeEvent, ModelInjectedTextChangedEvent>):Void {
        if (Std.isOfType(event, ModelInjectedTextChangedEvent)) {
            // If injected texts change, the view positions of all cursors need to be updated.
            if (this._isHandling) {
                // The view positions will be updated when handling finishes
                return;
            }
            // setStates might remove markers, which could trigger a decoration change.
            // If there are injected text decorations for that line, `onModelContentChanged` is emitted again
            // and an endless recursion happens.
            // _isHandling prevents that.
            this._isHandling = true;
            try {
                this.setStates(eventsCollector, 'modelChange', CursorChangeReason.NotSet, cast this.getCursorStates());
            }
            catch (e:Dynamic) {
                this._isHandling = false;
                throw e;
            }
            this._isHandling = false;
        }
        else {
            final e = (cast event : InternalModelContentChangeEvent).rawContentChangedEvent;
            this._knownModelVersionId = e.versionId;
            if (this._isHandling) {
                return;
            }

            final hadFlushEvent = e.containsEvent(RawContentChangedType.Flush);
            this._prevEditOperationType = EditOperationType.Other;

            if (hadFlushEvent) {
                // a model.setValue() was called
                this._cursors.dispose();
                this._cursors = new CursorCollection(this.context);
                this._validateAutoClosedActions();
                this._emitStateChangedIfNecessary(eventsCollector, 'model', CursorChangeReason.ContentFlush, null, false);
            }
            else {
                if (this._hasFocus && e.resultingSelection != null && e.resultingSelection.length > 0) {
                    final cursorState = CursorState.fromSelections(e.resultingSelection);
                    if (this.setStates(eventsCollector, 'modelChange', e.isUndoing ? CursorChangeReason.Undo : e.isRedoing ? CursorChangeReason.Redo : CursorChangeReason.RecoverFromMarkers, cursorState)) {
                        this.revealAll(eventsCollector, 'modelChange', false, VerticalRevealType.Simple, true, ScrollType.Smooth);
                    }
                }
                else {
                    final selectionsFromMarkers = this._cursors.readSelectionFromMarkers();
                    this.setStates(eventsCollector, 'modelChange', CursorChangeReason.RecoverFromMarkers, CursorState.fromSelections(selectionsFromMarkers));
                }
            }
        }
    }

    public function getSelection():Selection {
        return this._cursors.getPrimaryCursor().modelState.selection;
    }

    public function getTopMostViewPosition():Position {
        return this._cursors.getTopMostViewPosition();
    }

    public function getBottomMostViewPosition():Position {
        return this._cursors.getBottomMostViewPosition();
    }

    public function getCursorColumnSelectData():IColumnSelectData {
        if (this._columnSelectData != null) {
            return this._columnSelectData;
        }
        final primaryCursor = this._cursors.getPrimaryCursor();
        final viewSelectionStart = primaryCursor.viewState.selectionStart.getStartPosition();
        final viewPosition = primaryCursor.viewState.position;
        return {
            isReal: false,
            fromViewLineNumber: viewSelectionStart.lineNumber,
            fromViewVisualColumn: this.context.cursorConfig.visibleColumnFromColumn(this._viewModel, viewSelectionStart),
            toViewLineNumber: viewPosition.lineNumber,
            toViewVisualColumn: this.context.cursorConfig.visibleColumnFromColumn(this._viewModel, viewPosition),
        };
    }

    public function getSelections():Array<Selection> {
        return this._cursors.getSelections();
    }

    public function getPosition():Position {
        return this._cursors.getPrimaryCursor().modelState.position;
    }

    public function setSelections(eventsCollector:ViewModelEventsCollector, source:Null<String>, selections:Array<ISelection>, reason:CursorChangeReason):Void {
        this.setStates(eventsCollector, source, reason, CursorState.fromModelSelections(selections));
    }

    public function getPrevEditOperationType():EditOperationType {
        return this._prevEditOperationType;
    }

    public function setPrevEditOperationType(type:EditOperationType):Void {
        this._prevEditOperationType = type;
    }

    // ------ auxiliary handling logic

    function _pushAutoClosedAction(autoClosedCharactersRanges:Array<Range>, autoClosedEnclosingRanges:Array<Range>):Void {
        final autoClosedCharactersDeltaDecorations:Array<IModelDeltaDecoration> = [];
        final autoClosedEnclosingDeltaDecorations:Array<IModelDeltaDecoration> = [];

        for (i in 0...autoClosedCharactersRanges.length) {
            autoClosedCharactersDeltaDecorations.push({
                range: autoClosedCharactersRanges[i],
                options: {
                    description: 'auto-closed-character',
                    inlineClassName: 'auto-closed-character',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges
                }
            });
            autoClosedEnclosingDeltaDecorations.push({
                range: autoClosedEnclosingRanges[i],
                options: {
                    description: 'auto-closed-enclosing',
                    stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges
                }
            });
        }

        final autoClosedCharactersDecorations = this._model.deltaDecorations([], autoClosedCharactersDeltaDecorations);
        final autoClosedEnclosingDecorations = this._model.deltaDecorations([], autoClosedEnclosingDeltaDecorations);
        this._autoClosedActions.push(new AutoClosedAction(this._model, autoClosedCharactersDecorations, autoClosedEnclosingDecorations));
    }

    function _executeEditOperation(opResult:Null<EditOperationResult>):Void {

        if (opResult == null) {
            // Nothing to execute
            return;
        }

        if (opResult.shouldPushStackElementBefore) {
            this._model.pushStackElement();
        }

        final result = CommandExecutor.executeCommands(this._model, this._cursors.getSelections(), opResult.commands);
        if (result != null) {
            // The commands were applied correctly
            this._interpretCommandResult(result);

            // Check for auto-closing closed characters
            final autoClosedCharactersRanges:Array<Range> = [];
            final autoClosedEnclosingRanges:Array<Range> = [];

            for (i in 0...opResult.commands.length) {
                final command = Std.downcast(opResult.commands[i], BaseTypeWithAutoClosingCommand);
                if (command != null && command.enclosingRange != null && command.closeCharacterRange != null) {
                    autoClosedCharactersRanges.push(command.closeCharacterRange);
                    autoClosedEnclosingRanges.push(command.enclosingRange);
                }
            }

            if (autoClosedCharactersRanges.length > 0) {
                this._pushAutoClosedAction(autoClosedCharactersRanges, autoClosedEnclosingRanges);
            }

            this._prevEditOperationType = opResult.type;
        }

        if (opResult.shouldPushStackElementAfter) {
            this._model.pushStackElement();
        }
    }

    function _interpretCommandResult(cursorState:Null<Array<Selection>>):Void {
        if (cursorState == null || cursorState.length == 0) {
            cursorState = this._cursors.readSelectionFromMarkers();
        }

        this._columnSelectData = null;
        this._cursors.setSelections(cursorState);
        this._cursors.normalize();
    }

    // -----------------------------------------------------------------------------------------------------------
    // ----- emitting events

    function _emitStateChangedIfNecessary(eventsCollector:ViewModelEventsCollector, source:Null<String>, reason:CursorChangeReason, oldState:Null<CursorModelState>, reachedMaxCursorCount:Bool):Bool {
        final newState = CursorModelState.from(this._model, this);
        if (newState.equals(oldState)) {
            return false;
        }

        final selections = this._cursors.getSelections();
        final viewSelections = this._cursors.getViewSelections();

        // Let the view get the event first.
        eventsCollector.emitViewEvent(new ViewCursorStateChangedEvent(viewSelections, selections, reason));

        // Only after the view has been notified, let the rest of the world know...
        var modelStateChanged = (oldState == null || oldState.cursorState.length != newState.cursorState.length);
        if (!modelStateChanged) {
            for (i in 0...newState.cursorState.length) {
                if (!newState.cursorState[i].modelState.equals(oldState.cursorState[i].modelState)) {
                    modelStateChanged = true;
                    break;
                }
            }
        }
        if (modelStateChanged) {
            final oldSelections = oldState != null ? [for (s in oldState.cursorState) s.modelState.selection] : null;
            final oldModelVersionId = oldState != null ? oldState.modelVersionId : 0;
            eventsCollector.emitOutgoingEvent(new CursorStateChangedEvent(oldSelections, selections, oldModelVersionId, newState.modelVersionId, (source != null && source.length > 0) ? source : 'keyboard', reason, reachedMaxCursorCount));
        }

        return true;
    }

    // -----------------------------------------------------------------------------------------------------------
    // ----- handlers beyond this point

    /**
     * Monaco's `[openCharIndex, closeCharIndex][]`, as pairs of numbers.
     */
    function _findAutoClosingPairs(edits:Array<IIdentifiedSingleEditOperation>):Null<Array<Array<Int>>> {
        if (edits.length == 0) {
            return null;
        }

        final indices:Array<Array<Int>> = [];
        for (i in 0...edits.length) {
            final edit = edits[i];
            if (edit.text == null || edit.text.length == 0 || edit.text.indexOf('\n') >= 0) {
                return null;
            }

            // `edit.text.match(/([)\]}>'"`])([^)\]}>'"`]*)$/)`: the last closing character and what follows it
            final text = edit.text;
            var closeCharIndex = -1;
            var j = text.length - 1;
            while (j >= 0) {
                if (isCloseCharacter(StringTools.fastCodeAt(text, j))) {
                    closeCharIndex = j;
                    break;
                }
                j--;
            }
            if (closeCharIndex == -1) {
                return null;
            }
            final closeChar = text.charAt(closeCharIndex);

            final autoClosingPairsCandidates = this.context.cursorConfig.autoClosingPairs.autoClosingPairsCloseSingleChar.get(closeChar);
            if (autoClosingPairsCandidates == null || autoClosingPairsCandidates.length != 1) {
                return null;
            }

            final openChar = autoClosingPairsCandidates[0].open;
            // JavaScript's lastIndexOf clamps a negative start to 0
            final openCharIndex = text.lastIndexOf(openChar, closeCharIndex - 1 < 0 ? 0 : closeCharIndex - 1);
            if (openCharIndex == -1) {
                return null;
            }

            indices.push([openCharIndex, closeCharIndex]);
        }

        return indices;
    }

    static inline function isCloseCharacter(c:Int):Bool {
        return c == ')'.code || c == ']'.code || c == '}'.code || c == '>'.code || c == '\''.code || c == '"'.code || c == '`'.code;
    }

    public function executeEdits(eventsCollector:ViewModelEventsCollector, source:Null<String>, edits:Array<IIdentifiedSingleEditOperation>, cursorStateComputer:ICursorStateComputer):Void {
        var autoClosingIndices:Null<Array<Array<Int>>> = null;
        if (source == 'snippet') {
            autoClosingIndices = this._findAutoClosingPairs(edits);
        }

        if (autoClosingIndices != null) {
            edits[0]._isTracked = true;
        }
        final autoClosedCharactersRanges:Array<Range> = [];
        final autoClosedEnclosingRanges:Array<Range> = [];
        final selections = this._model.pushEditOperations(this.getSelections(), edits, (undoEdits) -> {
            if (autoClosingIndices != null) {
                for (i in 0...autoClosingIndices.length) {
                    final openCharInnerIndex = autoClosingIndices[i][0];
                    final closeCharInnerIndex = autoClosingIndices[i][1];
                    final undoEdit = undoEdits[i];
                    final lineNumber = undoEdit.range.startLineNumber;
                    final openCharIndex = undoEdit.range.startColumn - 1 + openCharInnerIndex;
                    final closeCharIndex = undoEdit.range.startColumn - 1 + closeCharInnerIndex;

                    autoClosedCharactersRanges.push(new Range(lineNumber, closeCharIndex + 1, lineNumber, closeCharIndex + 2));
                    autoClosedEnclosingRanges.push(new Range(lineNumber, openCharIndex + 1, lineNumber, closeCharIndex + 2));
                }
            }
            final selections = cursorStateComputer(undoEdits);
            if (selections != null) {
                // Don't recover the selection from markers because
                // we know what it should be.
                this._isHandling = true;
            }

            return selections;
        });
        if (selections != null) {
            this._isHandling = false;
            this.setStates(eventsCollector, source, CursorChangeReason.NotSet, CursorState.fromSelections(selections));
        }
        if (autoClosedCharactersRanges.length > 0) {
            this._pushAutoClosedAction(autoClosedCharactersRanges, autoClosedEnclosingRanges);
        }
    }

    function _executeEdit(callback:() -> Void, eventsCollector:ViewModelEventsCollector, source:Null<String>, cursorChangeReason:CursorChangeReason = CursorChangeReason.NotSet):Void {
        if (this.context.cursorConfig.readOnly) {
            // we cannot edit when read only...
            return;
        }

        final oldState = CursorModelState.from(this._model, this);
        this._cursors.stopTrackingSelections();
        this._isHandling = true;

        try {
            this._cursors.ensureValidState();
            callback();
        }
        catch (err:Dynamic) {
            Errors.onUnexpectedError(err);
        }

        this._isHandling = false;
        this._cursors.startTrackingSelections();
        this._validateAutoClosedActions();
        if (this._emitStateChangedIfNecessary(eventsCollector, source, cursorChangeReason, oldState, false)) {
            this.revealAll(eventsCollector, source, false, VerticalRevealType.Simple, true, ScrollType.Smooth);
        }
    }

    public function getAutoClosedCharacters():Array<Range> {
        return AutoClosedAction.getAllAutoClosedCharacters(this._autoClosedActions);
    }

    public function startComposition(eventsCollector:ViewModelEventsCollector):Void {
        this._compositionState = new CompositionState(this._model, this.getSelections());
    }

    public function endComposition(eventsCollector:ViewModelEventsCollector, ?source:String):Void {
        final compositionOutcome = this._compositionState != null ? this._compositionState.deduceOutcome(this._model, this.getSelections()) : null;
        this._compositionState = null;

        this._executeEdit(() -> {
            if (source == 'keyboard') {
                // composition finishes, let's check if we need to auto complete if necessary.
                this._executeEditOperation(TypeOperations.compositionEndWithInterceptors(this._prevEditOperationType, this.context.cursorConfig, this._model, compositionOutcome, this.getSelections(), this.getAutoClosedCharacters()));
            }
        }, eventsCollector, source);
    }

    public function type(eventsCollector:ViewModelEventsCollector, text:String, ?source:String):Void {
        this._executeEdit(() -> {
            if (source == 'keyboard') {
                // If this event is coming straight from the keyboard, look for electric characters and enter

                final len = text.length;
                var offset = 0;
                while (offset < len) {
                    final charLength = Strings.nextCharLength(text, offset);
                    final chr = text.substr(offset, charLength);

                    // Here we must interpret each typed character individually
                    this._executeEditOperation(TypeOperations.typeWithInterceptors(this._compositionState != null, this._prevEditOperationType, this.context.cursorConfig, this._model, this.getSelections(), this.getAutoClosedCharacters(), chr));

                    offset += charLength;
                }

            }
            else {
                this._executeEditOperation(TypeOperations.typeWithoutInterceptors(this._prevEditOperationType, this.context.cursorConfig, this._model, this.getSelections(), text));
            }
        }, eventsCollector, source);
    }

    public function compositionType(eventsCollector:ViewModelEventsCollector, text:String, replacePrevCharCnt:Int, replaceNextCharCnt:Int, positionDelta:Int, ?source:String):Void {
        if (text.length == 0 && replacePrevCharCnt == 0 && replaceNextCharCnt == 0) {
            // this edit is a no-op
            if (positionDelta != 0) {
                // but it still wants to move the cursor
                final newSelections:Array<ISelection> = [for (selection in this.getSelections()) {
                    final position = selection.getPosition();
                    (new Selection(position.lineNumber, position.column + positionDelta, position.lineNumber, position.column + positionDelta) : ISelection);
                }];
                this.setSelections(eventsCollector, source, newSelections, CursorChangeReason.NotSet);
            }
            return;
        }
        this._executeEdit(() -> {
            this._executeEditOperation(TypeOperations.compositionType(this._prevEditOperationType, this.context.cursorConfig, this._model, this.getSelections(), text, replacePrevCharCnt, replaceNextCharCnt, positionDelta));
        }, eventsCollector, source);
    }

    public function paste(eventsCollector:ViewModelEventsCollector, text:String, pasteOnNewLine:Bool, ?multicursorText:Array<String>, ?source:String):Void {
        this._executeEdit(() -> {
            this._executeEditOperation(TypeOperations.paste(this.context.cursorConfig, this._model, this.getSelections(), text, pasteOnNewLine, multicursorText != null ? multicursorText : []));
        }, eventsCollector, source, CursorChangeReason.Paste);
    }

    public function cut(eventsCollector:ViewModelEventsCollector, ?source:String):Void {
        this._executeEdit(() -> {
            this._executeEditOperation(DeleteOperations.cut(this.context.cursorConfig, this._model, this.getSelections()));
        }, eventsCollector, source);
    }

    public function executeCommand(eventsCollector:ViewModelEventsCollector, command:ICommand, ?source:String):Void {
        this._executeEdit(() -> {
            this._cursors.killSecondaryCursors();

            this._executeEditOperation(new EditOperationResult(EditOperationType.Other, [command], {
                shouldPushStackElementBefore: false,
                shouldPushStackElementAfter: false
            }));
        }, eventsCollector, source);
    }

    public function executeCommands(eventsCollector:ViewModelEventsCollector, commands:Array<Null<ICommand>>, ?source:String):Void {
        this._executeEdit(() -> {
            this._executeEditOperation(new EditOperationResult(EditOperationType.Other, commands, {
                shouldPushStackElementBefore: false,
                shouldPushStackElementAfter: false
            }));
        }, eventsCollector, source);
    }

}

/**
 * A snapshot of the cursor and the model state
 */
class CursorModelState {

    public static function from(model:ITextModel, cursor:CursorsController):CursorModelState {
        return new CursorModelState(model.getVersionId(), cursor.getCursorStates());
    }

    public final modelVersionId:Int;
    public final cursorState:Array<CursorState>;

    public function new(modelVersionId:Int, cursorState:Array<CursorState>) {
        this.modelVersionId = modelVersionId;
        this.cursorState = cursorState;
    }

    public function equals(other:Null<CursorModelState>):Bool {
        if (other == null) {
            return false;
        }
        if (this.modelVersionId != other.modelVersionId) {
            return false;
        }
        if (this.cursorState.length != other.cursorState.length) {
            return false;
        }
        for (i in 0...this.cursorState.length) {
            if (!this.cursorState[i].equals(other.cursorState[i])) {
                return false;
            }
        }
        return true;
    }

}

class AutoClosedAction {

    public static function getAllAutoClosedCharacters(autoClosedActions:Array<AutoClosedAction>):Array<Range> {
        var autoClosedCharacters:Array<Range> = [];
        for (autoClosedAction in autoClosedActions) {
            autoClosedCharacters = autoClosedCharacters.concat(autoClosedAction.getAutoClosedCharactersRanges());
        }
        return autoClosedCharacters;
    }

    final _model:ITextModel;

    var _autoClosedCharactersDecorations:Array<String>;
    var _autoClosedEnclosingDecorations:Array<String>;

    public function new(model:ITextModel, autoClosedCharactersDecorations:Array<String>, autoClosedEnclosingDecorations:Array<String>) {
        this._model = model;
        this._autoClosedCharactersDecorations = autoClosedCharactersDecorations;
        this._autoClosedEnclosingDecorations = autoClosedEnclosingDecorations;
    }

    public function dispose():Void {
        this._autoClosedCharactersDecorations = this._model.deltaDecorations(this._autoClosedCharactersDecorations, []);
        this._autoClosedEnclosingDecorations = this._model.deltaDecorations(this._autoClosedEnclosingDecorations, []);
    }

    public function getAutoClosedCharactersRanges():Array<Range> {
        final result:Array<Range> = [];
        for (i in 0...this._autoClosedCharactersDecorations.length) {
            final decorationRange = this._model.getDecorationRange(this._autoClosedCharactersDecorations[i]);
            if (decorationRange != null) {
                result.push(decorationRange);
            }
        }
        return result;
    }

    public function isValid(selections:Array<Range>):Bool {
        final enclosingRanges:Array<Range> = [];
        for (i in 0...this._autoClosedEnclosingDecorations.length) {
            final decorationRange = this._model.getDecorationRange(this._autoClosedEnclosingDecorations[i]);
            if (decorationRange != null) {
                enclosingRanges.push(decorationRange);
                if (decorationRange.startLineNumber != decorationRange.endLineNumber) {
                    // Stop tracking if the range becomes multiline...
                    return false;
                }
            }
        }
        haxe.ds.ArraySort.sort(enclosingRanges, Range.compareRangesUsingStarts);

        haxe.ds.ArraySort.sort(selections, Range.compareRangesUsingStarts);

        for (i in 0...selections.length) {
            if (i >= enclosingRanges.length) {
                return false;
            }
            if (!enclosingRanges[i].strictContainsRange(selections[i])) {
                return false;
            }
        }

        return true;
    }

}

private typedef IExecContext = {
    final model:ITextModel;
    final selectionsBefore:Array<Selection>;
    final trackedRanges:Array<String>;
    final trackedRangesDirection:Array<SelectionDirection>;
}

private typedef ICommandData = {
    var operations:Array<IIdentifiedSingleEditOperation>;
    var hadTrackedEditOperation:Bool;
}

/**
 * The builder given to `ICommand.getEditOperations` (Monaco's object literal
 * of closures in `_getEditOperationsFromCommand`).
 */
private class EditOperationBuilder implements IEditOperationBuilder {

    final ctx:IExecContext;
    final majorIdentifier:Int;
    final command:ICommand;
    public final operations:Array<IIdentifiedSingleEditOperation> = [];
    var operationMinor = 0;
    public var hadTrackedEditOperation = false;

    public function new(ctx:IExecContext, majorIdentifier:Int, command:ICommand) {
        this.ctx = ctx;
        this.majorIdentifier = majorIdentifier;
        this.command = command;
    }

    public function addEditOperation(range:IRange, text:Null<String>, ?forceMoveMarkers:Bool):Void {
        if (Range.isEmptyStatic(range) && text == '') {
            // This command wants to add a no-op => no thank you
            return;
        }
        operations.push({
            identifier: {
                major: majorIdentifier,
                minor: operationMinor++
            },
            range: range,
            text: text,
            forceMoveMarkers: forceMoveMarkers == true,
            isAutoWhitespaceEdit: command.insertsAutoWhitespace
        });
    }

    public function addTrackedEditOperation(selection:IRange, text:Null<String>, ?forceMoveMarkers:Bool):Void {
        hadTrackedEditOperation = true;
        addEditOperation(selection, text, forceMoveMarkers);
    }

    public function trackSelection(_selection:Selection, ?trackPreviousOnEmpty:Bool):String {
        final selection = _selection;
        var stickiness:TrackedRangeStickiness;
        if (selection.isEmpty()) {
            if (trackPreviousOnEmpty != null) {
                if (trackPreviousOnEmpty) {
                    stickiness = TrackedRangeStickiness.GrowsOnlyWhenTypingBefore;
                }
                else {
                    stickiness = TrackedRangeStickiness.GrowsOnlyWhenTypingAfter;
                }
            }
            else {
                // Try to lock it with surrounding text
                final maxLineColumn = ctx.model.getLineMaxColumn(selection.startLineNumber);
                if (selection.startColumn == maxLineColumn) {
                    stickiness = TrackedRangeStickiness.GrowsOnlyWhenTypingBefore;
                }
                else {
                    stickiness = TrackedRangeStickiness.GrowsOnlyWhenTypingAfter;
                }
            }
        }
        else {
            stickiness = TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges;
        }

        final l = ctx.trackedRanges.length;
        final id = ctx.model._setTrackedRange(null, selection, stickiness);
        ctx.trackedRanges[l] = id;
        ctx.trackedRangesDirection[l] = selection.getDirection();
        return Std.string(l);
    }

}

/**
 * The helper given to `ICommand.computeCursorState`.
 */
private class CursorStateComputerData implements ICursorStateComputerData {

    final ctx:IExecContext;
    final inverseEditOperations:Array<IValidEditOperation>;

    public function new(ctx:IExecContext, inverseEditOperations:Array<IValidEditOperation>) {
        this.ctx = ctx;
        this.inverseEditOperations = inverseEditOperations;
    }

    public function getInverseEditOperations():Array<IValidEditOperation> {
        return inverseEditOperations;
    }

    public function getTrackedSelection(id:String):Selection {
        final idx = Std.parseInt(id);
        final range = ctx.model._getTrackedRange(ctx.trackedRanges[idx]);
        if (ctx.trackedRangesDirection[idx] == SelectionDirection.LTR) {
            return new Selection(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn);
        }
        return new Selection(range.endLineNumber, range.endColumn, range.startLineNumber, range.startColumn);
    }

}

class CommandExecutor {

    public static function executeCommands(model:ITextModel, selectionsBefore:Array<Selection>, commands:Array<Null<ICommand>>):Null<Array<Selection>> {

        final ctx:IExecContext = {
            model: model,
            selectionsBefore: selectionsBefore,
            trackedRanges: [],
            trackedRangesDirection: []
        };

        final result = _innerExecuteCommands(ctx, commands);

        for (i in 0...ctx.trackedRanges.length) {
            ctx.model._setTrackedRange(ctx.trackedRanges[i], null, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges);
        }

        return result;
    }

    static function _innerExecuteCommands(ctx:IExecContext, commands:Array<Null<ICommand>>):Null<Array<Selection>> {

        if (_arrayIsEmpty(commands)) {
            return null;
        }

        final commandsData = _getEditOperations(ctx, commands);
        if (commandsData.operations.length == 0) {
            return null;
        }

        final rawOperations = commandsData.operations;

        final loserCursorsMap = _getLoserCursorMap(rawOperations);
        if (loserCursorsMap.exists(0)) {
            // These commands are very messed up
            trace('Ignoring commands');
            return null;
        }

        // Remove operations belonging to losing cursors
        final filteredOperations:Array<IIdentifiedSingleEditOperation> = [];
        for (i in 0...rawOperations.length) {
            if (!loserCursorsMap.exists(rawOperations[i].identifier.major)) {
                filteredOperations.push(rawOperations[i]);
            }
        }

        // TODO@Alex: find a better way to do this.
        // give the hint that edit operations are tracked to the model
        if (commandsData.hadTrackedEditOperation && filteredOperations.length > 0) {
            filteredOperations[0]._isTracked = true;
        }
        var selectionsAfter = ctx.model.pushEditOperations(ctx.selectionsBefore, filteredOperations, (inverseEditOperations:Array<IValidEditOperation>) -> {
            final groupedInverseEditOperations:Array<Array<IValidEditOperation>> = [];
            for (i in 0...ctx.selectionsBefore.length) {
                groupedInverseEditOperations[i] = [];
            }
            for (op in inverseEditOperations) {
                if (op.identifier == null) {
                    // perhaps auto whitespace trim edits
                    continue;
                }
                groupedInverseEditOperations[op.identifier.major].push(op);
            }
            final minorBasedSorter = (a:IValidEditOperation, b:IValidEditOperation) -> {
                return a.identifier.minor - b.identifier.minor;
            };
            final cursorSelections:Array<Selection> = [];
            for (i in 0...ctx.selectionsBefore.length) {
                if (groupedInverseEditOperations[i].length > 0) {
                    haxe.ds.ArraySort.sort(groupedInverseEditOperations[i], minorBasedSorter);
                    cursorSelections[i] = commands[i].computeCursorState(ctx.model, new CursorStateComputerData(ctx, groupedInverseEditOperations[i]));
                }
                else {
                    cursorSelections[i] = ctx.selectionsBefore[i];
                }
            }
            return cursorSelections;
        });
        if (selectionsAfter == null) {
            selectionsAfter = ctx.selectionsBefore;
        }

        // Extract losing cursors
        final losingCursors:Array<Int> = [for (losingCursorIndex in loserCursorsMap.keys()) losingCursorIndex];

        // Sort losing cursors descending
        losingCursors.sort((a:Int, b:Int) -> {
            return b - a;
        });

        // Remove losing cursors
        for (losingCursor in losingCursors) {
            selectionsAfter.splice(losingCursor, 1);
        }

        return selectionsAfter;
    }

    static function _arrayIsEmpty(commands:Array<Null<ICommand>>):Bool {
        for (i in 0...commands.length) {
            if (commands[i] != null) {
                return false;
            }
        }
        return true;
    }

    static function _getEditOperations(ctx:IExecContext, commands:Array<Null<ICommand>>):ICommandData {
        var operations:Array<IIdentifiedSingleEditOperation> = [];
        var hadTrackedEditOperation:Bool = false;

        for (i in 0...commands.length) {
            final command = commands[i];
            if (command != null) {
                final r = _getEditOperationsFromCommand(ctx, i, command);
                operations = operations.concat(r.operations);
                hadTrackedEditOperation = hadTrackedEditOperation || r.hadTrackedEditOperation;
            }
        }
        return {
            operations: operations,
            hadTrackedEditOperation: hadTrackedEditOperation
        };
    }

    static function _getEditOperationsFromCommand(ctx:IExecContext, majorIdentifier:Int, command:ICommand):ICommandData {
        // This method acts as a transaction, if the command fails
        // everything it has done is ignored
        final editOperationBuilder = new EditOperationBuilder(ctx, majorIdentifier, command);

        try {
            command.getEditOperations(ctx.model, editOperationBuilder);
        }
        catch (e:Dynamic) {
            // TODO@Alex use notification service if this should be user facing
            // e.friendlyMessage = nls.localize('corrupt.commands', "Unexpected exception while executing command.");
            Errors.onUnexpectedError(e);
            return {
                operations: [],
                hadTrackedEditOperation: false
            };
        }

        return {
            operations: editOperationBuilder.operations,
            hadTrackedEditOperation: editOperationBuilder.hadTrackedEditOperation
        };
    }

    static function _getLoserCursorMap(operations:Array<IIdentifiedSingleEditOperation>):Map<Int, Bool> {
        // This is destructive on the array
        operations = operations.slice(0);

        // Sort operations with last one first
        haxe.ds.ArraySort.sort(operations, (a:IIdentifiedSingleEditOperation, b:IIdentifiedSingleEditOperation) -> {
            // Note the minus!
            return -(Range.compareRangesUsingEnds(a.range, b.range));
        });

        // Operations can not overlap!
        final loserCursorsMap = new Map<Int, Bool>();

        var i = 1;
        while (i < operations.length) {
            final previousOp = operations[i - 1];
            final currentOp = operations[i];

            if (Range.getStartPositionStatic(previousOp.range).isBefore(Range.getEndPositionStatic(currentOp.range))) {

                var loserMajor:Int;

                if (previousOp.identifier.major > currentOp.identifier.major) {
                    // previousOp loses the battle
                    loserMajor = previousOp.identifier.major;
                }
                else {
                    loserMajor = currentOp.identifier.major;
                }

                loserCursorsMap.set(loserMajor, true);

                var j = 0;
                while (j < operations.length) {
                    if (operations[j].identifier.major == loserMajor) {
                        operations.splice(j, 1);
                        if (j < i) {
                            i--;
                        }
                        j--;
                    }
                    j++;
                }

                if (i > 0) {
                    i--;
                }
            }
            i++;
        }

        return loserCursorsMap;
    }

}

class CompositionLineState {

    public final text:String;
    public final startSelection:Int;
    public final endSelection:Int;

    public function new(text:String, startSelection:Int, endSelection:Int) {
        this.text = text;
        this.startSelection = startSelection;
        this.endSelection = endSelection;
    }

}

class CompositionState {

    final _original:Null<Array<CompositionLineState>>;

    static function _capture(textModel:ITextModel, selections:Array<Selection>):Null<Array<CompositionLineState>> {
        final result:Array<CompositionLineState> = [];
        for (selection in selections) {
            if (selection.startLineNumber != selection.endLineNumber) {
                return null;
            }
            result.push(new CompositionLineState(
                textModel.getLineContent(selection.startLineNumber),
                selection.startColumn - 1,
                selection.endColumn - 1
            ));
        }
        return result;
    }

    public function new(textModel:ITextModel, selections:Array<Selection>) {
        this._original = CompositionState._capture(textModel, selections);
    }

    /**
     * Returns the inserted text during this composition.
     * If the composition resulted in existing text being changed (i.e. not a pure insertion) it returns null.
     */
    public function deduceOutcome(textModel:ITextModel, selections:Array<Selection>):Null<Array<CompositionOutcome>> {
        if (this._original == null) {
            return null;
        }
        final current = CompositionState._capture(textModel, selections);
        if (current == null) {
            return null;
        }
        if (this._original.length != current.length) {
            return null;
        }
        final result:Array<CompositionOutcome> = [];
        for (i in 0...this._original.length) {
            result.push(CompositionState._deduceOutcome(this._original[i], current[i]));
        }
        return result;
    }

    static function _deduceOutcome(original:CompositionLineState, current:CompositionLineState):CompositionOutcome {
        final commonPrefix = Std.int(Math.min(
            Math.min(original.startSelection, current.startSelection),
            Strings.commonPrefixLength(original.text, current.text)
        ));
        final commonSuffix = Std.int(Math.min(
            Math.min(original.text.length - original.endSelection, current.text.length - current.endSelection),
            Strings.commonSuffixLength(original.text, current.text)
        ));
        final deletedText = original.text.substring(commonPrefix, original.text.length - commonSuffix);
        final insertedText = current.text.substring(commonPrefix, current.text.length - commonSuffix);
        return new CompositionOutcome(
            deletedText,
            original.startSelection - commonPrefix,
            original.endSelection - commonPrefix,
            insertedText,
            current.startSelection - commonPrefix,
            current.endSelection - commonPrefix
        );
    }

}
