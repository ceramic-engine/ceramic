// Ported from vscode src/vs/editor/contrib/hover/browser/contentHoverController2.ts,
// contentHoverWidgetWrapper.ts, contentHoverTypes.ts, contentHoverRendered.ts,
// hoverActions.ts and hoverContribution.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

import cityscape.Cityscape;
import cityscape.base.common.Async;
import cityscape.base.common.Event;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.EditorContextKeys;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.hover.view.HoverOperation;
import cityscape.contrib.hover.view.HoverTypes;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.platform.keybinding.common.KeybindingResolver.ResultKind;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Render;
import glaze.Window;
import glaze.kit.scroll.Scrollable.ScrollableElement;
import cityscape.view.ContentWidgetPositioner;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/**
 * The parts computed for an anchor (Monaco's `HoverResult` of
 * contentHoverTypes.ts, with `FilteredHoverResult`).
 */
class HoverResult {

    public final anchor:HoverAnchor;
    public final hoverParts:Array<IHoverPart>;
    public final isComplete:Bool;
    final original:Null<HoverResult>;

    public function new(anchor:HoverAnchor, hoverParts:Array<IHoverPart>, isComplete:Bool, ?original:HoverResult) {
        this.anchor = anchor;
        this.hoverParts = hoverParts;
        this.isComplete = isComplete;
        this.original = original;
    }

    public function filter(anchor:HoverAnchor):HoverResult {
        if (original != null) {
            return original.filter(anchor);
        }
        final filteredHoverParts = [for (m in this.hoverParts) if (m.isValidForHoverAnchor(anchor)) m];
        if (filteredHoverParts.length == this.hoverParts.length) {
            return this;
        }
        return new HoverResult(this.anchor, filteredHoverParts, this.isComplete, this);
    }
}

/**
 * An action of the status bar of the hover (Monaco's `HoverAction`).
 */
class HoverStatusBarAction {

    public final label:String;
    public final commandId:String;
    /** The label of the primary keybinding of the command, or null. */
    public final keybindingLabel:Null<String>;
    public final run:() -> Void;

    public function new(label:String, commandId:String, keybindingLabel:Null<String>, run:() -> Void) {
        this.label = label;
        this.commandId = commandId;
        this.keybindingLabel = keybindingLabel;
        this.run = run;
    }

    /**
     * What the status bar shows: `label (keybinding)`, or the label alone.
     */
    public var text(get, never):String;
    function get_text():String {
        return keybindingLabel != null ? label + ' (' + keybindingLabel + ')' : label;
    }

}

/**
 * An item of the status bar: an action, or a text (null when hidden).
 */
enum HoverStatusBarItem {
    Action(action:HoverStatusBarAction);
    Text(entry:{text:Null<String>});
}

/**
 * The hover parts on screen (Monaco's `RenderedContentHover`): where the
 * hover shows, the highlight of the hovered range, the status bar.
 */
class RenderedContentHover implements IEditorHoverRenderContext {

    static var _decorationOptions:Null<ModelDecorationOptions> = null;

    public final showAtPosition:Position;
    public final showAtSecondaryPosition:Position;
    public final shouldFocus:Bool;
    public final source:HoverStartSource;
    public final hoverParts:Array<IHoverPart>;
    /**
     * The actions of the status bar (Monaco's `HoverAction`s): `label`,
     * `keybindingLabel` (the label of the primary keybinding of the command,
     * null without one) and `text`, what the status bar shows
     * (`View Problem (⌥F8)`).
     */
    public final statusBarActions:Array<HoverStatusBarAction> = [];
    public final statusBarTexts:Array<{text:Null<String>}> = [];
    /**
     * The actions and texts of the status bar, in the order they were added
     * (Monaco appends them to the status bar's `div.actions`).
     */
    public final statusBarItems:Array<HoverStatusBarItem> = [];
    /**
     * Monaco's `initialMousePosX`, `initialMousePosY` and
     * `closestMouseDistance` (`ContentHoverWidget.isMouseGettingCloser`).
     */
    public var initialMousePosX:Null<Float> = null;
    public var initialMousePosY:Null<Float> = null;
    public var closestMouseDistance:Null<Float> = null;
    /**
     * A background for the whole content of the hover when it has one part
     * row and no status bar, without the 2 pixels of padding at its bottom
     * (a host's style sheet can do this with `:has()`): set by a participant
     * while it renders a part that fills the hover, null for none.
     */
    public var contentsBackground:Null<glaze.Hsla> = null;

    final _editor:ICodeEditor;
    final _participants:Array<IEditorHoverParticipant>;
    final _wrapper:ContentHoverWidgetWrapper;
    final _highlight:IEditorDecorationsCollection;
    var _statusBarBounds:Null<Bounds> = null;

    public function new(editor:ICodeEditor, hoverResult:HoverResult, participants:Array<IEditorHoverParticipant>, computer:ContentHoverComputer, wrapper:ContentHoverWidgetWrapper) {
        this._editor = editor;
        this._participants = participants;
        this._wrapper = wrapper;
        final anchor = hoverResult.anchor;
        final parts = hoverResult.hoverParts;
        this.hoverParts = parts;
        final positions = computeHoverPositions(editor, anchor.range, parts);
        this.showAtPosition = positions.showAtPosition;
        this.showAtSecondaryPosition = positions.showAtSecondaryPosition;
        this.shouldFocus = computer.shouldFocus;
        this.source = computer.source;
        this.initialMousePosX = anchor.initialMousePosX;
        this.initialMousePosY = anchor.initialMousePosY;

        if (_decorationOptions == null) {
            _decorationOptions = ModelDecorationOptions.register({
                description: 'content-hover-highlight',
                className: 'hoverHighlight'
            });
        }
        this._highlight = editor.createDecorationsCollection();
        if (parts.length > 0) {
            var highlightRange = parts[0].range;
            for (hoverPart in parts) {
                highlightRange = Range.plusRangeStatic(highlightRange, hoverPart.range);
            }
            this._highlight.set([{range: highlightRange, options: cast _decorationOptions}]);
        }
    }

    public function dispose():Void {
        this._highlight.clear();
    }

    public static function computeHoverPositions(editor:ICodeEditor, anchorRange:Range, hoverParts:Array<IHoverPart>):{showAtPosition:Position, showAtSecondaryPosition:Position} {

        var startColumnBoundary = 1;
        final viewModel = editor._getViewModel();
        if (editor.hasModel() && viewModel != null) {
            // Ensure the range is on the current view line
            final coordinatesConverter = viewModel.coordinatesConverter;
            final anchorViewRange = coordinatesConverter.convertModelRangeToViewRange(anchorRange);
            final anchorViewMinColumn = viewModel.getLineMinColumn(anchorViewRange.startLineNumber);
            final anchorViewRangeStart = new Position(anchorViewRange.startLineNumber, anchorViewMinColumn);
            startColumnBoundary = coordinatesConverter.convertViewPositionToModelPosition(anchorViewRangeStart).column;
        }

        // The anchor range is always on a single line
        final anchorStartLineNumber = anchorRange.startLineNumber;
        var secondaryPositionColumn = anchorRange.startColumn;
        var forceShowAtRange:Null<Range> = null;

        for (hoverPart in hoverParts) {
            final hoverPartRange = hoverPart.range;
            final hoverPartRangeOnAnchorStartLine = hoverPartRange.startLineNumber == anchorStartLineNumber;
            final hoverPartRangeOnAnchorEndLine = hoverPartRange.endLineNumber == anchorStartLineNumber;
            final hoverPartRangeIsOnAnchorLine = hoverPartRangeOnAnchorStartLine && hoverPartRangeOnAnchorEndLine;
            if (hoverPartRangeIsOnAnchorLine) {
                // this message has a range that is completely sitting on the line of the anchor
                final hoverPartStartColumn = hoverPartRange.startColumn;
                final minSecondaryPositionColumn = Std.int(Math.min(secondaryPositionColumn, hoverPartStartColumn));
                secondaryPositionColumn = Std.int(Math.max(minSecondaryPositionColumn, startColumnBoundary));
            }
            if (hoverPart.forceShowAtRange) {
                forceShowAtRange = hoverPartRange;
            }
        }

        if (forceShowAtRange != null) {
            final forceShowAtPosition = forceShowAtRange.getStartPosition();
            return {showAtPosition: forceShowAtPosition, showAtSecondaryPosition: forceShowAtPosition};
        }
        return {
            showAtPosition: anchorRange.getStartPosition(),
            showAtSecondaryPosition: new Position(anchorStartLineNumber, secondaryPositionColumn),
        };
    }

    // IEditorHoverRenderContext

    /**
     * Monaco's `EditorHoverStatusBar.addAction`: the label of the primary
     * keybinding of the command follows the label in parentheses
     * (`HoverAction`).
     */
    public function addStatusBarAction(label:String, commandId:String, run:() -> Void):Void {
        if (ignoresStatusBar()) {
            return;
        }
        final keybinding = _editor.context.keybindingService.lookupKeybinding(commandId);
        final keybindingLabel = keybinding != null ? keybinding.getLabel() : null;
        final action = new HoverStatusBarAction(label, commandId, keybindingLabel, run);
        statusBarActions.push(action);
        statusBarItems.push(HoverStatusBarItem.Action(action));
    }

    public function addStatusBarText(text:String):(text:Null<String>) -> Void {
        if (ignoresStatusBar()) {
            return _ -> {};
        }
        final entry = {text: (text : Null<String>)};
        statusBarTexts.push(entry);
        statusBarItems.push(HoverStatusBarItem.Text(entry));
        return value -> {
            entry.text = value;
            onContentsChanged();
        };
    }

    public function hide():Void {
        _wrapper.hide();
    }

    public function onContentsChanged():Void {
        _wrapper._contentsChanged();
    }

    public function statusBarBounds():Null<Bounds> {
        return _statusBarBounds;
    }

    @:allow(cityscape.contrib.hover.view)
    function setStatusBarBounds(bounds:Bounds):Void {
        _statusBarBounds = bounds;
    }

    /**
     * The elements of the parts, participant by participant (Monaco renders
     * the parts of each participant in the order of the participants).
     */
    public function renderParts(window:Window, cx:App):Array<IntoElement> {
        final result:Array<IntoElement> = [];
        contentsBackground = null;
        _rendering = true;
        for (participant in _participants) {
            final parts = [for (p in hoverParts) if (p.owner == participant) p];
            if (parts.length == 0) {
                continue;
            }
            for (e in participant.renderHoverParts(this, parts, window, cx)) {
                result.push(e);
            }
        }
        _rendering = false;
        renderCount++;
        return result;
    }

    /**
     * How many times the parts were rendered. Monaco renders them once per
     * result; Glaze renders the hover's elements at every frame it shows
     * them, so the status bar is the one of the first render: what a
     * participant adds to it while the parts render again is ignored, what
     * it adds later (when the quick fixes of a marker arrive) is kept.
     */
    public var renderCount(default, null):Int = 0;
    var _rendering = false;

    inline function ignoresStatusBar():Bool {
        return _rendering && renderCount > 0;
    }
}

/**
 * The hover of an editor (Monaco's `ContentHoverWidgetWrapper`): runs the
 * hover operation for an anchor and shows its result.
 */
class ContentHoverWidgetWrapper extends Disposable {

    var _currentResult:Null<HoverResult> = null;
    var _renderedContentHover:Null<RenderedContentHover> = null;

    final _computer:ContentHoverComputer;
    final _participants:Array<IEditorHoverParticipant>;
    final _hoverOperation:HoverOperation<IHoverPart>;
    final _editor:ICodeEditor;
    final _widget:ContentHoverWidget;

    final _onContentsChanged = new Emitter<Any>();
    public final onContentsChanged:Event<Any>;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this.onContentsChanged = _onContentsChanged.event;
        this._register(_onContentsChanged);
        this._participants = this._initializeHoverParticipants();
        this._computer = new ContentHoverComputer(this._editor, this._participants);
        this._hoverOperation = this._register(new HoverOperation(this._editor, this._computer));
        this._widget = this._register(new ContentHoverWidget(editor, this));
        this._registerListeners();
    }

    function _initializeHoverParticipants():Array<IEditorHoverParticipant> {
        final participants:Array<IEditorHoverParticipant> = [];
        for (ctor in ContentHoverController.participantsOf(_editor.context)) {
            participants.push(ctor(this._editor));
        }
        haxe.ds.ArraySort.sort(participants, (p1, p2) -> p1.hoverOrdinal - p2.hoverOrdinal);
        return participants;
    }

    function _registerListeners():Void {
        this._register(this._hoverOperation.onResult(result -> {
            if (this._computer.anchor == null) {
                // invalid state, ignore result
                return;
            }
            final messages = (result.hasLoadingMessage ? this._addLoadingMessage(result.value) : result.value);
            this._withResult(new HoverResult(this._computer.anchor, messages, result.isComplete));
        }));
        this._register(this._editor.context.tokenizationRegistry.onDidChange(_ -> {
            if (this._widget.isVisible && this._currentResult != null) {
                this._widget.changed(); // render again
            }
        }));
    }

    /**
     * Returns true if the hover shows now or will show.
     */
    function _startShowingOrUpdateHover(anchor:Null<HoverAnchor>, mode:HoverStartMode, source:HoverStartSource, focus:Bool, mouseEvent:Null<IEditorMouseEvent>):Bool {
        final contentHoverIsVisible = this._widget.isVisible && this._currentResult != null;
        if (!contentHoverIsVisible) {
            if (anchor != null) {
                this._startHoverOperationIfNecessary(anchor, mode, source, focus, false);
                return true;
            }
            return false;
        }
        final isHoverSticky = this._editor.getOption(EditorOption.hover).sticky;
        final isMouseGettingCloser = mouseEvent != null && this._widget.isMouseGettingCloser(mouseEvent.event.posx, mouseEvent.event.posy);
        final isHoverStickyAndIsMouseGettingCloser = isHoverSticky && isMouseGettingCloser;
        // The mouse is getting closer to the hover, so we will keep the hover untouched
        // But we will kick off a hover update at the new anchor, insisting on keeping the hover visible.
        if (isHoverStickyAndIsMouseGettingCloser) {
            if (anchor != null) {
                this._startHoverOperationIfNecessary(anchor, mode, source, focus, true);
            }
            return true;
        }
        // If mouse is not getting closer and anchor not defined, hide the hover
        if (anchor == null) {
            this._setCurrentResult(null);
            return false;
        }
        // If mouse if not getting closer and anchor is defined, and the new anchor is the same as the previous anchor
        final currentAnchorEqualsPreviousAnchor = this._currentResult.anchor.equals(anchor);
        if (currentAnchorEqualsPreviousAnchor) {
            return true;
        }
        // If mouse if not getting closer and anchor is defined, and the new anchor is not compatible with the previous anchor
        final currentAnchorCompatibleWithPreviousAnchor = this._renderedContentHover != null && anchor.canAdoptVisibleHover(this._currentResult.anchor, this._renderedContentHover.showAtPosition);
        if (!currentAnchorCompatibleWithPreviousAnchor) {
            this._setCurrentResult(null);
            this._startHoverOperationIfNecessary(anchor, mode, source, focus, false);
            return true;
        }
        // We aren't getting any closer to the hover, so we will filter existing results
        // and keep those which also apply to the new anchor.
        this._setCurrentResult(this._currentResult.filter(anchor));
        this._startHoverOperationIfNecessary(anchor, mode, source, focus, false);
        return true;
    }

    function _startHoverOperationIfNecessary(anchor:HoverAnchor, mode:HoverStartMode, source:HoverStartSource, focus:Bool, insistOnKeepingHoverVisible:Bool):Void {
        final currentAnchorEqualToPreviousHover = this._computer.anchor != null && this._computer.anchor.equals(anchor);
        if (currentAnchorEqualToPreviousHover) {
            return;
        }
        this._hoverOperation.cancel();
        this._computer.anchor = anchor;
        this._computer.shouldFocus = focus;
        this._computer.source = source;
        this._computer.insistOnKeepingHoverVisible = insistOnKeepingHoverVisible;
        this._hoverOperation.start(mode);
    }

    function _setCurrentResult(hoverResult:Null<HoverResult>):Void {
        var currentHoverResult = hoverResult;
        final currentResultEqualToPreviousResult = this._currentResult == currentHoverResult;
        if (currentResultEqualToPreviousResult) {
            return;
        }
        final currentHoverResultIsEmpty = currentHoverResult != null && currentHoverResult.hoverParts.length == 0;
        if (currentHoverResultIsEmpty) {
            currentHoverResult = null;
        }
        this._currentResult = currentHoverResult;
        if (this._currentResult != null) {
            this._showHover(this._currentResult);
        }
        else {
            this._hideHover();
        }
    }

    function _addLoadingMessage(result:Array<IHoverPart>):Array<IHoverPart> {
        if (this._computer.anchor == null) {
            return result;
        }
        for (participant in this._participants) {
            final loadingMessage = participant.createLoadingMessage(this._computer.anchor);
            if (loadingMessage == null) {
                continue;
            }
            return result.concat([loadingMessage]);
        }
        return result;
    }

    function _withResult(hoverResult:HoverResult):Void {
        final previousHoverIsVisibleWithCompleteResult = this._widget.isVisible && this._currentResult != null && this._currentResult.isComplete;
        if (!previousHoverIsVisibleWithCompleteResult) {
            this._setCurrentResult(hoverResult);
        }
        // The hover is visible with a previous complete result.
        final isCurrentHoverResultComplete = hoverResult.isComplete;
        if (!isCurrentHoverResultComplete) {
            // Instead of rendering the new partial result, we wait for the result to be complete.
            return;
        }
        final currentHoverResultIsEmpty = hoverResult.hoverParts.length == 0;
        final insistOnKeepingPreviousHoverVisible = this._computer.insistOnKeepingHoverVisible;
        final shouldKeepPreviousHoverVisible = currentHoverResultIsEmpty && insistOnKeepingPreviousHoverVisible;
        if (shouldKeepPreviousHoverVisible) {
            // The hover would now hide normally, so we'll keep the previous messages
            return;
        }
        this._setCurrentResult(hoverResult);
    }

    function _showHover(hoverResult:HoverResult):Void {
        if (this._renderedContentHover != null) {
            this._renderedContentHover.dispose();
        }
        this._renderedContentHover = new RenderedContentHover(this._editor, hoverResult, this._participants, this._computer, this);
        if (hoverResult.hoverParts.length > 0) {
            this._widget.show(this._renderedContentHover);
        }
        else {
            this._renderedContentHover.dispose();
            this._renderedContentHover = null;
        }
    }

    function _hideHover():Void {
        if (this._renderedContentHover != null) {
            this._renderedContentHover.dispose();
            this._renderedContentHover = null;
        }
        this._widget.hide();
    }

    @:allow(cityscape.contrib.hover.view)
    function _contentsChanged():Void {
        this._onContentsChanged.fire(null);
        this._widget.changed();
    }

    public function showsOrWillShow(mouseEvent:IEditorMouseEvent):Bool {
        final anchorCandidates:Array<HoverAnchor> = this._findHoverAnchorCandidates(mouseEvent);
        final anchorCandidatesExist = anchorCandidates.length > 0;
        if (!anchorCandidatesExist) {
            return this._startShowingOrUpdateHover(null, HoverStartMode.Delayed, HoverStartSource.Mouse, false, mouseEvent);
        }
        final anchor = anchorCandidates[0];
        return this._startShowingOrUpdateHover(anchor, HoverStartMode.Delayed, HoverStartSource.Mouse, false, mouseEvent);
    }

    function _findHoverAnchorCandidates(mouseEvent:IEditorMouseEvent):Array<HoverAnchor> {
        final anchorCandidates:Array<HoverAnchor> = [];
        for (participant in this._participants) {
            final anchor = participant.suggestHoverAnchor(mouseEvent);
            if (anchor == null) {
                continue;
            }
            anchorCandidates.push(anchor);
        }
        final target = mouseEvent.target;
        switch (target.type) {
            case MouseTargetType.CONTENT_TEXT:
                anchorCandidates.push(HoverAnchor.rangeAnchor(0, target.range, mouseEvent.event.posx, mouseEvent.event.posy));
            case MouseTargetType.CONTENT_EMPTY:
                final epsilon = this._editor.getOption(EditorOption.fontInfo).typicalHalfwidthCharacterWidth / 2;
                // Let hover kick in even when the mouse is technically in the empty area after a line, given the distance is small enough
                final mouseIsWithinLinesAndCloseToHover = !target.isAfterLines
                    && target.horizontalDistanceToText < epsilon;
                if (mouseIsWithinLinesAndCloseToHover && target.range != null) {
                    anchorCandidates.push(HoverAnchor.rangeAnchor(0, target.range, mouseEvent.event.posx, mouseEvent.event.posy));
                }
            case _:
        }
        haxe.ds.ArraySort.sort(anchorCandidates, (a, b) -> b.priority > a.priority ? 1 : (b.priority < a.priority ? -1 : 0));
        return anchorCandidates;
    }

    public function startShowingAtRange(range:Range, mode:HoverStartMode, source:HoverStartSource, focus:Bool):Void {
        this._startShowingOrUpdateHover(HoverAnchor.rangeAnchor(0, range, null, null), mode, source, focus, null);
    }

    public function hide():Void {
        this._computer.anchor = null;
        this._hoverOperation.cancel();
        this._setCurrentResult(null);
    }

    public var isVisible(get, never):Bool;
    function get_isVisible():Bool {
        return this._widget.isVisible;
    }

    public var isMouseOver(get, never):Bool;
    function get_isMouseOver():Bool {
        return this._widget.isMouseOver;
    }

    public var isVisibleFromKeyboard(get, never):Bool;
    function get_isVisibleFromKeyboard():Bool {
        return this._widget.isVisibleFromKeyboard;
    }

    /**
     * The hover on screen (tests).
     */
    public function getWidget():ContentHoverWidget {
        return this._widget;
    }

    /**
     * Whether a window point is over the hover.
     */
    public function containsPoint(x:Float, y:Float):Bool {
        return this._widget.containsPoint(x, y);
    }

    /**
     * What the hover shows (tests).
     */
    public function getRenderedHover():Null<RenderedContentHover> {
        return this._renderedContentHover;
    }

    /**
     * Runs the pending waits of the hover operation (tests).
     * @internal
     */
    public function _flushOperation():Void {
        this._hoverOperation._flush();
    }

    public function getWidgetContent():Null<String> {
        final rendered = this._renderedContentHover;
        if (rendered == null) {
            return null;
        }
        final texts = [for (part in rendered.hoverParts) part.owner.getAccessibleContent(part)];
        return texts.join('\n');
    }

}

/**
 * The hover on screen (Monaco's `ContentHoverWidget`, its DOM replaced by
 * the Glaze view `ContentHoverView`): its state (shown, mouse over, bounds,
 * side, `isMouseGettingCloser`) for the controller.
 */
class ContentHoverWidget implements IOverlayWidget implements IDisposable {

    public static inline final ID = 'editor.contrib.resizableContentHoverWidget';

    final _editor:ICodeEditor;
    final _wrapper:ContentHoverWidgetWrapper;
    var _rendered:Null<RenderedContentHover> = null;
    var _view:Null<Entity<ContentHoverView>> = null;
    var _app:Null<App> = null;

    /** The window bounds of the hover, from its last layout. */
    public var bounds(default, null):Null<Bounds> = null;
    /** Whether the mouse is over the hover. */
    public var isMouseOver(default, null):Bool = false;
    var _mouseOverStop:Null<() -> Void> = null;

    public function new(editor:ICodeEditor, wrapper:ContentHoverWidgetWrapper) {
        this._editor = editor;
        this._wrapper = wrapper;
        editor.addOverlayWidget(this);
    }

    public function dispose():Void {
        _editor.removeOverlayWidget(this);
        cityscape.view.ViewEntities.release(_view);
        _view = null;
    }

    public var isVisible(get, never):Bool;
    function get_isVisible():Bool {
        return _rendered != null;
    }

    public function getRendered():Null<RenderedContentHover> {
        return _rendered;
    }

    public function show(rendered:RenderedContentHover):Void {
        _rendered = rendered;
        bounds = null;
        _contentEnd = null;
        positionPreference = null;
        changed();
    }

    public function hide():Void {
        if (_rendered == null) {
            return;
        }
        _rendered = null;
        bounds = null;
        positionPreference = null;
        isMouseOver = false;
        changed();
    }

    public function changed():Void {
        final v = _view;
        final app = _app;
        if (v != null && app != null) {
            app.notify(v.entityId());
        }
        else {
            _editor.layoutOverlayWidget(this);
        }
    }

    @:allow(cityscape.contrib.hover.view)
    function setBounds(b:Bounds):Void {
        bounds = b;
    }

    var _contentEnd:Null<Float> = null;

    @:allow(cityscape.contrib.hover.view)
    function setContentEnd(y:Float):Void {
        _contentEnd = y;
    }

    /**
     * The height of the content of the hover, all of it, scrolled or not
     * (Monaco's `scrollbar.getScrollDimensions().scrollHeight`), from its
     * last layout while not scrolled; null before.
     */
    public var scrollHeight(get, never):Null<Float>;
    function get_scrollHeight():Null<Float> {
        final b = bounds;
        if (b == null || _contentEnd == null) {
            return null;
        }
        // inside the 1 pixel border, with the 2 pixels at the bottom
        return _contentEnd - (b.origin.y + 1) + 2;
    }

    /**
     * The side the hover took at its last layout (Monaco's
     * `_positionPreference`), null before.
     */
    public var positionPreference(default, null):Null<ContentWidgetPositionPreference> = null;

    @:allow(cityscape.contrib.hover.view)
    function setPositionPreference(preference:ContentWidgetPositionPreference):Void {
        positionPreference = preference;
    }

    @:allow(cityscape.contrib.hover.view)
    function setMouseOver(over:Bool):Void {
        isMouseOver = over;
        if (!over) {
            // the mouse left the hover: hide it unless it went back to the editor
            if (_mouseOverStop != null) {
                _mouseOverStop();
            }
            _mouseOverStop = Async.setTimeout(() -> {
                _mouseOverStop = null;
                if (!isMouseOver && !ContentHoverController.mouseIsInEditor(_editor)) {
                    _wrapper.hide();
                }
            }, 50);
        }
    }

    public function containsPoint(x:Float, y:Float):Bool {
        final b = bounds;
        return b != null && x >= b.origin.x && x <= b.origin.x + b.size.width && y >= b.origin.y && y <= b.origin.y + b.size.height;
    }

    /**
     * Monaco's `isMouseGettingCloser`: whether the mouse is not getting
     * farther from the hover than the closest it came (4 pixels of
     * tolerance), its first position recorded on the rendered hover.
     */
    public function isMouseGettingCloser(posx:Float, posy:Float):Bool {
        final rendered = _rendered;
        if (rendered == null) {
            return false;
        }
        if (rendered.initialMousePosX == null || rendered.initialMousePosY == null) {
            rendered.initialMousePosX = posx;
            rendered.initialMousePosY = posy;
            return false;
        }
        final b = bounds;
        if (b == null) {
            return false;
        }
        if (rendered.closestMouseDistance == null) {
            rendered.closestMouseDistance = computeDistanceFromPointToRectangle(rendered.initialMousePosX, rendered.initialMousePosY, b.origin.x, b.origin.y, b.size.width, b.size.height);
        }
        final distance = computeDistanceFromPointToRectangle(posx, posy, b.origin.x, b.origin.y, b.size.width, b.size.height);
        if (distance > rendered.closestMouseDistance + 4 /* tolerance of 4 pixels */) {
            // The mouse is getting farther away
            return false;
        }
        rendered.closestMouseDistance = Math.min(rendered.closestMouseDistance, distance);
        return true;
    }

    public static function computeDistanceFromPointToRectangle(pointX:Float, pointY:Float, left:Float, top:Float, width:Float, height:Float):Float {
        final x = (left + width / 2); // x center of rectangle
        final y = (top + height / 2); // y center of rectangle
        final dx = Math.max(Math.abs(pointX - x) - width / 2, 0);
        final dy = Math.max(Math.abs(pointY - y) - height / 2, 0);
        return Math.sqrt(dx * dx + dy * dy);
    }

    /**
     * Whether the hover was shown from the keyboard (Monaco's
     * `isVisibleFromKeyboard`).
     */
    public var isVisibleFromKeyboard(get, never):Bool;
    function get_isVisibleFromKeyboard():Bool {
        return _rendered != null && _rendered.source == HoverStartSource.Keyboard;
    }

    public function getId():String {
        return ID;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        var v = _view;
        if (v == null) {
            _app = cx;
            v = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:Context<ContentHoverView>) -> new ContentHoverView(this, _editor)), cx);
            _view = v;
        }
        return v;
    }

}

/**
 * The Glaze view of the hover (Monaco's `ContentHoverWidget` and its
 * `HoverWidget`, styled by hover.css and hoverWidget.css): the parts one
 * under the other (`hover-row`s, a line of `editorHoverWidget.border` at 50%
 * between two), then the status bar (12 pixels, 22 high, its actions in
 * `textLink.foreground` 16 pixels apart on `editorHoverWidget.statusBarBackground`).
 * The text is at the editor's font size and line height. The hover is as
 * wide as its content up to `max(0.66 × the editor's width, 500)` and as
 * high up to `max(the editor's height / 4, 250)` (`_updateMaxDimensions`),
 * scrolling with a scrollbar beyond, and placed by
 * `ContentWidgetPositioner` (above the line by default, `hover.above`).
 */
class ContentHoverView extends Model implements Render {

    /** The minimum of the maximum width and height (`_updateMaxDimensions`). */
    public static inline final MAX_WIDTH = 500;
    public static inline final MAX_HEIGHT = 250;

    /** hoverWidget.css `.hover-row.status-bar` */
    public static inline final STATUS_BAR_FONT_SIZE = 12;
    public static inline final STATUS_BAR_LINE_HEIGHT = 22;

    final widget:ContentHoverWidget;
    final editor:ICodeEditor;

    public function new(widget:ContentHoverWidget, editor:ICodeEditor) {
        super();
        this.widget = widget;
        this.editor = editor;
    }

    /**
     * `_updateMaxDimensions` (the hover is never resized by hand here, so
     * `_lastDimensions` stays at zero).
     */
    public static function maxDimensions(editor:ICodeEditor):{width:Float, height:Float} {
        final layoutInfo = editor.getOption(EditorOption.layoutInfo);
        return {
            width: Math.max(layoutInfo.width * 0.66, MAX_WIDTH),
            height: Math.max(layoutInfo.height / 4, MAX_HEIGHT)
        };
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final rendered = widget.getRendered();
        if (rendered == null || !editor.hasModel()) {
            return new Empty();
        }
        final primaryPosition = rendered.showAtPosition;
        final secondaryPosition = rendered.showAtSecondaryPosition;
        final primary = EditorWidgets.positionBounds(editor, primaryPosition);
        final editorBounds = EditorWidgets.editorBounds(editor);
        if (primary == null || editorBounds == null || !EditorWidgets.isPositionVisible(editor, primaryPosition)) {
            return new Empty();
        }
        final secondary = secondaryPosition.lineNumber == primaryPosition.lineNumber ? EditorWidgets.positionBounds(editor, secondaryPosition) : null;
        final app:App = cx.app;
        final theme = Theme.global(cx);
        final background = EditorWidgets.color(editor, 'editorHoverWidget.background', EditorWidgets.color(editor, 'editorWidget.background', theme.popover));
        final foreground = EditorWidgets.color(editor, 'editorHoverWidget.foreground', EditorWidgets.color(editor, 'editor.foreground', theme.popoverForeground));
        final border = EditorWidgets.color(editor, 'editorHoverWidget.border', EditorWidgets.color(editor, 'editorWidget.border', theme.border));
        final statusBarBackground = EditorWidgets.color(editor, 'editorHoverWidget.statusBarBackground', background);
        final link = EditorWidgets.color(editor, 'textLink.foreground', theme.link);
        final fontInfo = editor.getOption(EditorOption.fontInfo);
        final max = maxDimensions(editor);
        // `overflowWidgetsBounds: 'editor'`: no larger than the room in the editor
        final page = EditorWidgets.overflowPage(editor);
        if (page != null) {
            max.width = Math.min(max.width, Math.max(0, page.size.width - ContentWidgetPositioner.LEFT_PADDING - ContentWidgetPositioner.RIGHT_PADDING));
            max.height = Math.min(max.height, ContentWidgetPositioner.maxHeightInPage(primary, page));
        }

        final parts = rendered.renderParts(window, app);
        // `.monaco-hover-content`: 2 pixels of padding on the right and at
        // the bottom, the font size and line height of the editor
        final content = div()
            .id('cityscape-hover-content')
            .flex()
            .flexCol()
            .pr(px(2))
            .pb(px(2))
            .textSize(px(fontInfo.fontSize))
            .lineHeight(px(fontInfo.lineHeight));
        var rows = 0;
        for (part in parts) {
            // `.hover-row` (flex) around `.hover-row-contents` (a column)
            final row = div().flex().flexCol().minW0().child(part);
            if (rows > 0) {
                // `.hover-row:not(:first-child):not(:empty)`
                row.borderT1().borderColor(border.opacity(0.5));
            }
            content.child(row);
            rows++;
        }

        final items = rendered.statusBarItems;
        var hasStatusBar = false;
        for (item in items) {
            switch item {
                case Action(_): hasStatusBar = true;
                case Text(entry): if (entry.text != null) hasStatusBar = true;
            }
        }
        if (hasStatusBar) {
            final actions = div()
                .flex()
                .flexRow()
                .wFull()
                .px(px(8))
                .bg(statusBarBackground);
            for (item in items) {
                switch item {
                    case Action(action):
                        final run = action.run;
                        // `.action-container`: 16 pixels on the right, on one
                        // line (the [loreline] patch of hoverWidget.css)
                        actions.child(div()
                            .id('cityscape-hover-action-' + action.commandId)
                            .flexNone()
                            .whitespaceNowrap()
                            .mr(px(16))
                            .cursorPointer()
                            .textColor(link)
                            .onMouseDown(MouseButton.Left, (_, _, cx) -> {
                                cx.stopPropagation();
                                run();
                            })
                            .child(action.text));
                    case Text(entry):
                        if (entry.text != null) {
                            // an empty placeholder keeps its line (Monaco's &nbsp;)
                            final text = StringTools.trim(entry.text).length == 0 ? '\u00A0' : entry.text;
                            actions.child(div().flexNone().whitespaceNowrap().child(text));
                        }
                }
            }
            final statusBar = div()
                .id('cityscape-hover-status')
                .flex()
                .flexRow()
                .textSize(px(STATUS_BAR_FONT_SIZE))
                .lineHeight(px(STATUS_BAR_LINE_HEIGHT))
                .child(actions);
            if (rows > 0) {
                statusBar.borderT1().borderColor(border.opacity(0.5));
            }
            content.child(statusBar);
        }

        // the end of the content (the height of what scrolls, read by
        // `ContentHoverWidget.scrollHeight`)
        content.child(canvas((b, _, _) -> {
            widget.setContentEnd(b.origin.y);
            return null;
        }, (_, _, _, _) -> {}));

        if (rendered.contentsBackground != null && rows == 1 && !hasStatusBar) {
            // a single row filling the hover: its background under the
            // padding of the content, without the padding at the bottom
            content.bg(rendered.contentsBackground).pb(px(0));
        }

        // the content scrolls beyond the maximum height (Monaco's
        // `DomScrollableElement`), inside the 1 pixel border
        final scrollable = ScrollableElement.overflowYScrollbar(content.maxH(px(max.height - 2))).id('cityscape-hover-scroll');

        final surface = div()
            .id('cityscape-hover')
            .flex()
            .flexCol()
            .maxW(px(max.width))
            .maxH(px(max.height))
            .bg(background)
            .textColor(foreground)
            .border1()
            .borderColor(border)
            .rounded(px(3))
            .overflowHidden()
            .onHover(hovered -> widget.setMouseOver(hovered))
            .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation())
            .child(scrollable);
        final chrome = editor.context.hoverChrome;
        if (chrome != null) {
            chrome(surface);
        }

        final above = editor.getOption(EditorOption.hover).above;
        final positioner = new ContentWidgetPositioner({
            primary: primary,
            secondary: secondary,
            editor: editorBounds,
            typicalFullwidthCharacterWidth: fontInfo.typicalFullwidthCharacterWidth,
            page: page
        }, above)
            .onPlacement(placement -> {
                final b = placement.bounds;
                widget.setBounds(b);
                widget.setPositionPreference(placement.preference);
                // the status bar sits at the bottom of the hover, above the
                // padding of the content and the border
                final statusTop = b.origin.y + b.size.height - 1 - 2 - STATUS_BAR_LINE_HEIGHT;
                rendered.setStatusBarBounds(new Bounds(new glaze.Point(b.origin.x, statusTop), new glaze.Size(b.size.width, STATUS_BAR_LINE_HEIGHT)));
            })
            .child(surface);
        return deferred(positioner).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY).intoAnyElement();
    }

}

/**
 * The hover contribution of an editor (Monaco's `ContentHoverController`
 * of contentHoverController2.ts): shows the hover after the hover delay
 * when the mouse rests on the text, hides it when the mouse leaves, a key
 * is pressed or the editor scrolls. The color picker of the hover is not
 * ported.
 */
class ContentHoverController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.contentHover';

    public static function get(editor:ICodeEditor):Null<ContentHoverController> {
        return editor.getContribution(ContentHoverController.ID);
    }

    /**
     * The participants of the hover of a context (Monaco's
     * `HoverParticipantRegistry`, `Cityscape.hoverParticipants`): the
     * markdown and marker participants, and those added with
     * `registerParticipant`.
     */
    public static function participantsOf(context:Cityscape):Array<(editor:ICodeEditor) -> IEditorHoverParticipant> {
        return context.hoverParticipants;
    }

    /**
     * Adds a participant to the hover of the editors of a context created
     * after this call (Monaco's `HoverParticipantRegistry.register`).
     */
    public static function registerParticipant(context:Cityscape, ctor:(editor:ICodeEditor) -> IEditorHoverParticipant):Void {
        context.hoverParticipants.push(ctor);
    }

    /**
     * Whether the mouse is over the editor (its last mouse move).
     */
    public static function mouseIsInEditor(editor:ICodeEditor):Bool {
        final controller = get(editor);
        return controller != null && controller._mouseInEditor;
    }

    public var shouldKeepOpenOnEditorMouseMoveOrLeave:Bool = false;

    final _listenersStore = new DisposableStore();
    var _contentWidget:Null<ContentHoverWidgetWrapper> = null;
    var _mouseMoveEvent:Null<IEditorMouseEvent> = null;
    final _reactToEditorMouseMoveRunner:RunOnceScheduler;
    var _hoverSettings:{enabled:Bool, sticky:Bool, hidingDelay:Int};
    var _mouseDown = false;
    var _mouseInEditor = false;
    var _leaveTimer:Null<() -> Void> = null;

    final _editor:ICodeEditor;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._reactToEditorMouseMoveRunner = this._register(new RunOnceScheduler(() -> this._reactToEditorMouseMove(this._mouseMoveEvent), 0));
        this._hookListeners();
        this._register(this._editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.hover)) {
                this._unhookListeners();
                this._hookListeners();
            }
        }));
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    function _hookListeners():Void {

        final hoverOpts = this._editor.getOption(EditorOption.hover);
        this._hoverSettings = {
            enabled: hoverOpts.enabled,
            sticky: hoverOpts.sticky,
            hidingDelay: hoverOpts.hidingDelay
        };

        if (hoverOpts.enabled) {
            this._listenersStore.add(this._editor.onMouseDown(e -> this._onEditorMouseDown(e)));
            this._listenersStore.add(this._editor.onMouseUp(_ -> this._onEditorMouseUp()));
        }
        this._listenersStore.add(this._editor.onMouseMove(e -> this._onEditorMouseMove(e)));
        this._listenersStore.add(this._editor.onKeyDown(e -> this._onKeyDown(e)));

        this._listenersStore.add(this._editor.onMouseLeave(e -> this._onEditorMouseLeave(e)));
        this._listenersStore.add(this._editor.onDidChangeModel(_ -> {
            this._cancelScheduler();
            this._hideWidgets();
        }));
        this._listenersStore.add(this._editor.onDidChangeModelContent(_ -> this._cancelScheduler()));
        this._listenersStore.add(this._editor.onDidScrollChange(e -> this._onEditorScrollChanged(e)));
    }

    function _unhookListeners():Void {
        this._listenersStore.clear();
    }

    function _cancelScheduler():Void {
        this._mouseMoveEvent = null;
        this._reactToEditorMouseMoveRunner.cancel();
    }

    function _onEditorScrollChanged(e:cityscape.common.EditorCommon.IScrollEvent):Void {
        if (e.scrollTopChanged || e.scrollLeftChanged) {
            this._hideWidgets();
        }
    }

    function _onEditorMouseDown(mouseEvent:IEditorMouseEvent):Void {
        this._mouseDown = true;

        if (this._isMouseOnContentHoverWidget(mouseEvent.event.posx, mouseEvent.event.posy)) {
            return;
        }

        this._hideWidgets();
    }

    function _isMouseOnContentHoverWidget(x:Float, y:Float):Bool {
        return this._contentWidget != null && (this._contentWidget.isMouseOver || this._contentWidget.containsPoint(x, y));
    }

    function _onEditorMouseUp():Void {
        this._mouseDown = false;
    }

    function _onEditorMouseLeave(mouseEvent:IPartialEditorMouseEvent):Void {
        _mouseInEditor = false;
        if (this.shouldKeepOpenOnEditorMouseMoveOrLeave) {
            return;
        }

        this._cancelScheduler();

        // Monaco tests whether the mouse left the editor over the hover; the
        // hover is drawn above the editor here, so the mouse leaves the
        // editor when it enters the hover: wait a moment to know where it went
        if (_leaveTimer != null) {
            _leaveTimer();
        }
        _leaveTimer = Async.setTimeout(() -> {
            _leaveTimer = null;
            if (_mouseInEditor || (this._contentWidget != null && this._contentWidget.isMouseOver)) {
                return;
            }
            this._hideWidgets();
        }, 50);
    }

    function _shouldNotRecomputeCurrentHoverWidget(mouseEvent:IEditorMouseEvent):Bool {
        final isHoverSticky = this._hoverSettings.sticky;
        final isMouseOnContentHoverWidget = this._isMouseOnContentHoverWidget(mouseEvent.event.posx, mouseEvent.event.posy);
        return isHoverSticky && isMouseOnContentHoverWidget;
    }

    function _onEditorMouseMove(mouseEvent:IEditorMouseEvent):Void {
        _mouseInEditor = true;
        if (this.shouldKeepOpenOnEditorMouseMoveOrLeave) {
            return;
        }

        this._mouseMoveEvent = mouseEvent;
        final sticky = this._hoverSettings.sticky;
        if (sticky && this._contentWidget != null && this._contentWidget.isVisibleFromKeyboard) {
            // Sticky mode is on and the hover has been shown via keyboard
            // so moving the mouse has no effect
            return;
        }

        final shouldNotRecomputeCurrentHoverWidget = this._shouldNotRecomputeCurrentHoverWidget(mouseEvent);
        if (shouldNotRecomputeCurrentHoverWidget) {
            this._reactToEditorMouseMoveRunner.cancel();
            return;
        }

        final hidingDelay = this._hoverSettings.hidingDelay;
        final isContentHoverWidgetVisible = this._contentWidget != null && this._contentWidget.isVisible;
        // If the mouse is not over the widget, and if sticky is on,
        // then give it a grace period before reacting to the mouse event
        final shouldRescheduleHoverComputation = isContentHoverWidgetVisible && sticky && hidingDelay > 0;

        if (shouldRescheduleHoverComputation) {
            if (!this._reactToEditorMouseMoveRunner.isScheduled()) {
                this._reactToEditorMouseMoveRunner.schedule(hidingDelay);
            }
            return;
        }
        this._reactToEditorMouseMove(mouseEvent);
    }

    function _reactToEditorMouseMove(mouseEvent:Null<IEditorMouseEvent>):Void {

        if (mouseEvent == null) {
            return;
        }

        final enabled = this._hoverSettings.enabled;
        if (!enabled) {
            this._hideWidgets();
            return;
        }

        final contentHoverShowsOrWillShow = this._tryShowHoverWidget(mouseEvent);
        if (contentHoverShowsOrWillShow) {
            return;
        }

        this._hideWidgets();
    }

    function _tryShowHoverWidget(mouseEvent:IEditorMouseEvent):Bool {
        final contentWidget = this._getOrCreateContentWidget();
        return contentWidget.showsOrWillShow(mouseEvent);
    }

    function _onKeyDown(e:IKeyboardEvent):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        final resolvedKeyboardEvent = this._editor.context.keybindingService.softDispatch(e, this._editor.contextKeyService);

        // If the beginning of a multi-chord keybinding is pressed,
        // or the command aims to focus the hover,
        // set the variable to true, otherwise false
        final shouldKeepHoverVisible = (
            resolvedKeyboardEvent.kind == ResultKind.MoreChordsNeeded ||
            (resolvedKeyboardEvent.kind == ResultKind.KbFound
                && resolvedKeyboardEvent.commandId == ShowOrFocusHoverAction.ID
                && this._contentWidget != null && this._contentWidget.isVisible
            )
        );

        if (
            e.keyCode == KeyCode.Ctrl
            || e.keyCode == KeyCode.Alt
            || e.keyCode == KeyCode.Meta
            || e.keyCode == KeyCode.Shift
            || shouldKeepHoverVisible
        ) {
            // Do not hide hover when a modifier key is pressed
            return;
        }

        this._hideWidgets();
    }

    function _hideWidgets():Void {
        if (this._contentWidget != null) {
            this._contentWidget.hide();
        }
    }

    function _getOrCreateContentWidget():ContentHoverWidgetWrapper {
        if (this._contentWidget == null) {
            this._contentWidget = new ContentHoverWidgetWrapper(this._editor);
        }
        return this._contentWidget;
    }

    /**
     * The hover (tests).
     */
    public function getContentWidget():ContentHoverWidgetWrapper {
        return _getOrCreateContentWidget();
    }

    public function hideContentHover():Void {
        this._hideWidgets();
    }

    public function showContentHover(range:Range, mode:HoverStartMode, source:HoverStartSource, focus:Bool):Void {
        this._getOrCreateContentWidget().startShowingAtRange(range, mode, source, focus);
    }

    public function getWidgetContent():Null<String> {
        return this._contentWidget != null ? this._contentWidget.getWidgetContent() : null;
    }

    public var isHoverVisible(get, never):Bool;
    function get_isHoverVisible():Bool {
        return this._contentWidget != null && this._contentWidget.isVisible;
    }

    override public function dispose():Void {
        super.dispose();
        this._unhookListeners();
        this._listenersStore.dispose();
        if (this._contentWidget != null) {
            this._contentWidget.dispose();
        }
        if (_leaveTimer != null) {
            _leaveTimer();
        }
    }

}

/**
 * `editor.action.showHover` (Cmd+K Cmd+I): shows the hover at the cursor
 * (Monaco's `ShowOrFocusHoverAction`; focusing the hover is not ported).
 */
class ShowOrFocusHoverAction extends EditorAction {

    public static inline final ID = 'editor.action.showHover';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('showOrFocusHover', "Show or Focus Hover"),
            alias: 'Show or Focus Hover',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyI),
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }
        final controller = ContentHoverController.get(editor);
        if (controller == null) {
            return;
        }
        final position = editor.getPosition();
        final range = new Range(position.lineNumber, position.column, position.lineNumber, position.column);
        controller.showContentHover(range, HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
    }

}

/**
 * The registration of hoverContribution.ts (its module level code).
 */
class HoverRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        if (r.context.decorationStyles.get('hoverHighlight') == null) {
            // hover.css: the hovered range
            r.context.registerDecorationStyle('hoverHighlight', {
                background: {id: 'editor.hoverHighlightBackground'}
            });
        }
        r.registerEditorContribution(ContentHoverController.ID, editor -> new ContentHoverController(editor), EditorContributionInstantiation.BeforeFirstInteraction);
        r.registerEditorAction(new ShowOrFocusHoverAction(r));
    }

}
