// Ported from vscode src/vs/editor/test/node/diffing/fixtures.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.diffing;

import cityscape.base.common.Errors;
import cityscape.common.core.Range;
import cityscape.common.diff.LegacyLinesDiffComputer;
import cityscape.common.diff.LinesDiffComputer;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;
import cityscape.common.diff.defaultLinesDiffComputer.DefaultLinesDiffComputer;
import testing.DeepEquals;
import testing.DiffFixtures;
import testing.TestCase;
import testing.TextEditTestUtils;

/**
 * vscode's diffing fixtures (`fixtures/<folder>`, copied in
 * `tests/unit/data/vscode/diffing/fixtures`): each folder is diffed with the
 * legacy and the advanced algorithm and compared with vscode's
 * `*.expected.diff.json`. vscode rewrites a failing expected file; here a
 * difference is a failure (the files are vscode's truths, never written).
 * The test methods `testFixture_<folder>_<algo>` are generated
 * (`DiffFixtures.buildTests`).
 */
@:build(testing.DiffFixtures.buildTests())
class FixturesTest extends TestCase {

    static var fixtures:Null<Array<DiffFixture>> = null;

    var previousHandler:Null<(e:Dynamic) -> Void> = null;

    override public function setup():Void {
        previousHandler = Errors.unexpectedErrorHandler;
        Errors.unexpectedErrorHandler = (e) -> {
            throw e;
        };
    }

    override public function teardown():Void {
        Errors.unexpectedErrorHandler = previousHandler;
    }

    static function getFixture(folder:String):DiffFixture {
        if (fixtures == null) {
            fixtures = DiffFixtures.load();
        }
        for (f in fixtures) {
            if (f.name == folder) {
                return f;
            }
        }
        throw 'Missing fixture ' + folder;
    }

    static function normalizeLineBreaks(content:String):String {
        return StringTools.replace(StringTools.replace(content, '\r\n', '\n'), '\r', '\n');
    }

    function runTest(folder:String, diffingAlgoName:String):Void {
        final fixture = getFixture(folder);

        final firstFileName = fixture.firstFileName;
        final secondFileName = fixture.secondFileName;

        final firstContent = normalizeLineBreaks(fixture.firstContent);
        final firstContentLines = firstContent.split('\n');
        final secondContent = normalizeLineBreaks(fixture.secondContent);
        final secondContentLines = secondContent.split('\n');

        final diffingAlgo:ILinesDiffComputer = diffingAlgoName == 'legacy' ? new LegacyLinesDiffComputer() : new DefaultLinesDiffComputer();

        final ignoreTrimWhitespace = folder.indexOf('trimws') >= 0;
        final diff = diffingAlgo.computeDiff(firstContentLines, secondContentLines, {ignoreTrimWhitespace: ignoreTrimWhitespace, maxComputationTimeMs: 9007199254740991.0, computeMoves: true});

        if (diffingAlgoName == 'advanced' && !ignoreTrimWhitespace) {
            assertDiffCorrectness(diff, firstContentLines, secondContentLines);
        }

        function formatRange(range:Range, lines:Array<String>):String {
            final toLastChar = range.endColumn == lines[range.endLineNumber - 1].length + 1;

            return '[' + range.startLineNumber + ',' + range.startColumn + ' -> ' + range.endLineNumber + ',' + range.endColumn + (toLastChar ? ' EOL' : '') + ']';
        }

        function getDiffs(changes:Array<DetailedLineRangeMapping>):Array<Any> {
            for (c in changes) {
                RangeMapping.assertSorted(c.innerChanges != null ? c.innerChanges : []);
            }

            return changes.map(c -> ({
                originalRange: c.original.toString(),
                modifiedRange: c.modified.toString(),
                innerChanges: c.innerChanges != null ? c.innerChanges.map(c -> ({
                    originalRange: formatRange(c.originalRange, firstContentLines),
                    modifiedRange: formatRange(c.modifiedRange, secondContentLines),
                } : Any)) : null
            } : Any));
        }

        final actualDiffingResult:Dynamic = {
            original: {content: firstContent, fileName: './' + firstFileName},
            modified: {content: secondContent, fileName: './' + secondFileName},
            diffs: getDiffs(diff.changes),
        };
        if (diff.moves.length > 0) {
            actualDiffingResult.moves = diff.moves.map(v -> ({
                originalRange: v.lineRangeMapping.original.toString(),
                modifiedRange: v.lineRangeMapping.modified.toString(),
                changes: getDiffs(v.changes),
            } : Any));
        }

        final expectedJsonStr = diffingAlgoName == 'legacy' ? fixture.legacyExpected : fixture.advancedExpected;
        if (expectedJsonStr == null) {
            fail('No expected file for ' + folder + ' (' + diffingAlgoName + ')');
            return;
        }
        final expectedFileDiffResult:Any = haxe.Json.parse(expectedJsonStr);
        assertions++;
        final difference = DeepEquals.diffJson(expectedFileDiffResult, actualDiffingResult, folder + '-' + diffingAlgoName);
        if (difference != null) {
            fail(difference);
        }
    }

    /**
     * vscode's `test('test')`: the first fixture run again on its own.
     */
    function testTest():Void {
        runTest('invalid-diff-trimws', 'advanced');
    }

    function assertDiffCorrectness(diff:LinesDiff, original:Array<String>, modified:Array<String>):Void {
        final allInnerChanges:Array<RangeMapping> = [];
        for (c in diff.changes) {
            for (i in c.innerChanges) {
                allInnerChanges.push(i);
            }
        }
        final edit = rangeMappingsToTextEdit(allInnerChanges, new ArrayText(modified));
        final result = edit.normalize().apply(new ArrayText(original));

        assertEquals(modified.join('\n'), result);
    }

    static function rangeMappingsToTextEdit(rangeMappings:Array<RangeMapping>, modified:ArrayText):TextEdit {
        return new TextEdit(rangeMappings.map(m -> {
            return new SingleTextEdit(
                m.originalRange,
                modified.getValueOfRange(m.modifiedRange)
            );
        }));
    }

}
