// Ported from vscode src/vs/editor/common/editorCommon.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Uri;
import cityscape.common.Model;
import cityscape.common.TextModelEvents.IModelDecorationsChangedEvent;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Dimension.IDimension;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.platform.commands.common.Commands.ICommandMetadata;
import haxe.extern.EitherType;

/**
 * A builder and helper for edit operations for a command.
 */
interface IEditOperationBuilder {
    /**
     * Add a new edit operation (a replace operation).
     * @param range The range to replace (delete). May be empty to represent a simple insert.
     * @param text The text to replace with. May be null to represent a simple delete.
     */
    function addEditOperation(range:IRange, text:Null<String>, ?forceMoveMarkers:Bool):Void;

    /**
     * Add a new edit operation (a replace operation).
     * The inverse edits will be accessible in `ICursorStateComputerData.getInverseEditOperations()`
     * @param range The range to replace (delete). May be empty to represent a simple insert.
     * @param text The text to replace with. May be null to represent a simple delete.
     */
    function addTrackedEditOperation(range:IRange, text:Null<String>, ?forceMoveMarkers:Bool):Void;

    /**
     * Track `selection` when applying edit operations.
     * A best effort will be made to not grow/expand the selection.
     * An empty selection will clamp to a nearby character.
     * @param selection The selection to track.
     * @param trackPreviousOnEmpty If set, and the selection is empty, indicates whether the selection
     *           should clamp to the previous or the next character.
     * @return A unique identifier.
     */
    function trackSelection(selection:Selection, ?trackPreviousOnEmpty:Bool):String;
}

/**
 * A helper for computing cursor state after a command.
 */
interface ICursorStateComputerData {
    /**
     * Get the inverse edit operations of the added edit operations.
     */
    function getInverseEditOperations():Array<IValidEditOperation>;
    /**
     * Get a previously tracked selection.
     * @param id The unique identifier returned by `trackSelection`.
     * @return The selection.
     */
    function getTrackedSelection(id:String):Selection;
}

/**
 * A command that modifies text / cursor state on a model.
 */
interface ICommand {

    /**
     * Signal that this command is inserting automatic whitespace that should be trimmed if possible.
     * @internal
     */
    final insertsAutoWhitespace:Bool;

    /**
     * Get the edit operations needed to execute this command.
     * @param model The model the command will execute on.
     * @param builder A helper to collect the needed edit operations and to track selections.
     */
    function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void;

    /**
     * Compute the cursor state after the edit operations were applied.
     * @param model The model the command has executed on.
     * @param helper A helper to get inverse edit operations and to get previously tracked selections.
     * @return The cursor state after the command executed.
     */
    function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection;
}

/**
 * A model for the diff editor.
 */
typedef IDiffEditorModel = {
    /**
     * Original model.
     */
    var original:ITextModel;
    /**
     * Modified model.
     */
    var modified:ITextModel;
}

/**
 * An event describing that an editor has had its model reset (i.e. `editor.setModel()`).
 */
typedef IModelChangedEvent = {
    /**
     * The `uri` of the previous model or null.
     */
    final oldModelUrl:Null<Uri>;
    /**
     * The `uri` of the new model or null.
     */
    final newModelUrl:Null<Uri>;
}

typedef IScrollEvent = {
    final scrollTop:Float;
    final scrollLeft:Float;
    final scrollWidth:Float;
    final scrollHeight:Float;

    final scrollTopChanged:Bool;
    final scrollLeftChanged:Bool;
    final scrollWidthChanged:Bool;
    final scrollHeightChanged:Bool;
}

typedef IContentSizeChangedEvent = {
    final contentWidth:Float;
    final contentHeight:Float;

    final contentWidthChanged:Bool;
    final contentHeightChanged:Bool;
}

typedef INewScrollPosition = {
    @:optional var scrollLeft:Float;
    @:optional var scrollTop:Float;
}

/**
 * An action of the editor (`addAction`, the actions of the contributions).
 *
 * `run` returns nothing: Monaco returns a promise; an asynchronous action
 * completes on its own.
 */
interface IEditorAction {
    final id:String;
    final label:String;
    final alias:String;
    final metadata:Null<ICommandMetadata>;
    function isSupported():Bool;
    function run(?args:Any):Void;
}

/**
 * Monaco's `IEditorModel`: `ITextModel | IDiffEditorModel |
 * IDiffEditorViewModel`. The diff editor comes last (step 7); its view model
 * is not part of the type yet.
 */
typedef IEditorModel = EitherType<ITextModel, IDiffEditorModel>;

/**
 * A (serializable) state of the cursors.
 */
typedef ICursorState = {
    var inSelectionMode:Bool;
    var selectionStart:IPosition;
    var position:IPosition;
}

/**
 * A (serializable) state of the view.
 */
typedef IViewState = {
    /** written by previous versions */
    @:optional var scrollTop:Float;
    /** written by previous versions */
    @:optional var scrollTopWithoutViewZones:Float;
    var scrollLeft:Float;
    var firstPosition:IPosition;
    var firstPositionDeltaTop:Float;
}

/**
 * A (serializable) state of the code editor.
 */
typedef ICodeEditorViewState = {
    var cursorState:Array<ICursorState>;
    var viewState:IViewState;
    var contributionsState:Map<String, Any>;
}

/**
 * (Serializable) View state for the diff editor.
 */
typedef IDiffEditorViewState = {
    var original:Null<ICodeEditorViewState>;
    var modified:Null<ICodeEditorViewState>;
    @:optional var modelState:Any;
}

/**
 * An editor view state.
 */
typedef IEditorViewState = EitherType<ICodeEditorViewState, IDiffEditorViewState>;

enum abstract ScrollType(Int) from Int to Int {
    var Smooth = 0;
    var Immediate = 1;
}

/**
 * An editor.
 *
 * Differences with Monaco's interface: `setSelection` takes any of its four
 * forms through one parameter (a `Range` or a `Selection` is an `IRange`; an
 * `ISelection` is also accepted); `layout` is driven by the Glaze layout
 * (Cityscape's editor is a Glaze component), the method is kept for
 * Monaco code.
 */
interface IEditor {
    /**
     * An event emitted when the editor has been disposed.
     * @event
     */
    function onDidDispose(listener:() -> Void):IDisposable;

    /**
     * Dispose the editor.
     */
    function dispose():Void;

    /**
     * Get a unique id for this editor instance.
     */
    function getId():String;

    /**
     * Get the editor type. Please see `EditorType`.
     * This is to avoid an instanceof check
     */
    function getEditorType():String;

    /**
     * Update the editor's options after the editor has been created.
     */
    function updateOptions(newOptions:IEditorOptions):Void;

    /**
     * Indicates that the editor becomes visible.
     * @internal
     */
    function onVisible():Void;

    /**
     * Indicates that the editor becomes hidden.
     * @internal
     */
    function onHide():Void;

    /**
     * Instructs the editor to remeasure its container. This method should
     * be called when the container of the editor gets resized.
     *
     * If a dimension is passed in, the passed in value will be used.
     *
     * By default, this will also render the editor immediately.
     * If you prefer to delay rendering to the next animation frame, use postponeRendering == true.
     */
    function layout(?dimension:IDimension, ?postponeRendering:Bool):Void;

    /**
     * Brings browser focus to the editor text
     */
    function focus():Void;

    /**
     * Returns true if the text inside this editor is focused (i.e. cursor is blinking).
     */
    function hasTextFocus():Bool;

    /**
     * Returns all actions associated with this editor.
     */
    function getSupportedActions():Array<IEditorAction>;

    /**
     * Saves current view state of the editor in a serializable object.
     */
    function saveViewState():Null<IEditorViewState>;

    /**
     * Restores the view state of the editor from a serializable object generated by `saveViewState`.
     */
    function restoreViewState(state:Null<IEditorViewState>):Void;

    /**
     * Given a position, returns a column number that takes tab-widths into account.
     */
    function getVisibleColumnFromPosition(position:IPosition):Int;

    /**
     * Given a position, returns a column number that takes tab-widths into account.
     * @internal
     */
    function getStatusbarColumn(position:IPosition):Int;

    /**
     * Returns the primary position of the cursor.
     */
    function getPosition():Null<Position>;

    /**
     * Set the primary position of the cursor. This will remove any secondary cursors.
     * @param position New primary cursor's position
     * @param source Source of the call that caused the position
     */
    function setPosition(position:IPosition, ?source:String):Void;

    /**
     * Scroll vertically as necessary and reveal a line.
     */
    function revealLine(lineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically as necessary and reveal a line centered vertically.
     */
    function revealLineInCenter(lineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically as necessary and reveal a line centered vertically only if it lies outside the viewport.
     */
    function revealLineInCenterIfOutsideViewport(lineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically as necessary and reveal a line close to the top of the viewport,
     * optimized for viewing a code definition.
     */
    function revealLineNearTop(lineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a position.
     */
    function revealPosition(position:IPosition, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a position centered vertically.
     */
    function revealPositionInCenter(position:IPosition, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a position centered vertically only if it lies outside the viewport.
     */
    function revealPositionInCenterIfOutsideViewport(position:IPosition, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a position close to the top of the viewport,
     * optimized for viewing a code definition.
     */
    function revealPositionNearTop(position:IPosition, ?scrollType:ScrollType):Void;

    /**
     * Returns the primary selection of the editor.
     */
    function getSelection():Null<Selection>;

    /**
     * Returns all the selections of the editor.
     */
    function getSelections():Null<Array<Selection>>;

    /**
     * Set the primary selection of the editor. This will remove any secondary cursors.
     * @param selection The new selection: an `IRange` (a `Range`, a
     * `Selection`) or an `ISelection`
     * @param source Source of the call that caused the selection
     */
    function setSelection(selection:EitherType<IRange, ISelection>, ?source:String):Void;

    /**
     * Set the selections for all the cursors of the editor.
     * Cursors will be removed or added, as necessary.
     * @param selections The new selection
     * @param source Source of the call that caused the selection
     */
    function setSelections(selections:Array<ISelection>, ?source:String):Void;

    /**
     * Scroll vertically as necessary and reveal lines.
     */
    function revealLines(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically as necessary and reveal lines centered vertically.
     */
    function revealLinesInCenter(lineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically as necessary and reveal lines centered vertically only if it lies outside the viewport.
     */
    function revealLinesInCenterIfOutsideViewport(lineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically as necessary and reveal lines close to the top of the viewport,
     * optimized for viewing a code definition.
     */
    function revealLinesNearTop(lineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a range.
     */
    function revealRange(range:IRange, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a range centered vertically.
     */
    function revealRangeInCenter(range:IRange, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a range at the top of the viewport.
     */
    function revealRangeAtTop(range:IRange, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a range centered vertically only if it lies outside the viewport.
     */
    function revealRangeInCenterIfOutsideViewport(range:IRange, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a range close to the top of the viewport,
     * optimized for viewing a code definition.
     */
    function revealRangeNearTop(range:IRange, ?scrollType:ScrollType):Void;

    /**
     * Scroll vertically or horizontally as necessary and reveal a range close to the top of the viewport,
     * optimized for viewing a code definition. Only if it lies outside the viewport.
     */
    function revealRangeNearTopIfOutsideViewport(range:IRange, ?scrollType:ScrollType):Void;

    /**
     * Directly trigger a handler or an editor action.
     * @param source The source of the call.
     * @param handlerId The id of the handler or the id of a contribution.
     * @param payload Extra data to be sent to the handler.
     */
    function trigger(source:Null<String>, handlerId:String, payload:Any):Void;

    /**
     * Gets the current model attached to this editor.
     */
    function getModel():Null<IEditorModel>;

    /**
     * Sets the current model attached to this editor.
     * If the previous model was created by the editor via the value key in the options
     * literal object, it will be destroyed. Otherwise, if the previous model was set
     * via setModel, or the model key in the options literal object, the previous model
     * will not be destroyed.
     * It is safe to call setModel(null) to simply detach the current model from the editor.
     */
    function setModel(model:Null<IEditorModel>):Void;

    /**
     * Create a collection of decorations. All decorations added through this collection
     * will get the ownerId of the editor (meaning they will not show up in other editors).
     * These decorations will be automatically cleared when the editor's model changes.
     */
    function createDecorationsCollection(?decorations:Array<IModelDeltaDecoration>):IEditorDecorationsCollection;

    /**
     * Change the decorations. All decorations added through this changeAccessor
     * will get the ownerId of the editor (meaning they will not show up in other
     * editors).
     * @see {@link ITextModel.changeDecorations}
     * @internal
     */
    function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T>;
}

/**
 * A collection of decorations
 */
interface IEditorDecorationsCollection {
    /**
     * An event emitted when decorations change in the editor,
     * but the change is not caused by us setting or clearing the collection.
     */
    final onDidChange:Event<IModelDecorationsChangedEvent>;
    /**
     * Get the decorations count.
     */
    var length(get, never):Int;
    /**
     * Get the range for a decoration.
     */
    function getRange(index:Int):Null<Range>;
    /**
     * Get all ranges for decorations.
     */
    function getRanges():Array<Range>;
    /**
     * Determine if a decoration is in this collection.
     */
    function has(decoration:IModelDecoration):Bool;
    /**
     * Replace all previous decorations with `newDecorations`.
     */
    function set(newDecorations:Array<IModelDeltaDecoration>):Array<String>;
    /**
     * Append `newDecorations` to this collection.
     */
    function append(newDecorations:Array<IModelDeltaDecoration>):Array<String>;
    /**
     * Remove all previous decorations.
     */
    function clear():Void;
}

/**
 * An editor contribution that gets created every time a new editor gets created and gets disposed when the editor gets disposed.
 *
 * Monaco's optional `saveViewState` and `restoreViewState` are always
 * present here (return null and do nothing when the contribution has no
 * view state).
 */
interface IEditorContribution {
    /**
     * Dispose this contribution.
     */
    function dispose():Void;
    /**
     * Store view state.
     */
    function saveViewState():Any;
    /**
     * Restore view state.
     */
    function restoreViewState(state:Any):Void;
}

/**
 * The type of the `IEditor`.
 */
class EditorType {

    public static inline final ICodeEditor:String = 'vs.editor.ICodeEditor';

    public static inline final IDiffEditor:String = 'vs.editor.IDiffEditor';

}

/**
 * Built-in commands.
 * @internal
 */
enum abstract Handler(String) from String to String {
    var CompositionStart = 'compositionStart';
    var CompositionEnd = 'compositionEnd';
    var Type = 'type';
    var ReplacePreviousChar = 'replacePreviousChar';
    var CompositionType = 'compositionType';
    var Paste = 'paste';
    var Cut = 'cut';
}

/**
 * @internal
 */
typedef TypePayload = {
    var text:String;
}

/**
 * @internal
 */
typedef ReplacePreviousCharPayload = {
    var text:String;
    var replaceCharCnt:Int;
}

/**
 * @internal
 */
typedef CompositionTypePayload = {
    var text:String;
    var replacePrevCharCnt:Int;
    var replaceNextCharCnt:Int;
    var positionDelta:Int;
}

class EditorCommonUtils {

    /**
     * @internal
     */
    public static function isThemeColor(o:Any):Bool {
        return cityscape.base.common.Themables.isThemeColor(o);
    }

}
