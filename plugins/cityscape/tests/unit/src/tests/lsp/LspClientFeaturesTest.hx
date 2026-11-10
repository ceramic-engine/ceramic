// New code for Cityscape (not a port): tests of the language features the
// LSP client registers besides completion, hover, definition, symbols, code
// actions, signature help and formatting, against the fake language server
// of LspClientTest. The expected conversions follow vscode-languageclient's
// protocol converter and vscode's extension host type converters.
package tests.lsp;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationTokens;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.base.common.Uri;
import cityscape.common.Languages.CodeLens;
import cityscape.common.Languages.CodeLensList;
import cityscape.common.Languages.CodeLensProvider;
import cityscape.common.Languages.Definition;
import cityscape.common.Languages.DocumentHighlight;
import cityscape.common.Languages.DocumentHighlightKind;
import cityscape.common.Languages.FoldingRange;
import cityscape.common.Languages.FoldingRangeKind;
import cityscape.common.Languages.FoldingRangeProvider;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.Languages.IColorPresentation;
import cityscape.common.Languages.ILink;
import cityscape.common.Languages.ILinksList;
import cityscape.common.Languages.IWorkspaceTextEdit;
import cityscape.common.Languages.InlayHint;
import cityscape.common.Languages.InlayHintLabelPart;
import cityscape.common.Languages.InlayHintList;
import cityscape.common.Languages.Location;
import cityscape.common.Languages.LocationLink;
import cityscape.common.Languages.RenameLocation;
import cityscape.common.Languages.SelectionRange;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensEdits;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Languages.WorkspaceEditAndRejection;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageKinds.InlayHintKind;
import cityscape.common.model.TextModel;
import cityscape.lsp.InProcessTransport;
import cityscape.lsp.LspClient;
import tests.lsp.LspClientTest.FakeLspServer;
import testing.TestCase;

class LspClientFeaturesTest extends TestCase {

    static inline final URI_A = 'file:///a.fake';

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

    function startWithModel(text:String):{context:Cityscape, server:FakeLspServer, client:LspClient, model:TextModel} {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'fakelang'});
        final server = new FakeLspServer();
        final model = context.modelService.createModel(text, 'fakelang', Uri.parse(URI_A));
        final client = new LspClient(context, new InProcessTransport(server), {languageIds: ['fakelang']});
        client.start();
        return {context: context, server: server, client: client, model: model};
    }

    function testClientCapabilities() {
        final setup = startWithModel('x');
        final params:Dynamic = setup.server.received[0].params;
        final textDocument:Dynamic = params.capabilities.textDocument;
        assertEquals(true, textDocument.declaration.linkSupport);
        assertEquals(true, textDocument.typeDefinition.linkSupport);
        assertEquals(true, textDocument.implementation.linkSupport);
        assertNotNull(textDocument.references);
        assertNotNull(textDocument.documentHighlight);
        assertEquals(true, textDocument.rename.prepareSupport);
        assertEquals(true, textDocument.foldingRange.lineFoldingOnly);
        assertDeepEquals(['comment', 'imports', 'region'], textDocument.foldingRange.foldingRangeKind.valueSet);
        assertNotNull(textDocument.selectionRange);
        assertNotNull(textDocument.inlayHint.resolveSupport);
        assertNotNull(textDocument.codeLens);
        assertDeepEquals(['relative'], textDocument.semanticTokens.formats);
        assertEquals(true, textDocument.semanticTokens.requests.full.delta);
        assertEquals(true, textDocument.semanticTokens.requests.range);
        assertEquals(true, textDocument.documentLink.tooltipSupport);
        assertNotNull(textDocument.colorProvider);
        assertNotNull(textDocument.onTypeFormatting);
        final workspace:Dynamic = params.capabilities.workspace;
        assertEquals(true, workspace.semanticTokens.refreshSupport);
        assertEquals(true, workspace.inlayHint.refreshSupport);
        assertEquals(true, workspace.codeLens.refreshSupport);
        assertEquals(true, workspace.foldingRange.refreshSupport);
        setup.client.dispose();
    }

    function testRegisteredAndDisposed() {
        final setup = startWithModel('x');
        final f = setup.context.languageFeaturesService;
        final model = setup.model;
        final registries:Array<{has:(m:TextModel) -> Bool, name:String}> = [
            {name: 'declaration', has: m -> f.declarationProvider.has(m)},
            {name: 'typeDefinition', has: m -> f.typeDefinitionProvider.has(m)},
            {name: 'implementation', has: m -> f.implementationProvider.has(m)},
            {name: 'references', has: m -> f.referenceProvider.has(m)},
            {name: 'documentHighlight', has: m -> f.documentHighlightProvider.has(m)},
            {name: 'rename', has: m -> f.renameProvider.has(m)},
            {name: 'foldingRange', has: m -> f.foldingRangeProvider.has(m)},
            {name: 'selectionRange', has: m -> f.selectionRangeProvider.has(m)},
            {name: 'inlayHints', has: m -> f.inlayHintsProvider.has(m)},
            {name: 'codeLens', has: m -> f.codeLensProvider.has(m)},
            {name: 'semanticTokens', has: m -> f.documentSemanticTokensProvider.has(m)},
            {name: 'rangeSemanticTokens', has: m -> f.documentRangeSemanticTokensProvider.has(m)},
            {name: 'links', has: m -> f.linkProvider.has(m)},
            {name: 'colors', has: m -> f.colorProvider.has(m)},
            {name: 'onTypeFormatting', has: m -> f.onTypeFormattingEditProvider.has(m)}
        ];
        for (r in registries) {
            assertTrue(r.has(model), r.name);
        }
        setup.client.dispose();
        for (r in registries) {
            assertFalse(r.has(model), r.name);
        }

        // `registerProviders: false` registers none of them
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'fakelang'});
        final other = context.modelService.createModel('x', 'fakelang', Uri.parse(URI_A));
        final client = new LspClient(context, new InProcessTransport(new FakeLspServer()), {languageIds: ['fakelang'], registerProviders: false});
        client.start();
        final g = context.languageFeaturesService;
        assertFalse(g.referenceProvider.has(other));
        assertFalse(g.codeLensProvider.has(other));
        assertFalse(g.inlayHintsProvider.has(other));
        assertFalse(g.documentSemanticTokensProvider.has(other));
        assertFalse(g.foldingRangeProvider.has(other));
        assertFalse(g.renameProvider.has(other));
        client.dispose();

        // a list registers those it names
        final context2 = new Cityscape();
        context2.languageService.registerLanguage({id: 'fakelang'});
        final third = context2.modelService.createModel('x', 'fakelang', Uri.parse(URI_A));
        final client2 = new LspClient(context2, new InProcessTransport(new FakeLspServer()), {languageIds: ['fakelang'], registerProviders: ['referencesProvider', 'semanticTokensProvider']});
        client2.start();
        final h = context2.languageFeaturesService;
        assertTrue(h.referenceProvider.has(third));
        assertTrue(h.documentSemanticTokensProvider.has(third));
        assertTrue(h.documentRangeSemanticTokensProvider.has(third));
        assertFalse(h.codeLensProvider.has(third));
        assertFalse(h.documentHighlightProvider.has(third));
        client2.dispose();
    }

    function testReferencesAndHighlights() {
        final setup = startWithModel('foo bar\nfoo b');
        final model = setup.model;
        final references = setup.context.languageFeaturesService.referenceProvider.ordered(model)[0];
        var locations:Null<Array<Location>> = null;
        references.provideReferences(model, new Position(1, 2), {includeDeclaration: false}, CancellationTokens.None, l -> locations = l);
        final request:Dynamic = setup.server.lastOf('textDocument/references');
        assertDeepEquals({line: 0, character: 1}, request.params.position);
        assertEquals(false, request.params.context.includeDeclaration);
        assertEquals(2, locations.length);
        assertEquals(URI_A, locations[0].uri.toString());
        assertRange(1, 1, 1, 4, locations[0].range);
        assertEquals('file:///other.fake', locations[1].uri.toString());
        assertRange(3, 2, 3, 5, locations[1].range);

        final highlights = setup.context.languageFeaturesService.documentHighlightProvider.ordered(model)[0];
        var list:Null<Array<DocumentHighlight>> = null;
        highlights.provideDocumentHighlights(model, new Position(1, 1), CancellationTokens.None, h -> list = h);
        assertEquals(4, list.length);
        // LSP kinds Text 1, Read 2, Write 3 are Monaco's 0, 1, 2
        assertEquals((DocumentHighlightKind.Text : Int), (list[0].kind : Int));
        assertEquals((DocumentHighlightKind.Read : Int), (list[1].kind : Int));
        assertEquals((DocumentHighlightKind.Write : Int), (list[2].kind : Int));
        assertNull(list[3].kind);
        assertRange(2, 5, 2, 6, list[3].range);

        // a failed request gives no answer
        setup.server.errors.set('textDocument/references', {code: -32603, message: 'broken'});
        locations = [];
        references.provideReferences(model, new Position(1, 2), {includeDeclaration: true}, CancellationTokens.None, l -> locations = l);
        assertNull(locations);
        setup.client.dispose();
    }

    function testRename() {
        final setup = startWithModel('foo = foo + 1');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.renameProvider.ordered(model)[0];
        assertNotNull(provider.resolveRenameLocation);
        final prepare = provider.resolveRenameLocation;
        var location:Null<RenameLocation> = null;
        var answered = false;
        final ask = () -> {
            location = null;
            answered = false;
            prepare(model, new Position(1, 2), CancellationTokens.None, l -> {
                location = l;
                answered = true;
            });
        };

        // {range, placeholder}
        ask();
        assertTrue(answered);
        assertRange(1, 1, 1, 4, location.range);
        assertEquals('foo', location.text);
        assertNull(location.rejectReason);
        assertDeepEquals({line: 0, character: 1}, setup.server.lastOf('textDocument/prepareRename').params.position);

        // a bare range: its text is the placeholder
        setup.server.overrides.set('textDocument/prepareRename', lspRange(0, 0, 0, 3));
        ask();
        assertRange(1, 1, 1, 4, location.range);
        assertEquals('foo', location.text);

        // defaultBehavior: Monaco's word at the position (no location)
        setup.server.overrides.set('textDocument/prepareRename', {defaultBehavior: true});
        ask();
        assertTrue(answered);
        assertNull(location);

        // null, or defaultBehavior false: rejected
        setup.server.overrides.set('textDocument/prepareRename', null);
        ask();
        assertEquals("The element can't be renamed.", location.rejectReason);
        setup.server.overrides.set('textDocument/prepareRename', {defaultBehavior: false});
        ask();
        assertEquals("The element can't be renamed.", location.rejectReason);

        // a range on another line than the position: ignored
        setup.server.overrides.set('textDocument/prepareRename', {range: lspRange(2, 0, 2, 3), placeholder: 'x'});
        ask();
        assertTrue(answered);
        assertNull(location);

        // an error: rejected with its message
        setup.server.overrides.remove('textDocument/prepareRename');
        setup.server.errors.set('textDocument/prepareRename', {code: -32603, message: 'Not a symbol'});
        ask();
        assertEquals('Not a symbol', location.rejectReason);

        // the edits (documentChanges with the version)
        var edit:Null<WorkspaceEditAndRejection> = null;
        provider.provideRenameEdits(model, new Position(1, 2), 'bar', CancellationTokens.None, e -> edit = e);
        assertEquals('bar', setup.server.lastOf('textDocument/rename').params.newName);
        assertEquals(1, edit.edits.length);
        final textEdit:IWorkspaceTextEdit = cast edit.edits[0];
        assertEquals(URI_A, textEdit.resource.toString());
        assertEquals('bar', textEdit.textEdit.text);
        assertEquals(1, textEdit.versionId);
        assertRange(1, 1, 1, 4, textEdit.textEdit.range);

        // a failed rename: rejected with the message
        setup.server.errors.set('textDocument/rename', {code: -32603, message: 'Name taken'});
        provider.provideRenameEdits(model, new Position(1, 2), 'bar', CancellationTokens.None, e -> edit = e);
        assertEquals('Name taken', edit.rejectReason);
        assertEquals(0, edit.edits.length);
        setup.client.dispose();

        // no prepareProvider: no resolveRenameLocation
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'fakelang'});
        final other = context.modelService.createModel('x', 'fakelang', Uri.parse(URI_A));
        final client = new LspClient(context, new InProcessTransport(new CapabilityServer({renameProvider: true})), {languageIds: ['fakelang']});
        client.start();
        assertNull(context.languageFeaturesService.renameProvider.ordered(other)[0].resolveRenameLocation);
        client.dispose();
    }

    function testFoldingAndSelectionRanges() {
        final setup = startWithModel('a\nb\nc\nd\ne\nf');
        final model = setup.model;
        final folding = setup.context.languageFeaturesService.foldingRangeProvider.ordered(model)[0];
        var ranges:Null<Array<FoldingRange>> = null;
        folding.provideFoldingRanges(model, {}, CancellationTokens.None, r -> ranges = r);
        assertEquals(URI_A, setup.server.lastOf('textDocument/foldingRange').params.textDocument.uri);
        assertEquals(4, ranges.length);
        // LSP lines start at 0, Monaco's at 1
        assertEquals(1, ranges[0].start);
        assertEquals(3, ranges[0].end);
        assertTrue(ranges[0].kind == FoldingRangeKind.Region);
        // an unknown kind is dropped
        assertEquals(4, ranges[1].start);
        assertNull(ranges[1].kind);
        assertTrue(ranges[2].kind == FoldingRangeKind.Comment);
        assertNull(ranges[3].kind);

        final selection = setup.context.languageFeaturesService.selectionRangeProvider.ordered(model)[0];
        var result:Null<Array<Array<SelectionRange>>> = null;
        selection.provideSelectionRanges(model, [new Position(1, 2), new Position(2, 1)], CancellationTokens.None, r -> result = r);
        final request:Dynamic = setup.server.lastOf('textDocument/selectionRange');
        assertDeepEquals([{line: 0, character: 1}, {line: 1, character: 0}], request.params.positions);
        assertEquals(2, result.length);
        // from the innermost range out
        assertEquals(3, result[0].length);
        assertRange(1, 2, 1, 3, result[0][0].range);
        assertRange(1, 1, 1, 10, result[0][1].range);
        assertRange(1, 1, 4, 1, result[0][2].range);
        assertRange(2, 1, 2, 2, result[1][0].range);

        // a parent not containing its child: no answer (vscode rejects it)
        setup.server.overrides.set('textDocument/selectionRange', [{range: lspRange(0, 0, 0, 5), parent: {range: lspRange(0, 1, 0, 2)}}]);
        result = [];
        selection.provideSelectionRanges(model, [new Position(1, 2)], CancellationTokens.None, r -> result = r);
        assertNull(result);
        setup.client.dispose();
    }

    function testInlayHints() {
        final setup = startWithModel('call(1)\n  x\n');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.inlayHintsProvider.ordered(model)[0];
        var list:Null<InlayHintList> = null;
        provider.provideInlayHints(model, new Range(1, 1, 3, 1), CancellationTokens.None, l -> list = l);
        final request:Dynamic = setup.server.lastOf('textDocument/inlayHint');
        assertDeepEquals(lspRange(0, 0, 2, 0), request.params.range);
        // the hints with an empty label are dropped
        assertEquals(2, list.hints.length);

        final first = list.hints[0];
        assertEquals('a:', first.label);
        assertEquals(1, first.position.lineNumber);
        assertEquals(5, first.position.column);
        assertEquals((InlayHintKind.Parameter : Int), (first.kind : Int));
        assertEquals(true, first.paddingRight);
        assertNull(first.paddingLeft);

        final second = list.hints[1];
        assertEquals((InlayHintKind.Type : Int), (second.kind : Int));
        assertEquals('hint', second.tooltip);
        assertEquals(1, second.textEdits.length);
        assertEquals(':Int', second.textEdits[0].text);
        assertRange(2, 3, 2, 3, second.textEdits[0].range);
        final parts:Array<InlayHintLabelPart> = cast second.label;
        assertEquals(1, parts.length);
        assertEquals('Int', parts[0].label);
        // plain text tooltips are escaped markdown
        final tooltip:IMarkdownString = cast parts[0].tooltip;
        assertEquals('a\\*b', tooltip.value);
        assertEquals(URI_A, parts[0].location.uri.toString());
        assertRange(1, 1, 1, 4, parts[0].location.range);
        // the arguments of the command are Monaco's
        assertEquals('editor.action.showReferences', parts[0].command.id);
        assertTrue(Std.isOfType(parts[0].command.arguments[0], Uri));
        assertTrue(Std.isOfType(parts[0].command.arguments[1], Position));

        // resolve sends the original hint
        assertNotNull(provider.resolveInlayHint);
        final resolveFn = provider.resolveInlayHint;
        var resolved:Null<InlayHint> = null;
        resolveFn(first, CancellationTokens.None, h -> resolved = h);
        final resolveRequest:Dynamic = setup.server.lastOf('inlayHint/resolve');
        assertEquals(1, resolveRequest.params.data);
        assertEquals('a:', resolveRequest.params.label);
        final resolvedTooltip:IMarkdownString = cast resolved.tooltip;
        assertEquals('**resolved**', resolvedTooltip.value);
        setup.client.dispose();
    }

    function testCodeLenses() {
        final setup = startWithModel('foo()\nbar()');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.codeLensProvider.ordered(model)[0];
        var list:Null<CodeLensList> = null;
        provider.provideCodeLenses(model, CancellationTokens.None, l -> list = l);
        assertEquals(2, list.lenses.length);
        final run = list.lenses[0];
        assertRange(1, 1, 1, 4, run.range);
        assertEquals("$(play) Run", run.command.title);
        assertEquals('fake.run', run.command.id);
        // the server's own commands keep their JSON arguments
        assertDeepEquals(['x'], run.command.arguments);
        assertNull(list.lenses[1].command);

        // resolve sends the original lens (with its data)
        assertNotNull(provider.resolveCodeLens);
        final resolveFn = provider.resolveCodeLens;
        var resolved:Null<CodeLens> = null;
        resolveFn(model, list.lenses[1], CancellationTokens.None, l -> resolved = l);
        final request:Dynamic = setup.server.lastOf('codeLens/resolve');
        assertEquals(7, request.params.data);
        assertDeepEquals(lspRange(1, 0, 1, 3), request.params.range);
        assertEquals('2 references', resolved.command.title);
        // editor.action.showReferences (uri, position, locations): Monaco's types
        final args = resolved.command.arguments;
        assertEquals(3, args.length);
        assertTrue(Std.isOfType(args[0], Uri));
        assertEquals(URI_A, (args[0] : Uri).toString());
        assertTrue(Std.isOfType(args[1], Position));
        assertEquals(2, (args[1] : Position).lineNumber);
        assertEquals(1, (args[1] : Position).column);
        final locations:Array<LocationLink> = args[2];
        assertEquals(2, locations.length);
        assertEquals(URI_A, locations[0].uri.toString());
        assertRange(1, 1, 1, 4, locations[0].range);
        assertEquals('file:///b.fake', locations[1].uri.toString());
        assertRange(3, 1, 3, 6, locations[1].range);
        assertRange(3, 1, 3, 4, locations[1].targetSelectionRange);
        setup.client.dispose();
    }

    function testSemanticTokens() {
        final setup = startWithModel('foo bar\nbaz');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.documentSemanticTokensProvider.ordered(model)[0];
        assertDeepEquals(['variable', 'function'], provider.getLegend().tokenTypes);
        assertDeepEquals(['declaration'], provider.getLegend().tokenModifiers);

        var result:Dynamic = null;
        provider.provideDocumentSemanticTokens(model, null, CancellationTokens.None, r -> result = r);
        assertNotNull(setup.server.lastOf('textDocument/semanticTokens/full'));
        final tokens:SemanticTokens = result;
        assertEquals('r1', tokens.resultId);
        assertEquals(10, tokens.data.length);
        assertEquals(3, tokens.data[2]);
        assertEquals(1, tokens.data[4]);

        // with the previous result id: a delta
        provider.provideDocumentSemanticTokens(model, 'r1', CancellationTokens.None, r -> result = r);
        final deltaRequest:Dynamic = setup.server.lastOf('textDocument/semanticTokens/full/delta');
        assertEquals('r1', deltaRequest.params.previousResultId);
        final edits:SemanticTokensEdits = result;
        assertEquals('r2', edits.resultId);
        assertEquals(2, edits.edits.length);
        assertEquals(0, edits.edits[0].start);
        assertEquals(5, edits.edits[0].deleteCount);
        assertEquals(5, edits.edits[0].data.length);
        assertNull(edits.edits[1].data);

        final rangeProvider = setup.context.languageFeaturesService.documentRangeSemanticTokensProvider.ordered(model)[0];
        var rangeTokens:Null<SemanticTokens> = null;
        rangeProvider.provideDocumentRangeSemanticTokens(model, new Range(1, 1, 1, 4), CancellationTokens.None, r -> rangeTokens = r);
        assertDeepEquals(lspRange(0, 0, 0, 3), setup.server.lastOf('textDocument/semanticTokens/range').params.range);
        assertNull(rangeTokens.resultId);
        assertEquals(5, rangeTokens.data.length);
        setup.client.dispose();

        // full without delta, no range
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'fakelang'});
        final other = context.modelService.createModel('x', 'fakelang', Uri.parse(URI_A));
        final server = new CapabilityServer({semanticTokensProvider: {legend: {tokenTypes: ['a'], tokenModifiers: []}, full: true}});
        final client = new LspClient(context, new InProcessTransport(server), {languageIds: ['fakelang']});
        client.start();
        assertFalse(context.languageFeaturesService.documentRangeSemanticTokensProvider.has(other));
        final full = context.languageFeaturesService.documentSemanticTokensProvider.ordered(other)[0];
        full.provideDocumentSemanticTokens(other, 'r1', CancellationTokens.None, _ -> {});
        assertEquals('textDocument/semanticTokens/full', server.lastMethod);
        client.dispose();
    }

    function testLocations() {
        final setup = startWithModel('use thing');
        final model = setup.model;
        final f = setup.context.languageFeaturesService;
        var definition:Null<Definition> = null;
        f.declarationProvider.ordered(model)[0].provideDeclaration(model, new Position(1, 6), CancellationTokens.None, d -> definition = d);
        assertDeepEquals({line: 0, character: 5}, setup.server.lastOf('textDocument/declaration').params.position);
        assertEquals(1, definition.length);
        assertEquals('file:///decl.fake', definition[0].uri.toString());
        assertRange(2, 1, 4, 1, definition[0].range);
        assertRange(2, 5, 2, 8, definition[0].targetSelectionRange);
        assertRange(1, 1, 1, 4, definition[0].originSelectionRange);

        f.typeDefinitionProvider.ordered(model)[0].provideTypeDefinition(model, new Position(1, 6), CancellationTokens.None, d -> definition = d);
        assertEquals(1, definition.length);
        assertEquals('file:///type.fake', definition[0].uri.toString());
        assertRange(6, 1, 6, 5, definition[0].range);

        f.implementationProvider.ordered(model)[0].provideImplementation(model, new Position(1, 6), CancellationTokens.None, d -> definition = d);
        assertEquals(2, definition.length);
        assertEquals('file:///impl2.fake', definition[1].uri.toString());
        setup.client.dispose();
    }

    function testLinksAndColors() {
        final setup = startWithModel('https x\nab');
        final model = setup.model;
        final f = setup.context.languageFeaturesService;
        final linkProvider = f.linkProvider.ordered(model)[0];
        var links:Null<ILinksList> = null;
        linkProvider.provideLinks(model, CancellationTokens.None, l -> links = l);
        assertEquals(2, links.links.length);
        final first = links.links[0];
        assertRange(1, 1, 1, 5, first.range);
        assertTrue(Std.isOfType(first.url, Uri));
        assertEquals('https://example.com/a', (first.url : Uri).toString());
        assertEquals('Open', first.tooltip);
        assertNull(links.links[1].url);

        assertNotNull(linkProvider.resolveLink);
        final resolveFn = linkProvider.resolveLink;
        var resolved:Null<ILink> = null;
        resolveFn(links.links[1], CancellationTokens.None, l -> resolved = l);
        assertEquals(9, setup.server.lastOf('documentLink/resolve').params.data);
        assertEquals('file:///resolved.fake', (resolved.url : Uri).toString());

        final colorProvider = f.colorProvider.ordered(model)[0];
        var colors:Null<Array<IColorInformation>> = null;
        colorProvider.provideDocumentColors(model, CancellationTokens.None, c -> colors = c);
        assertEquals(1, colors.length);
        assertRange(1, 1, 1, 8, colors[0].range);
        assertEquals(1.0, colors[0].color.red);
        assertEquals(0.5, colors[0].color.green);
        assertEquals(0.0, colors[0].color.blue);
        assertEquals(1.0, colors[0].color.alpha);

        var presentations:Null<Array<IColorPresentation>> = null;
        colorProvider.provideColorPresentations(model, colors[0], CancellationTokens.None, p -> presentations = p);
        final request:Dynamic = setup.server.lastOf('textDocument/colorPresentation');
        assertDeepEquals({red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0}, request.params.color);
        assertDeepEquals(lspRange(0, 0, 0, 7), request.params.range);
        assertEquals(2, presentations.length);
        assertEquals('#ff8000', presentations[0].label);
        assertEquals('#ff8000', presentations[0].textEdit.text);
        assertRange(1, 1, 1, 8, presentations[0].textEdit.range);
        assertEquals('use color;\n', presentations[0].additionalTextEdits[0].text);
        assertNull(presentations[1].textEdit);
        setup.client.dispose();
    }

    function testOnTypeFormatting() {
        final setup = startWithModel('if x {\n}');
        final model = setup.model;
        final provider = setup.context.languageFeaturesService.onTypeFormattingEditProvider.ordered(model)[0];
        assertDeepEquals(['}', ';'], provider.autoFormatTriggerCharacters);
        var edits:Null<Array<TextEdit>> = null;
        provider.provideOnTypeFormattingEdits(model, new Position(2, 2), '}', {tabSize: 4, insertSpaces: true}, CancellationTokens.None, e -> edits = e);
        final request:Dynamic = setup.server.lastOf('textDocument/onTypeFormatting');
        assertEquals('}', request.params.ch);
        assertDeepEquals({line: 1, character: 1}, request.params.position);
        assertEquals(4, request.params.options.tabSize);
        assertEquals(1, edits.length);
        assertRange(2, 1, 2, 1, edits[0].range);
        setup.client.dispose();
    }

    function testRefreshRequests() {
        final setup = startWithModel('x');
        final model = setup.model;
        final f = setup.context.languageFeaturesService;
        var semantic = 0;
        var hints = 0;
        var lenses = 0;
        var folding = 0;
        final semanticEvent = f.documentSemanticTokensProvider.ordered(model)[0].onDidChange;
        final hintsEvent = f.inlayHintsProvider.ordered(model)[0].onDidChangeInlayHints;
        final lensProvider = f.codeLensProvider.ordered(model)[0];
        final lensesEvent = lensProvider.onDidChange;
        final foldingProvider = f.foldingRangeProvider.ordered(model)[0];
        final foldingEvent = foldingProvider.onDidChange;
        semanticEvent(() -> semantic++);
        hintsEvent(() -> hints++);
        var lensSource:Null<CodeLensProvider> = null;
        lensesEvent(p -> {
            lenses++;
            lensSource = p;
        });
        var foldingSource:Null<FoldingRangeProvider> = null;
        foldingEvent(p -> {
            folding++;
            foldingSource = p;
        });

        final id1 = setup.server.requestClient('workspace/semanticTokens/refresh', null);
        final id2 = setup.server.requestClient('workspace/inlayHint/refresh', null);
        final id3 = setup.server.requestClient('workspace/codeLens/refresh', null);
        final id4 = setup.server.requestClient('workspace/foldingRange/refresh', null);
        assertEquals(1, semantic);
        assertEquals(1, hints);
        assertEquals(1, lenses);
        assertEquals(1, folding);
        assertTrue(lensSource == lensProvider);
        assertTrue(foldingSource == foldingProvider);
        for (id in [id1, id2, id3, id4]) {
            final response:Dynamic = setup.server.clientResponses.get(id);
            assertNotNull(response);
            assertNull(response.error);
            assertNull(response.result);
        }
        setup.client.dispose();
    }

}

/**
 * A server declaring the capabilities it is given, answering null to the
 * other requests and recording the last method asked.
 */
class CapabilityServer implements cityscape.lsp.LspInProcessServer {

    public var onNotification:Null<(notification:Dynamic) -> Void> = null;

    public var lastMethod:Null<String> = null;

    final capabilities:Dynamic;

    public function new(capabilities:Dynamic) {
        this.capabilities = capabilities;
        this.capabilities.textDocumentSync = 1;
    }

    public function handleMessage(message:Dynamic, onResponse:(response:Dynamic) -> Void):Void {
        if (message.id != null && message.method != null) {
            lastMethod = message.method;
            final result:Dynamic = message.method == 'initialize' ? {capabilities: capabilities} : null;
            onResponse({jsonrpc: '2.0', id: message.id, result: result});
        }
    }

}
