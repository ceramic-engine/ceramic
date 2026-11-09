// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsImpl.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart;

import cityscape.base.common.Arrays.CallbackIterable;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelBracketPairs;
import cityscape.common.TextModelEvents;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageConfigurationRegistry;
import cityscape.common.languages.Supports;
import cityscape.common.languages.supports.LanguageBracketsConfiguration;
import cityscape.common.languages.supports.RichEditBrackets;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.BracketPairsTree;
import cityscape.common.tokens.LineTokens;

/**
 * The bracket pairs part of a text model.
 *
 * The text model creates it with `new BracketPairsTextModelPart(textModel,
 * languageConfigurationService)` and forwards its events to the `handle*`
 * methods.
 */
class BracketPairsTextModelPart extends Disposable implements IBracketPairsTextModelPart {

    final bracketPairsTree:MutableDisposable<BracketPairsTreeRef>;

    final onDidChangeEmitter = new VoidEmitter();
    public var onDidChange(default, null):VoidEvent;

    var canBuildAST(get, never):Bool;
    function get_canBuildAST():Bool {
        final maxSupportedDocumentLength = /* max lines */ 50000 * /* average column count */ 100;
        return textModel.getValueLength() <= maxSupportedDocumentLength;
    }

    var bracketsRequested = false;

    final textModel:ITextModel;
    final languageConfigurationService:ILanguageConfigurationService;

    public function new(
        textModel:ITextModel,
        languageConfigurationService:ILanguageConfigurationService
    ) {
        super();
        this.textModel = textModel;
        this.languageConfigurationService = languageConfigurationService;
        bracketPairsTree = _register(new MutableDisposable<BracketPairsTreeRef>());
        onDidChange = onDidChangeEmitter.event;
    }

    inline function treeObject():Null<BracketPairsTree> {
        final value = bracketPairsTree.value;
        return value != null ? value.object : null;
    }

    //#region TextModel events

    public function handleLanguageConfigurationServiceChange(e:LanguageConfigurationServiceChangeEvent):Void {
        final tree = treeObject();
        if (e.languageId == null || e.languageId == '' || (tree != null && tree.didLanguageChange(e.languageId))) {
            bracketPairsTree.clear();
            updateBracketPairsTree();
        }
    }

    public function handleDidChangeOptions(e:IModelOptionsChangedEvent):Void {
        bracketPairsTree.clear();
        updateBracketPairsTree();
    }

    public function handleDidChangeLanguage(e:IModelLanguageChangedEvent):Void {
        bracketPairsTree.clear();
        updateBracketPairsTree();
    }

    public function handleDidChangeContent(change:IModelContentChangedEvent):Void {
        final tree = treeObject();
        if (tree != null) {
            tree.handleContentChanged(change);
        }
    }

    public function handleDidChangeBackgroundTokenizationState():Void {
        final tree = treeObject();
        if (tree != null) {
            tree.handleDidChangeBackgroundTokenizationState();
        }
    }

    public function handleDidChangeTokens(e:IModelTokensChangedEvent):Void {
        final tree = treeObject();
        if (tree != null) {
            tree.handleDidChangeTokens(e);
        }
    }

    //#endregion

    function updateBracketPairsTree():Void {
        if (bracketsRequested && canBuildAST) {
            if (bracketPairsTree.value == null) {
                final store = new DisposableStore();

                final ref = new BracketPairsTreeRef(
                    store.add(
                        new BracketPairsTree(textModel, (languageId) -> {
                            return languageConfigurationService.getLanguageConfiguration(languageId);
                        })
                    ),
                    store
                );
                bracketPairsTree.value = ref;
                store.add(ref.object.onDidChange(() -> onDidChangeEmitter.fire()));
                onDidChangeEmitter.fire();
            }
        }
        else {
            if (bracketPairsTree.value != null) {
                bracketPairsTree.clear();
                // Important: Don't call fire if there was no change!
                onDidChangeEmitter.fire();
            }
        }
    }

    /**
     * Returns all bracket pairs that intersect the given range.
     * The result is sorted by the start position.
     */
    public function getBracketPairsInRange(range:Range):CallbackIterable<BracketPairInfo> {
        bracketsRequested = true;
        updateBracketPairsTree();
        final tree = treeObject();
        return tree != null ? cast tree.getBracketPairsInRange(range, false) : CallbackIterable.empty();
    }

    public function getBracketPairsInRangeWithMinIndentation(range:Range):CallbackIterable<BracketPairWithMinIndentationInfo> {
        bracketsRequested = true;
        updateBracketPairsTree();
        final tree = treeObject();
        return tree != null ? tree.getBracketPairsInRange(range, true) : CallbackIterable.empty();
    }

    public function getBracketsInRange(range:Range, ?onlyColorizedBrackets:Bool):CallbackIterable<BracketInfo> {
        bracketsRequested = true;
        updateBracketPairsTree();
        final tree = treeObject();
        return tree != null ? tree.getBracketsInRange(range, onlyColorizedBrackets == true) : CallbackIterable.empty();
    }

    public function findMatchingBracketUp(_bracket:String, _position:IPosition, ?maxDuration:Float):Null<Range> {
        final position = textModel.validatePosition(_position);
        final languageId = textModel.getLanguageIdAtPosition(position.lineNumber, position.column);

        if (canBuildAST) {
            final closingBracketInfo = languageConfigurationService
                .getLanguageConfiguration(languageId)
                .bracketsNew.getClosingBracketInfo(_bracket);

            if (closingBracketInfo == null) {
                return null;
            }

            final bracketPair = getBracketPairsInRange(Range.fromPositions(_position, _position)).findLast((b) ->
                closingBracketInfo.closes(b.openingBracketInfo)
            );

            if (bracketPair != null) {
                return bracketPair.openingBracketRange;
            }
            return null;
        }
        else {
            // Fallback to old bracket matching code:
            final bracket = _bracket.toLowerCase();

            final bracketsSupport = languageConfigurationService.getLanguageConfiguration(languageId).brackets;

            if (bracketsSupport == null) {
                return null;
            }

            final data = bracketsSupport.textIsBracket.get(bracket);

            if (data == null) {
                return null;
            }

            return stripBracketSearchCanceled(_findMatchingBracketUp(data, position, createTimeBasedContinueBracketSearchPredicate(maxDuration)));
        }
    }

    public function matchBracket(position:IPosition, ?maxDuration:Float):Null<Array<Range>> {
        if (canBuildAST) {
            final bracketPair =
                getBracketPairsInRange(
                    Range.fromPositions(position, position)
                ).filter(
                    (item) ->
                        item.closingBracketRange != null &&
                        (item.openingBracketRange.containsPosition(position) ||
                            item.closingBracketRange.containsPosition(position))
                ).findLastMaxBy(
                    // compareBy(selector, Range.compareRangesUsingStarts)
                    (a, b) -> {
                        final rangeA = a.openingBracketRange.containsPosition(position) ? a.openingBracketRange : a.closingBracketRange;
                        final rangeB = b.openingBracketRange.containsPosition(position) ? b.openingBracketRange : b.closingBracketRange;
                        return Range.compareRangesUsingStarts(rangeA, rangeB);
                    }
                );
            if (bracketPair != null) {
                return [bracketPair.openingBracketRange, bracketPair.closingBracketRange];
            }
            return null;
        }
        else {
            // Fallback to old bracket matching code:
            final continueSearchPredicate = createTimeBasedContinueBracketSearchPredicate(maxDuration);
            return _matchBracket(textModel.validatePosition(position), continueSearchPredicate);
        }
    }

    function _establishBracketSearchOffsets(position:Position, lineTokens:LineTokens, modeBrackets:RichEditBrackets, tokenIndex:Int):{searchStartOffset:Int, searchEndOffset:Int} {
        final tokenCount = lineTokens.getCount();
        final currentLanguageId = lineTokens.getLanguageId(tokenIndex);

        // limit search to not go before `maxBracketLength`
        var searchStartOffset = position.column - 1 - modeBrackets.maxBracketLength;
        if (searchStartOffset < 0) {
            searchStartOffset = 0;
        }
        var i = tokenIndex - 1;
        while (i >= 0) {
            final tokenEndOffset = lineTokens.getEndOffset(i);
            if (tokenEndOffset <= searchStartOffset) {
                break;
            }
            if (Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(i)) || lineTokens.getLanguageId(i) != currentLanguageId) {
                searchStartOffset = tokenEndOffset;
                break;
            }
            i--;
        }

        // limit search to not go after `maxBracketLength`
        var searchEndOffset = position.column - 1 + modeBrackets.maxBracketLength;
        final lineLength = lineTokens.getLineContent().length;
        if (lineLength < searchEndOffset) {
            searchEndOffset = lineLength;
        }
        for (i in tokenIndex + 1...tokenCount) {
            final tokenStartOffset = lineTokens.getStartOffset(i);
            if (tokenStartOffset >= searchEndOffset) {
                break;
            }
            if (Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(i)) || lineTokens.getLanguageId(i) != currentLanguageId) {
                searchEndOffset = tokenStartOffset;
                break;
            }
        }

        return {searchStartOffset: searchStartOffset, searchEndOffset: searchEndOffset};
    }

    function _matchBracket(position:Position, continueSearchPredicate:ContinueBracketSearchPredicate):Null<Array<Range>> {
        final lineNumber = position.lineNumber;
        final lineTokens = textModel.tokenization.getLineTokens(lineNumber);
        final lineText = textModel.getLineContent(lineNumber);

        final tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
        if (tokenIndex < 0) {
            return null;
        }
        final currentModeBrackets = languageConfigurationService.getLanguageConfiguration(lineTokens.getLanguageId(tokenIndex)).brackets;

        // check that the token is not to be ignored
        if (currentModeBrackets != null && !Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(tokenIndex))) {

            final offsets = _establishBracketSearchOffsets(position, lineTokens, currentModeBrackets, tokenIndex);
            var searchStartOffset = offsets.searchStartOffset;
            final searchEndOffset = offsets.searchEndOffset;

            // it might be the case that [currentTokenStart -> currentTokenEnd] contains multiple brackets
            // `bestResult` will contain the most right-side result
            var bestResult:Null<Array<Range>> = null;
            while (true) {
                final foundBracket = BracketsUtils.findNextBracketInRange(currentModeBrackets.forwardRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (foundBracket == null) {
                    // there are no more brackets in this text
                    break;
                }

                // check that we didn't hit a bracket too far away from position
                if (foundBracket.startColumn <= position.column && position.column <= foundBracket.endColumn) {
                    final foundBracketText = lineText.substring(foundBracket.startColumn - 1, foundBracket.endColumn - 1).toLowerCase();
                    final r = _matchFoundBracket(foundBracket, currentModeBrackets.textIsBracket.get(foundBracketText), currentModeBrackets.textIsOpenBracket.get(foundBracketText) == true, continueSearchPredicate);
                    if (r != null) {
                        if (isCanceledPair(r)) {
                            return null;
                        }
                        bestResult = r;
                    }
                }

                searchStartOffset = foundBracket.endColumn - 1;
            }

            if (bestResult != null) {
                return bestResult;
            }
        }

        // If position is in between two tokens, try also looking in the previous token
        if (tokenIndex > 0 && lineTokens.getStartOffset(tokenIndex) == position.column - 1) {
            final prevTokenIndex = tokenIndex - 1;
            final prevModeBrackets = languageConfigurationService.getLanguageConfiguration(lineTokens.getLanguageId(prevTokenIndex)).brackets;

            // check that previous token is not to be ignored
            if (prevModeBrackets != null && !Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(prevTokenIndex))) {

                final offsets = _establishBracketSearchOffsets(position, lineTokens, prevModeBrackets, prevTokenIndex);

                final foundBracket = BracketsUtils.findPrevBracketInRange(prevModeBrackets.reversedRegex, lineNumber, lineText, offsets.searchStartOffset, offsets.searchEndOffset);

                // check that we didn't hit a bracket too far away from position
                if (foundBracket != null && foundBracket.startColumn <= position.column && position.column <= foundBracket.endColumn) {
                    final foundBracketText = lineText.substring(foundBracket.startColumn - 1, foundBracket.endColumn - 1).toLowerCase();
                    final r = _matchFoundBracket(foundBracket, prevModeBrackets.textIsBracket.get(foundBracketText), prevModeBrackets.textIsOpenBracket.get(foundBracketText) == true, continueSearchPredicate);
                    if (r != null) {
                        if (isCanceledPair(r)) {
                            return null;
                        }
                        return r;
                    }
                }
            }
        }

        return null;
    }

    /**
     * Returns the two ranges, null, or a canceled pair (`isCanceledPair`,
     * Monaco's `BracketSearchCanceled`).
     */
    function _matchFoundBracket(foundBracket:Range, data:Null<RichEditBracket>, isOpen:Bool, continueSearchPredicate:ContinueBracketSearchPredicate):Null<Array<Range>> {
        if (data == null) {
            return null;
        }

        final matched = (
            isOpen
                ? _findMatchingBracketDown(data, foundBracket.getEndPosition(), continueSearchPredicate)
                : _findMatchingBracketUp(data, foundBracket.getStartPosition(), continueSearchPredicate)
        );

        if (matched == null) {
            return null;
        }

        if (matched == BracketSearchCanceled.INSTANCE) {
            return [BracketSearchCanceled.INSTANCE, BracketSearchCanceled.INSTANCE];
        }

        return [foundBracket, matched];
    }

    /**
     * Returns the range, null, or `BracketSearchCanceled.INSTANCE`.
     */
    function _findMatchingBracketUp(bracket:RichEditBracket, position:Position, continueSearchPredicate:ContinueBracketSearchPredicate):Null<Range> {
        final languageId = bracket.languageId;
        final reversedBracketRegex = bracket.reversedRegex;
        var count = -1;

        var totalCallCount = 0;
        final searchPrevMatchingBracketInRange = (lineNumber:Int, lineText:String, searchStartOffset:Int, searchEndOffset:Int) -> {
            while (true) {
                if (continueSearchPredicate != null && (++totalCallCount) % 100 == 0 && !continueSearchPredicate()) {
                    return BracketSearchCanceled.INSTANCE;
                }
                final r = BracketsUtils.findPrevBracketInRange(reversedBracketRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r == null) {
                    break;
                }

                final hitText = lineText.substring(r.startColumn - 1, r.endColumn - 1).toLowerCase();
                if (bracket.isOpen(hitText)) {
                    count++;
                }
                else if (bracket.isClose(hitText)) {
                    count--;
                }

                if (count == 0) {
                    return r;
                }

                searchEndOffset = r.startColumn - 1;
            }

            return null;
        };

        var lineNumber = position.lineNumber;
        while (lineNumber >= 1) {
            final lineTokens = textModel.tokenization.getLineTokens(lineNumber);
            final tokenCount = lineTokens.getCount();
            final lineText = textModel.getLineContent(lineNumber);

            var tokenIndex = tokenCount - 1;
            var searchStartOffset = lineText.length;
            var searchEndOffset = lineText.length;
            if (lineNumber == position.lineNumber) {
                tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
                searchStartOffset = position.column - 1;
                searchEndOffset = position.column - 1;
            }

            var prevSearchInToken = true;
            while (tokenIndex >= 0) {
                final searchInToken = (lineTokens.getLanguageId(tokenIndex) == languageId && !Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(tokenIndex)));

                if (searchInToken) {
                    // this token should be searched
                    if (prevSearchInToken) {
                        // the previous token should be searched, simply extend searchStartOffset
                        searchStartOffset = lineTokens.getStartOffset(tokenIndex);
                    }
                    else {
                        // the previous token should not be searched
                        searchStartOffset = lineTokens.getStartOffset(tokenIndex);
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                }
                else {
                    // this token should not be searched
                    if (prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = searchPrevMatchingBracketInRange(lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return r;
                        }
                    }
                }

                prevSearchInToken = searchInToken;
                tokenIndex--;
            }

            if (prevSearchInToken && searchStartOffset != searchEndOffset) {
                final r = searchPrevMatchingBracketInRange(lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r != null) {
                    return r;
                }
            }
            lineNumber--;
        }

        return null;
    }

    /**
     * Returns the range, null, or `BracketSearchCanceled.INSTANCE`.
     */
    function _findMatchingBracketDown(bracket:RichEditBracket, position:Position, continueSearchPredicate:ContinueBracketSearchPredicate):Null<Range> {
        final languageId = bracket.languageId;
        final bracketRegex = bracket.forwardRegex;
        var count = 1;

        var totalCallCount = 0;
        final searchNextMatchingBracketInRange = (lineNumber:Int, lineText:String, searchStartOffset:Int, searchEndOffset:Int) -> {
            while (true) {
                if (continueSearchPredicate != null && (++totalCallCount) % 100 == 0 && !continueSearchPredicate()) {
                    return BracketSearchCanceled.INSTANCE;
                }
                final r = BracketsUtils.findNextBracketInRange(bracketRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r == null) {
                    break;
                }

                final hitText = lineText.substring(r.startColumn - 1, r.endColumn - 1).toLowerCase();
                if (bracket.isOpen(hitText)) {
                    count++;
                }
                else if (bracket.isClose(hitText)) {
                    count--;
                }

                if (count == 0) {
                    return r;
                }

                searchStartOffset = r.endColumn - 1;
            }

            return null;
        };

        final lineCount = textModel.getLineCount();
        for (lineNumber in position.lineNumber...lineCount + 1) {
            final lineTokens = textModel.tokenization.getLineTokens(lineNumber);
            final tokenCount = lineTokens.getCount();
            final lineText = textModel.getLineContent(lineNumber);

            var tokenIndex = 0;
            var searchStartOffset = 0;
            var searchEndOffset = 0;
            if (lineNumber == position.lineNumber) {
                tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
                searchStartOffset = position.column - 1;
                searchEndOffset = position.column - 1;
            }

            var prevSearchInToken = true;
            while (tokenIndex < tokenCount) {
                final searchInToken = (lineTokens.getLanguageId(tokenIndex) == languageId && !Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(tokenIndex)));

                if (searchInToken) {
                    // this token should be searched
                    if (prevSearchInToken) {
                        // the previous token should be searched, simply extend searchEndOffset
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                    else {
                        // the previous token should not be searched
                        searchStartOffset = lineTokens.getStartOffset(tokenIndex);
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                }
                else {
                    // this token should not be searched
                    if (prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = searchNextMatchingBracketInRange(lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return r;
                        }
                    }
                }

                prevSearchInToken = searchInToken;
                tokenIndex++;
            }

            if (prevSearchInToken && searchStartOffset != searchEndOffset) {
                final r = searchNextMatchingBracketInRange(lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r != null) {
                    return r;
                }
            }
        }

        return null;
    }

    public function findPrevBracket(_position:IPosition):Null<IFoundBracket> {
        final position = textModel.validatePosition(_position);

        if (canBuildAST) {
            bracketsRequested = true;
            updateBracketPairsTree();
            final tree = treeObject();
            return tree != null ? tree.getFirstBracketBefore(position) : null;
        }

        var languageId:Null<String> = null;
        var modeBrackets:Null<RichEditBrackets> = null;
        var bracketConfig:Null<LanguageBracketsConfiguration> = null;
        var lineNumber = position.lineNumber;
        while (lineNumber >= 1) {
            final lineTokens = textModel.tokenization.getLineTokens(lineNumber);
            final tokenCount = lineTokens.getCount();
            final lineText = textModel.getLineContent(lineNumber);

            var tokenIndex = tokenCount - 1;
            var searchStartOffset = lineText.length;
            var searchEndOffset = lineText.length;
            if (lineNumber == position.lineNumber) {
                tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
                searchStartOffset = position.column - 1;
                searchEndOffset = position.column - 1;
                final tokenLanguageId = lineTokens.getLanguageId(tokenIndex);
                if (languageId != tokenLanguageId) {
                    languageId = tokenLanguageId;
                    modeBrackets = languageConfigurationService.getLanguageConfiguration(languageId).brackets;
                    bracketConfig = languageConfigurationService.getLanguageConfiguration(languageId).bracketsNew;
                }
            }

            var prevSearchInToken = true;
            while (tokenIndex >= 0) {
                final tokenLanguageId = lineTokens.getLanguageId(tokenIndex);

                if (languageId != tokenLanguageId) {
                    // language id change!
                    if (modeBrackets != null && bracketConfig != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = BracketsUtils.findPrevBracketInRange(modeBrackets.reversedRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return _toFoundBracket(bracketConfig, r);
                        }
                        prevSearchInToken = false;
                    }
                    languageId = tokenLanguageId;
                    modeBrackets = languageConfigurationService.getLanguageConfiguration(languageId).brackets;
                    bracketConfig = languageConfigurationService.getLanguageConfiguration(languageId).bracketsNew;
                }

                final searchInToken = (modeBrackets != null && !Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(tokenIndex)));

                if (searchInToken) {
                    // this token should be searched
                    if (prevSearchInToken) {
                        // the previous token should be searched, simply extend searchStartOffset
                        searchStartOffset = lineTokens.getStartOffset(tokenIndex);
                    }
                    else {
                        // the previous token should not be searched
                        searchStartOffset = lineTokens.getStartOffset(tokenIndex);
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                }
                else {
                    // this token should not be searched
                    if (bracketConfig != null && modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = BracketsUtils.findPrevBracketInRange(modeBrackets.reversedRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return _toFoundBracket(bracketConfig, r);
                        }
                    }
                }

                prevSearchInToken = searchInToken;
                tokenIndex--;
            }

            if (bracketConfig != null && modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                final r = BracketsUtils.findPrevBracketInRange(modeBrackets.reversedRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r != null) {
                    return _toFoundBracket(bracketConfig, r);
                }
            }
            lineNumber--;
        }

        return null;
    }

    public function findNextBracket(_position:IPosition):Null<IFoundBracket> {
        final position = textModel.validatePosition(_position);

        if (canBuildAST) {
            bracketsRequested = true;
            updateBracketPairsTree();
            final tree = treeObject();
            return tree != null ? tree.getFirstBracketAfter(position) : null;
        }

        final lineCount = textModel.getLineCount();

        var languageId:Null<String> = null;
        var modeBrackets:Null<RichEditBrackets> = null;
        var bracketConfig:Null<LanguageBracketsConfiguration> = null;
        for (lineNumber in position.lineNumber...lineCount + 1) {
            final lineTokens = textModel.tokenization.getLineTokens(lineNumber);
            final tokenCount = lineTokens.getCount();
            final lineText = textModel.getLineContent(lineNumber);

            var tokenIndex = 0;
            var searchStartOffset = 0;
            var searchEndOffset = 0;
            if (lineNumber == position.lineNumber) {
                tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
                searchStartOffset = position.column - 1;
                searchEndOffset = position.column - 1;
                final tokenLanguageId = lineTokens.getLanguageId(tokenIndex);
                if (languageId != tokenLanguageId) {
                    languageId = tokenLanguageId;
                    modeBrackets = languageConfigurationService.getLanguageConfiguration(languageId).brackets;
                    bracketConfig = languageConfigurationService.getLanguageConfiguration(languageId).bracketsNew;
                }
            }

            var prevSearchInToken = true;
            while (tokenIndex < tokenCount) {
                final tokenLanguageId = lineTokens.getLanguageId(tokenIndex);

                if (languageId != tokenLanguageId) {
                    // language id change!
                    if (bracketConfig != null && modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = BracketsUtils.findNextBracketInRange(modeBrackets.forwardRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return _toFoundBracket(bracketConfig, r);
                        }
                        prevSearchInToken = false;
                    }
                    languageId = tokenLanguageId;
                    modeBrackets = languageConfigurationService.getLanguageConfiguration(languageId).brackets;
                    bracketConfig = languageConfigurationService.getLanguageConfiguration(languageId).bracketsNew;
                }

                final searchInToken = (modeBrackets != null && !Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(tokenIndex)));
                if (searchInToken) {
                    // this token should be searched
                    if (prevSearchInToken) {
                        // the previous token should be searched, simply extend searchEndOffset
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                    else {
                        // the previous token should not be searched
                        searchStartOffset = lineTokens.getStartOffset(tokenIndex);
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                }
                else {
                    // this token should not be searched
                    if (bracketConfig != null && modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = BracketsUtils.findNextBracketInRange(modeBrackets.forwardRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return _toFoundBracket(bracketConfig, r);
                        }
                    }
                }

                prevSearchInToken = searchInToken;
                tokenIndex++;
            }

            if (bracketConfig != null && modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                final r = BracketsUtils.findNextBracketInRange(modeBrackets.forwardRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r != null) {
                    return _toFoundBracket(bracketConfig, r);
                }
            }
        }

        return null;
    }

    public function findEnclosingBrackets(_position:IPosition, ?maxDuration:Float):Null<Array<Range>> {
        final position = textModel.validatePosition(_position);

        if (canBuildAST) {
            final range = Range.fromPositions(position);
            final bracketPair =
                getBracketPairsInRange(Range.fromPositions(position, position)).findLast(
                    (item) -> item.closingBracketRange != null && item.range.strictContainsRange(range)
                );
            if (bracketPair != null) {
                return [bracketPair.openingBracketRange, bracketPair.closingBracketRange];
            }
            return null;
        }

        final continueSearchPredicate = createTimeBasedContinueBracketSearchPredicate(maxDuration);
        final lineCount = textModel.getLineCount();
        final savedCounts = new Map<String, Array<Int>>();

        var counts:Array<Int> = [];
        final resetCounts = (languageId:String, modeBrackets:Null<RichEditBrackets>) -> {
            if (!savedCounts.exists(languageId)) {
                final tmp = [];
                final len = modeBrackets != null ? modeBrackets.brackets.length : 0;
                for (i in 0...len) {
                    tmp[i] = 0;
                }
                savedCounts.set(languageId, tmp);
            }
            counts = savedCounts.get(languageId);
        };

        var totalCallCount = 0;
        final searchInRange = (modeBrackets:RichEditBrackets, lineNumber:Int, lineText:String, searchStartOffset:Int, searchEndOffset:Int) -> {
            while (true) {
                if (continueSearchPredicate != null && (++totalCallCount) % 100 == 0 && !continueSearchPredicate()) {
                    return [BracketSearchCanceled.INSTANCE, BracketSearchCanceled.INSTANCE];
                }
                final r = BracketsUtils.findNextBracketInRange(modeBrackets.forwardRegex, lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r == null) {
                    break;
                }

                final hitText = lineText.substring(r.startColumn - 1, r.endColumn - 1).toLowerCase();
                final bracket = modeBrackets.textIsBracket.get(hitText);
                if (bracket != null) {
                    if (bracket.isOpen(hitText)) {
                        counts[bracket.index]++;
                    }
                    else if (bracket.isClose(hitText)) {
                        counts[bracket.index]--;
                    }

                    if (counts[bracket.index] == -1) {
                        return _matchFoundBracket(r, bracket, false, continueSearchPredicate);
                    }
                }

                searchStartOffset = r.endColumn - 1;
            }
            return null;
        };

        var languageId:Null<String> = null;
        var modeBrackets:Null<RichEditBrackets> = null;
        for (lineNumber in position.lineNumber...lineCount + 1) {
            final lineTokens = textModel.tokenization.getLineTokens(lineNumber);
            final tokenCount = lineTokens.getCount();
            final lineText = textModel.getLineContent(lineNumber);

            var tokenIndex = 0;
            var searchStartOffset = 0;
            var searchEndOffset = 0;
            if (lineNumber == position.lineNumber) {
                tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
                searchStartOffset = position.column - 1;
                searchEndOffset = position.column - 1;
                final tokenLanguageId = lineTokens.getLanguageId(tokenIndex);
                if (languageId != tokenLanguageId) {
                    languageId = tokenLanguageId;
                    modeBrackets = languageConfigurationService.getLanguageConfiguration(languageId).brackets;
                    resetCounts(languageId, modeBrackets);
                }
            }

            var prevSearchInToken = true;
            while (tokenIndex < tokenCount) {
                final tokenLanguageId = lineTokens.getLanguageId(tokenIndex);

                if (languageId != tokenLanguageId) {
                    // language id change!
                    if (modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = searchInRange(modeBrackets, lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return stripBracketSearchCanceledPair(r);
                        }
                        prevSearchInToken = false;
                    }
                    languageId = tokenLanguageId;
                    modeBrackets = languageConfigurationService.getLanguageConfiguration(languageId).brackets;
                    resetCounts(languageId, modeBrackets);
                }

                final searchInToken = (modeBrackets != null && !Supports.ignoreBracketsInToken(lineTokens.getStandardTokenType(tokenIndex)));
                if (searchInToken) {
                    // this token should be searched
                    if (prevSearchInToken) {
                        // the previous token should be searched, simply extend searchEndOffset
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                    else {
                        // the previous token should not be searched
                        searchStartOffset = lineTokens.getStartOffset(tokenIndex);
                        searchEndOffset = lineTokens.getEndOffset(tokenIndex);
                    }
                }
                else {
                    // this token should not be searched
                    if (modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                        final r = searchInRange(modeBrackets, lineNumber, lineText, searchStartOffset, searchEndOffset);
                        if (r != null) {
                            return stripBracketSearchCanceledPair(r);
                        }
                    }
                }

                prevSearchInToken = searchInToken;
                tokenIndex++;
            }

            if (modeBrackets != null && prevSearchInToken && searchStartOffset != searchEndOffset) {
                final r = searchInRange(modeBrackets, lineNumber, lineText, searchStartOffset, searchEndOffset);
                if (r != null) {
                    return stripBracketSearchCanceledPair(r);
                }
            }
        }

        return null;
    }

    function _toFoundBracket(bracketConfig:LanguageBracketsConfiguration, r:Null<Range>):Null<IFoundBracket> {
        if (r == null) {
            return null;
        }

        var text = textModel.getValueInRange(r);
        text = text.toLowerCase();

        final bracketInfo = bracketConfig.getBracketInfo(text);
        if (bracketInfo == null) {
            return null;
        }

        return {
            range: r,
            bracketInfo: bracketInfo
        };
    }

    static function createTimeBasedContinueBracketSearchPredicate(maxDuration:Null<Float>):ContinueBracketSearchPredicate {
        if (maxDuration == null) {
            return () -> true;
        }
        else {
            final startTime = haxe.Timer.stamp() * 1000;
            return () -> {
                return (haxe.Timer.stamp() * 1000 - startTime <= maxDuration);
            };
        }
    }

    static inline function isCanceledPair(result:Array<Range>):Bool {
        return result[0] == BracketSearchCanceled.INSTANCE;
    }

    static function stripBracketSearchCanceled(result:Null<Range>):Null<Range> {
        if (result == BracketSearchCanceled.INSTANCE) {
            return null;
        }
        return result;
    }

    static function stripBracketSearchCanceledPair(result:Null<Array<Range>>):Null<Array<Range>> {
        if (result != null && isCanceledPair(result)) {
            return null;
        }
        return result;
    }

}

/**
 * Monaco's `IReference<BracketPairsTree>` made by `createDisposableRef`.
 */
private class BracketPairsTreeRef implements IDisposable {

    public final object:BracketPairsTree;
    final disposable:Null<IDisposable>;

    public function new(object:BracketPairsTree, ?disposable:IDisposable) {
        this.object = object;
        this.disposable = disposable;
    }

    public function dispose():Void {
        if (disposable != null) {
            disposable.dispose();
        }
    }

}

private typedef ContinueBracketSearchPredicate = () -> Bool;

/**
 * Monaco's `BracketSearchCanceled` result: a sentinel range compared by
 * identity (never returned to callers). A pair result that was canceled
 * holds it twice.
 */
private class BracketSearchCanceled {

    public static final INSTANCE:Range = new Range(0, 0, 0, 0);

}
