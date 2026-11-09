// Ported from vscode src/vs/editor/common/model/tokenizationTextModelPart.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.Cityscape;
import cityscape.base.common.CharCode;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Languages;
import cityscape.common.Model.IAttachedView;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelEvents;
import cityscape.common.TokenizationTextModelPart;
import cityscape.common.core.EolCounter;
import cityscape.common.core.LineRange;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.WordHelper;
import cityscape.common.languages.LanguageConfigurationRegistry;
import cityscape.common.model.bracketPairsTextModelPart.BracketPairsImpl.BracketPairsTextModelPart;
import cityscape.common.model.TextModelTokens;
import cityscape.common.model.Tokens;
import cityscape.common.services.BackgroundScheduler;
import cityscape.common.tokens.ContiguousMultilineTokens;
import cityscape.common.tokens.ContiguousMultilineTokensBuilder;
import cityscape.common.tokens.ContiguousTokensStore;
import cityscape.common.tokens.LineTokens;
import cityscape.common.tokens.SparseMultilineTokens;
import cityscape.common.tokens.SparseTokensStore;

/**
 * The tokenization part of a text model.
 *
 * The text model creates it with its `Cityscape` context, which gives the
 * services Monaco injects: the language service (language id codec), the
 * language configuration service, the tokenization registry and the
 * background scheduler.
 *
 * Differences with Monaco: no tree sitter tokens (`TreeSitterTokens`), only
 * the TextMate style `GrammarTokens`; `_isDisposing()` of the text model is
 * read as `isDisposed()` (the interface has no `_isDisposing`).
 */
class TokenizationTextModelPart extends TextModelPart implements ITokenizationTextModelPart {

    final _semanticTokens:SparseTokensStore;

    final _onDidChangeLanguage = new Emitter<IModelLanguageChangedEvent>();

    public final onDidChangeLanguage:Event<IModelLanguageChangedEvent>;

    final _onDidChangeLanguageConfiguration = new Emitter<IModelLanguageConfigurationChangedEvent>();

    public final onDidChangeLanguageConfiguration:Event<IModelLanguageConfigurationChangedEvent>;

    final _onDidChangeTokens = new Emitter<IModelTokensChangedEvent>();

    public final onDidChangeTokens:Event<IModelTokensChangedEvent>;

    var _tokens:GrammarTokens;

    final _tokensDisposables = new DisposableStore();

    final _textModel:ITextModel;

    final _bracketPairsTextModelPart:Null<BracketPairsTextModelPart>;

    var _languageId:String;

    final _attachedViews:AttachedViews;

    final _context:Cityscape;

    /**
     * @param bracketPairsTextModelPart the bracket pairs part of the model
     * (null for a model without one, in tests)
     */
    public function new(textModel:ITextModel, bracketPairsTextModelPart:Null<BracketPairsTextModelPart>, languageId:String, attachedViews:AttachedViews, context:Cityscape) {
        super();
        _textModel = textModel;
        _bracketPairsTextModelPart = bracketPairsTextModelPart;
        _languageId = languageId;
        _attachedViews = attachedViews;
        _context = context;

        _semanticTokens = new SparseTokensStore(context.languageService.languageIdCodec);
        onDidChangeLanguage = _onDidChangeLanguage.event;
        onDidChangeLanguageConfiguration = _onDidChangeLanguageConfiguration.event;
        onDidChangeTokens = _onDidChangeTokens.event;
        _register(_onDidChangeLanguage);
        _register(_onDidChangeLanguageConfiguration);
        _register(_onDidChangeTokens);
        _register(_tokensDisposables);

        _register(context.languageConfigurationService.onDidChange(e -> {
            if (e.affects(_languageId)) {
                _onDidChangeLanguageConfiguration.fire({});
            }
        }));

        createTokens();
    }

    function createGrammarTokens():GrammarTokens {
        return _register(new GrammarTokens(_context.languageService.languageIdCodec, _textModel, () -> _languageId, _attachedViews, _context.tokenizationRegistry, _context.backgroundScheduler));
    }

    function createTokens():Void {
        final needsReset = _tokens != null;
        if (_tokens != null) {
            _tokens.dispose();
        }
        _tokens = createGrammarTokens();
        _tokensDisposables.clear();
        _tokensDisposables.add(_tokens.onDidChangeTokens(e -> {
            _emitModelTokensChangedEvent(e);
        }));

        _tokensDisposables.add(_tokens.onDidChangeBackgroundTokenizationState(() -> {
            if (_bracketPairsTextModelPart != null) {
                _bracketPairsTextModelPart.handleDidChangeBackgroundTokenizationState();
            }
        }));
        if (needsReset) {
            // We need to reset the tokenization, as the new token provider otherwise won't have a chance to provide tokens until some action happens in the editor.
            _tokens.resetTokenization();
        }
    }

    public function _hasListeners():Bool {
        return (_onDidChangeLanguage.hasListeners()
            || _onDidChangeLanguageConfiguration.hasListeners()
            || _onDidChangeTokens.hasListeners());
    }

    public function handleLanguageConfigurationServiceChange(e:LanguageConfigurationServiceChangeEvent):Void {
        if (e.affects(_languageId)) {
            _onDidChangeLanguageConfiguration.fire({});
        }
    }

    public function handleDidChangeContent(e:IModelContentChangedEvent):Void {
        if (e.isFlush) {
            _semanticTokens.flush();
        }
        else if (!e.isEolChange) { // We don't have to do anything on an EOL change
            for (c in e.changes) {
                // A typed local: `fastCodeAt` on the field of a structure fails on hxcpp
                final text:String = c.text;
                final eol = EolCounter.countEOL(text);

                _semanticTokens.acceptEdit(
                    c.range,
                    eol.eolCount,
                    eol.firstLineLength,
                    eol.lastLineLength,
                    text.length > 0 ? StringTools.fastCodeAt(text, 0) : CharCode.Null
                );
            }
        }

        _tokens.handleDidChangeContent(e);
    }

    public function handleDidChangeAttached():Void {
        _tokens.handleDidChangeAttached();
    }

    /**
     * Includes grammar and semantic tokens.
     */
    public function getLineTokens(lineNumber:Int):LineTokens {
        validateLineNumber(lineNumber);
        final syntacticTokens = _tokens.getLineTokens(lineNumber);
        return _semanticTokens.addSparseTokens(lineNumber, syntacticTokens);
    }

    function _emitModelTokensChangedEvent(e:IModelTokensChangedEvent):Void {
        if (!_textModel.isDisposed()) {
            if (_bracketPairsTextModelPart != null) {
                _bracketPairsTextModelPart.handleDidChangeTokens(e);
            }
            _onDidChangeTokens.fire(e);
        }
    }

    // #region Grammar Tokens

    function validateLineNumber(lineNumber:Int):Void {
        if (lineNumber < 1 || lineNumber > _textModel.getLineCount()) {
            throw new BugIndicatingError('Illegal value for lineNumber');
        }
    }

    public var hasTokens(get, never):Bool;
    function get_hasTokens():Bool {
        return _tokens.hasTokens;
    }

    public function resetTokenization():Void {
        _tokens.resetTokenization();
    }

    public var backgroundTokenizationState(get, never):BackgroundTokenizationState;
    function get_backgroundTokenizationState():BackgroundTokenizationState {
        return _tokens.backgroundTokenizationState;
    }

    public function forceTokenization(lineNumber:Int):Void {
        validateLineNumber(lineNumber);
        _tokens.forceTokenization(lineNumber);
    }

    public function hasAccurateTokensForLine(lineNumber:Int):Bool {
        validateLineNumber(lineNumber);
        return _tokens.hasAccurateTokensForLine(lineNumber);
    }

    public function isCheapToTokenize(lineNumber:Int):Bool {
        validateLineNumber(lineNumber);
        return _tokens.isCheapToTokenize(lineNumber);
    }

    public function tokenizeIfCheap(lineNumber:Int):Void {
        validateLineNumber(lineNumber);
        _tokens.tokenizeIfCheap(lineNumber);
    }

    public function getTokenTypeIfInsertingCharacter(lineNumber:Int, column:Int, character:String):StandardTokenType {
        return _tokens.getTokenTypeIfInsertingCharacter(lineNumber, column, character);
    }

    public function tokenizeLineWithEdit(position:IPosition, length:Int, newText:String):Null<LineTokens> {
        return _tokens.tokenizeLineWithEdit(position, length, newText);
    }

    // #endregion

    // #region Semantic Tokens

    public function setSemanticTokens(tokens:Null<Array<SparseMultilineTokens>>, isComplete:Bool):Void {
        _semanticTokens.set(tokens, isComplete);

        _emitModelTokensChangedEvent({
            semanticTokensApplied: tokens != null,
            ranges: [{fromLineNumber: 1, toLineNumber: _textModel.getLineCount()}],
        });
    }

    public function hasCompleteSemanticTokens():Bool {
        return _semanticTokens.isComplete();
    }

    public function hasSomeSemanticTokens():Bool {
        return !_semanticTokens.isEmpty();
    }

    public function setPartialSemanticTokens(range:Range, tokens:Array<SparseMultilineTokens>):Void {
        if (hasCompleteSemanticTokens()) {
            return;
        }
        final changedRange = _textModel.validateRange(
            _semanticTokens.setPartial(range, tokens)
        );

        _emitModelTokensChangedEvent({
            semanticTokensApplied: true,
            ranges: [
                {
                    fromLineNumber: changedRange.startLineNumber,
                    toLineNumber: changedRange.endLineNumber,
                },
            ],
        });
    }

    // #endregion

    // #region Utility Methods

    public function getWordAtPosition(_position:IPosition):Null<IWordAtPosition> {
        assertNotDisposed();

        final position = _textModel.validatePosition(_position);
        final lineContent = _textModel.getLineContent(position.lineNumber);
        final lineTokens = getLineTokens(position.lineNumber);
        final tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);

        // (1). First try checking right biased word
        final rb = _findLanguageBoundaries(lineTokens, tokenIndex);
        final rightBiasedWord = WordHelper.getWordAtText(
            position.column,
            getLanguageConfiguration(lineTokens.getLanguageId(tokenIndex)).getWordDefinition(),
            lineContent.substring(rb.startOffset, rb.endOffset),
            rb.startOffset
        );
        // Make sure the result touches the original passed in position
        if (
            rightBiasedWord != null &&
            rightBiasedWord.startColumn <= _position.column &&
            _position.column <= rightBiasedWord.endColumn
        ) {
            return rightBiasedWord;
        }

        // (2). Else, if we were at a language boundary, check the left biased word
        if (tokenIndex > 0 && rb.startOffset == position.column - 1) {
            // edge case, where `position` sits between two tokens belonging to two different languages
            final lb = _findLanguageBoundaries(lineTokens, tokenIndex - 1);
            final leftBiasedWord = WordHelper.getWordAtText(
                position.column,
                getLanguageConfiguration(lineTokens.getLanguageId(tokenIndex - 1)).getWordDefinition(),
                lineContent.substring(lb.startOffset, lb.endOffset),
                lb.startOffset
            );
            // Make sure the result touches the original passed in position
            if (
                leftBiasedWord != null &&
                leftBiasedWord.startColumn <= _position.column &&
                _position.column <= leftBiasedWord.endColumn
            ) {
                return leftBiasedWord;
            }
        }

        return null;
    }

    function getLanguageConfiguration(languageId:String):ResolvedLanguageConfiguration {
        return _context.languageConfigurationService.getLanguageConfiguration(languageId);
    }

    static function _findLanguageBoundaries(lineTokens:LineTokens, tokenIndex:Int):{startOffset:Int, endOffset:Int} {
        final languageId = lineTokens.getLanguageId(tokenIndex);

        // go left until a different language is hit
        var startOffset = 0;
        var i = tokenIndex;
        while (i >= 0 && lineTokens.getLanguageId(i) == languageId) {
            startOffset = lineTokens.getStartOffset(i);
            i--;
        }

        // go right until a different language is hit
        var endOffset = lineTokens.getLineContent().length;
        final tokenCount = lineTokens.getCount();
        i = tokenIndex;
        while (i < tokenCount && lineTokens.getLanguageId(i) == languageId) {
            endOffset = lineTokens.getEndOffset(i);
            i++;
        }

        return {startOffset: startOffset, endOffset: endOffset};
    }

    public function getWordUntilPosition(position:IPosition):IWordAtPosition {
        final wordAtPosition = getWordAtPosition(position);
        if (wordAtPosition == null) {
            return {word: '', startColumn: position.column, endColumn: position.column};
        }
        return {
            word: wordAtPosition.word.substr(0, position.column - wordAtPosition.startColumn),
            startColumn: wordAtPosition.startColumn,
            endColumn: position.column,
        };
    }

    // #endregion

    // #region Language Id handling

    public function getLanguageId():String {
        return _languageId;
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        final position = _textModel.validatePosition(new Position(lineNumber, column));
        final lineTokens = getLineTokens(position.lineNumber);
        return lineTokens.getLanguageId(lineTokens.findTokenIndexAtOffset(position.column - 1));
    }

    public function setLanguageId(languageId:String, ?source:String):Void {
        if (source == null) {
            source = 'api';
        }
        if (_languageId == languageId) {
            // There's nothing to do
            return;
        }

        final e:IModelLanguageChangedEvent = {
            oldLanguage: _languageId,
            newLanguage: languageId,
            source: source
        };

        _languageId = languageId;

        if (_bracketPairsTextModelPart != null) {
            _bracketPairsTextModelPart.handleDidChangeLanguage(e);
        }
        _tokens.resetTokenization();
        _onDidChangeLanguage.fire(e);
        _onDidChangeLanguageConfiguration.fire({});
    }

    // #endregion

}

/**
 * The tokens computed by a tokenization support (TextMate or any other
 * `ITokenizationSupport` registered for the language).
 */
class GrammarTokens extends AbstractTokens {

    var _tokenizer:Null<TokenizerWithStateStoreAndTextModel> = null;

    var _defaultBackgroundTokenizer:Null<DefaultBackgroundTokenizer> = null;

    final _backgroundTokenizer = new MutableDisposable<IBackgroundTokenizer>();

    final _tokens:ContiguousTokensStore;

    final _attachedViewViews:Array<IAttachedView> = [];

    final _attachedViewStates:Array<AttachedViewHandler> = [];

    final _tokenizationRegistry:ITokenizationRegistry<ITokenizationSupport>;

    final _scheduler:Null<BackgroundScheduler>;

    public function new(languageIdCodec:ILanguageIdCodec, textModel:ITextModel, getLanguageId:() -> String, attachedViews:AttachedViews, tokenizationRegistry:ITokenizationRegistry<ITokenizationSupport>, scheduler:Null<BackgroundScheduler>) {
        super(languageIdCodec, textModel, getLanguageId);
        _register(_backgroundTokenizer);
        _tokens = new ContiguousTokensStore(languageIdCodec);
        _tokenizationRegistry = tokenizationRegistry;
        _scheduler = scheduler;

        _register(tokenizationRegistry.onDidChange(e -> {
            final languageId = this.getLanguageId();
            if (e.changedLanguages.indexOf(languageId) == -1) {
                return;
            }
            resetTokenization();
        }));

        resetTokenization();

        _register(attachedViews.onDidChangeVisibleRanges(change -> {
            final view = change.view;
            final state = change.state;
            final index = _attachedViewViews.indexOf(view);
            if (state != null) {
                var existing:AttachedViewHandler = index != -1 ? _attachedViewStates[index] : null;
                if (existing == null) {
                    var handler:AttachedViewHandler = null;
                    handler = new AttachedViewHandler(() -> refreshRanges(handler.lineRanges));
                    existing = handler;
                    _attachedViewViews.push(view);
                    _attachedViewStates.push(existing);
                }
                existing.handleStateChange(state);
            }
            else if (index != -1) {
                final handler = _attachedViewStates[index];
                _attachedViewViews.splice(index, 1);
                _attachedViewStates.splice(index, 1);
                handler.dispose();
            }
        }));
    }

    override public function dispose():Void {
        for (handler in _attachedViewStates) {
            handler.dispose();
        }
        _attachedViewViews.resize(0);
        _attachedViewStates.resize(0);
        super.dispose();
    }

    override public function resetTokenization(fireTokenChangeEvent:Bool = true):Void {
        _tokens.flush();
        if (fireTokenChangeEvent) {
            _onDidChangeTokens.fire({
                semanticTokensApplied: false,
                ranges: [
                    {
                        fromLineNumber: 1,
                        toLineNumber: _textModel.getLineCount(),
                    },
                ],
            });
        }

        var tokenizationSupport:Null<ITokenizationSupport> = null;
        var initialState:Null<IState> = null;
        if (!_textModel.isTooLargeForTokenization()) {
            tokenizationSupport = _tokenizationRegistry.get(getLanguageId());
            if (tokenizationSupport != null) {
                try {
                    initialState = tokenizationSupport.getInitialState();
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                    tokenizationSupport = null;
                }
            }
        }

        if (tokenizationSupport != null && initialState != null) {
            _tokenizer = new TokenizerWithStateStoreAndTextModel(_textModel.getLineCount(), tokenizationSupport, _textModel, _languageIdCodec);
        }
        else {
            _tokenizer = null;
        }

        _backgroundTokenizer.clear();

        _defaultBackgroundTokenizer = null;
        if (_tokenizer != null) {
            final b = new GrammarTokensBackgroundStore(this);

            if (tokenizationSupport != null) {
                _backgroundTokenizer.value = tokenizationSupport.createBackgroundTokenizer(_textModel, b);
            }
            if (_backgroundTokenizer.value == null && !_textModel.isTooLargeForTokenization()) {
                _defaultBackgroundTokenizer = new DefaultBackgroundTokenizer(_tokenizer, b, _scheduler);
                _backgroundTokenizer.value = _defaultBackgroundTokenizer;
                _defaultBackgroundTokenizer.handleChanges();
            }
        }

        refreshAllVisibleLineTokens();
    }

    @:allow(cityscape.common.model.GrammarTokensBackgroundStore)
    function _backgroundTokenizationFinished():Void {
        if (_backgroundTokenizationState == BackgroundTokenizationState.Completed) {
            // We already did a full tokenization and don't go back to progressing.
            return;
        }
        final newState = BackgroundTokenizationState.Completed;
        _backgroundTokenizationState = newState;
        _onDidChangeBackgroundTokenizationState.fire();
    }

    @:allow(cityscape.common.model.GrammarTokensBackgroundStore)
    function _setEndState(lineNumber:Int, state:IState):Void {
        if (_tokenizer == null) {
            return;
        }
        final firstInvalidEndStateLineNumber = _tokenizer.store.getFirstInvalidEndStateLineNumber();
        // Don't accept states for definitely valid states, the renderer is ahead of the worker!
        if (firstInvalidEndStateLineNumber != -1 && lineNumber >= firstInvalidEndStateLineNumber) {
            _tokenizer.store.setEndState(lineNumber, state);
        }
    }

    override public function handleDidChangeAttached():Void {
        if (_defaultBackgroundTokenizer != null) {
            _defaultBackgroundTokenizer.handleChanges();
        }
    }

    override public function handleDidChangeContent(e:IModelContentChangedEvent):Void {
        if (e.isFlush) {
            // Don't fire the event, as the view might not have got the text change event yet
            resetTokenization(false);
        }
        else if (!e.isEolChange) { // We don't have to do anything on an EOL change
            for (c in e.changes) {
                final eol = EolCounter.countEOL(c.text);

                _tokens.acceptEdit(c.range, eol.eolCount, eol.firstLineLength);
            }

            if (_tokenizer != null) {
                _tokenizer.store.acceptChanges(e.changes);
            }
            if (_defaultBackgroundTokenizer != null) {
                _defaultBackgroundTokenizer.handleChanges();
            }
        }
    }

    @:allow(cityscape.common.model.GrammarTokensBackgroundStore)
    function setTokens(tokens:Array<ContiguousMultilineTokens>):Array<cityscape.common.tokens.ContiguousTokensStore.ILineNumberRange> {
        final changes = _tokens.setMultilineTokens(tokens, _textModel).changes;

        if (changes.length > 0) {
            _onDidChangeTokens.fire({semanticTokensApplied: false, ranges: changes});
        }

        return changes;
    }

    function refreshAllVisibleLineTokens():Void {
        final ranges = LineRange.joinMany([for (s in _attachedViewStates) s.lineRanges]);
        refreshRanges(ranges);
    }

    function refreshRanges(ranges:Array<LineRange>):Void {
        for (range in ranges) {
            refreshRange(range.startLineNumber, range.endLineNumberExclusive - 1);
        }
    }

    function refreshRange(startLineNumber:Int, endLineNumber:Int):Void {
        if (_tokenizer == null) {
            return;
        }

        final lineCount = _textModel.getLineCount();
        startLineNumber = Std.int(Math.max(1, Math.min(lineCount, startLineNumber)));
        endLineNumber = Std.int(Math.min(lineCount, endLineNumber));

        final builder = new ContiguousMultilineTokensBuilder();
        final heuristicTokens = _tokenizer.tokenizeHeuristically(builder, startLineNumber, endLineNumber);
        final changedTokens = setTokens(builder.finalize());

        if (heuristicTokens) {
            // We overrode tokens with heuristically computed ones.
            // Because old states might get reused (thus stopping invalidation),
            // we have to explicitly request the tokens for the changed ranges again.
            final backgroundTokenizer = _backgroundTokenizer.value;
            if (backgroundTokenizer != null) {
                for (c in changedTokens) {
                    backgroundTokenizer.requestTokens(c.fromLineNumber, c.toLineNumber + 1);
                }
            }
        }

        if (_defaultBackgroundTokenizer != null) {
            _defaultBackgroundTokenizer.checkFinished();
        }
    }

    override public function forceTokenization(lineNumber:Int):Void {
        final builder = new ContiguousMultilineTokensBuilder();
        if (_tokenizer != null) {
            _tokenizer.updateTokensUntilLine(builder, lineNumber);
        }
        setTokens(builder.finalize());
        if (_defaultBackgroundTokenizer != null) {
            _defaultBackgroundTokenizer.checkFinished();
        }
    }

    override public function hasAccurateTokensForLine(lineNumber:Int):Bool {
        if (_tokenizer == null) {
            return true;
        }
        return _tokenizer.hasAccurateTokensForLine(lineNumber);
    }

    override public function isCheapToTokenize(lineNumber:Int):Bool {
        if (_tokenizer == null) {
            return true;
        }
        return _tokenizer.isCheapToTokenize(lineNumber);
    }

    override public function getLineTokens(lineNumber:Int):LineTokens {
        final lineText = _textModel.getLineContent(lineNumber);
        return _tokens.getTokens(
            _textModel.getLanguageId(),
            lineNumber - 1,
            lineText
        );
    }

    override public function getTokenTypeIfInsertingCharacter(lineNumber:Int, column:Int, character:String):StandardTokenType {
        if (_tokenizer == null) {
            return StandardTokenType.Other;
        }

        final position = _textModel.validatePosition(new Position(lineNumber, column));
        forceTokenization(position.lineNumber);
        return _tokenizer.getTokenTypeIfInsertingCharacter(position, character);
    }

    override public function tokenizeLineWithEdit(position:IPosition, length:Int, newText:String):Null<LineTokens> {
        if (_tokenizer == null) {
            return null;
        }

        final validatedPosition = _textModel.validatePosition(position);
        forceTokenization(validatedPosition.lineNumber);
        return _tokenizer.tokenizeLineWithEdit(validatedPosition, length, newText);
    }

    override function get_hasTokens():Bool {
        return _tokens.hasTokens;
    }

}

/**
 * The `IBackgroundTokenizationStore` given to the background tokenizers of
 * `GrammarTokens` (an object literal in Monaco).
 */
private class GrammarTokensBackgroundStore implements IBackgroundTokenizationStore {

    final tokens:GrammarTokens;

    public function new(tokens:GrammarTokens) {
        this.tokens = tokens;
    }

    public function setTokens(t:Array<ContiguousMultilineTokens>):Void {
        @:privateAccess tokens.setTokens(t);
    }

    public function backgroundTokenizationFinished():Void {
        @:privateAccess tokens._backgroundTokenizationFinished();
    }

    public function setEndState(lineNumber:Int, state:IState):Void {
        @:privateAccess tokens._setEndState(lineNumber, state);
    }

}
