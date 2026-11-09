// Ported from vscode src/vs/editor/contrib/indentation/common/indentation.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.indentation.common;

import cityscape.base.common.Strings;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Model.IIdentifiedSingleEditOperation;
import cityscape.common.Model.ITextModel;
import cityscape.common.commands.ShiftCommand;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Indentation.normalizeIndentation;
import cityscape.common.core.Selection;
import cityscape.common.languages.AutoIndent.TextModelVirtualModel;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.languages.supports.IndentationLineProcessor.ProcessedIndentRulesSupport;

/**
 * Module functions of indentation.ts (common).
 */
class Indentation {

    public static function getReindentEditOperations(model:ITextModel, languageConfigurationService:ILanguageConfigurationService, startLineNumber:Int, endLineNumber:Int):Array<IIdentifiedSingleEditOperation> {
        if (model.getLineCount() == 1 && model.getLineMaxColumn(1) == 1) {
            // Model is empty
            return [];
        }

        final indentationRulesSupport = languageConfigurationService.getLanguageConfiguration(model.getLanguageId()).indentRulesSupport;
        if (indentationRulesSupport == null) {
            return [];
        }

        final processedIndentRulesSupport = new ProcessedIndentRulesSupport(new TextModelVirtualModel(model), indentationRulesSupport, languageConfigurationService);
        endLineNumber = Std.int(Math.min(endLineNumber, model.getLineCount()));

        // Skip `unIndentedLinePattern` lines
        while (startLineNumber <= endLineNumber) {
            if (!processedIndentRulesSupport.shouldIgnore(startLineNumber)) {
                break;
            }

            startLineNumber++;
        }

        if (startLineNumber > endLineNumber - 1) {
            return [];
        }

        final options = model.getOptions();
        final tabSize = options.tabSize;
        final indentSize = options.indentSize;
        final insertSpaces = options.insertSpaces;
        final shiftIndent = (indentation:String, ?count:Int) -> {
            if (count == null || count == 0) {
                count = 1;
            }
            return ShiftCommand.shiftIndent(indentation, indentation.length + count, tabSize, indentSize, insertSpaces);
        };
        final unshiftIndent = (indentation:String, ?count:Int) -> {
            if (count == null || count == 0) {
                count = 1;
            }
            return ShiftCommand.unshiftIndent(indentation, indentation.length + count, tabSize, indentSize, insertSpaces);
        };
        final indentEdits:Array<IIdentifiedSingleEditOperation> = [];

        // indentation being passed to lines below

        // Calculate indentation for the first line
        // If there is no passed-in indentation, we use the indentation of the first line as base.
        final currentLineText = model.getLineContent(startLineNumber);
        var globalIndent = Strings.getLeadingWhitespace(currentLineText);
        // idealIndentForNextLine doesn't equal globalIndent when there is a line matching `indentNextLinePattern`.
        var idealIndentForNextLine:String = globalIndent;

        if (processedIndentRulesSupport.shouldIncrease(startLineNumber)) {
            idealIndentForNextLine = shiftIndent(idealIndentForNextLine);
            globalIndent = shiftIndent(globalIndent);
        }
        else if (processedIndentRulesSupport.shouldIndentNextLine(startLineNumber)) {
            idealIndentForNextLine = shiftIndent(idealIndentForNextLine);
        }

        startLineNumber++;

        // Calculate indentation adjustment for all following lines
        for (lineNumber in startLineNumber...endLineNumber + 1) {
            if (doesLineStartWithString(model, lineNumber)) {
                continue;
            }
            final text = model.getLineContent(lineNumber);
            final oldIndentation = Strings.getLeadingWhitespace(text);
            final currentIdealIndent = idealIndentForNextLine;

            if (processedIndentRulesSupport.shouldDecrease(lineNumber, currentIdealIndent)) {
                idealIndentForNextLine = unshiftIndent(idealIndentForNextLine);
                globalIndent = unshiftIndent(globalIndent);
            }

            if (oldIndentation != idealIndentForNextLine) {
                indentEdits.push(EditOperation.replaceMove(new Selection(lineNumber, 1, lineNumber, oldIndentation.length + 1), normalizeIndentation(idealIndentForNextLine, indentSize, insertSpaces)));
            }

            // calculate idealIndentForNextLine
            if (processedIndentRulesSupport.shouldIgnore(lineNumber)) {
                // In reindent phase, if the line matches `unIndentedLinePattern` we inherit indentation from above lines
                // but don't change globalIndent and idealIndentForNextLine.
                continue;
            }
            else if (processedIndentRulesSupport.shouldIncrease(lineNumber, currentIdealIndent)) {
                globalIndent = shiftIndent(globalIndent);
                idealIndentForNextLine = globalIndent;
            }
            else if (processedIndentRulesSupport.shouldIndentNextLine(lineNumber, currentIdealIndent)) {
                idealIndentForNextLine = shiftIndent(idealIndentForNextLine);
            }
            else {
                idealIndentForNextLine = globalIndent;
            }
        }

        return indentEdits;
    }

    static function doesLineStartWithString(model:ITextModel, lineNumber:Int):Bool {
        if (!model.tokenization.isCheapToTokenize(lineNumber)) {
            return false;
        }
        final lineTokens = model.tokenization.getLineTokens(lineNumber);
        return lineTokens.getStandardTokenType(0) == StandardTokenType.String;
    }

}
