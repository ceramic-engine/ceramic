// Ported from vscode src/vs/editor/contrib/gotoSymbol/browser/symbolNavigation.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoSymbol.view;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.common.core.Range;
import cityscape.contrib.gotoSymbol.view.ReferencesModel;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.standalone.StandaloneServices.CodeEditorService;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/**
 * Keeps the other locations of a "go to" with several results (the
 * `gotoLocation` `'goto'` mode), so that F12 goes to the next one (Monaco's
 * `SymbolNavigationService`, one per context). Monaco shows "Symbol 1 of 3"
 * in the status bar: the message is given to the context's
 * `onStatusMessage` hook here.
 */
class SymbolNavigationService {

    static var _ctxHasSymbols:Null<RawContextKey<Bool>> = null;

    /**
     * `hasSymbols`: whether there are symbol locations that can be
     * navigated via keyboard-only.
     */
    public static var ctxHasSymbols(get, never):RawContextKey<Bool>;
    static function get_ctxHasSymbols():RawContextKey<Bool> {
        if (_ctxHasSymbols == null) {
            _ctxHasSymbols = new RawContextKey<Bool>('hasSymbols', false, "Whether there are symbol locations that can be navigated via keyboard-only.");
        }
        return _ctxHasSymbols;
    }

    final _context:Cityscape;
    final _r:EditorExtensionsRegistry;
    final _ctxHasSymbolsKey:IContextKey<Bool>;
    final _editorService:CodeEditorService;

    var _currentModel:Null<ReferencesModel> = null;
    var _currentIdx:Int = -1;
    var _currentState:Null<IDisposable> = null;
    var _currentMessage:Null<IDisposable> = null;
    var _ignoreEditorChange:Bool = false;

    public function new(r:EditorExtensionsRegistry) {
        this._r = r;
        this._context = r.context;
        this._ctxHasSymbolsKey = ctxHasSymbols.bindTo(r.context.contextKeyService);
        this._editorService = r.context.codeEditorService;
    }

    public function reset():Void {
        this._ctxHasSymbolsKey.reset();
        if (this._currentState != null) this._currentState.dispose();
        if (this._currentMessage != null) this._currentMessage.dispose();
        this._currentState = null;
        this._currentMessage = null;
        this._currentModel = null;
        this._currentIdx = -1;
    }

    /**
     * The index of the current location, -1 when there is none (tests).
     */
    public var currentIndex(get, never):Int;
    function get_currentIndex():Int {
        return _currentIdx;
    }

    public function put(anchor:OneReference):Void {
        final refModel = anchor.parent.parent;

        if (refModel.references.length <= 1) {
            this.reset();
            return;
        }

        this._currentModel = refModel;
        this._currentIdx = refModel.references.indexOf(anchor);
        this._ctxHasSymbolsKey.set(true);
        this._showMessage();

        final editorState = new EditorState(this._editorService);
        final listener = editorState.onDidChange(_ -> {

            if (this._ignoreEditorChange) {
                return;
            }

            final editor = this._editorService.getActiveCodeEditor();
            if (editor == null) {
                return;
            }
            final model = editor.getModel();
            final position = editor.getPosition();
            if (model == null || position == null) {
                return;
            }

            var seenUri = false;
            var seenPosition = false;
            for (reference in refModel.references) {
                if (ReferencesModel.uriIsEqual(reference.uri, model.uri)) {
                    seenUri = true;
                    seenPosition = seenPosition || Range.containsPositionStatic(reference.range, position);
                }
                else if (seenUri) {
                    break;
                }
            }
            if (!seenUri || !seenPosition) {
                this.reset();
            }
        });

        this._currentState = Lifecycle.combinedDisposable([editorState, listener]);
    }

    public function revealNext(source:ICodeEditor, ?callback:() -> Void):Void {
        if (this._currentModel == null) {
            if (callback != null) callback();
            return;
        }

        // get next result and advance
        this._currentIdx += 1;
        this._currentIdx %= this._currentModel.references.length;
        final reference = this._currentModel.references[this._currentIdx];

        // status
        this._showMessage();

        // open editor, ignore events while that happens
        this._ignoreEditorChange = true;
        this._editorService.openCodeEditor({
            resource: reference.uri,
            options: {
                selection: Range.collapseToStartStatic(reference.range)
            }
        }, source, false, _ -> {
            this._ignoreEditorChange = false;
            if (callback != null) callback();
        });
    }

    function _showMessage():Void {

        if (this._currentMessage != null) this._currentMessage.dispose();
        this._currentMessage = null;

        final kb = this._context.keybindingService.lookupKeybinding('editor.gotoNextSymbolFromResult');
        final count = this._currentModel != null ? this._currentModel.references.length : 0;
        final message = kb != null
            ? this._r.localize('location.kb', "Symbol {0} of {1}, {2} for next", [this._currentIdx + 1, count, kb.getLabel()])
            : this._r.localize('location', "Symbol {0} of {1}", [this._currentIdx + 1, count]);

        final status = this._context.onStatusMessage;
        if (status != null) {
            this._currentMessage = status(message);
        }
    }

}

/**
 * Fires when the cursor or the content of an editor of the context changes
 * (symbolNavigation.ts `EditorState`).
 */
private class EditorState implements IDisposable {

    final _listener:Map<ICodeEditor, IDisposable> = new Map();
    final _disposables = new DisposableStore();

    final _onDidChange = new Emitter<{editor:ICodeEditor}>();
    public final onDidChange:Event<{editor:ICodeEditor}>;

    public function new(editorService:CodeEditorService) {
        this.onDidChange = _onDidChange.event;
        this._disposables.add(editorService.onCodeEditorRemove(this._onDidRemoveEditor));
        this._disposables.add(editorService.onCodeEditorAdd(this._onDidAddEditor));
        for (editor in editorService.listCodeEditors()) {
            this._onDidAddEditor(editor);
        }
    }

    public function dispose():Void {
        this._disposables.dispose();
        this._onDidChange.dispose();
        for (l in this._listener) {
            l.dispose();
        }
        this._listener.clear();
    }

    function _onDidAddEditor(editor:ICodeEditor):Void {
        this._listener.set(editor, Lifecycle.combinedDisposable([
            editor.onDidChangeCursorPosition(_ -> this._onDidChange.fire({editor: editor})),
            editor.onDidChangeModelContent(_ -> this._onDidChange.fire({editor: editor})),
        ]));
    }

    function _onDidRemoveEditor(editor:ICodeEditor):Void {
        final l = this._listener.get(editor);
        if (l != null) {
            l.dispose();
        }
        this._listener.remove(editor);
    }

}

/**
 * `editor.gotoNextSymbolFromResult` (F12 while `hasSymbols`).
 */
private class GotoNextSymbolFromResultCommand extends EditorCommand {

    final service:SymbolNavigationService;

    public function new(service:SymbolNavigationService) {
        super({
            id: 'editor.gotoNextSymbolFromResult',
            precondition: SymbolNavigationService.ctxHasSymbols,
            kbOpts: {
                weight: KeybindingWeight.EditorContrib,
                primary: KeyCode.F12
            }
        });
        this.service = service;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        service.revealNext(editor);
    }

}

/**
 * The module level registrations of symbolNavigation.ts.
 */
class SymbolNavigationRegistration {

    public static function register(r:EditorExtensionsRegistry, service:SymbolNavigationService):Void {
        r.registerEditorCommand(new GotoNextSymbolFromResultCommand(service));
        r.context.keybindingsRegistry.registerCommandAndKeybindingRule({
            id: 'editor.gotoNextSymbolFromResult.cancel',
            weight: KeybindingWeight.EditorContrib,
            when: SymbolNavigationService.ctxHasSymbols,
            primary: KeyCode.Escape,
            handler: (accessor, args) -> service.reset()
        });
    }

}
