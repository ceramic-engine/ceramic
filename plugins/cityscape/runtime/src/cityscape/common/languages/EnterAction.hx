// Ported from vscode src/vs/editor/common/languages/enterAction.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.LanguageConfigurationRegistry;
import cityscape.common.languages.supports.IndentationLineProcessor;

/**
 * Module functions of enterAction.ts (the module name is also the name of
 * the `EnterAction` type of languageConfiguration.ts).
 */
class EnterActionUtils {

    public static function getEnterAction(
        autoIndent:EditorAutoIndentStrategy,
        model:ITextModel,
        range:Range,
        languageConfigurationService:ILanguageConfigurationService
    ):Null<CompleteEnterAction> {
        model.tokenization.forceTokenization(range.startLineNumber);
        final languageId = model.getLanguageIdAtPosition(range.startLineNumber, range.startColumn);
        final richEditSupport = languageConfigurationService.getLanguageConfiguration(languageId);
        if (richEditSupport == null) {
            return null;
        }
        final indentationContextProcessor = new IndentationContextProcessor(model, languageConfigurationService);
        final processedContextTokens = indentationContextProcessor.getProcessedTokenContextAroundRange(range);
        final previousLineText = processedContextTokens.previousLineProcessedTokens.getLineContent();
        final beforeEnterText = processedContextTokens.beforeRangeProcessedTokens.getLineContent();
        final afterEnterText = processedContextTokens.afterRangeProcessedTokens.getLineContent();

        final enterResult = richEditSupport.onEnter(autoIndent, previousLineText, beforeEnterText, afterEnterText);
        if (enterResult == null) {
            return null;
        }

        final indentAction = enterResult.indentAction;
        var appendText = enterResult.appendText;
        final removeText:Int = enterResult.removeText != null ? enterResult.removeText : 0;

        // Here we add `\t` to appendText first because enterAction is leveraging appendText and removeText to change indentation.
        if (appendText == null || appendText.length == 0) {
            if (
                (indentAction == IndentAction.Indent) ||
                (indentAction == IndentAction.IndentOutdent)
            ) {
                appendText = '\t';
            }
            else {
                appendText = '';
            }
        }
        else if (indentAction == IndentAction.Indent) {
            appendText = '\t' + appendText;
        }

        var indentation = LanguageConfigurationRegistry.getIndentationAtPosition(model, range.startLineNumber, range.startColumn);
        if (removeText != 0) {
            indentation = indentation.substring(0, indentation.length - removeText);
        }

        return {
            indentAction: indentAction,
            appendText: appendText,
            removeText: removeText,
            indentation: indentation
        };
    }

}
