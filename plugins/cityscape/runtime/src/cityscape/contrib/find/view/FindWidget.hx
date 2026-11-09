// New code for Cityscape (not a port): the find widget of an editor built
// with the Glaze kit (inputs, toggle buttons, buttons), with the behaviour of
// Monaco's FindWidget (src/vs/editor/contrib/find/browser/findWidget.ts):
// the state it shows and changes, the match count, the enabled buttons, the
// keys of its inputs.
package cityscape.contrib.find.view;

import cityscape.base.common.Lifecycle.DisposableStore;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.base.common.Color;
import cityscape.platform.contextkey.common.ContextKey.IContextKey;
import cityscape.view.EditorBrowser;
import cityscape.contrib.find.view.FindController;
import cityscape.contrib.find.view.FindModel;
import cityscape.contrib.find.view.FindState;
import glaze.App;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.IconName;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.button.Button;
import glaze.kit.input.Input;
import glaze.kit.label.Label;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

/**
 * The English labels of Monaco's find widget (the NLS keys of
 * findWidget.ts in comments).
 */
class FindWidgetLabels {
    public static inline final FIND_DIALOG_LABEL = 'Find / Replace'; // label.findDialog
    public static inline final FIND_INPUT_PLACEHOLDER = 'Find'; // placeholder.find
    public static inline final PREVIOUS_MATCH_BTN_LABEL = 'Previous Match'; // label.previousMatchButton
    public static inline final NEXT_MATCH_BTN_LABEL = 'Next Match'; // label.nextMatchButton
    public static inline final TOGGLE_SELECTION_FIND_TITLE = 'Find in Selection'; // label.toggleSelectionFind
    public static inline final CLOSE_BTN_LABEL = 'Close'; // label.closeButton
    public static inline final REPLACE_INPUT_PLACEHOLDER = 'Replace'; // placeholder.replace
    public static inline final REPLACE_BTN_LABEL = 'Replace'; // label.replaceButton
    public static inline final REPLACE_ALL_BTN_LABEL = 'Replace All'; // label.replaceAllButton
    public static inline final TOGGLE_REPLACE_MODE_BTN_LABEL = 'Toggle Replace'; // label.toggleReplaceButton
    public static inline final MATCHES_LOCATION = '{0} of {1}'; // label.matchesLocation
    public static inline final NO_RESULTS = 'No results'; // label.noResults
    public static inline final CASE_SENSITIVE = 'Match Case'; // caseDescription (findInputToggles.ts)
    public static inline final WHOLE_WORDS = 'Match Whole Word'; // wordsDescription
    public static inline final REGEX = 'Use Regular Expression'; // regexDescription
    public static inline final PRESERVE_CASE = 'Preserve Case'; // preserveCaseDescription (replaceInput.ts)
}

/**
 * The find widget of one editor, shown at the top right corner of the
 * editor while the find state is revealed. Its inputs and buttons are the
 * kit's; colors come from the VS Code theme of the editor when it has them
 * (`editorWidget.background`, `editorWidget.border`, `input.*`,
 * `inputOption.*`), else from the kit theme.
 */
class FindWidget extends Model implements Render implements IFindWidget {

    /**
     * Monaco's `FIND_WIDGET_INITIAL_WIDTH`.
     */
    public static inline final FIND_WIDGET_INITIAL_WIDTH = 419;

    final controller:FindController;
    final state:FindReplaceState;
    final editor:ICodeEditor;
    final window:Window;
    final app:App;

    /**
     * Theme colors of the editor by key (null when the theme has none).
     */
    final themeColor:(key:String) -> Null<Hsla>;

    public final findInput:Entity<InputState>;
    public final replaceInput:Entity<InputState>;

    final _subscriptions:Array<Subscription>;
    final _findInputFocused:IContextKey<Bool>;
    final _replaceInputFocused:IContextKey<Bool>;
    final _toDispose = new DisposableStore();

    var _isVisible = false;
    var _isReplaceVisible = false;
    var _ignoreChangeEvent = false;

    public static function create(controller:FindController, editor:ICodeEditor, themeColor:(key:String) -> Null<Hsla>, window:Window, cx:App):Entity<FindWidget> {
        final findInput = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).withPlaceholder(FindWidgetLabels.FIND_INPUT_PLACEHOLDER));
        final replaceInput = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).withPlaceholder(FindWidgetLabels.REPLACE_INPUT_PLACEHOLDER));
        return cx.newEntity((c:Context<FindWidget>) -> new FindWidget(controller, editor, themeColor, findInput, replaceInput, window, c));
    }

    function new(controller:FindController, editor:ICodeEditor, themeColor:(key:String) -> Null<Hsla>, findInput:Entity<InputState>, replaceInput:Entity<InputState>, window:Window, cx:Context<FindWidget>) {
        super();
        this.controller = controller;
        this.state = controller.getState();
        this.editor = editor;
        this.themeColor = themeColor;
        this.findInput = findInput;
        this.replaceInput = replaceInput;
        this.window = window;
        this.app = cx.app;
        this._findInputFocused = FindModel.CONTEXT_FIND_INPUT_FOCUSED.bindTo(controller.contextKeyService);
        this._replaceInputFocused = FindModel.CONTEXT_REPLACE_INPUT_FOCUSED.bindTo(controller.contextKeyService);

        _subscriptions = [
            cx.subscribe(findInput, InputEvent, (this_:FindWidget, _, ev:InputEvent, cx:Context<FindWidget>) -> {
                switch ev {
                    case Change:
                        if (!this_._ignoreChangeEvent) {
                            this_.state.change({searchString: this_.findInput.read(cx).value()}, true);
                        }
                    case Focus:
                        this_._findInputFocused.set(true);
                        this_._updateSearchScope();
                    case Blur:
                        this_._findInputFocused.set(false);
                    case _:
                }
            }),
            cx.subscribe(replaceInput, InputEvent, (this_:FindWidget, _, ev:InputEvent, cx:Context<FindWidget>) -> {
                switch ev {
                    case Change:
                        if (!this_._ignoreChangeEvent) {
                            this_.state.change({replaceString: this_.replaceInput.read(cx).value()}, false);
                        }
                    case Focus:
                        this_._replaceInputFocused.set(true);
                        this_._updateSearchScope();
                    case Blur:
                        this_._replaceInputFocused.set(false);
                    case _:
                }
            }),
        ];

        _toDispose.add(state.onFindReplaceStateChange(e -> _onStateChanged(e)));
        _toDispose.add(editor.onDidChangeCursorSelection(_ -> {
            if (_isVisible) {
                _notify();
            }
        }));

        // The widget is created when the find widget is first shown: start
        // from the current state
        _ignoreChangeEvent = true;
        findInput.update(app, (s, c) -> s.setValue(state.searchString, window, cast c));
        replaceInput.update(app, (s, c) -> s.setValue(state.replaceString, window, cast c));
        _ignoreChangeEvent = false;
        _isVisible = state.isRevealed;
        _isReplaceVisible = state.isReplaceRevealed && !editor.getOption(EditorOption.readOnly);
    }

    /**
     * Releases the listeners of the widget (the contribution calls it).
     */
    public function release():Void {
        _toDispose.dispose();
        for (s in _subscriptions) {
            s.dispose();
        }
    }

    function _notify():Void {
        app.notify(entityId);
    }

    /**
     * Monaco's `_updateSearchScope`: when the search is in the selection and
     * an input gets the focus, the scope follows the current selections.
     */
    function _updateSearchScope():Void {
        if (!editor.hasModel()) {
            return;
        }
        if (state.searchScope != null) {
            final selections = editor.getSelections();
            final scopes:Array<Range> = [];
            for (s in selections) {
                var selection:Selection = s;
                if (selection.endColumn == 1 && selection.endLineNumber > selection.startLineNumber) {
                    selection = selection.setEndPosition(selection.endLineNumber - 1, editor.getModel().getLineMaxColumn(selection.endLineNumber - 1));
                }
                final currentMatch = state.currentMatch;
                if (selection.startLineNumber != selection.endLineNumber) {
                    if (!Range.equalsRangeStatic(selection, currentMatch)) {
                        scopes.push(selection);
                    }
                }
            }
            if (scopes.length > 0) {
                state.change({searchScope: scopes}, true);
            }
        }
    }

    // ----- React to state changes (Monaco's `_onStateChanged`)

    function _onStateChanged(e:FindReplaceStateChangedEvent):Void {
        if (e.searchString) {
            _setInputValue(findInput, state.searchString);
        }
        if (e.replaceString) {
            _setInputValue(replaceInput, state.replaceString);
        }
        if (e.isRevealed) {
            if (state.isRevealed) {
                _reveal();
            } else {
                _hide(true);
            }
        }
        if (e.isReplaceRevealed) {
            if (state.isReplaceRevealed) {
                if (!editor.getOption(EditorOption.readOnly) && !_isReplaceVisible) {
                    _isReplaceVisible = true;
                }
            } else {
                if (_isReplaceVisible) {
                    _isReplaceVisible = false;
                }
            }
        }
        _notify();
    }

    function _setInputValue(input:Entity<InputState>, value:String):Void {
        if (input.read(app).value() == value) {
            return;
        }
        _ignoreChangeEvent = true;
        try {
            input.update(app, (s, c) -> s.setValue(value, window, cast c));
        }
        catch (e:Dynamic) {
            _ignoreChangeEvent = false;
            throw e;
        }
        _ignoreChangeEvent = false;
    }

    function _reveal():Void {
        if (!_isVisible) {
            _isVisible = true;
        }
    }

    function _hide(focusTheEditor:Bool):Void {
        if (_isVisible) {
            _isVisible = false;
            if (focusTheEditor) {
                editor.focus();
            }
        }
    }

    /**
     * Whether the widget is shown.
     */
    public function isVisible():Bool {
        return _isVisible;
    }

    /**
     * Whether the replace row is shown.
     */
    public function isReplaceVisible():Bool {
        return _isReplaceVisible;
    }

    // ----- IFindWidget

    public function focusFindInput():Void {
        findInput.update(app, (s, c) -> {
            s.selectAll(window, cast c);
            s.focus(window, cast c);
        });
        _findInputFocused.set(true);
        _replaceInputFocused.set(false);
    }

    public function focusReplaceInput():Void {
        replaceInput.update(app, (s, c) -> {
            s.selectAll(window, cast c);
            s.focus(window, cast c);
        });
        _findInputFocused.set(false);
        _replaceInputFocused.set(true);
    }

    public function highlightFindOptions(ignoreWhenVisible:Bool):Void {
        // Monaco flashes the options of the find input, or shows them in a
        // small widget (`FindOptionsWidget`) when the find widget is closed:
        // the toggles of the open widget already show the new state.
        _notify();
    }

    // ----- The label of the match count (Monaco's `_updateMatchesCount`)

    /**
     * "No results", or "{position} of {count}" (`?` when the position is
     * not known, `+` after the count at the match limit).
     */
    public function matchesCountLabel():String {
        if (state.matchesCount > 0) {
            var matchesCount = Std.string(state.matchesCount);
            if (state.matchesCount >= FindModel.MATCHES_LIMIT) {
                matchesCount += '+';
            }
            var matchesPosition = Std.string(state.matchesPosition);
            if (matchesPosition == '0') {
                matchesPosition = '?';
            }
            return StringTools.replace(StringTools.replace(FindWidgetLabels.MATCHES_LOCATION, '{0}', matchesPosition), '{1}', matchesCount);
        }
        return FindWidgetLabels.NO_RESULTS;
    }

    // ----- Actions of the widget

    /**
     * Runs a find action of the editor (Monaco's
     * `this._codeEditor.getAction(id).run()`).
     */
    function _runAction(actionId:String):Void {
        final action = editor.getAction(actionId);
        if (action != null) {
            action.run();
        }
    }

    /**
     * Enter in the inputs (the kit's `Enter` action, with Shift and the
     * secondary modifier): in the find input, Enter goes to the next match
     * and Shift+Enter to the previous one; in the replace input, Enter
     * replaces one match and Cmd/Ctrl+Enter replaces all (Monaco's
     * keybindings with `findInputFocussed` / `replaceInputFocussed`, and
     * loreline-monaco's fix that keeps Enter from reaching the editor).
     */
    public function onEnter(secondary:Bool, shift:Bool, window:Window):Bool {
        if (replaceInput.read(app).focusHandle.isFocused(window)) {
            if (secondary) {
                controller.replaceAll();
            } else {
                controller.replace();
            }
            return true;
        }
        if (findInput.read(app).focusHandle.isFocused(window)) {
            _runAction(shift ? FIND_IDS.PreviousMatchFindAction : FIND_IDS.NextMatchFindAction);
            return true;
        }
        return false;
    }

    /**
     * Tab and Shift+Tab move between the inputs (Monaco also stops on the
     * toggles and buttons).
     */
    function _onTab(backwards:Bool, window:Window):Void {
        final inFind = findInput.read(app).focusHandle.isFocused(window);
        if (inFind) {
            if (_isReplaceVisible) {
                focusReplaceInput();
            }
        } else {
            focusFindInput();
        }
    }

    function _toggleSelectionFind():Void {
        if (state.searchScope == null) {
            if (editor.hasModel()) {
                final selections:Array<Range> = [];
                for (s in editor.getSelections()) {
                    var selection:Selection = s;
                    if (selection.endColumn == 1 && selection.endLineNumber > selection.startLineNumber) {
                        selection = selection.setEndPosition(selection.endLineNumber - 1, editor.getModel().getLineMaxColumn(selection.endLineNumber - 1));
                    }
                    if (!selection.isEmpty()) {
                        selections.push(selection);
                    }
                }
                if (selections.length > 0) {
                    state.change({searchScope: selections}, true);
                }
            }
        } else {
            state.change({searchScope: null}, true);
        }
    }

    // ----- Rendering

    function color(key:String, fallback:Hsla):Hsla {
        final c = themeColor(key);
        return c != null ? c : fallback;
    }

    /**
     * The color of the icons of the buttons (`icon.foreground`, else the
     * widget foreground), set at each render.
     */
    var _iconColor:Null<Hsla> = null;

    function optionToggle(id:String, icon:IconName, checked:Bool, tooltip:String, theme:Theme, onToggle:() -> Void):Button {
        final button = Button.component(id)
            .ghost()
            .xsmall()
            .compact()
            .icon(icon)
            .selected(checked)
            .toggled(checked)
            .tooltip(tooltip)
            .onClick((_:ClickEvent, _:Window, _:App) -> onToggle());
        if (_iconColor != null) {
            button.textColor(_iconColor);
        }
        if (checked) {
            final activeForeground = themeColor('inputOption.activeForeground');
            if (activeForeground != null) {
                button.textColor(activeForeground);
            }
            final activeBackground = themeColor('inputOption.activeBackground');
            if (activeBackground != null) {
                button.bg(activeBackground);
            }
            final activeBorder = themeColor('inputOption.activeBorder');
            if (activeBorder != null) {
                button.border1().borderColor(activeBorder);
            }
        }
        return button;
    }

    function actionButton(id:String, icon:IconName, tooltip:String, enabled:Bool, onTrigger:() -> Void):Button {
        final button = Button.component(id)
            .ghost()
            .xsmall()
            .icon(icon)
            .tooltip(tooltip)
            .disabled(!enabled)
            .onClick((_:ClickEvent, _:Window, _:App) -> onTrigger());
        if (enabled && _iconColor != null) {
            button.textColor(_iconColor);
        }
        return button;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        if (!_isVisible) {
            return new Empty();
        }
        final theme = Theme.global(cx);

        final background = color('editorWidget.background', theme.popover);
        final foreground = color('editorWidget.foreground', theme.popoverForeground);
        _iconColor = color('icon.foreground', foreground);
        final border = themeColor('editorWidget.border');
        final inputBackground = themeColor('input.background');
        // Monaco's inputs have the border `input.border` (none by default)
        // and the outline `focusBorder` when focused
        final inputBorder:Null<Hsla> = themeColor('input.border') != null ? themeColor('input.border') : (inputBackground != null ? inputBackground : null);
        final focusBorder = themeColor('focusBorder');
        final findFocused = findInput.read(app).focusHandle.isFocused(window);
        final replaceFocused = replaceInput.read(app).focusHandle.isFocused(window);
        final errorBorder = color('inputValidation.errorBorder', theme.danger);

        // Monaco's `_updateButtons`
        final findInputIsNonEmpty = (state.searchString.length > 0);
        final matchesCount = state.matchesCount > 0;
        final prevEnabled = findInputIsNonEmpty && matchesCount && state.canNavigateBack();
        final nextEnabled = findInputIsNonEmpty && matchesCount && state.canNavigateForward();
        final replaceEnabled = _isReplaceVisible && findInputIsNonEmpty;
        final canReplace = !editor.getOption(EditorOption.readOnly);
        final selection = editor.getSelection();
        final isSelection = selection != null ? (selection.startLineNumber != selection.endLineNumber || selection.startColumn != selection.endColumn) : false;
        final selectionFindChecked = state.searchScope != null;
        final selectionFindEnabled = selectionFindChecked || isSelection;
        final noResults = (state.searchString.length > 0 && state.matchesCount == 0);

        final findToggles = hFlex()
            .gap(px(2))
            .itemsCenter()
            .child(optionToggle('find-case', IconName.CaseSensitive, state.matchCase, FindWidgetLabels.CASE_SENSITIVE, theme, () -> {
                state.change({matchCase: !state.matchCase}, true);
            }))
            .child(optionToggle('find-word', IconName.WholeWord, state.wholeWord, FindWidgetLabels.WHOLE_WORDS, theme, () -> {
                state.change({wholeWord: !state.wholeWord}, true);
            }))
            .child(optionToggle('find-regex', IconName.Regex, state.isRegex, FindWidgetLabels.REGEX, theme, () -> {
                state.change({isRegex: !state.isRegex}, true);
            }));

        final findInputElement = Input.component(findInput)
            .focusBordered(false)
            .suffix(findToggles)
            .small()
            .flex1()
            .minW0()
            .shadowNone();
        if (inputBackground != null) findInputElement.bg(inputBackground);
        if (noResults) {
            findInputElement.borderColor(errorBorder);
        } else if (findFocused && focusBorder != null) {
            findInputElement.borderColor(focusBorder);
        } else if (inputBorder != null) {
            findInputElement.borderColor(inputBorder);
        }

        final matchesLabel = Label.component(matchesCountLabel())
            .textXs()
            .whitespaceNowrap()
            .textColor(noResults ? errorBorder : foreground);

        final findRow = hFlex()
            .wFull()
            .h(px(28))
            .gap1()
            .itemsCenter()
            .child(findInputElement)
            .child(div().minW(px(64)).flexNone().child(matchesLabel))
            .child(actionButton('find-prev', IconName.ArrowUp, FindWidgetLabels.PREVIOUS_MATCH_BTN_LABEL, prevEnabled, () -> _runAction(FIND_IDS.PreviousMatchFindAction)))
            .child(actionButton('find-next', IconName.ArrowDown, FindWidgetLabels.NEXT_MATCH_BTN_LABEL, nextEnabled, () -> _runAction(FIND_IDS.NextMatchFindAction)))
            .child(optionToggle('find-selection', IconName.TextSelect, selectionFindChecked, FindWidgetLabels.TOGGLE_SELECTION_FIND_TITLE, theme, () -> {
                if (selectionFindEnabled) _toggleSelectionFind();
            }).disabled(!selectionFindEnabled))
            .child(actionButton('find-close', IconName.Close, FindWidgetLabels.CLOSE_BTN_LABEL, true, () -> {
                state.change({isRevealed: false, searchScope: null}, false);
            }));

        final rows = vFlex()
            .flex1()
            .minW0()
            .gap1()
            .child(findRow);

        if (_isReplaceVisible) {
            final replaceInputElement = Input.component(replaceInput)
                .focusBordered(false)
                .suffix(optionToggle('find-preserve-case', IconName.CaseUpper, state.preserveCase, FindWidgetLabels.PRESERVE_CASE, theme, () -> {
                    state.change({preserveCase: !state.preserveCase}, true);
                }))
                .small()
                .flex1()
                .minW0()
                .shadowNone();
            if (inputBackground != null) replaceInputElement.bg(inputBackground);
            if (replaceFocused && focusBorder != null) {
                replaceInputElement.borderColor(focusBorder);
            } else if (inputBorder != null) {
                replaceInputElement.borderColor(inputBorder);
            }
            rows.child(hFlex()
                .wFull()
                .h(px(28))
                .gap1()
                .itemsCenter()
                .child(replaceInputElement)
                .child(actionButton('find-replace-one', IconName.Replace, FindWidgetLabels.REPLACE_BTN_LABEL, replaceEnabled, () -> controller.replace()))
                .child(actionButton('find-replace-all', IconName.ReplaceAll, FindWidgetLabels.REPLACE_ALL_BTN_LABEL, replaceEnabled, () -> controller.replaceAll()))
                // keeps the replace input as wide as the find input
                .child(div().w(px(64 + 4 * 24 + 8)).flexNone()));
        }

        final toggleReplace = Button.component('find-toggle-replace')
            .ghost()
            .xsmall()
            .compact()
            .textColor(_iconColor)
            .icon(_isReplaceVisible ? IconName.ChevronDown : IconName.ChevronRight)
            .tooltip(FindWidgetLabels.TOGGLE_REPLACE_MODE_BTN_LABEL)
            .disabled(!canReplace)
            .onClick((_:ClickEvent, _:Window, _:App) -> {
                state.change({isReplaceRevealed: !_isReplaceVisible}, false);
            });

        final panel = hFlex()
            .id('cityscape-find-widget')
            .occlude()
            .keyContext('CityscapeFindWidget')
            .onAction(Enter, (action:Enter, window:Window, cx:App) -> {
                if (onEnter(action.secondary, action.shift, window)) {
                    cx.stopPropagation();
                } else {
                    cx.propagate();
                }
            })
            .onAction(IndentInline, (_:IndentInline, window:Window, cx:App) -> _onTab(false, window))
            .onAction(OutdentInline, (_:OutdentInline, window:Window, cx:App) -> _onTab(true, window))
            .w(px(FIND_WIDGET_INITIAL_WIDTH))
            .itemsStart()
            .gap1()
            .pl1()
            .pr2()
            .py1()
            .fontFamily(theme.fontFamily)
            .textSm()
            .textColor(foreground)
            .bg(background)
            .roundedBMd()
            .shadowMd()
            .child(div().h(px(_isReplaceVisible ? 60 : 28)).flex().itemsCenter().child(toggleReplace))
            .child(rows);
        if (border != null) {
            panel.borderL1().borderR1().borderB1().borderColor(border);
        }
        return panel;
    }

}

/**
 * The find widget as an overlay widget of the editor, at its top right
 * corner (Monaco's `FindWidget` is an `IOverlayWidget` too). It is added
 * with the find controller, and its Glaze view (`FindWidget`) is created
 * the first time the editor renders it (its inputs need the window).
 */
class FindWidgetOverlay implements IOverlayWidget implements IFindWidget implements IDisposable {

    public static inline final ID = 'editor.contrib.findWidget';

    final editor:ICodeEditor;
    final controller:FindController;
    final state:FindReplaceState;
    final _toDispose = new DisposableStore();

    var view:Null<Entity<FindWidget>> = null;
    var app:Null<App> = null;

    /**
     * The focus asked before the view exists: 1 for the find input, 2 for
     * the replace input.
     */
    var pendingFocus:Int = 0;

    public function new(editor:ICodeEditor, controller:FindController, state:FindReplaceState) {
        this.editor = editor;
        this.controller = controller;
        this.state = state;
        editor.addOverlayWidget(this);
        _toDispose.add(state.onFindReplaceStateChange(e -> {
            if (e.isRevealed) {
                editor.layoutOverlayWidget(this);
            }
        }));
    }

    /**
     * The Glaze view of the widget (null before it was first rendered).
     */
    public function getView():Null<FindWidget> {
        final v = view;
        return v != null ? (v : FindWidget) : null;
    }

    public function dispose():Void {
        _toDispose.dispose();
        editor.removeOverlayWidget(this);
        final v = view;
        if (v != null) {
            (v : FindWidget).release();
        }
        view = null;
    }

    public function getId():String {
        return ID;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return {preference: OverlayWidgetPositionPreference.TOP_RIGHT_CORNER};
    }

    function themeColor(key:String):Null<Hsla> {
        final color:Null<Color> = editor.context.themeService.getColorTheme().getColor(key);
        if (color == null) {
            return null;
        }
        final rgba = color.rgba;
        return new glaze.Rgba(rgba.r / 255, rgba.g / 255, rgba.b / 255, rgba.a).toHsla();
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        // The Glaze view is created at the first render of the editor and
        // stays in its tree: it shows and hides itself (it renders nothing
        // while the find widget is closed), so a change of the find state
        // only renders the widget again, not the editor
        var v = view;
        if (v == null) {
            app = cx;
            v = FindWidget.create(controller, editor, key -> themeColor(key), window, cx);
            view = v;
            final focus = pendingFocus;
            pendingFocus = 0;
            if (focus != 0) {
                // focus once the inputs are in the tree
                final widget:FindWidget = v;
                cx.defer(_ -> focus == 1 ? widget.focusFindInput() : widget.focusReplaceInput());
            }
        }
        return v;
    }

    public function focusFindInput():Void {
        final v = view;
        if (v != null) {
            (v : FindWidget).focusFindInput();
        } else {
            pendingFocus = 1;
            FindModel.CONTEXT_FIND_INPUT_FOCUSED.bindTo(controller.contextKeyService).set(true);
            FindModel.CONTEXT_REPLACE_INPUT_FOCUSED.bindTo(controller.contextKeyService).set(false);
        }
    }

    public function focusReplaceInput():Void {
        final v = view;
        if (v != null) {
            (v : FindWidget).focusReplaceInput();
        } else {
            pendingFocus = 2;
            FindModel.CONTEXT_FIND_INPUT_FOCUSED.bindTo(controller.contextKeyService).set(false);
            FindModel.CONTEXT_REPLACE_INPUT_FOCUSED.bindTo(controller.contextKeyService).set(true);
        }
    }

    public function highlightFindOptions(ignoreWhenVisible:Bool):Void {
        final v = view;
        if (v != null) {
            (v : FindWidget).highlightFindOptions(ignoreWhenVisible);
        }
    }

}
