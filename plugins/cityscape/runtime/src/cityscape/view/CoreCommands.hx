// Ported from vscode src/vs/editor/browser/coreCommands.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import cityscape.Cityscape;
import cityscape.base.common.JsValues;
import cityscape.common.CursorCommon;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Model.ITextModel;
import cityscape.common.ViewEvents.VerticalRevealType;
import cityscape.common.ViewModel.IViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.CursorColumnSelection;
import cityscape.common.cursor.CursorDeleteOperations;
import cityscape.common.cursor.CursorMoveCommands;
import cityscape.common.cursor.CursorTypeEditOperations.EnterOperation;
import cityscape.common.cursor.CursorTypeOperations;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.common.EditorContextKeys;
import cityscape.common.EditorCommon.Handler;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * The core commands of the editor: cursor movements, selections, scrolling
 * and the basic edits (coreCommands.ts), with their keybindings.
 *
 * The command objects are immutable and shared by every context
 * (`CoreNavigationCommands.CursorLeft.runCoreEditorCommand(viewModel, args)`);
 * `CoreCommandsRegistration.register(r)` registers them in a context
 * (Monaco's module level `registerEditorCommand` calls). The DOM fallbacks of
 * `EditorOrNativeTextInputCommand` (Undo, Redo, SelectAll in a native input)
 * do not exist without the DOM.
 */

/**
 * The arguments of the core commands (Monaco's `Partial<...Options>`
 * interfaces of coreCommands.ts, merged: every field is optional).
 */
typedef CoreCommandArgs = {
    /**
     * `'mouse'`, `'keyboard'` or another source.
     */
    @:optional var source:String;
    // MoveCommandOptions
    @:optional var position:IPosition;
    @:optional var viewPosition:IPosition;
    @:optional var revealType:NavigationCommandRevealType;
    // ColumnSelectCommandOptions
    @:optional var mouseColumn:Int;
    @:optional var doColumnSelect:Bool;
    // CursorMoveCommandOptions
    @:optional var pageSize:Int;
    // CreateCursorCommandOptions
    @:optional var wholeLine:Bool;
    // EndCommandOptions
    @:optional var sticky:Bool;
    // CursorMove.RawArguments and EditorScroll_.RawArguments
    @:optional var to:String;
    @:optional var by:String;
    @:optional var value:Int;
    @:optional var select:Bool;
    @:optional var revealCursor:Bool;
    // RevealLine_.RawArguments: a number or a string
    @:optional var lineNumber:Any;
    @:optional var at:String;
    // SetSelectionCommandOptions
    @:optional var selection:ISelection;
}

enum abstract NavigationCommandRevealType(Int) from Int to Int {
    /**
     * Do regular revealing.
     */
    var Regular = 0;
    /**
     * Do only minimal revealing.
     */
    var Minimal = 1;
    /**
     * Do not reveal the position.
     */
    var None = 2;
}

abstract class CoreEditorCommand extends cityscape.view.EditorExtensions.EditorCommand {

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final viewModel = editor._getViewModel();
        if (viewModel == null) {
            // the editor has no view => has no cursors
            return;
        }
        this.runCoreEditorCommand(viewModel, args != null ? args : {});
    }

    abstract public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void;

}

/**
 * Monaco's `EditorScroll_` namespace.
 */
class EditorScroll_ {

    public static function isEditorScrollArgs(arg:Any):Bool {
        if (!JsValues.isObject(arg)) {
            return false;
        }

        if (!JsValues.isString(JsValues.field(arg, 'to'))) {
            return false;
        }

        final by = JsValues.field(arg, 'by');
        if (!JsValues.isUndefined(by) && !JsValues.isString(by)) {
            return false;
        }

        final value = JsValues.field(arg, 'value');
        if (!JsValues.isUndefined(value) && !JsValues.isNumber(value)) {
            return false;
        }

        final revealCursor = JsValues.field(arg, 'revealCursor');
        if (!JsValues.isUndefined(revealCursor) && !JsValues.isBoolean(revealCursor)) {
            return false;
        }

        return true;
    }

    /**
     * Directions in the view for editor scroll command.
     */
    public static final RawDirection = {
        Up: 'up',
        Right: 'right',
        Down: 'down',
        Left: 'left'
    };

    /**
     * Units for editor scroll 'by' argument
     */
    public static final RawUnit = {
        Line: 'line',
        WrappedLine: 'wrappedLine',
        Page: 'page',
        HalfPage: 'halfPage',
        Editor: 'editor',
        Column: 'column'
    };

    public static function parse(args:CoreCommandArgs):Null<EditorScrollParsedArguments> {
        var direction:EditorScrollDirection;
        switch (args.to) {
            case 'up':
                direction = EditorScrollDirection.Up;
            case 'right':
                direction = EditorScrollDirection.Right;
            case 'down':
                direction = EditorScrollDirection.Down;
            case 'left':
                direction = EditorScrollDirection.Left;
            default:
                // Illegal arguments
                return null;
        }

        var unit:EditorScrollUnit;
        switch (args.by) {
            case 'line':
                unit = EditorScrollUnit.Line;
            case 'wrappedLine':
                unit = EditorScrollUnit.WrappedLine;
            case 'page':
                unit = EditorScrollUnit.Page;
            case 'halfPage':
                unit = EditorScrollUnit.HalfPage;
            case 'editor':
                unit = EditorScrollUnit.Editor;
            case 'column':
                unit = EditorScrollUnit.Column;
            default:
                unit = EditorScrollUnit.WrappedLine;
        }

        final value = (args.value == null || args.value == 0 ? 1 : args.value);
        final revealCursor = (args.revealCursor == true);

        return {
            direction: direction,
            unit: unit,
            value: value,
            revealCursor: revealCursor,
            select: (args.select == true)
        };
    }

}

typedef EditorScrollParsedArguments = {
    var direction:EditorScrollDirection;
    var unit:EditorScrollUnit;
    var value:Int;
    var revealCursor:Bool;
    var select:Bool;
}

enum abstract EditorScrollDirection(Int) from Int to Int {
    var Up = 1;
    var Right = 2;
    var Down = 3;
    var Left = 4;
}

enum abstract EditorScrollUnit(Int) from Int to Int {
    var Line = 1;
    var WrappedLine = 2;
    var Page = 3;
    var HalfPage = 4;
    var Editor = 5;
    var Column = 6;
}

/**
 * Monaco's `RevealLine_` namespace.
 */
class RevealLine_ {

    public static function isRevealLineArgs(arg:Any):Bool {
        if (!JsValues.isObject(arg)) {
            return false;
        }

        final lineNumber = JsValues.field(arg, 'lineNumber');
        if (!JsValues.isNumber(lineNumber) && !JsValues.isString(lineNumber)) {
            return false;
        }

        final at = JsValues.field(arg, 'at');
        if (!JsValues.isUndefined(at) && !JsValues.isString(at)) {
            return false;
        }

        return true;
    }

    /**
     * Values for reveal line 'at' argument
     */
    public static final RawAtArgument = {
        Top: 'top',
        Center: 'center',
        Bottom: 'bottom'
    };

}

// ---- CoreNavigationCommands

private class BaseMoveToCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.position == null) {
            return;
        }
        viewModel.model.pushStackElement();
        final cursorStateChanged = viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            [
                CursorMoveCommands.moveTo(viewModel, viewModel.getPrimaryCursorState(), this._inSelectionMode, args.position, args.viewPosition)
            ]
        );
        if (cursorStateChanged && args.revealType != NavigationCommandRevealType.None) {
            viewModel.revealAllCursors(args.source, true, true);
        }
    }

}

private abstract class ColumnSelectCommand extends CoreEditorCommand {

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        final result = this._getColumnSelectResult(viewModel, viewModel.getPrimaryCursorState(), viewModel.getCursorColumnSelectData(), args);
        if (result == null) {
            // invalid arguments
            return;
        }
        viewModel.setCursorStates(args.source, CursorChangeReason.Explicit, [for (viewState in result.viewStates) (CursorState.fromViewState(viewState) : PartialCursorState)]);
        viewModel.setCursorColumnSelectData({
            isReal: true,
            fromViewLineNumber: result.fromLineNumber,
            fromViewVisualColumn: result.fromVisualColumn,
            toViewLineNumber: result.toLineNumber,
            toViewVisualColumn: result.toVisualColumn
        });
        if (result.reversed) {
            viewModel.revealTopMostCursor(args.source);
        }
        else {
            viewModel.revealBottomMostCursor(args.source);
        }
    }

    abstract function _getColumnSelectResult(viewModel:IViewModel, primary:CursorState, prevColumnSelectData:IColumnSelectData, args:CoreCommandArgs):Null<IColumnSelectResult>;

}

private class ColumnSelectImpl extends ColumnSelectCommand {

    public function new() {
        super({id: 'columnSelect', precondition: null});
    }

    function _getColumnSelectResult(viewModel:IViewModel, primary:CursorState, prevColumnSelectData:IColumnSelectData, args:CoreCommandArgs):Null<IColumnSelectResult> {
        if (args.position == null || args.viewPosition == null || args.mouseColumn == null) {
            return null;
        }
        // validate `args`
        final validatedPosition = viewModel.model.validatePosition(args.position);
        final validatedViewPosition = viewModel.coordinatesConverter.validateViewPosition(new Position(args.viewPosition.lineNumber, args.viewPosition.column), validatedPosition);

        final fromViewLineNumber = args.doColumnSelect == true ? prevColumnSelectData.fromViewLineNumber : validatedViewPosition.lineNumber;
        final fromViewVisualColumn = args.doColumnSelect == true ? prevColumnSelectData.fromViewVisualColumn : args.mouseColumn - 1;
        return ColumnSelection.columnSelect(viewModel.cursorConfig, viewModel, fromViewLineNumber, fromViewVisualColumn, validatedViewPosition.lineNumber, args.mouseColumn - 1);
    }

}

private class CursorColumnSelectLeftImpl extends ColumnSelectCommand {

    public function new() {
        super({id: 'cursorColumnSelectLeft', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyMod.Alt | KeyCode.LeftArrow, linux: {primary: 0}}});
    }

    function _getColumnSelectResult(viewModel:IViewModel, primary:CursorState, prevColumnSelectData:IColumnSelectData, args:CoreCommandArgs):Null<IColumnSelectResult> {
        return ColumnSelection.columnSelectLeft(viewModel.cursorConfig, viewModel, prevColumnSelectData);
    }

}

private class CursorColumnSelectRightImpl extends ColumnSelectCommand {

    public function new() {
        super({id: 'cursorColumnSelectRight', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyMod.Alt | KeyCode.RightArrow, linux: {primary: 0}}});
    }

    function _getColumnSelectResult(viewModel:IViewModel, primary:CursorState, prevColumnSelectData:IColumnSelectData, args:CoreCommandArgs):Null<IColumnSelectResult> {
        return ColumnSelection.columnSelectRight(viewModel.cursorConfig, viewModel, prevColumnSelectData);
    }

}

private class ColumnSelectUpCommand extends ColumnSelectCommand {

    final _isPaged:Bool;

    public function new(opts:ICommandOptions, isPaged:Bool) {
        super(opts);
        this._isPaged = isPaged;
    }

    function _getColumnSelectResult(viewModel:IViewModel, primary:CursorState, prevColumnSelectData:IColumnSelectData, args:CoreCommandArgs):Null<IColumnSelectResult> {
        return ColumnSelection.columnSelectUp(viewModel.cursorConfig, viewModel, prevColumnSelectData, this._isPaged);
    }

}

private class ColumnSelectDownCommand extends ColumnSelectCommand {

    final _isPaged:Bool;

    public function new(opts:ICommandOptions, isPaged:Bool) {
        super(opts);
        this._isPaged = isPaged;
    }

    function _getColumnSelectResult(viewModel:IViewModel, primary:CursorState, prevColumnSelectData:IColumnSelectData, args:CoreCommandArgs):Null<IColumnSelectResult> {
        return ColumnSelection.columnSelectDown(viewModel.cursorConfig, viewModel, prevColumnSelectData, this._isPaged);
    }

}

class CursorMoveImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'cursorMove', precondition: null});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        final parsed = CursorMove.parse({to: args.to, select: args.select, by: args.by, value: args.value});
        if (parsed == null) {
            // illegal arguments
            return;
        }
        this._runCursorMove(viewModel, args.source, parsed);
    }

    function _runCursorMove(viewModel:IViewModel, source:Null<String>, args:CursorMoveParsedArguments):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            source,
            CursorChangeReason.Explicit,
            CursorMoveImpl._move(viewModel, viewModel.getCursorStates(), args)
        );
        viewModel.revealAllCursors(source, true);
    }

    static function _move(viewModel:IViewModel, cursors:Array<CursorState>, args:CursorMoveParsedArguments):Null<Array<PartialCursorState>> {
        final inSelectionMode = args.select;
        final value = args.value;

        switch (args.direction) {
            case CursorMoveDirection.Left | CursorMoveDirection.Right | CursorMoveDirection.Up | CursorMoveDirection.Down | CursorMoveDirection.PrevBlankLine | CursorMoveDirection.NextBlankLine | CursorMoveDirection.WrappedLineStart | CursorMoveDirection.WrappedLineFirstNonWhitespaceCharacter | CursorMoveDirection.WrappedLineColumnCenter | CursorMoveDirection.WrappedLineEnd | CursorMoveDirection.WrappedLineLastNonWhitespaceCharacter:
                return CursorMoveCommands.simpleMove(viewModel, cursors, args.direction, inSelectionMode, value, args.unit);

            case CursorMoveDirection.ViewPortTop | CursorMoveDirection.ViewPortBottom | CursorMoveDirection.ViewPortCenter | CursorMoveDirection.ViewPortIfOutside:
                return CursorMoveCommands.viewportMove(viewModel, cursors, args.direction, inSelectionMode, value);
            default:
                return null;
        }
    }

}

private class CursorMoveBasedCommand extends CoreEditorCommand {

    /**
     * `value` -1 is a marker for the page size.
     */
    static inline final PAGE_SIZE_MARKER = -1;

    final _staticArgs:CursorMoveParsedArguments;

    public function new(opts:ICommandOptions, args:CursorMoveParsedArguments) {
        super(opts);
        this._staticArgs = args;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, dynamicArgs:CoreCommandArgs):Void {
        var args = this._staticArgs;
        if (this._staticArgs.value == PAGE_SIZE_MARKER) {
            // -1 is a marker for page size
            args = {
                direction: this._staticArgs.direction,
                unit: this._staticArgs.unit,
                select: this._staticArgs.select,
                value: (dynamicArgs.pageSize != null && dynamicArgs.pageSize != 0) ? dynamicArgs.pageSize : viewModel.cursorConfig.pageSize
            };
        }

        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            dynamicArgs.source,
            CursorChangeReason.Explicit,
            CursorMoveCommands.simpleMove(viewModel, viewModel.getCursorStates(), args.direction, args.select, args.value, args.unit)
        );
        viewModel.revealAllCursors(dynamicArgs.source, true);
    }

}

private class CreateCursorImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'createCursor', precondition: null});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.position == null) {
            return;
        }

        var newState:PartialCursorState;
        if (args.wholeLine == true) {
            newState = CursorMoveCommands.line(viewModel, viewModel.getPrimaryCursorState(), false, args.position, args.viewPosition);
        }
        else {
            newState = CursorMoveCommands.moveTo(viewModel, viewModel.getPrimaryCursorState(), false, args.position, args.viewPosition);
        }

        final states:Array<PartialCursorState> = cast viewModel.getCursorStates();

        // Check if we should remove a cursor (sort of like a toggle)
        if (states.length > 1) {
            final newModelPosition = (newState.modelState != null ? newState.modelState.position : null);
            final newViewPosition = (newState.viewState != null ? newState.viewState.position : null);

            for (i in 0...states.length) {
                final state = states[i];

                if (newModelPosition != null && !state.modelState.selection.containsPosition(newModelPosition)) {
                    continue;
                }

                if (newViewPosition != null && !state.viewState.selection.containsPosition(newViewPosition)) {
                    continue;
                }

                // => Remove the cursor
                states.splice(i, 1);

                viewModel.model.pushStackElement();
                viewModel.setCursorStates(
                    args.source,
                    CursorChangeReason.Explicit,
                    states
                );
                return;
            }
        }

        // => Add the new cursor
        states.push(newState);

        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            states
        );
    }

}

private class LastCursorMoveToSelectImpl extends CoreEditorCommand {

    public function new() {
        super({id: '_lastCursorMoveToSelect', precondition: null});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.position == null) {
            return;
        }
        final lastAddedCursorIndex = viewModel.getLastAddedCursorIndex();

        final states = viewModel.getCursorStates();
        final newStates:Array<PartialCursorState> = cast states.slice(0);
        newStates[lastAddedCursorIndex] = CursorMoveCommands.moveTo(viewModel, states[lastAddedCursorIndex], true, args.position, args.viewPosition);

        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            newStates
        );
    }

}

private class HomeCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            CursorMoveCommands.moveToBeginningOfLine(viewModel, viewModel.getCursorStates(), this._inSelectionMode)
        );
        viewModel.revealAllCursors(args.source, true);
    }

}

private class LineStartCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            this._exec(viewModel.getCursorStates())
        );
        viewModel.revealAllCursors(args.source, true);
    }

    function _exec(cursors:Array<CursorState>):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final lineNumber = cursor.modelState.position.lineNumber;
            result[i] = CursorState.fromModelState(cursor.modelState.move(this._inSelectionMode, lineNumber, 1, 0));
        }
        return result;
    }

}

private class EndCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            CursorMoveCommands.moveToEndOfLine(viewModel, viewModel.getCursorStates(), this._inSelectionMode, args.sticky == true)
        );
        viewModel.revealAllCursors(args.source, true);
    }

}

private class LineEndCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            this._exec(viewModel, viewModel.getCursorStates())
        );
        viewModel.revealAllCursors(args.source, true);
    }

    function _exec(viewModel:IViewModel, cursors:Array<CursorState>):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final lineNumber = cursor.modelState.position.lineNumber;
            final maxColumn = viewModel.model.getLineMaxColumn(lineNumber);
            result[i] = CursorState.fromModelState(cursor.modelState.move(this._inSelectionMode, lineNumber, maxColumn, 0));
        }
        return result;
    }

}

private class TopCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            CursorMoveCommands.moveToBeginningOfBuffer(viewModel, viewModel.getCursorStates(), this._inSelectionMode)
        );
        viewModel.revealAllCursors(args.source, true);
    }

}

private class BottomCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            CursorMoveCommands.moveToEndOfBuffer(viewModel, viewModel.getCursorStates(), this._inSelectionMode)
        );
        viewModel.revealAllCursors(args.source, true);
    }

}

class EditorScrollImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'editorScroll', precondition: null});
    }

    function determineScrollMethod(args:EditorScrollParsedArguments):Null<(viewModel:IViewModel, source:Null<String>, args:EditorScrollParsedArguments) -> Void> {
        final horizontalUnits = [EditorScrollUnit.Column];
        final verticalUnits = [
            EditorScrollUnit.Line,
            EditorScrollUnit.WrappedLine,
            EditorScrollUnit.Page,
            EditorScrollUnit.HalfPage,
            EditorScrollUnit.Editor,
            EditorScrollUnit.Column
        ];
        final horizontalDirections = [EditorScrollDirection.Left, EditorScrollDirection.Right];
        final verticalDirections = [EditorScrollDirection.Up, EditorScrollDirection.Down];

        if (horizontalUnits.indexOf(args.unit) != -1 && horizontalDirections.indexOf(args.direction) != -1) {
            return this._runHorizontalEditorScroll;
        }
        if (verticalUnits.indexOf(args.unit) != -1 && verticalDirections.indexOf(args.direction) != -1) {
            return this._runVerticalEditorScroll;
        }
        return null;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        final parsed = EditorScroll_.parse(args);
        if (parsed == null) {
            // illegal arguments
            return;
        }
        final runEditorScroll = this.determineScrollMethod(parsed);
        if (runEditorScroll == null) {
            // Incompatible unit and direction
            return;
        }
        runEditorScroll(viewModel, args.source, parsed);
    }

    function _runVerticalEditorScroll(viewModel:IViewModel, source:Null<String>, args:EditorScrollParsedArguments):Void {

        final desiredScrollTop = this._computeDesiredScrollTop(viewModel, args);

        if (args.revealCursor) {
            // must ensure cursor is in new visible range
            final desiredVisibleViewRange = viewModel.getCompletelyVisibleViewRangeAtScrollTop(desiredScrollTop);
            viewModel.setCursorStates(
                source,
                CursorChangeReason.Explicit,
                [
                    CursorMoveCommands.findPositionInViewportIfOutside(viewModel, viewModel.getPrimaryCursorState(), desiredVisibleViewRange, args.select)
                ]
            );
        }

        viewModel.viewLayout.setScrollPosition({scrollTop: desiredScrollTop}, ScrollType.Smooth);
    }

    function _computeDesiredScrollTop(viewModel:IViewModel, args:EditorScrollParsedArguments):Float {

        if (args.unit == EditorScrollUnit.Line) {
            // scrolling by model lines
            final futureViewport = viewModel.viewLayout.getFutureViewport();
            final visibleViewRange = viewModel.getCompletelyVisibleViewRangeAtScrollTop(futureViewport.top);
            final visibleModelRange = viewModel.coordinatesConverter.convertViewRangeToModelRange(visibleViewRange);

            var desiredTopModelLineNumber:Int;
            if (args.direction == EditorScrollDirection.Up) {
                // must go x model lines up
                desiredTopModelLineNumber = Std.int(Math.max(1, visibleModelRange.startLineNumber - args.value));
            }
            else {
                // must go x model lines down
                desiredTopModelLineNumber = Std.int(Math.min(viewModel.model.getLineCount(), visibleModelRange.startLineNumber + args.value));
            }

            final viewPosition = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(desiredTopModelLineNumber, 1));
            return viewModel.viewLayout.getVerticalOffsetForLineNumber(viewPosition.lineNumber);
        }

        if (args.unit == EditorScrollUnit.Editor) {
            var desiredTopModelLineNumber = 0;
            if (args.direction == EditorScrollDirection.Down) {
                desiredTopModelLineNumber = viewModel.model.getLineCount() - viewModel.cursorConfig.pageSize;
            }
            return viewModel.viewLayout.getVerticalOffsetForLineNumber(desiredTopModelLineNumber);
        }

        var noOfLines:Int;
        if (args.unit == EditorScrollUnit.Page) {
            noOfLines = viewModel.cursorConfig.pageSize * args.value;
        }
        else if (args.unit == EditorScrollUnit.HalfPage) {
            noOfLines = Math.round(viewModel.cursorConfig.pageSize / 2) * args.value;
        }
        else {
            noOfLines = args.value;
        }
        final deltaLines = (args.direction == EditorScrollDirection.Up ? -1 : 1) * noOfLines;
        return viewModel.viewLayout.getCurrentScrollTop() + deltaLines * viewModel.cursorConfig.lineHeight;
    }

    function _runHorizontalEditorScroll(viewModel:IViewModel, source:Null<String>, args:EditorScrollParsedArguments):Void {
        final desiredScrollLeft = this._computeDesiredScrollLeft(viewModel, args);
        viewModel.viewLayout.setScrollPosition({scrollLeft: desiredScrollLeft}, ScrollType.Smooth);
    }

    function _computeDesiredScrollLeft(viewModel:IViewModel, args:EditorScrollParsedArguments):Float {
        final deltaColumns = (args.direction == EditorScrollDirection.Left ? -1 : 1) * args.value;
        return viewModel.viewLayout.getCurrentScrollLeft() + deltaColumns * viewModel.cursorConfig.typicalHalfwidthCharacterWidth;
    }

}

/**
 * The scroll commands that run `EditorScroll` with fixed arguments.
 */
private class EditorScrollShortcut extends CoreEditorCommand {

    final to:String;
    final by:String;
    final value:Int;

    public function new(opts:ICommandOptions, to:String, by:String, value:Int) {
        super(opts);
        this.to = to;
        this.by = by;
        this.value = value;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        CoreNavigationCommands.EditorScroll.runCoreEditorCommand(viewModel, {
            to: this.to,
            by: this.by,
            value: this.value,
            revealCursor: false,
            select: false,
            source: args.source
        });
    }

}

private class WordCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.position == null) {
            return;
        }
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            [
                CursorMoveCommands.word(viewModel, viewModel.getPrimaryCursorState(), this._inSelectionMode, args.position)
            ]
        );
        if (args.revealType != NavigationCommandRevealType.None) {
            viewModel.revealAllCursors(args.source, true, true);
        }
    }

}

private class LastCursorWordSelectImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'lastCursorWordSelect', precondition: null});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.position == null) {
            return;
        }

        final lastAddedCursorIndex = viewModel.getLastAddedCursorIndex();

        final states = viewModel.getCursorStates();
        final newStates:Array<PartialCursorState> = cast states.slice(0);
        final lastAddedState = states[lastAddedCursorIndex];
        newStates[lastAddedCursorIndex] = CursorMoveCommands.word(viewModel, lastAddedState, lastAddedState.modelState.hasSelection(), args.position);

        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            newStates
        );
    }

}

private class LineCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.position == null) {
            return;
        }
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            [
                CursorMoveCommands.line(viewModel, viewModel.getPrimaryCursorState(), this._inSelectionMode, args.position, args.viewPosition)
            ]
        );
        if (args.revealType != NavigationCommandRevealType.None) {
            viewModel.revealAllCursors(args.source, false, true);
        }
    }

}

private class LastCursorLineCommand extends CoreEditorCommand {

    final _inSelectionMode:Bool;

    public function new(opts:ICommandOptions, inSelectionMode:Bool) {
        super(opts);
        this._inSelectionMode = inSelectionMode;
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.position == null) {
            return;
        }

        final lastAddedCursorIndex = viewModel.getLastAddedCursorIndex();

        final states = viewModel.getCursorStates();
        final newStates:Array<PartialCursorState> = cast states.slice(0);
        newStates[lastAddedCursorIndex] = CursorMoveCommands.line(viewModel, states[lastAddedCursorIndex], this._inSelectionMode, args.position, args.viewPosition);

        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            newStates
        );
    }

}

private class CancelSelectionImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'cancelSelection', precondition: EditorContextKeys.hasNonEmptySelection, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.Escape, secondary: [KeyMod.Shift | KeyCode.Escape]}});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            [
                CursorMoveCommands.cancelSelection(viewModel, viewModel.getPrimaryCursorState())
            ]
        );
        viewModel.revealAllCursors(args.source, true);
    }

}

private class RemoveSecondaryCursorsImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'removeSecondaryCursors', precondition: EditorContextKeys.hasMultipleSelections, kbOpts: {weight: KeybindingWeight.EditorCore + 1, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.Escape, secondary: [KeyMod.Shift | KeyCode.Escape]}});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            [
                viewModel.getPrimaryCursorState()
            ]
        );
        viewModel.revealAllCursors(args.source, true);
    }

}

private class RevealLineImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'revealLine', precondition: null});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        final revealLineArg = args;
        final lineNumberArg:Any = JsValues.truthy(revealLineArg.lineNumber) ? revealLineArg.lineNumber : 0;
        var lineNumber = Std.int(JsValues.isNumber(lineNumberArg) ? ((lineNumberArg : Float) + 1) : (JsValues.parseInt(lineNumberArg) + 1));
        if (lineNumber < 1) {
            lineNumber = 1;
        }
        final lineCount = viewModel.model.getLineCount();
        if (lineNumber > lineCount) {
            lineNumber = lineCount;
        }

        final range = new Range(
            lineNumber, 1,
            lineNumber, viewModel.model.getLineMaxColumn(lineNumber)
        );

        var revealAt = VerticalRevealType.Simple;
        if (revealLineArg.at != null && revealLineArg.at.length > 0) {
            switch (revealLineArg.at) {
                case 'top':
                    revealAt = VerticalRevealType.Top;
                case 'center':
                    revealAt = VerticalRevealType.Center;
                case 'bottom':
                    revealAt = VerticalRevealType.Bottom;
                default:
            }
        }

        final viewRange = viewModel.coordinatesConverter.convertModelRangeToViewRange(range);

        viewModel.revealRange(args.source, false, viewRange, revealAt, ScrollType.Smooth);
    }

}

/**
 * A command that runs on the editor that has the focus, or on the last
 * active one (Monaco's `EditorOrNativeTextInputCommand`, whose second case,
 * a focused native input, does not exist without the DOM). `attach` adds
 * its implementations to the multi command of a context (`undo`, `redo`,
 * `editor.action.selectAll`).
 */
abstract class EditorOrNativeTextInputCommand {

    public function new() {}

    public function attach(target:MultiCommand):Void {
        // 1. handle case when focus is in editor.
        target.addImplementation(10000, 'code-editor', (accessor:Null<Cityscape>, args:Any) -> {
            // Only if editor text focus (i.e. not if editor has widget focus).
            final focusedEditor = accessor != null ? accessor.codeEditorService.getFocusedCodeEditor() : null;
            if (focusedEditor != null && focusedEditor.hasTextFocus()) {
                return this._runEditorCommand(accessor, focusedEditor, args);
            }
            return false;
        });

        // 3. (default) handle case when focus is somewhere else.
        target.addImplementation(0, 'generic-dom', (accessor:Null<Cityscape>, args:Any) -> {
            // Redirecting to active editor
            final activeEditor = accessor != null ? accessor.codeEditorService.getActiveCodeEditor() : null;
            if (activeEditor != null) {
                activeEditor.focus();
                return this._runEditorCommand(accessor, activeEditor, args);
            }
            return false;
        });
    }

    public function _runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Bool {
        this.runEditorCommand(accessor, editor, args);
        return true;
    }

    abstract public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void;

}

/**
 * Monaco's `SelectAll`.
 */
class SelectAllImpl extends EditorOrNativeTextInputCommand {

    public final id:String = 'editor.action.selectAll';

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final viewModel = editor._getViewModel();
        if (viewModel == null) {
            // the editor has no view => has no cursors
            return;
        }
        this.runCoreEditorCommand(viewModel, args != null ? args : {});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            'keyboard',
            CursorChangeReason.Explicit,
            [
                CursorMoveCommands.selectAll(viewModel, viewModel.getPrimaryCursorState())
            ]
        );
    }

}

private class SetSelectionImpl extends CoreEditorCommand {

    public function new() {
        super({id: 'setSelection', precondition: null});
    }

    public function runCoreEditorCommand(viewModel:IViewModel, args:CoreCommandArgs):Void {
        if (args.selection == null) {
            return;
        }
        viewModel.model.pushStackElement();
        viewModel.setCursorStates(
            args.source,
            CursorChangeReason.Explicit,
            [
                CursorState.fromModelSelection(args.selection)
            ]
        );
    }

}

class CoreNavigationCommands {

    public static final MoveTo:CoreEditorCommand = new BaseMoveToCommand({id: '_moveTo', precondition: null}, false);
    public static final MoveToSelect:CoreEditorCommand = new BaseMoveToCommand({id: '_moveToSelect', precondition: null}, true);
    public static final ColumnSelect:CoreEditorCommand = new ColumnSelectImpl();
    public static final CursorColumnSelectLeft:CoreEditorCommand = new CursorColumnSelectLeftImpl();
    public static final CursorColumnSelectRight:CoreEditorCommand = new CursorColumnSelectRightImpl();
    public static final CursorColumnSelectUp:CoreEditorCommand = new ColumnSelectUpCommand({id: 'cursorColumnSelectUp', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyMod.Alt | KeyCode.UpArrow, linux: {primary: 0}}}, false);
    public static final CursorColumnSelectPageUp:CoreEditorCommand = new ColumnSelectUpCommand({id: 'cursorColumnSelectPageUp', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyMod.Alt | KeyCode.PageUp, linux: {primary: 0}}}, true);
    public static final CursorColumnSelectDown:CoreEditorCommand = new ColumnSelectDownCommand({id: 'cursorColumnSelectDown', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyMod.Alt | KeyCode.DownArrow, linux: {primary: 0}}}, false);
    public static final CursorColumnSelectPageDown:CoreEditorCommand = new ColumnSelectDownCommand({id: 'cursorColumnSelectPageDown', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyMod.Alt | KeyCode.PageDown, linux: {primary: 0}}}, true);
    public static final CursorMove:CursorMoveImpl = new CursorMoveImpl();

    public static final CursorLeft:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorLeft', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.LeftArrow, mac: {primary: KeyCode.LeftArrow, secondary: [KeyMod.WinCtrl | KeyCode.KeyB]}}}, {direction: CursorMoveDirection.Left, unit: CursorMoveUnit.None, select: false, value: 1});
    public static final CursorLeftSelect:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorLeftSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.LeftArrow}}, {direction: CursorMoveDirection.Left, unit: CursorMoveUnit.None, select: true, value: 1});
    public static final CursorRight:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorRight', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.RightArrow, mac: {primary: KeyCode.RightArrow, secondary: [KeyMod.WinCtrl | KeyCode.KeyF]}}}, {direction: CursorMoveDirection.Right, unit: CursorMoveUnit.None, select: false, value: 1});
    public static final CursorRightSelect:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorRightSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.RightArrow}}, {direction: CursorMoveDirection.Right, unit: CursorMoveUnit.None, select: true, value: 1});
    public static final CursorUp:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorUp', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.UpArrow, mac: {primary: KeyCode.UpArrow, secondary: [KeyMod.WinCtrl | KeyCode.KeyP]}}}, {direction: CursorMoveDirection.Up, unit: CursorMoveUnit.WrappedLine, select: false, value: 1});
    public static final CursorUpSelect:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorUpSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.UpArrow, secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.UpArrow], mac: {primary: KeyMod.Shift | KeyCode.UpArrow}, linux: {primary: KeyMod.Shift | KeyCode.UpArrow}}}, {direction: CursorMoveDirection.Up, unit: CursorMoveUnit.WrappedLine, select: true, value: 1});
    public static final CursorPageUp:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorPageUp', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.PageUp}}, {direction: CursorMoveDirection.Up, unit: CursorMoveUnit.WrappedLine, select: false, value: -1});
    public static final CursorPageUpSelect:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorPageUpSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.PageUp}}, {direction: CursorMoveDirection.Up, unit: CursorMoveUnit.WrappedLine, select: true, value: -1});
    public static final CursorDown:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorDown', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.DownArrow, mac: {primary: KeyCode.DownArrow, secondary: [KeyMod.WinCtrl | KeyCode.KeyN]}}}, {direction: CursorMoveDirection.Down, unit: CursorMoveUnit.WrappedLine, select: false, value: 1});
    public static final CursorDownSelect:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorDownSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.DownArrow, secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.DownArrow], mac: {primary: KeyMod.Shift | KeyCode.DownArrow}, linux: {primary: KeyMod.Shift | KeyCode.DownArrow}}}, {direction: CursorMoveDirection.Down, unit: CursorMoveUnit.WrappedLine, select: true, value: 1});
    public static final CursorPageDown:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorPageDown', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.PageDown}}, {direction: CursorMoveDirection.Down, unit: CursorMoveUnit.WrappedLine, select: false, value: -1});
    public static final CursorPageDownSelect:CoreEditorCommand = new CursorMoveBasedCommand({id: 'cursorPageDownSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.PageDown}}, {direction: CursorMoveDirection.Down, unit: CursorMoveUnit.WrappedLine, select: true, value: -1});

    public static final CreateCursor:CoreEditorCommand = new CreateCursorImpl();
    public static final LastCursorMoveToSelect:CoreEditorCommand = new LastCursorMoveToSelectImpl();

    public static final CursorHome:CoreEditorCommand = new HomeCommand({id: 'cursorHome', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.Home, mac: {primary: KeyCode.Home, secondary: [KeyMod.CtrlCmd | KeyCode.LeftArrow]}}}, false);
    public static final CursorHomeSelect:CoreEditorCommand = new HomeCommand({id: 'cursorHomeSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.Home, mac: {primary: KeyMod.Shift | KeyCode.Home, secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.LeftArrow]}}}, true);
    public static final CursorLineStart:CoreEditorCommand = new LineStartCommand({id: 'cursorLineStart', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: 0, mac: {primary: KeyMod.WinCtrl | KeyCode.KeyA}}}, false);
    public static final CursorLineStartSelect:CoreEditorCommand = new LineStartCommand({id: 'cursorLineStartSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: 0, mac: {primary: KeyMod.WinCtrl | KeyMod.Shift | KeyCode.KeyA}}}, true);
    public static final CursorEnd:CoreEditorCommand = new EndCommand({id: 'cursorEnd', precondition: null, kbOpts: {args: {sticky: false}, weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.End, mac: {primary: KeyCode.End, secondary: [KeyMod.CtrlCmd | KeyCode.RightArrow]}}}, false);
    public static final CursorEndSelect:CoreEditorCommand = new EndCommand({id: 'cursorEndSelect', precondition: null, kbOpts: {args: {sticky: false}, weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.Shift | KeyCode.End, mac: {primary: KeyMod.Shift | KeyCode.End, secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.RightArrow]}}}, true);
    public static final CursorLineEnd:CoreEditorCommand = new LineEndCommand({id: 'cursorLineEnd', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: 0, mac: {primary: KeyMod.WinCtrl | KeyCode.KeyE}}}, false);
    public static final CursorLineEndSelect:CoreEditorCommand = new LineEndCommand({id: 'cursorLineEndSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: 0, mac: {primary: KeyMod.WinCtrl | KeyMod.Shift | KeyCode.KeyE}}}, true);
    public static final CursorTop:CoreEditorCommand = new TopCommand({id: 'cursorTop', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.Home, mac: {primary: KeyMod.CtrlCmd | KeyCode.UpArrow}}}, false);
    public static final CursorTopSelect:CoreEditorCommand = new TopCommand({id: 'cursorTopSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Home, mac: {primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.UpArrow}}}, true);
    public static final CursorBottom:CoreEditorCommand = new BottomCommand({id: 'cursorBottom', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.End, mac: {primary: KeyMod.CtrlCmd | KeyCode.DownArrow}}}, false);
    public static final CursorBottomSelect:CoreEditorCommand = new BottomCommand({id: 'cursorBottomSelect', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.End, mac: {primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.DownArrow}}}, true);

    public static final EditorScroll:EditorScrollImpl = new EditorScrollImpl();
    public static final ScrollLineUp:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollLineUp', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.UpArrow, mac: {primary: KeyMod.WinCtrl | KeyCode.PageUp}}}, 'up', 'wrappedLine', 1);
    public static final ScrollPageUp:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollPageUp', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.PageUp, win: {primary: KeyMod.Alt | KeyCode.PageUp}, linux: {primary: KeyMod.Alt | KeyCode.PageUp}}}, 'up', 'page', 1);
    public static final ScrollEditorTop:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollEditorTop', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus}}, 'up', 'editor', 1);
    public static final ScrollLineDown:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollLineDown', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.DownArrow, mac: {primary: KeyMod.WinCtrl | KeyCode.PageDown}}}, 'down', 'wrappedLine', 1);
    public static final ScrollPageDown:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollPageDown', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyMod.CtrlCmd | KeyCode.PageDown, win: {primary: KeyMod.Alt | KeyCode.PageDown}, linux: {primary: KeyMod.Alt | KeyCode.PageDown}}}, 'down', 'page', 1);
    public static final ScrollEditorBottom:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollEditorBottom', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus}}, 'down', 'editor', 1);
    public static final ScrollLeft:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollLeft', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus}}, 'left', 'column', 2);
    public static final ScrollRight:CoreEditorCommand = new EditorScrollShortcut({id: 'scrollRight', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus}}, 'right', 'column', 2);

    public static final WordSelect:CoreEditorCommand = new WordCommand({id: '_wordSelect', precondition: null}, false);
    public static final WordSelectDrag:CoreEditorCommand = new WordCommand({id: '_wordSelectDrag', precondition: null}, true);
    public static final LastCursorWordSelect:CoreEditorCommand = new LastCursorWordSelectImpl();
    public static final LineSelect:CoreEditorCommand = new LineCommand({id: '_lineSelect', precondition: null}, false);
    public static final LineSelectDrag:CoreEditorCommand = new LineCommand({id: '_lineSelectDrag', precondition: null}, true);
    public static final LastCursorLineSelect:CoreEditorCommand = new LastCursorLineCommand({id: 'lastCursorLineSelect', precondition: null}, false);
    public static final LastCursorLineSelectDrag:CoreEditorCommand = new LastCursorLineCommand({id: 'lastCursorLineSelectDrag', precondition: null}, true);
    public static final CancelSelection:CoreEditorCommand = new CancelSelectionImpl();
    public static final RemoveSecondaryCursors:CoreEditorCommand = new RemoveSecondaryCursorsImpl();
    public static final RevealLine:CoreEditorCommand = new RevealLineImpl();
    public static final SelectAll:SelectAllImpl = new SelectAllImpl();
    public static final SetSelection:CoreEditorCommand = new SetSelectionImpl();

}

// ---- CoreEditingCommands

abstract class CoreEditingCommand extends cityscape.view.EditorExtensions.EditorCommand {

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final viewModel = editor._getViewModel();
        if (viewModel == null) {
            // the editor has no view => has no cursors
            return;
        }
        this.runCoreEditingCommand(editor, viewModel, args != null ? args : {});
    }

    abstract public function runCoreEditingCommand(editor:ICodeEditor, viewModel:IViewModel, args:CoreCommandArgs):Void;

}

private class LineBreakInsertImpl extends CoreEditingCommand {

    public function new() {
        super({id: 'lineBreakInsert', precondition: EditorContextKeys.writable, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: 0, mac: {primary: KeyMod.WinCtrl | KeyCode.KeyO}}});
    }

    public function runCoreEditingCommand(editor:ICodeEditor, viewModel:IViewModel, args:CoreCommandArgs):Void {
        editor.pushUndoStop();
        editor.executeCommands(this.id, cast EnterOperation.lineBreakInsert(viewModel.cursorConfig, viewModel.model, [for (s in viewModel.getCursorStates()) s.modelState.selection]));
    }

}

private class OutdentImpl extends CoreEditingCommand {

    public function new() {
        super({id: 'outdent', precondition: EditorContextKeys.writable, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: ContextKeyExpr.and(EditorContextKeys.editorTextFocus, EditorContextKeys.tabDoesNotMoveFocus), primary: KeyMod.Shift | KeyCode.Tab}});
    }

    public function runCoreEditingCommand(editor:ICodeEditor, viewModel:IViewModel, args:CoreCommandArgs):Void {
        editor.pushUndoStop();
        editor.executeCommands(this.id, cast TypeOperations.outdent(viewModel.cursorConfig, viewModel.model, [for (s in viewModel.getCursorStates()) s.modelState.selection]));
        editor.pushUndoStop();
    }

}

private class TabImpl extends CoreEditingCommand {

    public function new() {
        super({id: 'tab', precondition: EditorContextKeys.writable, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: ContextKeyExpr.and(EditorContextKeys.editorTextFocus, EditorContextKeys.tabDoesNotMoveFocus), primary: KeyCode.Tab}});
    }

    public function runCoreEditingCommand(editor:ICodeEditor, viewModel:IViewModel, args:CoreCommandArgs):Void {
        editor.pushUndoStop();
        editor.executeCommands(this.id, cast TypeOperations.tab(viewModel.cursorConfig, viewModel.model, [for (s in viewModel.getCursorStates()) s.modelState.selection]));
        editor.pushUndoStop();
    }

}

private class DeleteLeftImpl extends CoreEditingCommand {

    public function new() {
        super({id: 'deleteLeft', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.Backspace, secondary: [KeyMod.Shift | KeyCode.Backspace], mac: {primary: KeyCode.Backspace, secondary: [KeyMod.Shift | KeyCode.Backspace, KeyMod.WinCtrl | KeyCode.KeyH, KeyMod.WinCtrl | KeyCode.Backspace]}}});
    }

    public function runCoreEditingCommand(editor:ICodeEditor, viewModel:IViewModel, args:CoreCommandArgs):Void {
        final r = DeleteOperations.deleteLeft(viewModel.getPrevEditOperationType(), viewModel.cursorConfig, viewModel.model, [for (s in viewModel.getCursorStates()) s.modelState.selection], viewModel.getCursorAutoClosedCharacters());
        if (r.shouldPushStackElementBefore) {
            editor.pushUndoStop();
        }
        editor.executeCommands(this.id, r.commands);
        viewModel.setPrevEditOperationType(EditOperationType.DeletingLeft);
    }

}

private class DeleteRightImpl extends CoreEditingCommand {

    public function new() {
        super({id: 'deleteRight', precondition: null, kbOpts: {weight: KeybindingWeight.EditorCore, kbExpr: EditorContextKeys.textInputFocus, primary: KeyCode.Delete, mac: {primary: KeyCode.Delete, secondary: [KeyMod.WinCtrl | KeyCode.KeyD, KeyMod.WinCtrl | KeyCode.Delete]}}});
    }

    public function runCoreEditingCommand(editor:ICodeEditor, viewModel:IViewModel, args:CoreCommandArgs):Void {
        final r = DeleteOperations.deleteRight(viewModel.getPrevEditOperationType(), viewModel.cursorConfig, viewModel.model, [for (s in viewModel.getCursorStates()) s.modelState.selection]);
        if (r.shouldPushStackElementBefore) {
            editor.pushUndoStop();
        }
        editor.executeCommands(this.id, r.commands);
        viewModel.setPrevEditOperationType(EditOperationType.DeletingRight);
    }

}

/**
 * Monaco's `Undo` and `Redo` (`EditorOrNativeTextInputCommand`s).
 */
private class UndoRedoImpl extends EditorOrNativeTextInputCommand {

    public final id:String;
    final isRedo:Bool;

    public function new(id:String, isRedo:Bool) {
        super();
        this.id = id;
        this.isRedo = isRedo;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final model = editor.getTextModel();
        if (model == null || editor.getOption(EditorOption.readOnly) == true) {
            return;
        }
        if (isRedo) {
            model.redo();
        }
        else {
            model.undo();
        }
    }

}

class CoreEditingCommands {

    public static final LineBreakInsert:EditorCommand = new LineBreakInsertImpl();
    public static final Outdent:EditorCommand = new OutdentImpl();
    public static final Tab:EditorCommand = new TabImpl();
    public static final DeleteLeft:EditorCommand = new DeleteLeftImpl();
    public static final DeleteRight:EditorCommand = new DeleteRightImpl();
    public static final Undo:EditorOrNativeTextInputCommand = new UndoRedoImpl('undo', false);
    public static final Redo:EditorOrNativeTextInputCommand = new UndoRedoImpl('redo', true);

}

/**
 * A command that will invoke a command on the focused editor.
 */
class EditorHandlerCommand extends Command {

    final _handlerId:String;

    public function new(id:String, handlerId:String, ?metadata:cityscape.platform.commands.common.Commands.ICommandMetadata) {
        super({
            id: id,
            precondition: null,
            metadata: metadata
        });
        this._handlerId = handlerId;
    }

    public function runCommand(accessor:Null<Cityscape>, args:Any):Void {
        final editor = accessor != null ? accessor.codeEditorService.getFocusedCodeEditor() : null;
        if (editor == null) {
            return;
        }

        editor.trigger('keyboard', this._handlerId, args);
    }

}

/**
 * The module level registrations of coreCommands.ts, for one context.
 */
class CoreCommandsRegistration {

    static function registerColumnSelection(r:EditorExtensionsRegistry, id:String, keybinding:Int):Void {
        r.registerKeybindingRule({
            id: id,
            primary: keybinding,
            when: ContextKeyExpr.and(
                EditorContextKeys.textInputFocus,
                EditorContextKeys.columnSelection
            ),
            weight: KeybindingWeight.EditorCore + 1
        });
    }

    static function registerOverwritableCommand(r:EditorExtensionsRegistry, handlerId:String, ?metadata:cityscape.platform.commands.common.Commands.ICommandMetadata):Void {
        r.registerCommand(new EditorHandlerCommand('default:' + handlerId, handlerId));
        r.registerCommand(new EditorHandlerCommand(handlerId, handlerId, metadata));
    }

    public static function register(r:EditorExtensionsRegistry):Void {
        final nav = [
            CoreNavigationCommands.MoveTo,
            CoreNavigationCommands.MoveToSelect,
            CoreNavigationCommands.ColumnSelect,
            CoreNavigationCommands.CursorColumnSelectLeft,
            CoreNavigationCommands.CursorColumnSelectRight,
            CoreNavigationCommands.CursorColumnSelectUp,
            CoreNavigationCommands.CursorColumnSelectPageUp,
            CoreNavigationCommands.CursorColumnSelectDown,
            CoreNavigationCommands.CursorColumnSelectPageDown,
            CoreNavigationCommands.CursorMove,
            CoreNavigationCommands.CursorLeft,
            CoreNavigationCommands.CursorLeftSelect,
            CoreNavigationCommands.CursorRight,
            CoreNavigationCommands.CursorRightSelect,
            CoreNavigationCommands.CursorUp,
            CoreNavigationCommands.CursorUpSelect,
            CoreNavigationCommands.CursorPageUp,
            CoreNavigationCommands.CursorPageUpSelect,
            CoreNavigationCommands.CursorDown,
            CoreNavigationCommands.CursorDownSelect,
            CoreNavigationCommands.CursorPageDown,
            CoreNavigationCommands.CursorPageDownSelect,
            CoreNavigationCommands.CreateCursor,
            CoreNavigationCommands.LastCursorMoveToSelect,
            CoreNavigationCommands.CursorHome,
            CoreNavigationCommands.CursorHomeSelect,
            CoreNavigationCommands.CursorLineStart,
            CoreNavigationCommands.CursorLineStartSelect,
            CoreNavigationCommands.CursorEnd,
            CoreNavigationCommands.CursorEndSelect,
            CoreNavigationCommands.CursorLineEnd,
            CoreNavigationCommands.CursorLineEndSelect,
            CoreNavigationCommands.CursorTop,
            CoreNavigationCommands.CursorTopSelect,
            CoreNavigationCommands.CursorBottom,
            CoreNavigationCommands.CursorBottomSelect,
            CoreNavigationCommands.EditorScroll,
            CoreNavigationCommands.ScrollLineUp,
            CoreNavigationCommands.ScrollPageUp,
            CoreNavigationCommands.ScrollEditorTop,
            CoreNavigationCommands.ScrollLineDown,
            CoreNavigationCommands.ScrollPageDown,
            CoreNavigationCommands.ScrollEditorBottom,
            CoreNavigationCommands.ScrollLeft,
            CoreNavigationCommands.ScrollRight,
            CoreNavigationCommands.WordSelect,
            CoreNavigationCommands.WordSelectDrag,
            CoreNavigationCommands.LastCursorWordSelect,
            CoreNavigationCommands.LineSelect,
            CoreNavigationCommands.LineSelectDrag,
            CoreNavigationCommands.LastCursorLineSelect,
            CoreNavigationCommands.LastCursorLineSelectDrag,
            CoreNavigationCommands.CancelSelection,
            CoreNavigationCommands.RemoveSecondaryCursors,
            CoreNavigationCommands.RevealLine,
            CoreNavigationCommands.SetSelection,
        ];
        for (command in nav) {
            r.registerEditorCommand((command : cityscape.view.EditorExtensions.EditorCommand));
        }
        CoreNavigationCommands.SelectAll.attach(r.SelectAllCommand);

        registerColumnSelection(r, CoreNavigationCommands.CursorColumnSelectLeft.id, KeyMod.Shift | KeyCode.LeftArrow);
        registerColumnSelection(r, CoreNavigationCommands.CursorColumnSelectRight.id, KeyMod.Shift | KeyCode.RightArrow);
        registerColumnSelection(r, CoreNavigationCommands.CursorColumnSelectUp.id, KeyMod.Shift | KeyCode.UpArrow);
        registerColumnSelection(r, CoreNavigationCommands.CursorColumnSelectPageUp.id, KeyMod.Shift | KeyCode.PageUp);
        registerColumnSelection(r, CoreNavigationCommands.CursorColumnSelectDown.id, KeyMod.Shift | KeyCode.DownArrow);
        registerColumnSelection(r, CoreNavigationCommands.CursorColumnSelectPageDown.id, KeyMod.Shift | KeyCode.PageDown);

        r.registerEditorCommand(CoreEditingCommands.LineBreakInsert);
        r.registerEditorCommand(CoreEditingCommands.Outdent);
        r.registerEditorCommand(CoreEditingCommands.Tab);
        r.registerEditorCommand(CoreEditingCommands.DeleteLeft);
        r.registerEditorCommand(CoreEditingCommands.DeleteRight);
        CoreEditingCommands.Undo.attach(r.UndoCommand);
        CoreEditingCommands.Redo.attach(r.RedoCommand);

        registerOverwritableCommand(r, Handler.Type, {
            description: 'Type',
            args: [{
                name: 'args'
            }]
        });
        registerOverwritableCommand(r, Handler.ReplacePreviousChar);
        registerOverwritableCommand(r, Handler.CompositionType);
        registerOverwritableCommand(r, Handler.CompositionStart);
        registerOverwritableCommand(r, Handler.CompositionEnd);
        registerOverwritableCommand(r, Handler.Paste);
        registerOverwritableCommand(r, Handler.Cut);
    }

}
