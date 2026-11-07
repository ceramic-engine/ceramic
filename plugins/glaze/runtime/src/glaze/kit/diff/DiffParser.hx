// Ported from gpui-kit 0.8.1: crates/component/src/diff/parser.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.diff;

import glaze.Range;
import glaze.kit.diff.DiffFile.FileSide;
import glaze.kit.diff.DiffFile.Hunk;
import glaze.kit.diff.DiffFile.LinePair;
import glaze.util.Utf8;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

/**
 * The unified and Git diff parser behind `DiffFile.parse`.
 *
 * Line numbers are `Int`: where Rust bounds them by `usize::MAX`, the port
 * bounds them by `MAX_LINE` (a hunk header beyond is invalid, like one
 * overflowing `usize` in Rust).
 */
@:allow(glaze.kit.diff)
class DiffParser {

    /** The largest line number (Rust `usize::MAX`). */
    public static inline final MAX_LINE:Int = 0x7FFFFFFF;

    /**
     * Source prefixes Git writes on each side: the default `a/` and `b/`,
     * the `diff.mnemonicPrefix` pairs, `--no-index` and `diff.noprefix`.
     */
    static final GIT_PREFIXES:Array<Array<String>> = [
        ['a/', 'b/'],
        ['i/', 'w/'],
        ['c/', 'w/'],
        ['c/', 'i/'],
        ['o/', 'w/'],
        ['1/', '2/'],
        ['', ''],
    ];

    public static function parse(patch:String, options:DiffParseOptions):Array<DiffFile> {
        final raw:Array<String> = [];
        {
            var unit = 0;
            while (unit < patch.length) {
                final next = patch.indexOf('\n', unit);
                if (next == -1) {
                    raw.push(patch.substring(unit));
                    break;
                }
                raw.push(patch.substring(unit, next));
                unit = next + 1;
            }
        }
        // Git preserves CR in source lines but emits LF headers. CRLF transport
        // instead has CR on its header records as well; strip that framing CR only.
        var transportCrlf = false;
        for (line in raw) {
            if (StringTools.startsWith(line, 'diff --git ') || StringTools.startsWith(line, '--- ')) {
                transportCrlf = StringTools.endsWith(line, '\r');
                break;
            }
        }
        final lines = [
            for (line in raw)
                transportCrlf && StringTools.endsWith(line, '\r') ? line.substr(0, line.length - 1) : line
        ];
        final files:Array<DiffFile> = [];
        var current:Null<ParsedFile> = null;
        var ix = 0;
        while (ix < lines.length) {
            final line = lines[ix];
            if (StringTools.startsWith(line, 'diff --cc ') || StringTools.startsWith(line, 'diff --combined ') || StringTools.startsWith(line, '@@@'))
                throw new DiffParseError(ix + 1, 'combined diffs are not supported');
            if (StringTools.startsWith(line, 'diff --git ')) {
                final paths = line.substr('diff --git '.length);
                if (current != null) {
                    files.push(current.finish());
                    current = null;
                }
                final parsed = gitPaths(paths);
                if (parsed == null)
                    throw new DiffParseError(ix + 1, 'invalid Git file header');
                current = new ParsedFile();
                current.oldPath = parsed.old;
                current.newPath = parsed.newPath;
                current.gitPrefixes = parsed.prefixes;
                ix += 1;
                continue;
            }
            // `git format-patch` ends each message with a `-- ` signature line,
            // followed by the Git version. Mail clients may strip its trailing space.
            if (line == '-- ' || line == '--') {
                if (current != null) {
                    files.push(current.finish());
                    current = null;
                }
                ix += 1;
                continue;
            }
            if (StringTools.startsWith(line, '--- ')) {
                final path = line.substr(4);
                if (current != null && current.headers) {
                    files.push(current.finish());
                    current = null;
                }
                if (current == null)
                    current = new ParsedFile();
                final file = current;
                final old = headerPath(path, ix + 1);
                ix += 1;
                if (!(ix < lines.length && StringTools.startsWith(lines[ix], '+++ ')))
                    throw new DiffParseError(ix + 1, 'expected modified file header');
                final newPath = headerPath(lines[ix].substr(4), ix + 1);
                if (old == null && newPath == null)
                    throw new DiffParseError(ix + 1, 'both file sides are missing');
                final prefixes = if (file.gitPrefixes != null) {
                    file.gitPrefixes;
                }
                else {
                    // Without a Git header, strip `a/` and `b/` only when the
                    // present sides agree on that convention.
                    final conventional = (old == null || StringTools.startsWith(old, 'a/')) && (newPath == null || StringTools.startsWith(newPath, 'b/'));
                    conventional ? ['a/', 'b/'] : ['', ''];
                }
                file.oldPath = old != null ? stripPrefix(old, prefixes[0]) : null;
                file.newPath = newPath != null ? stripPrefix(newPath, prefixes[1]) : null;
                file.headers = true;
                ix += 1;
                continue;
            }
            if (StringTools.startsWith(line, '@@ ')) {
                if (current == null)
                    throw new DiffParseError(ix + 1, 'hunk has no file header');
                if (!current.headers)
                    throw new DiffParseError(ix + 1, 'hunk requires original and modified file headers');
                ix = parseHunk(current, lines, ix, options);
                continue;
            }
            // Binary payload is opaque to the UI. Keep its marker, not thousands
            // of encoded records or a fabricated text source.
            if (current != null && current.binary) {
                ix += 1;
                continue;
            }
            if ((StringTools.startsWith(line, '+') || StringTools.startsWith(line, '-') || StringTools.startsWith(line, ' ')
                || StringTools.startsWith(line, '\\ No newline'))
                && current != null
                && current.headers)
                throw new DiffParseError(ix + 1, 'source line outside a hunk');
            if (current != null) {
                final file = current;
                if (StringTools.startsWith(line, 'Binary files ') || line == 'GIT binary patch')
                    file.binary = true;
                if (StringTools.startsWith(line, 'rename from ')) {
                    file.oldPath = decodePath(line.substr('rename from '.length), ix + 1);
                    file.renamed = true;
                }
                if (StringTools.startsWith(line, 'copy from ')) {
                    file.oldPath = decodePath(line.substr('copy from '.length), ix + 1);
                    file.copied = true;
                }
                if (StringTools.startsWith(line, 'rename to '))
                    file.newPath = decodePath(line.substr('rename to '.length), ix + 1);
                else if (StringTools.startsWith(line, 'copy to '))
                    file.newPath = decodePath(line.substr('copy to '.length), ix + 1);
                if (StringTools.startsWith(line, 'new file mode '))
                    file.oldPath = null;
                if (StringTools.startsWith(line, 'deleted file mode '))
                    file.newPath = null;
                if (line.length > 0)
                    file.extendedHeaders.push(line);
            }
            ix += 1;
        }
        if (current != null)
            files.push(current.finish());
        if (files.length == 0 && DiffFile.trimUnicode(patch).length > 0)
            throw new DiffParseError(1, 'expected a unified or Git diff');
        return files;
    }

    /** Parses the hunk whose header is `lines[ix]` and returns the next line index. */
    static function parseHunk(file:ParsedFile, lines:Array<String>, ix:Int, options:DiffParseOptions):Int {
        final header = lines[ix];
        final parsed = hunkHeader(header, ix + 1);
        final oldStart = parsed[0];
        final oldCount = parsed[1];
        final newStart = parsed[2];
        final newCount = parsed[3];
        // A zero-count side names the line before its insertion point.
        final firstOriginal = oldStart + (oldCount == 0 ? 1 : 0);
        final firstModified = newStart + (newCount == 0 ? 1 : 0);
        final lastOriginal = file.original.lastLine();
        final lastModified = file.modified.lastLine();
        if (options.hasTruncatedHunks() && file.lastHunkStart != null
            && (firstOriginal < file.lastHunkStart[0] || firstModified < file.lastHunkStart[1])
            || lastOriginal != null && lastOriginal >= oldStart && oldCount > 0
            || lastModified != null && lastModified >= newStart && newCount > 0)
            throw new DiffParseError(ix + 1, 'overlapping or unordered hunks');
        if (file.oldPath == null && oldCount != 0 || file.newPath == null && newCount != 0)
            throw new DiffParseError(ix + 1, 'missing file side has source lines');
        final pairsStart = file.pairs.length;
        final originalStart = file.original.lines.length;
        final modifiedStart = file.modified.lines.length;
        ix += 1;
        final nextFile = options.hasTruncatedHunks() ? truncatedFileHeader(lines, ix, oldCount, newCount) : null;
        var oldUsed = 0;
        var newUsed = 0;
        final deleted:Array<Int> = [];
        final added:Array<Int> = [];
        var last:Null<Int> = null;
        while (ix < lines.length) {
            if (nextFile != null && ix == nextFile)
                break;
            final content = lines[ix];
            if (content == '\\ No newline at end of file') {
                if (last == '-'.code) {
                    file.original.removeFinalNewline();
                }
                else if (last == '+'.code) {
                    file.modified.removeFinalNewline();
                }
                else if (last == ' '.code) {
                    file.original.removeFinalNewline();
                    file.modified.removeFinalNewline();
                }
                else {
                    throw new DiffParseError(ix + 1, 'newline marker has no preceding source line');
                }
                last = null;
                ix += 1;
                continue;
            }
            if (oldUsed == oldCount && newUsed == newCount)
                break;
            // Editors and mail transports may strip the space from an empty
            // context line; `git apply` accepts that, so accept it here too.
            final tag = content.length > 0 ? StringTools.fastCodeAt(content, 0) : ' '.code;
            if (tag != ' '.code && tag != '+'.code && tag != '-'.code) {
                if (options.hasTruncatedHunks())
                    break;
                throw new DiffParseError(ix + 1, 'hunk ended before its declared line counts');
            }
            final text = content.length > 0 ? content.substr(1) : '';
            if (tag != '+'.code && file.original.noNewline || tag != '-'.code && file.modified.noNewline)
                throw new DiffParseError(ix + 1, 'source continues after an unterminated final line');
            if (tag == ' '.code) {
                file.flushChanges(deleted, added);
                if (oldUsed >= oldCount || newUsed >= newCount)
                    throw new DiffParseError(ix + 1, 'hunk exceeds declared line counts');
                final original = file.original.push(oldStart + oldUsed, text);
                final modified = file.modified.push(newStart + newUsed, text);
                file.pairs.push(new LinePair(original, modified, false));
                oldUsed += 1;
                newUsed += 1;
            }
            else if (tag == '-'.code) {
                if (oldUsed >= oldCount)
                    throw new DiffParseError(ix + 1, 'hunk exceeds original line count');
                deleted.push(file.original.push(oldStart + oldUsed, text));
                oldUsed += 1;
            }
            else {
                if (newUsed >= newCount)
                    throw new DiffParseError(ix + 1, 'hunk exceeds modified line count');
                added.push(file.modified.push(newStart + newUsed, text));
                newUsed += 1;
            }
            last = tag;
            ix += 1;
        }
        final truncated = oldUsed != oldCount || newUsed != newCount;
        if (truncated && !options.hasTruncatedHunks())
            throw new DiffParseError(ix + 1, 'hunk ended before its declared line counts');
        file.flushChanges(deleted, added);
        file.hunks.push(new Hunk(new Range(pairsStart, file.pairs.length), new Range(originalStart, file.original.lines.length),
            new Range(modifiedStart, file.modified.lines.length), header, new Range(firstOriginal, firstOriginal + oldUsed), truncated));
        file.lastHunkStart = [firstOriginal, firstModified];
        return ix;
    }

    /**
     * Finds a unified file header inside a short hunk. A header-looking pair
     * can also be source text, so a complete hunk interpretation wins.
     */
    static function truncatedFileHeader(lines:Array<String>, start:Int, oldRemaining:Int, newRemaining:Int):Null<Int> {
        var header:Null<Int> = null;
        for (ix in start...lines.length) {
            final line = lines[ix];
            if (line == '\\ No newline at end of file')
                continue;
            if (oldRemaining == 0 && newRemaining == 0)
                return null;
            if (header == null && StringTools.startsWith(line, '--- ') && ix + 1 < lines.length && StringTools.startsWith(lines[ix + 1], '+++ '))
                header = ix;
            final first = line.length > 0 ? StringTools.fastCodeAt(line, 0) : ' '.code;
            if (first == ' '.code && oldRemaining > 0 && newRemaining > 0) {
                oldRemaining -= 1;
                newRemaining -= 1;
            }
            else if (first == '-'.code && oldRemaining > 0) {
                oldRemaining -= 1;
            }
            else if (first == '+'.code && newRemaining > 0) {
                newRemaining -= 1;
            }
            else {
                return header;
            }
        }
        return oldRemaining == 0 && newRemaining == 0 ? null : header;
    }

    /** Parses `@@ -a,b +c,d @@` into `[oldStart, oldCount, newStart, newCount]`. */
    static function hunkHeader(line:String, number:Int):Array<Int> {
        function invalid() {
            return new DiffParseError(number, 'invalid hunk header');
        }
        if (!StringTools.startsWith(line, '@@ '))
            throw invalid();
        final body = line.substr(3);
        final end = body.indexOf(' @@');
        if (end == -1)
            throw invalid();
        final fields = splitWhitespace(body.substring(0, end));
        if (fields.length < 1 || !StringTools.startsWith(fields[0], '-'))
            throw invalid();
        if (fields.length < 2 || !StringTools.startsWith(fields[1], '+'))
            throw invalid();
        if (fields.length > 2)
            throw invalid();
        function range(value:String):Null<Array<Int>> {
            final comma = value.indexOf(',');
            final startText = comma == -1 ? value : value.substring(0, comma);
            final countText = comma == -1 ? '1' : value.substr(comma + 1);
            final start = parseUsize(startText);
            final count = parseUsize(countText);
            if (start == null || count == null)
                return null;
            final countMax = count > 1 ? count : 1;
            if (count > 0 && start == 0 || start > MAX_LINE - countMax)
                return null;
            return [start, count];
        }
        final old = range(fields[0].substr(1));
        if (old == null)
            throw invalid();
        final newRange = range(fields[1].substr(1));
        if (newRange == null)
            throw invalid();
        return [old[0], old[1], newRange[0], newRange[1]];
    }

    /** Rust `str::parse::<usize>`, bounded by `MAX_LINE`. */
    static function parseUsize(text:String):Null<Int> {
        var i = 0;
        if (StringTools.startsWith(text, '+'))
            i = 1;
        if (i >= text.length)
            return null;
        var value = 0.0;
        while (i < text.length) {
            final c = StringTools.fastCodeAt(text, i);
            if (c < '0'.code || c > '9'.code)
                return null;
            value = value * 10 + (c - '0'.code);
            if (value > MAX_LINE)
                return null;
            i++;
        }
        return Std.int(value);
    }

    /** Rust `str::split_whitespace`. */
    static function splitWhitespace(text:String):Array<String> {
        final rv = [];
        var start = -1;
        for (i in 0...text.length) {
            final ws = Utf8.isWhitespace(StringTools.fastCodeAt(text, i));
            if (ws) {
                if (start != -1) {
                    rv.push(text.substring(start, i));
                    start = -1;
                }
            }
            else if (start == -1) {
                start = i;
            }
        }
        if (start != -1)
            rv.push(text.substring(start));
        return rv;
    }

    static function stripPrefix(path:String, prefix:String):String {
        if (prefix.length > 0 && StringTools.startsWith(path, prefix))
            return path.substr(prefix.length);
        return path;
    }

    /** Decodes a `---` or `+++` path, or null for `/dev/null`. */
    static function headerPath(value:String, number:Int):Null<String> {
        final tab = value.indexOf('\t');
        if (tab != -1)
            value = value.substring(0, tab);
        if (value == '/dev/null')
            return null;
        return decodePath(value, number);
    }

    /** Splits the paths of a `diff --git` header and detects their prefixes. */
    static function gitPaths(value:String):Null<{old:String, newPath:String, prefixes:Array<String>}> {
        function detect(old:String, newPath:String):Array<String> {
            for (prefixes in GIT_PREFIXES) {
                if (StringTools.startsWith(old, prefixes[0]) && StringTools.startsWith(newPath, prefixes[1]))
                    return prefixes;
            }
            return ['', ''];
        }
        var old:String;
        var newPath:String;
        var prefixes:Array<String>;
        if (StringTools.startsWith(value, '"')) {
            final end = quotedEnd(value);
            if (end == null)
                return null;
            try {
                old = decodePath(value.substring(0, end), 1);
                newPath = decodePath(StringTools.ltrim(value.substr(end)), 1);
            }
            catch (e:DiffParseError) {
                return null;
            }
            prefixes = detect(old, newPath);
        }
        else if (StringTools.endsWith(value, '"')) {
            var start:Null<Int> = null;
            var search = 0;
            while (true) {
                final at = value.indexOf(' "', search);
                if (at == -1)
                    break;
                final ix = at + 1;
                if (quotedEnd(value.substr(ix)) == value.length - ix) {
                    start = ix;
                    break;
                }
                search = at + 1;
            }
            if (start == null)
                return null;
            old = value.substring(0, start - 1);
            try {
                newPath = decodePath(value.substr(start), 1);
            }
            catch (e:DiffParseError) {
                return null;
            }
            prefixes = detect(old, newPath);
        }
        else {
            // Git does not quote spaces. Without a rename both sides name the
            // same path, which identifies the separating space unambiguously.
            var found:Null<Array<Dynamic>> = null;
            for (pair in GIT_PREFIXES) {
                var search = 0;
                while (found == null) {
                    final ix = value.indexOf(' ', search);
                    if (ix == -1)
                        break;
                    final o = value.substring(0, ix);
                    final n = value.substr(ix + 1);
                    if (StringTools.startsWith(o, pair[0])) {
                        final path = o.substr(pair[0].length);
                        if (path.length > 0 && StringTools.startsWith(n, pair[1]) && n.substr(pair[1].length) == path)
                            found = [o, n, pair];
                    }
                    search = ix + 1;
                }
                if (found != null)
                    break;
            }
            // Otherwise this is a rename or copy, and `rename from`/`rename to`
            // records supply the exact paths.
            if (found == null) {
                for (pair in GIT_PREFIXES) {
                    if (pair[0].length == 0)
                        continue;
                    final ix = value.lastIndexOf(' ' + pair[1]);
                    if (ix == -1)
                        continue;
                    if (StringTools.startsWith(value, pair[0])) {
                        found = [value.substring(0, ix), value.substr(ix + 1), pair];
                        break;
                    }
                }
            }
            if (found == null) {
                final ix = value.indexOf(' ');
                if (ix == -1)
                    return null;
                found = [value.substring(0, ix), value.substr(ix + 1), ['', '']];
            }
            old = found[0];
            newPath = found[1];
            prefixes = found[2];
        }
        return {old: stripPrefix(old, prefixes[0]), newPath: stripPrefix(newPath, prefixes[1]), prefixes: prefixes};
    }

    static function quotedEnd(value:String):Null<Int> {
        var escaped = false;
        var i = 1;
        while (i < value.length) {
            final c = StringTools.fastCodeAt(value, i);
            if (escaped) {
                escaped = false;
            }
            else if (c == '\\'.code) {
                escaped = true;
            }
            else if (c == '"'.code) {
                return i + 1;
            }
            i++;
        }
        return null;
    }

    static function decodePath(value:String, number:Int):String {
        if (!StringTools.startsWith(value, '"'))
            return value;
        if (quotedEnd(value) != value.length)
            throw new DiffParseError(number, 'invalid quoted file path');
        final all = Bytes.ofString(value);
        final bytes = all.sub(1, all.length - 2);
        final output = new BytesBuffer();
        var ix = 0;
        while (ix < bytes.length) {
            if (bytes.get(ix) != '\\'.code) {
                output.addByte(bytes.get(ix));
                ix += 1;
                continue;
            }
            ix += 1;
            if (ix >= bytes.length)
                throw new DiffParseError(number, 'invalid path escape');
            final escaped = bytes.get(ix);
            if (escaped >= '0'.code && escaped <= '7'.code) {
                var byte = 0;
                var count = 0;
                while (count < 3 && ix < bytes.length && bytes.get(ix) >= '0'.code && bytes.get(ix) <= '7'.code) {
                    byte = byte * 8 + (bytes.get(ix) - '0'.code);
                    ix += 1;
                    count += 1;
                }
                if (byte > 255)
                    throw new DiffParseError(number, 'invalid octal path escape');
                output.addByte(byte);
            }
            else if (escaped == 'n'.code) {
                output.addByte('\n'.code);
                ix += 1;
            }
            else if (escaped == 't'.code) {
                output.addByte('\t'.code);
                ix += 1;
            }
            else if (escaped == 'r'.code) {
                output.addByte('\r'.code);
                ix += 1;
            }
            else if (escaped == 'a'.code || escaped == 'b'.code || escaped == 'f'.code || escaped == 'v'.code) {
                output.addByte(escaped == 'a'.code ? 7 : escaped == 'b'.code ? 8 : escaped == 'f'.code ? 12 : 11);
                ix += 1;
            }
            else if (escaped == '"'.code || escaped == '\\'.code) {
                output.addByte(escaped);
                ix += 1;
            }
            else {
                throw new DiffParseError(number, 'unsupported path escape');
            }
        }
        final decoded = output.getBytes();
        if (!validUtf8(decoded))
            throw new DiffParseError(number, 'file path is not valid UTF-8');
        return decoded.getString(0, decoded.length, UTF8);
    }

    /** Rust `String::from_utf8` validation. */
    static function validUtf8(bytes:Bytes):Bool {
        var i = 0;
        final n = bytes.length;
        while (i < n) {
            final b = bytes.get(i);
            if (b < 0x80) {
                i++;
                continue;
            }
            var need = 0;
            var min = 0;
            var cp = 0;
            if (b >= 0xC2 && b <= 0xDF) {
                need = 1;
                min = 0x80;
                cp = b & 0x1F;
            }
            else if (b >= 0xE0 && b <= 0xEF) {
                need = 2;
                min = 0x800;
                cp = b & 0x0F;
            }
            else if (b >= 0xF0 && b <= 0xF4) {
                need = 3;
                min = 0x10000;
                cp = b & 0x07;
            }
            else {
                return false;
            }
            for (k in 1...need + 1) {
                if (i + k >= n)
                    return false;
                final c = bytes.get(i + k);
                if (c & 0xC0 != 0x80)
                    return false;
                cp = (cp << 6) | (c & 0x3F);
            }
            if (cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF))
                return false;
            i += need + 1;
        }
        return true;
    }

}

/**
 * One file side while parsing: patch source is appended once, and lines are
 * recorded as ranges until the file is complete.
 */
@:allow(glaze.kit.diff)
private class SideBuilder {

    final parts:Array<String> = [];

    var sourceLen = 0;

    final lines:Array<Array<Int>> = [];

    var noNewline = false;

    function new() {}

    function push(lineNumber:Int, content:String):Int {
        final start = sourceLen;
        parts.push(content);
        parts.push('\n');
        sourceLen += Utf8.byteLength(content) + 1;
        lines.push([lineNumber, start, sourceLen]);
        return lines.length - 1;
    }

    function removeFinalNewline():Void {
        if (lines.length > 0) {
            if (parts.length > 0 && parts[parts.length - 1] == '\n')
                parts.pop();
            sourceLen -= 1;
            lines[lines.length - 1][2] -= 1;
        }
        noNewline = true;
    }

    function lastLine():Null<Int> {
        return lines.length > 0 ? lines[lines.length - 1][0] : null;
    }

    function finish(path:Null<String>):FileSide {
        return new FileSide(path, parts.join(''), lines);
    }

}

@:allow(glaze.kit.diff)
private class ParsedFile {

    var oldPath:Null<String> = null;
    var newPath:Null<String> = null;

    /** Prefixes detected from `diff --git`, stripped from `---` and `+++` paths. */
    var gitPrefixes:Null<Array<String>> = null;

    final original = new SideBuilder();
    final modified = new SideBuilder();
    final pairs:Array<LinePair> = [];
    final hunks:Array<Hunk> = [];

    /** Empty truncated hunks still constrain the next hunk's position. */
    var lastHunkStart:Null<Array<Int>> = null;

    final extendedHeaders:Array<String> = [];
    var binary = false;
    var headers = false;
    var renamed = false;
    var copied = false;

    function new() {}

    function finish():DiffFile {
        final status:DiffFileStatus = if (oldPath == null) {
            Added;
        }
        else if (newPath == null) {
            Deleted;
        }
        else if (copied) {
            Copied;
        }
        else if (renamed) {
            Renamed;
        }
        else {
            Modified;
        }
        return DiffFile.create(status, original.finish(oldPath), modified.finish(newPath), pairs, hunks, extendedHeaders, binary);
    }

    function flushChanges(deleted:Array<Int>, added:Array<Int>):Void {
        final count = deleted.length > added.length ? deleted.length : added.length;
        for (ix in 0...count)
            pairs.push(new LinePair(ix < deleted.length ? deleted[ix] : null, ix < added.length ? added[ix] : null, true));
        deleted.resize(0);
        added.resize(0);
    }

}
