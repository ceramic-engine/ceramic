// Ported from vscode src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.codeEditor;

import cityscape.Cityscape;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon;
import cityscape.common.EditorContextKeys;
import cityscape.common.Model;
import cityscape.common.TextModelEvents;
import cityscape.common.ViewEvents.VerticalRevealType;
import cityscape.common.ViewModel.IViewModel;
import cityscape.common.ViewModelEventDispatcher;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.ModelLineProjectionData.ILineBreaksComputerFactory;
import cityscape.common.core.CursorColumns;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.common.cursor.CursorWordOperations.WordOperations;
import cityscape.common.viewModel.MonospaceLineBreaksComputer;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.platform.commands.common.Commands.ICommandMetadata;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;
import cityscape.view.config.EditorConfiguration;
import haxe.extern.EitherType;

/**
 * What a `CodeEditorWidget` needs from its view (Monaco's `View`): the
 * Glaze view of `CityscapeEditor` implements it; an editor without a view
 * (tests) has none.
 */
interface ICodeEditorView {
    /**
     * The line breaks computer of the `advanced` wrapping strategy (Monaco's
     * `DOMLineBreaksComputerFactory`).
     */
    function createDomLineBreaksComputerFactory():Null<ILineBreaksComputerFactory>;
    /**
     * A view model was created for a model (`_attachModel`).
     */
    function onDidAttachModel(viewModel:ViewModel):Void;
    /**
     * The view model is about to be disposed (`_detachModel`).
     */
    function onWillDetachModel(viewModel:ViewModel):Void;
    function focus():Void;
    /**
     * Whether the text has the focus.
     */
    function isFocused():Bool;
    /**
     * Whether the editor or one of its widgets has the focus.
     */
    function hasWidgetFocus():Bool;
    function render(forceRedraw:Bool):Void;
    /**
     * `cut`, `copy` or `paste` (Monaco's `document.execCommand`).
     */
    function clipboardAction(action:String):Void;
    function getTargetAtClientPoint(clientX:Float, clientY:Float):Null<IMouseTarget>;
    function getOffsetForColumn(modelLineNumber:Int, modelColumn:Int):Float;
    function getScrolledVisiblePosition(modelPosition:Position):Null<{top:Float, left:Float, height:Float}>;
    /**
     * The overlay widgets changed (added, removed, laid out).
     */
    function overlayWidgetsChanged():Void;
}

typedef ICodeEditorWidgetOptions = {
    /**
     * Is this a simple widget (not a real code editor)?
     * Defaults to false.
     */
    @:optional var isSimpleWidget:Bool;

    /**
     * Contributions to instantiate.
     * When provided, only the contributions included will be instantiated.
     * To include the defaults, those must be provided as well.
     * Defaults to the contributions registered in the context.
     */
    @:optional var contributions:Array<IEditorContributionDescription>;

    /**
     * Restore the view state of a model when it comes back
     * (`setModel`), Cityscape's per model view state. Defaults to true.
     */
    @:optional var keepViewStatePerModel:Bool;
}

private class ModelData {
    public final model:ITextModel;
    public final viewModel:ViewModel;
    public final listenersToRemove:Array<IDisposable>;
    /**
     * The view zones of the view model (Monaco's `View._viewZones`).
     */
    public final viewZones:cityscape.view.viewParts.viewZones.ViewZones;

    public function new(model:ITextModel, viewModel:ViewModel, listenersToRemove:Array<IDisposable>, viewZones:cityscape.view.viewParts.viewZones.ViewZones) {
        this.model = model;
        this.viewModel = viewModel;
        this.listenersToRemove = listenersToRemove;
        this.viewZones = viewZones;
    }
}

/**
 * Monaco's `BooleanEventEmitter`: fires on changes of a boolean.
 */
private class BooleanEventEmitter implements IDisposable {
    public final onDidChangeToTrue:VoidEvent;
    public final onDidChangeToFalse:VoidEvent;
    final _onDidChangeToTrue = new VoidEmitter();
    final _onDidChangeToFalse = new VoidEmitter();
    var _value:Int = 0; // 0 not set, 1 true, 2 false

    public function new() {
        onDidChangeToTrue = _onDidChangeToTrue.event;
        onDidChangeToFalse = _onDidChangeToFalse.event;
    }

    public var value(get, never):Bool;
    function get_value():Bool {
        return _value == 1;
    }

    public function setValue(value:Bool):Void {
        final newValue = value ? 1 : 2;
        if (_value == newValue) {
            return;
        }
        _value = newValue;
        if (newValue == 1) {
            _onDidChangeToTrue.fire();
        }
        else {
            _onDidChangeToFalse.fire();
        }
    }

    public function dispose():Void {
        _onDidChangeToTrue.dispose();
        _onDidChangeToFalse.dispose();
    }
}

/**
 * Monaco's `CodeEditorContributions`: the contributions of an editor. The
 * eager ones are created with the editor, the others when first asked for
 * (`get`) or when a model is attached (Monaco creates them in idle time).
 */
private class CodeEditorContributions implements IDisposable {

    var _editor:Null<ICodeEditor> = null;
    final _instances = new Map<String, IEditorContribution>();
    final _pending = new Map<String, IEditorContributionDescription>();
    final _order:Array<String> = [];

    public function new() {}

    public function initialize(editor:ICodeEditor, contributions:Array<IEditorContributionDescription>):Void {
        _editor = editor;
        for (desc in contributions) {
            if (_pending.exists(desc.id)) {
                Errors.onUnexpectedError('Cannot have two contributions with the same id ' + desc.id);
                continue;
            }
            _pending.set(desc.id, desc);
            _order.push(desc.id);
        }
        // Eager contributions are created now
        for (desc in contributions) {
            if (desc.instantiation == EditorContributionInstantiation.Eager) {
                _instantiateById(desc.id);
            }
        }
    }

    public function onAfterModelAttached():Null<IDisposable> {
        // Monaco creates the AfterFirstRender contributions when the window is
        // idle after the model is attached (50 ms at most), and the
        // Eventually ones in idle time later: both are created now here
        for (instantiation in [EditorContributionInstantiation.AfterFirstRender, EditorContributionInstantiation.Eventually]) {
            for (id in _order.copy()) {
                final desc = _pending.get(id);
                if (desc != null && desc.instantiation == instantiation) {
                    _instantiateById(id);
                }
            }
        }
        return null;
    }

    /**
     * Monaco creates the `BeforeFirstInteraction` contributions before an
     * interaction event.
     */
    public function onBeforeInteractionEvent():Void {
        for (id in _order.copy()) {
            final desc = _pending.get(id);
            if (desc != null && desc.instantiation == EditorContributionInstantiation.BeforeFirstInteraction) {
                _instantiateById(id);
            }
        }
    }

    public function saveViewState():Map<String, Any> {
        final contributionsState = new Map<String, Any>();
        for (id => contribution in _instances) {
            final state = contribution.saveViewState();
            if (state != null) {
                contributionsState.set(id, state);
            }
        }
        return contributionsState;
    }

    public function restoreViewState(contributionsState:Null<Map<String, Any>>):Void {
        if (contributionsState == null) {
            return;
        }
        for (id => contribution in _instances) {
            if (contributionsState.exists(id)) {
                contribution.restoreViewState(contributionsState.get(id));
            }
        }
    }

    public function get(id:String):Null<IEditorContribution> {
        _instantiateById(id);
        return _instances.get(id);
    }

    function _instantiateById(id:String):Void {
        final desc = _pending.get(id);
        if (desc == null || _editor == null) {
            return;
        }
        _pending.remove(id);
        try {
            final instance = desc.ctor(_editor);
            _instances.set(id, instance);
        }
        catch (e:Dynamic) {
            Errors.onUnexpectedError(e);
        }
    }

    public function dispose():Void {
        for (id in _order) {
            final instance = _instances.get(id);
            if (instance != null) {
                instance.dispose();
            }
        }
        _instances.clear();
        _pending.clear();
        _editor = null;
    }

}

/**
 * Monaco's `InternalEditorAction` (editorAction.ts).
 */
class InternalEditorAction implements IEditorAction {

    public final id:String;
    public final label:String;
    public final alias:String;
    public final metadata:Null<ICommandMetadata>;
    final _precondition:Null<ContextKeyExpression>;
    final _run:(args:Any) -> Void;
    final _contextKeyService:IContextKeyService;

    public function new(id:String, label:String, alias:String, metadata:Null<ICommandMetadata>, precondition:Null<ContextKeyExpression>, run:(args:Any) -> Void, contextKeyService:IContextKeyService) {
        this.id = id;
        this.label = label;
        this.alias = alias;
        this.metadata = metadata;
        this._precondition = precondition;
        this._run = run;
        this._contextKeyService = contextKeyService;
    }

    public function isSupported():Bool {
        return this._contextKeyService.contextMatchesRules(this._precondition);
    }

    public function run(?args:Any):Void {
        if (!this.isSupported()) {
            return;
        }
        this._run(args);
    }

}

/**
 * A code editor (Monaco's `CodeEditorWidget`) without the DOM: the model
 * and its view model, the options, the context keys, the contributions and
 * actions, the decorations of the editor and its events. The Glaze view
 * (`CityscapeView`, through `ICodeEditorView`) renders it and feeds it the
 * input; without a view (tests), it is Monaco's view less editor.
 *
 * `context` is the `Cityscape` context: its services are Monaco's injected
 * services, its registries the contributions and commands.
 */
class CodeEditorWidget extends Disposable implements ICodeEditor {

    static var EDITOR_ID = 0;

    //#region Eventing
    final _onDidDispose = new VoidEmitter();
    final _onDidChangeModelContent = new Emitter<IModelContentChangedEvent>();
    final _onDidChangeModelLanguage = new Emitter<IModelLanguageChangedEvent>();
    final _onDidChangeModelLanguageConfiguration = new Emitter<IModelLanguageConfigurationChangedEvent>();
    final _onDidChangeModelOptions = new Emitter<IModelOptionsChangedEvent>();
    final _onDidChangeModelDecorations = new Emitter<IModelDecorationsChangedEvent>();
    final _onDidChangeModelTokens = new Emitter<IModelTokensChangedEvent>();
    final _onDidChangeConfiguration = new Emitter<ConfigurationChangedEvent>();
    final _onWillChangeModel = new Emitter<IModelChangedEvent>();
    final _onDidChangeModel = new Emitter<IModelChangedEvent>();
    final _onDidChangeCursorPosition = new Emitter<ICursorPositionChangedEvent>();
    final _onDidChangeCursorSelection = new Emitter<ICursorSelectionChangedEvent>();
    final _onDidAttemptReadOnlyEdit = new VoidEmitter();
    final _onDidLayoutChange = new Emitter<EditorLayoutInfo>();
    final _editorTextFocus = new BooleanEventEmitter();
    final _editorWidgetFocus = new BooleanEventEmitter();
    final _onWillType = new Emitter<String>();
    final _onDidType = new Emitter<String>();
    final _onDidCompositionStart = new VoidEmitter();
    final _onDidCompositionEnd = new VoidEmitter();
    final _onDidPaste = new Emitter<IPasteEvent>();
    final _onMouseUp = new Emitter<IEditorMouseEvent>();
    final _onMouseDown = new Emitter<IEditorMouseEvent>();
    final _onContextMenu = new Emitter<IEditorMouseEvent>();
    final _onMouseMove = new Emitter<IEditorMouseEvent>();
    final _onMouseLeave = new Emitter<IPartialEditorMouseEvent>();
    final _onKeyUp = new Emitter<cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent>();
    final _onKeyDown = new Emitter<cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent>();
    final _onDidContentSizeChange = new Emitter<IContentSizeChangedEvent>();
    final _onDidScrollChange = new Emitter<IScrollEvent>();
    final _onDidChangeHiddenAreas = new VoidEmitter();
    final _onDidChangeViewZones = new VoidEmitter();
    final _onBeginUpdate = new VoidEmitter();
    final _onEndUpdate = new VoidEmitter();

    public var onDidChangeModelContent(get, never):Event<IModelContentChangedEvent>;
    inline function get_onDidChangeModelContent() return _onDidChangeModelContent.event;
    public var onDidChangeModelLanguage(get, never):Event<IModelLanguageChangedEvent>;
    inline function get_onDidChangeModelLanguage() return _onDidChangeModelLanguage.event;
    public var onDidChangeModelLanguageConfiguration(get, never):Event<IModelLanguageConfigurationChangedEvent>;
    inline function get_onDidChangeModelLanguageConfiguration() return _onDidChangeModelLanguageConfiguration.event;
    public var onDidChangeModelOptions(get, never):Event<IModelOptionsChangedEvent>;
    inline function get_onDidChangeModelOptions() return _onDidChangeModelOptions.event;
    public var onDidChangeModelDecorations(get, never):Event<IModelDecorationsChangedEvent>;
    inline function get_onDidChangeModelDecorations() return _onDidChangeModelDecorations.event;
    public var onDidChangeModelTokens(get, never):Event<IModelTokensChangedEvent>;
    inline function get_onDidChangeModelTokens() return _onDidChangeModelTokens.event;
    public var onDidChangeConfiguration(get, never):Event<ConfigurationChangedEvent>;
    inline function get_onDidChangeConfiguration() return _onDidChangeConfiguration.event;
    public var onWillChangeModel(get, never):Event<IModelChangedEvent>;
    inline function get_onWillChangeModel() return _onWillChangeModel.event;
    public var onDidChangeModel(get, never):Event<IModelChangedEvent>;
    inline function get_onDidChangeModel() return _onDidChangeModel.event;
    public var onDidChangeCursorPosition(get, never):Event<ICursorPositionChangedEvent>;
    inline function get_onDidChangeCursorPosition() return _onDidChangeCursorPosition.event;
    public var onDidChangeCursorSelection(get, never):Event<ICursorSelectionChangedEvent>;
    inline function get_onDidChangeCursorSelection() return _onDidChangeCursorSelection.event;
    public var onDidAttemptReadOnlyEdit(get, never):VoidEvent;
    inline function get_onDidAttemptReadOnlyEdit() return _onDidAttemptReadOnlyEdit.event;
    public var onDidLayoutChange(get, never):Event<EditorLayoutInfo>;
    inline function get_onDidLayoutChange() return _onDidLayoutChange.event;
    public var onDidFocusEditorText(get, never):VoidEvent;
    inline function get_onDidFocusEditorText() return _editorTextFocus.onDidChangeToTrue;
    public var onDidBlurEditorText(get, never):VoidEvent;
    inline function get_onDidBlurEditorText() return _editorTextFocus.onDidChangeToFalse;
    public var onDidFocusEditorWidget(get, never):VoidEvent;
    inline function get_onDidFocusEditorWidget() return _editorWidgetFocus.onDidChangeToTrue;
    public var onDidBlurEditorWidget(get, never):VoidEvent;
    inline function get_onDidBlurEditorWidget() return _editorWidgetFocus.onDidChangeToFalse;
    public var onWillType(get, never):Event<String>;
    inline function get_onWillType() return _onWillType.event;
    public var onDidType(get, never):Event<String>;
    inline function get_onDidType() return _onDidType.event;
    public var onDidCompositionStart(get, never):VoidEvent;
    inline function get_onDidCompositionStart() return _onDidCompositionStart.event;
    public var onDidCompositionEnd(get, never):VoidEvent;
    inline function get_onDidCompositionEnd() return _onDidCompositionEnd.event;
    public var onDidPaste(get, never):Event<IPasteEvent>;
    inline function get_onDidPaste() return _onDidPaste.event;
    public var onMouseUp(get, never):Event<IEditorMouseEvent>;
    inline function get_onMouseUp() return _onMouseUp.event;
    public var onMouseDown(get, never):Event<IEditorMouseEvent>;
    inline function get_onMouseDown() return _onMouseDown.event;
    public var onContextMenu(get, never):Event<IEditorMouseEvent>;
    inline function get_onContextMenu() return _onContextMenu.event;
    public var onMouseMove(get, never):Event<IEditorMouseEvent>;
    inline function get_onMouseMove() return _onMouseMove.event;
    public var onMouseLeave(get, never):Event<IPartialEditorMouseEvent>;
    inline function get_onMouseLeave() return _onMouseLeave.event;
    public var onKeyUp(get, never):Event<cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent>;
    inline function get_onKeyUp() return _onKeyUp.event;
    public var onKeyDown(get, never):Event<cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent>;
    inline function get_onKeyDown() return _onKeyDown.event;
    public var onDidContentSizeChange(get, never):Event<IContentSizeChangedEvent>;
    inline function get_onDidContentSizeChange() return _onDidContentSizeChange.event;
    public var onDidScrollChange(get, never):Event<IScrollEvent>;
    inline function get_onDidScrollChange() return _onDidScrollChange.event;
    public var onDidChangeHiddenAreas(get, never):VoidEvent;
    inline function get_onDidChangeHiddenAreas() return _onDidChangeHiddenAreas.event;
    public var onDidChangeViewZones(get, never):VoidEvent;
    inline function get_onDidChangeViewZones() return _onDidChangeViewZones.event;
    public var onBeginUpdate(get, never):VoidEvent;
    inline function get_onBeginUpdate() return _onBeginUpdate.event;
    public var onEndUpdate(get, never):VoidEvent;
    inline function get_onEndUpdate() return _onEndUpdate.event;

    public function onDidDispose(listener:() -> Void):IDisposable {
        return _onDidDispose.event(listener);
    }

    var _updateCounter = 0;
    //#endregion

    final _context:Cityscape;
    public var context(get, never):Cityscape;
    inline function get_context():Cityscape {
        return _context;
    }

    final _isSimpleWidget:Bool;
    public var isSimpleWidget(get, never):Bool;
    inline function get_isSimpleWidget():Bool {
        return _isSimpleWidget;
    }

    final _contextKeyService:IScopedContextKeyService;
    public var contextKeyService(get, never):IContextKeyService;
    inline function get_contextKeyService():IContextKeyService {
        return _contextKeyService;
    }

    final _id:Int;
    final _configuration:EditorConfiguration;
    final _contributions = new CodeEditorContributions();
    final _actions = new Map<String, IEditorAction>();
    final _actionOrder:Array<String> = [];
    var _contributionsDisposable:Null<IDisposable> = null;
    var _modelData:Null<ModelData> = null;
    var _view:Null<ICodeEditorView> = null;
    final _overlayWidgets:Array<IOverlayWidget> = [];
    final _monospaceLineBreaksComputerFactory:ILineBreaksComputerFactory;
    var _wrappingIndentColumns:Int = -1;
    final _keepViewStatePerModel:Bool;
    final _savedViewStates = new Map<String, ICodeEditorViewState>();
    var _disposed = false;

    /**
     * `configuration` is the editor's configuration (the view gives one
     * that measures its fonts; the tests one of 100x100 pixels).
     */
    public function new(context:Cityscape, configuration:EditorConfiguration, ?codeEditorWidgetOptions:ICodeEditorWidgetOptions) {
        super();
        if (codeEditorWidgetOptions == null) {
            codeEditorWidgetOptions = {};
        }
        this._context = context;
        this._id = (++EDITOR_ID);
        this._isSimpleWidget = codeEditorWidgetOptions.isSimpleWidget == true;
        this._keepViewStatePerModel = codeEditorWidgetOptions.keepViewStatePerModel != false;

        this._configuration = configuration;
        this._register(Lifecycle.toDisposable(() -> this._configuration.dispose()));
        this._register(this._configuration.onDidChange((e) -> {
            this._onDidChangeConfiguration.fire(e);

            final options = this._configuration.options;
            if (e.hasChanged(EditorOption.layoutInfo)) {
                final layoutInfo = options.get(EditorOption.layoutInfo);
                this._onDidLayoutChange.fire(layoutInfo);
            }
            if (e.hasChanged(EditorOption.bracketPairColorization) && this._modelData != null) {
                this._applyBracketPairColorization(this._modelData.model);
            }
        }));

        final options = this._configuration.options;
        this._monospaceLineBreaksComputerFactory = MonospaceLineBreaksComputerFactory.create(options.get(EditorOption.wordWrapBreakBeforeCharacters), options.get(EditorOption.wordWrapBreakAfterCharacters));

        this._contextKeyService = this._register(context.contextKeyService.createScoped(null));
        this._register(new EditorContextKeysManager(this, this._contextKeyService));
        this._register(new EditorModeContext(this, this._contextKeyService));

        for (emitter in ([_onDidDispose, _onDidAttemptReadOnlyEdit, _onDidCompositionStart, _onDidCompositionEnd, _onDidChangeHiddenAreas, _onDidChangeViewZones, _onBeginUpdate, _onEndUpdate] : Array<IDisposable>)) {
            this._register(emitter);
        }
        this._register(_editorTextFocus);
        this._register(_editorWidgetFocus);

        final registry = context.editorExtensions;
        final contributions = codeEditorWidgetOptions.contributions != null ? codeEditorWidgetOptions.contributions : registry.getEditorContributions();
        this._contributions.initialize(this, contributions);

        for (action in registry.getEditorActions()) {
            if (this._actions.exists(action.id)) {
                Errors.onUnexpectedError('Cannot have two actions with the same id ' + action.id);
                continue;
            }
            final internalAction = new InternalEditorAction(
                action.id,
                action.label,
                action.alias,
                action.metadata,
                action.precondition,
                (args:Any) -> {
                    this.invokeWithinContext((accessor) -> {
                        action.runEditorCommand(accessor, this, args);
                        return null;
                    });
                },
                this._contextKeyService
            );
            this._actions.set(internalAction.id, internalAction);
            this._actionOrder.push(internalAction.id);
        }

        this._context.codeEditorService.addCodeEditor(this);
    }

    /**
     * The view of the editor (its Glaze rendering), set by the view.
     */
    public function setView(view:Null<ICodeEditorView>):Void {
        this._view = view;
        final modelData = this._modelData;
        if (modelData != null && view != null) {
            view.onDidAttachModel(modelData.viewModel);
        }
    }

    public function getView():Null<ICodeEditorView> {
        return _view;
    }

    /**
     * The configuration of the editor (options, layout).
     */
    public function getConfiguration():EditorConfiguration {
        return _configuration;
    }

    public function getId():String {
        return this.getEditorType() + ':' + this._id;
    }

    /**
     * The numeric id of the editor (the owner id of its decorations).
     */
    public function getNumericId():Int {
        return this._id;
    }

    public function getEditorType():String {
        return EditorType.ICodeEditor;
    }

    override public function dispose():Void {
        if (_disposed) {
            return;
        }
        _disposed = true;
        this._context.codeEditorService.removeCodeEditor(this);

        this._actions.clear();
        this._actionOrder.resize(0);
        this._overlayWidgets.resize(0);

        this._postDetachModelCleanup(this._detachModel());

        this._onDidDispose.fire();

        this._contributions.dispose();
        for (emitter in ([_onDidChangeModelContent, _onDidChangeModelLanguage, _onDidChangeModelLanguageConfiguration, _onDidChangeModelOptions, _onDidChangeModelDecorations, _onDidChangeModelTokens, _onDidChangeConfiguration, _onWillChangeModel, _onDidChangeModel, _onDidChangeCursorPosition, _onDidChangeCursorSelection, _onDidLayoutChange, _onWillType, _onDidType, _onDidPaste, _onMouseUp, _onMouseDown, _onContextMenu, _onMouseMove, _onMouseLeave, _onKeyUp, _onKeyDown, _onDidContentSizeChange, _onDidScrollChange] : Array<IDisposable>)) {
            emitter.dispose();
        }

        super.dispose();
    }

    public function invokeWithinContext<T>(fn:(accessor:Cityscape) -> T):T {
        return this._context.codeEditorService.withInvokingEditor(this, () -> fn(this._context));
    }

    public function updateOptions(newOptions:IEditorOptions):Void {
        this._configuration.updateOptions(newOptions != null ? newOptions : {});
    }

    public function getOptions():IComputedEditorOptions {
        return this._configuration.options;
    }

    public function getOption<V>(id:EditorOption<V>):V {
        return this._configuration.options.get(id);
    }

    public function getRawOptions():IEditorOptions {
        return this._configuration.getRawOptions();
    }

    public function getConfiguredWordAtPosition(position:Position):Null<IWordAtPosition> {
        if (this._modelData == null) {
            return null;
        }
        return WordOperations.getWordAtPosition(this._modelData.model, this._configuration.options.get(EditorOption.wordSeparators), this._configuration.options.get(EditorOption.wordSegmenterLocales), position);
    }

    public function getValue(?options:{preserveBOM:Bool, lineEnding:String}):String {
        if (this._modelData == null) {
            return '';
        }

        final preserveBOM:Bool = (options != null && options.preserveBOM) ? true : false;
        var eolPreference = EndOfLinePreference.TextDefined;
        if (options != null && options.lineEnding != null && options.lineEnding == '\n') {
            eolPreference = EndOfLinePreference.LF;
        }
        else if (options != null && options.lineEnding != null && options.lineEnding == '\r\n') {
            eolPreference = EndOfLinePreference.CRLF;
        }
        return this._modelData.model.getValue(eolPreference, preserveBOM);
    }

    public function setValue(newValue:String):Void {
        this._beginUpdate();
        try {
            if (this._modelData != null) {
                this._modelData.model.setValue(newValue);
            }
        }
        catch (e:Dynamic) {
            this._endUpdate();
            throw e;
        }
        this._endUpdate();
    }

    public function getModel():Null<ITextModel> {
        if (this._modelData == null) {
            return null;
        }
        return this._modelData.model;
    }

    public function getTextModel():Null<ITextModel> {
        return getModel();
    }

    public function setModel(_model:Null<IEditorModel>):Void {
        this._beginUpdate();
        try {
            final model:Null<ITextModel> = cast _model;
            if ((this._modelData == null && model == null) || (this._modelData != null && this._modelData.model == model)) {
                // Current model is the new model
                this._endUpdate();
                return;
            }

            final e:IModelChangedEvent = {
                oldModelUrl: this._modelData != null ? this._modelData.model.uri : null,
                newModelUrl: model != null ? model.uri : null
            };
            this._onWillChangeModel.fire(e);

            // Cityscape: the view state of the model is kept (Monaco leaves it to the host)
            if (this._keepViewStatePerModel && this._modelData != null && !this._modelData.model.isDisposed()) {
                final state = this.saveViewState();
                if (state != null) {
                    this._savedViewStates.set(this._modelData.model.id, state);
                }
            }

            final hasTextFocus = this.hasTextFocus();
            final detachedModel = this._detachModel();
            this._attachModel(model);
            if (hasTextFocus && this.hasModel()) {
                this.focus();
            }

            this._onDidChangeModel.fire(e);
            this._postDetachModelCleanup(detachedModel);

            this._contributionsDisposable = this._contributions.onAfterModelAttached();

            // after the contributions saw the new model, like a host calling
            // `restoreViewState` after `setModel` in Monaco
            if (this._keepViewStatePerModel && model != null) {
                final saved = this._savedViewStates.get(model.id);
                if (saved != null) {
                    this.restoreViewState(saved);
                }
            }
        }
        catch (e:Dynamic) {
            this._endUpdate();
            throw e;
        }
        this._endUpdate();
    }

    /**
     * Forgets the view state kept for `model` (Cityscape's per model view
     * state), or for every model when null.
     */
    public function forgetViewState(?model:ITextModel):Void {
        if (model == null) {
            _savedViewStates.clear();
        }
        else {
            _savedViewStates.remove(model.id);
        }
    }

    public function getVisibleRanges():Array<Range> {
        if (this._modelData == null) {
            return [];
        }
        return this._modelData.viewModel.getVisibleRanges();
    }

    public function getVisibleRangesPlusViewportAboveBelow():Array<Range> {
        if (this._modelData == null) {
            return [];
        }
        return this._modelData.viewModel.getVisibleRangesPlusViewportAboveBelow();
    }

    static function _getVerticalOffsetAfterPosition(modelData:ModelData, modelLineNumber:Int, modelColumn:Int, includeViewZones:Bool):Float {
        final modelPosition = modelData.model.validatePosition({
            lineNumber: modelLineNumber,
            column: modelColumn
        });
        final viewPosition = modelData.viewModel.coordinatesConverter.convertModelPositionToViewPosition(modelPosition);
        return modelData.viewModel.viewLayout.getVerticalOffsetAfterLineNumber(viewPosition.lineNumber, includeViewZones);
    }

    public function getTopForLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float {
        if (this._modelData == null) {
            return -1;
        }
        return CodeEditorWidget._getVerticalOffsetForPosition(this._modelData, lineNumber, 1, includeViewZones == true);
    }

    public function getTopForPosition(lineNumber:Int, column:Int):Float {
        if (this._modelData == null) {
            return -1;
        }
        return CodeEditorWidget._getVerticalOffsetForPosition(this._modelData, lineNumber, column, false);
    }

    static function _getVerticalOffsetForPosition(modelData:ModelData, modelLineNumber:Int, modelColumn:Int, includeViewZones:Bool = false):Float {
        final modelPosition = modelData.model.validatePosition({
            lineNumber: modelLineNumber,
            column: modelColumn
        });
        final viewPosition = modelData.viewModel.coordinatesConverter.convertModelPositionToViewPosition(modelPosition);
        return modelData.viewModel.viewLayout.getVerticalOffsetForLineNumber(viewPosition.lineNumber, includeViewZones);
    }

    public function getBottomForLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float {
        if (this._modelData == null) {
            return -1;
        }
        final maxCol = this._modelData.model.getLineMaxColumn(lineNumber);
        return CodeEditorWidget._getVerticalOffsetAfterPosition(this._modelData, lineNumber, maxCol, includeViewZones == true);
    }

    public function setHiddenAreas(ranges:Array<IRange>, ?source:Any):Void {
        if (this._modelData != null) {
            this._modelData.viewModel.setHiddenAreas([for (r in ranges) Range.lift(r)], source);
        }
    }

    public function changeViewZones(callback:(accessor:IViewZoneChangeAccessor) -> Void):Void {
        if (this._modelData == null) {
            return;
        }
        // Monaco's `View.change`: the view model fires `ViewZonesChanged`
        // (and the editor `onDidChangeViewZones`) when the zones changed
        this._modelData.viewZones.changeViewZones(callback);
        if (_view != null) {
            _view.render(false);
        }
    }

    public function getWhitespaces():Array<cityscape.common.ViewModel.IEditorWhitespace> {
        if (this._modelData == null) {
            return [];
        }
        return this._modelData.viewModel.viewLayout.getWhitespaces();
    }

    /**
     * The view zones of the current view model (painted by the view), null
     * without a model.
     */
    public function getViewZones():Null<cityscape.view.viewParts.viewZones.ViewZones> {
        return this._modelData != null ? this._modelData.viewZones : null;
    }

    public function getVisibleColumnFromPosition(rawPosition:IPosition):Int {
        if (this._modelData == null) {
            return rawPosition.column;
        }

        final position = this._modelData.model.validatePosition(rawPosition);
        final tabSize = this._modelData.model.getOptions().tabSize;

        return CursorColumns.visibleColumnFromColumn(this._modelData.model.getLineContent(position.lineNumber), position.column, tabSize) + 1;
    }

    public function getStatusbarColumn(rawPosition:IPosition):Int {
        if (this._modelData == null) {
            return rawPosition.column;
        }

        final position = this._modelData.model.validatePosition(rawPosition);
        final tabSize = this._modelData.model.getOptions().tabSize;

        return CursorColumns.toStatusbarColumn(this._modelData.model.getLineContent(position.lineNumber), position.column, tabSize);
    }

    public function getPosition():Null<Position> {
        if (this._modelData == null) {
            return null;
        }
        return this._modelData.viewModel.getPosition();
    }

    public function setPosition(position:IPosition, ?source:String):Void {
        if (source == null) {
            source = 'api';
        }
        if (this._modelData == null) {
            return;
        }
        if (!Position.isIPosition(position)) {
            throw 'Invalid arguments';
        }
        this._modelData.viewModel.setSelections(source, [new Selection(position.lineNumber, position.column, position.lineNumber, position.column)]);
    }

    function _sendRevealRange(modelRange:Range, verticalType:VerticalRevealType, revealHorizontal:Bool, scrollType:ScrollType):Void {
        if (this._modelData == null) {
            return;
        }
        if (!Range.isIRange(modelRange)) {
            throw 'Invalid arguments';
        }
        final validatedModelRange = this._modelData.model.validateRange(modelRange);
        final viewRange = this._modelData.viewModel.coordinatesConverter.convertModelRangeToViewRange(validatedModelRange);

        this._modelData.viewModel.revealRange('api', revealHorizontal, viewRange, verticalType, scrollType);
    }

    static inline function st(scrollType:Null<ScrollType>):ScrollType {
        return scrollType != null ? scrollType : ScrollType.Smooth;
    }

    public function revealLine(lineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLine(lineNumber, VerticalRevealType.Simple, st(scrollType));
    }

    public function revealLineInCenter(lineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLine(lineNumber, VerticalRevealType.Center, st(scrollType));
    }

    public function revealLineInCenterIfOutsideViewport(lineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLine(lineNumber, VerticalRevealType.CenterIfOutsideViewport, st(scrollType));
    }

    public function revealLineNearTop(lineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLine(lineNumber, VerticalRevealType.NearTop, st(scrollType));
    }

    function _revealLine(lineNumber:Int, revealType:VerticalRevealType, scrollType:ScrollType):Void {
        this._sendRevealRange(
            new Range(lineNumber, 1, lineNumber, 1),
            revealType,
            false,
            scrollType
        );
    }

    public function revealPosition(position:IPosition, ?scrollType:ScrollType):Void {
        this._revealPosition(position, VerticalRevealType.Simple, true, st(scrollType));
    }

    public function revealPositionInCenter(position:IPosition, ?scrollType:ScrollType):Void {
        this._revealPosition(position, VerticalRevealType.Center, true, st(scrollType));
    }

    public function revealPositionInCenterIfOutsideViewport(position:IPosition, ?scrollType:ScrollType):Void {
        this._revealPosition(position, VerticalRevealType.CenterIfOutsideViewport, true, st(scrollType));
    }

    public function revealPositionNearTop(position:IPosition, ?scrollType:ScrollType):Void {
        this._revealPosition(position, VerticalRevealType.NearTop, true, st(scrollType));
    }

    function _revealPosition(position:IPosition, verticalType:VerticalRevealType, revealHorizontal:Bool, scrollType:ScrollType):Void {
        if (!Position.isIPosition(position)) {
            throw 'Invalid arguments';
        }

        this._sendRevealRange(
            new Range(position.lineNumber, position.column, position.lineNumber, position.column),
            verticalType,
            revealHorizontal,
            scrollType
        );
    }

    public function getSelection():Null<Selection> {
        if (this._modelData == null) {
            return null;
        }
        return this._modelData.viewModel.getSelection();
    }

    public function getSelections():Null<Array<Selection>> {
        if (this._modelData == null) {
            return null;
        }
        return this._modelData.viewModel.getSelections();
    }

    /**
     * `something` is an `IRange` (a `Range`) or an `ISelection` (a
     * `Selection`): a range selects from its start to its end.
     */
    public function setSelection(something:EitherType<IRange, ISelection>, ?source:String):Void {
        if (source == null) {
            source = 'api';
        }
        final isSelection = Std.isOfType(something, Selection) || Selection.isISelection(something);
        final isRange = !isSelection && Range.isIRange(something);

        if (!isSelection && !isRange) {
            throw 'Invalid arguments';
        }

        if (isSelection) {
            final sel:ISelection = cast something;
            this._setSelectionImpl(sel.selectionStartLineNumber, sel.selectionStartColumn, sel.positionLineNumber, sel.positionColumn, source);
        }
        else {
            // act as if it was an IRange
            final range:IRange = cast something;
            this._setSelectionImpl(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn, source);
        }
    }

    function _setSelectionImpl(selectionStartLineNumber:Int, selectionStartColumn:Int, positionLineNumber:Int, positionColumn:Int, source:String):Void {
        if (this._modelData == null) {
            return;
        }
        final selection = new Selection(selectionStartLineNumber, selectionStartColumn, positionLineNumber, positionColumn);
        this._modelData.viewModel.setSelections(source, [selection]);
    }

    public function revealLines(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLines(startLineNumber, endLineNumber, VerticalRevealType.Simple, st(scrollType));
    }

    public function revealLinesInCenter(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLines(startLineNumber, endLineNumber, VerticalRevealType.Center, st(scrollType));
    }

    public function revealLinesInCenterIfOutsideViewport(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLines(startLineNumber, endLineNumber, VerticalRevealType.CenterIfOutsideViewport, st(scrollType));
    }

    public function revealLinesNearTop(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        this._revealLines(startLineNumber, endLineNumber, VerticalRevealType.NearTop, st(scrollType));
    }

    function _revealLines(startLineNumber:Int, endLineNumber:Int, verticalType:VerticalRevealType, scrollType:ScrollType):Void {
        this._sendRevealRange(
            new Range(startLineNumber, 1, endLineNumber, 1),
            verticalType,
            false,
            scrollType
        );
    }

    public function revealRange(range:IRange, ?scrollType:ScrollType):Void {
        this._revealRange(range, VerticalRevealType.Simple, true, st(scrollType));
    }

    public function revealRangeInCenter(range:IRange, ?scrollType:ScrollType):Void {
        this._revealRange(range, VerticalRevealType.Center, true, st(scrollType));
    }

    public function revealRangeInCenterIfOutsideViewport(range:IRange, ?scrollType:ScrollType):Void {
        this._revealRange(range, VerticalRevealType.CenterIfOutsideViewport, true, st(scrollType));
    }

    public function revealRangeNearTop(range:IRange, ?scrollType:ScrollType):Void {
        this._revealRange(range, VerticalRevealType.NearTop, true, st(scrollType));
    }

    public function revealRangeNearTopIfOutsideViewport(range:IRange, ?scrollType:ScrollType):Void {
        this._revealRange(range, VerticalRevealType.NearTopIfOutsideViewport, true, st(scrollType));
    }

    public function revealRangeAtTop(range:IRange, ?scrollType:ScrollType):Void {
        this._revealRange(range, VerticalRevealType.Top, true, st(scrollType));
    }

    function _revealRange(range:IRange, verticalType:VerticalRevealType, revealHorizontal:Bool, scrollType:ScrollType):Void {
        if (!Range.isIRange(range)) {
            throw 'Invalid arguments';
        }

        this._sendRevealRange(
            Range.lift(range),
            verticalType,
            revealHorizontal,
            scrollType
        );
    }

    public function setSelections(ranges:Array<ISelection>, ?source:String, ?reason:CursorChangeReason):Void {
        if (source == null) {
            source = 'api';
        }
        if (reason == null) {
            reason = CursorChangeReason.NotSet;
        }
        if (this._modelData == null) {
            return;
        }
        if (ranges == null || ranges.length == 0) {
            throw 'Invalid arguments';
        }
        final selections:Array<Selection> = [];
        for (i in 0...ranges.length) {
            final r:Any = ranges[i];
            if (Std.isOfType(r, Selection)) {
                selections.push(cast r);
                continue;
            }
            if (!Selection.isISelection(ranges[i])) {
                throw 'Invalid arguments';
            }
            selections.push(Selection.liftSelection(ranges[i]));
        }
        this._modelData.viewModel.setSelections(source, selections, reason);
    }

    public function getContentWidth():Float {
        if (this._modelData == null) {
            return -1;
        }
        return this._modelData.viewModel.viewLayout.getContentWidth();
    }

    public function getScrollWidth():Float {
        if (this._modelData == null) {
            return -1;
        }
        return this._modelData.viewModel.viewLayout.getScrollWidth();
    }

    public function getScrollLeft():Float {
        if (this._modelData == null) {
            return -1;
        }
        return this._modelData.viewModel.viewLayout.getCurrentScrollLeft();
    }

    public function getContentHeight():Float {
        if (this._modelData == null) {
            return -1;
        }
        return this._modelData.viewModel.viewLayout.getContentHeight();
    }

    public function getScrollHeight():Float {
        if (this._modelData == null) {
            return -1;
        }
        return this._modelData.viewModel.viewLayout.getScrollHeight();
    }

    public function getScrollTop():Float {
        if (this._modelData == null) {
            return -1;
        }
        return this._modelData.viewModel.viewLayout.getCurrentScrollTop();
    }

    public function setScrollLeft(newScrollLeft:Float, ?scrollType:ScrollType):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.viewLayout.setScrollPosition({
            scrollLeft: newScrollLeft
        }, scrollType != null ? scrollType : ScrollType.Immediate);
    }

    public function setScrollTop(newScrollTop:Float, ?scrollType:ScrollType):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.viewLayout.setScrollPosition({
            scrollTop: newScrollTop
        }, scrollType != null ? scrollType : ScrollType.Immediate);
    }

    public function setScrollPosition(position:INewScrollPosition, ?scrollType:ScrollType):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.viewLayout.setScrollPosition(position, scrollType != null ? scrollType : ScrollType.Immediate);
    }

    public function hasPendingScrollAnimation():Bool {
        return false;
    }

    public function saveViewState():Null<IEditorViewState> {
        if (this._modelData == null) {
            return null;
        }
        final contributionsState = this._contributions.saveViewState();
        final cursorState = this._modelData.viewModel.saveCursorState();
        final viewState = this._modelData.viewModel.saveState();
        final result:ICodeEditorViewState = {
            cursorState: cursorState,
            viewState: {
                scrollLeft: viewState.scrollLeft,
                firstPosition: viewState.firstPosition,
                firstPositionDeltaTop: viewState.firstPositionDeltaTop
            },
            contributionsState: contributionsState
        };
        return result;
    }

    /**
     * Monaco restores the view state only with a real view; Cityscape
     * restores the cursors and contributions without one too, and the
     * scroll position when the editor has a view.
     */
    public function restoreViewState(s:Null<IEditorViewState>):Void {
        if (this._modelData == null) {
            return;
        }
        final codeEditorState:Null<ICodeEditorViewState> = cast s;
        if (codeEditorState != null && codeEditorState.cursorState != null && codeEditorState.viewState != null) {
            final cursorState = codeEditorState.cursorState;
            if (cursorState.length > 0) {
                this._modelData.viewModel.restoreCursorState(cursorState);
            }

            this._contributions.restoreViewState(codeEditorState.contributionsState);
            final reducedState = this._modelData.viewModel.reduceRestoreState({
                scrollLeft: codeEditorState.viewState.scrollLeft,
                firstPosition: codeEditorState.viewState.firstPosition,
                firstPositionDeltaTop: codeEditorState.viewState.firstPositionDeltaTop
            });
            // Monaco's `View.restoreState`
            this._modelData.viewModel.viewLayout.setScrollPosition({
                scrollTop: reducedState.scrollTop,
                scrollLeft: reducedState.scrollLeft
            }, ScrollType.Immediate);
        }
    }

    public function handleInitialized():Void {
        final viewModel = this._getViewModel();
        if (viewModel != null) {
            viewModel.visibleLinesStabilized();
        }
    }

    public function onVisible():Void {}

    public function onHide():Void {}

    public function layout(?dimension:cityscape.common.core.Dimension.IDimension, ?postponeRendering:Bool):Void {
        this._configuration.observeContainer(dimension);
        if (postponeRendering != true) {
            this.render();
        }
    }

    public function getContribution<T:IEditorContribution>(id:String):Null<T> {
        return cast this._contributions.get(id);
    }

    public function getActions():Array<IEditorAction> {
        return [for (id in _actionOrder) _actions.get(id)];
    }

    public function getSupportedActions():Array<IEditorAction> {
        return [for (action in this.getActions()) if (action.isSupported()) action];
    }

    public function getAction(id:String):Null<IEditorAction> {
        return this._actions.get(id);
    }

    /**
     * Adds an action of this editor (`addAction` of `CityscapeEditor`).
     */
    @:allow(cityscape)
    function _addAction(action:IEditorAction, ?key:String):Void {
        if (key == null) {
            key = action.id;
        }
        this._actions.set(key, action);
        if (_actionOrder.indexOf(key) < 0) {
            _actionOrder.push(key);
        }
    }

    @:allow(cityscape)
    function _removeAction(id:String):Void {
        this._actions.remove(id);
        this._actionOrder.remove(id);
    }

    public function trigger(source:Null<String>, handlerId:String, payload:Any):Void {
        if (payload == null) {
            payload = {};
        }

        this._beginUpdate();
        try {
            _triggerImpl(source, handlerId, payload);
        }
        catch (e:Dynamic) {
            this._endUpdate();
            throw e;
        }
        this._endUpdate();
    }

    function _triggerImpl(source:Null<String>, handlerId:String, payload:Any):Void {
        switch (handlerId) {
            case Handler.CompositionStart:
                this._startComposition();
                return;
            case Handler.CompositionEnd:
                this._endComposition(source);
                return;
            case Handler.Type:
                final text:Null<String> = JsValues.field(payload, 'text');
                this._type(source, text != null ? text : '');
                return;
            case Handler.ReplacePreviousChar:
                final text:Null<String> = JsValues.field(payload, 'text');
                final replaceCharCnt:Null<Int> = JsValues.field(payload, 'replaceCharCnt');
                this._compositionType(source, text != null ? text : '', replaceCharCnt != null ? replaceCharCnt : 0, 0, 0);
                return;
            case Handler.CompositionType:
                final text:Null<String> = JsValues.field(payload, 'text');
                final replacePrevCharCnt:Null<Int> = JsValues.field(payload, 'replacePrevCharCnt');
                final replaceNextCharCnt:Null<Int> = JsValues.field(payload, 'replaceNextCharCnt');
                final positionDelta:Null<Int> = JsValues.field(payload, 'positionDelta');
                this._compositionType(source, text != null ? text : '', replacePrevCharCnt != null ? replacePrevCharCnt : 0, replaceNextCharCnt != null ? replaceNextCharCnt : 0, positionDelta != null ? positionDelta : 0);
                return;
            case Handler.Paste:
                final text:Null<String> = JsValues.field(payload, 'text');
                final pasteOnNewLine:Null<Bool> = JsValues.field(payload, 'pasteOnNewLine');
                final multicursorText:Null<Array<String>> = JsValues.field(payload, 'multicursorText');
                final mode:Null<String> = JsValues.field(payload, 'mode');
                this._paste(source, text != null ? text : '', pasteOnNewLine == true, multicursorText, mode);
                return;
            case Handler.Cut:
                this._cut(source);
                return;
            case _:
        }

        final action = this.getAction(handlerId);
        if (action != null) {
            try {
                action.run(payload);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }
            return;
        }

        if (this._modelData == null) {
            return;
        }

        if (this._triggerEditorCommand(source, handlerId, payload)) {
            return;
        }

        this._triggerCommand(handlerId, payload);
    }

    function _triggerCommand(handlerId:String, payload:Any):Void {
        this.invokeWithinContext((accessor) -> {
            this._context.commandService.executeCommand(handlerId, [payload]);
            return null;
        });
    }

    function _startComposition():Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.startComposition();
        this._onDidCompositionStart.fire();
    }

    function _endComposition(source:Null<String>):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.endComposition(source);
        this._onDidCompositionEnd.fire();
    }

    function _type(source:Null<String>, text:String):Void {
        if (this._modelData == null || text.length == 0) {
            return;
        }
        if (source == 'keyboard') {
            this._onWillType.fire(text);
        }
        this._modelData.viewModel.type(text, source);
        if (source == 'keyboard') {
            this._onDidType.fire(text);
        }
    }

    function _compositionType(source:Null<String>, text:String, replacePrevCharCnt:Int, replaceNextCharCnt:Int, positionDelta:Int):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.compositionType(text, replacePrevCharCnt, replaceNextCharCnt, positionDelta, source);
    }

    function _paste(source:Null<String>, text:String, pasteOnNewLine:Bool, multicursorText:Null<Array<String>>, mode:Null<String>):Void {
        if (this._modelData == null) {
            return;
        }
        final viewModel = this._modelData.viewModel;
        final startPosition = viewModel.getSelection().getStartPosition();
        viewModel.paste(text, pasteOnNewLine, multicursorText, source);
        final endPosition = viewModel.getSelection().getStartPosition();
        if (source == 'keyboard') {
            this._onDidPaste.fire({
                range: new Range(startPosition.lineNumber, startPosition.column, endPosition.lineNumber, endPosition.column),
                languageId: mode
            });
        }
    }

    function _cut(source:Null<String>):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.cut(source);
    }

    function _triggerEditorCommand(source:Null<String>, handlerId:String, payload:Any):Bool {
        final command = this._context.editorExtensions.getEditorCommand(handlerId);
        if (command != null) {
            if (payload == null) {
                payload = {};
            }
            if (JsValues.isObject(payload)) {
                Reflect.setField(payload, 'source', source);
            }
            this.invokeWithinContext((accessor) -> {
                try {
                    command.runEditorCommand(accessor, this, payload);
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                }
                return null;
            });
            return true;
        }

        return false;
    }

    public function _getViewModel():Null<IViewModel> {
        if (this._modelData == null) {
            return null;
        }
        return this._modelData.viewModel;
    }

    /**
     * The view model of the editor (its class), or null without a model.
     */
    public function getViewModel():Null<ViewModel> {
        return this._modelData != null ? this._modelData.viewModel : null;
    }

    public function pushUndoStop():Bool {
        if (this._modelData == null) {
            return false;
        }
        if (this._configuration.options.get(EditorOption.readOnly)) {
            // read only editor => sorry!
            return false;
        }
        this._modelData.model.pushStackElement();
        return true;
    }

    public function popUndoStop():Bool {
        if (this._modelData == null) {
            return false;
        }
        if (this._configuration.options.get(EditorOption.readOnly)) {
            // read only editor => sorry!
            return false;
        }
        this._modelData.model.popStackElement();
        return true;
    }

    public function executeEdits(source:Null<String>, edits:Array<IIdentifiedSingleEditOperation>, ?endCursorState:EitherType<Array<Selection>, ICursorStateComputer>):Bool {
        if (this._modelData == null) {
            return false;
        }
        if (this._configuration.options.get(EditorOption.readOnly)) {
            // read only editor => sorry!
            return false;
        }

        var cursorStateComputer:ICursorStateComputer;
        if (endCursorState == null) {
            cursorStateComputer = (_) -> null;
        }
        else if (Std.isOfType(endCursorState, Array)) {
            final selections:Array<Selection> = cast endCursorState;
            cursorStateComputer = (_) -> selections;
        }
        else {
            cursorStateComputer = cast endCursorState;
        }

        this._modelData.viewModel.executeEdits(source, edits, cursorStateComputer);
        return true;
    }

    public function executeCommand(source:Null<String>, command:ICommand):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.executeCommand(command, source);
    }

    public function executeCommands(source:Null<String>, commands:Array<Null<ICommand>>):Void {
        if (this._modelData == null) {
            return;
        }
        this._modelData.viewModel.executeCommands(commands, source);
    }

    public function createDecorationsCollection(?decorations:Array<IModelDeltaDecoration>):IEditorDecorationsCollection {
        return new EditorDecorationsCollection(this, decorations);
    }

    public function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T> {
        if (this._modelData == null) {
            // callback will not be called
            return null;
        }
        return this._modelData.model.changeDecorations(callback, this._id);
    }

    static function filterValidationDecorations(options:IComputedEditorOptions):Bool {
        final renderValidationDecorations = options.get(EditorOption.renderValidationDecorations);
        return renderValidationDecorations == 'off' || (renderValidationDecorations == 'editable' && options.get(EditorOption.readOnly));
    }

    public function getLineDecorations(lineNumber:Int):Null<Array<IModelDecoration>> {
        if (this._modelData == null) {
            return null;
        }
        return this._modelData.model.getLineDecorations(lineNumber, this._id, filterValidationDecorations(this._configuration.options));
    }

    public function getDecorationsInRange(range:Range):Null<Array<IModelDecoration>> {
        if (this._modelData == null) {
            return null;
        }
        return this._modelData.model.getDecorationsInRange(range, this._id, filterValidationDecorations(this._configuration.options));
    }

    public function deltaDecorations(oldDecorations:Array<String>, newDecorations:Array<IModelDeltaDecoration>):Array<String> {
        if (this._modelData == null) {
            return [];
        }

        if (oldDecorations.length == 0 && newDecorations.length == 0) {
            return oldDecorations;
        }

        return this._modelData.model.deltaDecorations(oldDecorations, newDecorations, this._id);
    }

    public function removeDecorations(decorationIds:Array<String>):Void {
        if (this._modelData == null || decorationIds.length == 0) {
            return;
        }

        this._modelData.model.changeDecorations((changeAccessor) -> {
            changeAccessor.deltaDecorations(decorationIds, []);
            return null;
        });
    }

    public function getLayoutInfo():EditorLayoutInfo {
        final options = this._configuration.options;
        final layoutInfo = options.get(EditorOption.layoutInfo);
        return layoutInfo;
    }

    public function focus():Void {
        if (this._modelData == null || this._view == null) {
            return;
        }
        this._view.focus();
    }

    public function hasTextFocus():Bool {
        if (this._modelData == null) {
            return false;
        }
        return this._editorTextFocus.value;
    }

    public function hasWidgetFocus():Bool {
        return this._editorWidgetFocus.value || this.hasTextFocus();
    }

    /**
     * Called by the view when the focus of the editor's widgets changes
     * (Monaco's `CodeEditorWidgetFocusTracker`).
     */
    public function _setWidgetFocus(hasFocus:Bool):Void {
        this._editorWidgetFocus.setValue(hasFocus);
        if (hasFocus) {
            this._context.codeEditorService.setActiveCodeEditor(this);
        }
    }

    public function addOverlayWidget(widget:IOverlayWidget):Void {
        removeOverlayWidget(widget);
        for (w in _overlayWidgets) {
            if (w.getId() == widget.getId()) {
                _overlayWidgets.remove(w);
                break;
            }
        }
        _overlayWidgets.push(widget);
        if (_view != null) {
            _view.overlayWidgetsChanged();
        }
    }

    public function layoutOverlayWidget(widget:IOverlayWidget):Void {
        if (_view != null) {
            _view.overlayWidgetsChanged();
        }
    }

    public function removeOverlayWidget(widget:IOverlayWidget):Void {
        if (_overlayWidgets.remove(widget) && _view != null) {
            _view.overlayWidgetsChanged();
        }
    }

    /**
     * The overlay widgets, in the order they were added.
     */
    public function getOverlayWidgets():Array<IOverlayWidget> {
        return _overlayWidgets.copy();
    }

    public function getTargetAtClientPoint(clientX:Float, clientY:Float):Null<IMouseTarget> {
        if (this._modelData == null || this._view == null) {
            return null;
        }
        return this._view.getTargetAtClientPoint(clientX, clientY);
    }

    public function getScrolledVisiblePosition(rawPosition:IPosition):Null<{top:Float, left:Float, height:Float}> {
        if (this._modelData == null || this._view == null) {
            return null;
        }
        final position = this._modelData.model.validatePosition(rawPosition);
        return this._view.getScrolledVisiblePosition(position);
    }

    public function getOffsetForColumn(lineNumber:Int, column:Int):Float {
        if (this._modelData == null || this._view == null) {
            return -1;
        }
        return this._view.getOffsetForColumn(lineNumber, column);
    }

    public function render(?forceRedraw:Bool):Void {
        if (this._modelData == null || this._view == null) {
            return;
        }
        this._view.render(forceRedraw == true);
    }

    public function _executeClipboardAction(action:String):Bool {
        if (this._modelData == null || this._view == null) {
            return false;
        }
        this._view.clipboardAction(action);
        return true;
    }

    /**
     * The extra indent of wrapped lines in columns per level
     * (loreline-monaco's `[loreline]` patch), -1 for Monaco's tab stops.
     */
    public function setWrappingIndentColumns(value:Int):Void {
        if (_wrappingIndentColumns == value) {
            return;
        }
        _wrappingIndentColumns = value;
        if (_modelData != null) {
            _modelData.viewModel.setWrappingIndentColumns(value);
        }
    }

    public function getWrappingIndentColumns():Int {
        return _wrappingIndentColumns;
    }

    /**
     * Monaco's standalone editor writes the `bracketPairColorization`
     * option to the configuration service, whose model service gives it to
     * the models (`bracketColorizationOptions`). Without a configuration
     * service, an editor gives the option it was set with to its model.
     */
    function _applyBracketPairColorization(model:ITextModel):Void {
        final raw:Dynamic = this._configuration.getRawOptions();
        if (raw == null || !Reflect.hasField(raw, 'bracketPairColorization')) {
            return;
        }
        final value = this._configuration.options.get(EditorOption.bracketPairColorization);
        final current = model.getOptions().bracketPairColorizationOptions;
        if (current.enabled != value.enabled || current.independentColorPoolPerBracketType != value.independentColorPoolPerBracketType) {
            model.updateOptions({bracketColorizationOptions: {enabled: value.enabled, independentColorPoolPerBracketType: value.independentColorPoolPerBracketType}});
        }
    }

    function _attachModel(model:Null<ITextModel>):Void {
        if (model == null) {
            this._modelData = null;
            return;
        }

        final listenersToRemove:Array<IDisposable> = [];

        this._configuration.setIsDominatedByLongLines(model.isDominatedByLongLines());
        this._configuration.setModelLineCount(model.getLineCount());
        this._applyBracketPairColorization(model);

        final domFactory = _view != null ? _view.createDomLineBreaksComputerFactory() : null;
        final viewModel = new ViewModel(
            this._id,
            this._configuration,
            model,
            domFactory != null ? domFactory : _monospaceLineBreaksComputerFactory,
            _monospaceLineBreaksComputerFactory,
            _wrappingIndentColumns,
            this._context
        );

        // Someone might destroy the model from under the editor, so prevent any exceptions by setting a null model
        listenersToRemove.push(model.onWillDispose(() -> this.setModel(null)));

        listenersToRemove.push(viewModel.onEvent((e) -> {
            switch (e.kind) {
                case OutgoingViewModelEventKind.ContentSizeChanged:
                    final e:ContentSizeChangedEvent = cast e;
                    this._onDidContentSizeChange.fire({
                        contentWidth: e.contentWidth,
                        contentHeight: e.contentHeight,
                        contentWidthChanged: e.contentWidthChanged,
                        contentHeightChanged: e.contentHeightChanged
                    });
                case OutgoingViewModelEventKind.FocusChanged:
                    final e:FocusChangedEvent = cast e;
                    this._editorTextFocus.setValue(e.hasFocus);
                    if (e.hasFocus) {
                        this._context.codeEditorService.setActiveCodeEditor(this);
                    }
                case OutgoingViewModelEventKind.ScrollChanged:
                    final e:ScrollChangedEvent = cast e;
                    this._onDidScrollChange.fire({
                        scrollTop: e.scrollTop,
                        scrollLeft: e.scrollLeft,
                        scrollWidth: e.scrollWidth,
                        scrollHeight: e.scrollHeight,
                        scrollTopChanged: e.scrollTopChanged,
                        scrollLeftChanged: e.scrollLeftChanged,
                        scrollWidthChanged: e.scrollWidthChanged,
                        scrollHeightChanged: e.scrollHeightChanged
                    });
                case OutgoingViewModelEventKind.ViewZonesChanged:
                    this._onDidChangeViewZones.fire();
                case OutgoingViewModelEventKind.HiddenAreasChanged:
                    this._onDidChangeHiddenAreas.fire();
                case OutgoingViewModelEventKind.ReadOnlyEditAttempt:
                    this._onDidAttemptReadOnlyEdit.fire();
                case OutgoingViewModelEventKind.CursorStateChanged:
                    final e:CursorStateChangedEvent = cast e;
                    final positions:Array<Position> = [];
                    for (i in 0...e.selections.length) {
                        positions[i] = e.selections[i].getPosition();
                    }

                    final e1:ICursorPositionChangedEvent = {
                        position: positions[0],
                        secondaryPositions: positions.slice(1),
                        reason: e.reason,
                        source: e.source
                    };
                    this._onDidChangeCursorPosition.fire(e1);

                    final e2:ICursorSelectionChangedEvent = {
                        selection: e.selections[0],
                        secondarySelections: e.selections.slice(1),
                        modelVersionId: e.modelVersionId,
                        oldSelections: e.oldSelections,
                        oldModelVersionId: e.oldModelVersionId,
                        source: e.source,
                        reason: e.reason
                    };
                    this._onDidChangeCursorSelection.fire(e2);
                case OutgoingViewModelEventKind.ModelDecorationsChanged:
                    this._onDidChangeModelDecorations.fire((cast e : ModelDecorationsChangedEvent).event);
                case OutgoingViewModelEventKind.ModelLanguageChanged:
                    this._onDidChangeModelLanguage.fire((cast e : ModelLanguageChangedEvent).event);
                case OutgoingViewModelEventKind.ModelLanguageConfigurationChanged:
                    this._onDidChangeModelLanguageConfiguration.fire((cast e : ModelLanguageConfigurationChangedEvent).event);
                case OutgoingViewModelEventKind.ModelContentChanged:
                    this._onDidChangeModelContent.fire((cast e : ModelContentChangedEvent).event);
                case OutgoingViewModelEventKind.ModelOptionsChanged:
                    this._onDidChangeModelOptions.fire((cast e : ModelOptionsChangedEvent).event);
                case OutgoingViewModelEventKind.ModelTokensChanged:
                    this._onDidChangeModelTokens.fire((cast e : ModelTokensChangedEvent).event);
                case _:
            }
        }));

        final viewZones = new cityscape.view.viewParts.viewZones.ViewZones(viewModel, this._configuration);
        viewModel.addViewEventHandler(viewZones);

        this._modelData = new ModelData(model, viewModel, listenersToRemove, viewZones);

        // The markers of the model are rendered while an editor shows it
        this._context.markerDecorationsService.ensureModel(model);

        if (_view != null) {
            _view.onDidAttachModel(viewModel);
        }
    }

    function _postDetachModelCleanup(detachedModel:Null<ITextModel>):Void {
        if (detachedModel != null && !detachedModel.isDisposed()) {
            detachedModel.removeAllDecorationsWithOwnerId(this._id);
        }
    }

    function _detachModel():Null<ITextModel> {
        if (this._contributionsDisposable != null) {
            this._contributionsDisposable.dispose();
        }
        this._contributionsDisposable = null;
        if (this._modelData == null) {
            return null;
        }
        final model = this._modelData.model;

        if (_view != null) {
            _view.onWillDetachModel(this._modelData.viewModel);
        }
        Lifecycle.dispose(cast this._modelData.listenersToRemove);
        this._modelData.viewModel.removeViewEventHandler(this._modelData.viewZones);
        this._modelData.viewZones.dispose();
        this._modelData.viewModel.dispose();
        this._modelData = null;

        return model;
    }

    public function hasModel():Bool {
        return this._modelData != null;
    }

    public function setContextValue(key:String, value:Any):Void {
        this._contextKeyService.createKey(key, value);
    }

    function _beginUpdate():Void {
        this._updateCounter++;
        if (this._updateCounter == 1) {
            this._onBeginUpdate.fire();
        }
    }

    function _endUpdate():Void {
        this._updateCounter--;
        if (this._updateCounter == 0) {
            this._onEndUpdate.fire();
        }
    }

    //#region input from the view

    /**
     * Fires `onMouseDown` (the view's mouse handler).
     */
    @:allow(cityscape)
    function _fireMouseDown(e:IEditorMouseEvent):Void {
        _contributions.onBeforeInteractionEvent();
        _onMouseDown.fire(e);
    }

    @:allow(cityscape)
    function _fireMouseUp(e:IEditorMouseEvent):Void {
        _contributions.onBeforeInteractionEvent();
        _onMouseUp.fire(e);
    }

    @:allow(cityscape)
    function _fireMouseMove(e:IEditorMouseEvent):Void {
        _onMouseMove.fire(e);
    }

    @:allow(cityscape)
    function _fireMouseLeave(e:IPartialEditorMouseEvent):Void {
        _onMouseLeave.fire(e);
    }

    @:allow(cityscape)
    function _fireContextMenu(e:IEditorMouseEvent):Void {
        _contributions.onBeforeInteractionEvent();
        _onContextMenu.fire(e);
    }

    @:allow(cityscape)
    function _fireKeyDown(e:cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent):Void {
        _contributions.onBeforeInteractionEvent();
        _onKeyDown.fire(e);
    }

    @:allow(cityscape)
    function _fireKeyUp(e:cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent):Void {
        _onKeyUp.fire(e);
    }

    /**
     * Types text from the keyboard (Monaco's view controller `type`).
     */
    @:allow(cityscape)
    function _typeFromKeyboard(text:String):Void {
        _contributions.onBeforeInteractionEvent();
        this._type('keyboard', text);
    }

    /**
     * Pastes from the keyboard (Monaco's view controller `paste`).
     */
    @:allow(cityscape)
    function _pasteFromKeyboard(text:String, pasteOnNewLine:Bool, multicursorText:Null<Array<String>>, mode:Null<String>):Void {
        this._paste('keyboard', text, pasteOnNewLine, multicursorText, mode);
    }

    //#endregion

}

private class EditorContextKeysManager extends Disposable {

    final _editor:CodeEditorWidget;
    final _editorSimpleInput:IContextKey<Bool>;
    final _editorFocus:IContextKey<Bool>;
    final _textInputFocus:IContextKey<Bool>;
    final _editorTextFocus:IContextKey<Bool>;
    final _tabMovesFocus:IContextKey<Bool>;
    final _editorReadonly:IContextKey<Bool>;
    final _inDiffEditor:IContextKey<Bool>;
    final _editorColumnSelection:IContextKey<Bool>;
    final _hasMultipleSelections:IContextKey<Bool>;
    final _hasNonEmptySelection:IContextKey<Bool>;
    final _canUndo:IContextKey<Bool>;
    final _canRedo:IContextKey<Bool>;

    public function new(editor:CodeEditorWidget, contextKeyService:IContextKeyService) {
        super();

        this._editor = editor;

        contextKeyService.createKey('editorId', editor.getId());

        this._editorSimpleInput = EditorContextKeys.editorSimpleInput.bindTo(contextKeyService);
        this._editorFocus = EditorContextKeys.focus.bindTo(contextKeyService);
        this._textInputFocus = EditorContextKeys.textInputFocus.bindTo(contextKeyService);
        this._editorTextFocus = EditorContextKeys.editorTextFocus.bindTo(contextKeyService);
        this._tabMovesFocus = EditorContextKeys.tabMovesFocus.bindTo(contextKeyService);
        this._editorReadonly = EditorContextKeys.readOnly.bindTo(contextKeyService);
        this._inDiffEditor = EditorContextKeys.inDiffEditor.bindTo(contextKeyService);
        this._editorColumnSelection = EditorContextKeys.columnSelection.bindTo(contextKeyService);
        this._hasMultipleSelections = EditorContextKeys.hasMultipleSelections.bindTo(contextKeyService);
        this._hasNonEmptySelection = EditorContextKeys.hasNonEmptySelection.bindTo(contextKeyService);
        this._canUndo = EditorContextKeys.canUndo.bindTo(contextKeyService);
        this._canRedo = EditorContextKeys.canRedo.bindTo(contextKeyService);

        this._register(this._editor.onDidChangeConfiguration((_) -> this._updateFromConfig()));
        this._register(this._editor.onDidChangeCursorSelection((_) -> this._updateFromSelection()));
        this._register(this._editor.onDidFocusEditorWidget(() -> this._updateFromFocus()));
        this._register(this._editor.onDidBlurEditorWidget(() -> this._updateFromFocus()));
        this._register(this._editor.onDidFocusEditorText(() -> this._updateFromFocus()));
        this._register(this._editor.onDidBlurEditorText(() -> this._updateFromFocus()));
        this._register(this._editor.onDidChangeModel((_) -> this._updateFromModel()));
        this._register(this._editor.onDidChangeConfiguration((_) -> this._updateFromModel()));
        // Cityscape: the undo state follows the content (Monaco updates it in the workbench)
        this._register(this._editor.onDidChangeModelContent((_) -> this._updateFromModel()));

        this._updateFromConfig();
        this._updateFromSelection();
        this._updateFromFocus();
        this._updateFromModel();

        this._editorSimpleInput.set(this._editor.isSimpleWidget);
    }

    function _updateFromConfig():Void {
        final options = this._editor.getOptions();

        // Cityscape has no tab focus mode (TabFocus): Tab always indents
        this._tabMovesFocus.set(false);
        this._editorReadonly.set(options.get(EditorOption.readOnly));
        this._inDiffEditor.set(options.get(EditorOption.inDiffEditor));
        this._editorColumnSelection.set(options.get(EditorOption.columnSelection));
    }

    function _updateFromSelection():Void {
        final selections = this._editor.getSelections();
        if (selections == null) {
            this._hasMultipleSelections.reset();
            this._hasNonEmptySelection.reset();
        }
        else {
            this._hasMultipleSelections.set(selections.length > 1);
            var nonEmpty = false;
            for (s in selections) {
                if (!s.isEmpty()) {
                    nonEmpty = true;
                    break;
                }
            }
            this._hasNonEmptySelection.set(nonEmpty);
        }
    }

    function _updateFromFocus():Void {
        this._editorFocus.set(this._editor.hasWidgetFocus() && !this._editor.isSimpleWidget);
        this._editorTextFocus.set(this._editor.hasTextFocus() && !this._editor.isSimpleWidget);
        this._textInputFocus.set(this._editor.hasTextFocus());
    }

    function _updateFromModel():Void {
        final model = this._editor.getModel();
        this._canUndo.set(model != null && model.canUndo());
        this._canRedo.set(model != null && model.canRedo());
    }

}

/**
 * Monaco's `EditorModeContext`: the language of the model and whether the
 * registries of the context have providers for it
 * (`editorHasCompletionItemProvider`...).
 */
private class EditorModeContext extends Disposable {

    final _editor:CodeEditorWidget;
    final _langId:IContextKey<String>;
    final _hasCompletionItemProvider:IContextKey<Bool>;
    final _hasCodeActionsProvider:IContextKey<Bool>;
    final _hasCodeLensProvider:IContextKey<Bool>;
    final _hasDefinitionProvider:IContextKey<Bool>;
    final _hasDeclarationProvider:IContextKey<Bool>;
    final _hasImplementationProvider:IContextKey<Bool>;
    final _hasTypeDefinitionProvider:IContextKey<Bool>;
    final _hasHoverProvider:IContextKey<Bool>;
    final _hasDocumentHighlightProvider:IContextKey<Bool>;
    final _hasDocumentSymbolProvider:IContextKey<Bool>;
    final _hasReferenceProvider:IContextKey<Bool>;
    final _hasRenameProvider:IContextKey<Bool>;
    final _hasDocumentFormattingProvider:IContextKey<Bool>;
    final _hasDocumentSelectionFormattingProvider:IContextKey<Bool>;
    final _hasMultipleDocumentFormattingProvider:IContextKey<Bool>;
    final _hasMultipleDocumentSelectionFormattingProvider:IContextKey<Bool>;
    final _hasSignatureHelpProvider:IContextKey<Bool>;
    final _hasInlayHintsProvider:IContextKey<Bool>;
    final _isInEmbeddedEditor:IContextKey<Bool>;

    public function new(editor:CodeEditorWidget, contextKeyService:IContextKeyService) {
        super();
        this._editor = editor;
        this._langId = EditorContextKeys.languageId.bindTo(contextKeyService);
        this._hasCompletionItemProvider = EditorContextKeys.hasCompletionItemProvider.bindTo(contextKeyService);
        this._hasCodeActionsProvider = EditorContextKeys.hasCodeActionsProvider.bindTo(contextKeyService);
        this._hasCodeLensProvider = EditorContextKeys.hasCodeLensProvider.bindTo(contextKeyService);
        this._hasDefinitionProvider = EditorContextKeys.hasDefinitionProvider.bindTo(contextKeyService);
        this._hasDeclarationProvider = EditorContextKeys.hasDeclarationProvider.bindTo(contextKeyService);
        this._hasImplementationProvider = EditorContextKeys.hasImplementationProvider.bindTo(contextKeyService);
        this._hasTypeDefinitionProvider = EditorContextKeys.hasTypeDefinitionProvider.bindTo(contextKeyService);
        this._hasHoverProvider = EditorContextKeys.hasHoverProvider.bindTo(contextKeyService);
        this._hasDocumentHighlightProvider = EditorContextKeys.hasDocumentHighlightProvider.bindTo(contextKeyService);
        this._hasDocumentSymbolProvider = EditorContextKeys.hasDocumentSymbolProvider.bindTo(contextKeyService);
        this._hasReferenceProvider = EditorContextKeys.hasReferenceProvider.bindTo(contextKeyService);
        this._hasRenameProvider = EditorContextKeys.hasRenameProvider.bindTo(contextKeyService);
        this._hasDocumentFormattingProvider = EditorContextKeys.hasDocumentFormattingProvider.bindTo(contextKeyService);
        this._hasDocumentSelectionFormattingProvider = EditorContextKeys.hasDocumentSelectionFormattingProvider.bindTo(contextKeyService);
        this._hasMultipleDocumentFormattingProvider = EditorContextKeys.hasMultipleDocumentFormattingProvider.bindTo(contextKeyService);
        this._hasMultipleDocumentSelectionFormattingProvider = EditorContextKeys.hasMultipleDocumentSelectionFormattingProvider.bindTo(contextKeyService);
        this._hasSignatureHelpProvider = EditorContextKeys.hasSignatureHelpProvider.bindTo(contextKeyService);
        this._hasInlayHintsProvider = EditorContextKeys.hasInlayHintsProvider.bindTo(contextKeyService);
        this._isInEmbeddedEditor = EditorContextKeys.isInEmbeddedEditor.bindTo(contextKeyService);

        // update when model/mode changes
        this._register(editor.onDidChangeModel((_) -> this._update()));
        this._register(editor.onDidChangeModelLanguage((_) -> this._update()));

        // update when registries change
        final lfs = editor.context.languageFeaturesService;
        this._register(lfs.completionProvider.onDidChange(_ -> this._update()));
        this._register(lfs.codeActionProvider.onDidChange(_ -> this._update()));
        this._register(lfs.codeLensProvider.onDidChange(_ -> this._update()));
        this._register(lfs.definitionProvider.onDidChange(_ -> this._update()));
        this._register(lfs.declarationProvider.onDidChange(_ -> this._update()));
        this._register(lfs.implementationProvider.onDidChange(_ -> this._update()));
        this._register(lfs.typeDefinitionProvider.onDidChange(_ -> this._update()));
        this._register(lfs.hoverProvider.onDidChange(_ -> this._update()));
        this._register(lfs.documentHighlightProvider.onDidChange(_ -> this._update()));
        this._register(lfs.documentSymbolProvider.onDidChange(_ -> this._update()));
        this._register(lfs.referenceProvider.onDidChange(_ -> this._update()));
        this._register(lfs.renameProvider.onDidChange(_ -> this._update()));
        this._register(lfs.documentFormattingEditProvider.onDidChange(_ -> this._update()));
        this._register(lfs.documentRangeFormattingEditProvider.onDidChange(_ -> this._update()));
        this._register(lfs.signatureHelpProvider.onDidChange(_ -> this._update()));
        this._register(lfs.inlayHintsProvider.onDidChange(_ -> this._update()));

        this._update();
    }

    function reset():Void {
        this._langId.reset();
        this._hasCompletionItemProvider.reset();
        this._hasCodeActionsProvider.reset();
        this._hasCodeLensProvider.reset();
        this._hasDefinitionProvider.reset();
        this._hasDeclarationProvider.reset();
        this._hasImplementationProvider.reset();
        this._hasTypeDefinitionProvider.reset();
        this._hasHoverProvider.reset();
        this._hasDocumentHighlightProvider.reset();
        this._hasDocumentSymbolProvider.reset();
        this._hasReferenceProvider.reset();
        this._hasRenameProvider.reset();
        this._hasDocumentFormattingProvider.reset();
        this._hasDocumentSelectionFormattingProvider.reset();
        this._hasSignatureHelpProvider.reset();
        this._isInEmbeddedEditor.reset();
    }

    function _update():Void {
        final model = this._editor.getModel();
        if (model == null) {
            this.reset();
            return;
        }
        final lfs = this._editor.context.languageFeaturesService;
        this._langId.set(model.getLanguageId());
        this._hasCompletionItemProvider.set(lfs.completionProvider.has(model));
        this._hasCodeActionsProvider.set(lfs.codeActionProvider.has(model));
        this._hasCodeLensProvider.set(lfs.codeLensProvider.has(model));
        this._hasDefinitionProvider.set(lfs.definitionProvider.has(model));
        this._hasDeclarationProvider.set(lfs.declarationProvider.has(model));
        this._hasImplementationProvider.set(lfs.implementationProvider.has(model));
        this._hasTypeDefinitionProvider.set(lfs.typeDefinitionProvider.has(model));
        this._hasHoverProvider.set(lfs.hoverProvider.has(model));
        this._hasDocumentHighlightProvider.set(lfs.documentHighlightProvider.has(model));
        this._hasDocumentSymbolProvider.set(lfs.documentSymbolProvider.has(model));
        this._hasReferenceProvider.set(lfs.referenceProvider.has(model));
        this._hasRenameProvider.set(lfs.renameProvider.has(model));
        this._hasSignatureHelpProvider.set(lfs.signatureHelpProvider.has(model));
        this._hasInlayHintsProvider.set(lfs.inlayHintsProvider.has(model));
        this._hasDocumentFormattingProvider.set(lfs.documentFormattingEditProvider.has(model) || lfs.documentRangeFormattingEditProvider.has(model));
        this._hasDocumentSelectionFormattingProvider.set(lfs.documentRangeFormattingEditProvider.has(model));
        this._hasMultipleDocumentFormattingProvider.set(lfs.documentFormattingEditProvider.all(model).length + lfs.documentRangeFormattingEditProvider.all(model).length > 1);
        this._hasMultipleDocumentSelectionFormattingProvider.set(lfs.documentRangeFormattingEditProvider.all(model).length > 1);
        this._isInEmbeddedEditor.set(model.uri.scheme == 'walkThroughSnippet' || model.uri.scheme == 'vscode-chat-code-block');
    }

}

/**
 * A collection of decorations of an editor (Monaco's
 * `EditorDecorationsCollection`).
 */
class EditorDecorationsCollection implements IEditorDecorationsCollection {

    var _decorationIds:Array<String> = [];
    var _isChangingDecorations:Bool = false;
    final _editor:ICodeEditor;

    public var length(get, never):Int;
    function get_length():Int {
        return this._decorationIds.length;
    }

    public final onDidChange:Event<IModelDecorationsChangedEvent>;

    public function new(editor:ICodeEditor, ?decorations:Array<IModelDeltaDecoration>) {
        this._editor = editor;
        this.onDidChange = (listener) -> this._editor.onDidChangeModelDecorations((e) -> {
            if (this._isChangingDecorations) {
                return;
            }
            listener(e);
        });
        if (decorations != null && decorations.length > 0) {
            this.set(decorations);
        }
    }

    public function getRange(index:Int):Null<Range> {
        if (!this._editor.hasModel()) {
            return null;
        }
        if (index >= this._decorationIds.length) {
            return null;
        }
        return this._editor.getModel().getDecorationRange(this._decorationIds[index]);
    }

    public function getRanges():Array<Range> {
        if (!this._editor.hasModel()) {
            return [];
        }
        final model = this._editor.getModel();
        final result:Array<Range> = [];
        for (decorationId in this._decorationIds) {
            final range = model.getDecorationRange(decorationId);
            if (range != null) {
                result.push(range);
            }
        }
        return result;
    }

    public function has(decoration:IModelDecoration):Bool {
        return this._decorationIds.indexOf(decoration.id) >= 0;
    }

    public function clear():Void {
        if (this._decorationIds.length == 0) {
            // nothing to do
            return;
        }
        this.set([]);
    }

    public function set(newDecorations:Array<IModelDeltaDecoration>):Array<String> {
        this._isChangingDecorations = true;
        try {
            this._editor.changeDecorations((accessor) -> {
                this._decorationIds = accessor.deltaDecorations(this._decorationIds, newDecorations);
                return null;
            });
        }
        catch (e:Dynamic) {
            this._isChangingDecorations = false;
            throw e;
        }
        this._isChangingDecorations = false;
        return this._decorationIds;
    }

    public function append(newDecorations:Array<IModelDeltaDecoration>):Array<String> {
        var newDecorationIds:Array<String> = [];
        this._isChangingDecorations = true;
        try {
            this._editor.changeDecorations((accessor) -> {
                newDecorationIds = accessor.deltaDecorations([], newDecorations);
                this._decorationIds = this._decorationIds.concat(newDecorationIds);
                return null;
            });
        }
        catch (e:Dynamic) {
            this._isChangingDecorations = false;
            throw e;
        }
        this._isChangingDecorations = false;
        return newDecorationIds;
    }

}
