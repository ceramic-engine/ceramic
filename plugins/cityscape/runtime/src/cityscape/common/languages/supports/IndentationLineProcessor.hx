// Ported from vscode src/vs/editor/common/languages/supports/indentationLineProcessor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.AutoIndent;
import cityscape.common.languages.LanguageConfigurationRegistry;
import cityscape.common.languages.Supports;
import cityscape.common.languages.supports.IndentRules;
import cityscape.common.tokens.LineTokens;

/**
 * This class is a wrapper class around {@link IndentRulesSupport}.
 * It processes the lines by removing the language configuration brackets from the regex, string and comment tokens.
 * It then calls into the {@link IndentRulesSupport} to validate the indentation conditions.
 */
class ProcessedIndentRulesSupport {

    final _indentRulesSupport:IndentRulesSupport;
    final _indentationLineProcessor:IndentationLineProcessor;

    public function new(
        model:IVirtualModel,
        indentRulesSupport:IndentRulesSupport,
        languageConfigurationService:ILanguageConfigurationService
    ) {
        _indentRulesSupport = indentRulesSupport;
        _indentationLineProcessor = new IndentationLineProcessor(model, languageConfigurationService);
    }

    /**
     * Apply the new indentation and return whether the indentation level should be increased after the given line number
     */
    public function shouldIncrease(lineNumber:Int, ?newIndentation:String):Bool {
        final processedLine = _indentationLineProcessor.getProcessedLine(lineNumber, newIndentation);
        return _indentRulesSupport.shouldIncrease(processedLine);
    }

    /**
     * Apply the new indentation and return whether the indentation level should be decreased after the given line number
     */
    public function shouldDecrease(lineNumber:Int, ?newIndentation:String):Bool {
        final processedLine = _indentationLineProcessor.getProcessedLine(lineNumber, newIndentation);
        return _indentRulesSupport.shouldDecrease(processedLine);
    }

    /**
     * Apply the new indentation and return whether the indentation level should remain unchanged at the given line number
     */
    public function shouldIgnore(lineNumber:Int, ?newIndentation:String):Bool {
        final processedLine = _indentationLineProcessor.getProcessedLine(lineNumber, newIndentation);
        return _indentRulesSupport.shouldIgnore(processedLine);
    }

    /**
     * Apply the new indentation and return whether the indentation level should increase on the line after the given line number
     */
    public function shouldIndentNextLine(lineNumber:Int, ?newIndentation:String):Bool {
        final processedLine = _indentationLineProcessor.getProcessedLine(lineNumber, newIndentation);
        return _indentRulesSupport.shouldIndentNextLine(processedLine);
    }

}

typedef ProcessedTokenContext = {
    final beforeRangeProcessedTokens:IViewLineTokens;
    final afterRangeProcessedTokens:IViewLineTokens;
    final previousLineProcessedTokens:IViewLineTokens;
}

/**
 * This class fetches the processed text around a range which can be used for indentation evaluation.
 * It returns:
 * - The processed text before the given range and on the same start line
 * - The processed text after the given range and on the same end line
 * - The processed text on the previous line
 */
class IndentationContextProcessor {

    final model:ITextModel;
    final indentationLineProcessor:IndentationLineProcessor;

    public function new(
        model:ITextModel,
        languageConfigurationService:ILanguageConfigurationService
    ) {
        this.model = model;
        indentationLineProcessor = new IndentationLineProcessor(new TextModelVirtualModel(model), languageConfigurationService);
    }

    /**
     * Returns the processed text, stripped from the language configuration brackets within the string, comment and regex tokens, around the given range
     */
    public function getProcessedTokenContextAroundRange(range:Range):ProcessedTokenContext {
        final beforeRangeProcessedTokens = _getProcessedTokensBeforeRange(range);
        final afterRangeProcessedTokens = _getProcessedTokensAfterRange(range);
        final previousLineProcessedTokens = _getProcessedPreviousLineTokens(range);
        return {
            beforeRangeProcessedTokens: beforeRangeProcessedTokens,
            afterRangeProcessedTokens: afterRangeProcessedTokens,
            previousLineProcessedTokens: previousLineProcessedTokens
        };
    }

    function _getProcessedTokensBeforeRange(range:Range):IViewLineTokens {
        model.tokenization.forceTokenization(range.startLineNumber);
        final lineTokens = model.tokenization.getLineTokens(range.startLineNumber);
        final scopedLineTokens = Supports.createScopedLineTokens(lineTokens, range.startColumn - 1);
        var slicedTokens:IViewLineTokens;
        if (IndentationLineProcessorUtils.isLanguageDifferentFromLineStart(model, range.getStartPosition())) {
            final columnIndexWithinScope = (range.startColumn - 1) - scopedLineTokens.firstCharOffset;
            final firstCharacterOffset = scopedLineTokens.firstCharOffset;
            final lastCharacterOffset = firstCharacterOffset + columnIndexWithinScope;
            slicedTokens = lineTokens.sliceAndInflate(firstCharacterOffset, lastCharacterOffset, 0);
        }
        else {
            final columnWithinLine = range.startColumn - 1;
            slicedTokens = lineTokens.sliceAndInflate(0, columnWithinLine, 0);
        }
        final processedTokens = indentationLineProcessor.getProcessedTokens(slicedTokens);
        return processedTokens;
    }

    function _getProcessedTokensAfterRange(range:Range):IViewLineTokens {
        final position:Position = range.isEmpty() ? range.getStartPosition() : range.getEndPosition();
        model.tokenization.forceTokenization(position.lineNumber);
        final lineTokens = model.tokenization.getLineTokens(position.lineNumber);
        final scopedLineTokens = Supports.createScopedLineTokens(lineTokens, position.column - 1);
        final columnIndexWithinScope = position.column - 1 - scopedLineTokens.firstCharOffset;
        final firstCharacterOffset = scopedLineTokens.firstCharOffset + columnIndexWithinScope;
        final lastCharacterOffset = scopedLineTokens.firstCharOffset + scopedLineTokens.getLineLength();
        final slicedTokens = lineTokens.sliceAndInflate(firstCharacterOffset, lastCharacterOffset, 0);
        final processedTokens = indentationLineProcessor.getProcessedTokens(slicedTokens);
        return processedTokens;
    }

    function _getProcessedPreviousLineTokens(range:Range):IViewLineTokens {
        final getScopedLineTokensAtEndColumnOfLine = (lineNumber:Int) -> {
            model.tokenization.forceTokenization(lineNumber);
            final lineTokens = model.tokenization.getLineTokens(lineNumber);
            final endColumnOfLine = model.getLineMaxColumn(lineNumber) - 1;
            final scopedLineTokensAtEndColumn = Supports.createScopedLineTokens(lineTokens, endColumnOfLine);
            return scopedLineTokensAtEndColumn;
        };

        model.tokenization.forceTokenization(range.startLineNumber);
        final lineTokens = model.tokenization.getLineTokens(range.startLineNumber);
        final scopedLineTokens = Supports.createScopedLineTokens(lineTokens, range.startColumn - 1);
        final emptyTokens = LineTokens.createEmpty('', scopedLineTokens.languageIdCodec);
        final previousLineNumber = range.startLineNumber - 1;
        final isFirstLine = previousLineNumber == 0;
        if (isFirstLine) {
            return emptyTokens;
        }
        final canScopeExtendOnPreviousLine = scopedLineTokens.firstCharOffset == 0;
        if (!canScopeExtendOnPreviousLine) {
            return emptyTokens;
        }
        final scopedLineTokensAtEndColumnOfPreviousLine = getScopedLineTokensAtEndColumnOfLine(previousLineNumber);
        final doesLanguageContinueOnPreviousLine = scopedLineTokens.languageId == scopedLineTokensAtEndColumnOfPreviousLine.languageId;
        if (!doesLanguageContinueOnPreviousLine) {
            return emptyTokens;
        }
        final previousSlicedLineTokens = scopedLineTokensAtEndColumnOfPreviousLine.toIViewLineTokens();
        final processedTokens = indentationLineProcessor.getProcessedTokens(previousSlicedLineTokens);
        return processedTokens;
    }

}

/**
 * This class performs the actual processing of the indentation lines.
 * The brackets of the language configuration are removed from the regex, string and comment tokens.
 */
class IndentationLineProcessor {

    final model:IVirtualModel;
    final languageConfigurationService:ILanguageConfigurationService;

    public function new(
        model:IVirtualModel,
        languageConfigurationService:ILanguageConfigurationService
    ) {
        this.model = model;
        this.languageConfigurationService = languageConfigurationService;
    }

    /**
     * Get the processed line for the given line number and potentially adjust the indentation level.
     * Remove the language configuration brackets from the regex, string and comment tokens.
     */
    public function getProcessedLine(lineNumber:Int, ?newIndentation:String):String {
        final replaceIndentation = (line:String, newIndentation:String) -> {
            final currentIndentation = Strings.getLeadingWhitespace(line);
            final adjustedLine = newIndentation + line.substring(currentIndentation.length);
            return adjustedLine;
        };

        model.tokenization.forceTokenization(lineNumber);
        final tokens = model.tokenization.getLineTokens(lineNumber);
        var processedLine = getProcessedTokens(tokens).getLineContent();
        if (newIndentation != null) {
            processedLine = replaceIndentation(processedLine, newIndentation);
        }
        return processedLine;
    }

    /**
     * Process the line with the given tokens, remove the language configuration brackets from the regex, string and comment tokens.
     */
    public function getProcessedTokens(tokens:IViewLineTokens):IViewLineTokens {

        final shouldRemoveBracketsFromTokenType = (tokenType:StandardTokenType) -> {
            return tokenType == StandardTokenType.String
                || tokenType == StandardTokenType.RegEx
                || tokenType == StandardTokenType.Comment;
        };

        final languageId = tokens.getLanguageId(0);
        final bracketsConfiguration = languageConfigurationService.getLanguageConfiguration(languageId).bracketsNew;
        final bracketsRegExp = bracketsConfiguration.getBracketRegExp({global: true});
        final textAndMetadata:Array<{text:String, metadata:Int}> = [];
        tokens.forEach((tokenIndex:Int) -> {
            final tokenType = tokens.getStandardTokenType(tokenIndex);
            var text = tokens.getTokenText(tokenIndex);
            if (shouldRemoveBracketsFromTokenType(tokenType)) {
                text = replaceAllWithEmpty(text, bracketsRegExp);
            }
            final metadata = tokens.getMetadata(tokenIndex);
            textAndMetadata.push({text: text, metadata: metadata});
        });
        final processedLineTokens = LineTokens.createFromTextAndMetadata(textAndMetadata, tokens.languageIdCodec);
        return processedLineTokens;
    }

    /**
     * `text.replace(regExp, '')` with a global regular expression.
     */
    static function replaceAllWithEmpty(text:String, regExp:RegExp):String {
        regExp.lastIndex = 0;
        final buf = new StringBuf();
        var last = 0;
        while (true) {
            final m = regExp.exec(text);
            if (m == null) {
                break;
            }
            final matchText = m[0];
            buf.add(text.substring(last, m.index));
            last = m.index + matchText.length;
            if (matchText.length == 0) {
                regExp.lastIndex++;
            }
        }
        buf.add(text.substring(last));
        regExp.lastIndex = 0;
        return buf.toString();
    }

}

/**
 * Module functions of indentationLineProcessor.ts.
 */
class IndentationLineProcessorUtils {

    public static function isLanguageDifferentFromLineStart(model:ITextModel, position:Position):Bool {
        model.tokenization.forceTokenization(position.lineNumber);
        final lineTokens = model.tokenization.getLineTokens(position.lineNumber);
        final scopedLineTokens = Supports.createScopedLineTokens(lineTokens, position.column - 1);
        final doesScopeStartAtOffsetZero = scopedLineTokens.firstCharOffset == 0;
        final isScopedLanguageEqualToFirstLanguageOnLine = lineTokens.getLanguageId(0) == scopedLineTokens.languageId;
        final languageIsDifferentFromLineStart = !doesScopeStartAtOffsetZero && !isScopedLanguageEqualToFirstLanguageOnLine;
        return languageIsDifferentFromLineStart;
    }

}
