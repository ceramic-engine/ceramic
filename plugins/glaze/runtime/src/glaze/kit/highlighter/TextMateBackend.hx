// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/syntect_backend.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic, on TextMate grammars (the `textmate`
// library) instead of syntect. See NOTICE.md.
package glaze.kit.highlighter;

import glaze.HighlightStyle;
import glaze.Range;
import glaze.kit.base.input.HighlightStyleResolver;
import glaze.kit.base.input.StyledRange;
import ropey.Rope;
import textmate.IGrammar;
import textmate.Textmate;

using glaze.kit.base.input.RopeExt;

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
 * It colors the code blocks of `TextView` and the diffs of `DiffView`.
 * gpui-kit's code editor highlighter (an `InputHighlighter`) is not part of
 * Glaze: its code editor is Cityscape (plugin `cityscape`), which tokenizes
 * with the same `textmate` library.
 *
 * Differences with the syntect backend, all additions:
 * - the grammars come from `TextMateGrammars` (bundled tm-grammars files and
 *   registered ones) instead of bat's syntax set;
 * - a line that takes more than `LINE_TIME_LIMIT` ms to tokenize keeps the
 *   tokens found so far and passes its start state on, like VSCode.
 */
class TextMateBackend {

    /** Milliseconds a single line may take to tokenize (VSCode uses the same limit). */
    public static final LINE_TIME_LIMIT:Int = 500;

    /**
     * The limit in use, `LINE_TIME_LIMIT` unless changed (0: no limit). Tests
     * that compare tokens set it to 0 so their results do not depend on the
     * speed of the machine (Mono in the Unity editor goes over the limit on
     * the first lines of large grammars, while their regexes compile).
     */
    @:noCompletion public static var lineTimeLimit:Int = LINE_TIME_LIMIT;

    /** `semanticName` results, by scope ("" for none). */
    static final names:Map<String, String> = new Map();

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
    @:allow(glaze.kit.highlighter, tests)
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
    @:allow(glaze.kit.highlighter)
    static function tokenizeLine(grammar:IGrammar, lineText:String, lineBytes:Int, newlineBytes:Int, state:textmate.IGrammar.StateStack):LineResult {
        final result = grammar.tokenizeLine(lineText, state, lineTimeLimit);
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
    @:allow(glaze.kit.highlighter)
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
     * What `braceFoldRanges` does with one line, reduced: the braces that
     * close a block of an earlier line (`braceCloses`), then the blocks left
     * open at its end (`braceOpens`). A block opened and closed on the same
     * line spans 0 lines and never folds, so only these two counts matter.
     * `line` is the text of the line without its `\n` (a trailing `\r` is
     * ignored like Rust `str::lines`).
     */
    @:allow(glaze.kit.highlighter)
    /**
     * `braceFoldRanges` of the whole text from the reduced braces of its
     * lines (`scanLineBraces`): the same ranges, without converting the
     * text to a string or scanning the lines that did not change.
     */
    @:allow(glaze.kit.highlighter)
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
