// Ported from vscode src/vs/editor/contrib/find/browser/findController.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.find.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle.Disposable;
import cityscape.base.common.Strings;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.find.view.FindModel;
import cityscape.contrib.find.view.FindState;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.IKeybindings;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.platform.storage.common.Storage;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * The find controller of an editor and the find actions (findController.ts).
 *
 * Ported: `getSelectionSearchString`, `CommonFindController`,
 * `FindController` (its widget is the Glaze `FindWidget`, an overlay widget
 * of the editor), the actions and the commands with their keybindings,
 * registered by `FindRegistration` (Monaco's module level registration).
 * `StartFindAction` and `StartFindReplaceAction` are plain editor actions
 * (Monaco's `MultiEditorAction` with one implementation).
 *
 * Not ported: the global find clipboard of macOS (`globalFindClipboard`,
 * the clipboard service's find text: not needed, the option stays false),
 * `MoveToMatchFindAction` (it asks for a match number in a quick input),
 * the find options widget shown when an option is toggled while the find
 * widget is closed (`FindOptionsWidget`), and the search history.
 */

/**
 * Module functions of findController.ts.
 */
class FindControllerUtils {

    static inline final SEARCH_STRING_MAX_LENGTH = 524288;

    /**
     * `seedSearchStringFromSelection` is `'single'` or `'multiple'`.
     */
    public static function getSelectionSearchString(editor:ICodeEditor, seedSearchStringFromSelection:String = 'single', seedSearchStringFromNonEmptySelection:Bool = false):Null<String> {
        if (!editor.hasModel()) {
            return null;
        }

        final selection = editor.getSelection();
        // if selection spans multiple lines, default search string to empty

        if ((seedSearchStringFromSelection == 'single' && selection.startLineNumber == selection.endLineNumber)
            || seedSearchStringFromSelection == 'multiple') {
            if (selection.isEmpty()) {
                final wordAtPosition = editor.getConfiguredWordAtPosition(selection.getStartPosition());
                if (wordAtPosition != null && (false == seedSearchStringFromNonEmptySelection)) {
                    return wordAtPosition.word;
                }
            } else {
                if (editor.getModel().getValueLengthInRange(selection) < SEARCH_STRING_MAX_LENGTH) {
                    return editor.getModel().getValueInRange(selection);
                }
            }
        }

        return null;
    }

}

enum abstract FindStartFocusAction(Int) from Int to Int {
    var NoFocusChange = 0;
    var FocusFindInput = 1;
    var FocusReplaceInput = 2;
}

typedef IFindStartOptions = {
    var forceRevealReplace:Bool;
    /**
     * `'none'`, `'single'` or `'multiple'`.
     */
    var seedSearchStringFromSelection:String;
    var seedSearchStringFromNonEmptySelection:Bool;
    var seedSearchStringFromGlobalClipboard:Bool;
    var shouldFocus:FindStartFocusAction;
    var shouldAnimate:Bool;
    var updateSearchScope:Bool;
    var loop:Bool;
}

typedef IFindStartArguments = {
    @:optional var searchString:String;
    @:optional var replaceString:String;
    @:optional var isRegex:Bool;
    @:optional var matchWholeWord:Bool;
    @:optional var isCaseSensitive:Bool;
    @:optional var preserveCase:Bool;
    @:optional var findInSelection:Bool;
}

/**
 * The find logic of an editor (one per editor: each has its own find state
 * and find model).
 */
class CommonFindController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.findController';

    /**
     * The find controller of an editor (Monaco's `CommonFindController.get`).
     */
    public static function get(editor:ICodeEditor):Null<CommonFindController> {
        return editor.getContribution(ID);
    }

    var _editor:ICodeEditor;
    final _findWidgetVisible:IContextKey<Bool>;
    final _contextKeyService:IContextKeyService;
    var _state:FindReplaceState;
    var _model:Null<FindModelBoundToEditorModel>;
    final _storageService:IStorageService;

    public var editor(get, never):ICodeEditor;
    inline function get_editor():ICodeEditor {
        return this._editor;
    }

    /**
     * The context key service of the editor (the find context keys are
     * there).
     */
    public var contextKeyService(get, never):IContextKeyService;
    inline function get_contextKeyService():IContextKeyService {
        return this._contextKeyService;
    }

    /**
     * `storageService` is the storage of the query options: the one of the
     * editor's context when null (Monaco's injected `IStorageService`).
     */
    public function new(editor:ICodeEditor, ?storageService:IStorageService) {
        super();
        this._editor = editor;
        this._contextKeyService = editor.contextKeyService;
        this._findWidgetVisible = FindModel.CONTEXT_FIND_WIDGET_VISIBLE.bindTo(editor.contextKeyService);
        this._storageService = storageService != null ? storageService : editor.context.storageService;

        this._state = this._register(new FindReplaceState());
        this.loadQueryState();
        this._register(this._state.onFindReplaceStateChange((e) -> this._onStateChanged(e)));

        this._model = null;

        this._register(this._editor.onDidChangeModel((_) -> {
            final shouldRestartFind = (this._editor.getModel() != null && this._state.isRevealed);

            this.disposeModel();

            this._state.change({
                searchScope: null,
                matchCase: this._storageService.getBoolean('editor.matchCase', StorageScope.WORKSPACE, false),
                wholeWord: this._storageService.getBoolean('editor.wholeWord', StorageScope.WORKSPACE, false),
                isRegex: this._storageService.getBoolean('editor.isRegex', StorageScope.WORKSPACE, false),
                preserveCase: this._storageService.getBoolean('editor.preserveCase', StorageScope.WORKSPACE, false)
            }, false);

            if (shouldRestartFind) {
                this._start({
                    forceRevealReplace: false,
                    seedSearchStringFromSelection: 'none',
                    seedSearchStringFromNonEmptySelection: false,
                    seedSearchStringFromGlobalClipboard: false,
                    shouldFocus: FindStartFocusAction.NoFocusChange,
                    shouldAnimate: false,
                    updateSearchScope: false,
                    loop: this._editor.getOption(EditorOption.find).loop
                });
            }
        }));
    }

    override public function dispose():Void {
        this.disposeModel();
        super.dispose();
    }

    function disposeModel():Void {
        if (this._model != null) {
            this._model.dispose();
            this._model = null;
        }
    }

    function _onStateChanged(e:FindReplaceStateChangedEvent):Void {
        this.saveQueryState(e);

        if (e.isRevealed) {
            if (this._state.isRevealed) {
                this._findWidgetVisible.set(true);
            } else {
                this._findWidgetVisible.reset();
                this.disposeModel();
            }
        }
        if (e.searchString) {
            this.setGlobalBufferTerm(this._state.searchString);
        }
    }

    function saveQueryState(e:FindReplaceStateChangedEvent):Void {
        if (e.isRegex) {
            this._storageService.store('editor.isRegex', this._state.actualIsRegex, StorageScope.WORKSPACE, StorageTarget.MACHINE);
        }
        if (e.wholeWord) {
            this._storageService.store('editor.wholeWord', this._state.actualWholeWord, StorageScope.WORKSPACE, StorageTarget.MACHINE);
        }
        if (e.matchCase) {
            this._storageService.store('editor.matchCase', this._state.actualMatchCase, StorageScope.WORKSPACE, StorageTarget.MACHINE);
        }
        if (e.preserveCase) {
            this._storageService.store('editor.preserveCase', this._state.actualPreserveCase, StorageScope.WORKSPACE, StorageTarget.MACHINE);
        }
    }

    function loadQueryState():Void {
        this._state.change({
            matchCase: this._storageService.getBoolean('editor.matchCase', StorageScope.WORKSPACE, this._state.matchCase),
            wholeWord: this._storageService.getBoolean('editor.wholeWord', StorageScope.WORKSPACE, this._state.wholeWord),
            isRegex: this._storageService.getBoolean('editor.isRegex', StorageScope.WORKSPACE, this._state.isRegex),
            preserveCase: this._storageService.getBoolean('editor.preserveCase', StorageScope.WORKSPACE, this._state.preserveCase)
        }, false);
    }

    public function isFindInputFocused():Bool {
        return FindModel.CONTEXT_FIND_INPUT_FOCUSED.getValue(this._contextKeyService) == true;
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function getState():FindReplaceState {
        return this._state;
    }

    public function closeFindWidget():Void {
        this._state.change({
            isRevealed: false,
            searchScope: null
        }, false);
        this._editor.focus();
    }

    public function toggleCaseSensitive():Void {
        this._state.change({matchCase: !this._state.matchCase}, false);
        if (!this._state.isRevealed) {
            this.highlightFindOptions();
        }
    }

    public function toggleWholeWords():Void {
        this._state.change({wholeWord: !this._state.wholeWord}, false);
        if (!this._state.isRevealed) {
            this.highlightFindOptions();
        }
    }

    public function toggleRegex():Void {
        this._state.change({isRegex: !this._state.isRegex}, false);
        if (!this._state.isRevealed) {
            this.highlightFindOptions();
        }
    }

    public function togglePreserveCase():Void {
        this._state.change({preserveCase: !this._state.preserveCase}, false);
        if (!this._state.isRevealed) {
            this.highlightFindOptions();
        }
    }

    public function toggleSearchScope():Void {
        if (this._state.searchScope != null) {
            this._state.change({searchScope: null}, true);
        } else {
            if (this._editor.hasModel()) {
                final selections:Array<Range> = [];
                for (s in this._editor.getSelections()) {
                    var selection:Selection = s;
                    if (selection.endColumn == 1 && selection.endLineNumber > selection.startLineNumber) {
                        selection = selection.setEndPosition(
                            selection.endLineNumber - 1,
                            this._editor.getModel().getLineMaxColumn(selection.endLineNumber - 1)
                        );
                    }
                    if (!selection.isEmpty()) {
                        selections.push(selection);
                    }
                }

                if (selections.length > 0) {
                    this._state.change({searchScope: selections}, true);
                }
            }
        }
    }

    public function setSearchString(searchString:String):Void {
        if (this._state.isRegex) {
            searchString = Strings.escapeRegExpCharacters(searchString);
        }
        this._state.change({searchString: searchString}, false);
    }

    public function highlightFindOptions(ignoreWhenVisible:Bool = false):Void {
        // overwritten in subclass
    }

    /**
     * Opens the find widget (synchronous: Monaco awaits the global find
     * clipboard only, which is not ported).
     */
    function _start(opts:IFindStartOptions, ?newState:INewFindReplaceState):Void {
        this.disposeModel();

        if (!this._editor.hasModel()) {
            // cannot do anything with an editor that doesn't have a model...
            return;
        }

        final stateChanges:INewFindReplaceState = copyNewState(newState);
        stateChanges.isRevealed = true;

        if (opts.seedSearchStringFromSelection == 'single') {
            final selectionSearchString = FindControllerUtils.getSelectionSearchString(this._editor, opts.seedSearchStringFromSelection, opts.seedSearchStringFromNonEmptySelection);
            if (selectionSearchString != null && selectionSearchString.length > 0) {
                if (this._state.isRegex) {
                    stateChanges.searchString = Strings.escapeRegExpCharacters(selectionSearchString);
                } else {
                    stateChanges.searchString = selectionSearchString;
                }
            }
        } else if (opts.seedSearchStringFromSelection == 'multiple' && !opts.updateSearchScope) {
            final selectionSearchString = FindControllerUtils.getSelectionSearchString(this._editor, opts.seedSearchStringFromSelection);
            if (selectionSearchString != null && selectionSearchString.length > 0) {
                stateChanges.searchString = selectionSearchString;
            }
        }

        if ((stateChanges.searchString == null || stateChanges.searchString.length == 0) && opts.seedSearchStringFromGlobalClipboard) {
            final selectionSearchString = this.getGlobalBufferTerm();

            if (!this._editor.hasModel()) {
                // the editor has lost its model in the meantime
                return;
            }

            if (selectionSearchString.length > 0) {
                stateChanges.searchString = selectionSearchString;
            }
        }

        // Overwrite isReplaceRevealed
        if (opts.forceRevealReplace || stateChanges.isReplaceRevealed == true) {
            stateChanges.isReplaceRevealed = true;
        } else if (this._findWidgetVisible.get() != true) {
            stateChanges.isReplaceRevealed = false;
        }

        if (opts.updateSearchScope) {
            final currentSelections = this._editor.getSelections();
            var some = false;
            for (selection in currentSelections) {
                if (!selection.isEmpty()) {
                    some = true;
                    break;
                }
            }
            if (some) {
                stateChanges.searchScope = [for (s in currentSelections) (s : Range)];
            }
        }

        stateChanges.loop = opts.loop;

        this._state.change(stateChanges, false);

        if (this._model == null) {
            this._model = new FindModelBoundToEditorModel(this._editor, this._state);
        }
    }

    /**
     * A copy of the fields given (`{...newState}`), without the fields left
     * out (a `searchScope` given stays given, even when null).
     */
    static function copyNewState(newState:Null<INewFindReplaceState>):INewFindReplaceState {
        final copy:INewFindReplaceState = {};
        if (newState != null) {
            for (field in Reflect.fields(newState)) {
                Reflect.setField(copy, field, Reflect.field(newState, field));
            }
        }
        return copy;
    }

    public function start(opts:IFindStartOptions, ?newState:INewFindReplaceState):Void {
        this._start(opts, newState);
    }

    public function moveToNextMatch():Bool {
        if (this._model != null) {
            this._model.moveToNextMatch();
            return true;
        }
        return false;
    }

    public function moveToPrevMatch():Bool {
        if (this._model != null) {
            this._model.moveToPrevMatch();
            return true;
        }
        return false;
    }

    public function goToMatch(index:Int):Bool {
        if (this._model != null) {
            this._model.moveToMatch(index);
            return true;
        }
        return false;
    }

    public function replace():Bool {
        if (this._model != null) {
            this._model.replace();
            return true;
        }
        return false;
    }

    public function replaceAll():Bool {
        if (this._model != null) {
            final model = this._editor.getModel();
            if (model != null && model.isTooLargeForHeapOperation()) {
                // Monaco warns: "The file is too large to perform a replace all operation."
                return false;
            }
            this._model.replaceAll();
            return true;
        }
        return false;
    }

    public function selectAllMatches():Bool {
        if (this._model != null) {
            this._model.selectAllMatches();
            this._editor.focus();
            return true;
        }
        return false;
    }

    /**
     * The search string of the global find clipboard of macOS: not ported,
     * always empty.
     */
    public function getGlobalBufferTerm():String {
        return '';
    }

    public function setGlobalBufferTerm(text:String):Void {
        // The global find clipboard of macOS is not ported
    }

}

/**
 * What the find controller asks of its widget (Monaco's `FindWidget`
 * methods it calls).
 */
interface IFindWidget {
    function focusFindInput():Void;
    function focusReplaceInput():Void;
    function highlightFindOptions(ignoreWhenVisible:Bool):Void;
}

/**
 * The find controller with a widget: turns find in selection on according
 * to `find.autoFindInSelection`, and moves the focus to the inputs of the
 * widget (the Glaze `FindWidget`, an overlay widget of the editor created on
 * first use).
 */
class FindController extends CommonFindController {

    var _widget:Null<IFindWidget> = null;

    public function new(editor:ICodeEditor, ?storageService:IStorageService) {
        super(editor, storageService);
        // Monaco creates the widget when the find widget is first opened;
        // here it is added with the editor, so that the editor renders it
        // once and the widget then renders itself when it shows (see
        // `FindWidgetOverlay`)
        this._createFindWidget();
    }

    /**
     * The widget of the controller (null before the find widget was first
     * opened).
     */
    public function getWidget():Null<IFindWidget> {
        return this._widget;
    }

    override function _start(opts:IFindStartOptions, ?newState:INewFindReplaceState):Void {
        if (this._widget == null) {
            this._createFindWidget();
        }

        final selection = this._editor.getSelection();
        var updateSearchScope = false;

        switch (this._editor.getOption(EditorOption.find).autoFindInSelection) {
            case 'always':
                updateSearchScope = true;
            case 'never':
                updateSearchScope = false;
            case 'multiline':
                final isSelectionMultipleLine = selection != null && selection.startLineNumber != selection.endLineNumber;
                updateSearchScope = isSelectionMultipleLine;
            default:
        }

        opts.updateSearchScope = opts.updateSearchScope || updateSearchScope;

        super._start(opts, newState);

        if (this._widget != null) {
            if (opts.shouldFocus == FindStartFocusAction.FocusReplaceInput) {
                this._widget.focusReplaceInput();
            } else if (opts.shouldFocus == FindStartFocusAction.FocusFindInput) {
                this._widget.focusFindInput();
            }
        }
    }

    override public function highlightFindOptions(ignoreWhenVisible:Bool = false):Void {
        if (this._widget == null) {
            this._createFindWidget();
        }
        this._widget.highlightFindOptions(ignoreWhenVisible);
    }

    function _createFindWidget():Void {
        final overlay = new FindWidget.FindWidgetOverlay(this._editor, this, this._state);
        this._widget = overlay;
        this._register(overlay);
    }

}

/**
 * Monaco's `StartFindAction` (`actions.find`).
 */
class StartFindAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.StartFindAction,
            label: r.localize('startFindAction', "Find"),
            alias: 'Find',
            precondition: ContextKeyExpr.or(EditorContextKeys.focus, ContextKeyExpr.has('editorIsOpen')),
            kbOpts: {
                kbExpr: null,
                primary: KeyMod.CtrlCmd | KeyCode.KeyF,
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarEditMenu',
                group: '3_find',
                title: r.localize('miFind', "&&Find"),
                order: 1
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = CommonFindController.get(editor);
        if (controller == null) {
            return;
        }
        final find = editor.getOption(EditorOption.find);
        controller.start({
            forceRevealReplace: false,
            seedSearchStringFromSelection: find.seedSearchStringFromSelection != 'never' ? 'single' : 'none',
            seedSearchStringFromNonEmptySelection: find.seedSearchStringFromSelection == 'selection',
            seedSearchStringFromGlobalClipboard: find.globalFindClipboard,
            shouldFocus: FindStartFocusAction.FocusFindInput,
            shouldAnimate: true,
            updateSearchScope: false,
            loop: find.loop
        });
    }

}

/**
 * Monaco's `StartFindWithArgsAction` (`editor.actions.findWithArgs`).
 */
class StartFindWithArgsAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.StartFindWithArgs,
            label: r.localize('startFindWithArgsAction', "Find With Arguments"),
            alias: 'Find With Arguments',
            precondition: null,
            kbOpts: {
                kbExpr: null,
                primary: 0,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, rawArgs:Any):Void {
        final controller = CommonFindController.get(editor);
        if (controller == null) {
            return;
        }
        final args:Null<IFindStartArguments> = rawArgs;
        final find = editor.getOption(EditorOption.find);
        final newState:INewFindReplaceState = {};
        if (args != null) {
            if (args.searchString != null) newState.searchString = args.searchString;
            if (args.replaceString != null) newState.replaceString = args.replaceString;
            newState.isReplaceRevealed = args.replaceString != null;
            if (args.isRegex != null) newState.isRegex = args.isRegex;
            if (args.matchWholeWord != null) newState.wholeWord = args.matchWholeWord;
            if (args.isCaseSensitive != null) newState.matchCase = args.isCaseSensitive;
            if (args.preserveCase != null) newState.preserveCase = args.preserveCase;
        }

        controller.start({
            forceRevealReplace: false,
            seedSearchStringFromSelection: (controller.getState().searchString.length == 0) && find.seedSearchStringFromSelection != 'never' ? 'single' : 'none',
            seedSearchStringFromNonEmptySelection: find.seedSearchStringFromSelection == 'selection',
            seedSearchStringFromGlobalClipboard: true,
            shouldFocus: FindStartFocusAction.FocusFindInput,
            shouldAnimate: true,
            updateSearchScope: args != null && args.findInSelection == true,
            loop: find.loop
        }, newState);

        controller.setGlobalBufferTerm(controller.getState().searchString);
    }

}

/**
 * Monaco's `StartFindWithSelectionAction` (`actions.findWithSelection`).
 */
class StartFindWithSelectionAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.StartFindWithSelection,
            label: r.localize('startFindWithSelectionAction', "Find With Selection"),
            alias: 'Find With Selection',
            precondition: null,
            kbOpts: {
                kbExpr: null,
                primary: 0,
                mac: {
                    primary: KeyMod.CtrlCmd | KeyCode.KeyE,
                },
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = CommonFindController.get(editor);
        if (controller == null) {
            return;
        }
        controller.start({
            forceRevealReplace: false,
            seedSearchStringFromSelection: 'multiple',
            seedSearchStringFromNonEmptySelection: false,
            seedSearchStringFromGlobalClipboard: false,
            shouldFocus: FindStartFocusAction.NoFocusChange,
            shouldAnimate: true,
            updateSearchScope: false,
            loop: editor.getOption(EditorOption.find).loop
        });

        controller.setGlobalBufferTerm(controller.getState().searchString);
    }

}

abstract class MatchFindAction extends EditorAction {

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = CommonFindController.get(editor);
        if (controller != null && !this._run(controller)) {
            final find = editor.getOption(EditorOption.find);
            controller.start({
                forceRevealReplace: false,
                seedSearchStringFromSelection: (controller.getState().searchString.length == 0) && find.seedSearchStringFromSelection != 'never' ? 'single' : 'none',
                seedSearchStringFromNonEmptySelection: find.seedSearchStringFromSelection == 'selection',
                seedSearchStringFromGlobalClipboard: true,
                shouldFocus: FindStartFocusAction.NoFocusChange,
                shouldAnimate: true,
                updateSearchScope: false,
                loop: find.loop
            });
            this._run(controller);
        }
    }

    abstract function _run(controller:CommonFindController):Bool;

}

/**
 * Monaco's `NextMatchFindAction` (`editor.action.nextMatchFindAction`).
 */
class NextMatchFindAction extends MatchFindAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.NextMatchFindAction,
            label: r.localize('findNextMatchAction', "Find Next"),
            alias: 'Find Next',
            precondition: null,
            kbOpts: [{
                kbExpr: EditorContextKeys.focus,
                primary: KeyCode.F3,
                mac: {primary: KeyMod.CtrlCmd | KeyCode.KeyG, secondary: [KeyCode.F3]},
                weight: KeybindingWeight.EditorContrib
            }, {
                kbExpr: ContextKeyExpr.and(EditorContextKeys.focus, FindModel.CONTEXT_FIND_INPUT_FOCUSED),
                primary: KeyCode.Enter,
                weight: KeybindingWeight.EditorContrib
            }]
        });
    }

    function _run(controller:CommonFindController):Bool {
        final result = controller.moveToNextMatch();
        if (result) {
            controller.editor.pushUndoStop();
            return true;
        }

        return false;
    }

}

/**
 * Monaco's `PreviousMatchFindAction` (`editor.action.previousMatchFindAction`).
 */
class PreviousMatchFindAction extends MatchFindAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.PreviousMatchFindAction,
            label: r.localize('findPreviousMatchAction', "Find Previous"),
            alias: 'Find Previous',
            precondition: null,
            kbOpts: [{
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.Shift | KeyCode.F3,
                mac: {primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyG, secondary: [KeyMod.Shift | KeyCode.F3]},
                weight: KeybindingWeight.EditorContrib
            }, {
                kbExpr: ContextKeyExpr.and(EditorContextKeys.focus, FindModel.CONTEXT_FIND_INPUT_FOCUSED),
                primary: KeyMod.Shift | KeyCode.Enter,
                weight: KeybindingWeight.EditorContrib
            }]
        });
    }

    function _run(controller:CommonFindController):Bool {
        return controller.moveToPrevMatch();
    }

}

abstract class SelectionMatchFindAction extends EditorAction {

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = CommonFindController.get(editor);
        if (controller == null) {
            return;
        }

        final selectionSearchString = FindControllerUtils.getSelectionSearchString(editor, 'single', false);
        if (selectionSearchString != null && selectionSearchString.length > 0) {
            controller.setSearchString(selectionSearchString);
        }
        if (!this._run(controller)) {
            controller.start({
                forceRevealReplace: false,
                seedSearchStringFromSelection: 'none',
                seedSearchStringFromNonEmptySelection: false,
                seedSearchStringFromGlobalClipboard: false,
                shouldFocus: FindStartFocusAction.NoFocusChange,
                shouldAnimate: true,
                updateSearchScope: false,
                loop: editor.getOption(EditorOption.find).loop
            });
            this._run(controller);
        }
    }

    abstract function _run(controller:CommonFindController):Bool;

}

/**
 * Monaco's `NextSelectionMatchFindAction`.
 */
class NextSelectionMatchFindAction extends SelectionMatchFindAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.NextSelectionMatchFindAction,
            label: r.localize('nextSelectionMatchFindAction', "Find Next Selection"),
            alias: 'Find Next Selection',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.CtrlCmd | KeyCode.F3,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    function _run(controller:CommonFindController):Bool {
        return controller.moveToNextMatch();
    }

}

/**
 * Monaco's `PreviousSelectionMatchFindAction`.
 */
class PreviousSelectionMatchFindAction extends SelectionMatchFindAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.PreviousSelectionMatchFindAction,
            label: r.localize('previousSelectionMatchFindAction', "Find Previous Selection"),
            alias: 'Find Previous Selection',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.F3,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    function _run(controller:CommonFindController):Bool {
        return controller.moveToPrevMatch();
    }

}

/**
 * Monaco's `StartFindReplaceAction` (`editor.action.startFindReplaceAction`).
 */
class StartFindReplaceAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: FIND_IDS.StartFindReplaceAction,
            label: r.localize('startReplace', "Replace"),
            alias: 'Replace',
            precondition: ContextKeyExpr.or(EditorContextKeys.focus, ContextKeyExpr.has('editorIsOpen')),
            kbOpts: {
                kbExpr: null,
                primary: KeyMod.CtrlCmd | KeyCode.KeyH,
                mac: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyF},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarEditMenu',
                group: '3_find',
                title: r.localize('miReplace', "&&Replace"),
                order: 2
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel() || editor.getOption(EditorOption.readOnly)) {
            return;
        }
        final controller = CommonFindController.get(editor);
        if (controller == null) {
            return;
        }

        final find = editor.getOption(EditorOption.find);
        final currentSelection = editor.getSelection();
        final findInputFocused = controller.isFindInputFocused();
        // we only seed search string from selection when the current selection is single line and not empty,
        // + the find input is not focused
        final seedSearchStringFromSelection = !currentSelection.isEmpty()
            && currentSelection.startLineNumber == currentSelection.endLineNumber
            && (find.seedSearchStringFromSelection != 'never')
            && !findInputFocused;
        /*
         * if the existing search string in find widget is empty and we don't seed search string from selection, it means the Find Input is still empty, so we should focus the Find Input instead of Replace Input.

         * findInputFocused true -> seedSearchStringFromSelection false, FocusReplaceInput
         * findInputFocused false, seedSearchStringFromSelection true FocusReplaceInput
         * findInputFocused false seedSearchStringFromSelection false FocusFindInput
         */
        final shouldFocus = (findInputFocused || seedSearchStringFromSelection) ? FindStartFocusAction.FocusReplaceInput : FindStartFocusAction.FocusFindInput;

        controller.start({
            forceRevealReplace: true,
            seedSearchStringFromSelection: seedSearchStringFromSelection ? 'single' : 'none',
            seedSearchStringFromNonEmptySelection: find.seedSearchStringFromSelection == 'selection',
            seedSearchStringFromGlobalClipboard: find.seedSearchStringFromSelection != 'never',
            shouldFocus: shouldFocus,
            shouldAnimate: true,
            updateSearchScope: false,
            loop: find.loop
        });
    }

}

/**
 * The module level registration of findController.ts: the contribution,
 * the actions, and the commands bound to the find controller (Monaco's
 * `EditorCommand.bindToContribution`), with their keybindings.
 */
class FindRegistration {

    static function toggleKbOpts(keybinding:IKeybindings):ICommandKeybindingsOptions {
        return {
            weight: KeybindingWeight.EditorContrib + 5,
            kbExpr: EditorContextKeys.focus,
            primary: keybinding.primary,
            mac: keybinding.mac,
            win: keybinding.win,
            linux: keybinding.linux
        };
    }

    /**
     * The look of the find decorations (Monaco's theme participant of
     * findWidget.ts and the editor CSS: `findMatch`, `currentFindMatch`,
     * `rangeHighlight`, `findScope`), registered in the context unless the
     * host registered its own.
     */
    static function registerDecorationStyles(context:Cityscape):Void {
        final styles = context.decorationStyles;
        if (styles.get('findMatch') == null) {
            context.registerDecorationStyle('findMatch', {
                background: {id: 'editor.findMatchHighlightBackground'},
                border: {color: {id: 'editor.findMatchHighlightBorder'}}
            });
        }
        if (styles.get('currentFindMatch') == null) {
            context.registerDecorationStyle('currentFindMatch', {
                background: {id: 'editor.findMatchBackground'},
                border: {color: {id: 'editor.findMatchBorder'}, width: 2}
            });
        }
        if (styles.get('findMatchInline') == null) {
            context.registerDecorationStyle('findMatchInline', {
                color: {id: 'editor.findMatchHighlightForeground'}
            });
        }
        if (styles.get('currentFindMatchInline') == null) {
            context.registerDecorationStyle('currentFindMatchInline', {
                color: {id: 'editor.findMatchForeground'}
            });
        }
        if (styles.get('rangeHighlight') == null) {
            context.registerDecorationStyle('rangeHighlight', {
                background: {id: 'editor.rangeHighlightBackground'},
                border: {color: {id: 'editor.rangeHighlightBorder'}}
            });
        }
        if (styles.get('findScope') == null) {
            context.registerDecorationStyle('findScope', {
                background: {id: 'editor.findRangeHighlightBackground'},
                border: {color: {id: 'editor.findRangeHighlightBorder'}}
            });
        }
    }

    public static function register(r:EditorExtensionsRegistry):Void {
        registerDecorationStyles(r.context);
        r.registerEditorContribution(CommonFindController.ID, editor -> new FindController(editor), EditorContributionInstantiation.Eager); // eager because it uses `saveViewState`/`restoreViewState`

        r.registerEditorAction(new StartFindAction(r));
        r.registerEditorAction(new StartFindWithArgsAction(r));
        r.registerEditorAction(new StartFindWithSelectionAction(r));
        r.registerEditorAction(new NextMatchFindAction(r));
        r.registerEditorAction(new PreviousMatchFindAction(r));
        r.registerEditorAction(new NextSelectionMatchFindAction(r));
        r.registerEditorAction(new PreviousSelectionMatchFindAction(r));
        r.registerEditorAction(new StartFindReplaceAction(r));

        final get = CommonFindController.get;

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.CloseFindWidgetCommand,
            precondition: FindModel.CONTEXT_FIND_WIDGET_VISIBLE,
            handler: (x, args) -> x.closeFindWidget(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 5,
                kbExpr: ContextKeyExpr.and(EditorContextKeys.focus, ContextKeyExpr.not('isComposing')),
                primary: KeyCode.Escape,
                secondary: [KeyMod.Shift | KeyCode.Escape]
            }
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ToggleCaseSensitiveCommand,
            precondition: null,
            handler: (x, args) -> x.toggleCaseSensitive(),
            kbOpts: toggleKbOpts(FindModel.ToggleCaseSensitiveKeybinding)
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ToggleWholeWordCommand,
            precondition: null,
            handler: (x, args) -> x.toggleWholeWords(),
            kbOpts: toggleKbOpts(FindModel.ToggleWholeWordKeybinding)
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ToggleRegexCommand,
            precondition: null,
            handler: (x, args) -> x.toggleRegex(),
            kbOpts: toggleKbOpts(FindModel.ToggleRegexKeybinding)
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ToggleSearchScopeCommand,
            precondition: null,
            handler: (x, args) -> x.toggleSearchScope(),
            kbOpts: toggleKbOpts(FindModel.ToggleSearchScopeKeybinding)
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.TogglePreserveCaseCommand,
            precondition: null,
            handler: (x, args) -> x.togglePreserveCase(),
            kbOpts: toggleKbOpts(FindModel.TogglePreserveCaseKeybinding)
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ReplaceOneAction,
            precondition: FindModel.CONTEXT_FIND_WIDGET_VISIBLE,
            handler: (x, args) -> x.replace(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 5,
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Digit1
            }
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ReplaceOneAction,
            precondition: FindModel.CONTEXT_FIND_WIDGET_VISIBLE,
            handler: (x, args) -> x.replace(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 5,
                kbExpr: ContextKeyExpr.and(EditorContextKeys.focus, FindModel.CONTEXT_REPLACE_INPUT_FOCUSED),
                primary: KeyCode.Enter
            }
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ReplaceAllAction,
            precondition: FindModel.CONTEXT_FIND_WIDGET_VISIBLE,
            handler: (x, args) -> x.replaceAll(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 5,
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.Enter
            }
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.ReplaceAllAction,
            precondition: FindModel.CONTEXT_FIND_WIDGET_VISIBLE,
            handler: (x, args) -> x.replaceAll(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 5,
                kbExpr: ContextKeyExpr.and(EditorContextKeys.focus, FindModel.CONTEXT_REPLACE_INPUT_FOCUSED),
                primary: null,
                mac: {
                    primary: KeyMod.CtrlCmd | KeyCode.Enter,
                }
            }
        }));

        r.registerEditorCommand(new ContributionCommand<CommonFindController>(get, {
            id: FIND_IDS.SelectAllMatchesAction,
            precondition: FindModel.CONTEXT_FIND_WIDGET_VISIBLE,
            handler: (x, args) -> x.selectAllMatches(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 5,
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.Alt | KeyCode.Enter
            }
        }));
    }

}
