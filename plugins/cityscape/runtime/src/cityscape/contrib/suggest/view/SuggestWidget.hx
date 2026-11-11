// Ported from vscode src/vs/editor/contrib/suggest/browser/suggestWidget.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.base.common.Filters;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.common.Languages.CompletionItemLabel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.contrib.suggest.view.CompletionModel;
import cityscape.contrib.suggest.view.Suggest;
import cityscape.platform.contextkey.common.ContextKey.IContextKey;
import cityscape.view.Codicons;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import cityscape.view.SymbolIcons;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.HighlightStyle;
import glaze.HighlightStyle.TextHighlight;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.StyledText;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.base.Scrollbar;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

private enum abstract SuggestWidgetState(Int) {
    var Hidden = 0;
    var Loading = 1;
    var Empty = 2;
    var Open = 3;
    var Frozen = 4;
    var Details = 5;
}

/**
 * A focused or selected item of the suggest widget (Monaco's
 * `ISelectedSuggestion`).
 */
/**
 * suggestWidget.ts `getLayoutInfo()`.
 */
typedef SuggestWidgetLayoutInfo = {
    var itemHeight:Float;
    var statusBarHeight:Float;
    var borderWidth:Float;
    var borderHeight:Float;
    var typicalHalfwidthCharacterWidth:Float;
    var verticalPadding:Float;
    var horizontalPadding:Float;
    var defaultSize:Size;
}

typedef ISelectedSuggestion = {
    var item:CompletionItem;
    var index:Int;
    var model:CompletionModel;
}

/**
 * The suggest widget (Monaco's `SuggestWidget`): its states (loading, no
 * suggestions, open, frozen, details), the focused item, the moves of the
 * focus, the details, and its context keys. Monaco's list and content
 * widget (DOM) are replaced by a list kept here (`items`, `focusedIndex`,
 * `firstVisibleIndex`) and drawn by `SuggestWidgetView` with the Glaze kit,
 * in the colors of the theme (`editorSuggestWidget.*`, else the kit's).
 * Its size and side are Monaco's (`_layout`, `_resize`, the content widget's
 * `ABOVE` or `BELOW` preference placed by `ContentWidgetPositioner`, the
 * details placed by `SuggestDetailsOverlay._placeAtAnchor`): below the
 * cursor when the list fits between the line and the bottom of the window
 * (less 22 pixels), else above, its height capped to the room on that side,
 * the list scrolling beyond. The layout runs at the next render after
 * Monaco's calls (it needs the window).
 * Not ported: the resizing sash and the persisted size (never stored, so
 * `restore()` is always undefined), the status bar (its height is 0, the
 * default `suggest.showStatusBar: false`), the explain mode details, the aria
 * announcements, the high contrast border width (2).
 */
class SuggestWidget implements IDisposable {

    public static final LOADING_MESSAGE = 'Loading...';
    public static final NO_SUGGESTIONS_MESSAGE = 'No suggestions.';

    /**
     * The number of rows shown at most (Monaco shows 12 by default).
     */
    public static inline final MAX_VISIBLE_ITEMS = 12;

    // _layout requests (Monaco calls `_layout` at these points, the port at
    // the next render, in this order): from the persisted size (`_show`,
    // `forceRenderingAbove`), from the current size (after `showSuggestions`)
    static inline final LAYOUT_PERSISTED = 1;
    static inline final LAYOUT_CURRENT = 2;

    final editor:ICodeEditor;

    var _state:SuggestWidgetState = SuggestWidgetState.Hidden;
    var _isAuto:Bool = false;
    var _loadingTimeout:Null<IDisposable> = null;
    var _currentSuggestionDetails:Null<CancellationTokenSource> = null;
    var _focusedItem:Null<CompletionItem> = null;
    var _ignoreFocusEvents:Bool = false;
    var _completionModel:Null<CompletionModel> = null;
    var _detailsVisible:Bool = false;

    // Monaco's `element.size` (the content box of the widget, without its
    // border), `element.maxSize`, `_cappedHeight`, `_forceRenderingAbove`
    // and the content widget's `_preference`
    var _size:Null<Size> = null;
    var _maxSize:Null<Size> = null;
    var _minSize:Null<Size> = null;
    var _cappedHeight:Null<{wanted:Float, capped:Float}> = null;
    var _forceRenderingAbove:Bool = false;
    var _layoutRequests:Int = 0;

    /**
     * The side of the widget (Monaco's `SuggestContentWidget._preference`),
     * null before the first layout.
     */
    public var preference(default, null):Null<ContentWidgetPositionPreference> = null;

    /**
     * The window bounds of the list and of the details, as last drawn
     * (null when they do not show).
     */
    public var listBounds(default, null):Null<Bounds> = null;
    public var detailsBounds(default, null):Null<Bounds> = null;

    /** The items of the list (Monaco's list elements). */
    public var items(default, null):Array<CompletionItem> = [];
    /** The focused item index, -1 for none. */
    public var focusedIndex(default, null):Int = -1;
    /** The first row shown. */
    public var firstVisibleIndex(default, null):Int = 0;
    /** The position the widget is shown at (Monaco's content widget position). */
    public var position(default, null):Null<Position> = null;
    /** The message shown instead of the list (loading, no suggestions). */
    public var message(default, null):Null<String> = null;

    final _showTimeout = new TimeoutTimer();
    final _disposables = new DisposableStore();

    final _ctxSuggestWidgetVisible:IContextKey<Bool>;
    final _ctxSuggestWidgetDetailsVisible:IContextKey<Bool>;
    final _ctxSuggestWidgetMultipleSuggestions:IContextKey<Bool>;
    final _ctxSuggestWidgetHasFocusedSuggestion:IContextKey<Bool>;

    final _onDidSelect = new Emitter<ISelectedSuggestion>();
    final _onDidFocus = new Emitter<ISelectedSuggestion>();
    final _onDidHide = new Emitter<SuggestWidget>();
    final _onDidShow = new Emitter<SuggestWidget>();

    public final onDidSelect:Event<ISelectedSuggestion>;
    public final onDidHide:Event<SuggestWidget>;
    public final onDidShow:Event<SuggestWidget>;
    public final onDidFocus:Event<ISelectedSuggestion>;

    /**
     * Called when what the widget shows changes (the view renders again).
     */
    public var onChange:Null<() -> Void> = null;

    final overlay:SuggestWidgetOverlay;

    public function new(editor:ICodeEditor) {
        this.editor = editor;
        onDidSelect = _onDidSelect.event;
        onDidHide = _onDidHide.event;
        onDidShow = _onDidShow.event;
        onDidFocus = _onDidFocus.event;

        final contextKeyService = editor.contextKeyService;
        _ctxSuggestWidgetVisible = SuggestContext.Visible.bindTo(contextKeyService);
        _ctxSuggestWidgetDetailsVisible = SuggestContext.DetailsVisible.bindTo(contextKeyService);
        _ctxSuggestWidgetMultipleSuggestions = SuggestContext.MultipleSuggestions.bindTo(contextKeyService);
        _ctxSuggestWidgetHasFocusedSuggestion = SuggestContext.HasFocusedSuggestion.bindTo(contextKeyService);

        _detailsVisible = editor.context.storageService.getBoolean('expandSuggestionDocs', cityscape.platform.storage.common.Storage.StorageScope.PROFILE, false) == true;

        _disposables.add(editor.onDidChangeCursorSelection(_ -> _onCursorSelectionChanged()));
        _disposables.add(editor.onDidScrollChange(_ -> _changed()));

        overlay = new SuggestWidgetOverlay(this, editor);
        editor.addOverlayWidget(overlay);
    }

    public function dispose():Void {
        editor.removeOverlayWidget(overlay);
        overlay.dispose();
        _disposables.dispose();
        if (_loadingTimeout != null) {
            _loadingTimeout.dispose();
        }
        _showTimeout.dispose();
        _onDidSelect.dispose();
        _onDidFocus.dispose();
        _onDidHide.dispose();
        _onDidShow.dispose();
    }

    function _changed():Void {
        final f = onChange;
        if (f != null) {
            f();
        }
        else {
            editor.layoutOverlayWidget(overlay);
        }
    }

    function _onCursorSelectionChanged():Void {
        if (_state != SuggestWidgetState.Hidden) {
            _changed();
        }
    }

    /**
     * A click on a row (Monaco's list mouse down): accepts the item.
     */
    public function selectAt(index:Int):Void {
        if (index < 0 || index >= items.length) {
            return;
        }
        _select(items[index], index);
    }

    function _select(item:CompletionItem, index:Int):Void {
        final completionModel = _completionModel;
        if (completionModel != null) {
            _onDidSelect.fire({item: item, index: index, model: completionModel});
            editor.focus();
        }
    }

    /**
     * Monaco's list `setFocus`: focuses a row (or none with -1) and fires
     * the focus events.
     */
    function _setFocus(index:Int):Void {
        focusedIndex = index;
        _onListFocus();
        _changed();
    }

    function _onListFocus():Void {
        if (_ignoreFocusEvents) {
            return;
        }

        if (focusedIndex < 0 || focusedIndex >= items.length) {
            if (_currentSuggestionDetails != null) {
                _currentSuggestionDetails.cancel();
                _currentSuggestionDetails = null;
                _focusedItem = null;
            }
            _ctxSuggestWidgetHasFocusedSuggestion.set(false);
            return;
        }

        if (_completionModel == null) {
            return;
        }

        _ctxSuggestWidgetHasFocusedSuggestion.set(true);
        final item = items[focusedIndex];
        final index = focusedIndex;

        if (item != _focusedItem) {

            if (_currentSuggestionDetails != null) {
                _currentSuggestionDetails.cancel();
            }
            _currentSuggestionDetails = null;

            _focusedItem = item;
            _detailsRenders = 0;

            _reveal(index);

            final source = new CancellationTokenSource();
            _currentSuggestionDetails = source;
            item.resolve(source.token).done(_ -> {
                if (index >= items.length || item != items[index]) {
                    return;
                }
                // item can have extra information, so re-render
                _changed();
            });
        }

        // emit an event
        _onDidFocus.fire({item: item, index: index, model: _completionModel});
    }

    function _reveal(index:Int):Void {
        if (index < firstVisibleIndex) {
            firstVisibleIndex = index;
        }
        else if (index >= firstVisibleIndex + visibleRowCount()) {
            firstVisibleIndex = index - visibleRowCount() + 1;
        }
    }

    /**
     * Scrolls the list so that the row `index` is the first one shown
     * (clamped like `scrollBy`; the scrollbar).
     */
    public function scrollToRow(index:Int):Void {
        final max = Std.int(Math.max(0, items.length - visibleRowCount()));
        final next = Std.int(Math.max(0, Math.min(max, index)));
        if (next != firstVisibleIndex) {
            firstVisibleIndex = next;
            _changed();
        }
    }

    var _listScrollHandle:Null<SuggestListScrollHandle> = null;

    /**
     * The handle of the kit scrollbar of the list (made once).
     */
    public function listScrollHandle():SuggestListScrollHandle {
        if (_listScrollHandle == null) {
            _listScrollHandle = new SuggestListScrollHandle(this);
        }
        return _listScrollHandle;
    }

    /**
     * Scrolls the list by `delta` rows (the mouse wheel over the list).
     */
    public function scrollBy(delta:Int):Void {
        final max = Std.int(Math.max(0, items.length - visibleRowCount()));
        final next = Std.int(Math.max(0, Math.min(max, firstVisibleIndex + delta)));
        if (next != firstVisibleIndex) {
            firstVisibleIndex = next;
            _changed();
        }
    }

    function _setState(state:SuggestWidgetState):Void {

        if (_state == state) {
            return;
        }
        _state = state;

        switch (state) {
            case SuggestWidgetState.Hidden:
                message = null;
                _ctxSuggestWidgetVisible.reset();
                _ctxSuggestWidgetMultipleSuggestions.reset();
                _ctxSuggestWidgetHasFocusedSuggestion.reset();
                _showTimeout.cancel();
                items = [];
                focusedIndex = -1;
                firstVisibleIndex = 0;
                _focusedItem = null;
                _cappedHeight = null;
                _layoutRequests = 0;
                listBounds = null;
                detailsBounds = null;
            case SuggestWidgetState.Loading:
                message = editor.context.nls.localize('suggestWidget.loading', LOADING_MESSAGE);
                _show();
                _focusedItem = null;
            case SuggestWidgetState.Empty:
                message = editor.context.nls.localize('suggestWidget.noSuggestions', NO_SUGGESTIONS_MESSAGE);
                _show();
                _focusedItem = null;
            case SuggestWidgetState.Open | SuggestWidgetState.Frozen | SuggestWidgetState.Details:
                message = null;
                _show();
        }
        _changed();
    }

    function _show():Void {
        _requestLayout(LAYOUT_PERSISTED);
        _ctxSuggestWidgetVisible.set(true);

        _showTimeout.cancelAndSet(() -> {
            _onDidShow.fire(this);
        }, 100);
    }

    public function showTriggered(auto:Bool, delay:Int):Void {
        if (_state != SuggestWidgetState.Hidden) {
            return;
        }
        position = editor.getPosition();
        _isAuto = auto;

        if (!_isAuto) {
            final cancel = Async.setTimeout(() -> _setState(SuggestWidgetState.Loading), delay);
            _loadingTimeout = Lifecycle.toDisposable(cancel);
        }
    }

    public function showSuggestions(completionModel:CompletionModel, selectionIndex:Int, isFrozen:Bool, isAuto:Bool, noFocus:Bool):Void {

        position = editor.getPosition();
        if (_loadingTimeout != null) {
            _loadingTimeout.dispose();
            _loadingTimeout = null;
        }

        if (_currentSuggestionDetails != null) {
            _currentSuggestionDetails.cancel();
        }
        _currentSuggestionDetails = null;

        if (_completionModel != completionModel) {
            _completionModel = completionModel;
        }

        if (isFrozen && _state != SuggestWidgetState.Empty && _state != SuggestWidgetState.Hidden) {
            _setState(SuggestWidgetState.Frozen);
            return;
        }

        final visibleCount = completionModel.items.length;
        final isEmpty = visibleCount == 0;
        _ctxSuggestWidgetMultipleSuggestions.set(visibleCount > 1);

        if (isEmpty) {
            _setState(isAuto ? SuggestWidgetState.Hidden : SuggestWidgetState.Empty);
            _completionModel = null;
            return;
        }

        _focusedItem = null;

        // calling list.splice triggers focus event which this widget forwards. That can lead to
        // suggestions being cancelled and the widget being cleared (and hidden). All this happens
        // before revealing and focusing is done which means revealing and focusing will fail when
        // they get run.
        _ignoreFocusEvents = true;
        items = completionModel.items.copy();
        focusedIndex = -1;
        firstVisibleIndex = 0;
        _ignoreFocusEvents = false;
        _setState(isFrozen ? SuggestWidgetState.Frozen : SuggestWidgetState.Open);
        firstVisibleIndex = Std.int(Math.max(0, Math.min(selectionIndex, items.length - visibleRowCount())));
        _setFocus(noFocus ? -1 : selectionIndex);

        // Monaco: `_layout(this.element.size)` at this or the next animation frame
        _requestLayout(LAYOUT_CURRENT);
    }

    public function focusSelected():Void {
        if (items.length > 0) {
            _setFocus(0);
        }
    }

    function focusNext(n:Int, loop:Bool):Void {
        if (items.length == 0) {
            return;
        }
        var index = focusedIndex + n;
        if (index >= items.length) {
            index = loop ? 0 : items.length - 1;
        }
        _setFocus(index);
    }

    function focusPrevious(n:Int, loop:Bool):Void {
        if (items.length == 0) {
            return;
        }
        var index = focusedIndex < 0 ? items.length - 1 : focusedIndex - n;
        if (index < 0) {
            index = loop ? items.length - 1 : 0;
        }
        _setFocus(index);
    }

    public function selectNextPage():Bool {
        switch (_state) {
            case SuggestWidgetState.Hidden:
                return false;
            case SuggestWidgetState.Loading:
                return !_isAuto;
            default:
                // Monaco's focusNextPage: to the last visible row, then one page on
                final lastVisible = Std.int(Math.min(items.length - 1, firstVisibleIndex + visibleRowCount() - 1));
                if (focusedIndex != lastVisible) {
                    _setFocus(lastVisible);
                }
                else {
                    _setFocus(Std.int(Math.min(items.length - 1, lastVisible + visibleRowCount() - 1)));
                }
                return true;
        }
    }

    public function selectNext():Bool {
        switch (_state) {
            case SuggestWidgetState.Hidden:
                return false;
            case SuggestWidgetState.Loading:
                return !_isAuto;
            default:
                focusNext(1, true);
                return true;
        }
    }

    public function selectLast():Bool {
        switch (_state) {
            case SuggestWidgetState.Hidden:
                return false;
            case SuggestWidgetState.Loading:
                return !_isAuto;
            default:
                if (items.length > 0) {
                    _setFocus(items.length - 1);
                }
                return true;
        }
    }

    public function selectPreviousPage():Bool {
        switch (_state) {
            case SuggestWidgetState.Hidden:
                return false;
            case SuggestWidgetState.Loading:
                return !_isAuto;
            default:
                // Monaco's focusPreviousPage: to the first visible row, then one page back
                final firstVisible = firstVisibleIndex;
                if (focusedIndex != firstVisible) {
                    _setFocus(firstVisible);
                }
                else {
                    _setFocus(Std.int(Math.max(0, firstVisible - visibleRowCount() + 1)));
                }
                return true;
        }
    }

    public function selectPrevious():Bool {
        switch (_state) {
            case SuggestWidgetState.Hidden:
                return false;
            case SuggestWidgetState.Loading:
                return !_isAuto;
            default:
                focusPrevious(1, true);
                return false;
        }
    }

    public function selectFirst():Bool {
        switch (_state) {
            case SuggestWidgetState.Hidden:
                return false;
            case SuggestWidgetState.Loading:
                return !_isAuto;
            default:
                if (items.length > 0) {
                    _setFocus(0);
                }
                return true;
        }
    }

    public function getFocusedItem():Null<ISelectedSuggestion> {
        if (_state != SuggestWidgetState.Hidden
            && _state != SuggestWidgetState.Empty
            && _state != SuggestWidgetState.Loading
            && _completionModel != null
            && focusedIndex >= 0 && focusedIndex < items.length
        ) {
            return {
                item: items[focusedIndex],
                index: focusedIndex,
                model: _completionModel
            };
        }
        return null;
    }

    public function toggleDetailsFocus():Void {
        if (_state == SuggestWidgetState.Details) {
            _setState(SuggestWidgetState.Open);
        }
        else if (_state == SuggestWidgetState.Open && _isDetailsVisible()) {
            _setState(SuggestWidgetState.Details);
        }
    }

    /**
     * Monaco's `canExpandCompletionItem` (suggestWidgetDetails.ts).
     */
    public static function canExpandCompletionItem(item:Null<CompletionItem>):Bool {
        return item != null && ((item.completion.documentation != null && hasText(item.completion.documentation)) || (item.completion.detail != null && item.completion.detail != item.completion.label));
    }

    static function hasText(doc:Any):Bool {
        if (JsValues.isString(doc)) {
            return (doc : String).length > 0;
        }
        final md:IMarkdownString = doc;
        return md.value != null && md.value.length > 0;
    }

    public function toggleDetails():Void {
        _detailsRenders = 0;
        if (_isDetailsVisible()) {
            // hide details widget
            _ctxSuggestWidgetDetailsVisible.set(false);
            _setDetailsVisible(false);
        }
        else if (canExpandCompletionItem(focusedIndex >= 0 && focusedIndex < items.length ? items[focusedIndex] : null) && (_state == SuggestWidgetState.Open || _state == SuggestWidgetState.Details || _state == SuggestWidgetState.Frozen)) {
            // show details widget (iff possible)
            _ctxSuggestWidgetDetailsVisible.set(true);
            _setDetailsVisible(true);
        }
        _changed();
    }

    public function toggleExplainMode():Void {
        // the explain mode (debug information of the items) is not ported
    }

    public function resetPersistedSize():Void {
        // the widget has no persisted size
    }

    public function hideWidget():Void {
        if (_loadingTimeout != null) {
            _loadingTimeout.dispose();
            _loadingTimeout = null;
        }

        _setState(SuggestWidgetState.Hidden);
        _onDidHide.fire(this);
    }

    public function isFrozen():Bool {
        return _state == SuggestWidgetState.Frozen;
    }

    /**
     * Whether the widget shows (any state but hidden).
     */
    public function isVisible():Bool {
        return _state != SuggestWidgetState.Hidden;
    }

    /**
     * Whether the widget shows a list (open, frozen or details).
     */
    public function isShowingList():Bool {
        return _state == SuggestWidgetState.Open || _state == SuggestWidgetState.Frozen || _state == SuggestWidgetState.Details;
    }

    public function _isDetailsVisible():Bool {
        return _detailsVisible;
    }

    function _setDetailsVisible(value:Bool):Void {
        _detailsVisible = value;
        editor.context.storageService.store('expandSuggestionDocs', value, cityscape.platform.storage.common.Storage.StorageScope.PROFILE, cityscape.platform.storage.common.Storage.StorageTarget.USER);
    }

    public function forceRenderingAbove():Void {
        if (!_forceRenderingAbove) {
            _forceRenderingAbove = true;
            _requestLayout(LAYOUT_PERSISTED);
            _changed();
        }
    }

    public function stopForceRenderingAbove():Void {
        _forceRenderingAbove = false;
    }

    function _requestLayout(kind:Int):Void {
        _layoutRequests |= kind;
    }

    /**
     * The rows the list shows entirely (its height over the item height, 12
     * by default), at least 1: the step of the keyboard pages and the limit
     * of the scroll (the port scrolls by whole rows).
     */
    public function visibleRowCount():Int {
        final size = _size;
        if (size == null || !isShowingList()) {
            return MAX_VISIBLE_ITEMS;
        }
        final info = getLayoutInfo();
        return Std.int(Math.max(1, Math.floor((size.height - info.statusBarHeight) / info.itemHeight)));
    }

    /**
     * Monaco's `element.size`: the content box of the widget (without its
     * border), null before the first layout.
     */
    public function getSize():Null<Size> {
        return _size;
    }

    /**
     * suggestWidget.ts `getLayoutInfo()`.
     */
    public function getLayoutInfo():SuggestWidgetLayoutInfo {
        final fontInfo = editor.getOption(EditorOption.fontInfo);
        final suggestLineHeight:Float = editor.getOption(EditorOption.suggestLineHeight);
        final itemHeight = Math.max(8, Math.min(1000, suggestLineHeight > 0 ? suggestLineHeight : fontInfo.lineHeight));
        // the status bar is not ported (`suggest.showStatusBar` is false by default)
        final statusBarHeight = 0.0;
        final borderWidth = 1.0;
        final borderHeight = 2 * borderWidth;
        return {
            itemHeight: itemHeight,
            statusBarHeight: statusBarHeight,
            borderWidth: borderWidth,
            borderHeight: borderHeight,
            typicalHalfwidthCharacterWidth: fontInfo.typicalHalfwidthCharacterWidth,
            verticalPadding: 22,
            horizontalPadding: 14,
            defaultSize: new Size(430, statusBarHeight + 12 * itemHeight + borderHeight)
        };
    }

    /**
     * Runs the pending `_layout` calls in `page` (Monaco's `document.body`
     * client area: the window, or the editor with `overflowWidgetsBounds:
     * 'editor'`); called by the view when it renders.
     */
    public function flushLayout(page:Bounds):Void {
        final requests = _layoutRequests;
        if (requests == 0 || _state == SuggestWidgetState.Hidden) {
            return;
        }
        _layoutRequests = 0;
        if ((requests & LAYOUT_PERSISTED) != 0) {
            // `this._persistedSize.restore()`: nothing is ever persisted
            _layout(null, page);
        }
        if ((requests & LAYOUT_CURRENT) != 0) {
            _layout(_size, page);
        }
        if (focusedIndex >= 0) {
            _reveal(focusedIndex);
        }
        final max = Std.int(Math.max(0, items.length - visibleRowCount()));
        if (firstVisibleIndex > max) {
            firstVisibleIndex = max;
        }
    }

    /**
     * suggestWidget.ts `_layout`: the size of the widget and its side
     * (`ABOVE` when the list does not fit below the cursor, inside the
     * page less `verticalPadding`), its height capped to the room there.
     * `page` is the window (Monaco's body), or the editor with
     * `overflowWidgetsBounds: 'editor'`.
     */
    function _layout(size:Null<Size>, page:Bounds):Void {
        final bodyBox = page.size;
        if (!editor.hasModel()) {
            return;
        }
        final editorBox = EditorWidgets.editorBounds(editor);
        if (editorBox == null) {
            // happens when running tests
            return;
        }

        final info = getLayoutInfo();

        if (size == null) {
            size = info.defaultSize;
        }

        var height = size.height;
        var width = size.width;

        if (_state == SuggestWidgetState.Empty || _state == SuggestWidgetState.Loading) {
            // showing a message only
            height = info.itemHeight + info.borderHeight;
            width = info.defaultSize.width / 2;
            _minSize = _maxSize = new Size(width, height);
            _setPreference(ContentWidgetPositionPreference.BELOW);

        }
        else {
            // showing items

            // width math
            final maxWidth = bodyBox.width - info.borderHeight - 2 * info.horizontalPadding;
            if (width > maxWidth) {
                width = maxWidth;
            }

            // height math
            final fullHeight = info.statusBarHeight + items.length * info.itemHeight + info.borderHeight;
            final minHeight = info.itemHeight + info.statusBarHeight;
            final cursorPosition = editor.getPosition();
            final cursorBox = cursorPosition != null ? editor.getScrolledVisiblePosition(cursorPosition) : null;
            if (cursorBox == null) {
                return;
            }
            // in the page (the window's origin, or the editor's)
            final editorTop = editorBox.origin.y - page.origin.y;
            final cursorBottom = editorTop + cursorBox.top + cursorBox.height;
            final maxHeightBelow = Math.min(bodyBox.height - cursorBottom - info.verticalPadding, fullHeight);
            final availableSpaceAbove = editorTop + cursorBox.top - info.verticalPadding;
            final maxHeightAbove = Math.min(availableSpaceAbove, fullHeight);
            var maxHeight = Math.min(Math.max(maxHeightAbove, maxHeightBelow) + info.borderHeight, fullHeight);

            final capped = _cappedHeight;
            if (capped != null && height == capped.capped) {
                // Restore the old (wanted) height when the current
                // height is capped to fit
                height = capped.wanted;
            }

            if (height < minHeight) {
                height = minHeight;
            }
            if (height > maxHeight) {
                height = maxHeight;
            }

            final forceRenderingAboveRequiredSpace = 150;
            if (height > maxHeightBelow || (_forceRenderingAbove && availableSpaceAbove > forceRenderingAboveRequiredSpace)) {
                _setPreference(ContentWidgetPositionPreference.ABOVE);
                maxHeight = maxHeightAbove;
            }
            else {
                _setPreference(ContentWidgetPositionPreference.BELOW);
                maxHeight = maxHeightBelow;
            }
            _maxSize = new Size(maxWidth, maxHeight);
            _minSize = new Size(220, minHeight);

            // Know when the height was capped to fit and remember
            // the wanted height for later. This is required when going
            // left to widen suggestions.
            _cappedHeight = height == fullHeight
                ? {wanted: capped != null ? capped.wanted : size.height, capped: height}
                : null;
        }
        _resize(width, height);
    }

    /**
     * suggestWidget.ts `_resize` with `ResizableHTMLElement.layout` (the
     * size clamped to the maximum, then to the minimum).
     */
    function _resize(width:Float, height:Float):Void {
        final maxSize = _maxSize;
        final minSize = _minSize;
        if (maxSize != null) {
            width = Math.min(maxSize.width, width);
            height = Math.min(maxSize.height, height);
        }
        if (minSize != null && maxSize != null) {
            height = Math.max(minSize.height, Math.min(maxSize.height, height));
            width = Math.max(minSize.width, Math.min(maxSize.width, width));
        }
        _size = new Size(width, height);
    }

    function _setPreference(value:ContentWidgetPositionPreference):Void {
        // `lockPreference` is only used while resizing with the sashes (not ported)
        preference = value;
    }

    /**
     * Renders the widget again (the view found that the details' side
     * depends on their new height).
     */
    public function requestRender():Void {
        // at most twice for an item (no endless back and forth between two sides)
        if (_state != SuggestWidgetState.Hidden && _detailsRenders < 2) {
            _detailsRenders++;
            _changed();
        }
    }

    var _detailsRenders:Int = 0;

    /**
     * Called by the view once the list and the details are placed.
     */
    public function setDrawnBounds(list:Null<Bounds>, details:Null<Bounds>):Void {
        listBounds = list;
        detailsBounds = details;
    }

}

/**
 * The kit scrollbar handle of the suggest list: GPUI offsets (0 at the top,
 * negative down) over the first row shown (the port scrolls the list by
 * whole rows: the content is as high as the list plus the rows it can
 * scroll by).
 */
class SuggestListScrollHandle implements glaze.kit.base.Scrollbar.ScrollbarHandleImpl {

    final widget:SuggestWidget;

    public function new(widget:SuggestWidget) {
        this.widget = widget;
    }

    function itemHeight():Float {
        return widget.getLayoutInfo().itemHeight;
    }

    public function viewportBounds():Bounds {
        // the scrollbar takes its viewport from its layout (`viewportFromLayout`)
        final b = widget.listBounds;
        return b != null ? b : new Bounds(new Point(0, 0), new Size(0, 0));
    }

    public function offset():Point {
        return new Point(0, -widget.firstVisibleIndex * itemHeight());
    }

    public function setOffset(offset:Point):Void {
        widget.scrollToRow(Math.round(-offset.y / itemHeight()));
    }

    public function contentSize():Size {
        final h = itemHeight();
        final visible = widget.visibleRowCount();
        final size = widget.getSize();
        final listHeight = size != null ? size.height - widget.getLayoutInfo().statusBarHeight : visible * h;
        return new Size(size != null ? size.width : 0, listHeight + Math.max(0, widget.items.length - visible) * h);
    }

    public function startDrag():Void {}

    public function endDrag():Void {}

}

/**
 * The suggest widget in the editor: an overlay widget whose Glaze view
 * (`SuggestWidgetView`) is created at the first render of the editor and
 * draws the widget as a popup below (or above) the cursor.
 */
class SuggestWidgetOverlay implements IOverlayWidget implements IDisposable {

    public static inline final ID = 'editor.widget.suggestWidget';

    final widget:SuggestWidget;
    final editor:ICodeEditor;
    var view:Null<Entity<SuggestWidgetView>> = null;
    var app:Null<App> = null;

    public function new(widget:SuggestWidget, editor:ICodeEditor) {
        this.widget = widget;
        this.editor = editor;
    }

    public function dispose():Void {
        widget.onChange = null;
        cityscape.view.ViewEntities.release(view);
        view = null;
    }

    public function getId():String {
        return ID;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        var v = view;
        if (v == null) {
            app = cx;
            v = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:Context<SuggestWidgetView>) -> new SuggestWidgetView(widget, editor, c)), cx);
            view = v;
            final entityId = v.entityId();
            widget.onChange = () -> cx.notify(entityId);
        }
        return v;
    }

}

/**
 * Draws the suggest widget: a list of rows (kind icon, label with the
 * matched characters highlighted, detail), at most `MAX_VISIBLE_ITEMS`
 * rows, the focused one highlighted, and the documentation of the focused
 * item next to the list when the details show.
 */
class SuggestWidgetView extends Model implements Render {

    final widget:SuggestWidget;
    final editor:ICodeEditor;

    public function new(widget:SuggestWidget, editor:ICodeEditor, cx:Context<SuggestWidgetView>) {
        super();
        this.widget = widget;
        this.editor = editor;
    }

    /**
     * The color of a kind codicon: its `symbolIcon.*Foreground` color
     * (symbolIcons.css), `editorSuggestWidget.selectedIconForeground` in the
     * focused row, else the color of the row.
     */
    static function codiconColor(editor:ICodeEditor, codicon:String, foreground:Hsla, focused:Bool):Hsla {
        if (focused) {
            final selected = EditorWidgets.themeColor(editor, 'editorSuggestWidget.selectedIconForeground');
            if (selected != null) {
                return selected;
            }
            final quickInput = EditorWidgets.themeColor(editor, 'quickInputList.focusIconForeground');
            if (quickInput != null) {
                return quickInput;
            }
        }
        final key = cityscape.contrib.symbolIcons.view.SymbolIcons.SymbolIconColors.colorOf(codicon);
        if (key != null) {
            final c = EditorWidgets.themeColor(editor, key);
            if (c != null) {
                return c;
            }
        }
        return foreground;
    }

    /**
     * The UTF-8 byte offset of a UTF-16 offset of `s`.
     */
    static function utf8Offset(s:String, utf16Offset:Int):Int {
        var bytes = 0;
        var i = 0;
        while (i < utf16Offset && i < s.length) {
            final c = StringTools.fastCodeAt(s, i);
            if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
                bytes += 4;
                i += 2;
            }
            else {
                bytes += c < 0x80 ? 1 : (c < 0x800 ? 2 : 3);
                i++;
            }
        }
        return bytes;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        if (!widget.isVisible() || widget.position == null || !editor.hasModel()) {
            return new Empty();
        }
        final position = widget.position;
        if (!EditorWidgets.isPositionVisible(editor, position)) {
            return new Empty();
        }
        final theme = Theme.global(cx);
        final fontInfo = editor.getOption(EditorOption.fontInfo);
        final suggestFontSize:Float = editor.getOption(EditorOption.suggestFontSize) > 0 ? editor.getOption(EditorOption.suggestFontSize) : fontInfo.fontSize;
        final suggestLineHeight:Float = editor.getOption(EditorOption.suggestLineHeight) > 0 ? editor.getOption(EditorOption.suggestLineHeight) : fontInfo.lineHeight;
        final options = editor.getOption(EditorOption.suggest);

        final background = EditorWidgets.color(editor, 'editorSuggestWidget.background', EditorWidgets.color(editor, 'editorWidget.background', theme.popover));
        final foreground = EditorWidgets.color(editor, 'editorSuggestWidget.foreground', EditorWidgets.color(editor, 'editor.foreground', theme.popoverForeground));
        final border = EditorWidgets.color(editor, 'editorSuggestWidget.border', EditorWidgets.color(editor, 'editorWidget.border', theme.border));
        final selectedBackground = EditorWidgets.color(editor, 'editorSuggestWidget.selectedBackground', EditorWidgets.color(editor, 'list.activeSelectionBackground', EditorWidgets.color(editor, 'quickInputList.focusBackground', theme.accent)));
        final selectedForeground = EditorWidgets.color(editor, 'editorSuggestWidget.selectedForeground', EditorWidgets.color(editor, 'list.activeSelectionForeground', foreground));
        final highlightForeground = EditorWidgets.color(editor, 'editorSuggestWidget.highlightForeground', EditorWidgets.color(editor, 'list.highlightForeground', theme.blue));
        final focusHighlightForeground = EditorWidgets.color(editor, 'editorSuggestWidget.focusHighlightForeground', EditorWidgets.color(editor, 'list.focusHighlightForeground', highlightForeground));
        final mutedForeground = foreground.opacity(0.7);
        final fontFamily = EditorWidgets.editorFontFamily(editor);

        final anchor = EditorWidgets.positionBounds(editor, position);
        final editorBounds = EditorWidgets.editorBounds(editor);
        if (anchor == null || editorBounds == null) {
            return new Empty();
        }

        // Monaco's `_layout` (pending since the last change), then the size
        // and the side it found
        // the window (Monaco's page), or the editor (`overflowWidgetsBounds: 'editor'`)
        final overflowPage = EditorWidgets.overflowPage(editor);
        final page = overflowPage != null ? overflowPage : new Bounds(new Point(0, 0), window.viewportSize());
        widget.flushLayout(page);
        final size = widget.getSize();
        final preference = widget.preference;
        if (size == null || preference == null) {
            return new Empty();
        }
        final info = widget.getLayoutInfo();
        final itemHeight = info.itemHeight;
        // the content box of Monaco's widget plus its border
        final outerSize = new Size(size.width + info.borderHeight, size.height + info.borderHeight);
        final listHeight = size.height - info.statusBarHeight;

        final list = div()
            .id('cityscape-suggest-list')
            .flex()
            .flexCol()
            .w(px(outerSize.width))
            .h(px(outerSize.height))
            .flexNone()
            .bg(background)
            .border1()
            .borderColor(border)
            .rounded(px(3))
            .shadowMd()
            .overflowHidden()
            .fontFamily(fontFamily)
            .textSize(px(suggestFontSize))
            .textColor(foreground)
            .onScrollWheel((event, window, cx) -> {
                final delta = glaze.ScrollDelta.ScrollDeltaTools.pixelDelta(event.delta, itemHeight);
                widget.scrollBy(delta.y < 0 ? 1 : (delta.y > 0 ? -1 : 0));
                cx.stopPropagation();
            });

        if (widget.message != null) {
            // `.suggest-widget.message { flex-direction: row; align-items: center }`
            list.flexRow().itemsCenter();
            list.child(div().px2().h(px(itemHeight)).flex().itemsCenter().textColor(mutedForeground).child(widget.message));
        }
        else {
            // the rows in the height of the list, the last one cut when it
            // does not fit entirely
            final start = widget.firstVisibleIndex;
            final end = Std.int(Math.min(widget.items.length, start + Math.ceil(listHeight / itemHeight)));
            for (index in start...end) {
                final item = widget.items[index];
                final focused = index == widget.focusedIndex;
                final label:Any = item.completion.label;
                final labelDetail:Null<String> = JsValues.isString(label) ? null : (label : CompletionItemLabel).detail;
                final labelDescription:Null<String> = JsValues.isString(label) ? null : (label : CompletionItemLabel).description;
                final text = item.textLabel;
                final highlights:Array<TextHighlight> = [];
                for (m in Filters.createMatches(item.score)) {
                    final s = utf8Offset(text, m.start);
                    final e = utf8Offset(text, m.end);
                    if (e > s) {
                        highlights.push(new TextHighlight(s, e, new HighlightStyle(focused ? focusHighlightForeground : highlightForeground, glaze.FontWeight.BOLD)));
                    }
                }
                final deprecated = item.completion.tags != null && item.completion.tags.indexOf(cityscape.common.Languages.CompletionItemTag.Deprecated) >= 0;
                final codicon = cityscape.common.languages.CompletionItemKind.CompletionItemKinds.toIcon(item.completion.kind);
                final row = div()
                    .id('cityscape-suggest-row-' + index)
                    .flex()
                    .flexRow()
                    .itemsCenter()
                    .gap(px(4))
                    .px(px(4))
                    .h(px(itemHeight))
                    .flexNone()
                    .whitespaceNowrap()
                    .overflowHidden()
                    .onMouseDown(MouseButton.Left, (_, _, cx) -> {
                        widget.selectAt(index);
                        cx.stopPropagation();
                    });
                if (focused) {
                    row.bg(selectedBackground).textColor(selectedForeground);
                }
                if (options.showIcons) {
                    // the codicon of the kind (a 16px codicon, `margin-right: 4px`)
                    final svg = Codicons.svg(codicon);
                    final iconColor = codiconColor(editor, codicon, focused ? selectedForeground : foreground, focused);
                    if (svg != null) {
                        row.child(Icon.empty().data(svg).withSize(16).textColor(iconColor).flexNone());
                    }
                    else {
                        row.child(Icon.empty().data(SymbolIcons.codiconSvg(codicon)).withSize(16).textColor(iconColor).flexNone());
                    }
                }
                final labelElement = new StyledText(text).withHighlights(highlights);
                final labelBox = div().flexNone().child(labelElement);
                if (deprecated) {
                    labelBox.lineThrough().opacity(0.66);
                }
                row.child(labelBox);
                if (labelDetail != null && labelDetail.length > 0) {
                    row.child(div().flexNone().textColor(mutedForeground).child(labelDetail));
                }
                final right = div().flex1().minW0().flex().flexRow().justifyEnd().overflowHidden().textColor(mutedForeground);
                if (labelDescription != null && labelDescription.length > 0) {
                    right.child(labelDescription);
                }
                else if (focused && options.showInlineDetails && !widget._isDetailsVisible() && item.completion.detail != null) {
                    right.child(item.completion.detail);
                }
                row.child(right);
                list.child(row);
            }
        }

        // the scrollbar of the list (Monaco's list: a 10 pixel scrollbar on
        // the right of the rows, inside the border, not over the status bar)
        if (widget.message == null && widget.items.length > widget.visibleRowCount()) {
            final handle = widget.listScrollHandle();
            list.relative().child(div().absolute().top0().left0().right0().h(px(listHeight))
                .child(Scrollbar.vertical(handle).id('cityscape-suggest-scrollbar').viewportFromLayout().styles(EditorWidgets.widgetScrollbarStyles(editor))));
        }

        final anchors:ContentWidgetAnchors = {
            primary: anchor,
            secondary: null,
            editor: editorBounds,
            typicalFullwidthCharacterWidth: fontInfo.typicalFullwidthCharacterWidth,
            page: overflowPage
        };
        // `SuggestContentWidget.beforeRender`: the size the box is found for
        final placementSize = new Size(size.width + 2 * info.borderWidth + info.horizontalPadding, size.height + 2 * info.borderWidth);
        var placedList:Null<Bounds> = null;
        var placedDetails:Null<Bounds> = null;
        final positioner = new ContentWidgetPositioner(anchors, false)
            .preferences([preference])
            .beforeRender(placementSize)
            .onPlacement(placement -> {
                placedList = placement.bounds;
                widget.setDrawnBounds(placedList, null);
            })
            .child(list);

        // The details of the focused item (Monaco's details overlay), next to the list
        final focusedItem = widget.getFocusedItem();
        if (widget._isDetailsVisible() && widget.isShowingList() && focusedItem != null && SuggestWidget.canExpandCompletionItem(focusedItem.item)) {
            final completion = focusedItem.item.completion;
            final detailsLineHeight:Float = suggestLineHeight;
            final app:App = cx.app;
            // where the list will be (the positioner finds the same box)
            final side = ContentWidgetPositioner.preferredSide([preference], placementSize.height, anchor, page);
            final predicted = new Bounds(ContentWidgetPositioner.place(anchors, placementSize, page, side).origin, outerSize);
            final previous = widget.detailsBounds;
            final estimatedHeight = previous != null ? previous.size.height - info.borderHeight : 0.0;
            final layout = SuggestDetailsPlacement.compute(predicted, new Size(SuggestDetailsPlacement.DEFAULT_WIDTH, estimatedHeight), page, info, detailsLineHeight);
            final details = div()
                .id('cityscape-suggest-details')
                .flex()
                .flexCol()
                .gap(px(4))
                .w(px(layout.width + info.borderHeight))
                .minH(px(layout.minHeight + info.borderHeight))
                .maxH(px(layout.maxHeight + info.borderHeight))
                .flexNone()
                .p(px(6))
                .bg(background)
                .border1()
                .borderColor(border)
                .rounded(px(3))
                .shadowMd()
                .overflowHidden()
                .textColor(foreground)
                .textSize(px(suggestFontSize));
            if (completion.detail != null && completion.detail.length > 0) {
                details.child(div().fontFamily(fontFamily).textColor(mutedForeground).child(completion.detail));
            }
            if (completion.documentation != null) {
                final doc:Any = completion.documentation;
                if (JsValues.isString(doc)) {
                    details.child(div().whitespaceNormal().child((doc : String)));
                }
                else {
                    details.child(cityscape.contrib.hover.view.MarkdownRenderer.render(editor, 'cityscape-suggest-doc', (doc : IMarkdownString), cx.app));
                }
            }
            final preferAlignAtTop = preference == ContentWidgetPositionPreference.BELOW;
            positioner.attach(details, (listBounds, detailsSize) -> {
                final measuredHeight = detailsSize.height - info.borderHeight;
                if (SuggestDetailsPlacement.compute(listBounds, new Size(SuggestDetailsPlacement.DEFAULT_WIDTH, measuredHeight), page, info, detailsLineHeight).kind != layout.kind) {
                    // the side was chosen on the height of the last frame
                    // (Monaco knows the height of the details before
                    // placing them): render again with this one
                    app.defer(_ -> widget.requestRender());
                }
                final placement = SuggestDetailsPlacement.compute(listBounds, new Size(layout.width, measuredHeight), page, info, detailsLineHeight, layout.kind);
                final origin = ContentWidgetPositioner.keepInPage(placement.topLeft(listBounds, detailsSize.height - info.borderHeight, preferAlignAtTop, info), detailsSize, overflowPage);
                placedDetails = new Bounds(origin, detailsSize);
                widget.setDrawnBounds(placedList, placedDetails);
                return origin;
            });
        }

        // above the parameter hints (suggest.css: z-index 40, theirs 39)
        return deferred(positioner).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY).intoAnyElement();
    }

}

/**
 * suggestWidgetDetails.ts `SuggestDetailsOverlay._placeAtAnchor`: where the
 * details go next to the list (`anchorBox`, the window bounds of the list
 * with its border): east, else west, else south (the first that fits, else
 * the least bad), their maximum sizes, and their top, on the top of the list
 * (`alignAtTop`) or their bottom on its bottom.
 */
class SuggestDetailsPlacement {

    /** suggestWidgetDetails.ts `_size = new dom.Dimension(330, 0)` */
    public static inline final DEFAULT_WIDTH = 330;

    public static inline final EAST = 0;
    public static inline final WEST = 1;
    public static inline final SOUTH = 2;

    public final kind:Int;
    public final top:Float;
    public final left:Float;
    public final maxSizeTop:Size;
    public final maxSizeBottom:Size;
    public final minSize:Size;
    /** The width of the details (content box): `min(maxSize.width, size.width)`, at least the minimum. */
    public final width:Float;
    /** The highest the details can be (`max(maxSizeTop, maxSizeBottom)`). */
    public final maxHeight:Float;
    public final minHeight:Float;

    function new(kind:Int, top:Float, left:Float, maxSizeTop:Size, maxSizeBottom:Size, minSize:Size, sizeWidth:Float) {
        this.kind = kind;
        this.top = top;
        this.left = left;
        this.maxSizeTop = maxSizeTop;
        this.maxSizeBottom = maxSizeBottom;
        this.minSize = minSize;
        this.maxHeight = Math.max(maxSizeTop.height, maxSizeBottom.height);
        this.minHeight = minSize.height;
        this.width = Math.max(minSize.width, Math.min(Math.max(maxSizeTop.width, maxSizeBottom.width), sizeWidth));
    }

    /**
     * The placements of `_placeAtAnchor` for details of `size` (content
     * box) and the one taken (`kind` forces one, -1 picks it).
     */
    public static function compute(anchorBox:Bounds, size:Size, page:Bounds, info:SuggestWidget.SuggestWidgetLayoutInfo, lineHeight:Float, kind:Int = -1):SuggestDetailsPlacement {
        final borderWidth = info.borderWidth;
        final borderHeight = info.borderHeight;
        final horizontalPadding = info.horizontalPadding;
        final verticalPadding = info.verticalPadding;
        // computed in the page (the window, or the editor with
        // `overflowWidgetsBounds: 'editor'`), the tops and lefts given back
        // in the window
        final bodyBox = page.size;
        final pageX = page.origin.x;
        final pageY = page.origin.y;
        final anchorTop = anchorBox.origin.y - pageY;
        final anchorLeft = anchorBox.origin.x - pageX;
        final anchorWidth = anchorBox.size.width;
        final anchorHeight = anchorBox.size.height;

        final defaultMinSize = new Size(220, 2 * lineHeight);
        final defaultTop = anchorTop;

        // EAST
        final eastWidth = bodyBox.width - (anchorLeft + anchorWidth + borderWidth + horizontalPadding);
        final eastMaxSizeTop = new Size(eastWidth, bodyBox.height - anchorTop - borderHeight - verticalPadding);
        final east = new SuggestDetailsPlacement(EAST, pageY + defaultTop, pageX - borderWidth + anchorLeft + anchorWidth, eastMaxSizeTop,
            new Size(eastWidth, anchorTop + anchorHeight - borderHeight - verticalPadding), new Size(Math.min(eastWidth, defaultMinSize.width), defaultMinSize.height), size.width);
        final eastFit = eastWidth - size.width;

        // WEST
        final westWidth = anchorLeft - borderWidth - horizontalPadding;
        final west = new SuggestDetailsPlacement(WEST, pageY + defaultTop, pageX + Math.max(horizontalPadding, anchorLeft - size.width - borderWidth), new Size(westWidth, bodyBox.height - anchorTop - borderHeight - verticalPadding),
            new Size(westWidth, anchorTop + anchorHeight - borderHeight - verticalPadding), new Size(Math.min(westWidth, defaultMinSize.width), defaultMinSize.height), size.width);
        final westFit = westWidth - size.width;

        // SOUTH
        final southMaxSizeBottom = new Size(anchorWidth - borderHeight, bodyBox.height - anchorTop - anchorHeight - verticalPadding);
        final south = new SuggestDetailsPlacement(SOUTH, pageY - borderWidth + anchorTop + anchorHeight, pageX + anchorLeft, southMaxSizeBottom, southMaxSizeBottom,
            new Size(southMaxSizeBottom.width, defaultMinSize.height), size.width);
        final southFit = southMaxSizeBottom.height - size.height;

        if (kind == EAST) return east;
        if (kind == WEST) return west;
        if (kind == SOUTH) return south;

        // take first placement that fits or the first with "least bad" fit
        if (eastFit >= 0) return east;
        if (westFit >= 0) return west;
        if (southFit >= 0) return south;
        // a stable sort on the fit, descending
        var best = east;
        var bestFit = eastFit;
        if (westFit > bestFit) {
            best = west;
            bestFit = westFit;
        }
        if (southFit > bestFit) {
            best = south;
        }
        return best;
    }

    /**
     * The window position of details of `height` (content box): the top
     * of the placement, or their bottom on the list's bottom when they are
     * not aligned at the top and higher than the list.
     */
    public function topLeft(anchorBox:Bounds, height:Float, preferAlignAtTop:Bool, info:SuggestWidget.SuggestWidgetLayoutInfo):Point {
        // top/bottom placement
        final bottom = anchorBox.origin.y + anchorBox.size.height - info.borderHeight;
        var alignAtTop:Bool;
        if (height > maxHeight) {
            height = maxHeight;
        }
        if (preferAlignAtTop) {
            alignAtTop = height <= maxSizeTop.height;
        }
        else {
            alignAtTop = !(height <= maxSizeBottom.height);
        }
        var y = top;
        if (!alignAtTop && height > anchorBox.size.height) {
            y = bottom - height;
        }
        return new Point(left, y);
    }

}
