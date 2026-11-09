// Ported from vscode src/vs/editor/contrib/gotoSymbol/browser/peek/referencesController.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoSymbol.view.peek;

import cityscape.Cityscape;
import cityscape.base.common.Errors;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.Location;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.gotoSymbol.view.ReferencesModel;
import cityscape.contrib.gotoSymbol.view.peek.ReferencesWidget;
import cityscape.contrib.peekView.view.PeekView;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.storage.common.Storage;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/**
 * Shows the references in the peek view of an editor (Monaco's
 * `ReferencesController`, the standalone `StandaloneReferencesController`
 * with the tree keyboard support).
 *
 * Monaco's promise of the model is cancelable: here a newer request (or a
 * close) makes the result of an older one ignored, like Monaco's request
 * ids.
 */
class ReferencesController implements IEditorContribution {

    public static inline final ID = 'editor.contrib.referencesController';

    static var _ctxReferenceSearchVisible:Null<RawContextKey<Bool>> = null;

    /**
     * `referenceSearchVisible`: whether the reference peek is visible.
     */
    public static var ctxReferenceSearchVisible(get, never):RawContextKey<Bool>;
    static function get_ctxReferenceSearchVisible():RawContextKey<Bool> {
        if (_ctxReferenceSearchVisible == null) {
            _ctxReferenceSearchVisible = new RawContextKey<Bool>('referenceSearchVisible', false, "Whether reference peek is visible, like 'Peek References' or 'Peek Definition'");
        }
        return _ctxReferenceSearchVisible;
    }

    final _disposables = new DisposableStore();

    var _widget:Null<ReferenceWidget> = null;
    var _model:Null<ReferencesModel> = null;
    var _peekMode:Null<Bool> = null;
    var _requestIdPool:Int = 0;
    var _ignoreModelChangeEvent:Bool = false;

    final _referenceSearchVisible:IContextKey<Bool>;
    final _editor:ICodeEditor;

    public static function get(editor:ICodeEditor):Null<ReferencesController> {
        return editor.getContribution(ReferencesController.ID);
    }

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this._referenceSearchVisible = ctxReferenceSearchVisible.bindTo(editor.contextKeyService);
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        this._referenceSearchVisible.reset();
        this._disposables.dispose();
        if (this._widget != null) this._widget.dispose();
        if (this._model != null) this._model.dispose();
        this._widget = null;
        this._model = null;
    }

    /**
     * The peek view, when shown (tests).
     */
    public function getWidget():Null<ReferenceWidget> {
        return _widget;
    }

    public function toggleWidget(range:Range, modelPromise:Promise<ReferencesModel>, peekMode:Bool):Void {

        // close current widget and return early is position didn't change
        var widgetPosition:Null<Position> = null;
        if (this._widget != null) {
            widgetPosition = this._widget.position;
        }
        this.closeWidget();
        if (widgetPosition != null && range.containsPosition(widgetPosition)) {
            return;
        }

        this._peekMode = peekMode;
        this._referenceSearchVisible.set(true);

        // close the widget on model/mode changes
        this._disposables.add(this._editor.onDidChangeModelLanguage(_ -> this.closeWidget()));
        this._disposables.add(this._editor.onDidChangeModel(_ -> {
            if (!this._ignoreModelChangeEvent) {
                this.closeWidget();
            }
        }));
        final storage = this._editor.context.storageService;
        final storageKey = 'peekViewLayout';
        final data = LayoutData.fromJSON(storage.get(storageKey, StorageScope.PROFILE, '{}'));
        final widget = new ReferenceWidget(this._editor, data);
        this._widget = widget;
        widget.setTitle(widget.localize('labelLoading', "Loading..."));
        widget.show(range);

        this._disposables.add(widget.onDidClose(() -> {
            if (this._widget == widget) {
                storage.store(storageKey, widget.layoutData.toJSON(), StorageScope.PROFILE, StorageTarget.MACHINE);
                this._widget = null;
                this.closeWidget();
            }
        }));

        this._disposables.add(widget.onDidSelectReference(event -> {
            final element = event.element;
            if (element == null) {
                return;
            }
            switch event.kind {
                case 'open':
                    if (event.source != 'editor' || this._editor.context.configurationService.getValue('editor.stablePeek') != true) {
                        // when stable peek is configured we don't close
                        // the peek window on selecting the editor
                        this.openReference(element, false, false);
                    }
                case 'side':
                    this.openReference(element, true, false);
                case 'goto':
                    if (peekMode) {
                        this._gotoReference(element, true);
                    }
                    else {
                        this.openReference(element, false, true);
                    }
                case _:
            }
        }));

        final requestId = ++this._requestIdPool;

        modelPromise.done(model -> {
            if (model == null) {
                return;
            }

            // still current request? widget still open?
            if (requestId != this._requestIdPool || this._widget == null) {
                model.dispose();
                return;
            }

            if (this._model != null) this._model.dispose();
            this._model = model;

            // show widget
            final widget = this._widget;
            widget.setModel(model);
            if (this._widget != null && this._model != null && this._editor.hasModel()) { // might have been closed

                // set title
                if (!model.isEmpty) {
                    widget.setMetaTitle(widget.localize('metaTitle.N', "{0} ({1})", [model.title, model.references.length]));
                }
                else {
                    widget.setMetaTitle('');
                }

                // set 'best' selection
                final uri = this._editor.getModel().uri;
                final pos = new Position(range.startLineNumber, range.startColumn);
                final selection = model.nearestReference(uri, pos);
                if (selection != null) {
                    widget.setSelection(selection);
                    if (this._widget != null && this._editor.getOption(EditorOption.peekWidgetDefaultFocus) == 'editor') {
                        widget.focusOnPreviewEditor();
                    }
                }
            }

        }, error -> {
            Errors.onUnexpectedError(error);
        });
    }

    public function changeFocusBetweenPreviewAndReferences():Void {
        if (this._widget == null) {
            // can be called while still resolving...
            return;
        }
        if (this._widget.isPreviewEditorFocused()) {
            this._widget.focusOnReferenceTree();
        }
        else {
            this._widget.focusOnPreviewEditor();
        }
    }

    public function goToNextOrPreviousReference(fwd:Bool):Void {
        if (!this._editor.hasModel() || this._model == null || this._widget == null) {
            // can be called while still resolving...
            return;
        }
        final currentPosition = this._widget.position;
        if (currentPosition == null) {
            return;
        }
        final source = this._model.nearestReference(this._editor.getModel().uri, currentPosition);
        if (source == null) {
            return;
        }
        final target = this._model.nextOrPreviousReference(source, fwd);
        final editorFocus = this._editor.hasTextFocus();
        final previewEditorFocus = this._widget.isPreviewEditorFocused();
        this._widget.setSelection(target);
        this._gotoReference({uri: target.uri, range: target.range}, false, () -> {
            if (editorFocus) {
                this._editor.focus();
            }
            else if (this._widget != null && previewEditorFocus) {
                this._widget.focusOnPreviewEditor();
            }
        });
    }

    public function revealReference(reference:OneReference):Void {
        if (!this._editor.hasModel() || this._model == null || this._widget == null) {
            // can be called while still resolving...
            return;
        }
        this._widget.revealReference(reference);
    }

    public function closeWidget(focusEditor:Bool = true):Void {
        final widget = this._widget;
        this._widget = null;
        if (widget != null) widget.dispose();
        if (this._model != null) this._model.dispose();
        this._referenceSearchVisible.reset();
        this._disposables.clear();
        this._model = null;
        if (focusEditor) {
            this._editor.focus();
        }
        this._requestIdPool += 1; // Cancel pending requests
    }

    function _gotoReference(ref:Location, pinned:Bool, ?callback:() -> Void):Void {
        if (this._widget != null) this._widget.hide();

        this._ignoreModelChangeEvent = true;
        final range = Range.collapseToStartStatic(ref.range);

        this._editor.context.codeEditorService.openCodeEditor({
            resource: ref.uri,
            options: {selection: range}
        }, this._editor, false, openedEditor -> {
            this._ignoreModelChangeEvent = false;

            if (openedEditor == null || this._widget == null) {
                // something went wrong...
                this.closeWidget();
                if (callback != null) callback();
                return;
            }

            if (this._editor == openedEditor) {
                //
                this._widget.show(range);
                this._widget.focusOnReferenceTree();
            }
            else {
                // we opened a different editor instance which means a different controller instance.
                // therefore we stop with this controller and continue with the other
                final other = ReferencesController.get(openedEditor);
                final model = this._model.clone();

                this.closeWidget();
                openedEditor.focus();

                if (other != null) {
                    other.toggleWidget(range, Promise.resolve(model), this._peekMode != null ? this._peekMode : false);
                }
            }
            if (callback != null) callback();
        });
    }

    public function openReference(ref:Location, sideBySide:Bool, pinned:Bool):Void {
        // clear stage
        if (!sideBySide) {
            this.closeWidget();
        }

        this._editor.context.codeEditorService.openCodeEditor({
            resource: ref.uri,
            options: {selection: Range.lift(ref.range)}
        }, this._editor, sideBySide);
    }

    /**
     * `getOuterEditor`: the editor of the peek view the focused editor
     * belongs to (the focused editor itself, or the editor whose peek
     * view holds the focused preview editor).
     */
    public static function getOuterEditor(context:Cityscape):Null<ICodeEditor> {
        final editor = context.codeEditorService.getFocusedCodeEditor();
        if (editor == null) {
            return null;
        }
        if (PeekViewEditors.isEmbedded(editor)) {
            for (candidate in context.codeEditorService.listCodeEditors()) {
                final controller = ReferencesController.get(candidate);
                if (controller != null && controller._widget != null && controller._widget.preview != null && controller._widget.preview.getEditor() == editor) {
                    return candidate;
                }
            }
        }
        return editor;
    }

    static function withController(context:Null<Cityscape>, fn:(controller:ReferencesController) -> Void):Void {
        if (context == null) {
            return;
        }
        final outerEditor = getOuterEditor(context);
        if (outerEditor == null) {
            return;
        }
        final controller = ReferencesController.get(outerEditor);
        if (controller != null) {
            fn(controller);
        }
    }

    @:allow(cityscape.contrib.gotoSymbol.view.peek)
    static function registerCommands(r:EditorExtensionsRegistry):Void {
        final context = r.context;
        final keybindings = context.keybindingsRegistry;
        final inPeek = ContextKeyExpr.or(ctxReferenceSearchVisible, PeekContext.inPeekEditor);

        keybindings.registerCommandAndKeybindingRule({
            id: 'togglePeekWidgetFocus',
            weight: KeybindingWeight.EditorContrib,
            primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyCode.F2),
            when: inPeek,
            handler: (accessor, args) -> withController(accessor, controller -> controller.changeFocusBetweenPreviewAndReferences())
        });

        keybindings.registerCommandAndKeybindingRule({
            id: 'goToNextReference',
            weight: KeybindingWeight.EditorContrib - 10,
            primary: KeyCode.F4,
            secondary: [KeyCode.F12],
            when: inPeek,
            handler: (accessor, args) -> withController(accessor, controller -> controller.goToNextOrPreviousReference(true))
        });

        keybindings.registerCommandAndKeybindingRule({
            id: 'goToPreviousReference',
            weight: KeybindingWeight.EditorContrib - 10,
            primary: KeyMod.Shift | KeyCode.F4,
            secondary: [KeyMod.Shift | KeyCode.F12],
            when: inPeek,
            handler: (accessor, args) -> withController(accessor, controller -> controller.goToNextOrPreviousReference(false))
        });

        // commands that aren't needed anymore because there is now ContextKeyExpr.OR
        context.commandsRegistry.registerCommandAlias('goToNextReferenceFromEmbeddedEditor', 'goToNextReference');
        context.commandsRegistry.registerCommandAlias('goToPreviousReferenceFromEmbeddedEditor', 'goToPreviousReference');

        // close
        context.commandsRegistry.registerCommandAlias('closeReferenceSearchEditor', 'closeReferenceSearch');
        context.commandsRegistry.registerCommandHandler('closeReferenceSearch', (accessor, args) -> withController(accessor, controller -> controller.closeWidget()));
        keybindings.registerKeybindingRule({
            id: 'closeReferenceSearch',
            weight: KeybindingWeight.EditorContrib - 101,
            primary: KeyCode.Escape,
            secondary: [KeyMod.Shift | KeyCode.Escape],
            when: ContextKeyExpr.and(PeekContext.inPeekEditor, ContextKeyExpr.not('config.editor.stablePeek'))
        });
        keybindings.registerKeybindingRule({
            id: 'closeReferenceSearch',
            weight: KeybindingWeight.WorkbenchContrib + 50,
            primary: KeyCode.Escape,
            secondary: [KeyMod.Shift | KeyCode.Escape],
            when: ContextKeyExpr.and(
                ctxReferenceSearchVisible,
                ContextKeyExpr.not('config.editor.stablePeek'),
                ContextKeyExpr.or(
                    EditorContextKeys.editorTextFocus,
                    ContextKeyExpr.not('inputFocus')
                )
            )
        });

        // `revealReference`, `openReferenceToSide` and `openReference` act
        // on the focused reference of the tree: the tree of the peek view
        // handles Enter and Ctrl+Enter itself (see `ReferenceWidgetView`)
        context.commandsRegistry.registerCommandHandler('revealReference', (accessor, args) -> withController(accessor, controller -> {
            final widget = controller._widget;
            if (widget != null && widget.focusedReference != null) {
                controller.revealReference(widget.focusedReference);
            }
        }));
        context.commandsRegistry.registerCommandHandler('openReferenceToSide', (accessor, args) -> withController(accessor, controller -> {
            final widget = controller._widget;
            if (widget != null && widget.focusedReference != null) {
                controller.openReference({uri: widget.focusedReference.uri, range: widget.focusedReference.range}, true, true);
            }
        }));
        context.commandsRegistry.registerCommandHandler('openReference', (accessor, args) -> withController(accessor, controller -> {
            final widget = controller._widget;
            if (widget != null && widget.focusedReference != null) {
                controller.openReference({uri: widget.focusedReference.uri, range: widget.focusedReference.range}, false, true);
            }
        }));
    }

}

/**
 * The registration of the references controller (standaloneReferenceSearch.ts
 * and the module level code of referencesController.ts).
 */
class ReferencesControllerRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        if (r.context.decorationStyles.get('reference-decoration') == null) {
            // referencesWidget.css: the references in the preview editor
            r.context.registerDecorationStyle('reference-decoration', {
                background: {id: PeekViewColors.peekViewEditorMatchHighlight},
                border: {color: {id: PeekViewColors.peekViewEditorMatchHighlightBorder}, width: 2}
            });
        }
        ReferencesController.registerCommands(r);
        r.registerEditorContribution(ReferencesController.ID, editor -> new ReferencesController(editor), EditorContributionInstantiation.Lazy);
    }

}
