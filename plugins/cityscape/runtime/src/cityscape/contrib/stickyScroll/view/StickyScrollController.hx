// Ported from vscode src/vs/editor/contrib/stickyScroll/browser/stickyScrollController.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.stickyScroll.view;

import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon;
import cityscape.common.EditorContextKeys;
import cityscape.common.TextModelEvents.IModelTokensChangedEvent;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.folding.view.Folding.FoldingController;
import cityscape.contrib.folding.view.FoldingModel;
import cityscape.contrib.stickyScroll.view.StickyScrollElement;
import cityscape.contrib.stickyScroll.view.StickyScrollProvider;
import cityscape.contrib.stickyScroll.view.StickyScrollWidget;
import cityscape.platform.contextkey.common.ContextKey.IContextKey;
import cityscape.view.EditorBrowser.ICodeEditor;
import glaze.MouseButton;

/*
 * Differences with Monaco:
 * - The widget is painted by Glaze and its mouse events come from
 *   `StickyScrollWidget` (hit tests instead of DOM attributes). A click
 *   reveals the line (or, with Shift, the end of its scope); a click on the
 *   folding icon folds or unfolds; the hover background follows the mouse.
 * - Not ported: the definition link gesture (Cmd+hover underlines a symbol
 *   of a sticky line and Cmd+click goes to its definition: it needs the
 *   definition providers), the context menu of the widget
 *   (`MenuId.StickyScrollContext`), the DOM focus tracking (the keyboard
 *   focus of the widget is the `stickyScrollFocused` context key and the
 *   highlighted line).
 * - `_renderStickyScroll` and `_updateState` wait for the folding model
 *   through a callback instead of a promise.
 */

interface IStickyScrollController {
    var stickyScrollCandidateProvider(get, never):IStickyLineCandidateProvider;
    var stickyScrollWidgetState(get, never):StickyScrollWidgetState;
    function focus():Void;
    function focusNext():Void;
    function focusPrevious():Void;
    function goToFocused():Void;
    function findScrollWidgetState():StickyScrollWidgetState;
    function dispose():Void;
    function selectEditor():Void;
}

class StickyScrollController extends Disposable implements IEditorContribution implements IStickyScrollController {

    public static inline final ID = 'store.contrib.stickyScrollController';

    final _editor:ICodeEditor;
    final _stickyScrollWidget:StickyScrollWidget;
    final _stickyLineCandidateProvider:IStickyLineCandidateProvider;
    final _sessionStore:DisposableStore = new DisposableStore();

    var _widgetState:StickyScrollWidgetState;
    var _foldingModel:Null<FoldingModel> = null;
    var _maxStickyLines:Int = 0x7FFFFFFF;

    var _stickyScrollFocusedContextKey:IContextKey<Bool>;
    var _stickyScrollVisibleContextKey:IContextKey<Bool>;

    var _focusDisposableStore:Null<DisposableStore> = null;
    var _focusedStickyElementIndex:Int = -1;
    var _enabled:Bool = false;
    var _focused:Bool = false;
    var _positionRevealed:Bool = false;
    var _onMouseDown:Bool = false;
    var _endLineNumbers:Array<Int> = [];
    var _showEndForLine:Null<Int> = null;
    var _minRebuildFromLine:Null<Int> = null;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._stickyScrollWidget = new StickyScrollWidget(this._editor);
        this._stickyLineCandidateProvider = new StickyLineCandidateProvider(this._editor, editor.context.languageFeaturesService, editor.context.languageConfigurationService);
        this._register(this._stickyScrollWidget);
        this._register(this._stickyLineCandidateProvider);

        this._widgetState = StickyScrollWidgetState.Empty;
        this._onDidResize();
        this._stickyScrollFocusedContextKey = EditorContextKeys.stickyScrollFocused.bindTo(editor.contextKeyService);
        this._stickyScrollVisibleContextKey = EditorContextKeys.stickyScrollVisible.bindTo(editor.contextKeyService);
        this._readConfiguration();
        this._register(this._editor.onDidChangeConfiguration(e -> {
            this._readConfigurationChange(e);
        }));
        this._register(this._editor.onDidBlurEditorWidget(() -> {
            if (this._focused) {
                this._disposeFocusStickyScrollStore();
            }
        }));
        this._registerMouseListeners();
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public var stickyScrollCandidateProvider(get, never):IStickyLineCandidateProvider;
    function get_stickyScrollCandidateProvider():IStickyLineCandidateProvider {
        return this._stickyLineCandidateProvider;
    }

    public var stickyScrollWidgetState(get, never):StickyScrollWidgetState;
    function get_stickyScrollWidgetState():StickyScrollWidgetState {
        return this._widgetState;
    }

    /**
     * The widget (the Glaze view paints it as an overlay widget).
     */
    public var stickyScrollWidget(get, never):StickyScrollWidget;
    inline function get_stickyScrollWidget():StickyScrollWidget {
        return this._stickyScrollWidget;
    }

    public static function get(editor:ICodeEditor):Null<StickyScrollController> {
        return editor.getContribution(ID);
    }

    function _disposeFocusStickyScrollStore():Void {
        this._stickyScrollFocusedContextKey.set(false);
        if (this._focusDisposableStore != null) {
            this._focusDisposableStore.dispose();
        }
        this._focused = false;
        this._positionRevealed = false;
        this._onMouseDown = false;
        this._stickyScrollWidget.clearFocusedLine();
    }

    public function focus():Void {
        // If the mouse is down, do not focus on the sticky scroll
        if (this._onMouseDown) {
            this._onMouseDown = false;
            this._editor.focus();
            return;
        }
        final focusState = this._stickyScrollFocusedContextKey.get();
        if (focusState == true) {
            return;
        }
        this._focused = true;
        this._focusDisposableStore = new DisposableStore();
        this._stickyScrollFocusedContextKey.set(true);
        this._focusedStickyElementIndex = this._stickyScrollWidget.lineNumbers.length - 1;
        this._stickyScrollWidget.focusLineWithIndex(this._focusedStickyElementIndex);
    }

    public function focusNext():Void {
        if (this._focusedStickyElementIndex < this._stickyScrollWidget.lineNumberCount - 1) {
            this._focusNav(true);
        }
    }

    public function focusPrevious():Void {
        if (this._focusedStickyElementIndex > 0) {
            this._focusNav(false);
        }
    }

    public function selectEditor():Void {
        this._disposeFocusStickyScrollStore();
        this._editor.focus();
    }

    // True is next, false is previous
    function _focusNav(direction:Bool):Void {
        this._focusedStickyElementIndex = direction ? this._focusedStickyElementIndex + 1 : this._focusedStickyElementIndex - 1;
        this._stickyScrollWidget.focusLineWithIndex(this._focusedStickyElementIndex);
    }

    public function goToFocused():Void {
        final lineNumbers = this._stickyScrollWidget.lineNumbers;
        final index = this._focusedStickyElementIndex;
        this._disposeFocusStickyScrollStore();
        if (index >= 0 && index < lineNumbers.length) {
            this._revealPosition({lineNumber: lineNumbers[index], column: 1});
        }
    }

    function _revealPosition(position:IPosition):Void {
        this._reveaInEditor(position, () -> this._editor.revealPosition(position));
    }

    function _revealLineInCenterIfOutsideViewport(position:IPosition):Void {
        this._reveaInEditor(position, () -> this._editor.revealLineInCenterIfOutsideViewport(position.lineNumber, ScrollType.Smooth));
    }

    function _reveaInEditor(position:IPosition, revealFunction:() -> Void):Void {
        if (this._focused) {
            this._disposeFocusStickyScrollStore();
        }
        this._positionRevealed = true;
        revealFunction();
        this._editor.setSelection(Range.fromPositions(position));
        this._editor.focus();
    }

    function _registerMouseListeners():Void {
        this._stickyScrollWidget.onMouseDownHandler = (hit, button, modifiers) -> {
            // Suppose that mouse down on the sticky scroll, then do not focus on the sticky scroll because this will be followed by the revealing of a position
            this._onMouseDown = true;
            this._onClick(hit, button, modifiers);
        };
        this._stickyScrollWidget.onMouseMoveHandler = (hit, modifiers) -> {
            if (modifiers.shift) {
                final currentEndForLineIndex:Null<Int> = hit != null ? hit.lineIndex : null;
                if (currentEndForLineIndex == null || this._showEndForLine != null && this._showEndForLine == currentEndForLineIndex) {
                    return;
                }
                this._showEndForLine = currentEndForLineIndex;
                this._renderStickyScroll();
                return;
            }
            if (this._showEndForLine != null) {
                this._showEndForLine = null;
                this._renderStickyScroll();
            }
        };
        this._stickyScrollWidget.onMouseLeaveHandler = () -> {
            if (this._showEndForLine != null) {
                this._showEndForLine = null;
                this._renderStickyScroll();
            }
        };
    }

    /**
     * Monaco's click listener of the widget's node.
     */
    function _onClick(hit:Null<StickyScrollHit>, button:MouseButton, modifiers:glaze.Modifiers):Void {
        if (modifiers.control || modifiers.alt || modifiers.platform) {
            // modifier pressed
            return;
        }
        if (button != MouseButton.Left) {
            // not left click
            return;
        }
        if (hit == null) {
            return;
        }
        if (modifiers.shift) {
            // shift click
            final lineIndex = hit.lineIndex;
            if (lineIndex < 0 || lineIndex >= this._endLineNumbers.length) {
                return;
            }
            final position = new Position(this._endLineNumbers[lineIndex], 1);
            this._revealLineInCenterIfOutsideViewport(position);
            return;
        }
        if (hit.isInFoldingIcon) {
            // clicked on folding icon
            final lineNumber = this._stickyScrollWidget.lineNumbers[hit.lineIndex];
            this._toggleFoldingRegionForLine(lineNumber);
            return;
        }
        if (!hit.isInStickyLine) {
            return;
        }
        // normal click
        var position = hit.position;
        if (position == null) {
            position = new Position(this._stickyScrollWidget.lineNumbers[hit.lineIndex], 1);
        }
        this._revealPosition(position);
    }

    /**
     * A click on the widget at a point of the widget (`localX`, `localY`
     * from its top left corner): what a mouse click does (tests, hosts).
     */
    public function clickAt(localX:Float, localY:Float, ?modifiers:glaze.Modifiers):Void {
        this._onClick(this._stickyScrollWidget.hitTest(localX, localY), MouseButton.Left, modifiers != null ? modifiers : glaze.Modifiers.of());
    }

    function _toggleFoldingRegionForLine(line:Null<Int>):Void {
        if (this._foldingModel == null || line == null) {
            return;
        }
        final stickyLine = this._stickyScrollWidget.getRenderedStickyLine(line);
        final foldingIcon = stickyLine != null ? stickyLine.foldingIcon : null;
        if (foldingIcon == null) {
            return;
        }
        FoldingModelUtils.toggleCollapseState(this._foldingModel, FoldingModelUtils.MAX_LEVELS, [line]);
        foldingIcon.isCollapsed = !foldingIcon.isCollapsed;
        final scrollTop = (foldingIcon.isCollapsed ?
            this._editor.getTopForLineNumber(foldingIcon.foldingEndLine)
            : this._editor.getTopForLineNumber(foldingIcon.foldingStartLine))
            - this._editor.getOption(EditorOption.lineHeight) * stickyLine.index + 1;
        this._editor.setScrollTop(scrollTop);
        this._renderStickyScroll(line);
    }

    function _readConfiguration():Void {
        final options = this._editor.getOption(EditorOption.stickyScroll);
        if (options.enabled == false) {
            this._editor.removeOverlayWidget(this._stickyScrollWidget);
            this._sessionStore.clear();
            this._enabled = false;
            return;
        }
        else if (options.enabled && !this._enabled) {
            // When sticky scroll was just enabled, add the listeners on the sticky scroll
            this._editor.addOverlayWidget(this._stickyScrollWidget);
            this._sessionStore.add(this._editor.onDidScrollChange((e) -> {
                if (e.scrollTopChanged) {
                    this._showEndForLine = null;
                    this._renderStickyScroll();
                }
            }));
            this._sessionStore.add(this._editor.onDidLayoutChange((_) -> this._onDidResize()));
            this._sessionStore.add(this._editor.onDidChangeModelTokens((e) -> this._onTokensChange(e)));
            this._sessionStore.add(this._stickyLineCandidateProvider.onDidChangeStickyScroll(() -> {
                this._showEndForLine = null;
                this._renderStickyScroll();
            }));
            this._enabled = true;
        }

        final lineNumberOption = this._editor.getOption(EditorOption.lineNumbers);
        if (lineNumberOption.renderType == RenderLineNumbersType.Relative) {
            this._sessionStore.add(this._editor.onDidChangeCursorPosition((_) -> {
                this._showEndForLine = null;
                this._renderStickyScroll(0);
            }));
        }
    }

    function _readConfigurationChange(event:ConfigurationChangedEvent):Void {
        if (
            event.hasChanged(EditorOption.stickyScroll)
            || event.hasChanged(EditorOption.minimap)
            || event.hasChanged(EditorOption.lineHeight)
            || event.hasChanged(EditorOption.showFoldingControls)
            || event.hasChanged(EditorOption.lineNumbers)
        ) {
            this._readConfiguration();
        }

        if (event.hasChanged(EditorOption.lineNumbers)) {
            this._renderStickyScroll(0);
        }
    }

    function _needsUpdate(event:IModelTokensChangedEvent):Bool {
        final stickyLineNumbers = this._stickyScrollWidget.getCurrentLines();
        for (stickyLineNumber in stickyLineNumbers) {
            for (range in event.ranges) {
                if (stickyLineNumber >= range.fromLineNumber && stickyLineNumber <= range.toLineNumber) {
                    return true;
                }
            }
        }
        return false;
    }

    function _onTokensChange(event:IModelTokensChangedEvent):Void {
        if (this._needsUpdate(event)) {
            // Rebuilding the whole widget from line 0
            this._renderStickyScroll(0);
        }
    }

    function _onDidResize():Void {
        final layoutInfo = this._editor.getLayoutInfo();
        // Make sure sticky scroll doesn't take up more than 25% of the editor
        final theoreticalLines = layoutInfo.height / this._editor.getOption(EditorOption.lineHeight);
        this._maxStickyLines = Math.round(theoreticalLines * .25);
    }

    function _renderStickyScroll(?rebuildFromLine:Int):Void {
        final model = this._editor.getModel();
        if (model == null || model.isTooLargeForTokenization()) {
            this._resetState();
            return;
        }
        final nextRebuildFromLine = this._updateAndGetMinRebuildFromLine(rebuildFromLine);
        final stickyWidgetVersion = this._stickyLineCandidateProvider.getVersionId();
        final shouldUpdateState = stickyWidgetVersion == null || stickyWidgetVersion == model.getVersionId();
        if (shouldUpdateState) {
            if (!this._focused) {
                this._updateState(nextRebuildFromLine, () -> {});
            }
            else {
                // Suppose that previously the sticky scroll widget had height 0, then if there are visible lines, set the last line as focused
                if (this._focusedStickyElementIndex == -1) {
                    this._updateState(nextRebuildFromLine, () -> {
                        this._focusedStickyElementIndex = this._stickyScrollWidget.lineNumberCount - 1;
                        if (this._focusedStickyElementIndex != -1) {
                            this._stickyScrollWidget.focusLineWithIndex(this._focusedStickyElementIndex);
                        }
                    });
                }
                else {
                    final focusedStickyElementLineNumber = this._stickyScrollWidget.lineNumbers[this._focusedStickyElementIndex];
                    this._updateState(nextRebuildFromLine, () -> {
                        // Suppose that after setting the state, there are no sticky lines, set the focused index to -1
                        if (this._stickyScrollWidget.lineNumberCount == 0) {
                            this._focusedStickyElementIndex = -1;
                        }
                        else {
                            final previousFocusedLineNumberExists = this._stickyScrollWidget.lineNumbers.indexOf(focusedStickyElementLineNumber) != -1;

                            // If the line number is still there, do not change anything
                            // If the line number is not there, set the new focused line to be the last line
                            if (!previousFocusedLineNumberExists) {
                                this._focusedStickyElementIndex = this._stickyScrollWidget.lineNumberCount - 1;
                            }
                            this._stickyScrollWidget.focusLineWithIndex(this._focusedStickyElementIndex);
                        }
                    });
                }
            }
        }
    }

    function _updateAndGetMinRebuildFromLine(rebuildFromLine:Null<Int>):Null<Int> {
        if (rebuildFromLine != null) {
            final minRebuildFromLineOrInfinity:Int = this._minRebuildFromLine != null ? this._minRebuildFromLine : 0x7FFFFFFF;
            this._minRebuildFromLine = Std.int(Math.min(rebuildFromLine, minRebuildFromLineOrInfinity));
        }
        return this._minRebuildFromLine;
    }

    function _updateState(rebuildFromLine:Null<Int>, done:() -> Void):Void {
        this._minRebuildFromLine = null;
        final apply = (foldingModel:Null<FoldingModel>) -> {
            this._foldingModel = foldingModel;
            this._widgetState = this.findScrollWidgetState();
            final stickyWidgetHasLines = this._widgetState.startLineNumbers.length > 0;
            this._stickyScrollVisibleContextKey.set(stickyWidgetHasLines);
            this._stickyScrollWidget.setState(this._widgetState, this._foldingModel, rebuildFromLine);
            done();
        };
        final foldingController = FoldingController.get(this._editor);
        if (foldingController == null || !foldingController.getFoldingModel(apply)) {
            apply(null);
        }
    }

    function _resetState():Void {
        this._minRebuildFromLine = null;
        this._foldingModel = null;
        this._widgetState = StickyScrollWidgetState.Empty;
        this._stickyScrollVisibleContextKey.set(false);
        this._stickyScrollWidget.setState(null, null);
    }

    public function findScrollWidgetState():StickyScrollWidgetState {
        final lineHeight:Float = this._editor.getOption(EditorOption.lineHeight);
        final maxNumberStickyLines = Std.int(Math.min(this._maxStickyLines, this._editor.getOption(EditorOption.stickyScroll).maxLineCount));
        final scrollTop:Float = this._editor.getScrollTop();
        var lastLineRelativePosition:Float = 0;
        final startLineNumbers:Array<Int> = [];
        final endLineNumbers:Array<Int> = [];
        final arrayVisibleRanges = this._editor.getVisibleRanges();
        if (arrayVisibleRanges.length != 0) {
            final fullVisibleRange = new StickyRange(arrayVisibleRanges[0].startLineNumber, arrayVisibleRanges[arrayVisibleRanges.length - 1].endLineNumber);
            final candidateRanges = this._stickyLineCandidateProvider.getCandidateStickyLinesIntersecting(fullVisibleRange);
            for (range in candidateRanges) {
                final start = range.startLineNumber;
                final end = range.endLineNumber;
                final depth = range.nestingDepth;
                if (end - start > 0) {
                    final topOfElementAtDepth = (depth - 1) * lineHeight;
                    final bottomOfElementAtDepth = depth * lineHeight;

                    final bottomOfBeginningLine = this._editor.getBottomForLineNumber(start) - scrollTop;
                    final topOfEndLine = this._editor.getTopForLineNumber(end) - scrollTop;
                    final bottomOfEndLine = this._editor.getBottomForLineNumber(end) - scrollTop;

                    if (topOfElementAtDepth > topOfEndLine && topOfElementAtDepth <= bottomOfEndLine) {
                        startLineNumbers.push(start);
                        endLineNumbers.push(end + 1);
                        lastLineRelativePosition = bottomOfEndLine - bottomOfElementAtDepth;
                        break;
                    }
                    else if (bottomOfElementAtDepth > bottomOfBeginningLine && bottomOfElementAtDepth <= bottomOfEndLine) {
                        startLineNumbers.push(start);
                        endLineNumbers.push(end + 1);
                    }
                    if (startLineNumbers.length == maxNumberStickyLines) {
                        break;
                    }
                }
            }
        }
        this._endLineNumbers = endLineNumbers;
        return new StickyScrollWidgetState(startLineNumbers, endLineNumbers, lastLineRelativePosition, this._showEndForLine);
    }

    /**
     * Runs the pending updates now (tests): the sticky model, then the
     * rendering of the widget.
     */
    public function _flushPendingUpdate():Void {
        final provider = Std.downcast(this._stickyLineCandidateProvider, StickyLineCandidateProvider);
        if (provider != null) {
            provider._flushPendingUpdate();
        }
        this._renderStickyScroll();
    }

    override public function dispose():Void {
        super.dispose();
        this._sessionStore.dispose();
    }

}
