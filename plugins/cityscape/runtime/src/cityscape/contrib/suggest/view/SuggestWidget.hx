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
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import cityscape.view.SymbolIcons;
import glaze.App;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.HighlightStyle;
import glaze.HighlightStyle.TextHighlight;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Render;
import glaze.StyledText;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.base.Geometry.Placement;
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
 * Not ported: the resizing sash and the persisted size, the status bar, the
 * explain mode details, the aria announcements.
 */
class SuggestWidget implements IDisposable {

    public static final LOADING_MESSAGE = 'Loading...';
    public static final NO_SUGGESTIONS_MESSAGE = 'No suggestions.';

    /**
     * The number of rows shown at most (Monaco shows 12 by default).
     */
    public static inline final MAX_VISIBLE_ITEMS = 12;

    final editor:ICodeEditor;

    var _state:SuggestWidgetState = SuggestWidgetState.Hidden;
    var _isAuto:Bool = false;
    var _loadingTimeout:Null<IDisposable> = null;
    var _currentSuggestionDetails:Null<CancellationTokenSource> = null;
    var _focusedItem:Null<CompletionItem> = null;
    var _ignoreFocusEvents:Bool = false;
    var _completionModel:Null<CompletionModel> = null;
    var _detailsVisible:Bool = false;

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
        else if (index >= firstVisibleIndex + MAX_VISIBLE_ITEMS) {
            firstVisibleIndex = index - MAX_VISIBLE_ITEMS + 1;
        }
    }

    /**
     * Scrolls the list by `delta` rows (the mouse wheel over the list).
     */
    public function scrollBy(delta:Int):Void {
        final max = Std.int(Math.max(0, items.length - MAX_VISIBLE_ITEMS));
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
        firstVisibleIndex = Std.int(Math.max(0, Math.min(selectionIndex, items.length - MAX_VISIBLE_ITEMS)));
        _setFocus(noFocus ? -1 : selectionIndex);
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
                final lastVisible = Std.int(Math.min(items.length - 1, firstVisibleIndex + MAX_VISIBLE_ITEMS - 1));
                if (focusedIndex != lastVisible) {
                    _setFocus(lastVisible);
                }
                else {
                    _setFocus(Std.int(Math.min(items.length - 1, lastVisible + MAX_VISIBLE_ITEMS - 1)));
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
                    _setFocus(Std.int(Math.max(0, firstVisible - MAX_VISIBLE_ITEMS + 1)));
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

    public function forceRenderingAbove():Void {}

    public function stopForceRenderingAbove():Void {}

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

    static function codiconColor(editor:ICodeEditor, codicon:String, foreground:Hsla):Hsla {
        final dark = EditorWidgets.isDark(editor);
        final key = switch codicon {
            case 'symbol-method': 'symbolIcon.methodForeground';
            case 'symbol-function': 'symbolIcon.functionForeground';
            case 'symbol-constructor': 'symbolIcon.constructorForeground';
            case 'symbol-field': 'symbolIcon.fieldForeground';
            case 'symbol-variable': 'symbolIcon.variableForeground';
            case 'symbol-class': 'symbolIcon.classForeground';
            case 'symbol-interface': 'symbolIcon.interfaceForeground';
            case 'symbol-enum': 'symbolIcon.enumeratorForeground';
            case 'symbol-enum-member': 'symbolIcon.enumeratorMemberForeground';
            case 'symbol-event': 'symbolIcon.eventForeground';
            case _: null;
        };
        if (key != null) {
            final c = EditorWidgets.themeColor(editor, key);
            if (c != null) {
                return c;
            }
        }
        // symbolIcons.ts defaults
        return switch codicon {
            case 'symbol-method' | 'symbol-function' | 'symbol-constructor': dark ? rgb(0xB180D7).toHsla() : rgb(0x652D90).toHsla();
            case 'symbol-field' | 'symbol-variable' | 'symbol-interface' | 'symbol-enum-member': dark ? rgb(0x75BEFF).toHsla() : rgb(0x007ACC).toHsla();
            case 'symbol-class' | 'symbol-enum' | 'symbol-event': dark ? rgb(0xEE9D28).toHsla() : rgb(0xD67E00).toHsla();
            case _: foreground;
        };
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
        if (anchor == null) {
            return new Empty();
        }

        final listWidth = 430.0;
        final list = div()
            .id('cityscape-suggest-list')
            .flex()
            .flexCol()
            .w(px(listWidth))
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
                final delta = glaze.ScrollDelta.ScrollDeltaTools.pixelDelta(event.delta, suggestLineHeight);
                widget.scrollBy(delta.y < 0 ? 1 : (delta.y > 0 ? -1 : 0));
                cx.stopPropagation();
            });

        if (widget.message != null) {
            list.child(div().px2().h(px(suggestLineHeight)).flex().itemsCenter().textColor(mutedForeground).child(widget.message));
        }
        else {
            final start = widget.firstVisibleIndex;
            final end = Std.int(Math.min(widget.items.length, start + SuggestWidget.MAX_VISIBLE_ITEMS));
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
                    .h(px(suggestLineHeight))
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
                    row.child(Icon.empty().data(SymbolIcons.codiconSvg(codicon)).withSize(Math.round(suggestFontSize * 1.15)).textColor(codiconColor(editor, codicon, foreground)).flexNone());
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

        final content = div().flex().flexRow().itemsStart().gap(px(2)).child(list);

        // The details of the focused item (Monaco's details widget), next to the list
        final focusedItem = widget.getFocusedItem();
        if (widget._isDetailsVisible() && focusedItem != null && SuggestWidget.canExpandCompletionItem(focusedItem.item)) {
            final completion = focusedItem.item.completion;
            final details = div()
                .id('cityscape-suggest-details')
                .flex()
                .flexCol()
                .gap(px(4))
                .w(px(360))
                .maxH(px(suggestLineHeight * SuggestWidget.MAX_VISIBLE_ITEMS))
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
            content.child(details);
        }

        return EditorWidgets.popup(anchor, Placement.Bottom, content);
    }

}
