// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs
// and crates/component/src/diff/conflict.rs (`DiffFile::unchanged`, `DiffFile::parse_conflicts`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.diff;

import glaze.Range;
import glaze.util.Utf8;

/**
 * One row of the side-by-side alignment: a line on either or both sides.
 */
@:allow(glaze.kit.diff)
class LinePair {

    final _original:Null<Int>;

    final _modified:Null<Int>;

    final _changed:Bool;

    public function new(original:Null<Int>, modified:Null<Int>, changed:Bool) {
        _original = original;
        _modified = modified;
        _changed = changed;
    }

    public inline function original():Null<Int> {
        return _original;
    }

    public inline function modified():Null<Int> {
        return _modified;
    }

    public inline function isChanged():Bool {
        return _changed;
    }

    public function equals(other:LinePair):Bool {
        return other != null && other._original == _original && other._modified == _modified && other._changed == _changed;
    }

    public function toString():String {
        return 'LinePair { original: $_original, modified: $_modified, changed: $_changed }';
    }

}

/**
 * One `@@` hunk: its pairs and the source lines it supplies on each side.
 */
@:allow(glaze.kit.diff)
class Hunk {

    final _pairs:Range;

    final original:Range;

    final modified:Range;

    final _label:String;

    /** The one-based original lines the hunk supplies. */
    final originalLines:Range;

    /** Whether the hunk ended before its declared line counts. */
    final truncated:Bool;

    public function new(pairs:Range, original:Range, modified:Range, label:String, originalLines:Range, truncated:Bool) {
        _pairs = pairs;
        this.original = original;
        this.modified = modified;
        _label = label;
        this.originalLines = originalLines;
        this.truncated = truncated;
    }

    /**
     * Original lines between the previous hunk, or the file start, and this
     * one that the patch does not supply.
     */
    public function hiddenLinesBefore(previous:Null<Hunk>):Int {
        final after = previous == null ? 1 : previous.originalLines.end;
        return originalLines.start > after ? originalLines.start - after : 0;
    }

    public inline function pairs():Range {
        return _pairs;
    }

    public function lines(side:DiffSide):Range {
        return side == Original ? original : modified;
    }

    /** The `@@` header line. */
    public inline function label():String {
        return _label;
    }

    public inline function isTruncated():Bool {
        return truncated;
    }

}

/**
 * One side of a file: its path, unless the side is missing such as
 * `/dev/null`, and the source fragments the patch supplies.
 */
@:allow(glaze.kit.diff)
class FileSide {

    final path:Null<String>;

    final source:String;

    final lines:Array<SourceLine>;

    /**
     * Builds a side from its concatenated source and each line's number and
     * byte range in it (`[lineNumber, start, end]`, in increasing order).
     */
    public function new(path:Null<String>, source:String, lines:Array<Array<Int>>) {
        this.path = path;
        this.source = source;
        // Walk the source once to convert the increasing byte offsets.
        final ascii = Utf8.isAscii(source);
        var unit = 0;
        var byte = 0;
        function unitAt(target:Int):Int {
            if (ascii)
                return target;
            while (byte < target && unit < source.length) {
                final c = ttf.Utf8.codePointAt(source, unit);
                byte += Utf8.codePointLength(c);
                unit += c >= 0x10000 ? 2 : 1;
            }
            return unit;
        }
        this.lines = [
            for (line in lines) {
                final start = unitAt(line[1]);
                final end = unitAt(line[2]);
                SourceLine.build(source, new Range(line[1], line[2]), start, end, line[0]);
            }
        ];
    }

}

/**
 * One line of the patch body in patch order: an unchanged line on both
 * sides, or a deleted or added line on one side.
 */
@:allow(glaze.kit.diff)
class PatchLine {

    final original:Null<Int>;

    final modified:Null<Int>;

    function new(original:Null<Int>, modified:Null<Int>) {
        this.original = original;
        this.modified = modified;
    }

    public function line(side:DiffSide):Null<Int> {
        return side == Original ? original : modified;
    }

}

@:allow(glaze.kit.diff)
private class DocumentInner {

    var path:String;
    var status:DiffFileStatus;
    var original:FileSide;
    var modified:FileSide;
    var pairs:Array<LinePair>;
    var hunks:Array<Hunk>;
    var additions:Int;
    var deletions:Int;
    var extendedHeaders:Array<String>;
    var binary:Bool;

    /** Width of the widest line number, in digits. */
    var lineNumberDigits:Int;

    /** The patch body in order; each side's lines map back into it. */
    var patchLines:Array<PatchLine>;

    var patchIxs:Array<Array<Int>>;

    var conflicts:Array<DiffConflict>;

    function new() {}

}

/**
 * One changed file parsed from a unified or Git diff.
 *
 * Only source fragments present in the patch are retained; unavailable
 * context is never reconstructed or compared. Copying is cheap: the parsed
 * data is shared.
 */
class DiffFile {

    @:allow(glaze.kit.diff, tests)
    var inner:DocumentInner;

    var _language:Null<String> = null;

    /**
     * Parses every file in a unified or Git diff, in patch order, without
     * computing differences. Throws a `DiffParseError` on a malformed patch.
     */
    public static function parse(patch:String):Array<DiffFile> {
        return DiffParser.parse(patch, new DiffParseOptions());
    }

    /**
     * Parses like `parse`, applying the relaxations `options` enables.
     * Malformed headers, invalid paths and unordered hunks are still errors.
     */
    public static function parseWith(patch:String, options:DiffParseOptions):Array<DiffFile> {
        return DiffParser.parse(patch, options);
    }

    function new() {}

    /**
     * Assembles a parsed file, pairing counterpart lines and deriving its
     * display path, change counts and line-number width.
     */
    @:allow(glaze.kit.diff)
    static function create(status:DiffFileStatus, original:FileSide, modified:FileSide, pairs:Array<LinePair>, hunks:Array<Hunk>,
            extendedHeaders:Array<String>, binary:Bool):DiffFile {
        var additions = 0;
        var deletions = 0;
        for (pair in pairs) {
            // Conflict lines are unresolved alternatives, not additions.
            if (pair._changed && status != Conflicted) {
                additions += pair._modified != null ? 1 : 0;
                deletions += pair._original != null ? 1 : 0;
            }
            if (pair._original != null && pair._modified != null) {
                original.lines[pair._original]._counterpart = pair._modified;
                modified.lines[pair._modified]._counterpart = pair._original;
            }
        }
        var widest = 1;
        var any = false;
        for (side in [original, modified]) {
            if (side.lines.length > 0) {
                final number = side.lines[side.lines.length - 1]._lineNumber;
                if (!any || number > widest)
                    widest = number;
                any = true;
            }
        }
        final path = modified.path != null ? modified.path : (original.path != null ? original.path : '');
        final order = patchOrder(pairs, hunks, original, modified);
        final inner = new DocumentInner();
        inner.path = path;
        inner.status = status;
        inner.original = original;
        inner.modified = modified;
        inner.pairs = pairs;
        inner.hunks = hunks;
        inner.additions = additions;
        inner.deletions = deletions;
        inner.extendedHeaders = extendedHeaders;
        inner.binary = binary;
        inner.lineNumberDigits = ilog10(widest < 1 ? 1 : widest) + 1;
        inner.patchLines = order.lines;
        inner.patchIxs = order.ixs;
        inner.conflicts = [];
        final file = new DiffFile();
        file.inner = inner;
        return file;
    }

    static function ilog10(v:Int):Int {
        var rv = 0;
        while (v >= 10) {
            v = Std.int(v / 10);
            rv++;
        }
        return rv;
    }

    /**
     * Overrides the syntax language detected from the path, using a
     * highlighter language name such as `rust` or `javascript`.
     */
    public function withLanguage(language:String):DiffFile {
        final file = new DiffFile();
        file.inner = inner;
        file._language = language;
        return file;
    }

    /** The syntax language: the override, or the one detected from the path. */
    public function language():String {
        return _language != null ? _language : Presentation.detectedLanguage(path());
    }

    @:allow(glaze.kit.diff)
    function languageOverride():Null<String> {
        return _language;
    }

    /** How the file changed. */
    public function status():DiffFileStatus {
        return inner.status;
    }

    /**
     * The path to show for this file: the modified path, or the original path
     * of a deleted file.
     */
    public function path():String {
        return inner.path;
    }

    /** The original path, or null for an added file. */
    public function originalPath():Null<String> {
        return inner.original.path;
    }

    /** The modified path, or null for a deleted file. */
    public function modifiedPath():Null<String> {
        return inner.modified.path;
    }

    /**
     * Git extended header lines, such as file modes, similarity, renames
     * and the binary marker, as they appear in the patch.
     */
    public function extendedHeaders():Array<String> {
        return inner.extendedHeaders;
    }

    /** Whether the patch reports binary contents rather than textual hunks. */
    public function isBinary():Bool {
        return inner.binary;
    }

    /**
     * Whether a hunk ended before its declared line counts, which only
     * `DiffParseOptions.truncatedHunks` accepts.
     */
    public function isTruncated():Bool {
        for (hunk in inner.hunks) {
            if (hunk.isTruncated())
                return true;
        }
        return false;
    }

    public function additions():Int {
        return inner.additions;
    }

    public function deletions():Int {
        return inner.deletions;
    }

    /**
     * Whether the file changes, including an added or deleted empty file and
     * metadata-only changes such as a mode change or pure rename.
     */
    public function hasChanges():Bool {
        return additions() > 0 || deletions() > 0 || inner.extendedHeaders.length > 0 || inner.binary || originalPath() == null
            || modifiedPath() == null || status() == Conflicted;
    }

    /** Whether the file has one column in every display mode. */
    @:allow(glaze.kit.diff)
    function isSingleColumn():Bool {
        return status() == Unchanged || status() == Conflicted;
    }

    /** Merge conflicts in working-file order; array indices identify resolutions. */
    public function conflicts():Array<DiffConflict> {
        return inner.conflicts;
    }

    @:allow(glaze.kit.diff)
    function withConflicts(conflicts:Array<DiffConflict>):DiffFile {
        inner.conflicts = conflicts;
        return this;
    }

    @:allow(glaze.kit.diff, tests)
    function linesCount(side:DiffSide):Int {
        return lines(side).length;
    }

    /**
     * Copies patch-provided lines. Unavailable context is omitted, without
     * inventing source lines.
     */
    @:allow(glaze.kit.diff, tests)
    function textForLines(side:DiffSide, start:Int, end:Int):String {
        final lines = lines(side);
        var startIx = 0;
        while (startIx < lines.length && lines[startIx]._lineNumber < start)
            startIx++;
        var endIx = startIx;
        while (endIx < lines.length && lines[endIx]._lineNumber <= end)
            endIx++;
        if (endIx <= startIx)
            return '';
        final first = lines[startIx];
        final last = lines[endIx - 1];
        return source(side).substring(first.sourceUnitStart, last.sourceUnitEnd);
    }

    /** The one-based line number of the line at `index` on `side`. */
    @:allow(glaze.kit.diff, tests)
    function lineNumber(side:DiffSide, index:Int):Int {
        return lines(side)[index]._lineNumber;
    }

    @:allow(glaze.kit.diff, tests)
    function lineIndex(side:DiffSide, line:Int):Null<Int> {
        final lines = lines(side);
        var lo = 0;
        var hi = lines.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            final number = lines[mid]._lineNumber;
            if (number == line)
                return mid;
            if (number < line)
                lo = mid + 1;
            else
                hi = mid;
        }
        return null;
    }

    @:allow(glaze.kit.diff, tests)
    function pairs():Array<LinePair> {
        return inner.pairs;
    }

    @:allow(glaze.kit.diff, tests)
    function hunks():Array<Hunk> {
        return inner.hunks;
    }

    /** Width of the widest supplied line number, in digits. */
    @:allow(glaze.kit.diff, tests)
    function lineNumberDigits():Int {
        return inner.lineNumberDigits;
    }

    @:allow(glaze.kit.diff, tests)
    function patchLines():Array<PatchLine> {
        return inner.patchLines;
    }

    /** The position of a side's line in `patchLines()`. */
    @:allow(glaze.kit.diff, tests)
    function patchIx(side:DiffSide, ix:Int):Int {
        return inner.patchIxs[side.index()][ix];
    }

    @:allow(glaze.kit.diff)
    function sidePath(side:DiffSide):Null<String> {
        return fileSide(side).path;
    }

    function fileSide(side:DiffSide):FileSide {
        return side == Original ? inner.original : inner.modified;
    }

    @:allow(glaze.kit.diff, tests)
    function lines(side:DiffSide):Array<SourceLine> {
        return fileSide(side).lines;
    }

    @:allow(glaze.kit.diff, tests)
    function source(side:DiffSide):String {
        return fileSide(side).source;
    }

    /**
     * Orders the patch body as Git writes it: within each run of changes,
     * every deletion precedes every addition. Runs never cross hunk boundaries.
     */
    static function patchOrder(pairs:Array<LinePair>, hunks:Array<Hunk>, original:FileSide, modified:FileSide):{lines:Array<PatchLine>, ixs:Array<Array<Int>>} {
        final lines = [];
        final ixs = [[for (_ in 0...original.lines.length) 0], [for (_ in 0...modified.lines.length) 0]];
        final ranges = hunks.length == 0 ? [new Range(0, pairs.length)] : [for (hunk in hunks) hunk.pairs()];
        for (range in ranges) {
            var ix = range.start;
            while (ix < range.end) {
                if (!pairs[ix]._changed) {
                    final pair = pairs[ix];
                    lines.push(new PatchLine(pair._original, pair._modified));
                    ix += 1;
                    continue;
                }
                final start = ix;
                while (ix < range.end && pairs[ix]._changed)
                    ix += 1;
                for (i in start...ix) {
                    final line = pairs[i]._original;
                    if (line != null)
                        lines.push(new PatchLine(line, null));
                }
                for (i in start...ix) {
                    final line = pairs[i]._modified;
                    if (line != null)
                        lines.push(new PatchLine(null, line));
                }
            }
        }
        for (patchIx in 0...lines.length) {
            final line = lines[patchIx];
            if (line.original != null)
                ixs[0][line.original] = patchIx;
            if (line.modified != null)
                ixs[1][line.modified] = patchIx;
        }
        return {lines: lines, ixs: ixs};
    }

    /** Splits `text` into lines and their byte ranges, keeping line endings. */
    static function lineRanges(text:String):Array<{start:Int, end:Int, unitStart:Int, unitEnd:Int}> {
        final rv = [];
        var offset = 0;
        var unit = 0;
        while (unit < text.length) {
            final next = text.indexOf('\n', unit);
            final unitEnd = next == -1 ? text.length : next + 1;
            final bytes = Utf8.byteLength(text.substring(unit, unitEnd));
            rv.push({
                start: offset,
                end: offset + bytes,
                unitStart: unit,
                unitEnd: unitEnd
            });
            offset += bytes;
            unit = unitEnd;
        }
        return rv;
    }

    /**
     * A file shown in full, for reference, without changes. It appears as a
     * single column in every display mode.
     */
    public static function unchanged(path:String, text:String):DiffFile {
        final ranges = lineRanges(text);
        final pairs = [for (ix in 0...ranges.length) new LinePair(null, ix, false)];
        final lines = [for (ix in 0...ranges.length) [ix + 1, ranges[ix].start, ranges[ix].end]];
        return create(Unchanged, new FileSide(path, '', []), new FileSide(path, text, lines), pairs, [], [], false);
    }

    /**
     * Parses a working file containing Git conflict markers, including the
     * `|||||||` base section of `diff3` style. Lines keep their numbers in
     * the working file; marker lines are shown as conflict headings instead.
     * Throws a `DiffParseError` on malformed markers.
     */
    public static function parseConflicts(path:String, text:String):DiffFile {
        final source = new StringBuf();
        var sourceLen = 0;
        final lines:Array<Array<Int>> = [];
        final pairs = [];
        final conflicts = [];
        // The marker-delimited part being read, with the open region's ranges.
        var openPart:Null<ConflictPart> = null;
        var conflict:Null<DiffConflict> = null;
        final ranges = lineRanges(text);
        for (ix in 0...ranges.length) {
            final range = ranges[ix];
            final line = text.substring(range.unitStart, range.unitEnd);
            var content = line;
            while (content.length > 0 && (StringTools.endsWith(content, '\n') || StringTools.endsWith(content, '\r')))
                content = content.substr(0, content.length - 1);
            function marker(prefix:String):Null<String> {
                if (!StringTools.startsWith(content, prefix))
                    return null;
                final rest = content.substr(prefix.length);
                if (rest.length == 0 || StringTools.startsWith(rest, ' '))
                    return trimUnicode(rest);
                return null;
            }
            final next = lines.length;
            final opening = marker('<<<<<<<');
            final base = marker('|||||||');
            final separator = marker('=======');
            final closing = marker('>>>>>>>');
            if (openPart == null) {
                if (opening != null) {
                    openPart = Current;
                    conflict = new DiffConflict();
                    conflict._lines = new Range(ix + 1, ix + 1);
                    conflict._currentLines = new Range(ix + 2, ix + 2);
                    conflict._baseLines = null;
                    conflict._incomingLines = new Range(ix + 2, ix + 2);
                    conflict.current = new Range(next, next);
                    conflict.base = null;
                    conflict.incoming = new Range(next, next);
                    conflict._currentLabel = opening;
                    conflict._baseLabel = '';
                    conflict._incomingLabel = '';
                    continue;
                }
                if (base != null || closing != null)
                    throw new DiffParseError(ix + 1, 'conflict marker outside a conflict');
            }
            else {
                if (opening != null)
                    throw new DiffParseError(ix + 1, 'nested conflict marker');
                if (openPart == Current && base != null) {
                    conflict.current = new Range(conflict.current.start, next);
                    conflict._currentLines = new Range(conflict._currentLines.start, ix + 1);
                    conflict._baseLines = new Range(ix + 2, ix + 2);
                    conflict.base = new Range(next, next);
                    conflict._baseLabel = base;
                    openPart = Base;
                    continue;
                }
                if ((openPart == Current || openPart == Base) && separator != null) {
                    if (openPart == Current) {
                        conflict.current = new Range(conflict.current.start, next);
                        conflict._currentLines = new Range(conflict._currentLines.start, ix + 1);
                    }
                    else if (conflict.base != null) {
                        conflict.base = new Range(conflict.base.start, next);
                        conflict._baseLines = new Range(conflict._baseLines.start, ix + 1);
                    }
                    conflict.incoming = new Range(next, next);
                    conflict._incomingLines = new Range(ix + 2, ix + 2);
                    openPart = Incoming;
                    continue;
                }
                if (openPart == Incoming && closing != null) {
                    conflict.incoming = new Range(conflict.incoming.start, next);
                    conflict._incomingLines = new Range(conflict._incomingLines.start, ix + 1);
                    conflict._lines = new Range(conflict._lines.start, ix + 2);
                    conflict._incomingLabel = closing;
                    conflicts.push(conflict);
                    openPart = null;
                    conflict = null;
                    continue;
                }
            }
            final start = sourceLen;
            source.add(line);
            sourceLen += range.end - range.start;
            lines.push([ix + 1, start, sourceLen]);
            pairs.push(new LinePair(null, next, openPart != null));
        }
        if (openPart != null)
            throw new DiffParseError(rustLinesCount(text), 'unterminated conflict');
        return create(Conflicted, new FileSide(path, '', []), new FileSide(path, source.toString(), lines), pairs, [], [], false)
            .withConflicts(conflicts);
    }

    /** Rust `str::lines().count()`. */
    static function rustLinesCount(text:String):Int {
        if (text.length == 0)
            return 0;
        var count = text.split('\n').length;
        if (StringTools.endsWith(text, '\n'))
            count--;
        return count;
    }

    /** Rust `str::trim` (Unicode whitespace). */
    @:allow(glaze.kit.diff)
    static function trimUnicode(s:String):String {
        var start = 0;
        var end = s.length;
        while (start < end && Utf8.isWhitespace(StringTools.fastCodeAt(s, start)))
            start++;
        while (end > start && Utf8.isWhitespace(StringTools.fastCodeAt(s, end - 1)))
            end--;
        return s.substring(start, end);
    }

}
