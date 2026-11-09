// Ported from vscode src/vs/editor/common/model/textModelTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.Errors;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelEvents.IModelContentChange;
import cityscape.common.core.EolCounter;
import cityscape.common.core.LineRange;
import cityscape.common.core.OffsetRange;
import cityscape.common.core.Position;
import cityscape.common.languages.NullTokenize;
import cityscape.common.services.BackgroundScheduler;
import cityscape.common.tokens.ContiguousMultilineTokensBuilder;
import cityscape.common.tokens.LineTokens;

private enum abstract Constants(Int) to Int {
    var CHEAP_TOKENIZATION_LENGTH_LIMIT = 2048;
}

/**
 * The line to tokenize next and the state it starts with.
 */
typedef IFirstInvalidLine = {
    final lineNumber:Int;
    final startState:IState;
}

class TokenizerWithStateStore {

    final initialState:IState;

    public final store:TrackingTokenizationStateStore;

    public final tokenizationSupport:ITokenizationSupport;

    public function new(lineCount:Int, tokenizationSupport:ITokenizationSupport) {
        this.tokenizationSupport = tokenizationSupport;
        initialState = tokenizationSupport.getInitialState();
        store = new TrackingTokenizationStateStore(lineCount);
    }

    public function getStartState(lineNumber:Int):Null<IState> {
        return store.getStartState(lineNumber, initialState);
    }

    public function getFirstInvalidLine():Null<IFirstInvalidLine> {
        return store.getFirstInvalidLine(initialState);
    }

}

class TokenizerWithStateStoreAndTextModel extends TokenizerWithStateStore {

    public final _textModel:ITextModel;

    public final _languageIdCodec:ILanguageIdCodec;

    public function new(lineCount:Int, tokenizationSupport:ITokenizationSupport, textModel:ITextModel, languageIdCodec:ILanguageIdCodec) {
        super(lineCount, tokenizationSupport);
        _textModel = textModel;
        _languageIdCodec = languageIdCodec;
    }

    public function updateTokensUntilLine(builder:ContiguousMultilineTokensBuilder, lineNumber:Int):Void {
        final languageId = _textModel.getLanguageId();

        while (true) {
            final lineToTokenize = getFirstInvalidLine();
            if (lineToTokenize == null || lineToTokenize.lineNumber > lineNumber) {
                break;
            }

            final text = _textModel.getLineContent(lineToTokenize.lineNumber);

            final r = TextModelTokens.safeTokenize(_languageIdCodec, languageId, tokenizationSupport, text, true, lineToTokenize.startState);
            builder.add(lineToTokenize.lineNumber, r.tokens);
            store.setEndState(lineToTokenize.lineNumber, r.endState);
        }
    }

    /** assumes state is up to date */
    public function getTokenTypeIfInsertingCharacter(position:Position, character:String):StandardTokenType {
        final lineStartState = getStartState(position.lineNumber);
        if (lineStartState == null) {
            return StandardTokenType.Other;
        }

        final languageId = _textModel.getLanguageId();
        final lineContent = _textModel.getLineContent(position.lineNumber);

        // Create the text as if `character` was inserted
        final text = (
            lineContent.substring(0, position.column - 1)
            + character
            + lineContent.substring(position.column - 1)
        );

        final r = TextModelTokens.safeTokenize(_languageIdCodec, languageId, tokenizationSupport, text, true, lineStartState);
        final lineTokens = new LineTokens(r.tokens, text, _languageIdCodec);
        if (lineTokens.getCount() == 0) {
            return StandardTokenType.Other;
        }

        final tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
        return lineTokens.getStandardTokenType(tokenIndex);
    }

    /** assumes state is up to date */
    public function tokenizeLineWithEdit(position:Position, length:Int, newText:String):Null<LineTokens> {
        final lineNumber = position.lineNumber;
        final column = position.column;

        final lineStartState = getStartState(lineNumber);
        if (lineStartState == null) {
            return null;
        }

        final curLineContent = _textModel.getLineContent(lineNumber);
        final newLineContent = curLineContent.substring(0, column - 1)
            + newText + curLineContent.substring(column - 1 + length);

        final languageId = _textModel.getLanguageIdAtPosition(lineNumber, 0);
        final result = TextModelTokens.safeTokenize(
            _languageIdCodec,
            languageId,
            tokenizationSupport,
            newLineContent,
            true,
            lineStartState
        );

        final lineTokens = new LineTokens(result.tokens, newLineContent, _languageIdCodec);
        return lineTokens;
    }

    public function hasAccurateTokensForLine(lineNumber:Int):Bool {
        final firstInvalidLineNumber = store.getFirstInvalidEndStateLineNumberOrMax();
        return (lineNumber < firstInvalidLineNumber);
    }

    public function isCheapToTokenize(lineNumber:Int):Bool {
        final firstInvalidLineNumber = store.getFirstInvalidEndStateLineNumberOrMax();
        if (lineNumber < firstInvalidLineNumber) {
            return true;
        }
        if (lineNumber == firstInvalidLineNumber
            && _textModel.getLineLength(lineNumber) < (Constants.CHEAP_TOKENIZATION_LENGTH_LIMIT : Int)) {
            return true;
        }

        return false;
    }

    /**
     * The result is not cached.
     * @return `heuristicTokens` of Monaco's result object
     */
    public function tokenizeHeuristically(builder:ContiguousMultilineTokensBuilder, startLineNumber:Int, endLineNumber:Int):Bool {
        if (endLineNumber <= store.getFirstInvalidEndStateLineNumberOrMax()) {
            // nothing to do
            return false;
        }

        if (startLineNumber <= store.getFirstInvalidEndStateLineNumberOrMax()) {
            // tokenization has reached the viewport start...
            updateTokensUntilLine(builder, endLineNumber);
            return false;
        }

        var state = guessStartState(startLineNumber);
        final languageId = _textModel.getLanguageId();

        for (lineNumber in startLineNumber...(endLineNumber + 1)) {
            final text = _textModel.getLineContent(lineNumber);
            final r = TextModelTokens.safeTokenize(_languageIdCodec, languageId, tokenizationSupport, text, true, state);
            builder.add(lineNumber, r.tokens);
            state = r.endState;
        }

        return true;
    }

    function guessStartState(lineNumber:Int):IState {
        var nonWhitespaceColumn = _textModel.getLineFirstNonWhitespaceColumn(lineNumber);
        final likelyRelevantLines:Array<String> = [];
        var initialState:Null<IState> = null;
        var i = lineNumber - 1;
        while (nonWhitespaceColumn > 1 && i >= 1) {
            final newNonWhitespaceIndex = _textModel.getLineFirstNonWhitespaceColumn(i);
            // Ignore lines full of whitespace
            if (newNonWhitespaceIndex == 0) {
                i--;
                continue;
            }
            if (newNonWhitespaceIndex < nonWhitespaceColumn) {
                likelyRelevantLines.push(_textModel.getLineContent(i));
                nonWhitespaceColumn = newNonWhitespaceIndex;
                initialState = getStartState(i);
                if (initialState != null) {
                    break;
                }
            }
            i--;
        }

        if (initialState == null) {
            initialState = tokenizationSupport.getInitialState();
        }
        likelyRelevantLines.reverse();

        final languageId = _textModel.getLanguageId();
        var state = initialState;
        for (line in likelyRelevantLines) {
            final r = TextModelTokens.safeTokenize(_languageIdCodec, languageId, tokenizationSupport, line, false, state);
            state = r.endState;
        }
        return state;
    }

}

/**
 * **Invariant:**
 * If the text model is retokenized from line 1 to `getFirstInvalidEndStateLineNumber() - 1`,
 * then the recomputed end state for line l will be equal to `getEndState(l)`.
 */
class TrackingTokenizationStateStore {

    final _tokenizationStateStore = new TokenizationStateStore();

    final _invalidEndStatesLineNumbers = new RangePriorityQueueImpl();

    var lineCount:Int;

    public function new(lineCount:Int) {
        this.lineCount = lineCount;
        _invalidEndStatesLineNumbers.addRange(new OffsetRange(1, lineCount + 1));
    }

    public function getEndState(lineNumber:Int):Null<IState> {
        return _tokenizationStateStore.getEndState(lineNumber);
    }

    /**
     * @returns if the end state has changed.
     */
    public function setEndState(lineNumber:Int, state:IState):Bool {
        if (state == null) {
            throw new BugIndicatingError('Cannot set null/undefined state');
        }

        _invalidEndStatesLineNumbers.delete(lineNumber);
        final r = _tokenizationStateStore.setEndState(lineNumber, state);
        if (r && lineNumber < lineCount) {
            // because the state changed, we cannot trust the next state anymore and have to invalidate it.
            _invalidEndStatesLineNumbers.addRange(new OffsetRange(lineNumber + 1, lineNumber + 2));
        }

        return r;
    }

    public function acceptChange(range:LineRange, newLineCount:Int):Void {
        lineCount += newLineCount - range.length;
        _tokenizationStateStore.acceptChange(range, newLineCount);
        _invalidEndStatesLineNumbers.addRangeAndResize(new OffsetRange(range.startLineNumber, range.endLineNumberExclusive), newLineCount);
    }

    public function acceptChanges(changes:Array<IModelContentChange>):Void {
        for (c in changes) {
            final eolCount = EolCounter.countEOL(c.text).eolCount;
            acceptChange(new LineRange(c.range.startLineNumber, c.range.endLineNumber + 1), eolCount + 1);
        }
    }

    public function invalidateEndStateRange(range:LineRange):Void {
        _invalidEndStatesLineNumbers.addRange(new OffsetRange(range.startLineNumber, range.endLineNumberExclusive));
    }

    /**
     * -1 for Monaco's `null`.
     */
    public function getFirstInvalidEndStateLineNumber():Int {
        return _invalidEndStatesLineNumbers.min;
    }

    public function getFirstInvalidEndStateLineNumberOrMax():Int {
        final n = getFirstInvalidEndStateLineNumber();
        // Monaco: `getFirstInvalidEndStateLineNumber() || Number.MAX_SAFE_INTEGER`
        return n > 0 ? n : 0x7FFFFFFF;
    }

    public function allStatesValid():Bool {
        return _invalidEndStatesLineNumbers.min == -1;
    }

    public function getStartState(lineNumber:Int, initialState:IState):Null<IState> {
        if (lineNumber == 1) {
            return initialState;
        }
        return getEndState(lineNumber - 1);
    }

    public function getFirstInvalidLine(initialState:IState):Null<IFirstInvalidLine> {
        final lineNumber = getFirstInvalidEndStateLineNumber();
        if (lineNumber == -1) {
            return null;
        }
        final startState = getStartState(lineNumber, initialState);
        if (startState == null) {
            throw new BugIndicatingError('Start state must be defined');
        }

        return {lineNumber: lineNumber, startState: startState};
    }

}

class TokenizationStateStore {

    final _lineEndStates = new FixedArray<Null<IState>>(null);

    public function new() {}

    public function getEndState(lineNumber:Int):Null<IState> {
        return _lineEndStates.get(lineNumber);
    }

    public function setEndState(lineNumber:Int, state:IState):Bool {
        final oldState = _lineEndStates.get(lineNumber);
        if (oldState != null && oldState.equals(state)) {
            return false;
        }

        _lineEndStates.set(lineNumber, state);
        return true;
    }

    public function acceptChange(range:LineRange, newLineCount:Int):Void {
        var length = range.length;
        if (newLineCount > 0 && length > 0) {
            // Keep the last state, even though it is unrelated.
            // But if the new state happens to agree with this last state, then we know we can stop tokenizing.
            length--;
            newLineCount--;
        }

        _lineEndStates.replace(range.startLineNumber, length, newLineCount);
    }

    public function acceptChanges(changes:Array<IModelContentChange>):Void {
        for (c in changes) {
            final eolCount = EolCounter.countEOL(c.text).eolCount;
            acceptChange(new LineRange(c.range.startLineNumber, c.range.endLineNumber + 1), eolCount + 1);
        }
    }

}

/**
 * A priority queue of line numbers stored as sorted, disjoint ranges.
 * `min` and `removeMin` return -1 for Monaco's `null` (line numbers start at 1).
 */
class RangePriorityQueueImpl {

    final _ranges:Array<OffsetRange> = [];

    public function new() {}

    public function getRanges():Array<OffsetRange> {
        return _ranges;
    }

    public var min(get, never):Int;
    function get_min():Int {
        if (_ranges.length == 0) {
            return -1;
        }
        return _ranges[0].start;
    }

    public function removeMin():Int {
        if (_ranges.length == 0) {
            return -1;
        }
        final range = _ranges[0];
        if (range.start + 1 == range.endExclusive) {
            _ranges.shift();
        }
        else {
            _ranges[0] = new OffsetRange(range.start + 1, range.endExclusive);
        }
        return range.start;
    }

    public function delete(value:Int):Void {
        var idx = -1;
        for (i in 0..._ranges.length) {
            if (_ranges[i].contains(value)) {
                idx = i;
                break;
            }
        }
        if (idx != -1) {
            final range = _ranges[idx];
            if (range.start == value) {
                if (range.endExclusive == value + 1) {
                    _ranges.splice(idx, 1);
                }
                else {
                    _ranges[idx] = new OffsetRange(value + 1, range.endExclusive);
                }
            }
            else {
                if (range.endExclusive == value + 1) {
                    _ranges[idx] = new OffsetRange(range.start, value);
                }
                else {
                    _ranges[idx] = new OffsetRange(range.start, value);
                    _ranges.insert(idx + 1, new OffsetRange(value + 1, range.endExclusive));
                }
            }
        }
    }

    public function addRange(range:OffsetRange):Void {
        OffsetRange.addRange(range, _ranges);
    }

    public function addRangeAndResize(range:OffsetRange, newLength:Int):Void {
        var idxFirstMightBeIntersecting = 0;
        while (!(idxFirstMightBeIntersecting >= _ranges.length || range.start <= _ranges[idxFirstMightBeIntersecting].endExclusive)) {
            idxFirstMightBeIntersecting++;
        }
        var idxFirstIsAfter = idxFirstMightBeIntersecting;
        while (!(idxFirstIsAfter >= _ranges.length || range.endExclusive < _ranges[idxFirstIsAfter].start)) {
            idxFirstIsAfter++;
        }
        final delta = newLength - range.length;

        for (i in idxFirstIsAfter..._ranges.length) {
            _ranges[i] = _ranges[i].delta(delta);
        }

        if (idxFirstMightBeIntersecting == idxFirstIsAfter) {
            final newRange = new OffsetRange(range.start, range.start + newLength);
            if (!newRange.isEmpty) {
                _ranges.insert(idxFirstMightBeIntersecting, newRange);
            }
        }
        else {
            final start = Std.int(Math.min(range.start, _ranges[idxFirstMightBeIntersecting].start));
            final endEx = Std.int(Math.max(range.endExclusive, _ranges[idxFirstIsAfter - 1].endExclusive));

            final newRange = new OffsetRange(start, endEx + delta);
            _ranges.splice(idxFirstMightBeIntersecting, idxFirstIsAfter - idxFirstMightBeIntersecting);
            if (!newRange.isEmpty) {
                _ranges.insert(idxFirstMightBeIntersecting, newRange);
            }
        }
    }

    public function toString():String {
        return [for (r in _ranges) r.toString()].join(' + ');
    }

}

class TextModelTokens {

    public static function safeTokenize(languageIdCodec:ILanguageIdCodec, languageId:String, tokenizationSupport:Null<ITokenizationSupport>, text:String, hasEOL:Bool, state:IState):EncodedTokenizationResult {
        var r:Null<EncodedTokenizationResult> = null;

        if (tokenizationSupport != null) {
            try {
                r = tokenizationSupport.tokenizeEncoded(text, hasEOL, state.clone());
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }
        }

        if (r == null) {
            r = NullTokenize.nullTokenizeEncoded(languageIdCodec.encodeLanguageId(languageId), state);
        }

        LineTokens.convertToEndOffset(r.tokens, text.length);
        return r;
    }

}

/**
 * The default background tokenizer: tokenizes the invalid lines of a model
 * attached to an editor, in the background.
 *
 * Monaco runs it in `runWhenGlobalIdle` callbacks (tokenizing until the idle
 * deadline, yielding every 1 to 2 ms). Cityscape runs it from the
 * `BackgroundScheduler` of the context, which gives all models a shared time
 * budget per frame (see `BackgroundScheduler`). Without a scheduler (null),
 * nothing runs in the background: lines are tokenized on demand only.
 */
class DefaultBackgroundTokenizer implements IBackgroundTokenizer implements IBackgroundTask {

    var _isDisposed = false;

    final _tokenizerWithStateStore:TokenizerWithStateStoreAndTextModel;

    final _backgroundTokenStore:IBackgroundTokenizationStore;

    final _scheduler:Null<BackgroundScheduler>;

    public function new(tokenizerWithStateStore:TokenizerWithStateStoreAndTextModel, backgroundTokenStore:IBackgroundTokenizationStore, scheduler:Null<BackgroundScheduler>) {
        _tokenizerWithStateStore = tokenizerWithStateStore;
        _backgroundTokenStore = backgroundTokenStore;
        _scheduler = scheduler;
    }

    public function dispose():Void {
        _isDisposed = true;
        if (_scheduler != null) {
            _scheduler.cancel(this);
        }
    }

    public function handleChanges():Void {
        _beginBackgroundTokenization();
    }

    function _beginBackgroundTokenization():Void {
        if (_scheduler == null || _isDisposed || !_tokenizerWithStateStore._textModel.isAttachedToEditor() || !_hasLinesToTokenize()) {
            return;
        }
        _scheduler.schedule(this);
    }

    /**
     * Called by the scheduler: tokenizes invalid lines until `endTime`
     * (`haxe.Timer.stamp()` seconds). Returns true when there is more to do
     * (Monaco's `_backgroundTokenizeWithDeadline`).
     */
    public function runBackgroundTask(endTime:Float):Bool {
        if (_isDisposed || !_tokenizerWithStateStore._textModel.isAttachedToEditor() || !_hasLinesToTokenize()) {
            // disposed in the meantime or detached or finished
            return false;
        }
        _backgroundTokenizeUntil(endTime);
        return !_isDisposed && _tokenizerWithStateStore._textModel.isAttachedToEditor() && _hasLinesToTokenize();
    }

    /**
     * Monaco's `_backgroundTokenizeForAtLeast1ms`, with the scheduler's deadline.
     */
    function _backgroundTokenizeUntil(endTime:Float):Void {
        final lineCount = _tokenizerWithStateStore._textModel.getLineCount();
        final builder = new ContiguousMultilineTokensBuilder();

        do {
            final tokenizedLineNumber = _tokenizeOneInvalidLine(builder);

            if (tokenizedLineNumber >= lineCount) {
                break;
            }
            if (haxe.Timer.stamp() >= endTime) {
                break;
            }
        } while (_hasLinesToTokenize());

        _backgroundTokenStore.setTokens(builder.finalize());
        checkFinished();
    }

    function _hasLinesToTokenize():Bool {
        if (_tokenizerWithStateStore == null) {
            return false;
        }
        return !_tokenizerWithStateStore.store.allStatesValid();
    }

    function _tokenizeOneInvalidLine(builder:ContiguousMultilineTokensBuilder):Int {
        final firstInvalidLine = _tokenizerWithStateStore.getFirstInvalidLine();
        if (firstInvalidLine == null) {
            return _tokenizerWithStateStore._textModel.getLineCount() + 1;
        }
        _tokenizerWithStateStore.updateTokensUntilLine(builder, firstInvalidLine.lineNumber);
        return firstInvalidLine.lineNumber;
    }

    public function checkFinished():Void {
        if (_isDisposed) {
            return;
        }
        if (_tokenizerWithStateStore.store.allStatesValid()) {
            _backgroundTokenStore.backgroundTokenizationFinished();
        }
    }

    public function requestTokens(startLineNumber:Int, endLineNumberExclusive:Int):Void {
        _tokenizerWithStateStore.store.invalidateEndStateRange(new LineRange(startLineNumber, endLineNumberExclusive));
    }

}
