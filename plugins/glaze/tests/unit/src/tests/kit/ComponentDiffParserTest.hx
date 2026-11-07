// Ported from gpui-kit 0.8.1: crates/component/src/diff/parser_tests.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.kit.diff.DiffFile;
import glaze.kit.diff.DiffParseError;
import glaze.kit.diff.DiffParseOptions;
import glaze.kit.diff.DiffSide;
import testing.TestCase;

/**
 * The parser tests of gpui-kit's diff.
 *
 * Line numbers are `Int` in the port: the tests written with `usize::MAX`
 * (18446744073709551615) use the port's bound, `0x7FFFFFFF`, and the values
 * just below it.
 */
class ComponentDiffParserTest extends TestCase {

    static function parseError(patch:String, ?options:DiffParseOptions):Null<DiffParseError> {
        try {
            if (options != null)
                DiffFile.parseWith(patch, options);
            else
                DiffFile.parse(patch);
        }
        catch (e:DiffParseError) {
            return e;
        }
        return null;
    }

    function testSparseHunksPreserveSourceNumbersAndAvailableCopy() {
        final patch = '--- a/src/a.rs\n+++ b/src/a.rs\n@@ -10,2 +20,2 @@ fn first\n keep\n-old\n+new\n@@ -100 +110 @@\n-last\n+next\n';
        final files = DiffFile.parse(patch);
        final doc = files[0];
        assertEquals(2, doc.additions());
        assertEquals(2, doc.deletions());
        assertEquals(3, doc.linesCount(Original));
        assertEquals(21, doc.lineNumber(Modified, 1));
        assertEquals(2, doc.lineIndex(Original, 100));
        assertNull(doc.lineIndex(Original, 50));
        assertEquals('keep\nold\nlast\n', doc.textForLines(Original, 1, 200));
        assertEquals(2, doc.hunks()[1].pairs().start);
        assertEquals('2..3', doc.hunks()[1].lines(Original).toString());
        assertEquals(3, doc.lineNumberDigits());
    }

    function testMultiFileMissingSidesMetadataAndBinary() {
        final patch = 'diff --git a/new b/new\nnew file mode 100644\n--- /dev/null\n+++ b/new\n@@ -0,0 +1 @@\n+added\ndiff --git a/old b/old\ndeleted file mode 100644\n--- a/old\n+++ /dev/null\n@@ -1 +0,0 @@\n-deleted\ndiff --git a/from b/to\nsimilarity index 100%\nrename from from\nrename to to\ndiff --git a/pic b/pic\nBinary files a/pic and b/pic differ\n';
        final files = DiffFile.parse(patch);
        assertEquals(4, files.length);
        assertNull(files[0].originalPath());
        assertEquals('new', files[0].path());
        assertNull(files[1].modifiedPath());
        assertEquals('old', files[1].path());
        assertEquals('from', files[2].originalPath());
        assertEquals('to', files[2].modifiedPath());
        assertTrue(files[2].hasChanges());
        assertTrue(files[3].isBinary());
        assertEquals(0, files[3].linesCount(Original));
    }

    function testNewlineMarkersAndTransportAreDistinct() {
        var files = DiffFile.parse('--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n');
        assertEquals('old', files[0].source(Original));
        assertEquals('new', files[0].source(Modified));
        files = DiffFile.parse('--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\r\n+new\r\n');
        assertEquals('old\r\n', files[0].source(Original));
        files = DiffFile.parse('--- a/a\r\n+++ b/a\r\n@@ -1 +1 @@\r\n-old\r\n+new\r\n');
        assertEquals('old\n', files[0].source(Original));
    }

    function testQuotedGitPathsAndContextPrefixes() {
        final files = DiffFile.parse('diff --git "a/\\344\\270\\255.rs" "b/\\344\\270\\255.rs"\n--- "a/\\344\\270\\255.rs"\n+++ "b/\\344\\270\\255.rs"\n@@ -1,2 +1,2 @@\n --- source text\n-old\n+new\n');
        assertEquals('中.rs', files[0].originalPath());
        assertTrue(StringTools.startsWith(files[0].source(Original), '--- source text\n'));
    }

    function testFormatPatchSignatureEndsTheMessage() {
        final patch = 'From 1a2b Mon Sep 17 00:00:00 2001\nSubject: [PATCH 1/2] Change\n\n---\n a.rs | 2 +-\n 1 file changed\n\ndiff --git a/a.rs b/a.rs\n--- a/a.rs\n+++ b/a.rs\n@@ -1 +1 @@\n-old\n+new\n-- \n2.47.0\n\nFrom 3c4d Mon Sep 17 00:00:00 2001\nSubject: [PATCH 2/2] Again\n\n---\n b.rs | 2 +-\n\ndiff --git a/b.rs b/b.rs\n--- a/b.rs\n+++ b/b.rs\n@@ -1 +1 @@\n-before\n+after\n--\n2.47.0\n';
        final files = DiffFile.parse(patch);
        assertEquals(2, files.length);
        assertEquals('a.rs', files[0].path());
        assertEquals('b.rs', files[1].path());
        assertEquals('after\n', files[1].source(Modified));
    }

    function testGitPrefixConfigurationsResolvePaths() {
        for (item in [
            ['a/src/a.rs b/src/a.rs', 'a/src/a.rs', 'b/src/a.rs'],
            ['i/src/a.rs w/src/a.rs', 'i/src/a.rs', 'w/src/a.rs'],
            ['c/src/a.rs i/src/a.rs', 'c/src/a.rs', 'i/src/a.rs'],
            ['src/a.rs src/a.rs', 'src/a.rs', 'src/a.rs'],
            ['a/dir with space/a.rs b/dir with space/a.rs', 'a/dir with space/a.rs', 'b/dir with space/a.rs'],
        ]) {
            final header = item[0];
            final patch = 'diff --git $header\nindex 1..2 100644\n--- ${item[1]}\n+++ ${item[2]}\n@@ -1 +1 @@\n-old\n+new\n';
            final files = DiffFile.parse(patch);
            final expected = header.indexOf('space') != -1 ? 'dir with space/a.rs' : 'src/a.rs';
            assertEquals(expected, files[0].originalPath(), header);
            assertEquals(expected, files[0].modifiedPath(), header);
        }
        // A mode change has no `---`/`+++` records; the Git header names the file.
        final files = DiffFile.parse('diff --git src/run.sh src/run.sh\nold mode 100644\nnew mode 100755\n');
        assertEquals('src/run.sh', files[0].path());
    }

    function testPlainUnifiedPathsKeepDirectoriesNamedLikePrefixes() {
        var files = DiffFile.parse('--- a/notes.txt\n+++ a/notes.txt\n@@ -1 +1 @@\n-old\n+new\n');
        assertEquals('a/notes.txt', files[0].path());
        files = DiffFile.parse('--- a/notes.txt\n+++ b/notes.txt\n@@ -1 +1 @@\n-old\n+new\n');
        assertEquals('notes.txt', files[0].path());
    }

    function testWhitespaceStrippedContextLinesAreEmptyContext() {
        var files = DiffFile.parse('--- a/a\n+++ b/a\n@@ -1,3 +1,3 @@\n first\n\n-old\n+new\n');
        assertEquals('first\n\nold\n', files[0].source(Original));
        assertEquals('first\n\nnew\n', files[0].source(Modified));
        // A blank line after a complete hunk separates files instead.
        files = DiffFile.parse('--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\n+new\n\n--- a/b\n+++ b/b\n@@ -1 +1 @@\n-x\n+y\n');
        assertEquals(2, files.length);
    }

    function testMalformedHunksFailWithoutPartialDocuments() {
        for (patch in [
            '--- a/a\n+++ b/a\n@@ -1,2 +1,2 @@\n-old\n+new\n',
            '--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\n+new\n+extra\n',
            '--- a/a\n+++ b/a\n@@ -1 +1 @@\n same\n@@ -1 +2 @@\n again\n',
            '--- a/a\n+++ b/a\n@@ -2147483647 +1 @@\n-old\n+new\n',
            'diff --cc a.rs\n@@@ -1 -1 +1 @@@\n',
            '--- /dev/null\n+++ b/a\n@@ -1 +1 @@\n-old\n+new\n',
        ]) {
            final error = parseError(patch);
            assertNotNull(error, patch);
            if (error != null) {
                assertTrue(error.line() > 0);
                assertTrue(error.message().length > 0);
            }
        }
        assertEquals(0, DiffFile.parse('').length);
    }

    function testTruncatedHunksCountTheLinesPresent() {
        final truncated = new DiffParseOptions().truncatedHunks(true);
        assertTrue(truncated.hasTruncatedHunks());
        assertFalse(new DiffParseOptions().hasTruncatedHunks());
        // Cut before the next file, before the next hunk, and at the end of the patch.
        final patch = 'diff --git a/a b/a\n--- a/a\n+++ b/a\n@@ -1,9 +1,9 @@\n keep\n-old\n+new\ndiff --git a/b b/b\n--- a/b\n+++ b/b\n@@ -1,5 +1,5 @@\n-x\n+y\n@@ -10,5 +10,5 @@\n first\n\n-z\n+w\n';
        assertNotNull(parseError(patch));
        final files = DiffFile.parseWith(patch, truncated);
        assertEquals(2, files.length);
        assertTrue(files[0].isTruncated() && files[1].isTruncated());
        assertEquals(1, files[0].additions());
        assertEquals(1, files[0].deletions());
        assertEquals('keep\nold\n', files[0].source(Original));
        assertEquals('keep\nnew\n', files[0].source(Modified));
        final file = files[1];
        assertEquals(2, file.additions());
        assertEquals(2, file.deletions());
        // An empty line inside a short hunk is an empty context line.
        assertEquals('x\nfirst\n\nz\n', file.source(Original));
        assertEquals(12, file.lineNumber(Original, 3));
        assertEquals(12, file.lineNumber(Modified, 3));
        assertEquals(8, file.hunks()[1].hiddenLinesBefore(file.hunks()[0]));
        // Complete hunks parse the same either way.
        final complete = '--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\n+new\n';
        assertFalse(DiffFile.parseWith(complete, truncated)[0].isTruncated());
        assertFalse(DiffFile.parse(complete)[0].isTruncated());
    }

    function testTruncatedHunksKeepStructuralErrors() {
        final truncated = new DiffParseOptions().truncatedHunks(true);
        for (patch in [
            '--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\n+new\n+extra\n',
            '--- a/a\n+++ b/a\n@@ -1 +1 @@\n same\n@@ -1 +2 @@\n again\n',
            '--- a/a\n+++ b/a\n@@ -2147483647,2 +1,2 @@\n a\n',
            '--- a/a\n+++ b/a\n@@ -2147483647,0 +1,2 @@\n',
            '--- a/a\n+++ b/a\n@@ -x +1 @@\n a\n',
            '--- "a/\\q"\n+++ b/a\n@@ -1,3 +1,3 @@\n a\n',
            '--- /dev/null\n+++ b/a\n@@ -1,2 +1,2 @@\n a\n',
        ]) {
            assertNotNull(parseError(patch, truncated), patch);
        }
        // Line numbers stay within the declared range when a hunk ends early.
        var files = DiffFile.parseWith('--- a/a\n+++ b/a\n@@ -2147483646,1 +2147483646,1 @@\n', truncated);
        assertTrue(files[0].isTruncated());
        assertEquals(0, files[0].linesCount(Original));
        files = DiffFile.parseWith('--- a/a\n+++ b/a\n@@ -2147483645,2 +2147483645,2 @@\n same\n', truncated);
        assertEquals(2147483645, files[0].lineNumber(Modified, 0));
    }

    function testNonAsciiLinesAfterAShortHunkDoNotPanic() {
        final patch = '--- a/a\n+++ b/a\n@@ -1,2 +1,2 @@\n-old\n+new\n…\n';
        assertNotNull(parseError(patch));
        final files = DiffFile.parseWith(patch, new DiffParseOptions().truncatedHunks(true));
        assertTrue(files[0].isTruncated());
        assertEquals('old\n', files[0].source(Original));
        assertEquals('new\n', files[0].source(Modified));
    }

    function testTruncatedUnifiedHunksStopBeforeTheNextFileHeaders() {
        final options = new DiffParseOptions().truncatedHunks(true);
        var patch = '--- a/a\n+++ b/a\n@@ -1,9 +1,9 @@\n keep\n--- a/b\n+++ b/b\n@@ -10 +10 @@\n-old\n+new\n';
        var files = DiffFile.parseWith(patch, options);
        assertEquals(2, files.length);
        assertEquals('a', files[0].path());
        assertTrue(files[0].isTruncated());
        assertEquals('keep\n', files[0].source(Original));
        assertEquals('keep\n', files[0].source(Modified));
        assertEquals('b', files[1].path());
        assertFalse(files[1].isTruncated());
        assertEquals('old\n', files[1].source(Original));
        assertEquals('new\n', files[1].source(Modified));

        // Header-looking source remains source when it completes the declared hunk.
        patch = '--- a/a\n+++ b/a\n@@ -1,2 +1,2 @@\n--- source\n+++ source\n tail\n';
        files = DiffFile.parseWith(patch, options);
        assertEquals(1, files.length);
        assertFalse(files[0].isTruncated());
        assertEquals('-- source\ntail\n', files[0].source(Original));
        assertEquals('++ source\ntail\n', files[0].source(Modified));
    }

    function testEmptyTruncatedHunksPreserveOrderOnBothSides() {
        final options = new DiffParseOptions().truncatedHunks(true);
        for (next in ['@@ -1 +1 @@', '@@ -10 +1 @@', '@@ -1 +10 @@']) {
            final patch = '--- a/a\n+++ b/a\n@@ -10,2 +10,2 @@\n$next\n same\n';
            final error = parseError(patch, options);
            assertNotNull(error);
            if (error != null) {
                assertEquals(4, error.line());
                assertEquals('overlapping or unordered hunks', error.message());
            }
        }
        final files = DiffFile.parseWith('--- a/a\n+++ b/a\n@@ -10,2 +10,2 @@\n@@ -20 +20 @@\n same\n', options);
        assertTrue(files[0].isTruncated());
        assertEquals(20, files[0].lineNumber(Original, 0));
    }

}
