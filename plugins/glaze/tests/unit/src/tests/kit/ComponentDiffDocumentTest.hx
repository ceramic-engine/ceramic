// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs, conflict.rs and presentation.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.FontWeight;
import glaze.HighlightStyle;
import glaze.Range;
import glaze.kit.base.input.HighlightStyleResolver;
import glaze.kit.diff.ConflictPart;
import glaze.kit.diff.DiffConflict;
import glaze.kit.diff.DiffConflictResolution;
import glaze.kit.diff.DiffFile;
import glaze.kit.diff.DiffFileStatus;
import glaze.kit.diff.DiffParseError;
import glaze.kit.diff.DiffSide;
import glaze.kit.diff.Presentation;
import glaze.kit.diff.DiffInlineUnit;
import glaze.kit.diff.Presentation.DiffStyledRange;
import glaze.kit.diff.Presentation.FilePresentation;
import glaze.kit.diff.Presentation.PresentationOptions;
import glaze.kit.diff.SourceLine;
import glaze.util.Utf8;
import testing.TestCase;
import tests.kit.ComponentDiffFixture as Fixture;
import unicode_segmentation.UnicodeSegmentation;

/**
 * The model tests of gpui-kit's diff: documents, display mapping, chunks,
 * conflicts and prepared presentation.
 */
class ComponentDiffDocumentTest extends TestCase {

    static function ranges(list:Array<Range>):String {
        return '[' + [for (r in list) r.toString()].join(', ') + ']';
    }

    // document.rs

    function testComparisonPreservesSourceAndAlignment() {
        final doc = Fixture.modified('a.rs', 'same\r\n旧值\r\nremoved\r\ntail', 'same\r\n新值\r\ntail\r\n');
        assertEquals(2, doc.additions());
        assertEquals(3, doc.deletions());
        assertEquals('LinePair { original: 0, modified: 0, changed: false }', doc.pairs()[0].toString());
        for (side in [DiffSide.Original, DiffSide.Modified])
            assertEquals(doc.source(side), doc.textForLines(side, 1, Fixture.MAX));
        final same = Fixture.modified('empty', '', '');
        assertFalse(same.hasChanges());
        assertEquals(0, same.linesCount(Original));
        final added = Fixture.document(null, ['new', 'one\n\n']);
        assertEquals(2, added.additions());
        assertEquals(0, added.deletions());
        assertTrue(Lambda.foreach(added.pairs(), p -> p.original() == null));
        final deleted = Fixture.document(['old', 'one\n'], null);
        assertEquals(0, deleted.additions());
        assertEquals(1, deleted.deletions());
        assertTrue(Fixture.document(null, ['empty', '']).hasChanges());
    }

    function testAlignmentCoversEachSourceLineOnce() {
        for (item in [
            ['one\ntwo\n', 'one\ninserted\ntwo\n'],
            ['one\nremoved\ntwo\n', 'one\ntwo\n'],
            ['old one\nold two\n', 'new one\n'],
            ['repeat\nold\nrepeat\nsame\nold again\n', 'repeat\nnew\nrepeat\nsame\nnew again\n'],
            ['same\n', 'same\r\n'],
            ['same\n', 'same'],
            ['a\rb', 'a\rc'],
            ['a\rb\nlast\r', 'a\rc\nlast\r\n'],
            ['', '\n'],
            ['\n', ''],
        ]) {
            final old = item[0];
            final newText = item[1];
            final doc = Fixture.modified('a.txt', old, newText);
            assertEquals([for (i in 0...doc.linesCount(Original)) i].join(','), [for (p in doc.pairs()) if (p.original() != null) p.original()].join(','));
            assertEquals([for (i in 0...doc.linesCount(Modified)) i].join(','), [for (p in doc.pairs()) if (p.modified() != null) p.modified()].join(','));
            assertEquals(doc.deletions(), Lambda.count(doc.pairs(), p -> p.isChanged() && p.original() != null));
            assertEquals(doc.additions(), Lambda.count(doc.pairs(), p -> p.isChanged() && p.modified() != null));
            assertTrue(doc.hasChanges());
            for (pair in doc.pairs()) {
                if (!pair.isChanged()) {
                    final oldLine = doc.lines(Original)[pair.original()];
                    final newLine = doc.lines(Modified)[pair.modified()];
                    assertEquals(Utf8.substring(old, oldLine.source().start, oldLine.source().end),
                        Utf8.substring(newText, newLine.source().start, newLine.source().end));
                }
            }
        }
        final doc = Fixture.modified('a.txt', 'same\nold\ntail\n', 'same\nnew\nextra\ntail\n');
        assertEquals('LinePair { original: 1, modified: 1, changed: true }', doc.pairs()[1].toString());
        assertEquals('LinePair { original: null, modified: 2, changed: true }', doc.pairs()[2].toString());
        assertEquals('new\nextra\n', doc.textForLines(Modified, 2, 3));
        assertEquals('', doc.textForLines(Original, 99, 100));
        final bareCr = Fixture.modified('a.txt', 'a\rb', 'a\rb');
        assertFalse(bareCr.hasChanges());
        assertEquals(1, bareCr.linesCount(Original));
        assertEquals(1, bareCr.pairs().length);
    }

    function testSourceDisplayMappingPreservesTabsAndUnicode() {
        final lines = SourceLine.sourceLines('é\t中\t\r\nlast\r');
        final first = lines[0];
        assertEquals('é\t中\t', first.text());
        assertEquals('é   中   ', first.display());
        assertEquals('0..9', first.source().toString());
        assertEquals(7, first.contentEnd());
        assertEquals(2, @:privateAccess first.displayTabs.length);
        assertEquals('2..5', first.displayRange(new Range(2, 3)).toString());
        assertEquals('8..11', first.displayRange(new Range(6, 7)).toString());
        assertEquals(new Range(0, first.displayLen()).toString(), first.displayRange(new Range(0, first.textLen())).toString());
        for (offset in 2...5)
            assertEquals(2, first.sourceOffset(offset));
        assertEquals(3, first.sourceOffset(5));
        assertEquals(first.textLen(), first.sourceOffset(first.displayLen()));
        assertEquals(first.textLen(), first.sourceOffset(Fixture.MAX));
        assertEquals('last\r', lines[1].text());
        assertEquals(0, @:privateAccess lines[1].displayTabs.length);
        assertEquals(2, lines[1].sourceOffset(2));
        assertEquals(lines[1].textLen(), lines[1].sourceOffset(Fixture.MAX));
        assertEquals('1..4', lines[1].displayRange(new Range(1, 4)).toString());
        final plainUnicode = SourceLine.sourceLines('中é');
        assertEquals(0, @:privateAccess plainUnicode[0].displayTabs.length);
        assertEquals('3..5', plainUnicode[0].displayRange(new Range(3, 5)).toString());
        assertEquals(3, plainUnicode[0].sourceOffset(3));
        assertEquals(0, SourceLine.sourceLines('').length);
        assertEquals(1, SourceLine.sourceLines('\n').length);
        // Compare every byte against the former dense mapping, including
        // UTF-8 interiors and all spaces belonging to each expanded tab.
        final expected = [0, 1, 2, 2, 2, 3, 4, 5, 6, 6, 6, 7];
        for (displayOffset in 0...expected.length)
            assertEquals(expected[displayOffset], first.sourceOffset(displayOffset));
        final expectedDisplay = [0, 1, 2, 5, 6, 7, 8, 11];
        for (sourceOffset in 0...expectedDisplay.length)
            assertEquals(new Range(expectedDisplay[sourceOffset], expectedDisplay[sourceOffset]).toString(),
                first.displayRange(new Range(sourceOffset, sourceOffset)).toString());
        final adjacentTabs = SourceLine.sourceLines('\t\té\t');
        assertEquals('        é   ', adjacentTabs[0].display());
        assertEquals(3, @:privateAccess adjacentTabs[0].displayTabs.length);
        final expectedAdjacent = [0, 4, 8, 9, 10, 13];
        for (sourceOffset in 0...expectedAdjacent.length)
            assertEquals(new Range(expectedAdjacent[sourceOffset], expectedAdjacent[sourceOffset]).toString(),
                adjacentTabs[0].displayRange(new Range(sourceOffset, sourceOffset)).toString());
        // Rust checks that the display shares the text's storage; Haxe
        // strings are values, the display is the text itself.
        final longLine = SourceLine.sourceLines('a long source line without tabs uses shared heap storage');
        assertEquals(longLine[0].text(), longLine[0].display());
        final longTabLine = SourceLine.sourceLines(StringTools.lpad('', 'a', 100000) + '\t');
        assertEquals(1, @:privateAccess longTabLine[0].displayTabs.length);
    }

    function testDisplayChunksRetainCompleteUtf8Source() {
        final ordinary = 'an ordinary line uses the existing shared display string';
        final longGrapheme = 'a' + [for (_ in 0...600) '\u{301}'].join('');
        final repeated = [for (_ in 0...200) 'é👩‍💻中'].join('');
        for (text in ['', ordinary, repeated, longGrapheme]) {
            final chunks = SourceLine.displayChunks(text);
            var previousEnd = 0;
            for (range in chunks) {
                assertEquals(previousEnd, range.start);
                assertTrue(range.len() <= 512);
                assertTrue(Utf8.isCharBoundary(text, range.start) && Utf8.isCharBoundary(text, range.end));
                previousEnd = range.end;
            }
            assertEquals(Utf8.byteLength(text), previousEnd);
            assertEquals(text, [for (range in chunks) Utf8.substring(text, range.start, range.end)].join(''));
            if (text.length == 0)
                continue;
            final line = SourceLine.sourceLines(text)[0];
            assertEquals(chunks.length, line.chunkRanges().length);
            assertEquals(line.display(), line.chunkText(new Range(0, line.displayLen())));
            for (range in line.chunkRanges())
                assertEquals(Utf8.substring(text, range.start, range.end), line.chunkText(range));
        }
        final boundaries = [];
        final indices = UnicodeSegmentation.graphemeIndices(repeated, true);
        while (indices.next() != null)
            boundaries.push(indices.index);
        boundaries.push(Utf8.byteLength(repeated));
        for (range in SourceLine.displayChunks(repeated))
            assertTrue(boundaries.indexOf(range.start) != -1 && boundaries.indexOf(range.end) != -1);
    }

    // conflict.rs

    static final MERGE = 'fn retry() {\n<<<<<<< HEAD\n    3\n=======\n    5\n>>>>>>> feature\n}\n';

    function testUnchangedFilesShowEveryLineOnce() {
        final file = DiffFile.unchanged('src/lib.rs', 'one\r\ntwo\nlast');
        assertEquals(DiffFileStatus.Unchanged, file.status());
        assertFalse(file.hasChanges());
        assertEquals(3, file.linesCount(Modified));
        assertEquals(0, file.linesCount(Original));
        assertEquals('one\r\ntwo\nlast', file.textForLines(Modified, 1, 3));
        assertEquals(0, DiffFile.unchanged('empty', '').pairs().length);
    }

    function testConflictsKeepWorkingFileLineNumbers() {
        final file = DiffFile.parseConflicts('src/retry.rs', MERGE);
        assertEquals(DiffFileStatus.Conflicted, file.status());
        assertEquals('1,3,5,7', [for (line in file.lines(Modified)) line.lineNumber()].join(','));
        final conflict = file.conflicts()[0];
        assertEquals('2..7', conflict.lines().toString());
        assertEquals('3..4', conflict.currentLines().toString());
        assertEquals('5..6', conflict.incomingLines().toString());
        assertNull(conflict.baseLines());
        assertNull(conflict.baseLabel());
        assertEquals('HEAD', conflict.currentLabel());
        assertEquals('feature', conflict.incomingLabel());
        assertEquals('1..2', @:privateAccess conflict.part(ConflictPart.Current).toString());
        assertEquals('2..3', @:privateAccess conflict.part(ConflictPart.Incoming).toString());
        assertEquals('HEAD', @:privateAccess conflict.label(ConflictPart.Current));
        assertEquals('feature', @:privateAccess conflict.label(ConflictPart.Incoming));
        assertEquals(ConflictPart.Incoming, @:privateAccess conflict.partOf(2));
        assertTrue(file.pairs()[1].isChanged() && !file.pairs()[0].isChanged());
    }

    function testDiff3BasesAndMalformedMarkers() {
        final file = DiffFile.parseConflicts('a.txt', '<<<<<<< ours\na\n||||||| base\nb\n=======\nc\n>>>>>>> theirs\n');
        final conflict = file.conflicts()[0];
        assertEquals('1..8', conflict.lines().toString());
        assertEquals('2..3', conflict.currentLines().toString());
        assertEquals('4..5', conflict.baseLines().toString());
        assertEquals('6..7', conflict.incomingLines().toString());
        assertEquals('base', conflict.baseLabel());
        assertEquals('1..2', @:privateAccess conflict.part(ConflictPart.Base).toString());
        assertEquals('base', @:privateAccess conflict.label(ConflictPart.Base));
        assertEquals('[0..1, 2..3]', ranges(@:privateAccess conflict.kept(DiffConflictResolution.Both)));
        for (text in ['<<<<<<< a\nx\n', '<<<<<<< a\n<<<<<<< b\n', '>>>>>>> stray\n']) {
            var error:Null<DiffParseError> = null;
            try {
                DiffFile.parseConflicts('a.txt', text);
            }
            catch (e:DiffParseError) {
                error = e;
            }
            assertNotNull(error, text);
            if (error != null)
                assertTrue(error.line() > 0);
        }
        final empty = DiffFile.parseConflicts('empty.txt', '<<<<<<< ours\n||||||| base\n=======\n>>>>>>> theirs\n');
        final conflict = empty.conflicts()[0];
        assertEquals('1..5', conflict.lines().toString());
        assertEquals('2..2', conflict.currentLines().toString());
        assertEquals('3..3', conflict.baseLines().toString());
        assertEquals('4..4', conflict.incomingLines().toString());
        // A separator outside a conflict is ordinary text.
        var ok = true;
        try {
            DiffFile.parseConflicts('a.md', 'title\n=======\n');
        }
        catch (e:DiffParseError) {
            ok = false;
        }
        assertTrue(ok);
    }

    // presentation.rs

    static function options():PresentationOptions {
        return new PresentationOptions(Word, 1000, 1000);
    }

    function testLanguageDetectionUsesFilename() {
        for (item in [
            ['src/main.RS', 'rust'],
            ['src/components/App.jsx', 'javascript'],
            ['C:\\src\\lib.hpp', 'cpp'],
            ['build/CMakeLists.txt', 'cmake'],
            ['build/Makefile', 'make'],
            ['directory.rs/README', 'text'],
            ['ts', 'text'],
            ['notes.unknown', 'text'],
        ]) {
            assertEquals(item[1], Presentation.detectedLanguage(item[0]), item[0]);
        }
        final file = DiffFile.parse('--- a/notes\n+++ b/notes\n@@ -1 +1 @@\n-a\n+b\n')[0];
        assertEquals('text', file.language());
        assertEquals('rust', file.withLanguage('rust').language());
    }

    function testInlineChangesMergeWordsAcrossWhitespaceAndSkipUnrelatedLines() {
        var runs = Presentation.changedRuns('let total = price * count;', 'let total = cost * quantity;', Word);
        assertEquals('[12..17, 20..25]', ranges(runs.old));
        assertEquals('[12..16, 19..27]', ranges(runs.newRuns));
        runs = Presentation.changedRuns('old value here', 'new value here', Word);
        assertEquals('[0..3]', ranges(runs.old));
        assertEquals('[0..3]', ranges(runs.newRuns));
        runs = Presentation.changedRuns('a b c', 'a x y c', Word);
        assertEquals('[2..5]', ranges(runs.newRuns));
        assertTrue(runs.old.length == 0 || ranges(runs.old) == '[2..3]');
        runs = Presentation.changedRuns('colour', 'color', Character);
        assertEquals('[4..5]', ranges(runs.old));
        assertEquals('[]', ranges(runs.newRuns));
        runs = Presentation.changedRuns('alpha', 'zzzzzzzzz', Word);
        assertTrue(runs.old.length == 0 && runs.newRuns.length == 0);
    }

    function testInlineChangesCoverPairedLinesOnly() {
        var file = DiffFile.parse('--- a/a.txt\n+++ b/a.txt\n@@ -1,2 +1,3 @@\n-let total = price * count;\n same\n+let total = cost * count;\n+added\n')[0];
        var presentation = @:privateAccess FilePresentation.prepare(file, options(), new Map(), null);
        // The deletion and the first addition are in different change runs,
        // so they are not paired.
        assertEquals(0, presentation.inlineChanges(file.lines(Original)[0], Original, 0).length);
        file = DiffFile.parse('--- a/a.txt\n+++ b/a.txt\n@@ -1 +1,2 @@\n-let total = price * count;\n+let total = cost * count;\n+added\n')[0];
        presentation = @:privateAccess FilePresentation.prepare(file, options(), new Map(), null);
        assertEquals('[12..17]', ranges(presentation.inlineChanges(file.lines(Original)[0], Original, 0)));
        assertEquals('[12..16]', ranges(presentation.inlineChanges(file.lines(Modified)[0], Modified, 0)));
        assertEquals(0, presentation.inlineChanges(file.lines(Modified)[1], Modified, 1).length);
        final off = new PresentationOptions(null, 1000, 1000);
        presentation = @:privateAccess FilePresentation.prepare(file, off, new Map(), null);
        assertEquals(0, presentation.inlineChanges(file.lines(Original)[0], Original, 0).length);
    }

    function testAnApplicationHighlighterStylesEachHunkSideOnItsOwn() {
        final file = DiffFile.parse('--- a/a.rs\n+++ b/a.rs\n@@ -1,2 +1,2 @@\n-let a = 1;\n+let a = 2;\n /* open\n@@ -10,2 +10,2 @@\n close */\n-let old = 0;\n+let new = 0;\n')[0];
        final bold = new HighlightStyle(null, FontWeight.BOLD);
        final calls:Array<Array<String>> = [];
        function highlighter(language:String, text:String):Array<DiffStyledRange> {
            calls.push([language, text]);
            final rv = [];
            var at = 0;
            while (true) {
                final ix = text.indexOf('let', at);
                if (ix == -1)
                    break;
                final start = Utf8.indexToByteOffset(text, ix);
                rv.push(new DiffStyledRange(new Range(start, start + 3), bold));
                at = ix + 3;
            }
            return rv;
        }
        final presentation = @:privateAccess FilePresentation.prepare(file, options(), new Map(), highlighter);

        // Each side of each hunk alone, named by the file's language.
        assertEquals(4, calls.length);
        assertTrue(Lambda.foreach(calls, c -> c[0] == 'rust'));
        assertTrue(Lambda.foreach(calls, c -> !(c[1].indexOf('open') != -1 && c[1].indexOf('close') != -1)));
        final noTheme = new NoTheme();
        function styles(presentation:FilePresentation, side:DiffSide, ix:Int):String {
            return [
                for (s in presentation.syntaxHighlights(file.lines(side)[ix], side, ix, noTheme))
                    s.range.toString() + ':' + (s.style.equals(bold) ? 'bold' : 'other')
            ].join(',');
        }
        assertEquals('0..3:bold', styles(presentation, Modified, 0));
        assertEquals('0..3:bold', styles(presentation, Original, 3));
        assertEquals('', styles(presentation, Modified, 1));

        final short = new PresentationOptions(Word, 1000, 5);
        final presentation = @:privateAccess FilePresentation.prepare(file, short, new Map(), highlighter);
        assertEquals('', styles(presentation, Modified, 0));

        // `é` is two bytes, so 5..6 splits it: counted in characters, not bytes.
        final file = DiffFile.parse('--- a/a.rs\n+++ b/a.rs\n@@ -1 +1 @@\n-let é = 1;\n+let é = 2;\n')[0];
        function split(_:String, _:String):Array<DiffStyledRange> {
            return [
                new DiffStyledRange(new Range(0, 3), bold),
                new DiffStyledRange(new Range(5, 6), bold),
                new DiffStyledRange(new Range(4, 6), bold)
            ];
        }
        final presentation = @:privateAccess FilePresentation.prepare(file, options(), new Map(), split);
        assertEquals('0..3:bold,4..6:bold', [
            for (s in presentation.syntaxHighlights(file.lines(Modified)[0], Modified, 0, noTheme))
                s.range.toString() + ':' + (s.style.equals(bold) ? 'bold' : 'other')
        ].join(','));
    }

}

private class NoTheme implements HighlightStyleResolver {

    public function new() {}

    public function style(_:String):Null<HighlightStyle> {
        return null;
    }

}
