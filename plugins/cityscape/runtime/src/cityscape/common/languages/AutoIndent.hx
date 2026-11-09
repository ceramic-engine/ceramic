// Ported from vscode src/vs/editor/common/languages/autoIndent.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.Strings;
import cityscape.common.CursorCommon.CursorConfiguration;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageConfiguration.IndentAction;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.languages.supports.IndentRules.IndentConsts;
import cityscape.common.languages.supports.IndentationLineProcessor;
import cityscape.common.tokens.LineTokens.IViewLineTokens;

/**
 * The tokenization part of an `IVirtualModel`.
 *
 * Monaco's `forceTokenization` is optional: here it is required, and an
 * implementation without it does nothing.
 */
interface IVirtualModelTokenization {
    function getLineTokens(lineNumber:Int):IViewLineTokens;
    function getLanguageId():String;
    function getLanguageIdAtPosition(lineNumber:Int, column:Int):String;
    function forceTokenization(lineNumber:Int):Void;
}

/**
 * A model as auto indentation sees it (Monaco's structural type, which an
 * `ITextModel` satisfies; `TextModelVirtualModel` adapts an `ITextModel`).
 */
interface IVirtualModel {
    var tokenization(get, never):IVirtualModelTokenization;
    function getLineContent(lineNumber:Int):String;
}

/**
 * An `ITextModel` seen as an `IVirtualModel` (Monaco passes the text model
 * itself, structurally typed).
 */
class TextModelVirtualModel implements IVirtualModel implements IVirtualModelTokenization {

    final model:ITextModel;

    public function new(model:ITextModel) {
        this.model = model;
    }

    public var tokenization(get, never):IVirtualModelTokenization;
    inline function get_tokenization():IVirtualModelTokenization {
        return this;
    }

    public function getLineContent(lineNumber:Int):String {
        return model.getLineContent(lineNumber);
    }

    public function getLineTokens(lineNumber:Int):IViewLineTokens {
        return model.tokenization.getLineTokens(lineNumber);
    }

    public function getLanguageId():String {
        return model.tokenization.getLanguageId();
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        return model.tokenization.getLanguageIdAtPosition(lineNumber, column);
    }

    public function forceTokenization(lineNumber:Int):Void {
        model.tokenization.forceTokenization(lineNumber);
    }

}

/**
 * Monaco's `IIndentConverter` (`normalizeIndentation` is optional).
 */
typedef IIndentConverter = {
    var shiftIndent:(indentation:String) -> String;
    var unshiftIndent:(indentation:String) -> String;
    @:optional var normalizeIndentation:(indentation:String) -> String;
}

/**
 * The result of `getInheritIndentForLine` (Monaco's
 * `{ indentation, action, line? }`).
 */
class InheritIndent {

    public final indentation:String;
    public final action:Null<IndentAction>;
    public final line:Null<Int>;

    public function new(indentation:String, action:Null<IndentAction>, ?line:Int) {
        this.indentation = indentation;
        this.action = action;
        this.line = line;
    }

}

/**
 * The result of `getIndentForEnter`.
 */
typedef IndentForEnter = {
    var beforeEnter:String;
    var afterEnter:String;
}

/**
 * A virtual model whose tokens and content of one line are replaced
 * (`createVirtualModelWithModifiedTokensAtLine`).
 */
private class VirtualModelWithModifiedTokensAtLine implements IVirtualModel implements IVirtualModelTokenization {

    final model:ITextModel;
    final modifiedLineNumber:Int;
    final modifiedTokens:IViewLineTokens;

    public function new(model:ITextModel, modifiedLineNumber:Int, modifiedTokens:IViewLineTokens) {
        this.model = model;
        this.modifiedLineNumber = modifiedLineNumber;
        this.modifiedTokens = modifiedTokens;
    }

    public var tokenization(get, never):IVirtualModelTokenization;
    inline function get_tokenization():IVirtualModelTokenization {
        return this;
    }

    public function getLineTokens(lineNumber:Int):IViewLineTokens {
        if (lineNumber == modifiedLineNumber) {
            return modifiedTokens;
        }
        else {
            return model.tokenization.getLineTokens(lineNumber);
        }
    }

    public function getLanguageId():String {
        return model.getLanguageId();
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        return model.getLanguageIdAtPosition(lineNumber, column);
    }

    public function forceTokenization(lineNumber:Int):Void {
        // Monaco's virtual model has no forceTokenization
    }

    public function getLineContent(lineNumber:Int):String {
        if (lineNumber == modifiedLineNumber) {
            return modifiedTokens.getLineContent();
        }
        else {
            return model.getLineContent(lineNumber);
        }
    }

}

/**
 * Module functions of autoIndent.ts. The functions taking an
 * `IVirtualModel` accept an `ITextModel` through `TextModelVirtualModel`
 * (Monaco passes the text model, structurally typed).
 */
class AutoIndent {

    /**
     * `/^\s+$/.test(text)` (JavaScript's `\s`).
     */
    static function isOnlyWhitespace(text:String):Bool {
        if (text.length == 0) {
            return false;
        }
        for (i in 0...text.length) {
            if (!Strings.isJsWhitespace(StringTools.fastCodeAt(text, i))) {
                return false;
            }
        }
        return true;
    }

    /**
     * `/^\s*$/.test(text)` (JavaScript's `\s`).
     */
    @:allow(cityscape.common.cursor)
    static function isEmptyOrWhitespace(text:String):Bool {
        return text.length == 0 || isOnlyWhitespace(text);
    }

    /**
     * Get nearest preceding line which doesn't match unIndentPattern or contains all whitespace.
     * Result:
     * -1: run into the boundary of embedded languages
     * 0: every line above are invalid
     * else: nearest preceding line of the same language
     */
    static function getPrecedingValidLine(model:IVirtualModel, lineNumber:Int, processedIndentRulesSupport:ProcessedIndentRulesSupport):Int {
        final languageId = model.tokenization.getLanguageIdAtPosition(lineNumber, 0);
        if (lineNumber > 1) {
            var lastLineNumber = lineNumber - 1;
            var resultLineNumber = -1;

            while (lastLineNumber >= 1) {
                if (model.tokenization.getLanguageIdAtPosition(lastLineNumber, 0) != languageId) {
                    return resultLineNumber;
                }
                final text = model.getLineContent(lastLineNumber);
                if (processedIndentRulesSupport.shouldIgnore(lastLineNumber) || isOnlyWhitespace(text) || text == '') {
                    resultLineNumber = lastLineNumber;
                    lastLineNumber--;
                    continue;
                }

                return lastLineNumber;
            }
        }

        return -1;
    }

    /**
     * Get inherited indentation from above lines.
     * 1. Find the nearest preceding line which doesn't match unIndentedLinePattern.
     * 2. If this line matches indentNextLinePattern or increaseIndentPattern, it means that the indent level of `lineNumber` should be 1 greater than this line.
     * 3. If this line doesn't match any indent rules
     *   a. check whether the line above it matches indentNextLinePattern
     *   b. If not, the indent level of this line is the result
     *   c. If so, it means the indent of this line is *temporary*, go upward utill we find a line whose indent is not temporary (the same workflow a -> b -> c).
     * 4. Otherwise, we fail to get an inherited indent from aboves. Return null and we should not touch the indent of `lineNumber`
     *
     * This function only return the inherited indent based on above lines, it doesn't check whether current line should decrease or not.
     */
    public static function getInheritIndentForLine(
        autoIndent:EditorAutoIndentStrategy,
        model:IVirtualModel,
        lineNumber:Int,
        honorIntentialIndent:Bool = true,
        languageConfigurationService:ILanguageConfigurationService
    ):Null<InheritIndent> {
        if ((autoIndent : Int) < (EditorAutoIndentStrategy.Full : Int)) {
            return null;
        }

        final indentRulesSupport = languageConfigurationService.getLanguageConfiguration(model.tokenization.getLanguageId()).indentRulesSupport;
        if (indentRulesSupport == null) {
            return null;
        }
        final processedIndentRulesSupport = new ProcessedIndentRulesSupport(model, indentRulesSupport, languageConfigurationService);

        if (lineNumber <= 1) {
            return new InheritIndent('', null);
        }

        // Use no indent if this is the first non-blank line
        var priorLineNumber = lineNumber - 1;
        while (priorLineNumber > 0) {
            if (model.getLineContent(priorLineNumber) != '') {
                break;
            }
            if (priorLineNumber == 1) {
                return new InheritIndent('', null);
            }
            priorLineNumber--;
        }

        final precedingUnIgnoredLine = getPrecedingValidLine(model, lineNumber, processedIndentRulesSupport);
        if (precedingUnIgnoredLine < 0) {
            return null;
        }
        else if (precedingUnIgnoredLine < 1) {
            return new InheritIndent('', null);
        }

        if (processedIndentRulesSupport.shouldIncrease(precedingUnIgnoredLine) || processedIndentRulesSupport.shouldIndentNextLine(precedingUnIgnoredLine)) {
            final precedingUnIgnoredLineContent = model.getLineContent(precedingUnIgnoredLine);
            return new InheritIndent(Strings.getLeadingWhitespace(precedingUnIgnoredLineContent), IndentAction.Indent, precedingUnIgnoredLine);
        }
        else if (processedIndentRulesSupport.shouldDecrease(precedingUnIgnoredLine)) {
            final precedingUnIgnoredLineContent = model.getLineContent(precedingUnIgnoredLine);
            return new InheritIndent(Strings.getLeadingWhitespace(precedingUnIgnoredLineContent), null, precedingUnIgnoredLine);
        }
        else {
            // precedingUnIgnoredLine can not be ignored.
            // it doesn't increase indent of following lines
            // it doesn't increase just next line
            // so current line is not affect by precedingUnIgnoredLine
            // and then we should get a correct inheritted indentation from above lines
            if (precedingUnIgnoredLine == 1) {
                return new InheritIndent(Strings.getLeadingWhitespace(model.getLineContent(precedingUnIgnoredLine)), null, precedingUnIgnoredLine);
            }

            final previousLine = precedingUnIgnoredLine - 1;

            final previousLineIndentMetadata = indentRulesSupport.getIndentMetadata(model.getLineContent(previousLine));
            if ((previousLineIndentMetadata & (IndentConsts.INCREASE_MASK | IndentConsts.DECREASE_MASK)) == 0 &&
                (previousLineIndentMetadata & IndentConsts.INDENT_NEXTLINE_MASK) != 0) {
                var stopLine = 0;
                var i = previousLine - 1;
                while (i > 0) {
                    if (processedIndentRulesSupport.shouldIndentNextLine(i)) {
                        i--;
                        continue;
                    }
                    stopLine = i;
                    break;
                }

                return new InheritIndent(Strings.getLeadingWhitespace(model.getLineContent(stopLine + 1)), null, stopLine + 1);
            }

            if (honorIntentialIndent) {
                return new InheritIndent(Strings.getLeadingWhitespace(model.getLineContent(precedingUnIgnoredLine)), null, precedingUnIgnoredLine);
            }
            else {
                // search from precedingUnIgnoredLine until we find one whose indent is not temporary
                var i = precedingUnIgnoredLine;
                while (i > 0) {
                    if (processedIndentRulesSupport.shouldIncrease(i)) {
                        return new InheritIndent(Strings.getLeadingWhitespace(model.getLineContent(i)), IndentAction.Indent, i);
                    }
                    else if (processedIndentRulesSupport.shouldIndentNextLine(i)) {
                        var stopLine = 0;
                        var j = i - 1;
                        while (j > 0) {
                            if (processedIndentRulesSupport.shouldIndentNextLine(i)) {
                                j--;
                                continue;
                            }
                            stopLine = j;
                            break;
                        }

                        return new InheritIndent(Strings.getLeadingWhitespace(model.getLineContent(stopLine + 1)), null, stopLine + 1);
                    }
                    else if (processedIndentRulesSupport.shouldDecrease(i)) {
                        return new InheritIndent(Strings.getLeadingWhitespace(model.getLineContent(i)), null, i);
                    }
                    i--;
                }

                return new InheritIndent(Strings.getLeadingWhitespace(model.getLineContent(1)), null, 1);
            }
        }
    }

    public static function getGoodIndentForLine(
        autoIndent:EditorAutoIndentStrategy,
        virtualModel:IVirtualModel,
        languageId:String,
        lineNumber:Int,
        indentConverter:IIndentConverter,
        languageConfigurationService:ILanguageConfigurationService
    ):Null<String> {
        if ((autoIndent : Int) < (EditorAutoIndentStrategy.Full : Int)) {
            return null;
        }

        final richEditSupport = languageConfigurationService.getLanguageConfiguration(languageId);
        if (richEditSupport == null) {
            return null;
        }

        final indentRulesSupport = languageConfigurationService.getLanguageConfiguration(languageId).indentRulesSupport;
        if (indentRulesSupport == null) {
            return null;
        }

        final processedIndentRulesSupport = new ProcessedIndentRulesSupport(virtualModel, indentRulesSupport, languageConfigurationService);
        final indent = getInheritIndentForLine(autoIndent, virtualModel, lineNumber, true, languageConfigurationService);

        if (indent != null) {
            final inheritLine = indent.line;
            if (inheritLine != null) {
                // Apply enter action as long as there are only whitespace lines between inherited line and this line.
                var shouldApplyEnterRules = true;
                for (inBetweenLine in inheritLine...(lineNumber - 1)) {
                    if (!isEmptyOrWhitespace(virtualModel.getLineContent(inBetweenLine))) {
                        shouldApplyEnterRules = false;
                        break;
                    }
                }
                if (shouldApplyEnterRules) {
                    final enterResult = richEditSupport.onEnter(autoIndent, '', virtualModel.getLineContent(inheritLine), '');

                    if (enterResult != null) {
                        var indentation = Strings.getLeadingWhitespace(virtualModel.getLineContent(inheritLine));

                        if (enterResult.removeText != null && enterResult.removeText != 0) {
                            indentation = indentation.substring(0, indentation.length - enterResult.removeText);
                        }

                        if (
                            (enterResult.indentAction == IndentAction.Indent) ||
                            (enterResult.indentAction == IndentAction.IndentOutdent)
                        ) {
                            indentation = indentConverter.shiftIndent(indentation);
                        }
                        else if (enterResult.indentAction == IndentAction.Outdent) {
                            indentation = indentConverter.unshiftIndent(indentation);
                        }

                        if (processedIndentRulesSupport.shouldDecrease(lineNumber)) {
                            indentation = indentConverter.unshiftIndent(indentation);
                        }

                        if (enterResult.appendText != null && enterResult.appendText.length > 0) {
                            indentation += enterResult.appendText;
                        }

                        return Strings.getLeadingWhitespace(indentation);
                    }
                }
            }

            if (processedIndentRulesSupport.shouldDecrease(lineNumber)) {
                if (indent.action == IndentAction.Indent) {
                    return indent.indentation;
                }
                else {
                    return indentConverter.unshiftIndent(indent.indentation);
                }
            }
            else {
                if (indent.action == IndentAction.Indent) {
                    return indentConverter.shiftIndent(indent.indentation);
                }
                else {
                    return indent.indentation;
                }
            }
        }
        return null;
    }

    public static function getIndentForEnter(
        autoIndent:EditorAutoIndentStrategy,
        model:ITextModel,
        range:Range,
        indentConverter:IIndentConverter,
        languageConfigurationService:ILanguageConfigurationService
    ):Null<IndentForEnter> {
        if ((autoIndent : Int) < (EditorAutoIndentStrategy.Full : Int)) {
            return null;
        }
        final languageId = model.getLanguageIdAtPosition(range.startLineNumber, range.startColumn);
        final indentRulesSupport = languageConfigurationService.getLanguageConfiguration(languageId).indentRulesSupport;
        if (indentRulesSupport == null) {
            return null;
        }

        model.tokenization.forceTokenization(range.startLineNumber);
        final indentationContextProcessor = new IndentationContextProcessor(model, languageConfigurationService);
        final processedContextTokens = indentationContextProcessor.getProcessedTokenContextAroundRange(range);
        final afterEnterProcessedTokens = processedContextTokens.afterRangeProcessedTokens;
        final beforeEnterProcessedTokens = processedContextTokens.beforeRangeProcessedTokens;
        final beforeEnterIndent = Strings.getLeadingWhitespace(beforeEnterProcessedTokens.getLineContent());

        final virtualModel = createVirtualModelWithModifiedTokensAtLine(model, range.startLineNumber, beforeEnterProcessedTokens);
        final languageIsDifferentFromLineStart = IndentationLineProcessorUtils.isLanguageDifferentFromLineStart(model, range.getStartPosition());
        final currentLine = model.getLineContent(range.startLineNumber);
        final currentLineIndent = Strings.getLeadingWhitespace(currentLine);
        final afterEnterAction = getInheritIndentForLine(autoIndent, virtualModel, range.startLineNumber + 1, true, languageConfigurationService);
        if (afterEnterAction == null) {
            final beforeEnter = languageIsDifferentFromLineStart ? currentLineIndent : beforeEnterIndent;
            return {
                beforeEnter: beforeEnter,
                afterEnter: beforeEnter
            };
        }

        var afterEnterIndent = languageIsDifferentFromLineStart ? currentLineIndent : afterEnterAction.indentation;

        if (afterEnterAction.action == IndentAction.Indent) {
            afterEnterIndent = indentConverter.shiftIndent(afterEnterIndent);
        }

        if (indentRulesSupport.shouldDecrease(afterEnterProcessedTokens.getLineContent())) {
            afterEnterIndent = indentConverter.unshiftIndent(afterEnterIndent);
        }

        return {
            beforeEnter: languageIsDifferentFromLineStart ? currentLineIndent : beforeEnterIndent,
            afterEnter: afterEnterIndent
        };
    }

    /**
     * We should always allow intentional indentation. It means, if users change the indentation of `lineNumber` and the content of
     * this line doesn't match decreaseIndentPattern, we should not adjust the indentation.
     */
    public static function getIndentActionForType(
        cursorConfig:CursorConfiguration,
        model:ITextModel,
        range:Range,
        ch:String,
        indentConverter:IIndentConverter,
        languageConfigurationService:ILanguageConfigurationService
    ):Null<String> {
        final autoIndent = cursorConfig.autoIndent;
        if ((autoIndent : Int) < (EditorAutoIndentStrategy.Full : Int)) {
            return null;
        }
        final languageIsDifferentFromLineStart = IndentationLineProcessorUtils.isLanguageDifferentFromLineStart(model, range.getStartPosition());
        if (languageIsDifferentFromLineStart) {
            // this line has mixed languages and indentation rules will not work
            return null;
        }

        final languageId = model.getLanguageIdAtPosition(range.startLineNumber, range.startColumn);
        final indentRulesSupport = languageConfigurationService.getLanguageConfiguration(languageId).indentRulesSupport;
        if (indentRulesSupport == null) {
            return null;
        }

        final indentationContextProcessor = new IndentationContextProcessor(model, languageConfigurationService);
        final processedContextTokens = indentationContextProcessor.getProcessedTokenContextAroundRange(range);
        final beforeRangeText = processedContextTokens.beforeRangeProcessedTokens.getLineContent();
        final afterRangeText = processedContextTokens.afterRangeProcessedTokens.getLineContent();
        final textAroundRange = beforeRangeText + afterRangeText;
        final textAroundRangeWithCharacter = beforeRangeText + ch + afterRangeText;

        // If previous content already matches decreaseIndentPattern, it means indentation of this line should already be adjusted
        // Users might change the indentation by purpose and we should honor that instead of readjusting.
        if (!indentRulesSupport.shouldDecrease(textAroundRange) && indentRulesSupport.shouldDecrease(textAroundRangeWithCharacter)) {
            // after typing `ch`, the content matches decreaseIndentPattern, we should adjust the indent to a good manner.
            // 1. Get inherited indent action
            final r = getInheritIndentForLine(autoIndent, new TextModelVirtualModel(model), range.startLineNumber, false, languageConfigurationService);
            if (r == null) {
                return null;
            }

            var indentation = r.indentation;
            if (r.action != IndentAction.Indent) {
                indentation = indentConverter.unshiftIndent(indentation);
            }

            return indentation;
        }

        final previousLineNumber = range.startLineNumber - 1;
        if (previousLineNumber > 0) {
            final previousLine = model.getLineContent(previousLineNumber);
            if (indentRulesSupport.shouldIndentNextLine(previousLine) && indentRulesSupport.shouldIncrease(textAroundRangeWithCharacter)) {
                final inheritedIndentationData = getInheritIndentForLine(autoIndent, new TextModelVirtualModel(model), range.startLineNumber, false, languageConfigurationService);
                final inheritedIndentation = (inheritedIndentationData != null ? inheritedIndentationData.indentation : null);
                if (inheritedIndentation != null) {
                    final currentLine = model.getLineContent(range.startLineNumber);
                    final actualCurrentIndentation = Strings.getLeadingWhitespace(currentLine);
                    final inferredCurrentIndentation = indentConverter.shiftIndent(inheritedIndentation);
                    // If the inferred current indentation is not equal to the actual current indentation, then the indentation has been intentionally changed, in that case keep it
                    final inferredIndentationEqualsActual = inferredCurrentIndentation == actualCurrentIndentation;
                    final textAroundRangeContainsOnlyWhitespace = isEmptyOrWhitespace(textAroundRange);
                    final autoClosingPairs = cursorConfig.autoClosingPairs.autoClosingPairsOpenByEnd.get(ch);
                    final autoClosingPairExists = autoClosingPairs != null && autoClosingPairs.length > 0;
                    final isChFirstNonWhitespaceCharacterAndInAutoClosingPair = autoClosingPairExists && textAroundRangeContainsOnlyWhitespace;
                    if (inferredIndentationEqualsActual && isChFirstNonWhitespaceCharacterAndInAutoClosingPair) {
                        return inheritedIndentation;
                    }
                }
            }
        }

        return null;
    }

    public static function getIndentMetadata(
        model:ITextModel,
        lineNumber:Int,
        languageConfigurationService:ILanguageConfigurationService
    ):Null<Int> {
        final indentRulesSupport = languageConfigurationService.getLanguageConfiguration(model.getLanguageId()).indentRulesSupport;
        if (indentRulesSupport == null) {
            return null;
        }
        if (lineNumber < 1 || lineNumber > model.getLineCount()) {
            return null;
        }
        return indentRulesSupport.getIndentMetadata(model.getLineContent(lineNumber));
    }

    static function createVirtualModelWithModifiedTokensAtLine(model:ITextModel, modifiedLineNumber:Int, modifiedTokens:IViewLineTokens):IVirtualModel {
        return new VirtualModelWithModifiedTokensAtLine(model, modifiedLineNumber, modifiedTokens);
    }

}
