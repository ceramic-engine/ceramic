// Ported from vscode src/vs/editor/contrib/indentation/browser/indentation.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.indentation.view;

import cityscape.Cityscape;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Strings;
import cityscape.common.EditorCommon;
import cityscape.common.EditorContextKeys;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Model;
import cityscape.common.commands.ShiftCommand;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.AutoIndent;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.languages.supports.IndentRules.IndentConsts;
import cityscape.common.services.ModelService;
import cityscape.common.tokens.LineTokens;
import cityscape.contrib.indentation.common.IndentUtils;
import cityscape.contrib.indentation.common.Indentation.getReindentEditOperations;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * The indentation actions and the auto indentation on paste
 * (indentation.ts), registered by `IndentationRegistration.register`.
 *
 * Monaco's `ChangeIndentationSizeAction` (indent using tabs, indent using
 * spaces, change tab display size) asks for the size in a quick pick. There
 * is no quick input here: the size comes from the arguments of the action, a
 * number or `{tabSize: number}` (`editor.getAction(id).run(4)`,
 * `executeCommand(id, {tabSize: 4})`); without a size between 1 and 8 the
 * action does nothing (Monaco's quick pick dismissed).
 *
 * The creation options of `DetectIndentation` are the model service's
 * defaults (Cityscape has no configuration service, see `ModelService`).
 */

/**
 * Monaco's `TextEdit` as the auto indentation on paste builds it.
 */
typedef AutoIndentTextEdit = {
    var range:IRange;
    var text:String;
    @:optional var eol:EndOfLineSequence;
}

class IndentationToSpacesAction extends EditorAction {

    public static inline final ID = 'editor.action.indentationToSpaces';

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: IndentationToSpacesAction.ID,
            label: r != null ? r.localize('indentationToSpaces', "Convert Indentation to Spaces") : "Convert Indentation to Spaces",
            alias: 'Convert Indentation to Spaces',
            precondition: EditorContextKeys.writable,
            metadata: {
                description: r != null ? r.localize('indentationToSpacesDescription', "Convert the tab indentation to spaces.") : "Convert the tab indentation to spaces."
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getModel();
        if (model == null) {
            return;
        }
        final modelOpts = model.getOptions();
        final selection = editor.getSelection();
        if (selection == null) {
            return;
        }
        final command = new IndentationToSpacesCommand(selection, modelOpts.tabSize);

        editor.pushUndoStop();
        editor.executeCommands(this.id, [command]);
        editor.pushUndoStop();

        model.updateOptions({
            insertSpaces: true
        });
    }

}

class IndentationToTabsAction extends EditorAction {

    public static inline final ID = 'editor.action.indentationToTabs';

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: IndentationToTabsAction.ID,
            label: r != null ? r.localize('indentationToTabs', "Convert Indentation to Tabs") : "Convert Indentation to Tabs",
            alias: 'Convert Indentation to Tabs',
            precondition: EditorContextKeys.writable,
            metadata: {
                description: r != null ? r.localize('indentationToTabsDescription', "Convert the spaces indentation to tabs.") : "Convert the spaces indentation to tabs."
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getModel();
        if (model == null) {
            return;
        }
        final modelOpts = model.getOptions();
        final selection = editor.getSelection();
        if (selection == null) {
            return;
        }
        final command = new IndentationToTabsCommand(selection, modelOpts.tabSize);

        editor.pushUndoStop();
        editor.executeCommands(this.id, [command]);
        editor.pushUndoStop();

        model.updateOptions({
            insertSpaces: false
        });
    }

}

/**
 * Sets the tab size of the model (and the indentation size and kind unless
 * `displaySizeOnly`). Monaco picks the size in a quick pick; here it is the
 * argument of the action: a number or `{tabSize: number}`.
 */
class ChangeIndentationSizeAction extends EditorAction {

    final insertSpaces:Bool;
    final displaySizeOnly:Bool;

    public function new(insertSpaces:Bool, displaySizeOnly:Bool, opts:IActionOptions) {
        super(opts);
        this.insertSpaces = insertSpaces;
        this.displaySizeOnly = displaySizeOnly;
    }

    /**
     * The size given to the action, or -1 (Monaco's quick pick dismissed).
     * Monaco's picks are 1 to 8.
     */
    static function pickedSize(args:Any):Int {
        var value:Any = args;
        if (value != null && !JsValues.isNumber(value) && JsValues.isObject(value)) {
            value = JsValues.field(value, 'tabSize');
        }
        if (value == null || !JsValues.isNumber(value)) {
            return -1;
        }
        final n:Float = value;
        if (n != Math.ffloor(n) || n < 1 || n > 8) {
            return -1;
        }
        return Std.int(n);
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getModel();
        if (model == null) {
            return;
        }

        final pickedVal = pickedSize(args);
        if (pickedVal < 0) {
            return;
        }
        if (!model.isDisposed()) {
            if (this.displaySizeOnly) {
                model.updateOptions({
                    tabSize: pickedVal
                });
            }
            else {
                model.updateOptions({
                    tabSize: pickedVal,
                    indentSize: pickedVal,
                    insertSpaces: this.insertSpaces
                });
            }
        }
    }

}

class IndentUsingTabs extends ChangeIndentationSizeAction {

    public static inline final ID = 'editor.action.indentUsingTabs';

    public function new(?r:EditorExtensionsRegistry) {
        super(false, false, {
            id: IndentUsingTabs.ID,
            label: r != null ? r.localize('indentUsingTabs', "Indent Using Tabs") : "Indent Using Tabs",
            alias: 'Indent Using Tabs',
            precondition: null,
            metadata: {
                description: r != null ? r.localize('indentUsingTabsDescription', "Use indentation with tabs.") : "Use indentation with tabs."
            }
        });
    }

}

class IndentUsingSpaces extends ChangeIndentationSizeAction {

    public static inline final ID = 'editor.action.indentUsingSpaces';

    public function new(?r:EditorExtensionsRegistry) {
        super(true, false, {
            id: IndentUsingSpaces.ID,
            label: r != null ? r.localize('indentUsingSpaces', "Indent Using Spaces") : "Indent Using Spaces",
            alias: 'Indent Using Spaces',
            precondition: null,
            metadata: {
                description: r != null ? r.localize('indentUsingSpacesDescription', "Use indentation with spaces.") : "Use indentation with spaces."
            }
        });
    }

}

class ChangeTabDisplaySize extends ChangeIndentationSizeAction {

    public static inline final ID = 'editor.action.changeTabDisplaySize';

    public function new(?r:EditorExtensionsRegistry) {
        super(true, true, {
            id: ChangeTabDisplaySize.ID,
            label: r != null ? r.localize('changeTabDisplaySize', "Change Tab Display Size") : "Change Tab Display Size",
            alias: 'Change Tab Display Size',
            precondition: null,
            metadata: {
                description: r != null ? r.localize('changeTabDisplaySizeDescription', "Change the space size equivalent of the tab.") : "Change the space size equivalent of the tab."
            }
        });
    }

}

class DetectIndentation extends EditorAction {

    public static inline final ID = 'editor.action.detectIndentation';

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: DetectIndentation.ID,
            label: r != null ? r.localize('detectIndentation', "Detect Indentation from Content") : "Detect Indentation from Content",
            alias: 'Detect Indentation from Content',
            precondition: null,
            metadata: {
                description: r != null ? r.localize('detectIndentationDescription', "Detect the indentation from content.") : "Detect the indentation from content."
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getModel();
        if (model == null) {
            return;
        }

        // Monaco's `modelService.getCreationOptions(languageId, uri, isForSimpleWidget)`
        final creationOpts = ModelService._readModelOptions({}, model.isForSimpleWidget);
        model.detectIndentation(creationOpts.insertSpaces, creationOpts.tabSize);
    }

}

class ReindentLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.reindentlines',
            label: r != null ? r.localize('editor.reindentlines', "Reindent Lines") : "Reindent Lines",
            alias: 'Reindent Lines',
            precondition: EditorContextKeys.writable,
            metadata: {
                description: r != null ? r.localize('editor.reindentlinesDescription', "Reindent the lines of the editor.") : "Reindent the lines of the editor."
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final languageConfigurationService = editor.context.languageConfigurationService;

        final model = editor.getModel();
        if (model == null) {
            return;
        }
        final edits = getReindentEditOperations(model, languageConfigurationService, 1, model.getLineCount());
        if (edits.length > 0) {
            editor.pushUndoStop();
            editor.executeEdits(this.id, edits);
            editor.pushUndoStop();
        }
    }

}

class ReindentSelectedLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.reindentselectedlines',
            label: r != null ? r.localize('editor.reindentselectedlines', "Reindent Selected Lines") : "Reindent Selected Lines",
            alias: 'Reindent Selected Lines',
            precondition: EditorContextKeys.writable,
            metadata: {
                description: r != null ? r.localize('editor.reindentselectedlinesDescription', "Reindent the selected lines of the editor.") : "Reindent the selected lines of the editor."
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final languageConfigurationService = editor.context.languageConfigurationService;

        final model = editor.getModel();
        if (model == null) {
            return;
        }

        final selections = editor.getSelections();
        if (selections == null) {
            return;
        }

        final edits:Array<IIdentifiedSingleEditOperation> = [];

        for (selection in selections) {
            var startLineNumber = selection.startLineNumber;
            var endLineNumber = selection.endLineNumber;

            if (startLineNumber != endLineNumber && selection.endColumn == 1) {
                endLineNumber--;
            }

            if (startLineNumber == 1) {
                if (startLineNumber == endLineNumber) {
                    continue;
                }
            }
            else {
                startLineNumber--;
            }

            final editOperations = getReindentEditOperations(model, languageConfigurationService, startLineNumber, endLineNumber);
            for (op in editOperations) {
                edits.push(op);
            }
        }

        if (edits.length > 0) {
            editor.pushUndoStop();
            editor.executeEdits(this.id, edits);
            editor.pushUndoStop();
        }
    }

}

class AutoIndentOnPasteCommand implements ICommand {

    final _edits:Array<AutoIndentTextEdit>;

    final _initialSelection:Selection;
    var _selectionId:Null<String>;

    public final insertsAutoWhitespace:Bool = false;

    public function new(edits:Array<AutoIndentTextEdit>, initialSelection:Selection) {
        this._initialSelection = initialSelection;
        this._edits = [];
        this._selectionId = null;

        for (edit in edits) {
            if (edit.range != null && edit.text != null) {
                this._edits.push(edit);
            }
        }
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        for (edit in this._edits) {
            builder.addEditOperation(Range.lift(edit.range), edit.text);
        }

        var selectionIsSet = false;
        if (this._edits.length == 1 && this._initialSelection.isEmpty()) {
            if (this._edits[0].range.startColumn == this._initialSelection.endColumn &&
                this._edits[0].range.startLineNumber == this._initialSelection.endLineNumber) {
                selectionIsSet = true;
                this._selectionId = builder.trackSelection(this._initialSelection, true);
            }
            else if (this._edits[0].range.endColumn == this._initialSelection.startColumn &&
                this._edits[0].range.endLineNumber == this._initialSelection.startLineNumber) {
                selectionIsSet = true;
                this._selectionId = builder.trackSelection(this._initialSelection, false);
            }
        }

        if (!selectionIsSet) {
            this._selectionId = builder.trackSelection(this._initialSelection);
        }
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this._selectionId);
    }

}

/**
 * Monaco's object literal `virtualModel` of `AutoIndentOnPaste.trigger`: the
 * model with the first line replaced by its new text.
 */
private class PasteVirtualModel implements IVirtualModel implements IVirtualModelTokenization {

    final model:ITextModel;
    final firstLineNumber:Int;
    final firstLineText:String;

    public function new(model:ITextModel, firstLineNumber:Int, firstLineText:String) {
        this.model = model;
        this.firstLineNumber = firstLineNumber;
        this.firstLineText = firstLineText;
    }

    public var tokenization(get, never):IVirtualModelTokenization;
    inline function get_tokenization():IVirtualModelTokenization {
        return this;
    }

    public function getLineTokens(lineNumber:Int):cityscape.common.tokens.LineTokens.IViewLineTokens {
        return model.tokenization.getLineTokens(lineNumber);
    }

    public function getLanguageId():String {
        return model.getLanguageId();
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        return model.getLanguageIdAtPosition(lineNumber, column);
    }

    public function forceTokenization(lineNumber:Int):Void {
        // Monaco's object literal has no `forceTokenization`
    }

    public function getLineContent(lineNumber:Int):String {
        if (lineNumber == firstLineNumber) {
            return firstLineText;
        }
        else {
            return model.getLineContent(lineNumber);
        }
    }

}

class AutoIndentOnPaste implements IEditorContribution {

    public static inline final ID = 'editor.contrib.autoIndentOnPaste';

    final editor:ICodeEditor;
    final _languageConfigurationService:ILanguageConfigurationService;

    final callOnDispose = new DisposableStore();
    final callOnModel = new DisposableStore();

    public function new(editor:ICodeEditor, ?languageConfigurationService:ILanguageConfigurationService) {
        this.editor = editor;
        this._languageConfigurationService = languageConfigurationService != null ? languageConfigurationService : editor.context.languageConfigurationService;

        this.callOnDispose.add(editor.onDidChangeConfiguration((_) -> this.update()));
        this.callOnDispose.add(editor.onDidChangeModel((_) -> this.update()));
        this.callOnDispose.add(editor.onDidChangeModelLanguage((_) -> this.update()));
    }

    function update():Void {

        // clean up
        this.callOnModel.clear();

        // we are disabled
        if ((this.editor.getOption(EditorOption.autoIndent) : Int) < (EditorAutoIndentStrategy.Full : Int) || JsValues.truthy(this.editor.getOption(EditorOption.formatOnPaste))) {
            return;
        }

        // no model
        if (!this.editor.hasModel()) {
            return;
        }

        this.callOnModel.add(this.editor.onDidPaste((e) -> {
            this.trigger(e.range);
        }));
    }

    /**
     * `/\S/.test(text)` (JavaScript's `\s`).
     */
    static function hasNonWhitespace(text:String):Bool {
        return !Strings.isFalsyOrWhitespace(text);
    }

    public function trigger(range:Range):Void {
        final selections = this.editor.getSelections();
        if (selections == null || selections.length > 1) {
            return;
        }

        final model = this.editor.getModel();
        if (model == null) {
            return;
        }
        final containsOnlyWhitespace = this.rangeContainsOnlyWhitespaceCharacters(model, range);
        if (containsOnlyWhitespace) {
            return;
        }
        if (isStartOrEndInString(model, range)) {
            return;
        }
        if (!model.tokenization.isCheapToTokenize(range.getStartPosition().lineNumber)) {
            return;
        }
        final autoIndent = this.editor.getOption(EditorOption.autoIndent);
        final options = model.getOptions();
        final tabSize = options.tabSize;
        final indentSize = options.indentSize;
        final insertSpaces = options.insertSpaces;
        final textEdits:Array<AutoIndentTextEdit> = [];

        final indentConverter:IIndentConverter = {
            shiftIndent: (indentation:String) -> {
                return ShiftCommand.shiftIndent(indentation, indentation.length + 1, tabSize, indentSize, insertSpaces);
            },
            unshiftIndent: (indentation:String) -> {
                return ShiftCommand.unshiftIndent(indentation, indentation.length + 1, tabSize, indentSize, insertSpaces);
            }
        };

        var startLineNumber = range.startLineNumber;

        while (startLineNumber <= range.endLineNumber) {
            if (this.shouldIgnoreLine(model, startLineNumber)) {
                startLineNumber++;
                continue;
            }
            break;
        }

        if (startLineNumber > range.endLineNumber) {
            return;
        }

        var firstLineText = model.getLineContent(startLineNumber);
        if (!hasNonWhitespace(firstLineText.substring(0, range.startColumn - 1))) {
            final indentOfFirstLine = AutoIndent.getGoodIndentForLine(autoIndent, new TextModelVirtualModel(model), model.getLanguageId(), startLineNumber, indentConverter, this._languageConfigurationService);

            if (indentOfFirstLine != null) {
                final oldIndentation = Strings.getLeadingWhitespace(firstLineText);
                final newSpaceCnt = IndentUtils.getSpaceCnt(indentOfFirstLine, tabSize);
                final oldSpaceCnt = IndentUtils.getSpaceCnt(oldIndentation, tabSize);

                if (newSpaceCnt != oldSpaceCnt) {
                    final newIndent = IndentUtils.generateIndent(newSpaceCnt, tabSize, insertSpaces);
                    textEdits.push({
                        range: new Range(startLineNumber, 1, startLineNumber, oldIndentation.length + 1),
                        text: newIndent
                    });
                    firstLineText = newIndent + firstLineText.substring(oldIndentation.length);
                }
                else {
                    final indentMetadata = AutoIndent.getIndentMetadata(model, startLineNumber, this._languageConfigurationService);

                    if (indentMetadata == 0 || indentMetadata == IndentConsts.UNINDENT_MASK) {
                        // we paste content into a line where only contains whitespaces
                        // after pasting, the indentation of the first line is already correct
                        // the first line doesn't match any indentation rule
                        // then no-op.
                        return;
                    }
                }
            }
        }

        final firstLineNumber = startLineNumber;

        // ignore empty or ignored lines
        while (startLineNumber < range.endLineNumber) {
            if (!hasNonWhitespace(model.getLineContent(startLineNumber + 1))) {
                startLineNumber++;
                continue;
            }
            break;
        }

        if (startLineNumber != range.endLineNumber) {
            final virtualModel = new PasteVirtualModel(model, firstLineNumber, firstLineText);
            final indentOfSecondLine = AutoIndent.getGoodIndentForLine(autoIndent, virtualModel, model.getLanguageId(), startLineNumber + 1, indentConverter, this._languageConfigurationService);
            if (indentOfSecondLine != null) {
                final newSpaceCntOfSecondLine = IndentUtils.getSpaceCnt(indentOfSecondLine, tabSize);
                final oldSpaceCntOfSecondLine = IndentUtils.getSpaceCnt(Strings.getLeadingWhitespace(model.getLineContent(startLineNumber + 1)), tabSize);

                if (newSpaceCntOfSecondLine != oldSpaceCntOfSecondLine) {
                    final spaceCntOffset = newSpaceCntOfSecondLine - oldSpaceCntOfSecondLine;
                    for (i in startLineNumber + 1...range.endLineNumber + 1) {
                        final lineContent = model.getLineContent(i);
                        final originalIndent = Strings.getLeadingWhitespace(lineContent);
                        final originalSpacesCnt = IndentUtils.getSpaceCnt(originalIndent, tabSize);
                        final newSpacesCnt = originalSpacesCnt + spaceCntOffset;
                        final newIndent = IndentUtils.generateIndent(newSpacesCnt, tabSize, insertSpaces);

                        if (newIndent != originalIndent) {
                            textEdits.push({
                                range: new Range(i, 1, i, originalIndent.length + 1),
                                text: newIndent
                            });
                        }
                    }
                }
            }
        }

        if (textEdits.length > 0) {
            this.editor.pushUndoStop();
            final cmd = new AutoIndentOnPasteCommand(textEdits, this.editor.getSelection());
            this.editor.executeCommand('autoIndentOnPaste', cmd);
            this.editor.pushUndoStop();
        }
    }

    function rangeContainsOnlyWhitespaceCharacters(model:ITextModel, range:Range):Bool {
        final lineContainsOnlyWhitespace = (content:String) -> {
            return Strings.isFalsyOrWhitespace(content);
        };
        var containsOnlyWhitespace = true;
        if (range.startLineNumber == range.endLineNumber) {
            final lineContent = model.getLineContent(range.startLineNumber);
            final linePart = lineContent.substring(range.startColumn - 1, range.endColumn - 1);
            containsOnlyWhitespace = lineContainsOnlyWhitespace(linePart);
        }
        else {
            for (i in range.startLineNumber...range.endLineNumber + 1) {
                final lineContent = model.getLineContent(i);
                if (i == range.startLineNumber) {
                    final linePart = lineContent.substring(range.startColumn - 1);
                    containsOnlyWhitespace = lineContainsOnlyWhitespace(linePart);
                }
                else if (i == range.endLineNumber) {
                    final linePart = lineContent.substring(0, range.endColumn - 1);
                    containsOnlyWhitespace = lineContainsOnlyWhitespace(linePart);
                }
                else {
                    containsOnlyWhitespace = model.getLineFirstNonWhitespaceColumn(i) == 0;
                }
                if (!containsOnlyWhitespace) {
                    break;
                }
            }
        }
        return containsOnlyWhitespace;
    }

    function shouldIgnoreLine(model:ITextModel, lineNumber:Int):Bool {
        model.tokenization.forceTokenization(lineNumber);
        final nonWhitespaceColumn = model.getLineFirstNonWhitespaceColumn(lineNumber);
        if (nonWhitespaceColumn == 0) {
            return true;
        }
        final tokens = model.tokenization.getLineTokens(lineNumber);
        if (tokens.getCount() > 0) {
            final firstNonWhitespaceTokenIndex = tokens.findTokenIndexAtOffset(nonWhitespaceColumn);
            if (firstNonWhitespaceTokenIndex >= 0 && tokens.getStandardTokenType(firstNonWhitespaceTokenIndex) == StandardTokenType.Comment) {
                return true;
            }
        }

        return false;
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        this.callOnDispose.dispose();
        this.callOnModel.dispose();
    }

    static function isStartOrEndInString(model:ITextModel, range:Range):Bool {
        final isPositionInString = (position:Position) -> {
            final tokenType = LineTokens.getStandardTokenTypeAtPosition(model, position);
            return tokenType == StandardTokenType.String;
        };
        return isPositionInString(range.getStartPosition()) || isPositionInString(range.getEndPosition());
    }

}

/**
 * Module functions of indentation.ts (browser).
 */
class IndentationCommands {

    public static function getIndentationEditOperations(model:ITextModel, builder:IEditOperationBuilder, tabSize:Int, tabsToSpaces:Bool):Void {
        if (model.getLineCount() == 1 && model.getLineMaxColumn(1) == 1) {
            // Model is empty
            return;
        }

        final spacesBuf = new StringBuf();
        for (i in 0...tabSize) {
            spacesBuf.addChar(' '.code);
        }
        final spaces = spacesBuf.toString();

        final lineCount = model.getLineCount();
        for (lineNumber in 1...lineCount + 1) {
            var lastIndentationColumn = model.getLineFirstNonWhitespaceColumn(lineNumber);
            if (lastIndentationColumn == 0) {
                lastIndentationColumn = model.getLineMaxColumn(lineNumber);
            }

            if (lastIndentationColumn == 1) {
                continue;
            }

            final originalIndentationRange = new Range(lineNumber, 1, lineNumber, lastIndentationColumn);
            final originalIndentation = model.getValueInRange(originalIndentationRange);
            // `replace(/\t/ig, spaces)` and `replace(new RegExp(spaces, 'gi'), '\t')`
            final newIndentation = (
                tabsToSpaces
                    ? StringTools.replace(originalIndentation, '\t', spaces)
                    : (tabSize > 0 ? StringTools.replace(originalIndentation, spaces, '\t') : originalIndentation)
            );

            builder.addEditOperation(originalIndentationRange, newIndentation);
        }
    }

}

class IndentationToSpacesCommand implements ICommand {

    var selectionId:Null<String> = null;
    final selection:Selection;
    final tabSize:Int;

    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, tabSize:Int) {
        this.selection = selection;
        this.tabSize = tabSize;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        this.selectionId = builder.trackSelection(this.selection);
        IndentationCommands.getIndentationEditOperations(model, builder, this.tabSize, true);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this.selectionId);
    }

}

class IndentationToTabsCommand implements ICommand {

    var selectionId:Null<String> = null;
    final selection:Selection;
    final tabSize:Int;

    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, tabSize:Int) {
        this.selection = selection;
        this.tabSize = tabSize;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        this.selectionId = builder.trackSelection(this.selection);
        IndentationCommands.getIndentationEditOperations(model, builder, this.tabSize, false);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this.selectionId);
    }

}

class IndentationRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(AutoIndentOnPaste.ID, editor -> new AutoIndentOnPaste(editor), EditorContributionInstantiation.BeforeFirstInteraction);
        r.registerEditorAction(new IndentationToSpacesAction(r));
        r.registerEditorAction(new IndentationToTabsAction(r));
        r.registerEditorAction(new IndentUsingTabs(r));
        r.registerEditorAction(new IndentUsingSpaces(r));
        r.registerEditorAction(new ChangeTabDisplaySize(r));
        r.registerEditorAction(new DetectIndentation(r));
        r.registerEditorAction(new ReindentLinesAction(r));
        r.registerEditorAction(new ReindentSelectedLinesAction(r));
    }

}
