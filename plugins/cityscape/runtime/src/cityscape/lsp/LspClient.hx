// New code for Cityscape (not a port): a generic Language Server Protocol
// client plugging a language server into the providers, models and markers
// of a Cityscape context.
package cityscape.lsp;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.LanguageSelector;
import cityscape.common.Model.ITextModel;
import cityscape.common.Model.ModelUtils;
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.common.core.Range;
import cityscape.platform.markers.common.Markers.IMarkerData;

/**
 * The options of an `LspClient`.
 */
typedef LspClientOptions = {
    /**
     * The language ids of the models synchronized with the server and of the
     * providers registered for it (`'*'` for every language).
     */
    var languageIds:Array<String>;

    /**
     * The root uri of the workspace given to `initialize` (also its single
     * workspace folder), null for none.
     */
    @:optional var rootUri:Null<String>;

    /**
     * The `initializationOptions` of `initialize`.
     */
    @:optional var initializationOptions:Any;

    /**
     * The owner of the markers made from the server's diagnostics
     * (`'lsp'` by default). Give each client of a context its own.
     */
    @:optional var markerOwner:Null<String>;

    /**
     * Forces the document synchronization kind (0 None, 1 Full,
     * 2 Incremental) instead of the one the server declares.
     */
    @:optional var syncKind:Null<Int>;

    /**
     * The `clientInfo.name` of `initialize` (`'Cityscape'` by default).
     */
    @:optional var clientName:Null<String>;

    /**
     * The client capabilities sent to `initialize`, replacing
     * `LspClient.defaultClientCapabilities()`.
     */
    @:optional var capabilities:Any;

    /**
     * Which of the server's features the client registers as providers of
     * the context (and commands, `executeCommandProvider`): all of them when
     * missing or `true`, none with `false`, or the list of the capabilities
     * to register (`['hoverProvider', 'completionProvider']`). A host that
     * registers its own providers still gets the document sync, the
     * diagnostics and `sendRequest`.
     */
    @:optional var registerProviders:Any;
}

/**
 * A request sent and not answered yet.
 */
private class PendingRequest {

    public final method:String;
    public final callback:(result:Dynamic, error:Dynamic) -> Void;
    public var cancelListener:Null<IDisposable> = null;

    public function new(method:String, callback:(result:Dynamic, error:Dynamic) -> Void) {
        this.method = method;
        this.callback = callback;
    }

}

/**
 * A model the client listens to (language changes, disposal), opened on the
 * server or not.
 */
private class TrackedModel {

    public final model:ITextModel;
    public final store:DisposableStore = new DisposableStore();

    public function new(model:ITextModel) {
        this.model = model;
    }

}

/**
 * A model opened on the server (`textDocument/didOpen` sent).
 */
private class OpenDocument {

    public final model:ITextModel;
    public final uri:String;
    public final languageId:String;
    public var version:Int;
    public var contentListener:Null<IDisposable> = null;

    public function new(model:ITextModel, uri:String, languageId:String, version:Int) {
        this.model = model;
        this.uri = uri;
        this.languageId = languageId;
        this.version = version;
    }

    public function dispose():Void {
        if (contentListener != null) {
            contentListener.dispose();
            contentListener = null;
        }
    }

}

/**
 * A Language Server Protocol client: connects a language server (through
 * an `LspTransport`) to a `Cityscape` context.
 *
 * - `start` sends `initialize` and `initialized`, then registers in the
 *   context the providers of the features the server declares (completion,
 *   hover, definition, document symbols, code actions, signature help,
 *   formatting) for `languageIds`, and the commands of its
 *   `executeCommandProvider` (they send `workspace/executeCommand`).
 * - The models of the context's model service whose language is in
 *   `languageIds` are opened on the server (`didOpen`), their changes sent
 *   (`didChange`, full or incremental as the server asks), closed on
 *   disposal (`didClose`), closed and reopened when their language changes.
 *   A model created without the model service (`new TextModel(...)`) is
 *   synchronized once given to `openModel` (or when a provider of the client
 *   is asked about it).
 * - `textDocument/publishDiagnostics` becomes markers of `markerOwner`; the
 *   LSP diagnostics are kept so that code action requests send the
 *   original diagnostics of the markers they get.
 * - Requests of the server to the client get a default answer, unless
 *   `onServerRequest` handles them.
 *
 * Positions are converted by `LspConversions` (LSP lines and characters
 * start at 0, Monaco's at 1, both in UTF-16 units).
 */
class LspClient {

    /**
     * The client capabilities sent by default to `initialize`.
     */
    public static function defaultClientCapabilities():Dynamic {
        return {
            general: {
                positionEncodings: ['utf-16']
            },
            workspace: {
                applyEdit: true,
                workspaceEdit: {
                    documentChanges: true,
                    resourceOperations: ['create', 'rename', 'delete']
                },
                configuration: true,
                workspaceFolders: false,
                executeCommand: {dynamicRegistration: false}
            },
            textDocument: {
                synchronization: {
                    dynamicRegistration: false,
                    willSave: false,
                    willSaveWaitUntil: false,
                    didSave: false
                },
                completion: {
                    dynamicRegistration: false,
                    contextSupport: true,
                    completionItem: {
                        snippetSupport: true,
                        commitCharactersSupport: true,
                        documentationFormat: ['markdown', 'plaintext'],
                        deprecatedSupport: true,
                        preselectSupport: true,
                        tagSupport: {valueSet: [1]},
                        insertReplaceSupport: true,
                        labelDetailsSupport: true,
                        resolveSupport: {properties: ['documentation', 'detail', 'additionalTextEdits', 'command']}
                    },
                    completionItemKind: {valueSet: [for (i in 1...26) i]},
                    completionList: {itemDefaults: ['commitCharacters', 'editRange', 'insertTextFormat', 'data']}
                },
                hover: {
                    dynamicRegistration: false,
                    contentFormat: ['markdown', 'plaintext']
                },
                definition: {
                    dynamicRegistration: false,
                    linkSupport: true
                },
                documentSymbol: {
                    dynamicRegistration: false,
                    hierarchicalDocumentSymbolSupport: true,
                    symbolKind: {valueSet: [for (i in 1...27) i]},
                    tagSupport: {valueSet: [1]}
                },
                codeAction: {
                    dynamicRegistration: false,
                    codeActionLiteralSupport: {
                        codeActionKind: {
                            valueSet: ['', 'quickfix', 'refactor', 'refactor.extract', 'refactor.inline', 'refactor.rewrite', 'source', 'source.organizeImports', 'source.fixAll']
                        }
                    },
                    isPreferredSupport: true,
                    disabledSupport: true,
                    dataSupport: true,
                    resolveSupport: {properties: ['edit']}
                },
                signatureHelp: {
                    dynamicRegistration: false,
                    contextSupport: true,
                    signatureInformation: {
                        documentationFormat: ['markdown', 'plaintext'],
                        parameterInformation: {labelOffsetSupport: true},
                        activeParameterSupport: true
                    }
                },
                formatting: {dynamicRegistration: false},
                rangeFormatting: {dynamicRegistration: false},
                publishDiagnostics: {
                    relatedInformation: true,
                    tagSupport: {valueSet: [1, 2]},
                    codeDescriptionSupport: true,
                    dataSupport: true,
                    versionSupport: false
                }
            },
            window: {
                workDoneProgress: false
            }
        };
    }

    /**
     * The JSON-RPC error code of a cancelled request (LSP's
     * `RequestCancelled`).
     */
    public static inline final RequestCancelled = -32800;

    /**
     * The JSON-RPC error code of a method the receiver does not handle.
     */
    public static inline final MethodNotFound = -32601;

    /**
     * The error code given to requests sent while the client is not running
     * (LSP's `ServerNotInitialized`).
     */
    public static inline final ServerNotInitialized = -32002;

    public final context:Cityscape;

    public final transport:LspTransport;

    /**
     * The language ids of the synchronized models and of the providers.
     */
    public final languageIds:Array<String>;

    /**
     * The owner of the markers of the server's diagnostics.
     */
    public final markerOwner:String;

    final options:LspClientOptions;

    /**
     * The capabilities of the server (the `capabilities` of the
     * `initialize` result), null before.
     */
    public var serverCapabilities(default, null):Dynamic = null;

    /**
     * The `serverInfo` of the `initialize` result.
     */
    public var serverInfo(default, null):Dynamic = null;

    /**
     * True once `initialize` was answered and `initialized` sent.
     */
    public var isReady(default, null):Bool = false;

    public var isDisposed(default, null):Bool = false;

    /**
     * Handles a request of the server to the client before the defaults:
     * return true when the request is handled, and answer it by calling
     * `respond` once (at once or later). The defaults: `workspace/configuration`
     * gives null for each item, `workspace/applyEdit` applies the text
     * edits to the models of the context (`applyWorkspaceEdit`),
     * `window/showDocument` gives `{success: false}`,
     * `client/registerCapability`, `client/unregisterCapability`,
     * `window/workDoneProgress/create` and `window/showMessageRequest` give
     * null; other methods get a `MethodNotFound` error.
     */
    public var onServerRequest:Null<(method:String, params:Dynamic, respond:(result:Dynamic) -> Void) -> Bool> = null;

    /**
     * Told about failures: a failed `initialize`, an exception thrown while
     * handling a message of the server.
     */
    public var onError:Null<(message:String, error:Dynamic) -> Void> = null;

    var started:Bool = false;
    var nextId:Int = 1;
    var syncKind:Int = 0;
    var openClose:Bool = false;

    final pending:Map<String, PendingRequest> = new Map();
    final notificationHandlers:Map<String, Array<(params:Dynamic) -> Void>> = new Map();
    final trackedModels:Map<String, TrackedModel> = new Map();
    final openDocuments:Map<String, OpenDocument> = new Map();
    final diagnostics:Map<String, Array<Dynamic>> = new Map();
    final manualModels:Array<ITextModel> = [];
    final listeners:DisposableStore = new DisposableStore();
    final registrations:DisposableStore = new DisposableStore();

    public function new(context:Cityscape, transport:LspTransport, options:LspClientOptions) {
        this.context = context;
        this.transport = transport;
        this.options = options;
        this.languageIds = options.languageIds != null ? options.languageIds.copy() : [];
        this.markerOwner = options.markerOwner != null ? options.markerOwner : 'lsp';
    }

    //#region lifecycle

    /**
     * Starts the transport and sends `initialize`; once the server
     * answered: `initialized`, the providers and commands, the `didOpen` of
     * the matching models, then `onReady`. A failed `initialize` goes to
     * `onError` (`onReady` is not called).
     */
    public function start(?onReady:() -> Void):Void {
        if (started || isDisposed) {
            return;
        }
        started = true;
        transport.start(handleMessage);
        sendRequest('initialize', makeInitializeParams(), (result, error) -> {
            if (isDisposed) {
                return;
            }
            if (error != null || result == null) {
                reportError('initialize failed', error);
                return;
            }
            serverCapabilities = result.capabilities != null ? result.capabilities : {};
            serverInfo = result.serverInfo;
            readSyncOptions();
            sendNotification('initialized', {});
            isReady = true;
            registerProviders();
            registerCommands();
            listenToModels();
            if (onReady != null) {
                onReady();
            }
        });
    }

    function makeInitializeParams():Dynamic {
        final rootUri = options.rootUri;
        final params:Dynamic = {
            processId: null,
            clientInfo: {name: options.clientName != null ? options.clientName : 'Cityscape'},
            rootUri: rootUri,
            capabilities: options.capabilities != null ? options.capabilities : defaultClientCapabilities()
        };
        if (rootUri != null) {
            var name = rootUri;
            var end = name.length;
            while (end > 0 && name.charAt(end - 1) == '/') {
                end--;
            }
            name = name.substring(name.lastIndexOf('/', end - 1) + 1, end);
            params.workspaceFolders = [{uri: rootUri, name: name}];
        }
        if (options.initializationOptions != null) {
            params.initializationOptions = options.initializationOptions;
        }
        return params;
    }

    /**
     * Reads `textDocumentSync` (a kind, or `{openClose, change}`). A server
     * declaring a change kind without `openClose` gets the open and close
     * notifications too (the changes would be useless without them).
     */
    function readSyncOptions():Void {
        final sync:Dynamic = serverCapabilities.textDocumentSync;
        if (JsValues.isNumber(sync)) {
            syncKind = LspConversions.asInt(sync);
            openClose = syncKind > 0;
        }
        else if (sync != null) {
            syncKind = LspConversions.asInt(sync.change, 0);
            openClose = LspConversions.asBool(sync.openClose, syncKind > 0);
        }
        else {
            syncKind = 0;
            openClose = false;
        }
        if (options.syncKind != null) {
            syncKind = options.syncKind;
            if (syncKind > 0) {
                openClose = true;
            }
        }
    }

    /**
     * The document synchronization kind in use (0 None, 1 Full,
     * 2 Incremental).
     */
    public function getSyncKind():Int {
        return syncKind;
    }

    /**
     * Stops the client: unregisters the providers and commands, stops
     * listening to the models, removes the markers of `markerOwner`, fails
     * the pending requests (their callbacks get a `RequestCancelled`
     * error), then sends `shutdown` and, once answered, `exit`, and
     * disposes the transport.
     */
    public function dispose():Void {
        if (isDisposed) {
            return;
        }
        isDisposed = true;
        isReady = false;
        registrations.dispose();
        listeners.dispose();
        for (tracked in trackedModels) {
            tracked.store.dispose();
        }
        trackedModels.clear();
        for (doc in openDocuments) {
            doc.dispose();
        }
        openDocuments.clear();
        manualModels.resize(0);
        diagnostics.clear();
        notificationHandlers.clear();
        context.markerService.changeAll(markerOwner, []);

        final requests = [for (r in pending) r];
        pending.clear();
        for (r in requests) {
            if (r.cancelListener != null) {
                r.cancelListener.dispose();
            }
            r.callback(null, {code: RequestCancelled, message: 'The client was disposed'});
        }

        if (!started) {
            transport.dispose();
            return;
        }
        request('shutdown', null, null, (_, _) -> {
            sendRaw({jsonrpc: '2.0', method: 'exit'});
            transport.dispose();
        });
    }

    //#endregion

    //#region messages

    /**
     * Sends a request; `callback` gets the result, or the error
     * (`{code, message, data}`) as its second argument. A request sent
     * before `start` or after `dispose` fails at once.
     */
    public function sendRequest(method:String, params:Dynamic, callback:(result:Dynamic, error:Dynamic) -> Void):Void {
        sendCancellableRequest(method, params, null, callback);
    }

    /**
     * Sends a request cancelled with `token`: once the token is cancelled,
     * `$/cancelRequest` is sent, `callback` gets a `RequestCancelled`
     * error at once and the late response is ignored.
     */
    public function sendCancellableRequest(method:String, params:Dynamic, token:Null<CancellationToken>, callback:(result:Dynamic, error:Dynamic) -> Void):Void {
        if (!started || isDisposed) {
            callback(null, {code: ServerNotInitialized, message: 'The client is not running'});
            return;
        }
        request(method, params, token, callback);
    }

    function request(method:String, params:Dynamic, token:Null<CancellationToken>, callback:(result:Dynamic, error:Dynamic) -> Void):Void {
        if (token != null && token.isCancellationRequested) {
            callback(null, {code: RequestCancelled, message: 'Request cancelled'});
            return;
        }
        final id = nextId++;
        final key = Std.string(id);
        final pendingRequest = new PendingRequest(method, callback);
        // registered before sending: the response may come from inside `send`
        pending.set(key, pendingRequest);
        if (token != null) {
            pendingRequest.cancelListener = token.onCancellationRequested(() -> {
                if (pending.get(key) == pendingRequest) {
                    pending.remove(key);
                    sendRaw({jsonrpc: '2.0', method: "$/cancelRequest", params: {id: id}});
                    pendingRequest.callback(null, {code: RequestCancelled, message: 'Request cancelled'});
                }
            });
        }
        final message:Dynamic = {jsonrpc: '2.0', id: id, method: method};
        if (params != null) {
            message.params = params;
        }
        sendRaw(message);
    }

    /**
     * Sends a notification (ignored before `start` and after `dispose`).
     */
    public function sendNotification(method:String, params:Dynamic):Void {
        if (!started || isDisposed) {
            return;
        }
        final message:Dynamic = {jsonrpc: '2.0', method: method};
        if (params != null) {
            message.params = params;
        }
        sendRaw(message);
    }

    /**
     * Listens to a notification of the server (`window/logMessage`, a
     * custom method...). The handlers of `textDocument/publishDiagnostics`
     * are called after the markers were updated.
     */
    public function onNotification(method:String, handler:(params:Dynamic) -> Void):IDisposable {
        var handlers = notificationHandlers.get(method);
        if (handlers == null) {
            handlers = [];
            notificationHandlers.set(method, handlers);
        }
        handlers.push(handler);
        return Lifecycle.toDisposable(() -> {
            final list = notificationHandlers.get(method);
            if (list != null) {
                list.remove(handler);
            }
        });
    }

    /**
     * Runs a command of the server (`workspace/executeCommand`).
     */
    public function executeCommand(command:String, args:Null<Array<Any>>, ?callback:(result:Dynamic, error:Dynamic) -> Void):Void {
        final params:Dynamic = {command: command};
        if (args != null && args.length > 0) {
            params.arguments = args;
        }
        sendRequest('workspace/executeCommand', params, callback != null ? callback : (_, _) -> {});
    }

    function sendRaw(message:Dynamic):Void {
        transport.send(message);
    }

    function handleMessage(message:Dynamic):Void {
        if (message == null) {
            return;
        }
        try {
            final method = LspConversions.asString(message.method);
            final id:Dynamic = message.id;
            if (method != null) {
                if (isDisposed) {
                    return;
                }
                if (id != null) {
                    handleServerRequest(id, method, message.params);
                }
                else {
                    handleNotification(method, message.params);
                }
            }
            else if (id != null) {
                handleResponse(id, message.result, message.error);
            }
        }
        catch (e:Dynamic) {
            reportError('error while handling a message of the server', e);
            Errors.onUnexpectedError(e);
        }
    }

    static function idKey(id:Dynamic):String {
        return JsValues.isNumber(id) ? Std.string(Std.int(JsValues.toNumber(id))) : Std.string(id);
    }

    function handleResponse(id:Dynamic, result:Dynamic, error:Dynamic):Void {
        final key = idKey(id);
        final pendingRequest = pending.get(key);
        if (pendingRequest == null) {
            // cancelled, or not ours
            return;
        }
        pending.remove(key);
        if (pendingRequest.cancelListener != null) {
            pendingRequest.cancelListener.dispose();
            pendingRequest.cancelListener = null;
        }
        pendingRequest.callback(error != null ? null : result, error);
    }

    function handleServerRequest(id:Dynamic, method:String, params:Dynamic):Void {
        var answered = false;
        final respond = (result:Dynamic) -> {
            if (answered || isDisposed) {
                return;
            }
            answered = true;
            sendRaw({jsonrpc: '2.0', id: id, result: result});
        };
        if (onServerRequest != null && onServerRequest(method, params, respond)) {
            return;
        }
        switch method {
            case 'workspace/configuration':
                final items = params != null ? LspConversions.asArray(params.items) : null;
                final result:Array<Dynamic> = items == null ? [] : [for (i in 0...items.length) null];
                respond(result);
            case 'workspace/applyEdit':
                respond(applyWorkspaceEdit(params != null ? params.edit : null));
            case 'window/showDocument':
                respond({success: false});
            case 'client/registerCapability' | 'client/unregisterCapability' | 'window/workDoneProgress/create' | 'window/showMessageRequest':
                respond(null);
            case _:
                answered = true;
                sendRaw({jsonrpc: '2.0', id: id, error: {code: MethodNotFound, message: 'Unhandled method ' + method}});
        }
    }

    function handleNotification(method:String, params:Dynamic):Void {
        if (method == 'textDocument/publishDiagnostics' && params != null) {
            publishDiagnostics(params);
        }
        final handlers = notificationHandlers.get(method);
        if (handlers != null) {
            for (handler in handlers.copy()) {
                handler(params);
            }
        }
    }

    /**
     * Applies an LSP `WorkspaceEdit` to the models of the context (the
     * default answer to `workspace/applyEdit`): every edited resource must
     * have a model (of the model service, or open on the server) at the
     * version the edit gives, and the edit must hold no file operation;
     * otherwise nothing is applied. Gives the `ApplyWorkspaceEditResult`.
     */
    public function applyWorkspaceEdit(edit:Dynamic):Dynamic {
        final workspaceEdit = LspConversions.toWorkspaceEdit(edit);
        final models:Array<ITextModel> = [];
        final operations:Array<Array<cityscape.common.Model.IIdentifiedSingleEditOperation>> = [];
        for (item in workspaceEdit.edits) {
            final textEdit:cityscape.common.Languages.IWorkspaceTextEdit = cast item;
            if (JsValues.field(item, 'resource') == null) {
                return {applied: false, failureReason: 'File operations are not supported'};
            }
            final key = textEdit.resource.toString();
            final doc = openDocuments.get(key);
            final model = doc != null ? doc.model : context.modelService.getModel(textEdit.resource);
            if (model == null || model.isDisposed()) {
                return {applied: false, failureReason: 'No model for ' + key};
            }
            if (textEdit.versionId != null && textEdit.versionId != model.getVersionId()) {
                return {applied: false, failureReason: 'Version mismatch for ' + key};
            }
            var index = models.indexOf(model);
            if (index < 0) {
                index = models.length;
                models.push(model);
                operations.push([]);
            }
            operations[index].push({range: Range.lift(textEdit.textEdit.range), text: textEdit.textEdit.text});
        }
        for (i in 0...models.length) {
            models[i].pushEditOperations(null, operations[i], _ -> null);
        }
        return {applied: true};
    }

    function reportError(message:String, error:Dynamic):Void {
        if (onError != null) {
            onError(message, error);
        }
    }

    //#endregion

    //#region diagnostics

    function publishDiagnostics(params:Dynamic):Void {
        final uriString = LspConversions.asString(params.uri);
        if (uriString == null) {
            return;
        }
        var doc = openDocuments.get(uriString);
        final uri = doc != null ? doc.model.uri : Uri.parse(uriString);
        final key = uri.toString();
        if (doc == null) {
            doc = openDocuments.get(key);
        }
        final resource = doc != null ? doc.model.uri : uri;
        final list = LspConversions.asArray(params.diagnostics);
        if (list == null || list.length == 0) {
            diagnostics.remove(key);
            context.markerService.changeOne(markerOwner, resource, []);
        }
        else {
            diagnostics.set(key, list);
            context.markerService.changeOne(markerOwner, resource, [for (d in list) LspConversions.toMarkerData(d)]);
        }
    }

    /**
     * The last LSP diagnostics the server published for a resource.
     */
    public function getDiagnostics(uri:Uri):Array<Dynamic> {
        final list = diagnostics.get(uri.toString());
        return list != null ? list.copy() : [];
    }

    /**
     * The original LSP diagnostics for a code action request: the ones
     * matching `markers` (same message and range; markers of other owners
     * match none), or, when `markers` is null, the ones touching `range`.
     */
    public function findDiagnostics(model:ITextModel, markers:Null<Array<IMarkerData>>, range:IRange):Array<Dynamic> {
        final stored = diagnostics.get(model.uri.toString());
        final result:Array<Dynamic> = [];
        if (stored == null) {
            return result;
        }
        if (markers == null) {
            for (d in stored) {
                if (Range.areIntersectingOrTouching(LspConversions.fromLspRange(d.range), range)) {
                    result.push(d);
                }
            }
            return result;
        }
        for (marker in markers) {
            var found:Dynamic = null;
            for (d in stored) {
                if (result.indexOf(d) < 0 && LspConversions.markerMatchesDiagnostic(marker, d, false)) {
                    found = d;
                    break;
                }
            }
            if (found == null) {
                for (d in stored) {
                    if (result.indexOf(d) < 0 && LspConversions.markerMatchesDiagnostic(marker, d, true)) {
                        found = d;
                        break;
                    }
                }
            }
            if (found != null) {
                result.push(found);
            }
        }
        return result;
    }

    //#endregion

    //#region documents

    /**
     * Synchronizes a model that the model service of the context does not
     * know (created with `new TextModel(...)`): it is opened on the server
     * when its language matches (now, or once the client is ready), and
     * followed until it is disposed or given to `closeModel`.
     */
    public function openModel(model:ITextModel):Void {
        if (isDisposed) {
            return;
        }
        if (!isReady) {
            if (manualModels.indexOf(model) < 0) {
                manualModels.push(model);
            }
            return;
        }
        trackModel(model);
    }

    /**
     * Stops synchronizing a model: `didClose` when it was open.
     */
    public function closeModel(model:ITextModel):Void {
        manualModels.remove(model);
        untrackModel(model);
    }

    /**
     * Whether a model is open on the server.
     */
    public function isModelOpen(model:ITextModel):Bool {
        final doc = openDocuments.get(model.uri.toString());
        return doc != null && doc.model == model;
    }

    /**
     * Makes sure a model a provider is asked about is synchronized (opened
     * when its language matches and it was not yet).
     */
    public function syncModel(model:ITextModel):Void {
        if (isReady && !trackedModels.exists(model.id)) {
            trackModel(model);
        }
    }

    /**
     * The `TextDocumentIdentifier` of a model.
     */
    public function textDocumentIdentifier(model:ITextModel):Dynamic {
        return {uri: model.uri.toString()};
    }

    /**
     * Whether a model is synchronized with this server (its language).
     */
    public function matchesModel(model:ITextModel):Bool {
        if (!ModelUtils.shouldSynchronizeModel(model)) {
            return false;
        }
        return languageIds.indexOf('*') >= 0 || languageIds.indexOf(model.getLanguageId()) >= 0;
    }

    function listenToModels():Void {
        listeners.add(context.modelService.onModelAdded(model -> trackModel(model)));
        listeners.add(context.modelService.onModelRemoved(model -> untrackModel(model)));
        for (model in context.modelService.getModels()) {
            trackModel(model);
        }
        final manual = manualModels.copy();
        manualModels.resize(0);
        for (model in manual) {
            trackModel(model);
        }
    }

    function trackModel(model:ITextModel):Void {
        if (isDisposed || model.isDisposed() || trackedModels.exists(model.id)) {
            return;
        }
        final tracked = new TrackedModel(model);
        trackedModels.set(model.id, tracked);
        tracked.store.add(model.onDidChangeLanguage(_ -> onModelLanguageChanged(model)));
        tracked.store.add(model.onWillDispose(() -> untrackModel(model)));
        if (matchesModel(model)) {
            openDocument(model);
        }
    }

    function untrackModel(model:ITextModel):Void {
        closeDocument(model);
        final tracked = trackedModels.get(model.id);
        if (tracked != null && tracked.model == model) {
            trackedModels.remove(model.id);
            tracked.store.dispose();
        }
    }

    function onModelLanguageChanged(model:ITextModel):Void {
        closeDocument(model);
        if (matchesModel(model)) {
            openDocument(model);
        }
    }

    function openDocument(model:ITextModel):Void {
        if (!isReady) {
            return;
        }
        final uri = model.uri.toString();
        if (openDocuments.exists(uri)) {
            return;
        }
        final doc = new OpenDocument(model, uri, model.getLanguageId(), model.getVersionId());
        openDocuments.set(uri, doc);
        if (openClose) {
            sendNotification('textDocument/didOpen', {
                textDocument: {
                    uri: uri,
                    languageId: doc.languageId,
                    version: doc.version,
                    text: model.getValue()
                }
            });
        }
        doc.contentListener = model.onDidChangeContent(e -> onContentChanged(doc, e));
    }

    function closeDocument(model:ITextModel):Void {
        final uri = model.uri.toString();
        final doc = openDocuments.get(uri);
        if (doc == null || doc.model != model) {
            return;
        }
        openDocuments.remove(uri);
        doc.dispose();
        if (openClose) {
            sendNotification('textDocument/didClose', {textDocument: {uri: uri}});
        }
    }

    /**
     * Sends a change of a model. Monaco gives the changes of one event
     * sorted from the end of the document to its start, each relative to
     * the text before the event; LSP applies the changes of a
     * `didChange` in order, each relative to the result of the previous
     * one. Applied from the end, a change never moves the text of the
     * changes after it in the list, so Monaco's list is sent as it is (like
     * vscode's extension host does). A flush (`setValue`) or an event
     * without changes (end of line change) sends the full text.
     */
    function onContentChanged(doc:OpenDocument, e:IModelContentChangedEvent):Void {
        if (syncKind == 0 || isDisposed) {
            return;
        }
        doc.version = e.versionId;
        final contentChanges:Array<Dynamic> = [];
        if (syncKind == 1 || e.isFlush || e.changes.length == 0) {
            contentChanges.push({text: doc.model.getValue()});
        }
        else {
            for (change in e.changes) {
                contentChanges.push({
                    range: LspConversions.toLspRange(change.range),
                    rangeLength: change.rangeLength,
                    text: change.text
                });
            }
        }
        sendNotification('textDocument/didChange', {
            textDocument: {uri: doc.uri, version: e.versionId},
            contentChanges: contentChanges
        });
    }

    //#endregion

    //#region providers and commands

    static function isEnabled(capability:Dynamic):Bool {
        if (capability == null) {
            return false;
        }
        if (JsValues.isBoolean(capability)) {
            return (capability : Bool);
        }
        return true;
    }

    /**
     * The language selector of the providers (`languageIds`).
     */
    public function languageSelector():LanguageSelector {
        final ids:Array<String> = languageIds.copy();
        return cast ids;
    }

    /**
     * Whether the provider of a server capability is registered
     * (`LspClientOptions.registerProviders`).
     */
    public function registersProvider(capability:String):Bool {
        final option:Dynamic = options.registerProviders;
        if (option == null) {
            return true;
        }
        if (Std.isOfType(option, Bool)) {
            final enabled:Bool = option;
            return enabled;
        }
        final list = LspConversions.asArray(option);
        if (list == null) {
            return true;
        }
        for (item in list) {
            if (LspConversions.asString(item) == capability) {
                return true;
            }
        }
        return false;
    }

    function registerProviders():Void {
        final serverCaps:Dynamic = serverCapabilities;
        // the capabilities of the features the host leaves to the client
        final caps:Dynamic = {};
        for (field in Reflect.fields(serverCaps)) {
            if (StringTools.endsWith(field, 'Provider') && !registersProvider(field)) {
                continue;
            }
            Reflect.setField(caps, field, Reflect.field(serverCaps, field));
        }
        final selector = languageSelector();
        if (isEnabled(caps.completionProvider)) {
            registrations.add(context.registerCompletionItemProvider(selector, new LspCompletionProvider(this, caps.completionProvider)));
        }
        if (isEnabled(caps.hoverProvider)) {
            registrations.add(context.registerHoverProvider(selector, new LspHoverProvider(this)));
        }
        if (isEnabled(caps.definitionProvider)) {
            registrations.add(context.registerDefinitionProvider(selector, new LspDefinitionProvider(this)));
        }
        if (isEnabled(caps.documentSymbolProvider)) {
            registrations.add(context.registerDocumentSymbolProvider(selector, new LspDocumentSymbolProvider(this)));
        }
        if (isEnabled(caps.codeActionProvider)) {
            final provider = new LspCodeActionProvider(this, caps.codeActionProvider);
            registrations.add(context.registerCodeActionProvider(selector, provider, {providedCodeActionKinds: provider.providedCodeActionKinds}));
        }
        if (isEnabled(caps.signatureHelpProvider)) {
            registrations.add(context.registerSignatureHelpProvider(selector, new LspSignatureHelpProvider(this, caps.signatureHelpProvider)));
        }
        if (isEnabled(caps.documentFormattingProvider)) {
            registrations.add(context.registerDocumentFormattingEditProvider(selector, new LspDocumentFormattingProvider(this)));
        }
        if (isEnabled(caps.documentRangeFormattingProvider)) {
            registrations.add(context.registerDocumentRangeFormattingEditProvider(selector, new LspDocumentRangeFormattingProvider(this)));
        }
    }

    /**
     * Registers the commands of the server's `executeCommandProvider` in
     * the context: running one sends `workspace/executeCommand` with the
     * arguments of the command.
     */
    function registerCommands():Void {
        final provider:Dynamic = serverCapabilities.executeCommandProvider;
        if (provider == null || !registersProvider('executeCommandProvider')) {
            return;
        }
        final commands = LspConversions.asArray(provider.commands);
        if (commands == null) {
            return;
        }
        for (command in commands) {
            final id = LspConversions.asString(command);
            if (id == null) {
                continue;
            }
            registrations.add(context.commandsRegistry.registerCommandHandler(id, (_, args) -> executeCommand(id, args)));
        }
    }

    //#endregion

}
