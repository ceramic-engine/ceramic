// Ported from vscode src/vs/editor/contrib/rename/browser/renameWidget.ts
// (and the look of renameWidget.css), with the input of the Glaze kit
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.rename.view;

import cityscape.base.common.Cancellation.CancellationTokenSource;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.Bounds;
import glaze.BoxShadow;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.HitboxBehavior;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.input.Input;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

/**
 * Where the new name came from (Monaco's `NewNameSource`): `'inputField'`,
 * `'renameSuggestion'` or `'userEditedRenameSuggestion'`. Without the new
 * symbol names providers, always `'inputField'`.
 */
typedef NewNameSource = {
    final k:String;
}

/**
 * Various statistics regarding rename input field
 */
typedef RenameWidgetStats = {
    final nRenameSuggestions:Int;
    final source:NewNameSource;
    final timeBeforeFirstInputFieldEdit:Null<Float>;
    final nRenameSuggestionsInvocations:Int;
    final hadAutomaticRenameSuggestionsInvocation:Bool;
}

typedef RenameWidgetResult = {
    /**
     * The new name to be used
     */
    final newName:String;
    @:optional final wantsPreview:Null<Bool>;
    final stats:RenameWidgetStats;
}

/**
 * The rename input of an editor (Monaco's `RenameWidget`, a content widget
 * at the start of the renamed range): the kit's `Input` in a box with
 * Monaco's look, placed below the line (above when there is no room below,
 * `ContentWidgetPositionPreference.BELOW` then `ABOVE`, or the reverse when
 * the room below is short). It holds the name and its selection; Enter
 * accepts, Escape cancels, the editor losing the focus cancels.
 *
 * Not ported: the new symbol names suggestions (the candidate list, its
 * button and the `NewSymbolNamesProvider`s are not ported) and the preview
 * label (`{0} to Rename, {1} to Preview`, shown only with a preview service,
 * which the standalone editor has not).
 */
class RenameWidget implements IOverlayWidget implements IDisposable {

    static var _CONTEXT_RENAME_INPUT_VISIBLE:Null<RawContextKey<Bool>> = null;

    /**
     * `renameInputVisible`: whether the rename input widget is visible.
     */
    public static var CONTEXT_RENAME_INPUT_VISIBLE(get, never):RawContextKey<Bool>;
    static function get_CONTEXT_RENAME_INPUT_VISIBLE():RawContextKey<Bool> {
        if (_CONTEXT_RENAME_INPUT_VISIBLE == null) {
            _CONTEXT_RENAME_INPUT_VISIBLE = new RawContextKey<Bool>('renameInputVisible', false, "Whether the rename input widget is visible");
        }
        return _CONTEXT_RENAME_INPUT_VISIBLE;
    }

    static var _CONTEXT_RENAME_INPUT_FOCUSED:Null<RawContextKey<Bool>> = null;

    /**
     * `renameInputFocused`: whether the rename input widget is focused
     * (declared by Monaco 0.52, which does not bind it).
     */
    public static var CONTEXT_RENAME_INPUT_FOCUSED(get, never):RawContextKey<Bool>;
    static function get_CONTEXT_RENAME_INPUT_FOCUSED():RawContextKey<Bool> {
        if (_CONTEXT_RENAME_INPUT_FOCUSED == null) {
            _CONTEXT_RENAME_INPUT_FOCUSED = new RawContextKey<Bool>('renameInputFocused', false, "Whether the rename input widget is focused");
        }
        return _CONTEXT_RENAME_INPUT_FOCUSED;
    }

    final _editor:ICodeEditor;
    final _acceptKeybindings:Array<String>;
    final _visibleContextKey:IContextKey<Bool>;
    final _disposables = new DisposableStore();

    var _view:Null<Entity<RenameWidgetView>> = null;
    var _input:Null<Entity<InputState>> = null;
    var _app:Null<App> = null;

    // Model state

    var _position:Null<Position> = null;
    var _currentName:Null<String> = null;
    var _visible:Bool = false;
    var _renameCts:Null<CancellationTokenSource> = null;
    var _beforeFirstInputFieldEditStart:Float = 0;
    var _timeBeforeFirstInputFieldEdit:Null<Float> = null;

    /**
     * The text of the input (the kit input's value, kept here so that the
     * widget works without a view, in tests).
     */
    var _inputValue:String = '';

    /**
     * The selection of the input, in UTF-16 units of the name.
     */
    var _selectionStart:Int = 0;
    var _selectionEnd:Int = 0;

    /**
     * Monaco's `input.size` (the width of the input in characters).
     */
    var _inputSize:Float = 20;

    /**
     * Changes each time the input is shown with a value (the view then
     * gives the value, the selection and the focus to the kit input).
     */
    var _session:Int = 0;

    var _currentAcceptInput:Null<(wantsPreview:Bool) -> Void> = null;
    var _currentCancelInput:Null<(focusEditor:Bool) -> Void> = null;

    /**
     * `_acceptKeybindings`: the ids of the accept and accept with preview
     * commands (their keybindings make the label of the preview mode).
     */
    public function new(editor:ICodeEditor, acceptKeybindings:Array<String>, contextKeyService:IContextKeyService) {
        this._editor = editor;
        this._acceptKeybindings = acceptKeybindings;
        this._visibleContextKey = CONTEXT_RENAME_INPUT_VISIBLE.bindTo(contextKeyService);

        this._editor.addOverlayWidget(this);

        this._disposables.add(this._editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.fontInfo)) {
                this.changed();
            }
        }));
        this._disposables.add(this._editor.context.themeService.onDidColorThemeChange(_ -> this.changed()));
    }

    public function dispose():Void {
        this._disposables.dispose();
        this._editor.removeOverlayWidget(this);
        cityscape.view.ViewEntities.release(this._input);
        this._input = null;
        cityscape.view.ViewEntities.release(this._view);
        this._view = null;
    }

    public function getId():String {
        return '__renameInputWidget';
    }

    /**
     * Null: the Glaze view places itself next to the renamed range (Monaco's
     * content widget position, `getPosition`).
     */
    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        var v = _view;
        if (v == null) {
            _app = cx;
            final input = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:Context<InputState>) -> new InputState(window, c)), cx);
            _input = input;
            v = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:Context<RenameWidgetView>) -> new RenameWidgetView(this, _editor, input, window, c)), cx);
            _view = v;
        }
        return v;
    }

    /**
     * Renders the view again (or the editor, before the view exists).
     */
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

    public var isVisible(get, never):Bool;
    function get_isVisible():Bool {
        return _visible;
    }

    /**
     * Where the widget is (the start of the renamed range), null when hidden.
     */
    public function getWidgetPosition():Null<Position> {
        return _visible ? _position : null;
    }

    /**
     * The text of the input.
     */
    public function getInputValue():String {
        return _inputValue;
    }

    /**
     * The selection of the input (UTF-16 offsets in the name).
     */
    public function getInputSelection():{start:Int, end:Int} {
        return {start: _selectionStart, end: _selectionEnd};
    }

    /**
     * The width of the input in characters (Monaco's `input.size`).
     */
    public function getInputSize():Float {
        return _inputSize;
    }

    /**
     * Sets the text of the input, as typed (the view calls it on each
     * change of the kit input; tests call it to type a name).
     */
    public function setInputValue(value:String):Void {
        if (value == _inputValue) {
            return;
        }
        _inputValue = value;
        if (_timeBeforeFirstInputFieldEdit == null) {
            _timeBeforeFirstInputFieldEdit = (haxe.Timer.stamp() - _beforeFirstInputFieldEditStart) * 1000;
        }
    }

    @:allow(cityscape.contrib.rename.view)
    function session():Int {
        return _session;
    }

    public function acceptInput(wantsPreview:Bool):Void {
        final f = this._currentAcceptInput;
        if (f != null) {
            f(wantsPreview);
        }
    }

    public function cancelInput(focusEditor:Bool, caller:String):Void {
        final f = this._currentCancelInput;
        if (f != null) {
            f(focusEditor);
        }
    }

    /**
     * Shows the input over `where` with `currentName`, and resolves with
     * the new name (`RenameWidgetResult`) when accepted, or with a `Bool`
     * (whether to focus the editor) when cancelled.
     */
    public function getInput(where:IRange, currentName:String, supportPreview:Bool, cts:CancellationTokenSource):Promise<Any> {

        final selection = this._getSelection(where, currentName);

        this._renameCts = cts;

        final disposeOnDone = new DisposableStore();

        this._position = new Position(where.startLineNumber, where.startColumn);
        this._currentName = currentName;

        this._inputValue = currentName;
        this._selectionStart = selection.start;
        this._selectionEnd = selection.end;
        this._inputSize = Math.max((where.endColumn - where.startColumn) * 1.1, 20); // determines width
        this._session++;

        this._beforeFirstInputFieldEditStart = haxe.Timer.stamp();
        this._timeBeforeFirstInputFieldEdit = null;

        disposeOnDone.add(Lifecycle.toDisposable(() -> {
            this._renameCts = null;
            cts.dispose(true);
        }));

        var complete:Null<(value:Any) -> Void> = null;
        final inputResult = new Promise<Any>((resolve, _) -> complete = resolve);

        inputResult.finally(() -> {
            disposeOnDone.dispose();
            this._hide();
        });

        this._currentCancelInput = (focusEditor) -> {
            this._currentAcceptInput = null;
            this._currentCancelInput = null;
            complete(focusEditor);
        };

        this._currentAcceptInput = (wantsPreview) -> {
            final newName = this._inputValue;
            final source:NewNameSource = {k: 'inputField'};

            if (newName == currentName || StringTools.trim(newName).length == 0 /* is just whitespace */) {
                this.cancelInput(true, '_currentAcceptInput (because newName === value || newName.trim().length === 0)');
                return;
            }

            this._currentAcceptInput = null;
            this._currentCancelInput = null;

            final result:RenameWidgetResult = {
                newName: newName,
                wantsPreview: supportPreview && wantsPreview,
                stats: {
                    source: source,
                    nRenameSuggestions: 0,
                    timeBeforeFirstInputFieldEdit: this._timeBeforeFirstInputFieldEdit,
                    nRenameSuggestionsInvocations: 0,
                    hadAutomaticRenameSuggestionsInvocation: false
                }
            };
            complete(result);
        };

        disposeOnDone.add(cts.token.onCancellationRequested(() -> this.cancelInput(true, 'cts.token.onCancellationRequested')));
        // Monaco passes `!document.hasFocus()` (focus the editor again when
        // the whole window lost the focus); the focus went elsewhere in the
        // application here
        disposeOnDone.add(this._editor.onDidBlurEditorWidget(() -> this.cancelInput(false, 'editor.onDidBlurEditorWidget')));

        this._show();

        return inputResult;
    }

    /**
     * This allows selecting only part of the symbol name in the input field based on the selection in the editor
     */
    function _getSelection(where:IRange, currentName:String):{start:Int, end:Int} {
        final selection = this._editor.getSelection();
        var start = 0;
        var end = currentName.length;

        if (selection != null && !selection.isEmpty() && selection.startLineNumber == selection.endLineNumber && Range.containsRangeStatic(where, selection)) {
            start = Std.int(Math.max(0, selection.startColumn - where.startColumn));
            end = Std.int(Math.min(where.endColumn, selection.endColumn)) - where.startColumn;
        }

        return {start: start, end: end};
    }

    function _show():Void {
        this._editor.revealLineInCenterIfOutsideViewport(this._position.lineNumber, ScrollType.Smooth);
        this._visible = true;
        this._visibleContextKey.set(true);
        this.changed();
    }

    function _hide():Void {
        this._visible = false;
        this._visibleContextKey.reset();
        this.changed();
    }

}

/**
 * The Glaze view of the rename widget: `.rename-box` (renameWidget.css and
 * `_updateStyles`: `editorWidget.background`, a `0 0 8px 2px widget.shadow`
 * shadow, a `widget.border` border when the theme has one, 4 pixel
 * corners, at least 200 pixels wide) around `.rename-input-with-button`
 * (3 pixels of padding, `input.background`, an `input.border` border when
 * the theme has one, a `focusBorder` outline while focused) holding the
 * kit input in the editor's font, `input.size` characters wide.
 */
class RenameWidgetView extends Model implements Render {

    /**
     * `RenameCandidateView._PADDING`
     */
    static inline final CANDIDATE_PADDING = 2;

    final widget:RenameWidget;
    final editor:ICodeEditor;
    final input:Entity<InputState>;
    final window:Window;
    final app:App;
    final _subscriptions:Array<Subscription>;
    var _session:Int = 0;

    public var bounds(default, null):Null<Bounds> = null;
    public var preference(default, null):Null<ContentWidgetPositionPreference> = null;

    public function new(widget:RenameWidget, editor:ICodeEditor, input:Entity<InputState>, window:Window, cx:Context<RenameWidgetView>) {
        super();
        this.widget = widget;
        this.editor = editor;
        this.input = input;
        this.window = window;
        this.app = cx.app;
        _subscriptions = [
            cx.subscribe(input, InputEvent, (this_:RenameWidgetView, _, ev:InputEvent, cx:Context<RenameWidgetView>) -> {
                switch ev {
                    case Change:
                        if (this_._session == this_.widget.session()) {
                            this_.widget.setInputValue(this_.input.read(cx).value());
                        }
                    case _:
                }
            })
        ];
    }

    /**
     * The UTF-8 byte offset of a UTF-16 offset of `text` (the kit input's
     * selection is in bytes).
     */
    static function utf8Offset(text:String, utf16Offset:Int):Int {
        var bytes = 0;
        var i = 0;
        final end = Std.int(Math.min(utf16Offset, text.length));
        while (i < end) {
            final c = StringTools.fastCodeAt(text, i);
            if (c < 0x80) {
                bytes += 1;
            }
            else if (c < 0x800) {
                bytes += 2;
            }
            else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
                bytes += 4;
                i++;
            }
            else {
                bytes += 3;
            }
            i++;
        }
        return bytes;
    }

    function startSession():Void {
        // a new name to edit: the value, the selection and the focus (Monaco
        // focuses the input and selects 100 ms after showing it)
        _session = widget.session();
        final value = widget.getInputValue();
        final selection = widget.getInputSelection();
        final start = utf8Offset(value, selection.start);
        final end = utf8Offset(value, selection.end);
        final window = this.window;
        app.defer(_ -> {
            input.update(app, (s, c) -> {
                s.setValue(value, window, cast c);
                s.focus(window, cast c);
                s.setSelection(start, end);
            });
        });
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final position = widget.getWidgetPosition();
        if (position == null || !editor.hasModel()) {
            bounds = null;
            return new Empty();
        }
        if (_session != widget.session()) {
            startSession();
        }
        final primary = EditorWidgets.positionBounds(editor, position);
        final editorBounds = EditorWidgets.editorBounds(editor);
        if (primary == null || editorBounds == null || !EditorWidgets.isPositionVisible(editor, position)) {
            // Monaco: cancel rename when input widget isn't rendered anymore
            final w = widget;
            app.defer(_ -> w.cancelInput(true, 'afterRender (because position is null)'));
            bounds = null;
            return new Empty();
        }

        final theme = Theme.global(cx);
        final fontInfo = editor.getOption(EditorOption.fontInfo);
        final background = EditorWidgets.color(editor, 'editorWidget.background', theme.popover);
        final widgetShadow = EditorWidgets.themeColor(editor, 'widget.shadow');
        final widgetBorder = EditorWidgets.themeColor(editor, 'widget.border');
        final foreground = EditorWidgets.color(editor, 'input.foreground', theme.foreground);
        final inputBackground = EditorWidgets.themeColor(editor, 'input.background');
        final inputBorder = EditorWidgets.themeColor(editor, 'input.border');
        final focusBorder = EditorWidgets.themeColor(editor, 'focusBorder');
        final focused = input.read(cx).focusHandle.isFocused(window);

        // getPosition: below the line when there is room for about six
        // candidates below, else above
        final lineHeight = fontInfo.lineHeight;
        final candidateViewHeight = lineHeight + CANDIDATE_PADDING * 2;
        final nPxAvailableAbove = primary.origin.y;
        final nPxAvailableBelow = window.viewportSize().height - nPxAvailableAbove;
        final preferences:Array<ContentWidgetPositionPreference> = nPxAvailableBelow > candidateViewHeight * 6 ? [BELOW, ABOVE] : [ABOVE, BELOW];

        // the input: `size` characters of the editor's font
        final inputWidth = Math.ceil(widget.getInputSize() * fontInfo.typicalHalfwidthCharacterWidth);
        final inputElement = Input.component(input)
            .appearance(false)
            .w(px(inputWidth))
            .fontFamily(EditorWidgets.editorFontFamily(editor))
            .textSize(px(fontInfo.fontSize))
            .lineHeight(px(lineHeight))
            .textColor(foreground);

        // `.rename-input-with-button`
        final inputWithButton = div()
            .id('cityscape-rename-input')
            .flex()
            .flexRow()
            .itemsCenter()
            .p(px(3))
            .rounded(px(2))
            .child(inputElement);
        if (inputBackground != null) {
            inputWithButton.bg(inputBackground);
        }
        if (focused && focusBorder != null) {
            inputWithButton.border1().borderColor(focusBorder);
        }
        else if (inputBorder != null) {
            inputWithButton.border1().borderColor(inputBorder);
        }

        // `.rename-box`
        final box = div()
            .id('cityscape-rename-box')
            .keyContext('CityscapeRenameWidget')
            .flex()
            .flexCol()
            .minW(px(200))
            .rounded(px(4))
            .bg(background)
            .textColor(foreground)
            .onAction(Enter, (_:Enter, _:Window, cx:App) -> {
                cx.stopPropagation();
                widget.acceptInput(false);
            })
            .onAction(Escape, (_:Escape, _:Window, cx:App) -> {
                cx.stopPropagation();
                widget.cancelInput(true, 'cancelRenameInput command');
            })
            .child(div().pr(px(8)).child(inputWithButton));
        if (widgetShadow != null) {
            box.shadow([new BoxShadow(0, 0, widgetShadow).withBlurRadius(8).withSpreadRadius(2)]);
        }
        if (widgetBorder != null) {
            box.border1().borderColor(widgetBorder);
        }

        // ContentWidgets._prepareRenderWidget with the widget's preferences
        final positioner = new ContentWidgetPositioner({
            primary: primary,
            secondary: null,
            editor: editorBounds,
            typicalFullwidthCharacterWidth: fontInfo.typicalFullwidthCharacterWidth
        }, false)
            .preferences(preferences)
            .onPlacement(placement -> {
                bounds = placement.bounds;
                preference = placement.preference;
            })
            .child(box);
        return deferred(positioner).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY).intoAnyElement();
    }

}
