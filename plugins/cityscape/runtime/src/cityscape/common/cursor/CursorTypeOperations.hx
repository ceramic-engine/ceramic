// Ported from vscode src/vs/editor/common/cursor/cursorTypeOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.common.CursorCommon;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.Model.ITextModel;
import cityscape.common.commands.ShiftCommand;
import cityscape.common.commands.SurroundSelectionCommand;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.CursorTypeEditOperations;

class TypeOperations {

    public static function indent(config:CursorConfiguration, model:Null<ICursorSimpleModel>, selections:Null<Array<Selection>>):Array<ICommand> {
        if (model == null || selections == null) {
            return [];
        }

        final commands:Array<ICommand> = [];
        for (i in 0...selections.length) {
            commands[i] = new ShiftCommand(selections[i], {
                isUnshift: false,
                tabSize: config.tabSize,
                indentSize: config.indentSize,
                insertSpaces: config.insertSpaces,
                useTabStops: config.useTabStops,
                autoIndent: config.autoIndent
            }, config.languageConfigurationService);
        }
        return commands;
    }

    public static function outdent(config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>):Array<ICommand> {
        final commands:Array<ICommand> = [];
        for (i in 0...selections.length) {
            commands[i] = new ShiftCommand(selections[i], {
                isUnshift: true,
                tabSize: config.tabSize,
                indentSize: config.indentSize,
                insertSpaces: config.insertSpaces,
                useTabStops: config.useTabStops,
                autoIndent: config.autoIndent
            }, config.languageConfigurationService);
        }
        return commands;
    }

    public static function shiftIndent(config:CursorConfiguration, indentation:String, ?count:Int):String {
        return CursorTypeEditOperations.shiftIndent(config, indentation, count);
    }

    public static function unshiftIndent(config:CursorConfiguration, indentation:String, ?count:Int):String {
        return CursorTypeEditOperations.unshiftIndent(config, indentation, count);
    }

    public static function paste(config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>, text:String, pasteOnNewLine:Bool, multicursorText:Array<String>):EditOperationResult {
        return PasteOperation.getEdits(config, model, selections, text, pasteOnNewLine, multicursorText);
    }

    public static function tab(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>):Array<ICommand> {
        return TabOperation.getCommands(config, model, selections);
    }

    public static function compositionType(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, text:String, replacePrevCharCnt:Int, replaceNextCharCnt:Int, positionDelta:Int):EditOperationResult {
        return CompositionOperation.getEdits(prevEditOperationType, config, model, selections, text, replacePrevCharCnt, replaceNextCharCnt, positionDelta);
    }

    /**
     * `/^[ \\t]+$/.test(text)`.
     */
    static function isOnlySpacesAndTabs(text:String):Bool {
        if (text.length == 0) {
            return false;
        }
        return !CursorTypeEditOperations.containsNonSpaceOrTab(text);
    }

    /**
     * This is very similar with typing, but the character is already in the text buffer!
     */
    public static function compositionEndWithInterceptors(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, compositions:Null<Array<CompositionOutcome>>, selections:Array<Selection>, autoClosedCharacters:Array<Range>):Null<EditOperationResult> {
        if (compositions == null) {
            // could not deduce what the composition did
            return null;
        }

        var insertedText:Null<String> = null;
        for (composition in compositions) {
            if (insertedText == null) {
                insertedText = composition.insertedText;
            }
            else if (insertedText != composition.insertedText) {
                // not all selections agree on what was typed
                return null;
            }
        }

        if (insertedText == null || insertedText.length != 1) {
            // we're only interested in the case where a single character was inserted
            return null;
        }

        final ch = insertedText;

        var hasDeletion = false;
        for (composition in compositions) {
            if (composition.deletedText.length != 0) {
                hasDeletion = true;
                break;
            }
        }

        if (hasDeletion) {
            // Check if this could have been a surround selection

            if (!CursorTypeEditOperations.shouldSurroundChar(config, ch) || !config.surroundingPairs.exists(ch)) {
                return null;
            }

            final isTypingAQuoteCharacter = CursorCommon.isQuote(ch);

            for (composition in compositions) {
                if (composition.deletedSelectionStart != 0 || composition.deletedSelectionEnd != composition.deletedText.length) {
                    // more text was deleted than was selected, so this could not have been a surround selection
                    return null;
                }
                if (isOnlySpacesAndTabs(composition.deletedText)) {
                    // deleted text was only whitespace
                    return null;
                }
                if (isTypingAQuoteCharacter && CursorCommon.isQuote(composition.deletedText)) {
                    // deleted text was a quote
                    return null;
                }
            }

            final positions:Array<Position> = [];
            for (selection in selections) {
                if (!selection.isEmpty()) {
                    return null;
                }
                positions.push(selection.getPosition());
            }

            if (positions.length != compositions.length) {
                return null;
            }

            final commands:Array<Null<ICommand>> = [];
            for (i in 0...positions.length) {
                commands.push(new CompositionSurroundSelectionCommand(positions[i], compositions[i].deletedText, config.surroundingPairs.get(ch)));
            }
            return new EditOperationResult(EditOperationType.TypingOther, commands, {
                shouldPushStackElementBefore: true,
                shouldPushStackElementAfter: false
            });
        }

        final autoClosingOvertypeEdits = AutoClosingOvertypeWithInterceptorsOperation.getEdits(config, model, selections, autoClosedCharacters, ch);
        if (autoClosingOvertypeEdits != null) {
            return autoClosingOvertypeEdits;
        }

        final autoClosingOpenCharEdits = AutoClosingOpenCharTypeOperation.getEdits(config, model, selections, ch, true, false);
        if (autoClosingOpenCharEdits != null) {
            return autoClosingOpenCharEdits;
        }

        return null;
    }

    public static function typeWithInterceptors(isDoingComposition:Bool, prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, autoClosedCharacters:Array<Range>, ch:String):EditOperationResult {

        final enterEdits = EnterOperation.getEdits(config, model, selections, ch, isDoingComposition);
        if (enterEdits != null) {
            return enterEdits;
        }

        final autoIndentEdits = AutoIndentOperation.getEdits(config, model, selections, ch, isDoingComposition);
        if (autoIndentEdits != null) {
            return autoIndentEdits;
        }

        final autoClosingOverTypeEdits = AutoClosingOvertypeOperation.getEdits(prevEditOperationType, config, model, selections, autoClosedCharacters, ch);
        if (autoClosingOverTypeEdits != null) {
            return autoClosingOverTypeEdits;
        }

        final autoClosingOpenCharEdits = AutoClosingOpenCharTypeOperation.getEdits(config, model, selections, ch, false, isDoingComposition);
        if (autoClosingOpenCharEdits != null) {
            return autoClosingOpenCharEdits;
        }

        final surroundSelectionEdits = SurroundSelectionOperation.getEdits(config, model, selections, ch, isDoingComposition);
        if (surroundSelectionEdits != null) {
            return surroundSelectionEdits;
        }

        final interceptorElectricCharOperation = InterceptorElectricCharOperation.getEdits(prevEditOperationType, config, model, selections, ch, isDoingComposition);
        if (interceptorElectricCharOperation != null) {
            return interceptorElectricCharOperation;
        }

        return SimpleCharacterTypeOperation.getEdits(prevEditOperationType, selections, ch);
    }

    public static function typeWithoutInterceptors(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, str:String):EditOperationResult {
        return TypeWithoutInterceptorsOperation.getEdits(prevEditOperationType, selections, str);
    }

}

class CompositionOutcome {

    public final deletedText:String;
    public final deletedSelectionStart:Int;
    public final deletedSelectionEnd:Int;
    public final insertedText:String;
    public final insertedSelectionStart:Int;
    public final insertedSelectionEnd:Int;

    public function new(deletedText:String, deletedSelectionStart:Int, deletedSelectionEnd:Int, insertedText:String, insertedSelectionStart:Int, insertedSelectionEnd:Int) {
        this.deletedText = deletedText;
        this.deletedSelectionStart = deletedSelectionStart;
        this.deletedSelectionEnd = deletedSelectionEnd;
        this.insertedText = insertedText;
        this.insertedSelectionStart = insertedSelectionStart;
        this.insertedSelectionEnd = insertedSelectionEnd;
    }

}
