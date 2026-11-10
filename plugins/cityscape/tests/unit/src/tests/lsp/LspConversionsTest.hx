// New code for Cityscape (not a port): tests of the conversions between
// LSP values and Monaco's types.
package tests.lsp;

import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.base.common.Uri;
import cityscape.common.Languages.CompletionItemInsertTextRule;
import cityscape.common.Languages.CompletionItemLabel;
import cityscape.common.Languages.CompletionItemRanges;
import cityscape.common.Languages.CompletionItemTag;
import cityscape.common.Languages.IWorkspaceFileEdit;
import cityscape.common.Languages.IWorkspaceTextEdit;
import cityscape.common.Languages.SymbolTag;
import cityscape.common.core.Position;
import cityscape.lsp.LspConversions;
import cityscape.platform.markers.common.Markers.IMarkerData;
import cityscape.platform.markers.common.Markers.MarkerSeverity;
import cityscape.platform.markers.common.Markers.MarkerTag;
import testing.TestCase;

/**
 * Tests of `cityscape.lsp.LspConversions`: positions and ranges, the kind
 * tables, markdown, diagnostics, completion items, locations, symbols,
 * code actions and workspace edits.
 *
 * The kind enums are written qualified (their value names hide `String`,
 * `Array`, `Class`... when imported).
 */
class LspConversionsTest extends TestCase {

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

    //#region positions

    function testPositions() {
        assertDeepEquals({line: 2, character: 4}, LspConversions.toLspPosition(new Position(3, 5)));
        assertDeepEquals({line: 0, character: 0}, LspConversions.toLspPositionOf(1, 1));
        final position = LspConversions.fromLspPosition({line: 2, character: 4});
        assertEquals(3, position.lineNumber);
        assertEquals(5, position.column);
    }

    function testRanges() {
        final lsp = LspConversions.toLspRange({startLineNumber: 1, startColumn: 2, endLineNumber: 3, endColumn: 7});
        assertDeepEquals(lspRange(0, 1, 2, 6), lsp);
        assertDeepEquals({startLineNumber: 1, startColumn: 2, endLineNumber: 3, endColumn: 7}, LspConversions.fromLspRange(lsp));
        // numbers parsed from JSON may be floats
        assertDeepEquals({startLineNumber: 2, startColumn: 1, endLineNumber: 2, endColumn: 4}, LspConversions.fromLspRange({start: {line: 1.0, character: 0.0}, end: {line: 1.0, character: 3.0}}));
    }

    //#endregion

    //#region kinds

    function testCompletionItemKinds() {
        // LSP kind, Monaco kind (by name)
        final table:Array<Array<Int>> = [
            [1, cityscape.common.languages.CompletionItemKind.Text],
            [2, cityscape.common.languages.CompletionItemKind.Method],
            [3, cityscape.common.languages.CompletionItemKind.Function],
            [4, cityscape.common.languages.CompletionItemKind.Constructor],
            [5, cityscape.common.languages.CompletionItemKind.Field],
            [6, cityscape.common.languages.CompletionItemKind.Variable],
            [7, cityscape.common.languages.CompletionItemKind.Class],
            [8, cityscape.common.languages.CompletionItemKind.Interface],
            [9, cityscape.common.languages.CompletionItemKind.Module],
            [10, cityscape.common.languages.CompletionItemKind.Property],
            [11, cityscape.common.languages.CompletionItemKind.Unit],
            [12, cityscape.common.languages.CompletionItemKind.Value],
            [13, cityscape.common.languages.CompletionItemKind.Enum],
            [14, cityscape.common.languages.CompletionItemKind.Keyword],
            [15, cityscape.common.languages.CompletionItemKind.Snippet],
            [16, cityscape.common.languages.CompletionItemKind.Color],
            [17, cityscape.common.languages.CompletionItemKind.File],
            [18, cityscape.common.languages.CompletionItemKind.Reference],
            [19, cityscape.common.languages.CompletionItemKind.Folder],
            [20, cityscape.common.languages.CompletionItemKind.EnumMember],
            [21, cityscape.common.languages.CompletionItemKind.Constant],
            [22, cityscape.common.languages.CompletionItemKind.Struct],
            [23, cityscape.common.languages.CompletionItemKind.Event],
            [24, cityscape.common.languages.CompletionItemKind.Operator],
            [25, cityscape.common.languages.CompletionItemKind.TypeParameter]
        ];
        assertEquals(25, table.length);
        for (row in table) {
            assertEquals(row[1], (LspConversions.toCompletionItemKind(row[0]) : Int), 'LSP completion kind ' + row[0]);
            assertEquals(row[0], LspConversions.fromCompletionItemKind(row[1]), 'Monaco completion kind ' + row[1]);
        }
        final property:Int = cityscape.common.languages.CompletionItemKind.Property;
        assertEquals(property, (LspConversions.toCompletionItemKind(null) : Int));
        assertEquals(property, (LspConversions.toCompletionItemKind(0) : Int));
        assertEquals(property, (LspConversions.toCompletionItemKind(26) : Int));
        assertEquals(16, LspConversions.fromCompletionItemKind(cityscape.common.languages.CompletionItemKind.Customcolor));
        assertEquals(1, LspConversions.fromCompletionItemKind(cityscape.common.languages.CompletionItemKind.User));
        assertEquals(1, LspConversions.fromCompletionItemKind(cityscape.common.languages.CompletionItemKind.Issue));
    }

    function testSymbolKinds() {
        // LSP kind, Monaco kind (by name)
        final table:Array<Array<Int>> = [
            [1, cityscape.common.SymbolKind.File],
            [2, cityscape.common.SymbolKind.Module],
            [3, cityscape.common.SymbolKind.Namespace],
            [4, cityscape.common.SymbolKind.Package],
            [5, cityscape.common.SymbolKind.Class],
            [6, cityscape.common.SymbolKind.Method],
            [7, cityscape.common.SymbolKind.Property],
            [8, cityscape.common.SymbolKind.Field],
            [9, cityscape.common.SymbolKind.Constructor],
            [10, cityscape.common.SymbolKind.Enum],
            [11, cityscape.common.SymbolKind.Interface],
            [12, cityscape.common.SymbolKind.Function],
            [13, cityscape.common.SymbolKind.Variable],
            [14, cityscape.common.SymbolKind.Constant],
            [15, cityscape.common.SymbolKind.String],
            [16, cityscape.common.SymbolKind.Number],
            [17, cityscape.common.SymbolKind.Boolean],
            [18, cityscape.common.SymbolKind.Array],
            [19, cityscape.common.SymbolKind.Object],
            [20, cityscape.common.SymbolKind.Key],
            [21, cityscape.common.SymbolKind.Null],
            [22, cityscape.common.SymbolKind.EnumMember],
            [23, cityscape.common.SymbolKind.Struct],
            [24, cityscape.common.SymbolKind.Event],
            [25, cityscape.common.SymbolKind.Operator],
            [26, cityscape.common.SymbolKind.TypeParameter]
        ];
        assertEquals(26, table.length);
        for (row in table) {
            assertEquals(row[1], (LspConversions.toSymbolKind(row[0]) : Int), 'LSP symbol kind ' + row[0]);
            assertEquals(row[0], LspConversions.fromSymbolKind(row[1]), 'Monaco symbol kind ' + row[1]);
        }
    }

    function testSeverities() {
        assertEquals((MarkerSeverity.Error : Int), (LspConversions.toMarkerSeverity(1) : Int));
        assertEquals((MarkerSeverity.Warning : Int), (LspConversions.toMarkerSeverity(2) : Int));
        assertEquals((MarkerSeverity.Info : Int), (LspConversions.toMarkerSeverity(3) : Int));
        assertEquals((MarkerSeverity.Hint : Int), (LspConversions.toMarkerSeverity(4) : Int));
        assertEquals((MarkerSeverity.Error : Int), (LspConversions.toMarkerSeverity(null) : Int));
        assertEquals(1, LspConversions.fromMarkerSeverity(MarkerSeverity.Error));
        assertEquals(2, LspConversions.fromMarkerSeverity(MarkerSeverity.Warning));
        assertEquals(3, LspConversions.fromMarkerSeverity(MarkerSeverity.Info));
        assertEquals(4, LspConversions.fromMarkerSeverity(MarkerSeverity.Hint));
    }

    //#endregion

    //#region markdown

    function testMarkedStringAndMarkupContent() {
        assertEquals('**bold**', LspConversions.toMarkdownString('**bold**').value);
        assertEquals('```js\nlet x = 1;\n```', LspConversions.toMarkdownString({language: 'js', value: 'let x = 1;'}).value);
        // a fence longer than the backticks of the code
        assertEquals('````\n```\n````', LspConversions.toMarkdownString({language: '', value: '```'}).value);
        assertEquals('# Title', LspConversions.toMarkdownString({kind: 'markdown', value: '# Title'}).value);
        assertEquals('a\\*b\\_c \\> d\n\ne', LspConversions.toMarkdownString({kind: 'plaintext', value: 'a*b_c > d\ne'}).value);

        final contents = LspConversions.toHoverContents(([{language: 'hx', value: 'var x'}, 'text', ''] : Array<Dynamic>));
        assertEquals(2, contents.length);
        assertEquals('```hx\nvar x\n```', contents[0].value);
        assertEquals('text', contents[1].value);
        assertEquals(0, LspConversions.toHoverContents(null).length);

        assertEquals('plain', LspConversions.toDocumentation('plain'));
        assertEquals('plain', LspConversions.toDocumentation({kind: 'plaintext', value: 'plain'}));
        final md:IMarkdownString = cast LspConversions.toDocumentation({kind: 'markdown', value: '*md*'});
        assertEquals('*md*', md.value);
        assertNull(LspConversions.toDocumentation(null));

        assertNull(LspConversions.toHover({contents: []}));
        final hover = LspConversions.toHover({contents: 'x'});
        assertEquals('x', hover.contents[0].value);
        assertNull(hover.range);
    }

    //#endregion

    //#region diagnostics

    function testDiagnostics() {
        final marker = LspConversions.toMarkerData({
            range: lspRange(2, 3, 2, 8),
            severity: 2,
            message: 'careful',
            source: 'lint',
            code: 12,
            tags: [1, 2]
        });
        assertEquals((MarkerSeverity.Warning : Int), (marker.severity : Int));
        assertEquals('careful', marker.message);
        assertEquals('lint', marker.source);
        assertEquals('12', marker.code);
        assertRange(3, 4, 3, 9, marker);
        assertDeepEquals([(MarkerTag.Unnecessary : Int), (MarkerTag.Deprecated : Int)], [for (t in marker.tags) (t : Int)]);

        final withHref = LspConversions.toMarkerData({range: lspRange(0, 0, 0, 1), message: 'm', code: 'C1', codeDescription: {href: 'https://example.com/C1'}});
        assertEquals((MarkerSeverity.Error : Int), (withHref.severity : Int));
        assertEquals('C1', JsValues.field(withHref.code, 'value'));
        final target:Uri = JsValues.field(withHref.code, 'target');
        assertEquals('https://example.com/C1', target.toString());
        assertNull(withHref.source);
        assertNull(withHref.tags);

        // back to LSP
        final diagnostic:Dynamic = LspConversions.toLspDiagnostic(marker);
        assertDeepEquals(lspRange(2, 3, 2, 8), diagnostic.range);
        assertEquals(2, diagnostic.severity);
        assertEquals('careful', diagnostic.message);
        assertEquals('12', diagnostic.code);
        assertEquals('lint', diagnostic.source);
        assertDeepEquals([1, 2], diagnostic.tags);
        final hrefDiagnostic:Dynamic = LspConversions.toLspDiagnostic(withHref);
        assertEquals('C1', hrefDiagnostic.code);
        assertEquals('https://example.com/C1', hrefDiagnostic.codeDescription.href);

        // matching a marker with its diagnostic
        final original:Dynamic = {range: lspRange(2, 3, 2, 8), message: 'careful'};
        assertTrue(LspConversions.markerMatchesDiagnostic(marker, original, false));
        final moved:IMarkerData = {severity: MarkerSeverity.Warning, message: 'careful', startLineNumber: 3, startColumn: 1, endLineNumber: 3, endColumn: 9};
        assertFalse(LspConversions.markerMatchesDiagnostic(moved, original, false));
        assertTrue(LspConversions.markerMatchesDiagnostic(moved, original, true));
        assertFalse(LspConversions.markerMatchesDiagnostic(marker, {range: lspRange(2, 3, 2, 8), message: 'other'}, true));
    }

    //#endregion

    //#region completion

    function testCompletionItems() {
        final list = LspConversions.toCompletionList({
            isIncomplete: true,
            itemDefaults: {
                editRange: {insert: lspRange(0, 0, 0, 2), replace: lspRange(0, 0, 0, 5)},
                insertTextFormat: 2,
                commitCharacters: ['.'],
                data: {shared: true}
            },
            items: ([
                {label: 'withDefaults', textEditText: "a${1:b}"},
                {
                    label: 'full',
                    labelDetails: {detail: '(x)', description: 'module'},
                    kind: 7,
                    insertTextFormat: 1,
                    textEdit: {insert: lspRange(0, 1, 0, 2), replace: lspRange(0, 1, 0, 4), newText: 'fullText'},
                    additionalTextEdits: [{range: lspRange(0, 0, 0, 0), newText: 'import x;\n'}],
                    commitCharacters: [';'],
                    command: {title: 'After', command: 'do.after', arguments: [1]},
                    deprecated: true,
                    preselect: true,
                    sortText: 's',
                    filterText: 'f',
                    documentation: 'docs',
                    data: 5
                }
            ] : Array<Dynamic>)
        });
        assertTrue(list.incomplete);
        assertEquals(2, list.suggestions.length);

        final first = list.suggestions[0];
        assertEquals('withDefaults', first.label);
        assertEquals("a${1:b}", first.insertText);
        assertEquals((CompletionItemInsertTextRule.InsertAsSnippet : Int), (first.insertTextRules : Int));
        final firstRanges:CompletionItemRanges = cast first.range;
        assertRange(1, 1, 1, 3, firstRanges.insert);
        assertRange(1, 1, 1, 6, firstRanges.replace);
        assertDeepEquals(['.'], first.commitCharacters);
        assertEquals((cityscape.common.languages.CompletionItemKind.Property : Int), (first.kind : Int));
        // the default data is sent back on resolve
        assertEquals(true, LspConversions.originalOf(first).data.shared);

        final second = list.suggestions[1];
        final label:CompletionItemLabel = cast second.label;
        assertEquals('full', label.label);
        assertEquals('(x)', label.detail);
        assertEquals('module', label.description);
        assertEquals((cityscape.common.languages.CompletionItemKind.Class : Int), (second.kind : Int));
        assertEquals('fullText', second.insertText);
        assertNull(second.insertTextRules);
        final ranges:CompletionItemRanges = cast second.range;
        assertRange(1, 2, 1, 3, ranges.insert);
        assertRange(1, 2, 1, 5, ranges.replace);
        assertEquals(1, second.additionalTextEdits.length);
        assertRange(1, 1, 1, 1, second.additionalTextEdits[0].range);
        assertEquals('import x;\n', second.additionalTextEdits[0].text);
        assertDeepEquals([';'], second.commitCharacters);
        assertEquals('do.after', second.command.id);
        assertEquals('After', second.command.title);
        assertDeepEquals([1], second.command.arguments);
        assertDeepEquals([(CompletionItemTag.Deprecated : Int)], [for (t in second.tags) (t : Int)]);
        assertEquals(true, second.preselect);
        assertEquals('s', second.sortText);
        assertEquals('f', second.filterText);
        assertEquals('docs', second.documentation);
        assertEquals(5, LspConversions.originalOf(second).data);

        // a plain array of items, without text edit: the label is inserted
        final plain = LspConversions.toCompletionList(([{label: 'x'}] : Array<Dynamic>));
        assertFalse(plain.incomplete == true);
        assertEquals('x', plain.suggestions[0].insertText);
        assertNull(plain.suggestions[0].range);
        assertEquals(0, LspConversions.toCompletionList(null).suggestions.length);

        // the fields of a resolved item
        final fields = LspConversions.toResolvedCompletionFields({label: 'x', detail: 'more', documentation: {kind: 'markdown', value: 'md'}});
        assertEquals('more', fields.detail);
        final documentation:IMarkdownString = cast fields.documentation;
        assertEquals('md', documentation.value);
        assertFalse(Reflect.hasField(fields, 'additionalTextEdits'));
        assertFalse(Reflect.hasField(fields, 'label'));
    }

    //#endregion

    //#region commands, highlights, folding

    /**
     * The well known VS Code commands get Monaco's types; the others keep
     * their JSON arguments.
     */
    function testCommandArguments() {
        final location:Dynamic = {uri: 'file:///a.x', range: lspRange(0, 1, 0, 4)};
        final link:Dynamic = {targetUri: 'file:///b.x', targetRange: lspRange(2, 0, 3, 0), targetSelectionRange: lspRange(2, 4, 2, 6)};
        final position:Dynamic = {line: 3, character: 7};

        final findReferences = LspConversions.toCommand({title: 'refs', command: 'editor.action.findReferences', arguments: (['file:///a.x', position] : Array<Dynamic>)});
        assertTrue(Std.isOfType(findReferences.arguments[0], Uri));
        assertEquals('file:///a.x', (findReferences.arguments[0] : Uri).toString());
        assertTrue(Std.isOfType(findReferences.arguments[1], Position));
        assertEquals(4, (findReferences.arguments[1] : Position).lineNumber);
        assertEquals(8, (findReferences.arguments[1] : Position).column);

        for (id in ['editor.action.showReferences', 'editor.action.peekLocations', 'editor.action.goToLocations']) {
            final original:Array<Dynamic> = ['file:///a.x', position, ([location, link] : Array<Dynamic>), 'goto', 'none', true];
            final command = LspConversions.toCommand({title: 'go', command: id, arguments: original});
            final args = command.arguments;
            assertEquals(6, args.length, id);
            assertTrue(Std.isOfType(args[0], Uri), id);
            assertTrue(Std.isOfType(args[1], Position), id);
            final locations:Array<cityscape.common.Languages.LocationLink> = args[2];
            assertEquals(2, locations.length, id);
            assertEquals('file:///a.x', locations[0].uri.toString());
            assertRange(1, 2, 1, 5, locations[0].range);
            assertEquals('file:///b.x', locations[1].uri.toString());
            assertRange(3, 1, 4, 1, locations[1].range);
            assertRange(3, 5, 3, 7, locations[1].targetSelectionRange);
            assertEquals('goto', args[3]);
            assertEquals('none', args[4]);
            assertEquals(true, args[5]);
            // the LSP command is left as it is
            assertEquals('file:///a.x', original[0]);
            assertEquals(location, original[2][0]);
        }

        // values already converted are kept
        final uri = Uri.parse('file:///c.x');
        final monacoPosition = new Position(2, 3);
        final kept = LspConversions.toCommandArguments('editor.action.showReferences', ([uri, monacoPosition, ([] : Array<Dynamic>)] : Array<Dynamic>));
        assertTrue(kept[0] == uri);
        assertTrue(kept[1] == monacoPosition);

        // other commands keep their JSON arguments
        final other = LspConversions.toCommand({title: 'run', command: 'my.run', arguments: (['file:///a.x', position] : Array<Dynamic>)});
        assertEquals('file:///a.x', other.arguments[0]);
        assertEquals(position, other.arguments[1]);
    }

    function testHighlightAndFoldingKinds() {
        assertEquals(0, (LspConversions.toDocumentHighlightKind(1) : Int));
        assertEquals(1, (LspConversions.toDocumentHighlightKind(2) : Int));
        assertEquals(2, (LspConversions.toDocumentHighlightKind(3) : Int));
        assertEquals(0, (LspConversions.toDocumentHighlightKind(9) : Int));
        assertEquals(0, (LspConversions.toDocumentHighlightKind(null) : Int));
        assertTrue(LspConversions.toFoldingRangeKind('comment') == cityscape.common.Languages.FoldingRangeKind.Comment);
        assertTrue(LspConversions.toFoldingRangeKind('imports') == cityscape.common.Languages.FoldingRangeKind.Imports);
        assertTrue(LspConversions.toFoldingRangeKind('region') == cityscape.common.Languages.FoldingRangeKind.Region);
        assertNull(LspConversions.toFoldingRangeKind('other'));
        assertNull(LspConversions.toFoldingRangeKind(null));
        final range = LspConversions.toFoldingRange({startLine: 0, endLine: 4, startCharacter: 3});
        assertEquals(1, range.start);
        assertEquals(5, range.end);
    }

    function testSemanticTokensResults() {
        final legend = LspConversions.toSemanticTokensLegend({tokenTypes: ['a', 'b'], tokenModifiers: ['m']});
        assertDeepEquals(['a', 'b'], legend.tokenTypes);
        assertDeepEquals(['m'], legend.tokenModifiers);
        final tokens:cityscape.common.Languages.SemanticTokens = LspConversions.toSemanticTokensOrEdits({data: [1, 2, 3, 4, 5]});
        assertEquals(5, tokens.data.length);
        assertEquals(4, tokens.data[3]);
        final edits:cityscape.common.Languages.SemanticTokensEdits = LspConversions.toSemanticTokensOrEdits({resultId: 'x', edits: [{start: 2, deleteCount: 1, data: [9]}]});
        assertEquals('x', edits.resultId);
        assertEquals(9, edits.edits[0].data[0]);
        assertNull(LspConversions.toSemanticTokens(null));
        assertNull(LspConversions.toSemanticTokens({resultId: 'y'}));
    }

    //#endregion

    //#region locations and symbols

    function testDefinitions() {
        final single = LspConversions.toDefinition({uri: 'file:///a.x', range: lspRange(1, 2, 1, 4)});
        assertEquals(1, single.length);
        assertEquals('file:///a.x', single[0].uri.toString());
        assertRange(2, 3, 2, 5, single[0].range);
        assertNull(single[0].targetSelectionRange);

        final links = LspConversions.toDefinition(([{
            targetUri: 'file:///b.x',
            targetRange: lspRange(0, 0, 4, 1),
            targetSelectionRange: lspRange(0, 6, 0, 10),
            originSelectionRange: lspRange(7, 2, 7, 6)
        }] : Array<Dynamic>));
        assertEquals('file:///b.x', links[0].uri.toString());
        assertRange(1, 1, 5, 2, links[0].range);
        assertRange(1, 7, 1, 11, links[0].targetSelectionRange);
        assertRange(8, 3, 8, 7, links[0].originSelectionRange);

        assertEquals(0, LspConversions.toDefinition(null).length);
    }

    function testFlatSymbols() {
        final symbols = LspConversions.toDocumentSymbols(([{
            name: 'helper',
            kind: 12,
            location: {uri: 'file:///a.x', range: lspRange(3, 0, 5, 1)},
            containerName: 'Main',
            tags: [1]
        }] : Array<Dynamic>));
        assertEquals(1, symbols.length);
        final symbol = symbols[0];
        assertEquals('helper', symbol.name);
        assertEquals('', symbol.detail);
        assertEquals((cityscape.common.SymbolKind.Function : Int), (symbol.kind : Int));
        assertEquals('Main', symbol.containerName);
        assertRange(4, 1, 6, 2, symbol.range);
        assertRange(4, 1, 6, 2, symbol.selectionRange);
        assertDeepEquals([(SymbolTag.Deprecated : Int)], [for (t in symbol.tags) (t : Int)]);
        assertNull(symbol.children);
    }

    //#endregion

    //#region code actions and workspace edits

    function testCodeActions() {
        final command = LspConversions.toCodeAction({title: 'Run', command: 'x.run', arguments: ['a']});
        assertEquals('Run', command.title);
        assertEquals('x.run', command.command.id);
        assertDeepEquals(['a'], command.command.arguments);
        assertNull(command.edit);

        final action = LspConversions.toCodeAction({
            title: 'Refactor',
            kind: 'refactor.extract',
            disabled: {reason: 'Nothing selected'},
            diagnostics: [{range: lspRange(0, 0, 0, 1), message: 'm', severity: 3}],
            command: {title: 'Then', command: 'x.then'},
            data: 9
        });
        assertEquals('refactor.extract', action.kind);
        assertEquals('Nothing selected', action.disabled);
        assertEquals((MarkerSeverity.Info : Int), (action.diagnostics[0].severity : Int));
        assertEquals('x.then', action.command.id);
        assertNull(action.isPreferred);
        assertEquals(9, LspConversions.originalOf(action).data);
    }

    function testWorkspaceEditChanges() {
        final changes:Dynamic = {};
        Reflect.setField(changes, 'file:///a.x', [{range: lspRange(0, 0, 0, 1), newText: 'A'}, {range: lspRange(1, 0, 1, 1), newText: 'B'}]);
        Reflect.setField(changes, 'file:///b.x', [{range: lspRange(2, 2, 2, 2), newText: 'C'}]);
        final edit = LspConversions.toWorkspaceEdit({changes: changes});
        assertEquals(3, edit.edits.length);
        final texts = new Map<String, Array<String>>();
        for (e in edit.edits) {
            final textEdit:IWorkspaceTextEdit = cast e;
            final key = textEdit.resource.toString();
            if (!texts.exists(key)) {
                texts.set(key, []);
            }
            texts.get(key).push(textEdit.textEdit.text);
            assertNull(textEdit.versionId);
        }
        assertDeepEquals(['A', 'B'], texts.get('file:///a.x'));
        assertDeepEquals(['C'], texts.get('file:///b.x'));
    }

    function testWorkspaceEditDocumentChanges() {
        final edit = LspConversions.toWorkspaceEdit({
            documentChanges: ([
                {textDocument: {uri: 'file:///a.x', version: 4}, edits: [{range: lspRange(0, 0, 0, 3), newText: 'new'}]},
                {kind: 'create', uri: 'file:///c.x', options: {overwrite: true}},
                {kind: 'rename', oldUri: 'file:///c.x', newUri: 'file:///d.x'},
                {kind: 'delete', uri: 'file:///e.x'},
                {textDocument: {uri: 'file:///d.x', version: null}, edits: [{range: lspRange(0, 0, 0, 0), snippet: {kind: 'snippet', value: "x${1}"}}]}
            ] : Array<Dynamic>),
            // ignored when documentChanges is present
            changes: {}
        });
        assertEquals(5, edit.edits.length);

        final text:IWorkspaceTextEdit = cast edit.edits[0];
        assertEquals('file:///a.x', text.resource.toString());
        assertEquals(4, text.versionId);
        assertEquals('new', text.textEdit.text);
        assertRange(1, 1, 1, 4, text.textEdit.range);

        final create:IWorkspaceFileEdit = cast edit.edits[1];
        assertNull(create.oldResource);
        assertEquals('file:///c.x', create.newResource.toString());
        assertEquals(true, JsValues.field(create.options, 'overwrite'));

        final rename:IWorkspaceFileEdit = cast edit.edits[2];
        assertEquals('file:///c.x', rename.oldResource.toString());
        assertEquals('file:///d.x', rename.newResource.toString());

        final deletion:IWorkspaceFileEdit = cast edit.edits[3];
        assertEquals('file:///e.x', deletion.oldResource.toString());
        assertNull(deletion.newResource);

        final snippet:IWorkspaceTextEdit = cast edit.edits[4];
        assertNull(snippet.versionId);
        assertEquals("x${1}", snippet.textEdit.text);
        assertEquals(true, snippet.textEdit.insertAsSnippet);

        assertEquals(0, LspConversions.toWorkspaceEdit(null).edits.length);
    }

    //#endregion

    //#region signature help

    function testSignatureHelp() {
        assertNull(LspConversions.toSignatureHelp(null));
        assertNull(LspConversions.toSignatureHelp({signatures: []}));
        final help = LspConversions.toSignatureHelp({
            signatures: [{
                label: 'f(x)',
                documentation: {kind: 'markdown', value: '*f*'},
                parameters: [{label: 'x', documentation: 'the x'}],
                activeParameter: 0
            }]
        });
        assertEquals(0, help.activeSignature);
        assertEquals(0, help.activeParameter);
        final documentation:IMarkdownString = cast help.signatures[0].documentation;
        assertEquals('*f*', documentation.value);
        assertEquals('x', help.signatures[0].parameters[0].label);
        assertEquals('the x', help.signatures[0].parameters[0].documentation);
        assertEquals(0, help.signatures[0].activeParameter);

        final back:Dynamic = LspConversions.toLspSignatureHelp(help);
        assertEquals('f(x)', back.signatures[0].label);
        assertEquals('markdown', back.signatures[0].documentation.kind);
        assertEquals('the x', back.signatures[0].parameters[0].documentation);
    }

    //#endregion

}
