// Ported from vscode src/vs/editor/browser/editorBrowser.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon;
import cityscape.common.Model;
import cityscape.common.TextModelEvents;
import cityscape.common.ViewModel.IViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions.EditorLayoutInfo;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;

/**
 * Paints a view zone (Cityscape's replacement for Monaco's `domNode` and
 * `marginDomNode`): `bounds` is the zone's area in window coordinates (the
 * content area for `paint`, the margin for `paintMargin`), clipped to it.
 */
typedef ViewZonePainter = (window:glaze.Window, cx:glaze.App, bounds:glaze.Bounds) -> Void;

/**
 * A view zone is a full horizontal rectangle that 'pushes' text down.
 * The editor reserves space for view zones when rendering.
 *
 * Monaco's `domNode` and `marginDomNode` are `paint` and `paintMargin`
 * here (both optional: a zone without a painter is empty space).
 */
typedef IViewZone = {
    /**
     * The line number after which this zone should appear.
     * Use 0 to place a view zone before the first line number.
     */
    var afterLineNumber:Int;
    /**
     * The column after which this zone should appear.
     * If not set, the maxLineColumn of `afterLineNumber` will be used.
     * This is relevant for wrapped lines.
     */
    @:optional var afterColumn:Null<Int>;
    /**
     * If the `afterColumn` has multiple view columns, the affinity specifies which one to use. Defaults to `none`.
     */
    @:optional var afterColumnAffinity:Null<PositionAffinity>;
    /**
     * Render the zone even when its line is hidden.
     */
    @:optional var showInHiddenAreas:Null<Bool>;
    /**
     * Tiebreaker that is used when multiple view zones want to be after the same line.
     * Defaults to `afterColumn` otherwise 10000;
     */
    @:optional var ordinal:Null<Int>;
    /**
     * Suppress mouse down events.
     * If set, a mouse down on the zone does not move the cursor nor take the focus.
     * Defaults to false
     */
    @:optional var suppressMouseDown:Null<Bool>;
    /**
     * The height in lines of the view zone.
     * If specified, `heightInPx` will be used instead of this.
     * If neither `heightInPx` nor `heightInLines` is specified, a default of `heightInLines` = 1 will be chosen.
     */
    @:optional var heightInLines:Null<Float>;
    /**
     * The height in px of the view zone.
     * If this is set, the editor will give preference to it rather than `heightInLines` above.
     * If neither `heightInPx` nor `heightInLines` is specified, a default of `heightInLines` = 1 will be chosen.
     */
    @:optional var heightInPx:Null<Float>;
    /**
     * The minimum width in px of the view zone.
     * If this is set, the editor will ensure that the scroll width is >= than this value.
     */
    @:optional var minWidthInPx:Null<Float>;
    /**
     * Paints the zone in the content area (Monaco's `domNode`).
     */
    @:optional var paint:Null<ViewZonePainter>;
    /**
     * Paints the zone in the margin area (Monaco's `marginDomNode`).
     */
    @:optional var paintMargin:Null<ViewZonePainter>;
    /**
     * Callback which gives the relative top of the view zone as it appears (taking scrolling into account).
     */
    @:optional var onDomNodeTop:Null<(top:Float) -> Void>;
    /**
     * Callback which gives the height in pixels of the view zone.
     */
    @:optional var onComputedHeight:Null<(height:Float) -> Void>;
}

/**
 * An accessor that allows for zones to be added or removed.
 */
interface IViewZoneChangeAccessor {
    /**
     * Create a new view zone.
     * @param zone Zone to create
     * @return A unique identifier to the view zone.
     */
    function addZone(zone:IViewZone):String;
    /**
     * Remove a zone
     * @param id A unique identifier to the view zone, as returned by the `addZone` call.
     */
    function removeZone(id:String):Void;
    /**
     * Change a zone's position.
     * The editor will rescan the `afterLineNumber` and `afterColumn` properties of a view zone.
     */
    function layoutZone(id:String):Void;
}

/**
 * A positioning preference for rendering overlay widgets.
 */
enum abstract OverlayWidgetPositionPreference(Int) from Int to Int {
    /**
     * Position the overlay widget in the top right corner
     */
    var TOP_RIGHT_CORNER = 0;

    /**
     * Position the overlay widget in the bottom right corner
     */
    var BOTTOM_RIGHT_CORNER = 1;

    /**
     * Position the overlay widget in the top center
     */
    var TOP_CENTER = 2;
}

/**
 * Represents editor-relative coordinates of an overlay widget.
 */
typedef IOverlayWidgetPositionCoordinates = {
    /**
     * The top position for the overlay widget, relative to the editor.
     */
    var top:Float;
    /**
     * The left position for the overlay widget, relative to the editor.
     */
    var left:Float;
}

/**
 * A position for rendering overlay widgets: `preference` is an
 * `OverlayWidgetPositionPreference` or `IOverlayWidgetPositionCoordinates`
 * (or null: the widget places itself).
 */
typedef IOverlayWidgetPosition = {
    var preference:Null<haxe.extern.EitherType<OverlayWidgetPositionPreference, IOverlayWidgetPositionCoordinates>>;
    /**
     * When set, stacks with other overlay widgets with the same preference,
     * in an order determined by the ordinal value.
     */
    @:optional var stackOridinal:Int;
}

/**
 * An overlay widget renders on top of the text (the find widget). Cityscape
 * renders it with Glaze: `render` returns the element to place (Monaco's
 * `getDomNode`), inside the editor's root element and key context.
 */
interface IOverlayWidget {
    /**
     * Get a unique identifier of the overlay widget.
     */
    function getId():String;

    /**
     * The element of the overlay widget, rendered each time the editor
     * renders (null renders nothing).
     */
    function render(window:glaze.Window, cx:glaze.App):Null<glaze.IntoElement>;

    /**
     * Get the placement of the overlay widget.
     * If null is returned, the overlay widget is responsible to place itself.
     */
    function getPosition():Null<IOverlayWidgetPosition>;
}

/**
 * Type of hit element with the mouse in the editor.
 */
enum abstract MouseTargetType(Int) from Int to Int {
    /**
     * Mouse is on top of an unknown element.
     */
    var UNKNOWN = 0;
    /**
     * Mouse is on top of the textarea used for input.
     */
    var TEXTAREA = 1;
    /**
     * Mouse is on top of the glyph margin
     */
    var GUTTER_GLYPH_MARGIN = 2;
    /**
     * Mouse is on top of the line numbers
     */
    var GUTTER_LINE_NUMBERS = 3;
    /**
     * Mouse is on top of the line decorations
     */
    var GUTTER_LINE_DECORATIONS = 4;
    /**
     * Mouse is on top of the whitespace left in the gutter by a view zone.
     */
    var GUTTER_VIEW_ZONE = 5;
    /**
     * Mouse is on top of text in the content.
     */
    var CONTENT_TEXT = 6;
    /**
     * Mouse is on top of empty space in the content (e.g. after line text or below last line)
     */
    var CONTENT_EMPTY = 7;
    /**
     * Mouse is on top of a view zone in the content.
     */
    var CONTENT_VIEW_ZONE = 8;
    /**
     * Mouse is on top of a content widget.
     */
    var CONTENT_WIDGET = 9;
    /**
     * Mouse is on top of the decorations overview ruler.
     */
    var OVERVIEW_RULER = 10;
    /**
     * Mouse is on top of a scrollbar.
     */
    var SCROLLBAR = 11;
    /**
     * Mouse is on top of an overlay widget.
     */
    var OVERLAY_WIDGET = 12;
    /**
     * Mouse is outside of the editor.
     */
    var OUTSIDE_EDITOR = 13;
}

/**
 * Target hit with the mouse in the editor (Monaco's `IMouseTarget` union,
 * flattened: the `detail` fields of each kind are fields here).
 */
typedef IMouseTargetViewZoneData = {
    final viewZoneId:String;
    final positionBefore:Null<Position>;
    final positionAfter:Null<Position>;
    final position:Position;
    final afterLineNumber:Int;
}

class MouseTarget {

    /**
     * The target type
     */
    public final type:MouseTargetType;

    /**
     * The 'approximate' editor position
     */
    public final position:Null<Position>;

    /**
     * Desired mouse column (e.g. when position.column gets clamped to text length -- clicking after text on a line).
     */
    public final mouseColumn:Int;

    /**
     * The 'approximate' editor range
     */
    public final range:Null<Range>;

    /**
     * Gutter targets: the left of the gutter element hit (Monaco's
     * `target.element.offsetLeft`: the line decorations start at
     * `layoutInfo.decorationsLeft`).
     */
    public final elementOffsetLeft:Float;

    /**
     * Gutter targets: `detail.offsetX`, the x of the mouse from the left of
     * the editor.
     */
    public final offsetX:Float;

    /**
     * Gutter and empty content targets: `detail.isAfterLines`.
     */
    public final isAfterLines:Bool;

    /**
     * Empty content targets inside the lines: `detail.horizontalDistanceToText`.
     */
    public final horizontalDistanceToText:Float;

    public function new(type:MouseTargetType, position:Null<Position>, mouseColumn:Int, range:Null<Range>, elementOffsetLeft:Float = 0, offsetX:Float = 0, isAfterLines:Bool = false, horizontalDistanceToText:Float = 0) {
        this.type = type;
        this.position = position;
        this.mouseColumn = mouseColumn;
        this.range = range;
        this.elementOffsetLeft = elementOffsetLeft;
        this.offsetX = offsetX;
        this.isAfterLines = isAfterLines;
        this.horizontalDistanceToText = horizontalDistanceToText;
    }

    /**
     * View zone targets (`CONTENT_VIEW_ZONE`, `GUTTER_VIEW_ZONE`): Monaco's
     * `detail`, the zone and the positions around it (model positions).
     */
    public var viewZoneData:Null<IMouseTargetViewZoneData> = null;

    /**
     * View zone targets: the y of the mouse from the top of the zone
     * (Cityscape addition, Monaco's DOM event gives the element).
     */
    public var viewZoneOffsetY:Float = 0;

    /**
     * Text targets (`CONTENT_TEXT`): Monaco's `detail.injectedText`, the
     * injected text under the mouse (an inlay hint, a color swatch), or
     * null.
     */
    public var injectedText:Null<cityscape.common.ModelLineProjectionData.InjectedText> = null;

    public function toString():String {
        return 'MouseTarget(' + type + ', ' + (range != null ? range.toString() : 'null') + ')';
    }

}

/**
 * The mouse event of Monaco's `IMouseEvent`, the fields the contributions
 * read.
 */
class EditorMouseEventData {

    public final leftButton:Bool;
    public final middleButton:Bool;
    public final rightButton:Bool;
    public final ctrlKey:Bool;
    public final shiftKey:Bool;
    public final altKey:Bool;
    public final metaKey:Bool;
    /**
     * The click count.
     */
    public final detail:Int;
    /**
     * The position of the mouse in window coordinates (Monaco's `posx`,
     * `posy` in the page).
     */
    public final posx:Float;
    public final posy:Float;

    public function new(leftButton:Bool, middleButton:Bool, rightButton:Bool, ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool, detail:Int, posx:Float = 0, posy:Float = 0) {
        this.leftButton = leftButton;
        this.middleButton = middleButton;
        this.rightButton = rightButton;
        this.ctrlKey = ctrlKey;
        this.shiftKey = shiftKey;
        this.altKey = altKey;
        this.metaKey = metaKey;
        this.detail = detail;
        this.posx = posx;
        this.posy = posy;
    }

}

/**
 * A mouse event in the editor (Monaco's `IEditorMouseEvent`).
 */
class EditorMouseEvent {

    public final event:EditorMouseEventData;
    public final target:MouseTarget;

    public function new(event:EditorMouseEventData, target:MouseTarget) {
        this.event = event;
        this.target = target;
    }

}

/**
 * Monaco's names of the mouse types.
 */
typedef IMouseTarget = MouseTarget;
typedef IMouseEvent = EditorMouseEventData;
typedef IEditorMouseEvent = EditorMouseEvent;

/**
 * Monaco's `IPartialEditorMouseEvent`: a mouse event whose target may be
 * unknown (`onMouseLeave`).
 */
typedef IPartialEditorMouseEvent = {
    final event:EditorMouseEventData;
    final target:Null<MouseTarget>;
}

typedef IPasteEvent = {
    final range:Range;
    final languageId:Null<String>;
}

/**
 * A rich code editor (Monaco's `ICodeEditor`, implemented by
 * `CodeEditorWidget`). The parts that are DOM nodes in Monaco (content and
 * glyph margin widgets, view zones, banners, aria) are not part of it yet.
 *
 * `context` is the `Cityscape` context of the editor (Monaco's services) and
 * `contextKeyService` its scoped context key service (Monaco injects it in
 * the editor contributions).
 */
interface ICodeEditor extends IEditor {

    /**
     * The `Cityscape` context of the editor.
     */
    var context(get, never):Cityscape;

    /**
     * The scoped context key service of the editor.
     */
    var contextKeyService(get, never):IContextKeyService;

    /**
     * This editor is used as an alternative to an <input> box, i.e. as a simple widget.
     * @internal
     */
    var isSimpleWidget(get, never):Bool;

    /**
     * An event emitted when the content of the current model has changed.
     * @event
     */
    var onDidChangeModelContent(get, never):Event<IModelContentChangedEvent>;
    /**
     * An event emitted when the language of the current model has changed.
     * @event
     */
    var onDidChangeModelLanguage(get, never):Event<IModelLanguageChangedEvent>;
    /**
     * An event emitted when the language configuration of the current model has changed.
     * @event
     */
    var onDidChangeModelLanguageConfiguration(get, never):Event<IModelLanguageConfigurationChangedEvent>;
    /**
     * An event emitted when the options of the current model has changed.
     * @event
     */
    var onDidChangeModelOptions(get, never):Event<IModelOptionsChangedEvent>;
    /**
     * An event emitted when the configuration of the editor has changed. (e.g. `editor.updateOptions()`)
     * @event
     */
    var onDidChangeConfiguration(get, never):Event<ConfigurationChangedEvent>;
    /**
     * An event emitted when the cursor position has changed.
     * @event
     */
    var onDidChangeCursorPosition(get, never):Event<ICursorPositionChangedEvent>;
    /**
     * An event emitted when the cursor selection has changed.
     * @event
     */
    var onDidChangeCursorSelection(get, never):Event<ICursorSelectionChangedEvent>;
    /**
     * An event emitted when the model of this editor is about to change (e.g. from `editor.setModel()`).
     * @event
     */
    var onWillChangeModel(get, never):Event<IModelChangedEvent>;
    /**
     * An event emitted when the model of this editor has changed (e.g. `editor.setModel()`).
     * @event
     */
    var onDidChangeModel(get, never):Event<IModelChangedEvent>;
    /**
     * An event emitted when the decorations of the current model have changed.
     * @event
     */
    var onDidChangeModelDecorations(get, never):Event<IModelDecorationsChangedEvent>;

    /**
     * An event emitted when the tokens of the current model have changed.
     */
    var onDidChangeModelTokens(get, never):Event<cityscape.common.TextModelEvents.IModelTokensChangedEvent>;
    /**
     * An event emitted when the text inside this editor gained focus (i.e. cursor starts blinking).
     * @event
     */
    var onDidFocusEditorText(get, never):VoidEvent;
    /**
     * An event emitted when the text inside this editor lost focus (i.e. cursor stops blinking).
     * @event
     */
    var onDidBlurEditorText(get, never):VoidEvent;
    /**
     * An event emitted when the text inside this editor or an editor widget gained focus.
     * @event
     */
    var onDidFocusEditorWidget(get, never):VoidEvent;
    /**
     * An event emitted when the text inside this editor or an editor widget lost focus.
     * @event
     */
    var onDidBlurEditorWidget(get, never):VoidEvent;
    /**
     * An event emitted before interpreting typed characters (on the keyboard).
     * @event
     */
    var onWillType(get, never):Event<String>;
    /**
     * An event emitted after interpreting typed characters (on the keyboard).
     * @event
     */
    var onDidType(get, never):Event<String>;
    /**
     * An event emitted after composition has started.
     */
    var onDidCompositionStart(get, never):VoidEvent;
    /**
     * An event emitted after composition has ended.
     */
    var onDidCompositionEnd(get, never):VoidEvent;
    /**
     * An event emitted when editing failed because the editor is read-only.
     * @event
     */
    var onDidAttemptReadOnlyEdit(get, never):VoidEvent;
    /**
     * An event emitted when users paste text in the editor.
     * @event
     */
    var onDidPaste(get, never):Event<IPasteEvent>;
    /**
     * An event emitted on a "mouseup".
     * @event
     */
    var onMouseUp(get, never):Event<IEditorMouseEvent>;
    /**
     * An event emitted on a "mousedown".
     * @event
     */
    var onMouseDown(get, never):Event<IEditorMouseEvent>;
    /**
     * An event emitted on a "contextmenu".
     * @event
     */
    var onContextMenu(get, never):Event<IEditorMouseEvent>;
    /**
     * An event emitted on a "mousemove".
     * @event
     */
    var onMouseMove(get, never):Event<IEditorMouseEvent>;
    /**
     * An event emitted on a "mouseleave".
     * @event
     */
    var onMouseLeave(get, never):Event<IPartialEditorMouseEvent>;
    /**
     * An event emitted on a "keyup".
     * @event
     */
    var onKeyUp(get, never):Event<IKeyboardEvent>;
    /**
     * An event emitted on a "keydown".
     * @event
     */
    var onKeyDown(get, never):Event<IKeyboardEvent>;
    /**
     * An event emitted when the layout of the editor has changed.
     * @event
     */
    var onDidLayoutChange(get, never):Event<EditorLayoutInfo>;
    /**
     * An event emitted when the content width or content height in the editor has changed.
     * @event
     */
    var onDidContentSizeChange(get, never):Event<IContentSizeChangedEvent>;
    /**
     * An event emitted when the scroll in the editor has changed.
     * @event
     */
    var onDidScrollChange(get, never):Event<IScrollEvent>;
    /**
     * An event emitted when hidden areas change in the editor (e.g. due to folding).
     * @event
     */
    var onDidChangeHiddenAreas(get, never):VoidEvent;
    /**
     * An event emitted when the view zones of the editor change.
     * @event
     */
    var onDidChangeViewZones(get, never):VoidEvent;

    /**
     * Saves current view state of the editor in a serializable object.
     */
    function saveViewState():Null<IEditorViewState>;

    /**
     * Restores the view state of the editor from a serializable object generated by `saveViewState`.
     */
    function restoreViewState(state:Null<IEditorViewState>):Void;

    /**
     * Returns true if the text inside this editor or an editor widget has focus.
     */
    function hasWidgetFocus():Bool;

    /**
     * Get a contribution of this editor.
     * @id Unique identifier of the contribution.
     * @return The contribution or null if contribution not found.
     */
    function getContribution<T:IEditorContribution>(id:String):Null<T>;

    /**
     * Execute `fn` with the editor's services (Monaco's accessor: the
     * `Cityscape` context).
     * @internal
     */
    function invokeWithinContext<T>(fn:(accessor:Cityscape) -> T):T;

    /**
     * Type the getModel() of IEditor.
     */
    function getModel():Null<ITextModel>;

    /**
     * The model of the editor (`getModel()`, kept for the core commands).
     */
    function getTextModel():Null<ITextModel>;

    /**
     * Gets all the editor computed options.
     */
    function getOptions():IComputedEditorOptions;

    /**
     * Gets a specific editor option.
     */
    function getOption<V>(id:EditorOption<V>):V;

    /**
     * Returns the editor's configuration (without any validation or defaults).
     */
    function getRawOptions():IEditorOptions;

    /**
     * Get value of the current model attached to this editor.
     * @see {@link ITextModel.getValue}
     */
    function getValue(?options:{preserveBOM:Bool, lineEnding:String}):String;

    /**
     * Set the value of the current model attached to this editor.
     * @see {@link ITextModel.setValue}
     */
    function setValue(newValue:String):Void;

    /**
     * Get the width of the editor's content.
     */
    function getContentWidth():Float;

    /**
     * Get the scrollWidth of the editor's viewport.
     */
    function getScrollWidth():Float;

    /**
     * Get the scrollLeft of the editor's viewport.
     */
    function getScrollLeft():Float;

    /**
     * Get the height of the editor's content.
     */
    function getContentHeight():Float;

    /**
     * Get the scrollHeight of the editor's viewport.
     */
    function getScrollHeight():Float;

    /**
     * Get the scrollTop of the editor's viewport.
     */
    function getScrollTop():Float;

    /**
     * Change the scrollLeft of the editor's viewport.
     */
    function setScrollLeft(newScrollLeft:Float, ?scrollType:ScrollType):Void;

    /**
     * Change the scrollTop of the editor's viewport.
     */
    function setScrollTop(newScrollTop:Float, ?scrollType:ScrollType):Void;

    /**
     * Change the scroll position of the editor's viewport.
     */
    function setScrollPosition(position:INewScrollPosition, ?scrollType:ScrollType):Void;

    /**
     * Get an action that is a contribution to this editor.
     * @id Unique identifier of the contribution.
     * @return The action or null if action not found.
     */
    function getAction(id:String):Null<IEditorAction>;

    /**
     * Execute a command on the editor.
     * The edits will land on the undo-redo stack, but no "undo stop" will be pushed.
     * @param source The source of the call.
     * @param command The command to execute
     */
    function executeCommand(source:Null<String>, command:ICommand):Void;

    /**
     * Create an "undo stop" in the undo-redo stack.
     */
    function pushUndoStop():Bool;

    /**
     * Remove the "undo stop" in the undo-redo stack.
     */
    function popUndoStop():Bool;

    /**
     * Execute edits on the editor.
     * The edits will land on the undo-redo stack, but no "undo stop" will be pushed.
     * @param source The source of the call.
     * @param edits The edits to execute.
     * @param endCursorState Cursor state after the edits were applied: null,
     * an array of selections or an `ICursorStateComputer`.
     */
    function executeEdits(source:Null<String>, edits:Array<IIdentifiedSingleEditOperation>, ?endCursorState:haxe.extern.EitherType<Array<Selection>, ICursorStateComputer>):Bool;

    /**
     * Execute multiple (concomitant) commands on the editor.
     * @param source The source of the call.
     * @param command The commands to execute
     */
    function executeCommands(source:Null<String>, commands:Array<Null<ICommand>>):Void;

    /**
     * @internal
     */
    function _getViewModel():Null<IViewModel>;

    /**
     * Get all the decorations on a line (filtering out decorations from other editors).
     */
    function getLineDecorations(lineNumber:Int):Null<Array<IModelDecoration>>;

    /**
     * Get all the decorations for a range (filtering out decorations from other editors).
     */
    function getDecorationsInRange(range:Range):Null<Array<IModelDecoration>>;

    /**
     * All decorations added through this call will get the ownerId of this editor.
     * @deprecated Use `createDecorationsCollection`
     * @see createDecorationsCollection
     */
    function deltaDecorations(oldDecorations:Array<String>, newDecorations:Array<IModelDeltaDecoration>):Array<String>;

    /**
     * Remove previously added decorations.
     */
    function removeDecorations(decorationIds:Array<String>):Void;

    /**
     * Get the layout info for the editor.
     */
    function getLayoutInfo():EditorLayoutInfo;

    /**
     * Returns the ranges that are currently visible.
     * Does not account for horizontal scrolling.
     */
    function getVisibleRanges():Array<Range>;

    /**
     * Returns the ranges that are currently visible plus a viewport above
     * and below (inlay hints, step 7, cs7-rest-inlay).
     */
    function getVisibleRangesPlusViewportAboveBelow():Array<Range>;

    /**
     * Get the vertical position (top offset) for the line's top w.r.t. to the first line.
     */
    function getTopForLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float;

    /**
     * Get the vertical position (top offset) for the line's bottom w.r.t. to the first line.
     */
    function getBottomForLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float;

    /**
     * Get the vertical position (top offset) for the position w.r.t. to the first line.
     */
    function getTopForPosition(lineNumber:Int, column:Int):Float;

    /**
     * Set the model ranges that will be hidden in the view.
     * Hidden areas are stored per source.
     * @internal
     */
    function setHiddenAreas(ranges:Array<IRange>, ?source:Any):Void;

    /**
     * Change the view zones. View zones are lost when a new model is attached to the editor.
     */
    function changeViewZones(callback:(accessor:IViewZoneChangeAccessor) -> Void):Void;

    /**
     * The whitespaces of the view zones (Monaco's `getWhitespaces`, @internal).
     */
    function getWhitespaces():Array<cityscape.common.ViewModel.IEditorWhitespace>;

    /**
     * Add an overlay widget. Widgets must have unique ids, otherwise they will be overwritten.
     */
    function addOverlayWidget(widget:IOverlayWidget):Void;

    /**
     * Layout/Reposition an overlay widget. This is a ping to the editor to call widget.getPosition()
     * and update appropriately.
     */
    function layoutOverlayWidget(widget:IOverlayWidget):Void;

    /**
     * Remove an overlay widget.
     */
    function removeOverlayWidget(widget:IOverlayWidget):Void;

    /**
     * Get the hit test target at coordinates `clientX` and `clientY` (window coordinates).
     */
    function getTargetAtClientPoint(clientX:Float, clientY:Float):Null<IMouseTarget>;

    /**
     * Get the visible position for `position`.
     * The result position takes scrolling into account and is relative to the top left corner of the editor.
     */
    function getScrolledVisiblePosition(position:IPosition):Null<{top:Float, left:Float, height:Float}>;

    /**
     * Get the horizontal position (left offset) for the column w.r.t to the beginning of the line.
     */
    function getOffsetForColumn(lineNumber:Int, column:Int):Float;

    /**
     * Force an editor render now.
     */
    function render(?forceRedraw:Bool):Void;

    /**
     * Whether the editor has a model (Monaco's `hasModel()` type guard).
     */
    function hasModel():Bool;

    /**
     * Runs a clipboard action of the editor: `cut`, `copy` or `paste`
     * (Monaco's `document.execCommand` on the editor's textarea). Returns
     * false without a view.
     * @internal
     */
    function _executeClipboardAction(action:String):Bool;

    /**
     * Set the value of a context key of the editor.
     */
    function setContextValue(key:String, value:Any):Void;

    /**
     * Get the configured word at a position.
     */
    function getConfiguredWordAtPosition(position:Position):Null<IWordAtPosition>;

    /**
     * Change the decorations of the editor (owned by it) in one call. All
     * decorations added through this changeAccessor are owned by the
     * editor (Monaco's `changeDecorations`).
     */
    function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T>;


}
