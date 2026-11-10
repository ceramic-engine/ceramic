// New code for Cityscape (not a port): conversions between the Language
// Server Protocol types and Monaco's types, both directions.
package cityscape.lsp;

import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.base.common.Uri;
import cityscape.common.Languages.CodeAction;
import cityscape.common.Languages.CodeLens;
import cityscape.common.Languages.CodeActionTriggerType;
import cityscape.common.Languages.Command;
import cityscape.common.Languages.CompletionContext;
import cityscape.common.Languages.CompletionItem;
import cityscape.common.Languages.CompletionItemInsertTextRule;
import cityscape.common.Languages.CompletionItemLabel;
import cityscape.common.Languages.CompletionItemRanges;
import cityscape.common.Languages.CompletionItemTag;
import cityscape.common.Languages.CompletionList;
import cityscape.common.Languages.CompletionTriggerKind;
import cityscape.common.Languages.Definition;
import cityscape.common.Languages.DocumentHighlight;
import cityscape.common.Languages.DocumentHighlightKind;
import cityscape.common.Languages.DocumentSymbol;
import cityscape.common.Languages.FoldingRange;
import cityscape.common.Languages.FoldingRangeKind;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.Languages.Hover;
import cityscape.common.Languages.IColor;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.Languages.IColorPresentation;
import cityscape.common.Languages.ILink;
import cityscape.common.Languages.IWorkspaceFileEdit;
import cityscape.common.Languages.IWorkspaceTextEdit;
import cityscape.common.Languages.IWorkspaceTextEditTextEdit;
import cityscape.common.Languages.InlayHint;
import cityscape.common.Languages.InlayHintLabelPart;
import cityscape.common.Languages.Location;
import cityscape.common.Languages.LocationLink;
import cityscape.common.Languages.ParameterInformation;
import cityscape.common.Languages.SelectionRange;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensEdit;
import cityscape.common.Languages.SemanticTokensEdits;
import cityscape.common.Languages.SemanticTokensLegend;
import cityscape.common.Languages.SignatureHelp;
import cityscape.common.Languages.SignatureHelpContext;
import cityscape.common.Languages.SignatureInformation;
import cityscape.common.Languages.SymbolTag;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Languages.WorkspaceEdit;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Range.IRange;
import cityscape.common.languages.LanguageKinds.InlayHintKind;
import cityscape.platform.markers.common.Markers.IMarkerData;
import cityscape.platform.markers.common.Markers.IRelatedInformation;
import cityscape.platform.markers.common.Markers.MarkerSeverity;
import cityscape.platform.markers.common.Markers.MarkerTag;
import haxe.extern.EitherType;

/**
 * An LSP position: 0 based line, UTF-16 character offset in the line.
 */
typedef LspPosition = {
    var line:Int;
    var character:Int;
}

/**
 * An LSP range (end exclusive).
 */
typedef LspRange = {
    var start:LspPosition;
    var end:LspPosition;
}

/**
 * Conversions between LSP values (parsed JSON: anonymous structures read
 * as `Dynamic`, the JSON boundary) and Monaco's types.
 *
 * Positions: LSP lines and characters start at 0, Monaco's line numbers and
 * columns at 1; both count UTF-16 code units, so a conversion adds or
 * removes 1.
 *
 * The original LSP value of a converted completion item or code action is
 * kept on the Monaco object in the field `ORIGINAL_FIELD` (`_lsp`, set with
 * `Reflect.setField`, read with `originalOf`): `completionItem/resolve` and
 * `codeAction/resolve` send it back to the server.
 */
class LspConversions {

    /**
     * The field of a Monaco completion item or code action holding the LSP
     * item it was converted from.
     */
    public static inline final ORIGINAL_FIELD = '_lsp';

    /**
     * The LSP value a Monaco completion item or code action was converted
     * from (null when it was not).
     */
    public static function originalOf(value:Any):Dynamic {
        return JsValues.field(value, ORIGINAL_FIELD);
    }

    //#region JSON values

    /**
     * A JSON number as an `Int` (`def` when null or not a number).
     */
    public static function asInt(value:Dynamic, def:Int = 0):Int {
        if (value == null || !JsValues.isNumber(value)) {
            return def;
        }
        return Std.int(JsValues.toNumber(value));
    }

    /**
     * A JSON string (null when null or not a string).
     */
    public static function asString(value:Dynamic):Null<String> {
        return JsValues.isString(value) ? (value : String) : null;
    }

    /**
     * A JSON boolean (`def` when null or not a boolean).
     */
    public static function asBool(value:Dynamic, def:Bool = false):Bool {
        return JsValues.isBoolean(value) ? (value : Bool) : def;
    }

    /**
     * A JSON array (null when null or not an array).
     */
    public static function asArray(value:Dynamic):Null<Array<Dynamic>> {
        return JsValues.isArray(value) ? (value : Array<Dynamic>) : null;
    }

    //#endregion

    //#region positions and ranges

    public static function toLspPosition(position:Position):LspPosition {
        return {line: position.lineNumber - 1, character: position.column - 1};
    }

    public static function toLspPositionOf(lineNumber:Int, column:Int):LspPosition {
        return {line: lineNumber - 1, character: column - 1};
    }

    public static function fromLspPosition(position:Dynamic):Position {
        return new Position(asInt(position.line) + 1, asInt(position.character) + 1);
    }

    public static function toLspRange(range:IRange):LspRange {
        return {
            start: {line: range.startLineNumber - 1, character: range.startColumn - 1},
            end: {line: range.endLineNumber - 1, character: range.endColumn - 1}
        };
    }

    /**
     * A Monaco range (1 based) of an LSP range.
     */
    public static function fromLspRange(range:Dynamic):IRange {
        final start:Dynamic = range.start;
        final end:Dynamic = range.end;
        return {
            startLineNumber: asInt(start.line) + 1,
            startColumn: asInt(start.character) + 1,
            endLineNumber: asInt(end.line) + 1,
            endColumn: asInt(end.character) + 1
        };
    }

    //#endregion

    //#region kinds

    /**
     * Monaco's completion item kind of an LSP kind (1 to 25, by name;
     * `Property` when missing).
     */
    public static inline function toCompletionItemKind(lspKind:Null<Int>):cityscape.common.languages.CompletionItemKind {
        return LspKinds.toCompletionItemKind(lspKind);
    }

    public static inline function fromCompletionItemKind(kind:cityscape.common.languages.CompletionItemKind):Int {
        return LspKinds.fromCompletionItemKind(kind);
    }

    /**
     * Monaco's symbol kind of an LSP symbol kind (1 to 26): the LSP value
     * minus one.
     */
    public static inline function toSymbolKind(lspKind:Null<Int>):cityscape.common.SymbolKind {
        return LspKinds.toSymbolKind(lspKind);
    }

    public static inline function fromSymbolKind(kind:cityscape.common.SymbolKind):Int {
        return LspKinds.fromSymbolKind(kind);
    }

    /**
     * Monaco's severity of an LSP diagnostic severity (1 Error, 2 Warning,
     * 3 Information, 4 Hint; Error when missing).
     */
    public static function toMarkerSeverity(lspSeverity:Null<Int>):MarkerSeverity {
        if (lspSeverity == null) {
            return MarkerSeverity.Error;
        }
        return switch lspSeverity {
            case 2: MarkerSeverity.Warning;
            case 3: MarkerSeverity.Info;
            case 4: MarkerSeverity.Hint;
            case _: MarkerSeverity.Error;
        }
    }

    public static function fromMarkerSeverity(severity:MarkerSeverity):Int {
        return switch severity {
            case MarkerSeverity.Warning: 2;
            case MarkerSeverity.Info: 3;
            case MarkerSeverity.Hint: 4;
            case _: 1;
        }
    }

    /**
     * The LSP `CompletionTriggerKind` of Monaco's (Invoke 0 -> 1,
     * TriggerCharacter 1 -> 2, TriggerForIncompleteCompletions 2 -> 3).
     */
    public static function toLspCompletionTriggerKind(kind:CompletionTriggerKind):Int {
        final k:Int = kind;
        return k + 1;
    }

    /**
     * The LSP `CodeActionTriggerKind` of Monaco's trigger (Invoke 1 -> 1,
     * Auto 2 -> 2).
     */
    public static function toLspCodeActionTriggerKind(trigger:CodeActionTriggerType):Int {
        return trigger == CodeActionTriggerType.Auto ? 2 : 1;
    }

    //#endregion

    //#region diagnostics

    /**
     * Monaco's marker data of an LSP diagnostic. `code` is a string, or
     * `{value, target}` when the diagnostic has a `codeDescription.href`.
     */
    public static function toMarkerData(diagnostic:Dynamic):IMarkerData {
        final range = fromLspRange(diagnostic.range);
        final message = asString(diagnostic.message);
        final marker:IMarkerData = {
            severity: toMarkerSeverity(diagnostic.severity == null ? null : asInt(diagnostic.severity, 1)),
            message: message != null ? message : '',
            startLineNumber: range.startLineNumber,
            startColumn: range.startColumn,
            endLineNumber: range.endLineNumber,
            endColumn: range.endColumn
        };
        final code:Dynamic = diagnostic.code;
        if (code != null) {
            final value = JsValues.toJsString(code);
            final description:Dynamic = diagnostic.codeDescription;
            final href = description != null ? asString(description.href) : null;
            if (href != null) {
                marker.code = {value: value, target: Uri.parse(href)};
            }
            else {
                marker.code = value;
            }
        }
        final source = asString(diagnostic.source);
        if (source != null) {
            marker.source = source;
        }
        final tags = asArray(diagnostic.tags);
        if (tags != null && tags.length > 0) {
            final markerTags:Array<MarkerTag> = [];
            for (tag in tags) {
                switch asInt(tag) {
                    case 1: markerTags.push(MarkerTag.Unnecessary);
                    case 2: markerTags.push(MarkerTag.Deprecated);
                    case _:
                }
            }
            if (markerTags.length > 0) {
                marker.tags = markerTags;
            }
        }
        final related = asArray(diagnostic.relatedInformation);
        if (related != null && related.length > 0) {
            final infos:Array<IRelatedInformation> = [];
            for (info in related) {
                final location:Dynamic = info.location;
                if (location == null) {
                    continue;
                }
                final r = fromLspRange(location.range);
                final infoMessage = asString(info.message);
                infos.push({
                    resource: Uri.parse(asString(location.uri)),
                    message: infoMessage != null ? infoMessage : '',
                    startLineNumber: r.startLineNumber,
                    startColumn: r.startColumn,
                    endLineNumber: r.endLineNumber,
                    endColumn: r.endColumn
                });
            }
            marker.relatedInformation = infos;
        }
        return marker;
    }

    /**
     * An LSP diagnostic of a Monaco marker (for markers that do not come
     * from the server).
     */
    public static function toLspDiagnostic(marker:IMarkerData):Dynamic {
        final diagnostic:Dynamic = {
            range: toLspRange({startLineNumber: marker.startLineNumber, startColumn: marker.startColumn, endLineNumber: marker.endLineNumber, endColumn: marker.endColumn}),
            severity: fromMarkerSeverity(marker.severity),
            message: marker.message
        };
        if (marker.code != null) {
            if (JsValues.isString(marker.code)) {
                diagnostic.code = marker.code;
            }
            else {
                diagnostic.code = JsValues.field(marker.code, 'value');
                final target = JsValues.field(marker.code, 'target');
                if (target != null && Std.isOfType(target, Uri)) {
                    final targetUri:Uri = cast target;
                    diagnostic.codeDescription = {href: targetUri.toString()};
                }
            }
        }
        if (marker.source != null) {
            diagnostic.source = marker.source;
        }
        if (marker.tags != null && marker.tags.length > 0) {
            diagnostic.tags = [for (tag in marker.tags) (tag : Int)];
        }
        return diagnostic;
    }

    /**
     * Whether a Monaco marker is the conversion of an LSP diagnostic: same
     * message and same range. With `loose`, the start column is not
     * compared (the marker decorations move the start column of whole line
     * markers).
     */
    public static function markerMatchesDiagnostic(marker:IMarkerData, diagnostic:Dynamic, loose:Bool):Bool {
        if (asString(diagnostic.message) != marker.message) {
            return false;
        }
        final r = fromLspRange(diagnostic.range);
        return r.startLineNumber == marker.startLineNumber
            && r.endLineNumber == marker.endLineNumber
            && r.endColumn == marker.endColumn
            && (loose || r.startColumn == marker.startColumn);
    }

    //#endregion

    //#region markdown

    /**
     * Escapes text for markdown like Monaco's `MarkdownString.appendText`
     * (backslash before the markdown syntax characters and `>`, paragraph
     * breaks for line breaks), without its `&nbsp;` replacement of spaces
     * and tabs: the markdown views of Glaze do not decode HTML entities.
     */
    public static function escapeMarkdown(text:String):String {
        final buf = new StringBuf();
        for (i in 0...text.length) {
            final c = StringTools.fastCodeAt(text, i);
            switch c {
                case '\\'.code | '`'.code | '*'.code | '_'.code | '{'.code | '}'.code | '['.code | ']'.code | '('.code | ')'.code | '#'.code | '+'.code | '-'.code | '!'.code | '~'.code | '>'.code:
                    buf.addChar('\\'.code);
                    buf.addChar(c);
                case '\n'.code:
                    buf.add('\n\n');
                case _:
                    buf.addChar(c);
            }
        }
        return buf.toString();
    }

    /**
     * A fenced code block (Monaco's `appendEscapedMarkdownCodeBlockFence`
     * without the surrounding line breaks): the fence is longer than any
     * run of backticks starting a line of the code.
     */
    public static function codeBlock(language:String, code:String):String {
        var longest = 0;
        var atLineStart = true;
        var run = 0;
        for (i in 0...code.length) {
            final c = StringTools.fastCodeAt(code, i);
            if (atLineStart && c == '`'.code) {
                run++;
                if (run > longest) {
                    longest = run;
                }
                continue;
            }
            atLineStart = c == '\n'.code;
            run = 0;
        }
        final fence = StringTools.lpad('', '`', longest >= 3 ? longest + 1 : 3);
        return fence + language + '\n' + code + '\n' + fence;
    }

    /**
     * Markdown of an LSP `MarkedString` (a markdown string, or
     * `{language, value}` which becomes a fenced code block) or
     * `MarkupContent` (`{kind: 'markdown' | 'plaintext', value}`: plain
     * text is escaped with `escapeMarkdown`).
     */
    public static function toMarkdownString(content:Dynamic):IMarkdownString {
        if (JsValues.isString(content)) {
            return {value: (content : String)};
        }
        final value = asString(content.value);
        final kind = asString(content.kind);
        if (kind != null) {
            if (kind == 'plaintext') {
                return {value: escapeMarkdown(value != null ? value : '')};
            }
            return {value: value != null ? value : ''};
        }
        final language = asString(content.language);
        return {value: codeBlock(language != null ? language : '', value != null ? value : '')};
    }

    /**
     * The hover contents of an LSP `Hover.contents`: `MarkedString`,
     * `MarkedString[]` or `MarkupContent`. Empty strings are dropped.
     */
    public static function toHoverContents(contents:Dynamic):Array<IMarkdownString> {
        final result:Array<IMarkdownString> = [];
        if (contents == null) {
            return result;
        }
        final list = asArray(contents);
        if (list != null) {
            for (item in list) {
                final md = toMarkdownString(item);
                if (md.value.length > 0) {
                    result.push(md);
                }
            }
        }
        else {
            final md = toMarkdownString(contents);
            if (md.value.length > 0) {
                result.push(md);
            }
        }
        return result;
    }

    /**
     * The documentation of a completion item or a signature: a string stays
     * a string, `MarkupContent` gives a string (plain text) or an
     * `IMarkdownString` (markdown).
     */
    public static function toDocumentation(documentation:Dynamic):Null<EitherType<String, IMarkdownString>> {
        if (documentation == null) {
            return null;
        }
        if (JsValues.isString(documentation)) {
            return (documentation : String);
        }
        final value = asString(documentation.value);
        if (asString(documentation.kind) == 'markdown') {
            final md:IMarkdownString = {value: value != null ? value : ''};
            return md;
        }
        return value != null ? value : '';
    }

    /**
     * LSP documentation (`MarkupContent`, or a string) of Monaco's (a string
     * or an `IMarkdownString`).
     */
    public static function toLspDocumentation(documentation:Null<EitherType<String, IMarkdownString>>):Dynamic {
        if (documentation == null) {
            return null;
        }
        if (JsValues.isString(documentation)) {
            return documentation;
        }
        final md:IMarkdownString = cast documentation;
        return {kind: 'markdown', value: md.value};
    }

    //#endregion

    //#region edits and commands

    public static function toTextEdit(edit:Dynamic):TextEdit {
        final text = asString(edit.newText);
        return {range: fromLspRange(edit.range), text: text != null ? text : ''};
    }

    public static function toTextEdits(edits:Dynamic):Array<TextEdit> {
        final list = asArray(edits);
        return list == null ? [] : [for (edit in list) toTextEdit(edit)];
    }

    public static function toSingleEditOperation(edit:Dynamic):ISingleEditOperation {
        final text = asString(edit.newText);
        return {range: fromLspRange(edit.range), text: text != null ? text : ''};
    }

    public static function toLspTextEdit(edit:TextEdit):Dynamic {
        return {range: toLspRange(edit.range), newText: edit.text};
    }

    /**
     * Monaco's command of an LSP `Command` (`{title, command, arguments}`).
     */
    public static function toCommand(command:Dynamic):Null<Command> {
        if (command == null) {
            return null;
        }
        final id = asString(command.command);
        if (id == null) {
            return null;
        }
        final title = asString(command.title);
        final result:Command = {id: id, title: title != null ? title : ''};
        final args = asArray(command.arguments);
        if (args != null) {
            result.arguments = toCommandArguments(id, args);
        }
        return result;
    }

    /**
     * The arguments of a command sent by the server, for the editor: the
     * well known VS Code commands taking Monaco's types get them
     * (`editor.action.findReferences (uri, position)`,
     * `editor.action.showReferences`, `editor.action.peekLocations`
     * `(uri, position, locations, multiple?)` and
     * `editor.action.goToLocations (uri, position, locations, multiple?,
     * noResultsMessage?, openInPeek?)`): the uri string becomes a `Uri`, the
     * LSP position a `Position`, the LSP locations (`Location` or
     * `LocationLink`) `LocationLink`s. Values already converted, and the
     * arguments of the other commands (the server's own, run with
     * `workspace/executeCommand`), are kept as they are. The returned array
     * is a new one when something was converted.
     */
    public static function toCommandArguments(id:String, args:Array<Dynamic>):Array<Any> {
        switch id {
            case 'editor.action.findReferences' | 'editor.action.showReferences' | 'editor.action.peekLocations' | 'editor.action.goToLocations':
            case _:
                return cast args;
        }
        final result:Array<Any> = cast args.copy();
        if (result.length > 0 && JsValues.isString(result[0])) {
            result[0] = Uri.parse((result[0] : String));
        }
        if (result.length > 1 && isLspPosition(result[1])) {
            result[1] = fromLspPosition(result[1]);
        }
        if (id != 'editor.action.findReferences' && result.length > 2) {
            final locations = asArray(result[2]);
            if (locations != null) {
                final converted:Array<LocationLink> = [];
                for (location in locations) {
                    converted.push(isLspLocation(location) ? toLocationLink(location) : location);
                }
                result[2] = converted;
            }
        }
        return result;
    }

    /**
     * Whether a value is an LSP position (`{line, character}`).
     */
    public static function isLspPosition(value:Dynamic):Bool {
        return value != null && JsValues.isObject(value) && JsValues.isNumber(JsValues.field(value, 'line')) && JsValues.isNumber(JsValues.field(value, 'character'));
    }

    /**
     * Whether a value is an LSP `Location` (`{uri: string, range}`) or
     * `LocationLink` (`{targetUri: string, targetRange}`).
     */
    public static function isLspLocation(value:Dynamic):Bool {
        if (value == null || !JsValues.isObject(value)) {
            return false;
        }
        if (JsValues.isString(JsValues.field(value, 'targetUri'))) {
            return true;
        }
        final range:Dynamic = JsValues.field(value, 'range');
        return JsValues.isString(JsValues.field(value, 'uri')) && range != null && JsValues.isObject(range) && isLspPosition(JsValues.field(range, 'start'));
    }

    public static function toLspCommand(command:Command):Dynamic {
        final result:Dynamic = {title: command.title, command: command.id};
        if (command.arguments != null) {
            result.arguments = command.arguments;
        }
        return result;
    }

    /**
     * Monaco's workspace edit of an LSP `WorkspaceEdit`: `documentChanges`
     * when present (text document edits with their version, and file
     * operations `create`, `rename`, `delete` as `IWorkspaceFileEdit`s),
     * `changes` otherwise. A snippet text edit (`{range, snippet: {value}}`)
     * gives an edit inserted as a snippet.
     */
    public static function toWorkspaceEdit(edit:Dynamic):WorkspaceEdit {
        final result:WorkspaceEdit = {edits: []};
        if (edit == null) {
            return result;
        }
        final documentChanges = asArray(edit.documentChanges);
        if (documentChanges != null) {
            for (change in documentChanges) {
                final kind = asString(change.kind);
                if (kind != null) {
                    final fileEdit:IWorkspaceFileEdit = {};
                    switch kind {
                        case 'create':
                            fileEdit.newResource = Uri.parse(asString(change.uri));
                        case 'rename':
                            fileEdit.oldResource = Uri.parse(asString(change.oldUri));
                            fileEdit.newResource = Uri.parse(asString(change.newUri));
                        case 'delete':
                            fileEdit.oldResource = Uri.parse(asString(change.uri));
                        case _:
                            continue;
                    }
                    if (change.options != null) {
                        fileEdit.options = change.options;
                    }
                    result.edits.push(fileEdit);
                    continue;
                }
                final textDocument:Dynamic = change.textDocument;
                if (textDocument == null) {
                    continue;
                }
                final resource = Uri.parse(asString(textDocument.uri));
                final version:Null<Int> = textDocument.version == null ? null : asInt(textDocument.version);
                final edits = asArray(change.edits);
                if (edits != null) {
                    for (e in edits) {
                        result.edits.push(toWorkspaceTextEdit(resource, e, version));
                    }
                }
            }
            return result;
        }
        final changes:Dynamic = edit.changes;
        if (changes != null) {
            for (uri in Reflect.fields(changes)) {
                final resource = Uri.parse(uri);
                final edits = asArray(Reflect.field(changes, uri));
                if (edits != null) {
                    for (e in edits) {
                        result.edits.push(toWorkspaceTextEdit(resource, e, null));
                    }
                }
            }
        }
        return result;
    }

    static function toWorkspaceTextEdit(resource:Uri, edit:Dynamic, versionId:Null<Int>):IWorkspaceTextEdit {
        final textEdit:IWorkspaceTextEditTextEdit = {range: fromLspRange(edit.range), text: ''};
        final snippet:Dynamic = edit.snippet;
        if (snippet != null) {
            final value = asString(snippet.value);
            textEdit.text = value != null ? value : '';
            textEdit.insertAsSnippet = true;
        }
        else {
            final text = asString(edit.newText);
            textEdit.text = text != null ? text : '';
        }
        return {resource: resource, textEdit: textEdit, versionId: versionId};
    }

    //#endregion

    //#region completion

    /**
     * Monaco's completion list of an LSP completion result
     * (`CompletionItem[]`, `CompletionList` or null). The `itemDefaults` of
     * a list (`editRange`, `insertTextFormat`, `commitCharacters`, `data`)
     * apply to the items that do not set them.
     */
    public static function toCompletionList(result:Dynamic):CompletionList {
        final list:CompletionList = {suggestions: []};
        if (result == null) {
            return list;
        }
        var items = asArray(result);
        var defaults:Dynamic = null;
        if (items == null) {
            items = asArray(result.items);
            defaults = result.itemDefaults;
            if (asBool(result.isIncomplete)) {
                list.incomplete = true;
            }
        }
        if (items != null) {
            for (item in items) {
                list.suggestions.push(toCompletionItem(item, defaults));
            }
        }
        return list;
    }

    static function toCompletionRange(range:Dynamic):Null<EitherType<IRange, CompletionItemRanges>> {
        if (range == null) {
            return null;
        }
        if (range.insert != null && range.replace != null) {
            final ranges:CompletionItemRanges = {insert: fromLspRange(range.insert), replace: fromLspRange(range.replace)};
            return ranges;
        }
        if (range.range != null) {
            return fromLspRange(range.range);
        }
        if (range.start != null) {
            return fromLspRange(range);
        }
        return null;
    }

    /**
     * Monaco's completion item of an LSP completion item (`defaults`: the
     * `itemDefaults` of its list, or null). The LSP item is kept in
     * `ORIGINAL_FIELD` for `completionItem/resolve`.
     */
    public static function toCompletionItem(item:Dynamic, ?defaults:Dynamic):CompletionItem {
        final labelText = asString(item.label);
        final labelString = labelText != null ? labelText : '';
        var label:EitherType<String, CompletionItemLabel> = labelString;
        final labelDetails:Dynamic = item.labelDetails;
        if (labelDetails != null) {
            final l:CompletionItemLabel = {label: labelString};
            final detail = asString(labelDetails.detail);
            if (detail != null) {
                l.detail = detail;
            }
            final description = asString(labelDetails.description);
            if (description != null) {
                l.description = description;
            }
            label = l;
        }

        // the text to insert and its range
        final textEdit:Dynamic = item.textEdit;
        final itemInsertText = asString(item.insertText);
        var insertText:String = itemInsertText != null ? itemInsertText : labelString;
        var range:Null<EitherType<IRange, CompletionItemRanges>> = null;
        if (textEdit != null) {
            final newText = asString(textEdit.newText);
            if (newText != null) {
                insertText = newText;
            }
            range = toCompletionRange(textEdit);
        }
        else if (defaults != null && defaults.editRange != null) {
            final textEditText = asString(item.textEditText);
            if (textEditText != null) {
                insertText = textEditText;
            }
            range = toCompletionRange(defaults.editRange);
        }

        final result:CompletionItem = {
            label: label,
            kind: toCompletionItemKind(item.kind == null ? null : asInt(item.kind, 1)),
            insertText: insertText
        };
        if (range != null) {
            result.range = range;
        }

        var insertTextFormat:Dynamic = item.insertTextFormat;
        if (insertTextFormat == null && defaults != null) {
            insertTextFormat = defaults.insertTextFormat;
        }
        if (asInt(insertTextFormat, 1) == 2) {
            result.insertTextRules = CompletionItemInsertTextRule.InsertAsSnippet;
        }

        final detail = asString(item.detail);
        if (detail != null) {
            result.detail = detail;
        }
        final documentation = toDocumentation(item.documentation);
        if (documentation != null) {
            result.documentation = documentation;
        }
        final sortText = asString(item.sortText);
        if (sortText != null) {
            result.sortText = sortText;
        }
        final filterText = asString(item.filterText);
        if (filterText != null) {
            result.filterText = filterText;
        }
        if (asBool(item.preselect)) {
            result.preselect = true;
        }

        var tags:Null<Array<CompletionItemTag>> = null;
        final lspTags = asArray(item.tags);
        if (lspTags != null) {
            for (tag in lspTags) {
                if (asInt(tag) == 1) {
                    tags = [CompletionItemTag.Deprecated];
                }
            }
        }
        if (tags == null && asBool(item.deprecated)) {
            tags = [CompletionItemTag.Deprecated];
        }
        if (tags != null) {
            result.tags = tags;
        }

        var commitCharacters = asArray(item.commitCharacters);
        if (commitCharacters == null && defaults != null) {
            commitCharacters = asArray(defaults.commitCharacters);
        }
        if (commitCharacters != null) {
            result.commitCharacters = [for (c in commitCharacters) Std.string(c)];
        }

        final additionalTextEdits = asArray(item.additionalTextEdits);
        if (additionalTextEdits != null) {
            result.additionalTextEdits = [for (edit in additionalTextEdits) toSingleEditOperation(edit)];
        }

        final command = toCommand(item.command);
        if (command != null) {
            result.command = command;
        }

        if (item.data == null && defaults != null && defaults.data != null) {
            item.data = defaults.data;
        }
        Reflect.setField(result, ORIGINAL_FIELD, item);
        return result;
    }

    /**
     * The fields a resolved LSP completion item adds to a Monaco item
     * (`detail`, `documentation`, `additionalTextEdits`, `command`; only
     * the ones the resolved item has), with the resolved LSP item in
     * `ORIGINAL_FIELD`. Monaco's suggest widget copies them into the item.
     */
    public static function toResolvedCompletionFields(resolved:Dynamic):CompletionItem {
        final fields:Dynamic = {};
        final detail = asString(resolved.detail);
        if (detail != null) {
            fields.detail = detail;
        }
        final documentation = toDocumentation(resolved.documentation);
        if (documentation != null) {
            fields.documentation = documentation;
        }
        final additionalTextEdits = asArray(resolved.additionalTextEdits);
        if (additionalTextEdits != null) {
            fields.additionalTextEdits = [for (edit in additionalTextEdits) toSingleEditOperation(edit)];
        }
        final command = toCommand(resolved.command);
        if (command != null) {
            fields.command = command;
        }
        Reflect.setField(fields, ORIGINAL_FIELD, resolved);
        return fields;
    }

    /**
     * The LSP `CompletionContext` of Monaco's.
     */
    public static function toLspCompletionContext(context:CompletionContext):Dynamic {
        final result:Dynamic = {triggerKind: toLspCompletionTriggerKind(context.triggerKind)};
        if (context.triggerCharacter != null) {
            result.triggerCharacter = context.triggerCharacter;
        }
        return result;
    }

    //#endregion

    //#region hover, definition, symbols

    /**
     * Monaco's hover of an LSP hover (null when it has no content).
     */
    public static function toHover(hover:Dynamic):Null<Hover> {
        if (hover == null) {
            return null;
        }
        final contents = toHoverContents(hover.contents);
        if (contents.length == 0) {
            return null;
        }
        final result:Hover = {contents: contents};
        if (hover.range != null) {
            result.range = fromLspRange(hover.range);
        }
        return result;
    }

    /**
     * Monaco's location link of an LSP `Location` (`{uri, range}`) or
     * `LocationLink` (`{targetUri, targetRange, targetSelectionRange,
     * originSelectionRange}`).
     */
    public static function toLocationLink(location:Dynamic):LocationLink {
        final targetUri = asString(location.targetUri);
        if (targetUri != null) {
            final link:LocationLink = {uri: Uri.parse(targetUri), range: fromLspRange(location.targetRange)};
            if (location.targetSelectionRange != null) {
                link.targetSelectionRange = fromLspRange(location.targetSelectionRange);
            }
            if (location.originSelectionRange != null) {
                link.originSelectionRange = fromLspRange(location.originSelectionRange);
            }
            return link;
        }
        return {uri: Uri.parse(asString(location.uri)), range: fromLspRange(location.range)};
    }

    /**
     * Monaco's definition of an LSP result (`Location`, `Location[]`,
     * `LocationLink[]` or null).
     */
    public static function toDefinition(result:Dynamic):Definition {
        if (result == null) {
            return [];
        }
        final list = asArray(result);
        if (list == null) {
            return [toLocationLink(result)];
        }
        return [for (location in list) toLocationLink(location)];
    }

    static function toSymbolTags(symbol:Dynamic):Array<SymbolTag> {
        final tags:Array<SymbolTag> = [];
        final lspTags = asArray(symbol.tags);
        if (lspTags != null) {
            for (tag in lspTags) {
                if (asInt(tag) == 1) {
                    tags.push(SymbolTag.Deprecated);
                }
            }
        }
        if (tags.length == 0 && asBool(symbol.deprecated)) {
            tags.push(SymbolTag.Deprecated);
        }
        return tags;
    }

    /**
     * Monaco's document symbol of an LSP `DocumentSymbol` (hierarchical) or
     * `SymbolInformation` (flat: its location's range is both ranges).
     */
    public static function toDocumentSymbol(symbol:Dynamic):DocumentSymbol {
        final name = asString(symbol.name);
        final detail = asString(symbol.detail);
        final location:Dynamic = symbol.location;
        final range = location != null ? fromLspRange(location.range) : fromLspRange(symbol.range);
        final selectionRange = location != null ? range : (symbol.selectionRange != null ? fromLspRange(symbol.selectionRange) : range);
        final result:DocumentSymbol = {
            name: name != null ? name : '',
            detail: detail != null ? detail : '',
            kind: toSymbolKind(symbol.kind == null ? null : asInt(symbol.kind)),
            tags: toSymbolTags(symbol),
            range: range,
            selectionRange: selectionRange
        };
        final containerName = asString(symbol.containerName);
        if (containerName != null) {
            result.containerName = containerName;
        }
        final children = asArray(symbol.children);
        if (children != null) {
            result.children = [for (child in children) toDocumentSymbol(child)];
        }
        return result;
    }

    /**
     * Monaco's document symbols of an LSP result (`DocumentSymbol[]`,
     * `SymbolInformation[]` or null).
     */
    public static function toDocumentSymbols(result:Dynamic):Array<DocumentSymbol> {
        final list = asArray(result);
        return list == null ? [] : [for (symbol in list) toDocumentSymbol(symbol)];
    }

    //#endregion

    //#region code actions

    /**
     * Monaco's code action of an LSP `CodeAction` or `Command` (a bare
     * command becomes an action running it). The LSP value is kept in
     * `ORIGINAL_FIELD` for `codeAction/resolve`.
     */
    public static function toCodeAction(action:Dynamic):CodeAction {
        final title = asString(action.title);
        final result:CodeAction = {title: title != null ? title : ''};
        if (JsValues.isString(action.command)) {
            // a Command
            result.command = toCommand(action);
            Reflect.setField(result, ORIGINAL_FIELD, action);
            return result;
        }
        final kind = asString(action.kind);
        if (kind != null) {
            result.kind = kind;
        }
        final diagnostics = asArray(action.diagnostics);
        if (diagnostics != null) {
            result.diagnostics = [for (d in diagnostics) toMarkerData(d)];
        }
        if (JsValues.isBoolean(action.isPreferred)) {
            result.isPreferred = (action.isPreferred : Bool);
        }
        final disabled:Dynamic = action.disabled;
        if (disabled != null) {
            final reason = asString(disabled.reason);
            result.disabled = reason != null ? reason : '';
        }
        if (action.edit != null) {
            result.edit = toWorkspaceEdit(action.edit);
        }
        final command = toCommand(action.command);
        if (command != null) {
            result.command = command;
        }
        Reflect.setField(result, ORIGINAL_FIELD, action);
        return result;
    }

    //#endregion

    //#region signature help

    static function toParameterInformation(parameter:Dynamic):ParameterInformation {
        final label:Dynamic = parameter.label;
        final offsets = asArray(label);
        final result:ParameterInformation = {
            label: offsets != null ? ([for (o in offsets) asInt(o)] : EitherType<String, Array<Int>>) : ((JsValues.isString(label) ? (label : String) : '') : EitherType<String, Array<Int>>)
        };
        final documentation = toDocumentation(parameter.documentation);
        if (documentation != null) {
            result.documentation = documentation;
        }
        return result;
    }

    static function toSignatureInformation(signature:Dynamic):SignatureInformation {
        final label = asString(signature.label);
        final parameters = asArray(signature.parameters);
        final result:SignatureInformation = {
            label: label != null ? label : '',
            parameters: parameters == null ? [] : [for (p in parameters) toParameterInformation(p)]
        };
        final documentation = toDocumentation(signature.documentation);
        if (documentation != null) {
            result.documentation = documentation;
        }
        if (signature.activeParameter != null) {
            result.activeParameter = asInt(signature.activeParameter);
        }
        return result;
    }

    /**
     * Monaco's signature help of an LSP `SignatureHelp` (null when null or
     * without signatures). Missing active signature and parameter are 0.
     */
    public static function toSignatureHelp(help:Dynamic):Null<SignatureHelp> {
        if (help == null) {
            return null;
        }
        final signatures = asArray(help.signatures);
        if (signatures == null || signatures.length == 0) {
            return null;
        }
        return {
            signatures: [for (s in signatures) toSignatureInformation(s)],
            activeSignature: asInt(help.activeSignature, 0),
            activeParameter: asInt(help.activeParameter, 0)
        };
    }

    /**
     * The LSP `SignatureHelp` of Monaco's (for the active signature help
     * of a retrigger).
     */
    public static function toLspSignatureHelp(help:SignatureHelp):Dynamic {
        return {
            signatures: [for (s in help.signatures) toLspSignatureInformation(s)],
            activeSignature: help.activeSignature,
            activeParameter: help.activeParameter
        };
    }

    static function toLspSignatureInformation(signature:SignatureInformation):Dynamic {
        final result:Dynamic = {
            label: signature.label,
            parameters: [for (p in signature.parameters) toLspParameterInformation(p)]
        };
        if (signature.documentation != null) {
            result.documentation = toLspDocumentation(signature.documentation);
        }
        if (signature.activeParameter != null) {
            result.activeParameter = signature.activeParameter;
        }
        return result;
    }

    static function toLspParameterInformation(parameter:ParameterInformation):Dynamic {
        final result:Dynamic = {label: parameter.label};
        if (parameter.documentation != null) {
            result.documentation = toLspDocumentation(parameter.documentation);
        }
        return result;
    }

    /**
     * The LSP `SignatureHelpContext` of Monaco's (the trigger kinds have
     * the same values).
     */
    public static function toLspSignatureHelpContext(context:SignatureHelpContext):Dynamic {
        final result:Dynamic = {
            triggerKind: (context.triggerKind : Int),
            isRetrigger: context.isRetrigger
        };
        if (context.triggerCharacter != null) {
            result.triggerCharacter = context.triggerCharacter;
        }
        if (context.activeSignatureHelp != null) {
            result.activeSignatureHelp = toLspSignatureHelp(context.activeSignatureHelp);
        }
        return result;
    }

    //#endregion

    //#region references, highlights, rename

    /**
     * Monaco's location of an LSP `Location` (`{uri, range}`).
     */
    public static function toLocation(location:Dynamic):Location {
        return {uri: Uri.parse(asString(location.uri)), range: fromLspRange(location.range)};
    }

    /**
     * Monaco's locations of an LSP `Location[]` (null when the result is
     * not an array, like vscode-languageclient's `asReferences`).
     */
    public static function toLocations(result:Dynamic):Null<Array<Location>> {
        final list = asArray(result);
        return list == null ? null : [for (location in list) toLocation(location)];
    }

    /**
     * Monaco's highlight kind of an LSP `DocumentHighlightKind`: the LSP
     * kinds start at 1 (Text 1, Read 2, Write 3), Monaco's at 0; an unknown
     * kind is Text.
     */
    public static function toDocumentHighlightKind(lspKind:Null<Int>):DocumentHighlightKind {
        return switch lspKind {
            case 2: DocumentHighlightKind.Read;
            case 3: DocumentHighlightKind.Write;
            case _: DocumentHighlightKind.Text;
        }
    }

    /**
     * Monaco's highlight of an LSP `DocumentHighlight` (the kind only when
     * the LSP highlight has one, like vscode-languageclient).
     */
    public static function toDocumentHighlight(highlight:Dynamic):DocumentHighlight {
        final result:DocumentHighlight = {range: fromLspRange(highlight.range)};
        if (JsValues.isNumber(highlight.kind)) {
            result.kind = toDocumentHighlightKind(asInt(highlight.kind));
        }
        return result;
    }

    public static function toDocumentHighlights(result:Dynamic):Null<Array<DocumentHighlight>> {
        final list = asArray(result);
        return list == null ? null : [for (highlight in list) toDocumentHighlight(highlight)];
    }

    /**
     * Monaco's rename location of an LSP `prepareRename` result, like
     * vscode-languageclient and vscode's extension host together: a `Range`
     * (its text in the model is the placeholder), `{range, placeholder}`,
     * or `{defaultBehavior: true}` and null-like answers (null: Monaco then
     * renames the word at the position). `{defaultBehavior: false}`, a
     * result of another shape, an empty placeholder or a range not on the
     * line of `position` reject the rename: the location has a
     * `rejectReason` ("The element can't be renamed.").
     */
    public static function toRenameLocation(result:Dynamic, model:cityscape.common.Model.ITextModel, position:Position):Null<cityscape.common.Languages.RenameLocation> {
        if (result == null) {
            return rejectedRenameLocation(position, null);
        }
        var range:Null<IRange> = null;
        var text:Null<String> = null;
        if (isLspRange(result)) {
            range = fromLspRange(result);
            text = model.getValueInRange(range);
        }
        else if (JsValues.isBoolean(JsValues.field(result, 'defaultBehavior'))) {
            if ((JsValues.field(result, 'defaultBehavior') : Bool)) {
                return null;
            }
            return rejectedRenameLocation(position, null);
        }
        else if (isLspRange(result.range)) {
            range = fromLspRange(result.range);
            text = asString(result.placeholder);
        }
        else {
            return rejectedRenameLocation(position, null);
        }
        if (text == null || text.length == 0) {
            return null;
        }
        if (range.startLineNumber > position.lineNumber || range.endLineNumber < position.lineNumber) {
            // vscode's extension host: "INVALID rename location"
            return null;
        }
        return {range: range, text: text};
    }

    /**
     * A rename location rejecting the rename at `position` (`reason`, or
     * "The element can't be renamed.").
     */
    public static function rejectedRenameLocation(position:Position, reason:Null<String>):cityscape.common.Languages.RenameLocation {
        return {
            range: Range.fromPositions(position),
            text: '',
            rejectReason: reason != null && reason.length > 0 ? reason : "The element can't be renamed."
        };
    }

    /**
     * Whether a value is an LSP range (`{start, end}` positions).
     */
    public static function isLspRange(value:Dynamic):Bool {
        return value != null && JsValues.isObject(value) && isLspPosition(JsValues.field(value, 'start')) && isLspPosition(JsValues.field(value, 'end'));
    }

    //#endregion

    //#region folding, selection ranges

    /**
     * Monaco's folding range kind of an LSP kind: `comment`, `imports`,
     * `region`; null for the others (vscode-languageclient's
     * `asFoldingRangeKind`).
     */
    public static function toFoldingRangeKind(kind:Null<String>):Null<FoldingRangeKind> {
        return switch kind {
            case 'comment': FoldingRangeKind.Comment;
            case 'imports': FoldingRangeKind.Imports;
            case 'region': FoldingRangeKind.Region;
            case _: null;
        }
    }

    /**
     * Monaco's folding range of an LSP `FoldingRange`: LSP lines start at 0,
     * Monaco's at 1 (vscode's `FoldingRange.from` adds 1 to the 0 based
     * lines of the extension API).
     */
    public static function toFoldingRange(range:Dynamic):FoldingRange {
        final result:FoldingRange = {start: asInt(range.startLine) + 1, end: asInt(range.endLine) + 1};
        final kind = toFoldingRangeKind(asString(range.kind));
        if (kind != null) {
            result.kind = kind;
        }
        return result;
    }

    public static function toFoldingRanges(result:Dynamic):Null<Array<FoldingRange>> {
        final list = asArray(result);
        return list == null ? null : [for (range in list) toFoldingRange(range)];
    }

    /**
     * Monaco's selection ranges of an LSP `SelectionRange[]` (one chain of
     * `{range, parent}` per position): for each position, the ranges from
     * the innermost one out, like vscode's extension host. Null when a
     * parent does not contain its child (vscode rejects the result).
     */
    public static function toSelectionRanges(result:Dynamic):Null<Array<Array<SelectionRange>>> {
        final list = asArray(result);
        if (list == null) {
            return [];
        }
        final all:Array<Array<SelectionRange>> = [];
        for (chain in list) {
            final ranges:Array<SelectionRange> = [];
            var current:Dynamic = chain;
            var last:Null<Range> = null;
            while (current != null) {
                final range = Range.lift(fromLspRange(current.range));
                if (last != null && !range.containsRange(last)) {
                    return null;
                }
                ranges.push({range: range});
                last = range;
                current = current.parent;
            }
            all.push(ranges);
        }
        return all;
    }

    //#endregion

    //#region inlay hints, code lenses, links, colors

    /**
     * A tooltip: a string stays a string, `MarkupContent` gives an
     * `IMarkdownString` (plain text escaped, vscode-languageclient's
     * `asTooltip`).
     */
    public static function toTooltip(tooltip:Dynamic):Null<EitherType<String, IMarkdownString>> {
        if (tooltip == null) {
            return null;
        }
        if (JsValues.isString(tooltip)) {
            return (tooltip : String);
        }
        return toMarkdownString(tooltip);
    }

    /**
     * Monaco's label part of an LSP `InlayHintLabelPart` (`value` is
     * Monaco's `label`).
     */
    public static function toInlayHintLabelPart(part:Dynamic):InlayHintLabelPart {
        final value = asString(part.value);
        final result:InlayHintLabelPart = {label: value != null ? value : ''};
        if (part.tooltip != null) {
            result.tooltip = toTooltip(part.tooltip);
        }
        if (part.location != null) {
            result.location = toLocation(part.location);
        }
        if (part.command != null) {
            final command = toCommand(part.command);
            if (command != null) {
                result.command = command;
            }
        }
        return result;
    }

    /**
     * Monaco's inlay hint of an LSP `InlayHint` (the kinds have the same
     * values: Type 1, Parameter 2), null for a hint vscode drops (an empty
     * label, an empty list of parts or a part without text). The LSP hint
     * is kept in `ORIGINAL_FIELD` for `inlayHint/resolve`.
     */
    public static function toInlayHint(hint:Dynamic):Null<InlayHint> {
        var label:EitherType<String, Array<InlayHintLabelPart>>;
        final text = asString(hint.label);
        if (text != null) {
            if (text.length == 0) {
                return null;
            }
            label = text;
        }
        else {
            final parts = asArray(hint.label);
            if (parts == null || parts.length == 0) {
                return null;
            }
            final converted = [for (part in parts) toInlayHintLabelPart(part)];
            for (part in converted) {
                if (part.label.length == 0) {
                    return null;
                }
            }
            label = converted;
        }
        final result:InlayHint = {label: label, position: fromLspPosition(hint.position)};
        if (JsValues.isNumber(hint.kind)) {
            final kind = asInt(hint.kind);
            if (kind == 1 || kind == 2) {
                result.kind = (kind : InlayHintKind);
            }
        }
        if (hint.tooltip != null) {
            result.tooltip = toTooltip(hint.tooltip);
        }
        final textEdits = asArray(hint.textEdits);
        if (textEdits != null) {
            result.textEdits = [for (edit in textEdits) toTextEdit(edit)];
        }
        if (JsValues.isBoolean(hint.paddingLeft)) {
            result.paddingLeft = (hint.paddingLeft : Bool);
        }
        if (JsValues.isBoolean(hint.paddingRight)) {
            result.paddingRight = (hint.paddingRight : Bool);
        }
        Reflect.setField(result, ORIGINAL_FIELD, hint);
        return result;
    }

    public static function toInlayHints(result:Dynamic):Null<Array<InlayHint>> {
        final list = asArray(result);
        if (list == null) {
            return null;
        }
        final hints:Array<InlayHint> = [];
        for (item in list) {
            final hint = toInlayHint(item);
            if (hint != null) {
                hints.push(hint);
            }
        }
        return hints;
    }

    /**
     * Monaco's code lens of an LSP `CodeLens` (`{range, command, data}`),
     * the LSP lens kept in `ORIGINAL_FIELD` for `codeLens/resolve`.
     */
    public static function toCodeLens(lens:Dynamic):CodeLens {
        final result:CodeLens = {range: fromLspRange(lens.range)};
        final command = toCommand(lens.command);
        if (command != null) {
            result.command = command;
        }
        Reflect.setField(result, ORIGINAL_FIELD, lens);
        return result;
    }

    public static function toCodeLenses(result:Dynamic):Null<Array<CodeLens>> {
        final list = asArray(result);
        return list == null ? null : [for (lens in list) toCodeLens(lens)];
    }

    /**
     * Monaco's link of an LSP `DocumentLink` (`{range, target, tooltip,
     * data}`; the target becomes a `Uri`), the LSP link kept in
     * `ORIGINAL_FIELD` for `documentLink/resolve`.
     */
    public static function toLink(link:Dynamic):ILink {
        final result:ILink = {range: fromLspRange(link.range)};
        final target = asString(link.target);
        if (target != null && target.length > 0) {
            result.url = Uri.parse(target);
        }
        final tooltip = asString(link.tooltip);
        if (tooltip != null) {
            result.tooltip = tooltip;
        }
        Reflect.setField(result, ORIGINAL_FIELD, link);
        return result;
    }

    public static function toLinks(result:Dynamic):Null<Array<ILink>> {
        final list = asArray(result);
        return list == null ? null : [for (link in list) toLink(link)];
    }

    /**
     * Monaco's color of an LSP `Color` (both RGBA in [0, 1]).
     */
    public static function toColor(color:Dynamic):IColor {
        return {
            red: JsValues.toNumber(color.red),
            green: JsValues.toNumber(color.green),
            blue: JsValues.toNumber(color.blue),
            alpha: JsValues.toNumber(color.alpha)
        };
    }

    public static function toLspColor(color:IColor):Dynamic {
        return {red: color.red, green: color.green, blue: color.blue, alpha: color.alpha};
    }

    public static function toColorInformation(info:Dynamic):IColorInformation {
        return {range: fromLspRange(info.range), color: toColor(info.color)};
    }

    public static function toColorInformations(result:Dynamic):Null<Array<IColorInformation>> {
        final list = asArray(result);
        return list == null ? null : [for (info in list) toColorInformation(info)];
    }

    /**
     * Monaco's color presentation of an LSP `ColorPresentation`
     * (`{label, textEdit, additionalTextEdits}`).
     */
    public static function toColorPresentation(presentation:Dynamic):IColorPresentation {
        final label = asString(presentation.label);
        final result:IColorPresentation = {label: label != null ? label : ''};
        if (presentation.textEdit != null) {
            result.textEdit = toTextEdit(presentation.textEdit);
        }
        final additional = asArray(presentation.additionalTextEdits);
        if (additional != null) {
            result.additionalTextEdits = [for (edit in additional) toTextEdit(edit)];
        }
        return result;
    }

    public static function toColorPresentations(result:Dynamic):Null<Array<IColorPresentation>> {
        final list = asArray(result);
        return list == null ? null : [for (presentation in list) toColorPresentation(presentation)];
    }

    //#endregion

    //#region semantic tokens

    /**
     * Monaco's legend of an LSP `SemanticTokensLegend` (`{tokenTypes,
     * tokenModifiers}`).
     */
    public static function toSemanticTokensLegend(legend:Dynamic):SemanticTokensLegend {
        final types = legend != null ? asArray(legend.tokenTypes) : null;
        final modifiers = legend != null ? asArray(legend.tokenModifiers) : null;
        return {
            tokenTypes: types == null ? [] : [for (t in types) Std.string(t)],
            tokenModifiers: modifiers == null ? [] : [for (m in modifiers) Std.string(m)]
        };
    }

    static function toUInt32Array(data:Array<Dynamic>):haxe.io.UInt32Array {
        final result = new haxe.io.UInt32Array(data.length);
        for (i in 0...data.length) {
            result[i] = asInt(data[i]);
        }
        return result;
    }

    /**
     * Monaco's semantic tokens of an LSP `SemanticTokens` (`{resultId,
     * data}`), null when null or without data.
     */
    public static function toSemanticTokens(result:Dynamic):Null<SemanticTokens> {
        if (result == null) {
            return null;
        }
        final data = asArray(result.data);
        if (data == null) {
            return null;
        }
        final resultId = asString(result.resultId);
        if (resultId != null) {
            return {resultId: resultId, data: toUInt32Array(data)};
        }
        return {data: toUInt32Array(data)};
    }

    /**
     * Monaco's semantic token edits of an LSP `SemanticTokensDelta`
     * (`{resultId, edits: [{start, deleteCount, data}]}`).
     */
    public static function toSemanticTokensEdits(result:Dynamic):Null<SemanticTokensEdits> {
        if (result == null) {
            return null;
        }
        final list = asArray(result.edits);
        if (list == null) {
            return null;
        }
        final edits:Array<SemanticTokensEdit> = [];
        for (edit in list) {
            final data = asArray(edit.data);
            if (data != null) {
                edits.push({start: asInt(edit.start), deleteCount: asInt(edit.deleteCount), data: toUInt32Array(data)});
            }
            else {
                edits.push({start: asInt(edit.start), deleteCount: asInt(edit.deleteCount)});
            }
        }
        final resultId = asString(result.resultId);
        if (resultId != null) {
            return {resultId: resultId, edits: edits};
        }
        return {edits: edits};
    }

    /**
     * Monaco's answer to a semantic tokens request: an LSP `SemanticTokens`
     * (it has `data`) or `SemanticTokensDelta` (it has `edits`).
     */
    public static function toSemanticTokensOrEdits(result:Dynamic):Null<EitherType<SemanticTokens, SemanticTokensEdits>> {
        if (result == null) {
            return null;
        }
        if (asArray(result.edits) != null && asArray(result.data) == null) {
            return toSemanticTokensEdits(result);
        }
        return toSemanticTokens(result);
    }

    //#endregion

    //#region formatting

    public static function toLspFormattingOptions(options:FormattingOptions):Dynamic {
        return {tabSize: options.tabSize, insertSpaces: options.insertSpaces};
    }

    //#endregion

}
