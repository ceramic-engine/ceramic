// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/syntect_backend.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic, on TextMate grammars (the `textmate`
// library) instead of syntect. See NOTICE.md.
package gpui.component.highlighter;

import gpui.Context;
import gpui.HighlightStyle;
import gpui.Range;
import gpui.Task;
import gpui.Window;
import gpui.base.input.FoldRange;
import gpui.base.input.HighlightStyleResolver;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputEdit;
import gpui.base.input.InputHighlighter;
import gpui.base.input.InputHighlighterFactory;
import gpui.base.input.StyledRange;
import ropey.Rope;
import textmate.IGrammar;
import textmate.Textmate;

using gpui.base.input.RopeExt;

/**
 * A highlight name over a byte range (Rust tuple `(Range<usize>, &'static str)`).
 */
class Highlight {

    public var start:Int;

    public var end:Int;

    public final name:String;

    public inline function new(start:Int, end:Int, name:String) {
        this.start = start;
        this.end = end;
        this.name = name;
    }

    public function equals(other:Highlight):Bool {
        return other != null && other.start == start && other.end == end && other.name == name;
    }

    public function toString():String {
        return '($start..$end, $name)';
    }

}

/**
 * A highlight name over a byte range, for presentations that resolve styles
 * later (Rust tuple `(Range<usize>, SharedString)`).
 */
class CaptureName {

    public final range:Range;

    public final name:String;

    public inline function new(range:Range, name:String) {
        this.range = range;
        this.name = name;
    }

}

/**
 * The resolved grammar of a language (Rust `&'static SyntaxReference`).
 */
class Syntax {

    public final info:GrammarInfo;

    public final grammar:IGrammar;

    public function new(info:GrammarInfo, grammar:IGrammar) {
        this.info = info;
        this.grammar = grammar;
    }

}

/**
 * Syntax highlighting from TextMate grammars.
 *
 * gpui-kit's lighter highlighter (`syntect_backend.rs`) names what syntect
 * matched with TextMate scopes and maps them onto the highlight names the
 * theme already defines. The port keeps that design on top of the
 * `textmate` library (vscode-textmate 9.2.0 with the pure Haxe Oniguruma
 * port): the grammars are the TextMate grammars VSCode and shiki use, the
 * scopes are mapped by the same rules (`semanticName`), and the colors keep
 * following the application's `HighlightTheme`.
 *
 * Differences with the syntect backend, all additions:
 * - the grammars come from `TextMateGrammars` (bundled tm-grammars files and
 *   registered ones) instead of bat's syntax set;
 * - the editor highlighter keeps the tokenizer state of every line and only
 *   tokenizes the lines an edit changed, until the state of the next line is
 *   the one it had before (VSCode's approach), instead of reparsing the whole
 *   document; documents above `SYNC_PARSE_MAX_BYTES` are tokenized after a
 *   debounce like the original, still incrementally;
 * - a line that takes more than `LINE_TIME_LIMIT` ms to tokenize keeps the
 *   tokens found so far and passes its start state on, like VSCode.
 */
class TextMateBackend {

    /**
     * Documents up to this size are retokenized on the keystroke; larger ones
     * keep their shifted highlights until a deferred tokenization catches up.
     */
    public static final SYNC_PARSE_MAX_BYTES:Int = 64 * 1024;

    /** Seconds. */
    public static final PARSE_DEBOUNCE:Float = 0.15;

    /** Milliseconds a single line may take to tokenize (VSCode uses the same limit). */
    public static final LINE_TIME_LIMIT:Int = 500;

    /** `semanticName` results, by scope ("" for none). */
    static final names:Map<String, String> = new Map();

    public static function inputHighlighterFactory():InputHighlighterFactory {
        return language -> {
            final syntax = findSyntax(language);
            return syntax != null ? (new TextMateInputHighlighter(language, syntax) : InputHighlighter) : null;
        };
    }

    /**
     * Styles for one code block of a text view, or nothing for a language
     * no grammar knows.
     */
    public static function highlightCode(language:String, code:String, resolver:HighlightStyleResolver):Array<StyledRange> {
        final syntax = findSyntax(language);
        if (syntax == null) {
            return [];
        }
        return resolveStyles(parse(syntax, code), new Range(0, utf8Length(code)), resolver);
    }

    /** Highlight names for `text`, for presentations that resolve styles later. */
    public static function captureNames(language:String, text:String):Array<CaptureName> {
        final syntax = findSyntax(language);
        if (syntax == null) {
            return [];
        }
        return [for (highlight in parse(syntax, text)) new CaptureName(new Range(highlight.start, highlight.end), highlight.name)];
    }

    /**
     * The grammar for a code fence or editor language name.
     *
     * A token is matched against the names, aliases and file extensions of
     * the grammars (syntect matches extensions and syntax names). Most of the
     * names the rest of the library uses are already one of those; the few
     * that are not are spelled here the way the grammars know them.
     */
    public static function findSyntax(language:String):Null<Syntax> {
        final canonical = LanguageName.languageName(language);
        final alias = switch canonical {
            case "text": return null;
            case "csharp": "cs";
            case "make": "Makefile";
            case "markdown_inline": "md";
            case "embedded_template" | "ejs": "erb";
            case other: other;
        }
        for (token in [language, canonical, alias]) {
            final info = TextMateGrammars.findByToken(token);
            if (info != null) {
                final grammar = TextMateGrammars.grammar(info);
                return grammar != null ? new Syntax(info, grammar) : null;
            }
        }
        return null;
    }

    /** Runs the grammar over `text` and keeps the spans that map to a highlight name. */
    @:allow(gpui.component.highlighter, tests)
    static function parse(syntax:Syntax, text:String):Array<Highlight> {
        final highlights:Array<Highlight> = [];
        var state = Textmate.INITIAL;
        var offset = 0;
        var start = 0;
        final length = text.length;
        while (start <= length) {
            var end = text.indexOf('\n', start);
            final last = end < 0;
            if (last)
                end = length;
            final line = text.substring(start, end);
            if (last && line.length == 0)
                break;
            final lineBytes = utf8Length(line);
            final result = tokenizeLine(syntax.grammar, line, lineBytes, last ? 0 : 1, state);
            appendHighlights(highlights, result.highlights, offset);
            state = result.endState;
            offset += lineBytes + (last ? 0 : 1);
            if (last)
                break;
            start = end + 1;
        }
        return highlights;
    }

    /**
     * Tokenizes one line (`lineText` without its `\n`) from `state`. The
     * highlights are relative to the start of the line; like syntect's lines
     * with endings, the newline (`newlineBytes`) belongs to the last token.
     */
    @:allow(gpui.component.highlighter)
    static function tokenizeLine(grammar:IGrammar, lineText:String, lineBytes:Int, newlineBytes:Int, state:textmate.IGrammar.StateStack):LineResult {
        final result = grammar.tokenizeLine(lineText, state, LINE_TIME_LIMIT);
        final highlights:Array<Highlight> = [];
        final tokens = result.tokens;
        final utf16Length = lineText.length;
        final map = lineBytes == utf16Length ? null : utf16ToUtf8Map(lineText);
        inline function byteAt(index:Int):Int {
            return map == null ? index : map[index];
        }
        for (i in 0...tokens.length) {
            final token = tokens[i];
            var tokenStart = token.startIndex;
            var tokenEnd = token.endIndex;
            if (tokenStart > utf16Length)
                tokenStart = utf16Length;
            if (tokenEnd > utf16Length)
                tokenEnd = utf16Length;
            final startByte = byteAt(tokenStart);
            final endByte = i == tokens.length - 1 ? lineBytes + newlineBytes : byteAt(tokenEnd);
            push(highlights, startByte, endByte, token.scopes);
        }
        // A line that ran out of time keeps the state it started with, so
        // the next line starts over from it rather than from a partial state.
        return new LineResult(highlights, result.stoppedEarly ? state : result.ruleStack);
    }

    /**
     * Rust `push` of `parse`: the innermost scope that names something wins,
     * so the quotes of a string (`punctuation.definition.string` inside
     * `string`) color as the string rather than as punctuation.
     */
    static function push(highlights:Array<Highlight>, start:Int, end:Int, scopes:Array<String>):Void {
        if (end <= start) {
            return;
        }
        var name:Null<String> = null;
        var i = scopes.length - 1;
        while (i >= 0) {
            final scope = scopes[i];
            var cached = names.get(scope);
            if (cached == null) {
                final semantic = semanticName(scope);
                cached = semantic == null ? "" : semantic;
                names.set(scope, cached);
            }
            if (cached.length > 0) {
                name = cached;
                break;
            }
            i--;
        }
        if (name != null) {
            final last = highlights.length > 0 ? highlights[highlights.length - 1] : null;
            if (last != null && last.end == start && last.name == name) {
                last.end = end;
            }
            else {
                highlights.push(new Highlight(start, end, name));
            }
        }
    }

    /** Appends line highlights shifted by `offset`, merging with the previous one like `push`. */
    @:allow(gpui.component.highlighter)
    static function appendHighlights(into:Array<Highlight>, lineHighlights:Array<Highlight>, offset:Int):Void {
        for (highlight in lineHighlights) {
            final start = highlight.start + offset;
            final end = highlight.end + offset;
            final last = into.length > 0 ? into[into.length - 1] : null;
            if (last != null && last.end == start && last.name == highlight.name) {
                last.end = end;
            }
            else {
                into.push(new Highlight(start, end, highlight.name));
            }
        }
    }

    /**
     * The theme's highlight name for a TextMate scope, or null to let an
     * enclosing scope decide.
     */
    public static function semanticName(scope:String):Null<String> {
        inline function is(prefix:String):Bool {
            return scope == prefix || (StringTools.startsWith(scope, prefix) && scope.charCodeAt(prefix.length) == '.'.code);
        }

        if (is("punctuation.definition.string") || is("punctuation.definition.comment") || is("invalid") || is("meta") || is("source")
            || is("text")) {
            // Delimiters belong to what they delimit; the rest are containers
            // with no color of their own.
            return null;
        }
        else if (is("comment.block.documentation") || is("comment.line.documentation")) {
            return "comment.doc";
        }
        else if (is("comment")) {
            return "comment";
        }
        else if (is("constant.character.escape")) {
            return "string.escape";
        }
        else if (is("string.regexp")) {
            return "string.regex";
        }
        else if (is("string")) {
            return "string";
        }
        else if (is("constant.numeric")) {
            return "number";
        }
        else if (is("constant.language.boolean")) {
            return "boolean";
        }
        else if (is("constant") || is("support.constant") || is("entity.name.constant")) {
            return "constant";
        }
        else if (is("keyword.operator")) {
            return "operator";
        }
        else if (is("keyword.control.import") || is("meta.preprocessor")) {
            return "preproc";
        }
        else if (is("keyword") || is("storage.modifier")) {
            return "keyword";
        }
        else if (is("storage.type")) {
            // `fn`, `class` and `let` are declarations, `int` and `bool` are types.
            for (word in [
                "class", "enum", "function", "impl", "interface", "module", "namespace", "struct", "trait", "type", "let", "var", "const"
            ]) {
                if (scope.indexOf(word) >= 0)
                    return "keyword";
            }
            return "type";
        }
        else if (is("entity.name.function") || is("support.function") || is("variable.function") || is("meta.function-call")) {
            return "function";
        }
        else if (is("entity.name.type") || is("entity.name.class") || is("entity.name.struct") || is("entity.name.enum")
            || is("entity.name.trait") || is("entity.name.interface") || is("entity.other.inherited-class") || is("support.type")
            || is("support.class")) {
            return "type";
        }
        else if (is("entity.name.tag")) {
            return "tag";
        }
        else if (is("entity.other.attribute-name")) {
            return "attribute";
        }
        else if (is("entity.name.label")) {
            return "label";
        }
        else if (is("entity.name.section") || is("markup.heading")) {
            return "title";
        }
        else if (is("variable.language")) {
            return "variable.special";
        }
        else if (is("variable.other.member") || is("variable.other.property") || is("support.variable.property") || is("meta.mapping.key")) {
            return "property";
        }
        else if (is("variable")) {
            return "variable";
        }
        else if (is("markup.bold")) {
            return "emphasis.strong";
        }
        else if (is("markup.italic")) {
            return "emphasis";
        }
        else if (is("markup.underline.link")) {
            return "link_uri";
        }
        else if (is("markup.raw")) {
            return "text.literal";
        }
        else if (is("markup.list")) {
            return "punctuation.list_marker";
        }
        else if (is("punctuation.section") || is("punctuation.definition.block")) {
            return "punctuation.bracket";
        }
        else if (is("punctuation.separator") || is("punctuation.terminator")) {
            return "punctuation.delimiter";
        }
        else if (is("punctuation")) {
            return "punctuation";
        }
        else {
            return null;
        }
    }

    /**
     * Turns the highlights overlapping `range` into gap-free style runs.
     *
     * `highlights` is ordered and non-overlapping, so the first candidate is
     * found by binary search instead of scanning the whole document on every
     * frame.
     */
    public static function resolveStyles(highlights:Array<Highlight>, range:Range, resolver:HighlightStyleResolver):Array<StyledRange> {
        // Rust `partition_point(|h| h.end <= range.start)`.
        var lo = 0;
        var hi = highlights.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (highlights[mid].end <= range.start)
                lo = mid + 1;
            else
                hi = mid;
        }
        final runs:Array<StyledRange> = [];
        var cursor = range.start;

        for (i in lo...highlights.length) {
            final highlight = highlights[i];
            if (highlight.start >= range.end) {
                break;
            }
            final start = highlight.start > range.start ? highlight.start : range.start;
            final end = highlight.end < range.end ? highlight.end : range.end;
            if (start >= end || end <= cursor) {
                continue;
            }
            if (cursor < start) {
                runs.push(new StyledRange(new Range(cursor, start), new HighlightStyle()));
            }
            final style = resolver.style(highlight.name);
            runs.push(new StyledRange(new Range(start, end), style != null ? style : new HighlightStyle()));
            cursor = end;
        }

        if (cursor < range.end) {
            runs.push(new StyledRange(new Range(cursor, range.end), new HighlightStyle()));
        }
        return runs;
    }

    /**
     * Moves the highlights after an edit by its length and drops the ones it
     * touched, so the text that did not change keeps its colors while a
     * deferred tokenization catches up.
     */
    public static function shift(highlights:Array<Highlight>, edit:InputEdit):Void {
        final delta = edit.newEndByte - edit.oldEndByte;
        var write = 0;
        for (read in 0...highlights.length) {
            final highlight = highlights[read];
            if (highlight.end <= edit.startByte) {
                highlights[write++] = highlight;
            }
            else if (highlight.start >= edit.oldEndByte) {
                highlight.start = saturatingAdd(highlight.start, delta);
                highlight.end = saturatingAdd(highlight.end, delta);
                highlights[write++] = highlight;
            }
        }
        highlights.resize(write);
    }

    static inline function saturatingAdd(value:Int, delta:Int):Int {
        final result = value + delta;
        return result < 0 ? 0 : result;
    }

    /**
     * Fold candidates from matching braces outside strings and line comments.
     *
     * Without a syntax tree this is the structure most languages share; a
     * language that nests by indentation alone gets no candidates.
     */
    public static function braceFoldRanges(text:String):Array<FoldRange> {
        final starts:Array<Int> = [];
        final ranges:Array<FoldRange> = [];

        // Rust `str::lines`: split at `\n`, a trailing `\r` dropped, no
        // empty last line after a final newline.
        final lines = text.split('\n');
        if (lines.length > 0 && lines[lines.length - 1].length == 0)
            lines.pop();
        for (lineNumber in 0...lines.length) {
            var line = lines[lineNumber];
            if (StringTools.endsWith(line, '\r'))
                line = line.substr(0, line.length - 1);
            var quote:Int = -1;
            var escaped = false;
            var i = 0;
            final length = line.length;
            while (i < length) {
                final character = line.charCodeAt(i);
                i++;
                if (quote >= 0) {
                    if (escaped) {
                        escaped = false;
                    }
                    else if (character == '\\'.code) {
                        escaped = true;
                    }
                    else if (character == quote) {
                        quote = -1;
                    }
                }
                else {
                    if (character == '/'.code && i < length && line.charCodeAt(i) == '/'.code) {
                        break;
                    }
                    else if (character == '#'.code) {
                        break;
                    }
                    else if (character == '"'.code || character == '\''.code || character == '`'.code) {
                        quote = character;
                    }
                    else if (character == '{'.code) {
                        starts.push(lineNumber);
                    }
                    else if (character == '}'.code) {
                        final start = starts.pop();
                        if (start != null && lineNumber - start >= 2) {
                            ranges.push(new FoldRange(start, lineNumber));
                        }
                    }
                }
            }
        }
        // Rust `sort_by_key` (stable) then `dedup_by_key` on the start line.
        haxe.ds.ArraySort.sort(ranges, (a, b) -> a.startLine - b.startLine);
        final result:Array<FoldRange> = [];
        for (range in ranges) {
            if (result.length == 0 || result[result.length - 1].startLine != range.startLine)
                result.push(range);
        }
        return result;
    }

    /** The UTF-8 length of a string. */
    public static function utf8Length(text:String):Int {
        var bytes = 0;
        var i = 0;
        final length = text.length;
        while (i < length) {
            final c = text.charCodeAt(i);
            if (c < 0x80) {
                bytes += 1;
            }
            else if (c < 0x800) {
                bytes += 2;
            }
            else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < length) {
                final next = text.charCodeAt(i + 1);
                if (next >= 0xDC00 && next <= 0xDFFF) {
                    bytes += 4;
                    i++;
                }
                else {
                    bytes += 3;
                }
            }
            else {
                bytes += 3;
            }
            i++;
        }
        return bytes;
    }

    /**
     * The UTF-8 offset of every UTF-16 offset of `text` (`text.length + 1`
     * entries; the low half of a surrogate pair maps to the start of its
     * character).
     */
    static function utf16ToUtf8Map(text:String):Array<Int> {
        final length = text.length;
        final map:Array<Int> = [];
        map.resize(length + 1);
        var bytes = 0;
        var i = 0;
        while (i < length) {
            map[i] = bytes;
            final c = text.charCodeAt(i);
            if (c < 0x80) {
                bytes += 1;
            }
            else if (c < 0x800) {
                bytes += 2;
            }
            else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < length) {
                final next = text.charCodeAt(i + 1);
                if (next >= 0xDC00 && next <= 0xDFFF) {
                    map[i + 1] = bytes;
                    bytes += 4;
                    i++;
                }
                else {
                    bytes += 3;
                }
            }
            else {
                bytes += 3;
            }
            i++;
        }
        map[length] = bytes;
        return map;
    }

}

/**
 * The highlights of one line (relative to its start) and the tokenizer
 * state at its end.
 */
class LineResult {

    public final highlights:Array<Highlight>;

    public final endState:textmate.IGrammar.StateStack;

    public inline function new(highlights:Array<Highlight>, endState:textmate.IGrammar.StateStack) {
        this.highlights = highlights;
        this.endState = endState;
    }

}

/**
 * What the editor highlighter keeps for each line.
 */
private class LineInfo {

    /** Bytes of the line, with its `\n` when it has one. */
    public var bytes:Int;

    /** Whether `highlights` and `endState` were computed from the current text of the line. */
    public var valid:Bool = false;

    /** The state the line was tokenized from. */
    public var startState:Null<textmate.IGrammar.StateStack> = null;

    public var endState:Null<textmate.IGrammar.StateStack> = null;

    public var highlights:Array<Highlight> = [];

    public function new(bytes:Int) {
        this.bytes = bytes;
    }

}

/**
 * The code editor's highlighter (Rust `SyntectInputHighlighter`).
 */
class TextMateInputHighlighter extends InputHighlighterBase {

    final _language:String;

    final syntax:Syntax;

    var lines:Array<LineInfo> = [];

    /** The start offset of every line, rebuilt after a change of the lines. */
    var lineStarts:Null<Array<Int>> = null;

    var folds:Array<FoldRange> = [];

    var parseTask:Null<gpui.AnyTask> = null;

    /** Lines tokenized by the last update (for tests and measurements). */
    @:allow(gpui.component.highlighter, tests)
    var lastTokenizedLines:Int = 0;

    public function new(language:String, syntax:Syntax) {
        this._language = language;
        this.syntax = syntax;
    }

    public function language():String {
        return _language;
    }

    public function update(edit:Null<InputEdit>, text:Rope, folding:Bool, window:Window, cx:Context<InputBaseState>):Void {
        if (edit != null && lines.length > 0) {
            applyEdit(edit, text);
        }
        else {
            reset(text);
        }

        if (text.len() <= TextMateBackend.SYNC_PARSE_MAX_BYTES) {
            // Only the lines the edit changed are tokenized again, up to the
            // first line whose start state did not change.
            cancelTask();
            tokenize(text);
            folds = folding ? TextMateBackend.braceFoldRanges(text.toString()) : [];
            return;
        }

        final snapshot = text.clone();
        // Replacing the task cancels a tokenization still waiting out its debounce.
        cancelTask();
        parseTask = cx.spawn((entity, acx) -> acx.backgroundExecutor().timer(TextMateBackend.PARSE_DEBOUNCE).then(_ -> {
            tokenize(snapshot);
            final folded = folding ? TextMateBackend.braceFoldRanges(snapshot.toString()) : [];
            folds = folded;
            entity.tryUpdate(acx, (state, cx) -> {
                state.applyHighlighterFoldCandidates(folded, cx);
            });
        }));
    }

    public function styles(range:Range, resolver:HighlightStyleResolver):Array<StyledRange> {
        return TextMateBackend.resolveStyles(highlightsIn(range), range, resolver);
    }

    public function foldRanges(_:Rope):Array<FoldRange> {
        return [for (fold in folds) fold.copy()];
    }

    /**
     * The highlights of the lines overlapping `range`, absolute and merged
     * across lines like a whole-document parse would give them.
     */
    @:allow(gpui.component.highlighter, tests)
    function highlightsIn(range:Range):Array<Highlight> {
        final starts = ensureLineStarts();
        final result:Array<Highlight> = [];
        // The last line starting at or before `range.start`.
        var lo = 0;
        var hi = starts.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (starts[mid] <= range.start)
                lo = mid + 1;
            else
                hi = mid;
        }
        var row = lo > 0 ? lo - 1 : 0;
        // One line back, so a highlight continued from the previous line merges.
        if (row > 0)
            row--;
        while (row < lines.length && starts[row] < range.end) {
            TextMateBackend.appendHighlights(result, lines[row].highlights, starts[row]);
            row++;
        }
        return result;
    }

    function ensureLineStarts():Array<Int> {
        if (lineStarts == null) {
            final starts:Array<Int> = [];
            starts.resize(lines.length);
            var offset = 0;
            for (i in 0...lines.length) {
                starts[i] = offset;
                offset += lines[i].bytes;
            }
            lineStarts = starts;
        }
        return lineStarts;
    }

    function cancelTask():Void {
        if (parseTask != null) {
            parseTask.cancel();
            parseTask = null;
        }
    }

    /** Forgets every line: the whole text is tokenized again. */
    function reset(text:Rope):Void {
        final count = text.linesLen();
        lines = [for (row in 0...count) new LineInfo(lineBytes(text, row, count))];
        lineStarts = null;
    }

    /**
     * Replaces the lines an edit touched by placeholders for the new lines.
     * The other lines keep their highlights (relative to their start), so
     * the text that did not change keeps its colors.
     */
    function applyEdit(edit:InputEdit, text:Rope):Void {
        final count = text.linesLen();
        final startRow = edit.startPosition.row;
        final oldEndRow = edit.oldEndPosition.row;
        final newEndRow = edit.newEndPosition.row;
        if (startRow > lines.length || oldEndRow >= lines.length || count - (newEndRow - startRow + 1) != lines.length - (oldEndRow - startRow + 1)) {
            // The edit does not match what this highlighter saw: start over.
            reset(text);
            return;
        }
        final replacement = [for (row in startRow...newEndRow + 1) new LineInfo(lineBytes(text, row, count))];
        final removed = oldEndRow - startRow + 1;
        lines = lines.slice(0, startRow).concat(replacement).concat(lines.slice(startRow + removed));
        // The line that became the last one has lost its newline (or the
        // previous last one gained one): recompute its length.
        final last = lines.length - 1;
        for (row in (last > 0 ? last - 1 : 0)...last + 1) {
            final bytes = lineBytes(text, row, count);
            if (lines[row].bytes != bytes) {
                lines[row].bytes = bytes;
                lines[row].valid = false;
            }
        }
        lineStarts = null;
    }

    static function lineBytes(text:Rope, row:Int, count:Int):Int {
        return text.lineLen(row) + (row < count - 1 ? 1 : 0);
    }

    /**
     * Tokenizes the lines that are not valid, and the following lines while
     * their start state changed.
     */
    function tokenize(text:Rope):Void {
        final count = lines.length;
        var tokenized = 0;
        var row = 0;
        var state:textmate.IGrammar.StateStack = Textmate.INITIAL;
        while (row < count) {
            final line = lines[row];
            if (line.valid && line.startState != null && line.startState.equals(state)) {
                // Up to date: skip to the next line that is not.
                var next = row + 1;
                while (next < count && lines[next].valid)
                    next++;
                if (next >= count)
                    break;
                row = next;
                state = lines[row - 1].endState;
                continue;
            }
            final lineText = text.sliceLine(row).toString();
            final newline = row < count - 1 ? 1 : 0;
            final result = TextMateBackend.tokenizeLine(syntax.grammar, lineText, line.bytes - newline, newline, state);
            line.startState = state;
            line.endState = result.endState;
            line.highlights = result.highlights;
            line.valid = true;
            state = result.endState;
            tokenized++;
            row++;
        }
        lastTokenizedLines = tokenized;
    }

}
