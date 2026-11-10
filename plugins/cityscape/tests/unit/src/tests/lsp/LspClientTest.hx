// New code for Cityscape (not a port): tests of the LSP client against a
// small fake language server running in process.
package tests.lsp;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationTokenSource;
import cityscape.base.common.Cancellation.CancellationTokens;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.base.common.Uri;
import cityscape.common.Languages.CodeActionList;
import cityscape.common.Languages.CodeActionTriggerType;
import cityscape.common.Languages.CompletionItem;
import cityscape.common.Languages.CompletionItemInsertTextRule;
import cityscape.common.Languages.CompletionItemTag;
import cityscape.common.Languages.CompletionList;
import cityscape.common.Languages.CompletionTriggerKind;
import cityscape.common.Languages.Definition;
import cityscape.common.Languages.DocumentSymbol;
import cityscape.common.Languages.Hover;
import cityscape.common.Languages.IWorkspaceTextEdit;
import cityscape.common.Languages.SignatureHelpResult;
import cityscape.common.Languages.SignatureHelpTriggerKind;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.lsp.InProcessTransport;
import cityscape.lsp.LspClient;
import cityscape.lsp.LspInProcessServer;
import cityscape.platform.markers.common.Markers.IMarker;
import cityscape.platform.markers.common.Markers.MarkerSeverity;
import cityscape.platform.markers.common.Markers.MarkerTag;
import testing.TestCase;

/**
 * A fake language server: records the messages it receives, keeps the text
 * of the open documents (applying the changes like a real server, to check
 * the incremental synchronization), and answers the requests with fixed
 * results. With `deferred`, it answers the requests (except `initialize`
 * and `shutdown`) only when `flush` is called.
 */
class FakeLspServer implements LspInProcessServer {

    public var onNotification:Null<(notification:Dynamic) -> Void> = null;

    /**
     * The messages received, in order.
     */
    public final received:Array<Dynamic> = [];

    /**
     * The text of the open documents, by uri.
     */
    public final documents:Map<String, String> = new Map();

    /**
     * The responses of the client to the requests of the server, by id.
     */
    public final clientResponses:Map<String, Dynamic> = new Map();

    /**
     * `textDocumentSync` declared by `initialize`.
     */
    public var textDocumentSync:Dynamic = 2;

    public var deferred:Bool = false;

    /**
     * Results replacing the fixed ones, by method (a null value answers
     * null).
     */
    public final overrides:Map<String, Dynamic> = new Map();

    /**
     * Errors answering the requests of a method, by method.
     */
    public final errors:Map<String, Dynamic> = new Map();

    final later:Array<() -> Void> = [];

    var nextServerRequestId:Int = 1;

    public function new() {}

    public function messagesOf(method:String):Array<Dynamic> {
        return [for (m in received) if (m.method == method) m];
    }

    public function lastOf(method:String):Dynamic {
        final list = messagesOf(method);
        return list.length > 0 ? list[list.length - 1] : null;
    }

    /**
     * Answers the deferred requests.
     */
    public function flush():Void {
        final pending = later.copy();
        later.resize(0);
        for (answer in pending) {
            answer();
        }
    }

    public function notify(method:String, params:Dynamic):Void {
        if (onNotification != null) {
            onNotification({jsonrpc: '2.0', method: method, params: params});
        }
    }

    public function publish(uri:String, diagnostics:Array<Dynamic>):Void {
        notify('textDocument/publishDiagnostics', {uri: uri, diagnostics: diagnostics});
    }

    /**
     * Sends a request to the client; returns its id (a string, to check
     * that the client keeps ids as they are).
     */
    public function requestClient(method:String, params:Dynamic):String {
        final id = 'srv' + (nextServerRequestId++);
        if (onNotification != null) {
            onNotification({jsonrpc: '2.0', id: id, method: method, params: params});
        }
        return id;
    }

    public function handleMessage(message:Dynamic, onResponse:(response:Dynamic) -> Void):Void {
        received.push(message);
        final method:Null<String> = message.method;
        if (method == null) {
            clientResponses.set(Std.string(message.id), message);
            return;
        }
        if (message.id == null) {
            handleNotification(method, message.params);
            return;
        }
        final id:Dynamic = message.id;
        final params:Dynamic = message.params;
        final answer = () -> {
            switch method {
                case 'fake/unknown':
                    onResponse({jsonrpc: '2.0', id: id, error: {code: -32601, message: 'Unknown method'}});
                case _ if (errors.exists(method)):
                    onResponse({jsonrpc: '2.0', id: id, error: errors.get(method)});
                case _ if (overrides.exists(method)):
                    onResponse({jsonrpc: '2.0', id: id, result: overrides.get(method)});
                case _:
                    onResponse({jsonrpc: '2.0', id: id, result: resultOf(method, params)});
            }
        };
        if (deferred && method != 'initialize' && method != 'shutdown') {
            later.push(answer);
        }
        else {
            answer();
        }
    }

    function handleNotification(method:String, params:Dynamic):Void {
        switch method {
            case 'textDocument/didOpen':
                documents.set(params.textDocument.uri, params.textDocument.text);
            case 'textDocument/didChange':
                final uri:String = params.textDocument.uri;
                var text = documents.get(uri);
                final changes:Array<Dynamic> = params.contentChanges;
                for (change in changes) {
                    if (change.range == null) {
                        text = change.text;
                    }
                    else {
                        final start = offsetAt(text, change.range.start);
                        final end = offsetAt(text, change.range.end);
                        text = text.substring(0, start) + change.text + text.substring(end);
                    }
                }
                documents.set(uri, text);
            case 'textDocument/didClose':
                documents.remove(params.textDocument.uri);
            case _:
        }
    }

    static function offsetAt(text:String, position:Dynamic):Int {
        final line:Int = position.line;
        final character:Int = position.character;
        var offset = 0;
        for (i in 0...line) {
            final next = text.indexOf('\n', offset);
            if (next < 0) {
                return text.length;
            }
            offset = next + 1;
        }
        return offset + character;
    }

    static function range(startLine:Int, startCharacter:Int, endLine:Int, endCharacter:Int):Dynamic {
        return {start: {line: startLine, character: startCharacter}, end: {line: endLine, character: endCharacter}};
    }

    function resultOf(method:String, params:Dynamic):Dynamic {
        return switch method {
            case 'initialize':
                {
                    capabilities: {
                        textDocumentSync: textDocumentSync,
                        completionProvider: {triggerCharacters: ['.'], resolveProvider: true},
                        hoverProvider: true,
                        definitionProvider: true,
                        documentSymbolProvider: true,
                        codeActionProvider: {codeActionKinds: ['quickfix']},
                        signatureHelpProvider: {triggerCharacters: ['(', ','], retriggerCharacters: [')']},
                        documentFormattingProvider: true,
                        documentRangeFormattingProvider: true,
                        documentOnTypeFormattingProvider: {firstTriggerCharacter: '}', moreTriggerCharacter: [';']},
                        declarationProvider: true,
                        typeDefinitionProvider: true,
                        implementationProvider: true,
                        referencesProvider: true,
                        documentHighlightProvider: true,
                        renameProvider: {prepareProvider: true},
                        foldingRangeProvider: true,
                        selectionRangeProvider: true,
                        inlayHintProvider: {resolveProvider: true},
                        codeLensProvider: {resolveProvider: true},
                        semanticTokensProvider: {
                            legend: {tokenTypes: ['variable', 'function'], tokenModifiers: ['declaration']},
                            full: {delta: true},
                            range: true
                        },
                        documentLinkProvider: {resolveProvider: true},
                        colorProvider: true,
                        executeCommandProvider: {commands: ['fake.run']}
                    },
                    serverInfo: {name: 'fake'}
                };
            case 'textDocument/completion':
                {
                    isIncomplete: false,
                    items: ([
                        {label: 'alpha', kind: 3, detail: 'alpha()', insertText: "alpha($1)", insertTextFormat: 2, data: 1},
                        {label: 'beta', kind: 6, textEdit: {range: range(0, 0, 0, 3), newText: 'betaValue'}, tags: [1], data: 2}
                    ] : Array<Dynamic>)
                };
            case 'completionItem/resolve':
                {
                    label: params.label,
                    kind: params.kind,
                    data: params.data,
                    documentation: {kind: 'markdown', value: 'Docs for ' + params.label}
                };
            case 'textDocument/hover':
                {contents: {kind: 'markdown', value: '**hover**'}, range: range(0, 0, 0, 5)};
            case 'textDocument/definition':
                {uri: 'file:///other.fake', range: range(3, 2, 3, 8)};
            case 'textDocument/documentSymbol':
                [
                    {
                        name: 'Outer',
                        kind: 5,
                        range: range(0, 0, 1, 7),
                        selectionRange: range(0, 4, 0, 9),
                        children: [
                            {name: 'inner', detail: '()', kind: 6, range: range(1, 0, 1, 7), selectionRange: range(1, 0, 1, 3)}
                        ]
                    }
                ];
            case 'textDocument/codeAction':
                final changes:Dynamic = {};
                Reflect.setField(changes, params.textDocument.uri, [{range: range(0, 0, 0, 3), newText: 'fixed'}]);
                ([
                    {
                        title: 'Fix it',
                        kind: 'quickfix',
                        isPreferred: true,
                        diagnostics: params.context.diagnostics,
                        edit: {changes: changes}
                    },
                    {title: 'Run it', command: 'fake.run', arguments: ['x']}
                ] : Array<Dynamic>);
            case 'textDocument/signatureHelp':
                {
                    signatures: [
                        {label: 'f(a, b)', documentation: 'Calls f', parameters: ([{label: [2, 3]}, {label: 'b'}] : Array<Dynamic>)}
                    ],
                    activeSignature: 0,
                    activeParameter: 1
                };
            case 'textDocument/formatting' | 'textDocument/rangeFormatting':
                [{range: range(0, 0, 0, 0), newText: '  '}];
            case 'fake/echo':
                params;
            case 'textDocument/references':
                ([
                    {uri: params.textDocument.uri, range: range(0, 0, 0, 3)},
                    {uri: 'file:///other.fake', range: range(2, 1, 2, 4)}
                ] : Array<Dynamic>);
            case 'textDocument/documentHighlight':
                ([
                    {range: range(0, 0, 0, 3), kind: 1},
                    {range: range(0, 4, 0, 7), kind: 2},
                    {range: range(1, 0, 1, 3), kind: 3},
                    {range: range(1, 4, 1, 5)}
                ] : Array<Dynamic>);
            case 'textDocument/prepareRename':
                {range: range(0, 0, 0, 3), placeholder: 'foo'};
            case 'textDocument/rename':
                {
                    documentChanges: [
                        {textDocument: {uri: params.textDocument.uri, version: 1}, edits: [{range: range(0, 0, 0, 3), newText: params.newName}]}
                    ]
                };
            case 'textDocument/foldingRange':
                ([
                    {startLine: 0, endLine: 2, kind: 'region'},
                    {startLine: 3, endLine: 5, kind: 'other'},
                    {startLine: 1, endLine: 2, kind: 'comment'},
                    {startLine: 4, endLine: 5}
                ] : Array<Dynamic>);
            case 'textDocument/selectionRange':
                final positions:Array<Dynamic> = params.positions;
                [for (p in positions) ({
                    range: range(p.line, p.character, p.line, p.character + 1),
                    parent: {range: range(p.line, 0, p.line, 9), parent: {range: range(0, 0, 3, 0)}}
                } : Dynamic)];
            case 'textDocument/inlayHint':
                ([
                    {position: {line: 0, character: 4}, label: 'a:', kind: 2, paddingRight: true, data: 1},
                    {
                        position: {line: 1, character: 2},
                        label: ([
                            {
                                value: 'Int',
                                tooltip: {kind: 'plaintext', value: 'a*b'},
                                location: {uri: params.textDocument.uri, range: range(0, 0, 0, 3)},
                                command: {title: 'Show', command: 'editor.action.showReferences', arguments: ([params.textDocument.uri, {line: 0, character: 0}, ([{uri: params.textDocument.uri, range: range(0, 0, 0, 3)}] : Array<Dynamic>)] : Array<Dynamic>)}
                            }
                        ] : Array<Dynamic>),
                        kind: 1,
                        tooltip: 'hint',
                        textEdits: [{range: range(1, 2, 1, 2), newText: ':Int'}]
                    },
                    {position: {line: 2, character: 0}, label: ''},
                    {position: {line: 2, character: 0}, label: ([] : Array<Dynamic>)}
                ] : Array<Dynamic>);
            case 'inlayHint/resolve':
                {position: params.position, label: params.label, kind: params.kind, data: params.data, tooltip: {kind: 'markdown', value: '**resolved**'}};
            case 'textDocument/codeLens':
                ([
                    {range: range(0, 0, 0, 3), command: {title: "$(play) Run", command: 'fake.run', arguments: ['x']}},
                    {range: range(1, 0, 1, 3), data: 7}
                ] : Array<Dynamic>);
            case 'codeLens/resolve':
                {
                    range: params.range,
                    data: params.data,
                    command: {
                        title: '2 references',
                        command: 'editor.action.showReferences',
                        arguments: ([
                            'file:///a.fake',
                            {line: 1, character: 0},
                            ([
                                {uri: 'file:///a.fake', range: range(0, 0, 0, 3)},
                                {targetUri: 'file:///b.fake', targetRange: range(2, 0, 2, 5), targetSelectionRange: range(2, 0, 2, 3)}
                            ] : Array<Dynamic>)
                        ] : Array<Dynamic>)
                    }
                };
            case 'textDocument/semanticTokens/full':
                {resultId: 'r1', data: [0, 0, 3, 0, 1, 1, 0, 3, 1, 0]};
            case 'textDocument/semanticTokens/full/delta':
                {resultId: 'r2', edits: [{start: 0, deleteCount: 5, data: [0, 1, 2, 1, 0]}, {start: 10, deleteCount: 0}]};
            case 'textDocument/semanticTokens/range':
                {data: [0, 0, 3, 1, 0]};
            case 'textDocument/declaration':
                [{targetUri: 'file:///decl.fake', targetRange: range(1, 0, 3, 0), targetSelectionRange: range(1, 4, 1, 7), originSelectionRange: range(0, 0, 0, 3)}];
            case 'textDocument/typeDefinition':
                {uri: 'file:///type.fake', range: range(5, 0, 5, 4)};
            case 'textDocument/implementation':
                [{uri: 'file:///impl.fake', range: range(2, 2, 2, 6)}, {uri: 'file:///impl2.fake', range: range(0, 0, 0, 1)}];
            case 'textDocument/documentLink':
                ([
                    {range: range(0, 0, 0, 4), target: 'https://example.com/a', tooltip: 'Open'},
                    {range: range(1, 0, 1, 2), data: 9}
                ] : Array<Dynamic>);
            case 'documentLink/resolve':
                {range: params.range, target: 'file:///resolved.fake', data: params.data};
            case 'textDocument/documentColor':
                [{range: range(0, 0, 0, 7), color: {red: 1, green: 0.5, blue: 0, alpha: 1}}];
            case 'textDocument/colorPresentation':
                ([
                    {label: '#ff8000', textEdit: {range: params.range, newText: '#ff8000'}, additionalTextEdits: [{range: range(0, 0, 0, 0), newText: 'use color;\n'}]},
                    {label: 'rgb(255, 128, 0)'}
                ] : Array<Dynamic>);
            case 'textDocument/onTypeFormatting':
                [{range: range(params.position.line, 0, params.position.line, 0), newText: '  '}];
            case _:
                null;
        }
    }

}

/**
 * Tests of `cityscape.lsp.LspClient`: the handshake, the synchronization of
 * the models, the diagnostics, each provider (called through the registries
 * of the context), cancellation, custom messages and disposal.
 */
class LspClientTest extends TestCase {

    static inline final URI_A = 'file:///a.fake';

    static function newContext():Cityscape {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'fakelang'});
        context.languageService.registerLanguage({id: 'otherlang'});
        return context;
    }

    static function newClient(context:Cityscape, server:FakeLspServer):LspClient {
        return new LspClient(context, new InProcessTransport(server), {languageIds: ['fakelang'], rootUri: 'file:///project'});
    }

    static function lspRange(startLine:Int, startCharacter:Int, endLine:Int, endCharacter:Int):Dynamic {
        return {start: {line: startLine, character: startCharacter}, end: {line: endLine, character: endCharacter}};
    }

    function assertRange(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, range:Dynamic, ?pos:haxe.PosInfos):Void {
        assertNotNull(range, 'range', pos);
        if (range != null) {
            assertDeepEquals({startLineNumber: startLineNumber, startColumn: startColumn, endLineNumber: endLineNumber, endColumn: endColumn}, {
                startLineNumber: range.startLineNumber,
                startColumn: range.startColumn,
                endLineNumber: range.endLineNumber,
                endColumn: range.endColumn
            }, 'range', pos);
        }
    }

    function assertLspRange(startLine:Int, startCharacter:Int, endLine:Int, endCharacter:Int, range:Dynamic, ?pos:haxe.PosInfos):Void {
        assertDeepEquals(lspRange(startLine, startCharacter, endLine, endCharacter), range, 'LSP range', pos);
    }

    /**
     * A started client with a `fakelang` model at `URI_A`.
     */
    function startWithModel(text:String):{context:Cityscape, server:FakeLspServer, client:LspClient, model:TextModel} {
        final context = newContext();
        final server = new FakeLspServer();
        final model = context.modelService.createModel(text, 'fakelang', Uri.parse(URI_A));
        final client = newClient(context, server);
        client.start();
        return {context: context, server: server, client: client, model: model};
    }

    //#region handshake

    function testInitializeHandshake() {
        final context = newContext();
        final server = new FakeLspServer();
        final client = newClient(context, server);
        var ready = 0;
        client.start(() -> ready++);

        assertEquals(1, ready);
        assertTrue(client.isReady);
        assertTrue(server.received.length >= 2);
        final initialize:Dynamic = server.received[0];
        assertEquals('initialize', initialize.method);
        assertEquals('2.0', initialize.jsonrpc);
        assertNotNull(initialize.id);
        final params:Dynamic = initialize.params;
        assertNull(params.processId);
        assertEquals('file:///project', params.rootUri);
        assertEquals('file:///project', params.workspaceFolders[0].uri);
        assertEquals('project', params.workspaceFolders[0].name);
        final textDocument:Dynamic = params.capabilities.textDocument;
        assertEquals(true, textDocument.completion.completionItem.snippetSupport);
        assertDeepEquals(['markdown', 'plaintext'], textDocument.hover.contentFormat);
        assertEquals(true, textDocument.definition.linkSupport);
        assertEquals(true, textDocument.documentSymbol.hierarchicalDocumentSymbolSupport);
        assertNotNull(textDocument.codeAction.codeActionLiteralSupport);
        assertNotNull(textDocument.signatureHelp);
        assertNotNull(textDocument.formatting);
        assertNotNull(textDocument.rangeFormatting);
        assertNotNull(textDocument.publishDiagnostics);
        assertEquals(false, textDocument.synchronization.didSave);

        assertEquals('initialized', server.received[1].method);
        assertNull(server.received[1].id);
        assertEquals(2, client.getSyncKind());
        assertEquals('fake', client.serverInfo.name);
        client.dispose();
    }

    function testInitializeFailure() {
        final context = newContext();
        // a server answering initialize with an error
        final failing = new FailingServer();
        final failingClient = new LspClient(context, new InProcessTransport(failing), {languageIds: ['fakelang']});
        var ready = false;
        var errorMessage:Null<String> = null;
        failingClient.onError = (message, _) -> errorMessage = message;
        failingClient.start(() -> ready = true);
        assertFalse(ready);
        assertFalse(failingClient.isReady);
        assertEquals('initialize failed', errorMessage);
        failingClient.dispose();
    }

    //#endregion

    //#region document synchronization

    function testDidOpenForMatchingModels() {
        final context = newContext();
        final server = new FakeLspServer();
        final before = context.modelService.createModel('hello', 'fakelang', Uri.parse(URI_A));
        context.modelService.createModel('other', 'otherlang', Uri.parse('file:///b.other'));
        final client = newClient(context, server);
        client.start();

        var opens = server.messagesOf('textDocument/didOpen');
        assertEquals(1, opens.length);
        final doc:Dynamic = opens[0].params.textDocument;
        assertEquals(URI_A, doc.uri);
        assertEquals('fakelang', doc.languageId);
        assertEquals(before.getVersionId(), doc.version);
        assertEquals('hello', doc.text);
        assertTrue(client.isModelOpen(before));

        // a model created after start
        final after = context.modelService.createModel('second', 'fakelang', Uri.parse('file:///c.fake'));
        opens = server.messagesOf('textDocument/didOpen');
        assertEquals(2, opens.length);
        assertEquals('file:///c.fake', opens[1].params.textDocument.uri);
        assertEquals('second', opens[1].params.textDocument.text);

        // another language after start
        context.modelService.createModel('x', 'otherlang', Uri.parse('file:///d.other'));
        assertEquals(2, server.messagesOf('textDocument/didOpen').length);

        // a model created without the model service
        final manual = new TextModel('manual', 'fakelang', TextModel.DEFAULT_CREATION_OPTIONS, Uri.parse('file:///e.fake'), context);
        assertEquals(2, server.messagesOf('textDocument/didOpen').length);
        client.openModel(manual);
        opens = server.messagesOf('textDocument/didOpen');
        assertEquals(3, opens.length);
        assertEquals('file:///e.fake', opens[2].params.textDocument.uri);
        assertEquals('manual', server.documents.get('file:///e.fake'));

        manual.dispose();
        final closes = server.messagesOf('textDocument/didClose');
        assertEquals(1, closes.length);
        assertEquals('file:///e.fake', closes[0].params.textDocument.uri);
        assertFalse(server.documents.exists('file:///e.fake'));

        after.dispose();
        assertEquals(2, server.messagesOf('textDocument/didClose').length);
        client.dispose();
    }

    function testOpenModelBeforeStart() {
        final context = newContext();
        final server = new FakeLspServer();
        final client = newClient(context, server);
        final manual = new TextModel('early', 'fakelang', TextModel.DEFAULT_CREATION_OPTIONS, Uri.parse('file:///early.fake'), context);
        client.openModel(manual);
        assertEquals(0, server.received.length);
        client.start();
        final opens = server.messagesOf('textDocument/didOpen');
        assertEquals(1, opens.length);
        assertEquals('file:///early.fake', opens[0].params.textDocument.uri);
        client.dispose();
        manual.dispose();
    }

    function testDidChangeIncremental() {
        final setup = startWithModel('hello world\nsecond line');
        final server = setup.server;
        final model = setup.model;
        final version0 = model.getVersionId();

        model.applyEdits([{range: new Range(1, 7, 1, 12), text: 'there'}]);
        var change:Dynamic = server.lastOf('textDocument/didChange');
        assertNotNull(change);
        assertEquals(URI_A, change.params.textDocument.uri);
        final version1:Int = change.params.textDocument.version;
        assertEquals(model.getVersionId(), version1);
        assertTrue(version1 > version0);
        var contentChanges:Array<Dynamic> = change.params.contentChanges;
        assertEquals(1, contentChanges.length);
        assertLspRange(0, 6, 0, 11, contentChanges[0].range);
        assertEquals(5, contentChanges[0].rangeLength);
        assertEquals('there', contentChanges[0].text);
        assertEquals(model.getValue(), server.documents.get(URI_A));

        // several edits in one event: Monaco sorts them from the end, which
        // LSP can apply in order
        model.applyEdits([{range: new Range(1, 1, 1, 1), text: 'A'}, {range: new Range(2, 1, 2, 1), text: 'B'}]);
        change = server.lastOf('textDocument/didChange');
        contentChanges = change.params.contentChanges;
        assertEquals(2, contentChanges.length);
        assertEquals(1, contentChanges[0].range.start.line);
        assertEquals(0, contentChanges[1].range.start.line);
        final version2:Int = change.params.textDocument.version;
        assertTrue(version2 > version1);
        assertEquals(model.getValue(), server.documents.get(URI_A));

        // a multi-line deletion and a multi-line insertion
        model.applyEdits([{range: new Range(1, 3, 2, 4), text: ''}]);
        assertEquals(model.getValue(), server.documents.get(URI_A));
        model.applyEdits([{range: new Range(1, 2, 1, 2), text: 'x\ny\nz'}]);
        assertEquals(model.getValue(), server.documents.get(URI_A));

        // setValue sends the full text
        model.setValue('new text');
        change = server.lastOf('textDocument/didChange');
        contentChanges = change.params.contentChanges;
        assertEquals(1, contentChanges.length);
        assertFalse(Reflect.hasField(contentChanges[0], 'range'));
        assertEquals('new text', contentChanges[0].text);
        assertEquals(model.getVersionId(), change.params.textDocument.version);
        assertEquals('new text', server.documents.get(URI_A));
        setup.client.dispose();
    }

    function testDidChangeFull() {
        final context = newContext();
        final server = new FakeLspServer();
        server.textDocumentSync = {openClose: true, change: 1};
        final model = context.modelService.createModel('abc', 'fakelang', Uri.parse(URI_A));
        final client = newClient(context, server);
        client.start();
        assertEquals(1, client.getSyncKind());
        model.applyEdits([{range: new Range(1, 2, 1, 3), text: 'X'}]);
        final change:Dynamic = server.lastOf('textDocument/didChange');
        final contentChanges:Array<Dynamic> = change.params.contentChanges;
        assertEquals(1, contentChanges.length);
        assertFalse(Reflect.hasField(contentChanges[0], 'range'));
        assertEquals('aXc', contentChanges[0].text);
        assertEquals(model.getVersionId(), change.params.textDocument.version);
        client.dispose();
    }

    function testDidCloseAndLanguageChange() {
        final setup = startWithModel('text');
        final server = setup.server;
        final model = setup.model;

        model.setLanguage('otherlang');
        assertEquals(1, server.messagesOf('textDocument/didClose').length);
        assertFalse(setup.client.isModelOpen(model));
        model.applyEdits([{range: new Range(1, 1, 1, 1), text: 'x'}]);
        assertEquals(0, server.messagesOf('textDocument/didChange').length);

        model.setLanguage('fakelang');
        final opens = server.messagesOf('textDocument/didOpen');
        assertEquals(2, opens.length);
        assertEquals('xtext', opens[1].params.textDocument.text);
        assertEquals(model.getVersionId(), opens[1].params.textDocument.version);

        model.dispose();
        final closes = server.messagesOf('textDocument/didClose');
        assertEquals(2, closes.length);
        assertEquals(URI_A, closes[1].params.textDocument.uri);
        setup.client.dispose();
    }

    //#endregion

    //#region diagnostics

    static function markerWithMessage(markers:Array<IMarker>, message:String):Null<IMarker> {
        for (m in markers) {
            if (m.message == message) {
                return m;
            }
        }
        return null;
    }

    function testPublishDiagnostics() {
        final setup = startWithModel('some text here\nline two');
        final context = setup.context;
        final model = setup.model;

        setup.server.publish(URI_A, [
            {range: lspRange(0, 1, 0, 4), severity: 2, message: 'warn', source: 'fake', code: 42, tags: [1]},
            {range: lspRange(1, 0, 1, 4), message: 'err'},
            {range: lspRange(0, 5, 0, 9), severity: 3, message: 'info', code: 'X1', codeDescription: {href: 'https://example.com/X1'}, tags: [2]},
            {range: lspRange(1, 5, 1, 8), severity: 4, message: 'hint',
                relatedInformation: [{location: {uri: 'file:///rel.fake', range: lspRange(2, 0, 2, 1)}, message: 'related'}]}
        ]);

        final markers = context.markerService.read({resource: model.uri});
        assertEquals(4, markers.length);
        assertEquals(4, setup.client.getDiagnostics(model.uri).length);

        final warn = markerWithMessage(markers, 'warn');
        assertNotNull(warn);
        assertEquals('lsp', warn.owner);
        assertEquals((MarkerSeverity.Warning : Int), (warn.severity : Int));
        assertRange(1, 2, 1, 5, warn);
        assertEquals('fake', warn.source);
        assertEquals('42', warn.code);
        assertDeepEquals([(MarkerTag.Unnecessary : Int)], [for (t in warn.tags) (t : Int)]);

        final err = markerWithMessage(markers, 'err');
        assertEquals((MarkerSeverity.Error : Int), (err.severity : Int));
        assertRange(2, 1, 2, 5, err);
        assertNull(err.code);

        final info = markerWithMessage(markers, 'info');
        assertEquals((MarkerSeverity.Info : Int), (info.severity : Int));
        assertEquals('X1', JsValues.field(info.code, 'value'));
        final target:Uri = JsValues.field(info.code, 'target');
        assertEquals('https://example.com/X1', target.toString());
        assertDeepEquals([(MarkerTag.Deprecated : Int)], [for (t in info.tags) (t : Int)]);

        final hint = markerWithMessage(markers, 'hint');
        assertEquals((MarkerSeverity.Hint : Int), (hint.severity : Int));
        assertEquals(1, hint.relatedInformation.length);
        assertEquals('file:///rel.fake', hint.relatedInformation[0].resource.toString());
        assertEquals('related', hint.relatedInformation[0].message);
        assertRange(3, 1, 3, 2, hint.relatedInformation[0]);

        // an empty list clears them
        setup.server.publish(URI_A, []);
        assertEquals(0, context.markerService.read({resource: model.uri}).length);
        assertEquals(0, setup.client.getDiagnostics(model.uri).length);

        // dispose removes the markers of the client
        setup.server.publish(URI_A, [{range: lspRange(0, 0, 0, 1), message: 'again'}]);
        assertEquals(1, context.markerService.read({resource: model.uri}).length);
        setup.client.dispose();
        assertEquals(0, context.markerService.read({resource: model.uri}).length);
    }

    //#endregion

    //#region providers

    function testCompletion() {
        final setup = startWithModel('foo.bar');
        final model = setup.model;
        final providers = setup.context.languageFeaturesService.completionProvider.ordered(model);
        assertEquals(1, providers.length);
        final provider = providers[0];
        assertDeepEquals(['.'], provider.triggerCharacters);
        assertNotNull(provider.resolveCompletionItem);

        var list:Null<CompletionList> = null;
        provider.provideCompletionItems(model, new Position(1, 5), {triggerKind: CompletionTriggerKind.TriggerCharacter, triggerCharacter: '.'}, CancellationTokens.None, l -> list = l);

        final request:Dynamic = setup.server.lastOf('textDocument/completion');
        assertEquals(URI_A, request.params.textDocument.uri);
        assertDeepEquals({line: 0, character: 4}, request.params.position);
        assertEquals(2, request.params.context.triggerKind);
        assertEquals('.', request.params.context.triggerCharacter);

        assertNotNull(list);
        assertEquals(2, list.suggestions.length);
        assertFalse(list.incomplete == true);

        final alpha = list.suggestions[0];
        assertEquals('alpha', alpha.label);
        assertEquals((cityscape.common.languages.CompletionItemKind.Function : Int), (alpha.kind : Int));
        assertEquals('alpha()', alpha.detail);
        assertEquals("alpha($1)", alpha.insertText);
        assertEquals((CompletionItemInsertTextRule.InsertAsSnippet : Int), (alpha.insertTextRules : Int));
        assertNull(alpha.range);

        final beta = list.suggestions[1];
        assertEquals('beta', beta.label);
        assertEquals((cityscape.common.languages.CompletionItemKind.Variable : Int), (beta.kind : Int));
        assertEquals('betaValue', beta.insertText);
        assertNull(beta.insertTextRules);
        assertRange(1, 1, 1, 4, beta.range);
        assertDeepEquals([(CompletionItemTag.Deprecated : Int)], [for (t in beta.tags) (t : Int)]);

        // resolve sends the original item and adds the documentation
        var resolved:Null<CompletionItem> = null;
        final resolveFn = provider.resolveCompletionItem;
        resolveFn(alpha, CancellationTokens.None, r -> resolved = r);
        final resolveRequest:Dynamic = setup.server.lastOf('completionItem/resolve');
        assertEquals('alpha', resolveRequest.params.label);
        assertEquals(1, resolveRequest.params.data);
        assertNotNull(resolved);
        final documentation:IMarkdownString = cast resolved.documentation;
        assertEquals('Docs for alpha', documentation.value);
        setup.client.dispose();
    }

    function testHover() {
        final setup = startWithModel('hello world');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.hoverProvider.ordered(model)[0];
        var hover:Null<Hover> = null;
        provider.provideHover(model, new Position(1, 2), CancellationTokens.None, null, h -> hover = h);
        final request:Dynamic = setup.server.lastOf('textDocument/hover');
        assertDeepEquals({line: 0, character: 1}, request.params.position);
        assertNotNull(hover);
        assertEquals(1, hover.contents.length);
        assertEquals('**hover**', hover.contents[0].value);
        assertRange(1, 1, 1, 6, hover.range);
        setup.client.dispose();
    }

    function testDefinition() {
        final setup = startWithModel('use thing');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.definitionProvider.ordered(model)[0];
        var definition:Null<Definition> = null;
        provider.provideDefinition(model, new Position(1, 6), CancellationTokens.None, d -> definition = d);
        final request:Dynamic = setup.server.lastOf('textDocument/definition');
        assertDeepEquals({line: 0, character: 5}, request.params.position);
        assertNotNull(definition);
        assertEquals(1, definition.length);
        assertEquals('file:///other.fake', definition[0].uri.toString());
        assertRange(4, 3, 4, 9, definition[0].range);
        setup.client.dispose();
    }

    function testDocumentSymbols() {
        final setup = startWithModel('class Outer\ninner()');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.documentSymbolProvider.ordered(model)[0];
        var symbols:Null<Array<DocumentSymbol>> = null;
        provider.provideDocumentSymbols(model, CancellationTokens.None, s -> symbols = s);
        assertNotNull(symbols);
        assertEquals(1, symbols.length);
        final outer = symbols[0];
        assertEquals('Outer', outer.name);
        assertEquals('', outer.detail);
        assertEquals((cityscape.common.SymbolKind.Class : Int), (outer.kind : Int));
        assertRange(1, 1, 2, 8, outer.range);
        assertRange(1, 5, 1, 10, outer.selectionRange);
        assertEquals(0, outer.tags.length);
        assertEquals(1, outer.children.length);
        final inner = outer.children[0];
        assertEquals('inner', inner.name);
        assertEquals('()', inner.detail);
        assertEquals((cityscape.common.SymbolKind.Method : Int), (inner.kind : Int));
        assertRange(2, 1, 2, 4, inner.selectionRange);
        setup.client.dispose();
    }

    function testCodeAction() {
        final setup = startWithModel('bad code here');
        final model = setup.model;
        setup.server.publish(URI_A, [
            {range: lspRange(0, 0, 0, 3), severity: 1, message: 'bad thing', code: 'E1', data: {fix: 7}},
            {range: lspRange(0, 9, 0, 13), severity: 2, message: 'far away'}
        ]);

        final provider = setup.context.languageFeaturesService.codeActionProvider.ordered(model)[0];
        assertDeepEquals(['quickfix'], provider.providedCodeActionKinds);
        var list:Null<CodeActionList> = null;
        provider.provideCodeActions(model, new Range(1, 1, 1, 4), {trigger: CodeActionTriggerType.Invoke}, CancellationTokens.None, l -> list = l);

        final request:Dynamic = setup.server.lastOf('textDocument/codeAction');
        assertEquals(URI_A, request.params.textDocument.uri);
        assertLspRange(0, 0, 0, 3, request.params.range);
        assertEquals(1, request.params.context.triggerKind);
        final sent:Array<Dynamic> = request.params.context.diagnostics;
        assertEquals(1, sent.length);
        assertEquals('bad thing', sent[0].message);
        // the original diagnostic, with its data
        assertEquals(7, sent[0].data.fix);
        assertEquals('E1', sent[0].code);

        assertNotNull(list);
        assertEquals(2, list.actions.length);
        final action = list.actions[0];
        assertEquals('Fix it', action.title);
        assertEquals('quickfix', action.kind);
        assertEquals(true, action.isPreferred);
        assertEquals(1, action.diagnostics.length);
        assertEquals('bad thing', action.diagnostics[0].message);
        assertEquals((MarkerSeverity.Error : Int), (action.diagnostics[0].severity : Int));
        assertNotNull(action.edit);
        assertEquals(1, action.edit.edits.length);
        final edit:IWorkspaceTextEdit = cast action.edit.edits[0];
        assertEquals(URI_A, edit.resource.toString());
        assertEquals('fixed', edit.textEdit.text);
        assertRange(1, 1, 1, 4, edit.textEdit.range);
        assertNull(edit.versionId);

        // a bare command becomes an action running it
        final run = list.actions[1];
        assertEquals('Run it', run.title);
        assertEquals('fake.run', run.command.id);
        assertDeepEquals(['x'], run.command.arguments);

        // `only` is sent as an array
        provider.provideCodeActions(model, new Range(1, 1, 1, 1), {trigger: CodeActionTriggerType.Auto, only: 'quickfix'}, CancellationTokens.None, _ -> {});
        final request2:Dynamic = setup.server.lastOf('textDocument/codeAction');
        assertDeepEquals(['quickfix'], request2.params.context.only);
        assertEquals(2, request2.params.context.triggerKind);
        setup.client.dispose();
    }

    function testSignatureHelp() {
        final setup = startWithModel('f(1, 2)');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.signatureHelpProvider.ordered(model)[0];
        assertDeepEquals(['(', ','], provider.signatureHelpTriggerCharacters);
        assertDeepEquals([')'], provider.signatureHelpRetriggerCharacters);
        var result:Null<SignatureHelpResult> = null;
        provider.provideSignatureHelp(model, new Position(1, 3), CancellationTokens.None, {triggerKind: SignatureHelpTriggerKind.TriggerCharacter, triggerCharacter: '(', isRetrigger: false}, r -> result = r);

        final request:Dynamic = setup.server.lastOf('textDocument/signatureHelp');
        assertEquals(2, request.params.context.triggerKind);
        assertEquals('(', request.params.context.triggerCharacter);
        assertEquals(false, request.params.context.isRetrigger);

        assertNotNull(result);
        final help = result.value;
        assertEquals(1, help.signatures.length);
        assertEquals('f(a, b)', help.signatures[0].label);
        assertEquals('Calls f', help.signatures[0].documentation);
        assertEquals(2, help.signatures[0].parameters.length);
        assertDeepEquals([2, 3], help.signatures[0].parameters[0].label);
        assertEquals('b', help.signatures[0].parameters[1].label);
        assertEquals(0, help.activeSignature);
        assertEquals(1, help.activeParameter);

        // a retrigger sends the active signature help back
        provider.provideSignatureHelp(model, new Position(1, 5), CancellationTokens.None, {triggerKind: SignatureHelpTriggerKind.ContentChange, isRetrigger: true, activeSignatureHelp: help}, _ -> {});
        final request2:Dynamic = setup.server.lastOf('textDocument/signatureHelp');
        assertEquals(3, request2.params.context.triggerKind);
        assertEquals(true, request2.params.context.isRetrigger);
        assertEquals('f(a, b)', request2.params.context.activeSignatureHelp.signatures[0].label);
        assertDeepEquals([2, 3], request2.params.context.activeSignatureHelp.signatures[0].parameters[0].label);
        setup.client.dispose();
    }

    function testFormatting() {
        final setup = startWithModel('a\nb');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.documentFormattingEditProvider.ordered(model)[0];
        var edits:Null<Array<TextEdit>> = null;
        provider.provideDocumentFormattingEdits(model, {tabSize: 4, insertSpaces: true}, CancellationTokens.None, e -> edits = e);
        final request:Dynamic = setup.server.lastOf('textDocument/formatting');
        assertEquals(4, request.params.options.tabSize);
        assertEquals(true, request.params.options.insertSpaces);
        assertNotNull(edits);
        assertEquals(1, edits.length);
        assertRange(1, 1, 1, 1, edits[0].range);
        assertEquals('  ', edits[0].text);

        final rangeProvider = setup.context.languageFeaturesService.documentRangeFormattingEditProvider.ordered(model)[0];
        assertNull(rangeProvider.provideDocumentRangesFormattingEdits);
        var rangeEdits:Null<Array<TextEdit>> = null;
        rangeProvider.provideDocumentRangeFormattingEdits(model, new Range(2, 1, 2, 2), {tabSize: 2, insertSpaces: false}, CancellationTokens.None, e -> rangeEdits = e);
        final rangeRequest:Dynamic = setup.server.lastOf('textDocument/rangeFormatting');
        assertLspRange(1, 0, 1, 1, rangeRequest.params.range);
        assertEquals(2, rangeRequest.params.options.tabSize);
        assertEquals(false, rangeRequest.params.options.insertSpaces);
        assertEquals(1, rangeEdits.length);
        setup.client.dispose();
    }

    function testProvidersOnlyForDeclaredCapabilities() {
        final context = newContext();
        final server = new MinimalServer();
        final model = context.modelService.createModel('x', 'fakelang', Uri.parse(URI_A));
        final client = new LspClient(context, new InProcessTransport(server), {languageIds: ['fakelang']});
        client.start();
        assertTrue(context.languageFeaturesService.hoverProvider.has(model));
        assertFalse(context.languageFeaturesService.completionProvider.has(model));
        assertFalse(context.languageFeaturesService.definitionProvider.has(model));
        assertFalse(context.languageFeaturesService.codeActionProvider.has(model));
        assertFalse(context.languageFeaturesService.signatureHelpProvider.has(model));
        assertFalse(context.languageFeaturesService.documentFormattingEditProvider.has(model));
        // the providers are for the client's languages only
        final other = context.modelService.createModel('y', 'otherlang', Uri.parse('file:///o.other'));
        assertFalse(context.languageFeaturesService.hoverProvider.has(other));
        client.dispose();
    }

    /**
     * `registerProviders`: none (`false`) or a list of capabilities; the
     * documents are synced and the diagnostics become markers either way.
     */
    function testRegisterProvidersOption() {
        for (list in [false, true]) {
            final option:Any = list ? (['hoverProvider', 'executeCommandProvider'] : Any) : (false : Any);
            final context = newContext();
            final server = new FakeLspServer();
            final model = context.modelService.createModel('x', 'fakelang', Uri.parse(URI_A));
            final client = new LspClient(context, new InProcessTransport(server), {languageIds: ['fakelang'], registerProviders: option});
            client.start();
            assertEquals(list, client.registersProvider('hoverProvider'));
            assertFalse(client.registersProvider('completionProvider'));
            assertEquals(list, context.languageFeaturesService.hoverProvider.has(model));
            assertFalse(context.languageFeaturesService.completionProvider.has(model));
            assertFalse(context.languageFeaturesService.definitionProvider.has(model));
            assertFalse(context.languageFeaturesService.codeActionProvider.has(model));
            assertFalse(context.languageFeaturesService.signatureHelpProvider.has(model));
            assertFalse(context.languageFeaturesService.documentFormattingEditProvider.has(model));
            assertEquals(list, context.commandsRegistry.getCommand('fake.run') != null);
            // synced, diagnostics as markers
            assertEquals(1, server.messagesOf('textDocument/didOpen').length);
            server.publish(URI_A, [{range: lspRange(0, 0, 0, 1), severity: 1, message: 'Bad'}]);
            assertEquals(1, context.markerService.read({resource: model.uri}).length);
            client.dispose();
        }
        // all of them by default (and with `true`)
        final setup = startWithModel('x');
        assertTrue(setup.client.registersProvider('completionProvider'));
        assertTrue(setup.context.languageFeaturesService.completionProvider.has(setup.model));
        setup.client.dispose();
    }

    //#endregion

    //#region cancellation, custom messages, commands, dispose

    function testCancellation() {
        final setup = startWithModel('hello world');
        final model = setup.model;
        final server = setup.server;
        server.deferred = true;
        final provider = setup.context.languageFeaturesService.hoverProvider.ordered(model)[0];

        final source = new CancellationTokenSource();
        var calls = 0;
        var hover:Null<Hover> = null;
        provider.provideHover(model, new Position(1, 2), source.token, null, h -> {
            calls++;
            hover = h;
        });
        assertEquals(0, calls);
        final request:Dynamic = server.lastOf('textDocument/hover');
        assertNotNull(request);

        source.cancel();
        assertEquals(1, calls);
        assertNull(hover);
        final cancel:Dynamic = server.lastOf("$/cancelRequest");
        assertNotNull(cancel);
        assertEquals(Std.string(request.id), Std.string(cancel.params.id));

        // the late response is ignored
        server.flush();
        assertEquals(1, calls);
        assertNull(hover);

        // a response coming later is delivered
        var later:Null<Hover> = null;
        provider.provideHover(model, new Position(1, 2), CancellationTokens.None, null, h -> later = h);
        assertNull(later);
        server.flush();
        assertNotNull(later);
        assertEquals('**hover**', later.contents[0].value);

        // a token cancelled before the request sends nothing
        final cancelled = new CancellationTokenSource();
        cancelled.cancel();
        final count = server.messagesOf('textDocument/hover').length;
        var called = false;
        provider.provideHover(model, new Position(1, 2), cancelled.token, null, h -> {
            called = true;
            hover = h;
        });
        assertTrue(called);
        assertNull(hover);
        assertEquals(count, server.messagesOf('textDocument/hover').length);
        setup.client.dispose();
    }

    function testCustomRequestsAndNotifications() {
        final setup = startWithModel('x');
        final client = setup.client;
        final server = setup.server;

        var result:Dynamic = null;
        var error:Dynamic = 'unset';
        client.sendRequest('fake/echo', {x: 1}, (r, e) -> {
            result = r;
            error = e;
        });
        assertNull(error);
        assertEquals(1, result.x);

        var unknownError:Dynamic = null;
        client.sendRequest('fake/unknown', null, (_, e) -> unknownError = e);
        assertNotNull(unknownError);
        assertEquals(-32601, unknownError.code);

        var got:Dynamic = null;
        final listener = client.onNotification('fake/note', params -> got = params);
        server.notify('fake/note', {y: 2});
        assertEquals(2, got.y);
        listener.dispose();
        server.notify('fake/note', {y: 3});
        assertEquals(2, got.y);

        client.sendNotification('fake/clientNote', {z: 1});
        assertEquals(1, server.lastOf('fake/clientNote').params.z);

        // requests of the server get default answers
        final configId = server.requestClient('workspace/configuration', {items: [{section: 'a'}, {section: 'b'}]});
        final configResponse:Dynamic = server.clientResponses.get(configId);
        assertNotNull(configResponse);
        assertDeepEquals([null, null], configResponse.result);

        final registerId = server.requestClient('client/registerCapability', {registrations: []});
        final registerResponse:Dynamic = server.clientResponses.get(registerId);
        assertTrue(Reflect.hasField(registerResponse, 'result'));
        assertNull(registerResponse.result);

        final unknownId = server.requestClient('fake/serverAsks', null);
        assertEquals(-32601, server.clientResponses.get(unknownId).error.code);

        // a host can handle them
        client.onServerRequest = (method, params, respond) -> {
            if (method == 'fake/serverAsks') {
                respond(42);
                return true;
            }
            return false;
        };
        final handledId = server.requestClient('fake/serverAsks', null);
        assertEquals(42, server.clientResponses.get(handledId).result);
        client.dispose();
    }

    function testApplyEdit() {
        final setup = startWithModel('hello world');
        final server = setup.server;
        final changes:Dynamic = {};
        Reflect.setField(changes, URI_A, [{range: lspRange(0, 0, 0, 5), newText: 'HELLO'}, {range: lspRange(0, 6, 0, 11), newText: 'there'}]);
        final id = server.requestClient('workspace/applyEdit', {edit: {changes: changes}});
        assertEquals(true, server.clientResponses.get(id).result.applied);
        assertEquals('HELLO there', setup.model.getValue());
        assertEquals('HELLO there', server.documents.get(URI_A));

        // an unknown resource applies nothing
        final missing:Dynamic = {};
        Reflect.setField(missing, 'file:///missing.fake', [{range: lspRange(0, 0, 0, 0), newText: 'x'}]);
        final id2 = server.requestClient('workspace/applyEdit', {edit: {changes: missing}});
        assertEquals(false, server.clientResponses.get(id2).result.applied);
        setup.client.dispose();
    }

    function testCommands() {
        final setup = startWithModel('x');
        final context = setup.context;
        final command = context.commandsRegistry.getCommand('fake.run');
        assertNotNull(command);
        final args:Array<Any> = ['arg', 3];
        command.handler(context, args);
        final execute:Dynamic = setup.server.lastOf('workspace/executeCommand');
        assertNotNull(execute);
        assertEquals('fake.run', execute.params.command);
        assertDeepEquals(args, execute.params.arguments);
        setup.client.dispose();
        assertNull(context.commandsRegistry.getCommand('fake.run'));
    }

    function testDispose() {
        final setup = startWithModel('hello');
        final context = setup.context;
        final model = setup.model;
        final server = setup.server;
        final features = context.languageFeaturesService;
        assertTrue(features.completionProvider.has(model));
        assertTrue(features.hoverProvider.has(model));
        assertTrue(features.definitionProvider.has(model));
        assertTrue(features.documentSymbolProvider.has(model));
        assertTrue(features.codeActionProvider.has(model));
        assertTrue(features.signatureHelpProvider.has(model));
        assertTrue(features.documentFormattingEditProvider.has(model));
        assertTrue(features.documentRangeFormattingEditProvider.has(model));

        // a pending request fails on dispose
        server.deferred = true;
        var pendingError:Dynamic = null;
        setup.client.sendRequest('fake/echo', {}, (_, e) -> pendingError = e);

        setup.client.dispose();
        assertNotNull(pendingError);
        assertEquals(LspClient.RequestCancelled, pendingError.code);

        final count = server.received.length;
        assertEquals('shutdown', server.received[count - 2].method);
        assertEquals('exit', server.received[count - 1].method);
        assertNull(server.received[count - 1].id);

        assertFalse(features.completionProvider.has(model));
        assertFalse(features.hoverProvider.has(model));
        assertFalse(features.definitionProvider.has(model));
        assertFalse(features.documentSymbolProvider.has(model));
        assertFalse(features.codeActionProvider.has(model));
        assertFalse(features.signatureHelpProvider.has(model));
        assertFalse(features.documentFormattingEditProvider.has(model));
        assertFalse(features.documentRangeFormattingEditProvider.has(model));

        // nothing is sent after dispose
        model.applyEdits([{range: new Range(1, 1, 1, 1), text: 'x'}]);
        setup.client.sendNotification('fake/late', null);
        var lateError:Dynamic = null;
        setup.client.sendRequest('fake/echo', {}, (_, e) -> lateError = e);
        assertNotNull(lateError);
        assertEquals(count, server.received.length);
    }

    //#endregion

}

/**
 * A server whose `initialize` fails.
 */
class FailingServer implements LspInProcessServer {

    public var onNotification:Null<(notification:Dynamic) -> Void> = null;

    public function new() {}

    public function handleMessage(message:Dynamic, onResponse:(response:Dynamic) -> Void):Void {
        if (message.id != null && message.method != null) {
            onResponse({jsonrpc: '2.0', id: message.id, error: {code: -32603, message: 'broken'}});
        }
    }

}

/**
 * A server declaring hover only.
 */
class MinimalServer implements LspInProcessServer {

    public var onNotification:Null<(notification:Dynamic) -> Void> = null;

    public function new() {}

    public function handleMessage(message:Dynamic, onResponse:(response:Dynamic) -> Void):Void {
        if (message.id != null && message.method != null) {
            final result:Dynamic = message.method == 'initialize' ? {capabilities: {textDocumentSync: 1, hoverProvider: true}} : null;
            onResponse({jsonrpc: '2.0', id: message.id, result: result});
        }
    }

}
