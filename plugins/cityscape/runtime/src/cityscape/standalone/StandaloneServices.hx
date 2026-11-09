// Ported from vscode src/vs/editor/standalone/browser/standaloneServices.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.standalone;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.Keybindings;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.platform.commands.common.Commands;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.AbstractKeybindingService;
import cityscape.platform.keybinding.common.Keybinding;
import cityscape.platform.keybinding.common.KeybindingResolver;
import cityscape.platform.keybinding.common.KeybindingsRegistry;
import cityscape.platform.keybinding.common.ResolvedKeybindingItem;
import cityscape.platform.keybinding.common.UsLayoutResolvedKeybinding;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * Monaco's `StandaloneCommandService`: runs the commands of the commands
 * registry of a context.
 */
class StandaloneCommandService implements ICommandService {

    final _context:Cityscape;

    final _onWillExecuteCommand = new Emitter<ICommandEvent>();
    public var onWillExecuteCommand(get, never):Event<ICommandEvent>;
    function get_onWillExecuteCommand():Event<ICommandEvent> {
        return _onWillExecuteCommand.event;
    }

    final _onDidExecuteCommand = new Emitter<ICommandEvent>();
    public var onDidExecuteCommand(get, never):Event<ICommandEvent>;
    function get_onDidExecuteCommand():Event<ICommandEvent> {
        return _onDidExecuteCommand.event;
    }

    public function new(context:Cityscape) {
        this._context = context;
    }

    /**
     * Runs the command `id` with `args` (Monaco's `...args`). Throws when the
     * command does not exist (Monaco rejects the promise).
     */
    public function executeCommand(id:String, ?args:Array<Any>):Void {
        final command = _context.commandsRegistry.getCommand(id);
        if (command == null) {
            throw 'command \'' + id + '\' not found';
        }
        if (args == null) {
            args = [];
        }
        this._onWillExecuteCommand.fire({commandId: id, args: args});
        command.handler(_context, args);
        this._onDidExecuteCommand.fire({commandId: id, args: args});
    }

}

/**
 * Monaco's `ICodeEditorService` (the parts the commands use): the editors of
 * a context and the one that has the focus.
 */
/**
 * The options of an editor input (the parts of Monaco's
 * `ITextEditorOptions` Cityscape uses): `selection` is a range, or a
 * position when its end is null.
 */
typedef ITextEditorOptions = {
    @:optional var selection:Null<cityscape.common.core.Range.IRange>;
    @:optional var selectionRevealType:Null<Int>;
    @:optional var revealIfOpened:Null<Bool>;
    @:optional var pinned:Null<Bool>;
    @:optional var preserveFocus:Null<Bool>;
}

/**
 * A resource to open with its options (Monaco's `ITextResourceEditorInput`).
 */
typedef ITextResourceEditorInput = {
    var resource:Uri;
    @:optional var options:Null<ITextEditorOptions>;
}

/**
 * Opens a resource (Monaco's `ICodeEditorOpenHandler`): gives the editor
 * showing it to `resolve`, or null when the handler does not open it.
 */
typedef ICodeEditorOpenHandler = (input:ITextResourceEditorInput, source:Null<ICodeEditor>, sideBySide:Bool, resolve:(editor:Null<ICodeEditor>) -> Void) -> Void;

class CodeEditorService {

    final _codeEditors:Array<ICodeEditor> = [];
    var _activeEditor:Null<ICodeEditor> = null;

    /**
     * The editor running a keybinding or a command it was asked to run: the
     * commands find it first (Monaco finds the editor from the DOM focus).
     */
    var _invokingEditors:Array<ICodeEditor> = [];

    final _onCodeEditorAdd = new Emitter<ICodeEditor>();
    public final onCodeEditorAdd:Event<ICodeEditor>;

    final _onCodeEditorRemove = new Emitter<ICodeEditor>();
    public final onCodeEditorRemove:Event<ICodeEditor>;

    final _codeEditorOpenHandlers:Array<ICodeEditorOpenHandler> = [];

    public function new() {
        onCodeEditorAdd = _onCodeEditorAdd.event;
        onCodeEditorRemove = _onCodeEditorRemove.event;
        // Monaco's StandaloneCodeEditorService: a location in the model of
        // the source editor is shown in that editor
        registerCodeEditorOpenHandler((input, source, sideBySide, resolve) -> {
            if (source == null) {
                resolve(null);
                return;
            }
            resolve(doOpenEditor(source, input));
        });
    }

    function doOpenEditor(editor:ICodeEditor, input:ITextResourceEditorInput):Null<ICodeEditor> {
        final model = findModel(editor, input.resource);
        if (model == null) {
            return null;
        }

        final selection:Null<cityscape.common.core.Range.IRange> = input.options != null ? input.options.selection : null;
        if (selection != null) {
            if (selection.endLineNumber > 0 && selection.endColumn > 0) {
                editor.setSelection(selection);
                editor.revealRangeInCenter(selection, cityscape.common.EditorCommon.ScrollType.Immediate);
            }
            else {
                final pos:cityscape.common.core.Position.IPosition = {
                    lineNumber: selection.startLineNumber,
                    column: selection.startColumn
                };
                editor.setPosition(pos);
                editor.revealPositionInCenter(pos, cityscape.common.EditorCommon.ScrollType.Immediate);
            }
        }

        return editor;
    }

    function findModel(editor:ICodeEditor, resource:Uri):Null<cityscape.common.Model.ITextModel> {
        final model = editor.getModel();
        if (model != null && model.uri.toString() != resource.toString()) {
            return null;
        }
        return model;
    }

    /**
     * Opens a location (Monaco's `openCodeEditor`): the handlers are asked
     * in turn, the last registered first, until one gives an editor. The
     * default handler shows locations of the source editor's model in that
     * editor; a host registers a handler (`registerCodeEditorOpenHandler`)
     * to open other models or files (switch the model of an editor, open a
     * tab...). `callback` gets the editor showing the location, or null.
     */
    public function openCodeEditor(input:ITextResourceEditorInput, source:Null<ICodeEditor>, sideBySide:Bool = false, ?callback:(editor:Null<ICodeEditor>) -> Void):Void {
        final handlers = _codeEditorOpenHandlers.copy();
        function next(index:Int):Void {
            if (index >= handlers.length) {
                if (callback != null) {
                    callback(null);
                }
                return;
            }
            var answered = false;
            handlers[index](input, source, sideBySide, candidate -> {
                if (answered) {
                    return;
                }
                answered = true;
                if (candidate != null) {
                    if (callback != null) {
                        callback(candidate);
                    }
                }
                else {
                    next(index + 1);
                }
            });
        }
        next(0);
    }

    /**
     * Registers a handler opening locations (Monaco's
     * `registerCodeEditorOpenHandler`), asked before the ones registered
     * earlier. It gives the editor showing the location to `resolve`, or
     * null to let the next handler try.
     */
    public function registerCodeEditorOpenHandler(handler:ICodeEditorOpenHandler):IDisposable {
        _codeEditorOpenHandlers.unshift(handler);
        return Lifecycle.toDisposable(() -> _codeEditorOpenHandlers.remove(handler));
    }

    public function addCodeEditor(editor:ICodeEditor):Void {
        _codeEditors.push(editor);
        _onCodeEditorAdd.fire(editor);
    }

    public function removeCodeEditor(editor:ICodeEditor):Void {
        if (_codeEditors.remove(editor)) {
            if (_activeEditor == editor) {
                _activeEditor = null;
            }
            _onCodeEditorRemove.fire(editor);
        }
    }

    public function listCodeEditors():Array<ICodeEditor> {
        return _codeEditors.copy();
    }

    /**
     * The editor whose text or widgets have the focus.
     */
    public function getFocusedCodeEditor():Null<ICodeEditor> {
        if (_invokingEditors.length > 0) {
            return _invokingEditors[_invokingEditors.length - 1];
        }
        var editorWithWidgetFocus:Null<ICodeEditor> = null;
        for (editor in _codeEditors) {
            if (editor.hasTextFocus()) {
                // bingo!
                return editor;
            }
            if (editor.hasWidgetFocus()) {
                editorWithWidgetFocus = editor;
            }
        }
        return editorWithWidgetFocus;
    }

    /**
     * The editor that had the focus last.
     */
    public function getActiveCodeEditor():Null<ICodeEditor> {
        return _activeEditor;
    }

    /**
     * Called by an editor when it gets the focus.
     */
    public function setActiveCodeEditor(editor:Null<ICodeEditor>):Void {
        _activeEditor = editor;
    }

    /**
     * Runs `fn` with `editor` as the focused editor of the commands it runs
     * (a keybinding dispatched by an editor, `editor.trigger`).
     */
    public function withInvokingEditor<T>(editor:ICodeEditor, fn:() -> T):T {
        _invokingEditors.push(editor);
        try {
            final result = fn();
            _invokingEditors.pop();
            return result;
        }
        catch (e:Dynamic) {
            _invokingEditors.pop();
            throw e;
        }
    }

}

/**
 * A keybinding rule of `addKeybindingRule(s)` (Monaco's
 * `IKeybindingRule` of standaloneServices.ts): `command` null or
 * `'-commandId'` removes a default keybinding.
 */
typedef IStandaloneKeybindingRule = {
    var keybinding:Int;
    @:optional var command:Null<String>;
    @:optional var commandArgs:Any;
    @:optional var when:Null<ContextKeyExpression>;
}

/**
 * Monaco's `StandaloneKeybindingService`, one per `Cityscape` context: the
 * default keybindings of the context's keybindings registry and the dynamic
 * ones (`addCommand`, `addAction`, `addKeybindingRules`), resolved with the
 * US layout (Glaze reports the unshifted US key of each keystroke).
 *
 * Keys reach it from the editors (`CityscapeEditor`, through one Glaze
 * binding per chord in the `CityscapeEditor` key context): the `when`
 * clauses are evaluated in the context of the editor that has the focus.
 */
class StandaloneKeybindingService extends AbstractKeybindingService {

    final _keybindingsRegistry:KeybindingsRegistry;
    var _cachedResolver:Null<KeybindingResolver>;
    var _cachedRegistryVersion:Int = -1;
    var _dynamicKeybindings:Array<IKeybindingItem>;

    /**
     * Incremented each time the keybindings change (the editors bind the
     * new chords in Glaze).
     */
    public var version(get, never):Int;
    function get_version():Int {
        return _dynamicVersion + _keybindingsRegistry.version;
    }

    var _dynamicVersion:Int = 0;

    public function new(contextKeyService:IContextKeyService, commandService:ICommandService, keybindingsRegistry:KeybindingsRegistry) {
        super(contextKeyService, commandService);
        this._keybindingsRegistry = keybindingsRegistry;
        this._cachedResolver = null;
        this._dynamicKeybindings = [];
    }

    public function addDynamicKeybinding(command:String, keybinding:Int, handler:ICommandHandler, commandsRegistry:CommandsRegistry, when:Null<ContextKeyExpression>):IDisposable {
        return Lifecycle.combinedDisposable([
            commandsRegistry.registerCommandHandler(command, handler),
            this.addDynamicKeybindings([{
                keybinding: keybinding,
                command: command,
                when: when
            }])
        ]);
    }

    public function addDynamicKeybindings(rules:Array<IStandaloneKeybindingRule>):IDisposable {
        final OS = Platform.OS;
        final entries:Array<IKeybindingItem> = [for (rule in rules) {
            final keybinding = Keybindings.decodeKeybinding(rule.keybinding, OS);
            ({
                keybinding: keybinding,
                command: rule.command,
                commandArgs: rule.commandArgs,
                when: rule.when,
                weight1: 1000,
                weight2: 0,
                extensionId: null,
                isBuiltinExtension: false
            } : IKeybindingItem);
        }];
        this._dynamicKeybindings = this._dynamicKeybindings.concat(entries);

        this.updateResolver();

        return Lifecycle.toDisposable(() -> {
            // Search the first entry and remove them all since they will be contiguous
            for (i in 0...this._dynamicKeybindings.length) {
                if (entries.length > 0 && this._dynamicKeybindings[i] == entries[0]) {
                    this._dynamicKeybindings.splice(i, entries.length);
                    this.updateResolver();
                    return;
                }
            }
        });
    }

    function updateResolver():Void {
        this._cachedResolver = null;
        this._dynamicVersion++;
        this._onDidUpdateKeybindings.fire();
    }

    function _getResolver():KeybindingResolver {
        if (this._cachedResolver == null || this._cachedRegistryVersion != _keybindingsRegistry.version) {
            this._cachedRegistryVersion = _keybindingsRegistry.version;
            final defaults = this._toNormalizedKeybindingItems(_keybindingsRegistry.getDefaultKeybindings(), true);
            final overrides = this._toNormalizedKeybindingItems(this._dynamicKeybindings, false);
            this._cachedResolver = new KeybindingResolver(defaults, overrides, (str) -> this._log(str));
        }
        return this._cachedResolver;
    }

    function _toNormalizedKeybindingItems(items:Array<IKeybindingItem>, isDefault:Bool):Array<ResolvedKeybindingItem> {
        final OS = Platform.OS;
        final result:Array<ResolvedKeybindingItem> = [];
        for (item in items) {
            final when = item.when;
            final keybinding = item.keybinding;

            if (keybinding == null) {
                // This might be a removal keybinding item in user settings => accept it
                result.push(new ResolvedKeybindingItem(null, item.command, item.commandArgs, when, isDefault, null, false));
            }
            else {
                final resolvedKeybindings = USLayoutResolvedKeybinding.resolveKeybinding(keybinding, OS);
                for (resolvedKeybinding in resolvedKeybindings) {
                    result.push(new ResolvedKeybindingItem(resolvedKeybinding, item.command, item.commandArgs, when, isDefault, null, false));
                }
            }
        }

        return result;
    }

    public function resolveKeybinding(keybinding:Keybinding):Array<ResolvedKeybinding> {
        return cast USLayoutResolvedKeybinding.resolveKeybinding(keybinding, Platform.OS);
    }

    public function resolveKeyboardEvent(keyboardEvent:IKeyboardEvent):ResolvedKeybinding {
        final chord = new KeyCodeChord(
            keyboardEvent.ctrlKey,
            keyboardEvent.shiftKey,
            keyboardEvent.altKey,
            keyboardEvent.metaKey,
            keyboardEvent.keyCode
        );
        return new USLayoutResolvedKeybinding([chord], Platform.OS);
    }

    public function resolveUserBinding(userBinding:String):Array<ResolvedKeybinding> {
        return [];
    }

    /**
     * Every chord (the dispatch strings, `meta+K`) that starts or continues a
     * keybinding, with its `KeyCodeChord`: the editors bind them in Glaze.
     */
    public function getAllChords():Array<KeyCodeChord> {
        final OS = Platform.OS;
        final seen = new Map<String, Bool>();
        final result:Array<KeyCodeChord> = [];
        function add(keybinding:Null<Keybinding>) {
            if (keybinding == null) {
                return;
            }
            for (chord in keybinding.chords) {
                final keyCodeChord = Std.downcast(chord, KeyCodeChord);
                if (keyCodeChord == null) {
                    continue;
                }
                final dispatch = USLayoutResolvedKeybinding.getDispatchStr(keyCodeChord);
                if (dispatch != null && !seen.exists(dispatch)) {
                    seen.set(dispatch, true);
                    result.push(keyCodeChord);
                }
            }
        }
        for (item in _keybindingsRegistry.getDefaultKeybindings()) {
            add(item.keybinding);
        }
        for (item in _dynamicKeybindings) {
            add(item.keybinding);
        }
        return result;
    }

}

// Snippets (step 7, cs7-rest-snip): the label and workspace services of the
// snippet variables

/**
 * Monaco's `StandaloneUriLabelService`: the file system path of a `file`
 * URI, the path of the others.
 */
class StandaloneUriLabelService implements cityscape.platform.label.common.Label.ILabelService {

    public function new() {}

    public function getUriLabel(resource:Uri, ?options:cityscape.platform.label.common.Label.UriLabelOptions):String {
        if (resource.scheme == 'file') {
            return resource.fsPath;
        }
        return resource.path;
    }

    public function getUriBasenameLabel(resource:Uri):String {
        return cityscape.base.common.Resources.basename(resource);
    }

}

/**
 * Monaco's `StandaloneWorkspaceContextService`: a workspace of one folder,
 * `inmemory://model/` (so `WORKSPACE_NAME` is empty and `WORKSPACE_FOLDER`
 * is `/` in snippets, like Monaco).
 */
class StandaloneWorkspaceContextService implements cityscape.platform.workspace.common.Workspace.IWorkspaceContextService {

    public static inline final SCHEME = 'inmemory';

    /** Monaco's `STANDALONE_EDITOR_WORKSPACE_ID` */
    public static inline final STANDALONE_EDITOR_WORKSPACE_ID = '4064f6ec-cb38-4ad0-af64-ee6467e63c82';

    final workspace:cityscape.platform.workspace.common.Workspace.IWorkspace;

    public function new() {
        final resource = Uri.from({scheme: StandaloneWorkspaceContextService.SCHEME, authority: 'model', path: '/'});
        this.workspace = {id: STANDALONE_EDITOR_WORKSPACE_ID, folders: [{uri: resource, name: '', index: 0}]};
    }

    public function getWorkspace():cityscape.platform.workspace.common.Workspace.IWorkspace {
        return this.workspace;
    }

}
