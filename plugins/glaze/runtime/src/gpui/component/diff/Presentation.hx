// Ported from gpui-kit 0.8.1: crates/component/src/diff/presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.HighlightStyle;
import gpui.Range;
import gpui.base.input.HighlightStyleResolver;
import gpui.component.highlighter.LanguageName;
import gpui.component.highlighter.SyntaxHighlighter;
import gpui.util.Utf8;
import ropey.Rope;
import similar.ChangeTag;
import similar.DiffableStr;
import similar.TextDiff;

/**
 * Settings that determine prepared presentation.
 */
@:allow(gpui.component.diff)
class PresentationOptions {

    public var inlineUnit:Null<DiffInlineUnit>;

    public var inlineMaxLineLength:Int;

    public var syntaxMaxLineLength:Int;

    public function new(inlineUnit:Null<DiffInlineUnit>, inlineMaxLineLength:Int, syntaxMaxLineLength:Int) {
        this.inlineUnit = inlineUnit;
        this.inlineMaxLineLength = inlineMaxLineLength;
        this.syntaxMaxLineLength = syntaxMaxLineLength;
    }

    public function copy():PresentationOptions {
        return new PresentationOptions(inlineUnit, inlineMaxLineLength, syntaxMaxLineLength);
    }

}

/**
 * A range of a text and its style, as returned by an application highlighter.
 */
class DiffStyledRange {

    public final range:Range;

    public final style:HighlightStyle;

    public function new(range:Range, style:HighlightStyle) {
        this.range = range;
        this.style = style;
    }

}

/**
 * The application's highlighter, set with `DiffState.withSyntaxHighlighter`:
 * given a language and a text, byte ranges into the text with their styles.
 */
typedef DiffSyntaxHighlighter = (language:String, text:String) -> Array<DiffStyledRange>;

/**
 * What a syntax span is painted with: a highlight name (resolved against
 * the theme when the line paints), or a style the application's highlighter
 * returned.
 */
@:allow(gpui.component.diff)
private class SyntaxPaint {

    final name:Int;

    final style:Null<HighlightStyle>;

    function new(name:Int, style:Null<HighlightStyle>) {
        this.name = name;
        this.style = style;
    }

}

/**
 * Byte ranges relative to each line's source start, with a payload.
 */
@:allow(gpui.component.diff)
private class LineSpans<T> {

    /** `starts[ix]..starts[ix + 1]` index the spans of line `ix`. */
    final starts:Array<Int> = [];

    final ranges:Array<Range> = [];

    final payloads:Array<T> = [];

    function new() {}

    static function fromLines<T>(perLine:Array<Array<{range:Range, payload:T}>>):LineSpans<T> {
        final spans = new LineSpans<T>();
        spans.starts.push(0);
        for (line in perLine) {
            for (span in line) {
                spans.ranges.push(span.range);
                spans.payloads.push(span.payload);
            }
            spans.starts.push(spans.ranges.length);
        }
        return spans;
    }

    function lineStart(ix:Int):Int {
        return ix + 1 < starts.length ? starts[ix] : 0;
    }

    function lineEnd(ix:Int):Int {
        return ix + 1 < starts.length ? starts[ix + 1] : 0;
    }

}

/**
 * Prepared presentation for one file: syntax captures, as theme-independent
 * highlight names or an application highlighter's styles, and inline
 * changes between paired lines.
 */
@:allow(gpui.component.diff)
class FilePresentation {

    final names:Array<String> = [];

    var syntax:Array<LineSpans<SyntaxPaint>> = [new LineSpans(), new LineSpans()];

    var inlineSpans:Array<LineSpans<Bool>> = [new LineSpans(), new LineSpans()];

    function new() {}

    /**
     * Prepares a file. `custom` replaces the built-in highlighters when the
     * application set one. Rust runs it on a background thread; the port
     * runs it from a task of the foreground executor.
     */
    static function prepare(file:DiffFile, options:PresentationOptions, highlighters:Map<String, SyntaxHighlighter>,
            custom:Null<DiffSyntaxHighlighter>):FilePresentation {
        final presentation = new FilePresentation();
        final nameIxs = new Map<String, Int>();
        for (side in [DiffSide.Original, DiffSide.Modified]) {
            final perLine = Presentation.syntaxSpans(file, side, options.syntaxMaxLineLength, (language, text) -> {
                if (custom != null) {
                    // A range that splits a character, such as one counted in
                    // characters rather than bytes, cannot be painted.
                    return [
                        for (styled in custom(language, text))
                            if (Utf8.isCharBoundary(text, styled.range.start) && Utf8.isCharBoundary(text, styled.range.end))
                                {range: styled.range, payload: new SyntaxPaint(-1, styled.style)}
                    ];
                }
                var highlighter = highlighters.get(language);
                if (highlighter == null) {
                    highlighter = new SyntaxHighlighter(language);
                    highlighters.set(language, highlighter);
                }
                return [
                    for (capture in @:privateAccess highlighter.captureNames(Rope.fromStr(text))) {
                        final next = presentation.names.length < 65535 ? presentation.names.length : 65535;
                        var ix = nameIxs.get(capture.name);
                        if (ix == null) {
                            presentation.names.push(capture.name);
                            ix = next;
                            nameIxs.set(capture.name, ix);
                        }
                        {range: capture.range, payload: new SyntaxPaint(ix, null)};
                    }
                ];
            });
            presentation.syntax[side.index()] = LineSpans.fromLines(perLine);
        }
        if (options.inlineUnit != null)
            presentation.inlineSpans = Presentation.inlineChanges(file, options.inlineUnit, options.inlineMaxLineLength);
        return presentation;
    }

    /** Theme styles for one line's syntax, as display ranges. */
    public function syntaxHighlights(line:SourceLine, side:DiffSide, ix:Int, theme:HighlightStyleResolver):Array<DiffStyledRange> {
        final spans = syntax[side.index()];
        final rv = [];
        for (i in spans.lineStart(ix)...spans.lineEnd(ix)) {
            final paint = spans.payloads[i];
            final style = paint.style != null ? paint.style : theme.style(names[paint.name]);
            if (style == null)
                continue;
            rv.push(new DiffStyledRange(line.displayRange(spans.ranges[i]), style));
        }
        return rv;
    }

    /** Changed runs within one line, as display ranges. */
    public function inlineChanges(line:SourceLine, side:DiffSide, ix:Int):Array<Range> {
        final spans = inlineSpans[side.index()];
        return [for (i in spans.lineStart(ix)...spans.lineEnd(ix)) line.displayRange(spans.ranges[i])];
    }

}

/**
 * The functions of `presentation.rs`.
 */
@:allow(gpui.component.diff)
class Presentation {

    /**
     * Paired lines sharing less than this proportion of content are
     * emphasized as whole lines only; marking nearly every character adds
     * noise, not signal.
     */
    static final MIN_INLINE_SIMILARITY:Float = similar.Similar.f32(0.25);

    /**
     * Parses each hunk of one side independently, so an unterminated comment
     * or string in one hunk cannot affect the next.
     */
    static function syntaxSpans<T>(file:DiffFile, side:DiffSide, maxLineLength:Int,
            highlight:(String, String) -> Array<{range:Range, payload:T}>):Array<Array<{range:Range, payload:T}>> {
        final lines = file.lines(side);
        final perLine:Array<Array<{range:Range, payload:T}>> = [for (_ in 0...lines.length) []];
        final language = if (file.languageOverride() != null) {
            file.languageOverride();
        }
        else if (file.sidePath(side) != null) {
            detectedLanguage(file.sidePath(side));
        }
        else {
            return perLine;
        }
        if (language == 'text' || lines.length == 0)
            return perLine;
        final ranges = file.hunks().length == 0 ? [new Range(0, lines.length)] : [for (hunk in file.hunks()) hunk.lines(side)];
        final source = file.source(side);
        for (range in ranges) {
            if (range.isEmpty())
                continue;
            final base = lines[range.start].source().start;
            final text = source.substring(lines[range.start].sourceUnitStart, lines[range.end - 1].sourceUnitEnd);
            for (capture in highlight(language, text)) {
                final captureStart = capture.range.start + base;
                final captureEnd = capture.range.end + base;
                // `partition_point(|line| line.source().end <= capture.start)`
                var first = 0;
                while (range.start + first < range.end && lines[range.start + first].source().end <= captureStart)
                    first++;
                for (offset in 0...(range.end - range.start - first)) {
                    final line = lines[range.start + first + offset];
                    final lineStart = line.source().start;
                    if (lineStart >= captureEnd)
                        break;
                    if (line.contentEnd() - lineStart > maxLineLength)
                        continue;
                    final start = captureStart > lineStart ? captureStart : lineStart;
                    final end = captureEnd < line.contentEnd() ? captureEnd : line.contentEnd();
                    if (start < end)
                        perLine[range.start + first + offset].push({range: new Range(start - lineStart, end - lineStart), payload: capture.payload});
                }
            }
        }
        return perLine;
    }

    /** Compares each deleted line with the added line paired with it. */
    static function inlineChanges(file:DiffFile, unit:DiffInlineUnit, maxLineLength:Int):Array<LineSpans<Bool>> {
        final sides:Array<Array<Array<{range:Range, payload:Bool}>>> = [
            [for (_ in 0...file.linesCount(Original)) []],
            [for (_ in 0...file.linesCount(Modified)) []]
        ];
        for (pair in file.pairs()) {
            final oldIx = pair.original();
            final newIx = pair.modified();
            if (!pair.isChanged() || oldIx == null || newIx == null)
                continue;
            final oldLine = file.lines(Original)[oldIx];
            final newLine = file.lines(Modified)[newIx];
            if (oldLine.textLen() > maxLineLength || newLine.textLen() > maxLineLength || oldLine.text() == newLine.text())
                continue;
            final runs = changedRuns(oldLine.text(), newLine.text(), unit);
            sides[0][oldIx] = [for (range in runs.old) {range: range, payload: true}];
            sides[1][newIx] = [for (range in runs.newRuns) {range: range, payload: true}];
        }
        return [LineSpans.fromLines(sides[0]), LineSpans.fromLines(sides[1])];
    }

    /** Byte ranges that differ between two lines, on each side. */
    public static function changedRuns(old:String, newText:String, unit:DiffInlineUnit):{old:Array<Range>, newRuns:Array<Range>} {
        final diff = switch (unit) {
            case Word: TextDiff.fromUnicodeWords(old, newText);
            case Character: TextDiff.fromGraphemes(old, newText);
        }
        if (diff.ratio() < MIN_INLINE_SIMILARITY)
            return {old: [], newRuns: []};
        final oldRuns = [];
        final newRuns = [];
        var oldOffset = 0;
        var newOffset = 0;
        for (change in diff.iterAllChanges()) {
            final len = DiffableStr.len(change.value());
            switch (change.tag()) {
                case ChangeTag.Equal:
                    oldOffset += len;
                    newOffset += len;
                case ChangeTag.Delete:
                    pushRun(oldRuns, new Range(oldOffset, oldOffset + len), old, unit);
                    oldOffset += len;
                case ChangeTag.Insert:
                    pushRun(newRuns, new Range(newOffset, newOffset + len), newText, unit);
                    newOffset += len;
            }
        }
        return {old: oldRuns, newRuns: newRuns};
    }

    /** Extends the previous run when only whitespace separates it from `range`. */
    static function pushRun(runs:Array<Range>, range:Range, text:String, unit:DiffInlineUnit):Void {
        if (runs.length > 0) {
            final last = runs[runs.length - 1];
            final gap = Utf8.substring(text, last.end, range.start);
            if (gap.length == 0 || unit == Word && DiffFile.trimUnicode(gap).length == 0) {
                runs[runs.length - 1] = new Range(last.start, range.end);
                return;
            }
        }
        runs.push(range);
    }

    /**
     * File paths may come from another platform. Only the final component
     * determines the language; dots in a directory are not extensions.
     */
    public static function detectedLanguage(path:String):String {
        var cut = -1;
        for (i in 0...path.length) {
            final c = StringTools.fastCodeAt(path, i);
            if (c == '/'.code || c == '\\'.code)
                cut = i;
        }
        final name = path.substr(cut + 1).toLowerCase();
        final language = switch (name) {
            case 'makefile' | 'gnumakefile': 'make';
            case 'cmakelists.txt': 'cmake';
            default:
                final dot = name.lastIndexOf('.');
                final extension = dot == -1 ? null : name.substr(dot + 1);
                switch (extension) {
                    case 'jsx' | 'mjs' | 'cjs': 'javascript';
                    case 'mts' | 'cts': 'typescript';
                    case 'cc' | 'cxx' | 'hpp' | 'hxx': 'cpp';
                    case 'h': 'c';
                    case 'htm': 'html';
                    case 'gql': 'graphql';
                    case 'exs': 'elixir';
                    case 'astro' | 'sh' | 'bash' | 'c' | 'cmake' | 'cs' | 'cpp' | 'css' | 'scss' | 'diff' | 'ejs' | 'ex' | 'erb' | 'go' | 'graphql' |
                        'html' | 'java' | 'js' | 'json' | 'jsonc' | 'kt' | 'kts' | 'lua' | 'md' | 'mdx' | 'php' | 'php3' | 'php4' | 'php5' | 'phtml' |
                        'proto' | 'py' | 'pyi' | 'rb' | 'rs' | 'scala' | 'sql' | 'svelte' | 'swift' | 'toml' | 'tsx' | 'ts' | 'yaml' | 'yml' | 'zig':
                        extension;
                    default: 'text';
                }
        }
        return LanguageName.languageName(language);
    }

}
