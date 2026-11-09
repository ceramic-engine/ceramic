// Ported from vscode src/vs/editor/contrib/gotoSymbol/browser/goToCommands.ts,
// link/clickLinkGesture.ts and link/goToDefinitionAtPosition.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoSymbol.view;

import cityscape.Cityscape;
import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.LocationLink;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.contrib.gotoSymbol.view.ReferencesModel;
import cityscape.contrib.gotoSymbol.view.SymbolNavigation;
import cityscape.contrib.gotoSymbol.view.peek.ReferencesController;
import cityscape.contrib.peekView.view.PeekView;
import cityscape.base.common.JsValues;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.base.common.Promise;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;

typedef SymbolNavigationActionConfig = {
    final openToSide:Bool;
    final openInPeek:Bool;
    final muteMessage:Bool;
}

/**
 * Module functions shared by the symbol navigation.
 */
class SymbolNavigation {

    /**
     * The model of a resource: a model of the model service, or the model of
     * an editor of the context.
     */
    public static function findModel(context:Cityscape, resource:Uri):Null<ITextModel> {
        final model = context.modelService.getModel(resource);
        if (model != null) {
            return model;
        }
        final key = resource.toString();
        for (editor in context.codeEditorService.listCodeEditors()) {
            final m = editor.getModel();
            if (m != null && m.uri.toString() == key) {
                return m;
            }
        }
        return null;
    }

}

/**
 * Where a symbol navigation starts (Monaco's `SymbolNavigationAnchor`).
 */
class SymbolNavigationAnchor {

    public static function is(thing:Any):Bool {
        if (thing == null || !JsValues.isObject(thing)) {
            return false;
        }
        if (Std.isOfType(thing, SymbolNavigationAnchor)) {
            return true;
        }
        return Position.isIPosition(JsValues.field(thing, 'position')) && JsValues.field(thing, 'model') != null;
    }

    public final model:ITextModel;
    public final position:Position;

    public function new(model:ITextModel, position:Position) {
        this.model = model;
        this.position = position;
    }

}

/**
 * What Monaco keeps in the statics of `SymbolNavigationAction` (the symbol
 * navigation commands by id, the alternative commands running), one per
 * context here, with the symbol navigation service.
 */
class SymbolNavigationCommands {

    public final all:Map<String, SymbolNavigationAction> = new Map();
    public final activeAlternativeCommands:Map<String, Bool> = new Map();
    public final symbolNavigationService:SymbolNavigationService;

    public function new(r:EditorExtensionsRegistry) {
        this.symbolNavigationService = new SymbolNavigationService(r);
    }

}

/**
 * The commands that go to (or peek) the locations of the symbol at the
 * cursor (Monaco's `SymbolNavigationAction`): with one location the editor
 * goes to it; with several, the `gotoLocation` option decides between the
 * peek view (`'peek'`), the first one with the peek view (`'gotoAndPeek'`)
 * or the first one with F12 for the next ones (`'goto'`).
 *
 * The "no definition found" messages go to `onNoResult` of the context
 * (Monaco shows them next to the cursor). The locations open through
 * `context.codeEditorService.openCodeEditor`: in the same editor when it is
 * in its model, else by the handlers a host registers (also for the side
 * by side commands, given `sideBySide`).
 */
abstract class SymbolNavigationAction extends EditorAction {

    public final configuration:SymbolNavigationActionConfig;
    final r:EditorExtensionsRegistry;
    final commands:Null<SymbolNavigationCommands>;

    public function new(r:EditorExtensionsRegistry, commands:Null<SymbolNavigationCommands>, configuration:SymbolNavigationActionConfig, opts:IActionOptions) {
        super(opts);
        this.r = r;
        this.commands = commands;
        this.configuration = configuration;
        if (commands != null && opts.id.length > 0) {
            commands.all.set(opts.id, this);
        }
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        runEditorCommandWith(editor, args, null, null);
    }

    override public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        runEditorCommandWith(editor, args, null, null);
    }

    /**
     * Monaco's `runEditorCommand(accessor, editor, arg, range)`: `arg` may be
     * a `SymbolNavigationAnchor`; `callback` is called once the navigation is
     * done (Monaco's promise).
     */
    public function runEditorCommandWith(editor:ICodeEditor, arg:Any, range:Null<Range>, ?callback:() -> Void):Void {
        if (!editor.hasModel()) {
            if (callback != null) callback();
            return;
        }
        final context = editor.context;
        final languageFeaturesService = context.languageFeaturesService;

        final model = editor.getModel();
        final position = editor.getPosition();
        final anchor:SymbolNavigationAnchor = SymbolNavigationAnchor.is(arg) && Std.isOfType(arg, SymbolNavigationAnchor) ? cast arg : new SymbolNavigationAnchor(model, position);

        // EditorStateCancellationTokenSource (Value | Position)
        final cts = new CancellationTokenSource();
        final versionId = model.getVersionId();
        final listener = editor.onDidChangeCursorPosition(_ -> {
            if (!editor.getPosition().equals(position)) {
                cts.cancel();
            }
        });
        final contentListener = editor.onDidChangeModelContent(_ -> cts.cancel());
        function finish():Void {
            listener.dispose();
            contentListener.dispose();
            cts.dispose();
        }

        this._getLocationModel(context, anchor.model, anchor.position, cts.token).done(references -> {
            finish();
            if (references == null || cts.token.isCancellationRequested || model.getVersionId() != versionId) {
                if (callback != null) callback();
                return;
            }

            var altAction:Null<SymbolNavigationAction> = null;
            if (references.referenceAt(model.uri, position) != null && commands != null) {
                final altActionId = this._getAlternativeCommand(editor);
                if (!commands.activeAlternativeCommands.exists(altActionId) && commands.all.exists(altActionId)) {
                    altAction = commands.all.get(altActionId);
                }
            }

            final referenceCount = references.references.length;

            if (referenceCount == 0) {
                // no result -> show message
                if (!this.configuration.muteMessage) {
                    final info = model.getWordAtPosition(position);
                    final f = context.onNoResult;
                    if (f != null) {
                        f(editor, this._getNoResultFoundMessage(info), position);
                    }
                }
                references.dispose();
                if (callback != null) callback();
            }
            else if (referenceCount == 1 && altAction != null) {
                // already at the only result, run alternative
                references.dispose();
                final id = this.id;
                commands.activeAlternativeCommands.set(id, true);
                altAction.runEditorCommandWith(editor, arg, range, () -> {
                    commands.activeAlternativeCommands.remove(id);
                    if (callback != null) callback();
                });
            }
            else {
                // normal results handling
                this._onResult(editor, references, range, callback);
            }

        }, err -> {
            finish();
            // report an error
            Errors.onUnexpectedError(err);
            if (callback != null) callback();
        });
    }

    abstract function _getLocationModel(context:Cityscape, model:ITextModel, position:Position, token:CancellationToken):Promise<ReferencesModel>;

    abstract function _getNoResultFoundMessage(info:Null<IWordAtPosition>):String;

    abstract function _getAlternativeCommand(editor:ICodeEditor):String;

    abstract function _getGoToPreference(editor:ICodeEditor):GoToLocationValues;

    function _onResult(editor:ICodeEditor, model:ReferencesModel, range:Null<Range>, callback:Null<() -> Void>):Void {

        final gotoLocation = this._getGoToPreference(editor);
        if (!editor.isSimpleWidget && !PeekViewEditors.isEmbedded(editor) && (this.configuration.openInPeek || (gotoLocation == 'peek' && model.references.length > 1))) {
            this._openInPeek(editor, model, range);
            if (callback != null) callback();
        }
        else {
            final next = model.firstReference();
            final peek = model.references.length > 1 && gotoLocation == 'gotoAndPeek';
            _openReference(editor, next, this.configuration.openToSide, !peek, targetEditor -> {
                if (peek && targetEditor != null) {
                    this._openInPeek(targetEditor, model, range);
                }
                else {
                    model.dispose();
                }

                // keep remaining locations around when using
                // 'goto'-mode
                if (gotoLocation == 'goto' && commands != null) {
                    commands.symbolNavigationService.put(next);
                }
                if (callback != null) callback();
            });
        }
    }

    public static function _openReference(editor:ICodeEditor, reference:OneReference, sideBySide:Bool, highlight:Bool, callback:(target:Null<ICodeEditor>) -> Void):Void {
        // range is the target-selection-range when we have one
        // and the fallback is the 'full' range
        var range:Null<IRange> = reference.link.targetSelectionRange;
        if (range == null) {
            range = reference.link.range;
        }
        if (range == null) {
            callback(null);
            return;
        }
        final r:IRange = range;

        editor.context.codeEditorService.openCodeEditor({
            resource: reference.uri,
            options: {
                selection: Range.collapseToStartStatic(r)
            }
        }, editor, sideBySide, targetEditor -> {
            if (targetEditor == null) {
                callback(null);
                return;
            }
            if (highlight) {
                final modelNow = targetEditor.getModel();
                final decorations = targetEditor.createDecorationsCollection([{range: r, options: {description: 'symbol-navigate-action-highlight', className: 'symbolHighlight'}}]);
                Async.setTimeout(() -> {
                    if (targetEditor.getModel() == modelNow) {
                        decorations.clear();
                    }
                }, 350);
            }
            callback(targetEditor);
        });
    }

    function _openInPeek(target:ICodeEditor, model:ReferencesModel, range:Null<Range>):Void {
        final controller = ReferencesController.get(target);
        if (controller != null && target.hasModel()) {
            controller.toggleWidget(range != null ? range : target.getSelection(), Promise.resolve(model), this.configuration.openInPeek);
        }
        else {
            model.dispose();
        }
    }

}

//#region --- DEFINITION

/**
 * The definitions of the symbol (Monaco's `DefinitionAction`), and
 * `editor.action.revealDefinition` (F12) when created with
 * `DefinitionAction.goTo`.
 */
class DefinitionAction extends SymbolNavigationAction {

    /** `GoToDefinitionAction.id` */
    public static inline final ID = 'editor.action.revealDefinition';

    /**
     * `GoToDefinitionAction`: `editor.action.revealDefinition`.
     */
    public static function goTo(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):DefinitionAction {
        final kbOpts:Array<ICommandKeybindingsOptions> = [{
            kbExpr: EditorContextKeys.editorTextFocus,
            primary: KeyCode.F12,
            weight: KeybindingWeight.EditorContrib
        }];
        #if js
        // IsWebContext
        kbOpts.push({
            kbExpr: EditorContextKeys.editorTextFocus,
            primary: KeyMod.CtrlCmd | KeyCode.F12,
            weight: KeybindingWeight.EditorContrib
        });
        #end
        return new DefinitionAction(r, commands, {openToSide: false, openInPeek: false, muteMessage: false}, {
            id: ID,
            label: r.localize('actions.goToDecl.label', "Go to Definition"),
            alias: 'Go to Definition',
            precondition: EditorContextKeys.hasDefinitionProvider,
            kbOpts: kbOpts,
            contextMenuOpts: {group: 'navigation', order: 1.1}
        });
    }

    /**
     * `OpenDefinitionToSideAction`: `editor.action.revealDefinitionAside`.
     */
    public static function toSide(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):DefinitionAction {
        final kbOpts:Array<ICommandKeybindingsOptions> = [{
            kbExpr: EditorContextKeys.editorTextFocus,
            primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyCode.F12),
            weight: KeybindingWeight.EditorContrib
        }];
        #if js
        kbOpts.push({
            kbExpr: EditorContextKeys.editorTextFocus,
            primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.F12),
            weight: KeybindingWeight.EditorContrib
        });
        #end
        return new DefinitionAction(r, commands, {openToSide: true, openInPeek: false, muteMessage: false}, {
            id: 'editor.action.revealDefinitionAside',
            label: r.localize('actions.goToDeclToSide.label', "Open Definition to the Side"),
            alias: 'Open Definition to the Side',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDefinitionProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: kbOpts
        });
    }

    /**
     * `PeekDefinitionAction`: `editor.action.peekDefinition` (Alt+F12).
     */
    public static function peek(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):DefinitionAction {
        return new DefinitionAction(r, commands, {openToSide: false, openInPeek: true, muteMessage: false}, {
            id: 'editor.action.peekDefinition',
            label: r.localize('actions.previewDecl.label', "Peek Definition"),
            alias: 'Peek Definition',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDefinitionProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Alt | KeyCode.F12,
                linux: {primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.F10},
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {menuId: 'EditorContextPeek', group: 'peek', order: 2}
        });
    }

    /**
     * A definition action without id nor keybinding (`id: ''`, what
     * goToDefinitionAtPosition.ts runs on Cmd+click), or Monaco's
     * `DefinitionAction` subclasses with their options.
     */
    public function new(r:EditorExtensionsRegistry, ?commands:SymbolNavigationCommands, ?configuration:SymbolNavigationActionConfig, ?opts:IActionOptions) {
        super(r, commands, configuration != null ? configuration : {openToSide: false, openInPeek: false, muteMessage: false}, opts != null ? opts : {
            id: '',
            label: '',
            alias: '',
            precondition: null
        });
    }

    /**
     * Runs the action on an editor: `callback` is called once the navigation
     * is done (with the editor showing the definition when it went to one).
     */
    public function runOn(editor:ICodeEditor, ?callback:(target:Null<ICodeEditor>) -> Void):Void {
        runEditorCommandWith(editor, null, null, () -> {
            if (callback != null) callback(editor.context.codeEditorService.getActiveCodeEditor());
        });
    }

    function _getLocationModel(context:Cityscape, model:ITextModel, position:Position, token:CancellationToken):Promise<ReferencesModel> {
        return GoToSymbol.getDefinitionsAtPosition(context.languageFeaturesService.definitionProvider, model, position, false, token)
            .then(links -> new ReferencesModel(links != null ? links : [], r.localize('def.title', 'Definitions')));
    }

    function _getNoResultFoundMessage(info:Null<IWordAtPosition>):String {
        return info != null && info.word.length > 0
            ? r.localize('noResultWord', "No definition found for '{0}'", [info.word])
            : r.localize('generic.noResults', "No definition found");
    }

    function _getAlternativeCommand(editor:ICodeEditor):String {
        return editor.getOption(EditorOption.gotoLocation).alternativeDefinitionCommand;
    }

    function _getGoToPreference(editor:ICodeEditor):GoToLocationValues {
        return editor.getOption(EditorOption.gotoLocation).multipleDefinitions;
    }

}

//#endregion

//#region --- DECLARATION

class DeclarationAction extends SymbolNavigationAction {

    /**
     * `GoToDeclarationAction`: `editor.action.revealDeclaration`.
     */
    public static function goTo(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):DeclarationAction {
        return new DeclarationAction(r, commands, {openToSide: false, openInPeek: false, muteMessage: false}, {
            id: 'editor.action.revealDeclaration',
            label: r.localize('actions.goToDeclaration.label', "Go to Declaration"),
            alias: 'Go to Declaration',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDeclarationProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            contextMenuOpts: {group: 'navigation', order: 1.3}
        });
    }

    /**
     * `PeekDeclarationAction`: `editor.action.peekDeclaration`.
     */
    public static function peek(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):DeclarationAction {
        return new DeclarationAction(r, commands, {openToSide: false, openInPeek: true, muteMessage: false}, {
            id: 'editor.action.peekDeclaration',
            label: r.localize('actions.peekDecl.label', "Peek Declaration"),
            alias: 'Peek Declaration',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDeclarationProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            contextMenuOpts: {menuId: 'EditorContextPeek', group: 'peek', order: 3}
        });
    }

    public function new(r:EditorExtensionsRegistry, commands:Null<SymbolNavigationCommands>, configuration:SymbolNavigationActionConfig, opts:IActionOptions) {
        super(r, commands, configuration, opts);
    }

    function _getLocationModel(context:Cityscape, model:ITextModel, position:Position, token:CancellationToken):Promise<ReferencesModel> {
        return GoToSymbol.getDeclarationsAtPosition(context.languageFeaturesService.declarationProvider, model, position, false, token)
            .then(links -> new ReferencesModel(links != null ? links : [], r.localize('decl.title', 'Declarations')));
    }

    function _getNoResultFoundMessage(info:Null<IWordAtPosition>):String {
        return info != null && info.word.length > 0
            ? r.localize('decl.noResultWord', "No declaration found for '{0}'", [info.word])
            : r.localize('decl.generic.noResults', "No declaration found");
    }

    function _getAlternativeCommand(editor:ICodeEditor):String {
        return editor.getOption(EditorOption.gotoLocation).alternativeDeclarationCommand;
    }

    function _getGoToPreference(editor:ICodeEditor):GoToLocationValues {
        return editor.getOption(EditorOption.gotoLocation).multipleDeclarations;
    }

}

//#endregion

//#region --- TYPE DEFINITION

class TypeDefinitionAction extends SymbolNavigationAction {

    /**
     * `GoToTypeDefinitionAction`: `editor.action.goToTypeDefinition`.
     */
    public static function goTo(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):TypeDefinitionAction {
        return new TypeDefinitionAction(r, commands, {openToSide: false, openInPeek: false, muteMessage: false}, {
            id: 'editor.action.goToTypeDefinition',
            label: r.localize('actions.goToTypeDefinition.label', "Go to Type Definition"),
            alias: 'Go to Type Definition',
            precondition: EditorContextKeys.hasTypeDefinitionProvider,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 0,
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {group: 'navigation', order: 1.4}
        });
    }

    /**
     * `PeekTypeDefinitionAction`: `editor.action.peekTypeDefinition`.
     */
    public static function peek(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):TypeDefinitionAction {
        return new TypeDefinitionAction(r, commands, {openToSide: false, openInPeek: true, muteMessage: false}, {
            id: 'editor.action.peekTypeDefinition',
            label: r.localize('actions.peekTypeDefinition.label', "Peek Type Definition"),
            alias: 'Peek Type Definition',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasTypeDefinitionProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            contextMenuOpts: {menuId: 'EditorContextPeek', group: 'peek', order: 4}
        });
    }

    public function new(r:EditorExtensionsRegistry, commands:Null<SymbolNavigationCommands>, configuration:SymbolNavigationActionConfig, opts:IActionOptions) {
        super(r, commands, configuration, opts);
    }

    function _getLocationModel(context:Cityscape, model:ITextModel, position:Position, token:CancellationToken):Promise<ReferencesModel> {
        return GoToSymbol.getTypeDefinitionsAtPosition(context.languageFeaturesService.typeDefinitionProvider, model, position, false, token)
            .then(links -> new ReferencesModel(links != null ? links : [], r.localize('typedef.title', 'Type Definitions')));
    }

    function _getNoResultFoundMessage(info:Null<IWordAtPosition>):String {
        return info != null && info.word.length > 0
            ? r.localize('goToTypeDefinition.noResultWord', "No type definition found for '{0}'", [info.word])
            : r.localize('goToTypeDefinition.generic.noResults', "No type definition found");
    }

    function _getAlternativeCommand(editor:ICodeEditor):String {
        return editor.getOption(EditorOption.gotoLocation).alternativeTypeDefinitionCommand;
    }

    function _getGoToPreference(editor:ICodeEditor):GoToLocationValues {
        return editor.getOption(EditorOption.gotoLocation).multipleTypeDefinitions;
    }

}

//#endregion

//#region --- IMPLEMENTATION

class ImplementationAction extends SymbolNavigationAction {

    /**
     * `GoToImplementationAction`: `editor.action.goToImplementation` (Cmd+F12).
     */
    public static function goTo(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):ImplementationAction {
        return new ImplementationAction(r, commands, {openToSide: false, openInPeek: false, muteMessage: false}, {
            id: 'editor.action.goToImplementation',
            label: r.localize('actions.goToImplementation.label', "Go to Implementations"),
            alias: 'Go to Implementations',
            precondition: EditorContextKeys.hasImplementationProvider,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.F12,
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {group: 'navigation', order: 1.45}
        });
    }

    /**
     * `PeekImplementationAction`: `editor.action.peekImplementation`
     * (Cmd+Shift+F12).
     */
    public static function peek(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):ImplementationAction {
        return new ImplementationAction(r, commands, {openToSide: false, openInPeek: true, muteMessage: false}, {
            id: 'editor.action.peekImplementation',
            label: r.localize('actions.peekImplementation.label', "Peek Implementations"),
            alias: 'Peek Implementations',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasImplementationProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.F12,
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {menuId: 'EditorContextPeek', group: 'peek', order: 5}
        });
    }

    public function new(r:EditorExtensionsRegistry, commands:Null<SymbolNavigationCommands>, configuration:SymbolNavigationActionConfig, opts:IActionOptions) {
        super(r, commands, configuration, opts);
    }

    function _getLocationModel(context:Cityscape, model:ITextModel, position:Position, token:CancellationToken):Promise<ReferencesModel> {
        return GoToSymbol.getImplementationsAtPosition(context.languageFeaturesService.implementationProvider, model, position, false, token)
            .then(links -> new ReferencesModel(links != null ? links : [], r.localize('impl.title', 'Implementations')));
    }

    function _getNoResultFoundMessage(info:Null<IWordAtPosition>):String {
        return info != null && info.word.length > 0
            ? r.localize('goToImplementation.noResultWord', "No implementation found for '{0}'", [info.word])
            : r.localize('goToImplementation.generic.noResults', "No implementation found");
    }

    function _getAlternativeCommand(editor:ICodeEditor):String {
        return editor.getOption(EditorOption.gotoLocation).alternativeImplementationCommand;
    }

    function _getGoToPreference(editor:ICodeEditor):GoToLocationValues {
        return editor.getOption(EditorOption.gotoLocation).multipleImplementations;
    }

}

//#endregion

//#region --- REFERENCES

class ReferencesAction extends SymbolNavigationAction {

    /**
     * `GoToReferencesAction`: `editor.action.goToReferences` (Shift+F12).
     */
    public static function goTo(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):ReferencesAction {
        return new ReferencesAction(r, commands, true, {openToSide: false, openInPeek: false, muteMessage: false}, {
            id: 'editor.action.goToReferences',
            label: r.localize('goToReferences.label', "Go to References"),
            alias: 'Go to References',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasReferenceProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Shift | KeyCode.F12,
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {group: 'navigation', order: 1.45}
        });
    }

    /**
     * `PeekReferencesAction`: `editor.action.referenceSearch.trigger`.
     */
    public static function peek(r:EditorExtensionsRegistry, commands:SymbolNavigationCommands):ReferencesAction {
        return new ReferencesAction(r, commands, false, {openToSide: false, openInPeek: true, muteMessage: false}, {
            id: 'editor.action.referenceSearch.trigger',
            label: r.localize('references.action.label', "Peek References"),
            alias: 'Peek References',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasReferenceProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            contextMenuOpts: {menuId: 'EditorContextPeek', group: 'peek', order: 6}
        });
    }

    /**
     * `getReferencesAtPosition`'s `compact` (true for "Go to References").
     */
    final compact:Bool;

    public function new(r:EditorExtensionsRegistry, commands:Null<SymbolNavigationCommands>, compact:Bool, configuration:SymbolNavigationActionConfig, opts:IActionOptions) {
        super(r, commands, configuration, opts);
        this.compact = compact;
    }

    function _getLocationModel(context:Cityscape, model:ITextModel, position:Position, token:CancellationToken):Promise<ReferencesModel> {
        return GoToSymbol.getReferencesAtPosition(context.languageFeaturesService.referenceProvider, model, position, compact, false, token)
            .then(links -> new ReferencesModel(links != null ? links : [], r.localize('ref.title', 'References')));
    }

    function _getNoResultFoundMessage(info:Null<IWordAtPosition>):String {
        return info != null
            ? r.localize('references.no', "No references found for '{0}'", [info.word])
            : r.localize('references.noGeneric', "No references found");
    }

    function _getAlternativeCommand(editor:ICodeEditor):String {
        return editor.getOption(EditorOption.gotoLocation).alternativeReferenceCommand;
    }

    function _getGoToPreference(editor:ICodeEditor):GoToLocationValues {
        return editor.getOption(EditorOption.gotoLocation).multipleReferences;
    }

}

//#endregion

//#region --- GENERIC goto symbols command

/**
 * `editor.action.goToLocation` over given locations (Monaco's
 * `GenericGoToLocationAction`, behind the `editor.action.goToLocations`
 * and `editor.action.peekLocations` commands).
 */
class GenericGoToLocationAction extends SymbolNavigationAction {

    final _references:Array<LocationLink>;
    final _gotoMultipleBehaviour:Null<GoToLocationValues>;
    final _noResultsMessage:Null<String>;

    public function new(r:EditorExtensionsRegistry, commands:Null<SymbolNavigationCommands>, config:SymbolNavigationActionConfig, references:Array<LocationLink>, gotoMultipleBehaviour:Null<GoToLocationValues>, ?noResultsMessage:String) {
        super(r, commands, config, {
            id: 'editor.action.goToLocation',
            label: r.localize('label.generic', "Go to Any Symbol"),
            alias: 'Go to Any Symbol',
            precondition: ContextKeyExpr.and(PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated())
        });
        this._references = references;
        this._gotoMultipleBehaviour = gotoMultipleBehaviour;
        this._noResultsMessage = noResultsMessage;
    }

    function _getLocationModel(context:Cityscape, model:ITextModel, position:Position, token:CancellationToken):Promise<ReferencesModel> {
        return Promise.resolve(new ReferencesModel(this._references, r.localize('generic.title', 'Locations')));
    }

    function _getNoResultFoundMessage(info:Null<IWordAtPosition>):String {
        if (_noResultsMessage != null && _noResultsMessage.length > 0) {
            return _noResultsMessage;
        }
        return info != null ? r.localize('generic.noResult', "No results for '{0}'", [info.word]) : '';
    }

    function _getGoToPreference(editor:ICodeEditor):GoToLocationValues {
        return this._gotoMultipleBehaviour != null ? this._gotoMultipleBehaviour : editor.getOption(EditorOption.gotoLocation).multipleReferences;
    }

    function _getAlternativeCommand(editor:ICodeEditor):String {
        return '';
    }

}

//#endregion

/**
 * `'ctrlKey'`, `'shiftKey'`, `'altKey'` or `'metaKey'`.
 */
typedef TriggerModifier = String;

class ClickLinkOptions {

    public final triggerKey:KeyCode;
    public final triggerModifier:TriggerModifier;
    public final triggerSideBySideKey:KeyCode;
    public final triggerSideBySideModifier:TriggerModifier;

    public function new(triggerKey:KeyCode, triggerModifier:TriggerModifier, triggerSideBySideKey:KeyCode, triggerSideBySideModifier:TriggerModifier) {
        this.triggerKey = triggerKey;
        this.triggerModifier = triggerModifier;
        this.triggerSideBySideKey = triggerSideBySideKey;
        this.triggerSideBySideModifier = triggerSideBySideModifier;
    }

    public function equals(other:ClickLinkOptions):Bool {
        return (
            this.triggerKey == other.triggerKey
            && this.triggerModifier == other.triggerModifier
            && this.triggerSideBySideKey == other.triggerSideBySideKey
            && this.triggerSideBySideModifier == other.triggerSideBySideModifier
        );
    }

    public static function create(multiCursorModifier:String):ClickLinkOptions {
        if (multiCursorModifier == 'altKey') {
            if (Platform.isMacintosh) {
                return new ClickLinkOptions(KeyCode.Meta, 'metaKey', KeyCode.Alt, 'altKey');
            }
            return new ClickLinkOptions(KeyCode.Ctrl, 'ctrlKey', KeyCode.Alt, 'altKey');
        }
        if (Platform.isMacintosh) {
            return new ClickLinkOptions(KeyCode.Alt, 'altKey', KeyCode.Meta, 'metaKey');
        }
        return new ClickLinkOptions(KeyCode.Alt, 'altKey', KeyCode.Ctrl, 'ctrlKey');
    }

    public static function hasModifier(ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool, modifier:TriggerModifier):Bool {
        return switch modifier {
            case 'ctrlKey': ctrlKey;
            case 'shiftKey': shiftKey;
            case 'altKey': altKey;
            case 'metaKey': metaKey;
            case _: false;
        };
    }
}

/**
 * An event that encapsulates the various trigger modifiers logic needed for go to definition.
 */
class ClickLinkMouseEvent {

    public final target:IMouseTarget;
    public final hasTriggerModifier:Bool;
    public final hasSideBySideModifier:Bool;
    public final isNoneOrSingleMouseDown:Bool;
    public final isLeftClick:Bool;
    public final isMiddleClick:Bool;
    public final isRightClick:Bool;

    public function new(source:IEditorMouseEvent, opts:ClickLinkOptions) {
        final e = source.event;
        this.target = source.target;
        this.isLeftClick = e.leftButton;
        this.isMiddleClick = e.middleButton;
        this.isRightClick = e.rightButton;
        this.hasTriggerModifier = ClickLinkOptions.hasModifier(e.ctrlKey, e.shiftKey, e.altKey, e.metaKey, opts.triggerModifier);
        this.hasSideBySideModifier = ClickLinkOptions.hasModifier(e.ctrlKey, e.shiftKey, e.altKey, e.metaKey, opts.triggerSideBySideModifier);
        this.isNoneOrSingleMouseDown = (e.detail <= 1);
    }
}

/**
 * An event that encapsulates the various trigger modifiers logic needed for go to definition.
 */
class ClickLinkKeyboardEvent {

    public final keyCodeIsTriggerKey:Bool;
    public final keyCodeIsSideBySideKey:Bool;
    public final hasTriggerModifier:Bool;

    public function new(source:IKeyboardEvent, opts:ClickLinkOptions) {
        this.keyCodeIsTriggerKey = (source.keyCode == opts.triggerKey);
        this.keyCodeIsSideBySideKey = (source.keyCode == opts.triggerSideBySideKey);
        this.hasTriggerModifier = ClickLinkOptions.hasModifier(source.ctrlKey, source.shiftKey, source.altKey, source.metaKey, opts.triggerModifier);
    }
}

/**
 * The Cmd (Ctrl) click gesture (Monaco's `ClickLinkGesture`). Monaco also
 * resets on a mouse drag (`onMouseDrag`): a drag selects text, which
 * resets through the selection change here.
 */
class ClickLinkGesture extends Disposable {

    final _onMouseMoveOrRelevantKeyDown = new Emitter<{mouseEvent:ClickLinkMouseEvent, keyboardEvent:Null<ClickLinkKeyboardEvent>}>();
    public final onMouseMoveOrRelevantKeyDown:Event<{mouseEvent:ClickLinkMouseEvent, keyboardEvent:Null<ClickLinkKeyboardEvent>}>;

    final _onExecute = new Emitter<ClickLinkMouseEvent>();
    public final onExecute:Event<ClickLinkMouseEvent>;

    final _onCancel = new VoidEmitter();
    public final onCancel:VoidEvent;

    final _editor:ICodeEditor;
    var _opts:ClickLinkOptions;
    var _lastMouseMoveEvent:Null<ClickLinkMouseEvent> = null;
    var _hasTriggerKeyOnMouseDown:Bool = false;
    var _lineNumberOnMouseDown:Int = 0;

    static function extractLineNumberFromMouseEvent(e:ClickLinkMouseEvent):Int {
        return e.target.position != null ? e.target.position.lineNumber : 0;
    }

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this.onMouseMoveOrRelevantKeyDown = _onMouseMoveOrRelevantKeyDown.event;
        this.onExecute = _onExecute.event;
        this.onCancel = _onCancel.event;
        this._register(_onMouseMoveOrRelevantKeyDown);
        this._register(_onExecute);
        this._register(_onCancel);
        this._opts = ClickLinkOptions.create(this._editor.getOption(EditorOption.multiCursorModifier));

        this._register(this._editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.multiCursorModifier)) {
                final newOpts = ClickLinkOptions.create(this._editor.getOption(EditorOption.multiCursorModifier));
                if (this._opts.equals(newOpts)) {
                    return;
                }
                this._opts = newOpts;
                this._lastMouseMoveEvent = null;
                this._hasTriggerKeyOnMouseDown = false;
                this._lineNumberOnMouseDown = 0;
                this._onCancel.fire();
            }
        }));
        this._register(this._editor.onMouseMove(e -> this._onEditorMouseMove(new ClickLinkMouseEvent(e, this._opts))));
        this._register(this._editor.onMouseDown(e -> this._onEditorMouseDown(new ClickLinkMouseEvent(e, this._opts))));
        this._register(this._editor.onMouseUp(e -> this._onEditorMouseUp(new ClickLinkMouseEvent(e, this._opts))));
        this._register(this._editor.onKeyDown(e -> this._onEditorKeyDown(new ClickLinkKeyboardEvent(e, this._opts))));
        this._register(this._editor.onKeyUp(e -> this._onEditorKeyUp(new ClickLinkKeyboardEvent(e, this._opts))));
        this._register(this._editor.onDidChangeCursorSelection(e -> this._onDidChangeCursorSelection(e)));
        this._register(this._editor.onDidChangeModel(_ -> this._resetHandler()));
        this._register(this._editor.onDidChangeModelContent(_ -> this._resetHandler()));
        this._register(this._editor.onDidScrollChange(e -> {
            if (e.scrollTopChanged || e.scrollLeftChanged) {
                this._resetHandler();
            }
        }));
    }

    function _onDidChangeCursorSelection(e:ICursorSelectionChangedEvent):Void {
        if (e.selection != null && e.selection.startColumn != e.selection.endColumn) {
            this._resetHandler(); // immediately stop this feature if the user starts to select (https://github.com/microsoft/vscode/issues/7827)
        }
    }

    function _onEditorMouseMove(mouseEvent:ClickLinkMouseEvent):Void {
        this._lastMouseMoveEvent = mouseEvent;

        this._onMouseMoveOrRelevantKeyDown.fire({mouseEvent: mouseEvent, keyboardEvent: null});
    }

    function _onEditorMouseDown(mouseEvent:ClickLinkMouseEvent):Void {
        // We need to record if we had the trigger key on mouse down because someone might select something in the editor
        // holding the mouse down and then while mouse is down start to press Ctrl/Cmd to start a copy operation and then
        // release the mouse button without wanting to do the navigation.
        // With this flag we prevent goto definition if the mouse was down before the trigger key was pressed.
        this._hasTriggerKeyOnMouseDown = mouseEvent.hasTriggerModifier;
        this._lineNumberOnMouseDown = extractLineNumberFromMouseEvent(mouseEvent);
    }

    function _onEditorMouseUp(mouseEvent:ClickLinkMouseEvent):Void {
        final currentLineNumber = extractLineNumberFromMouseEvent(mouseEvent);
        if (this._hasTriggerKeyOnMouseDown && this._lineNumberOnMouseDown != 0 && this._lineNumberOnMouseDown == currentLineNumber) {
            this._onExecute.fire(mouseEvent);
        }
    }

    function _onEditorKeyDown(e:ClickLinkKeyboardEvent):Void {
        if (
            this._lastMouseMoveEvent != null
            && (
                e.keyCodeIsTriggerKey // User just pressed Ctrl/Cmd (normal goto definition)
                || (e.keyCodeIsSideBySideKey && e.hasTriggerModifier) // User pressed Ctrl/Cmd+Alt (goto definition to the side)
            )
        ) {
            this._onMouseMoveOrRelevantKeyDown.fire({mouseEvent: this._lastMouseMoveEvent, keyboardEvent: e});
        }
        else if (e.hasTriggerModifier) {
            this._onCancel.fire(); // remove decorations if user holds another key with ctrl/cmd to prevent accident goto declaration
        }
    }

    function _onEditorKeyUp(e:ClickLinkKeyboardEvent):Void {
        if (e.keyCodeIsTriggerKey) {
            this._onCancel.fire();
        }
    }

    function _resetHandler():Void {
        this._lastMouseMoveEvent = null;
        this._hasTriggerKeyOnMouseDown = false;
        this._onCancel.fire();
    }

}

/**
 * Underlines the symbol under the mouse while Cmd (Ctrl) is held when it
 * has a definition, with a preview of the definition in its hover, and goes
 * to it on Cmd+click (Monaco's `GotoDefinitionAtPositionEditorContribution`).
 * With `definitionLinkOpensInPeek`, the definition opens in the peek view.
 */
class GotoDefinitionAtPosition implements IEditorContribution {

    public static inline final ID = 'editor.contrib.gotodefinitionatposition';
    static inline final MAX_SOURCE_PREVIEW_LINES = 8;

    public static function get(editor:ICodeEditor):Null<GotoDefinitionAtPosition> {
        return editor.getContribution(GotoDefinitionAtPosition.ID);
    }

    final editor:ICodeEditor;
    final toUnhook = new DisposableStore();
    final toUnhookForKeyboard = new DisposableStore();
    final linkDecorations:IEditorDecorationsCollection;
    var currentWordAtPosition:Null<IWordAtPosition> = null;
    var previousToken:Null<CancellationTokenSource> = null;
    final r:EditorExtensionsRegistry;

    public function new(editor:ICodeEditor, r:EditorExtensionsRegistry) {
        this.editor = editor;
        this.r = r;
        this.linkDecorations = this.editor.createDecorationsCollection();

        final linkGesture = new ClickLinkGesture(editor);
        this.toUnhook.add(linkGesture);

        this.toUnhook.add(linkGesture.onMouseMoveOrRelevantKeyDown(e -> {
            this.startFindDefinitionFromMouse(e.mouseEvent, e.keyboardEvent);
        }));

        this.toUnhook.add(linkGesture.onExecute(mouseEvent -> {
            if (this.isEnabled(mouseEvent)) {
                this.gotoDefinition(mouseEvent.target.position, mouseEvent.hasSideBySideModifier, () -> {
                    this.removeLinkDecorations();
                });
            }
        }));

        this.toUnhook.add(linkGesture.onCancel(() -> {
            this.removeLinkDecorations();
            this.currentWordAtPosition = null;
        }));
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * The link decoration (tests).
     */
    public function getLinkRanges():Array<Range> {
        return linkDecorations.getRanges();
    }

    public function startFindDefinitionFromCursor(position:Position):Void {
        // For issue: https://github.com/microsoft/vscode/issues/46257
        // equivalent to mouse move with meta/ctrl key

        // First find the definition and add decorations
        // to the editor to be shown with the content hover widget
        this.startFindDefinition(position);

        // Add listeners for editor cursor move and key down events
        // Dismiss the "extended" editor decorations when the user hides
        // the hover widget. There is no event for the widget itself so these
        // serve as a best effort. After removing the link decorations, the hover
        // widget is clean and will only show declarations per next request.
        this.toUnhookForKeyboard.add(this.editor.onDidChangeCursorPosition(_ -> {
            this.currentWordAtPosition = null;
            this.removeLinkDecorations();
            this.toUnhookForKeyboard.clear();
        }));
        this.toUnhookForKeyboard.add(this.editor.onKeyDown(e -> {
            if (e != null) {
                this.currentWordAtPosition = null;
                this.removeLinkDecorations();
                this.toUnhookForKeyboard.clear();
            }
        }));
    }

    function startFindDefinitionFromMouse(mouseEvent:ClickLinkMouseEvent, ?withKey:ClickLinkKeyboardEvent):Void {

        // check if we are active and on a content widget
        if (mouseEvent.target.type == MouseTargetType.CONTENT_WIDGET && this.linkDecorations.length > 0) {
            return;
        }

        if (!this.editor.hasModel() || !this.isEnabled(mouseEvent, withKey)) {
            this.currentWordAtPosition = null;
            this.removeLinkDecorations();
            return;
        }

        final position = mouseEvent.target.position;

        this.startFindDefinition(position);
    }

    function startFindDefinition(position:Position):Void {

        // Dispose listeners for updating decorations when using keyboard to show definition hover
        this.toUnhookForKeyboard.clear();

        // Find word at mouse position
        final model = this.editor.getModel();
        final word = position != null && model != null ? model.getWordAtPosition(position) : null;
        if (word == null) {
            this.currentWordAtPosition = null;
            this.removeLinkDecorations();
            return;
        }

        // Return early if word at position is still the same
        if (this.currentWordAtPosition != null && this.currentWordAtPosition.startColumn == word.startColumn && this.currentWordAtPosition.endColumn == word.endColumn && this.currentWordAtPosition.word == word.word) {
            return;
        }

        this.currentWordAtPosition = word;

        // Find definition and decorate word if found
        // EditorState (Position | Value | Selection | Scroll)
        final versionId = model.getVersionId();
        final selection = this.editor.getSelection();
        final scrollTop = this.editor.getScrollTop();
        final scrollLeft = this.editor.getScrollLeft();

        if (this.previousToken != null) {
            this.previousToken.cancel();
            this.previousToken = null;
        }
        final source = new CancellationTokenSource();
        this.previousToken = source;

        GoToSymbol.getDefinitionsAtPosition(this.editor.context.languageFeaturesService.definitionProvider, model, position, false, source.token).done(results -> {
            if (source.token.isCancellationRequested) {
                return;
            }
            final stateValid = this.editor.getModel() == model && model.getVersionId() == versionId
                && this.editor.getSelection().equalsSelection(selection)
                && this.editor.getScrollTop() == scrollTop && this.editor.getScrollLeft() == scrollLeft;
            if (results == null || results.length == 0 || !stateValid) {
                this.removeLinkDecorations();
                return;
            }

            final linkRange = results[0].originSelectionRange != null
                ? Range.lift(results[0].originSelectionRange)
                : new Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn);

            // Multiple results
            if (results.length > 1) {

                var combinedRange = linkRange;
                for (result in results) {
                    if (result.originSelectionRange != null) {
                        combinedRange = Range.plusRangeStatic(combinedRange, result.originSelectionRange);
                    }
                }

                this.addDecoration(
                    combinedRange,
                    {value: escapeMarkdown(r.localize('multipleResults', "Click to show {0} definitions.", [results.length]))}
                );
            }
            else {
                // Single result
                final result = results[0];

                if (result.uri == null) {
                    return;
                }

                final textEditorModel = SymbolNavigation.findModel(this.editor.context, result.uri);
                if (textEditorModel == null) {
                    // the model is not open: underline without preview
                    this.addDecoration(linkRange, null);
                    return;
                }

                final startLineNumber = result.range.startLineNumber;

                if (startLineNumber < 1 || startLineNumber > textEditorModel.getLineCount()) {
                    // invalid range
                    return;
                }

                final previewValue = this.getPreviewValue(textEditorModel, startLineNumber, result);
                final languageId = textEditorModel.getLanguageId();
                this.addDecoration(
                    linkRange,
                    previewValue != null && previewValue.length > 0 ? {value: '```' + (languageId != null ? languageId : '') + '\n' + previewValue + '\n```\n'} : null
                );
            }
        }, error -> {
            Errors.onUnexpectedError(error);
        });
    }

    /**
     * Monaco's `MarkdownString.appendText` escaping.
     */
    static function escapeMarkdown(text:String):String {
        final buf = new StringBuf();
        for (i in 0...text.length) {
            final c = text.charAt(i);
            if ('\\`*_{}[]()#+-.!<>|~'.indexOf(c) >= 0) {
                buf.add('\\');
            }
            buf.add(c);
        }
        return buf.toString();
    }

    function getPreviewValue(textEditorModel:ITextModel, startLineNumber:Int, result:LocationLink):String {
        var rangeToUse:IRange = result.range;
        final numberOfLinesInRange = rangeToUse.endLineNumber - rangeToUse.startLineNumber;
        if (numberOfLinesInRange >= MAX_SOURCE_PREVIEW_LINES) {
            rangeToUse = this.getPreviewRangeBasedOnIndentation(textEditorModel, startLineNumber);
        }

        return this.stripIndentationFromPreviewRange(textEditorModel, startLineNumber, rangeToUse);
    }

    function stripIndentationFromPreviewRange(textEditorModel:ITextModel, startLineNumber:Int, previewRange:IRange):String {
        final startIndent = textEditorModel.getLineFirstNonWhitespaceColumn(startLineNumber);
        var minIndent = startIndent;

        for (endLineNumber in startLineNumber + 1...previewRange.endLineNumber) {
            final endIndent = textEditorModel.getLineFirstNonWhitespaceColumn(endLineNumber);
            minIndent = Std.int(Math.min(minIndent, endIndent));
        }

        // replace(new RegExp(`^\\s{${minIndent - 1}}`, 'gm'), '').trim()
        final count = minIndent - 1;
        final lines = textEditorModel.getValueInRange(previewRange).split('\n');
        for (i in 0...lines.length) {
            final line = lines[i];
            var n = 0;
            while (n < count && n < line.length && StringTools.isSpace(line, n)) {
                n++;
            }
            if (n == count) {
                lines[i] = line.substr(count);
            }
        }
        return StringTools.trim(lines.join('\n'));
    }

    function getPreviewRangeBasedOnIndentation(textEditorModel:ITextModel, startLineNumber:Int):Range {
        final startIndent = textEditorModel.getLineFirstNonWhitespaceColumn(startLineNumber);
        final maxLineNumber = Std.int(Math.min(textEditorModel.getLineCount(), startLineNumber + MAX_SOURCE_PREVIEW_LINES));
        var endLineNumber = startLineNumber + 1;

        while (endLineNumber < maxLineNumber) {
            final endIndent = textEditorModel.getLineFirstNonWhitespaceColumn(endLineNumber);

            if (startIndent == endIndent) {
                break;
            }
            endLineNumber++;
        }

        return new Range(startLineNumber, 1, endLineNumber + 1, 1);
    }

    function addDecoration(range:Range, hoverMessage:Null<IMarkdownString>):Void {
        this.linkDecorations.set([{
            range: range,
            options: {
                description: 'goto-definition-link',
                inlineClassName: 'goto-definition-link',
                hoverMessage: hoverMessage
            }
        }]);
    }

    function removeLinkDecorations():Void {
        this.linkDecorations.clear();
    }

    function isEnabled(mouseEvent:ClickLinkMouseEvent, ?withKey:ClickLinkKeyboardEvent):Bool {
        return this.editor.hasModel()
            && mouseEvent.isLeftClick
            && mouseEvent.isNoneOrSingleMouseDown
            && mouseEvent.target.type == MouseTargetType.CONTENT_TEXT
            && (mouseEvent.hasTriggerModifier || (withKey != null ? withKey.keyCodeIsTriggerKey : false))
            && this.editor.context.languageFeaturesService.definitionProvider.has(this.editor.getModel());
    }

    function gotoDefinition(position:Position, openToSide:Bool, done:() -> Void):Void {
        this.editor.setPosition(position);
        final canPeek = !openToSide && this.editor.getOption(EditorOption.definitionLinkOpensInPeek) && !PeekViewEditors.isEmbedded(this.editor);
        final action = new DefinitionAction(r, null, {openToSide: openToSide, openInPeek: canPeek, muteMessage: true});
        action.runOn(this.editor, _ -> done());
    }

    public function dispose():Void {
        if (this.previousToken != null) {
            this.previousToken.cancel();
        }
        this.toUnhook.dispose();
        this.toUnhookForKeyboard.dispose();
    }

}

/**
 * The registration of goToCommands.ts, symbolNavigation.ts,
 * peek/referencesController.ts and goToDefinitionAtPosition.ts (their module
 * level code).
 */
class GoToSymbolRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        if (r.context.decorationStyles.get('goto-definition-link') == null) {
            // goToDefinitionAtPosition.css
            r.context.registerDecorationStyle('goto-definition-link', {
                color: {id: 'editorLink.activeForeground'},
                underline: {color: {id: 'editorLink.activeForeground'}}
            });
        }
        if (r.context.decorationStyles.get('symbolHighlight') == null) {
            r.context.registerDecorationStyle('symbolHighlight', {
                background: {id: 'editor.symbolHighlightBackground'},
                border: {color: {id: 'editor.symbolHighlightBorder'}}
            });
        }

        final commands = new SymbolNavigationCommands(r);
        final context = r.context;

        // goToCommands.ts
        r.registerEditorAction(DefinitionAction.goTo(r, commands));
        context.commandsRegistry.registerCommandAlias('editor.action.goToDeclaration', DefinitionAction.ID);
        r.registerEditorAction(DefinitionAction.toSide(r, commands));
        context.commandsRegistry.registerCommandAlias('editor.action.openDeclarationToTheSide', 'editor.action.revealDefinitionAside');
        r.registerEditorAction(DefinitionAction.peek(r, commands));
        context.commandsRegistry.registerCommandAlias('editor.action.previewDeclaration', 'editor.action.peekDefinition');
        r.registerEditorAction(DeclarationAction.goTo(r, commands));
        r.registerEditorAction(DeclarationAction.peek(r, commands));
        r.registerEditorAction(TypeDefinitionAction.goTo(r, commands));
        r.registerEditorAction(TypeDefinitionAction.peek(r, commands));
        r.registerEditorAction(ImplementationAction.goTo(r, commands));
        r.registerEditorAction(ImplementationAction.peek(r, commands));
        r.registerEditorAction(ReferencesAction.goTo(r, commands));
        r.registerEditorAction(ReferencesAction.peek(r, commands));

        // editor.action.goToLocations (uri, position, locations, multiple?, noResultsMessage?, openInPeek?)
        context.commandsRegistry.registerCommand({
            id: 'editor.action.goToLocations',
            metadata: {description: 'Go to locations from a position in a file'},
            handler: (accessor, args) -> {
                final resource:Null<Uri> = args.length > 0 && Std.isOfType(args[0], Uri) ? cast args[0] : null;
                final position:Null<IPosition> = args.length > 1 && Position.isIPosition(args[1]) ? args[1] : null;
                final references:Null<Array<LocationLink>> = args.length > 2 && Std.isOfType(args[2], Array) ? args[2] : null;
                if (resource == null || position == null || references == null) {
                    return;
                }
                final multiple:Null<String> = args.length > 3 && JsValues.isString(args[3]) ? args[3] : null;
                final noResultsMessage:Null<String> = args.length > 4 && JsValues.isString(args[4]) ? args[4] : null;
                final openInPeek = args.length > 5 && args[5] == true;
                context.codeEditorService.openCodeEditor({resource: resource}, context.codeEditorService.getFocusedCodeEditor(), false, editor -> {
                    if (editor == null) {
                        return;
                    }
                    editor.setPosition(position);
                    editor.revealPositionInCenterIfOutsideViewport(position, ScrollType.Smooth);
                    final command = new GenericGoToLocationAction(r, commands, {
                        muteMessage: noResultsMessage == null || noResultsMessage.length == 0,
                        openInPeek: openInPeek,
                        openToSide: false
                    }, references, multiple, noResultsMessage);
                    command.runEditorCommandWith(editor, null, null);
                });
            }
        });

        // editor.action.peekLocations (uri, position, locations, multiple?)
        context.commandsRegistry.registerCommand({
            id: 'editor.action.peekLocations',
            metadata: {description: 'Peek locations from a position in a file'},
            handler: (accessor, args) -> {
                context.commandService.executeCommand('editor.action.goToLocations', [
                    args.length > 0 ? args[0] : null,
                    args.length > 1 ? args[1] : null,
                    args.length > 2 ? args[2] : null,
                    args.length > 3 ? args[3] : null,
                    null,
                    true
                ]);
            }
        });

        // editor.action.findReferences (uri, position)
        context.commandsRegistry.registerCommand({
            id: 'editor.action.findReferences',
            handler: (accessor, args) -> {
                final resource:Null<Uri> = args.length > 0 && Std.isOfType(args[0], Uri) ? cast args[0] : null;
                final position:Null<IPosition> = args.length > 1 && Position.isIPosition(args[1]) ? args[1] : null;
                if (resource == null || position == null) {
                    return;
                }
                context.codeEditorService.openCodeEditor({resource: resource}, context.codeEditorService.getFocusedCodeEditor(), false, control -> {
                    if (control == null || !control.hasModel()) {
                        return;
                    }
                    final controller = ReferencesController.get(control);
                    if (controller == null) {
                        return;
                    }
                    final references = GoToSymbol.getReferencesAtPosition(context.languageFeaturesService.referenceProvider, control.getModel(), Position.lift(position), false, false, CancellationTokens.None)
                        .then(links -> new ReferencesModel(links != null ? links : [], r.localize('ref.title', 'References')));
                    final range = new Range(position.lineNumber, position.column, position.lineNumber, position.column);
                    controller.toggleWidget(range, references, false);
                });
            }
        });

        // use NEW command
        context.commandsRegistry.registerCommandAlias('editor.action.showReferences', 'editor.action.peekLocations');

        // symbolNavigation.ts
        SymbolNavigationRegistration.register(r, commands.symbolNavigationService);

        // peek/referencesController.ts
        ReferencesControllerRegistration.register(r);

        r.registerEditorContribution(GotoDefinitionAtPosition.ID, editor -> new GotoDefinitionAtPosition(editor, r), EditorContributionInstantiation.BeforeFirstInteraction);
    }

}
