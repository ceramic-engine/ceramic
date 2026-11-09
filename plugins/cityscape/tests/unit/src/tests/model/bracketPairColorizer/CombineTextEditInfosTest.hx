// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/combineTextEditInfos.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;


import cityscape.base.common.RegExp;
import cityscape.common.Model;
import cityscape.common.core.Range;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.BeforeEditPositionMapper;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.CombineTextEditInfos;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import testing.Random;
import testing.TestCase;
import tests.TestTextModel;

/**
 * suite('combineTextEditInfos')
 *
 * Needs a text model: compiled with `-D cityscape_text_model` once the text
 * model is ported (`tests.TestTextModel.createTextModel(text)` is the port
 * of `createTextModel` of testTextModel.ts). Not registered in Tests.hx yet.
 * Monaco's `SingleTextEdit` (textEdit.ts, not ported) is the edit operation
 * `{range, text}` given to `applyEdits`.
 *
 * vscode generates `test0` to `test49` in a loop; they are the 50 seeds of
 * `testSeeds`.
 */
class CombineTextEditInfosTest extends TestCase {

    function testSeeds() {
        for (seed in 0...50) {
            runTest(seed);
        }
    }

    function runTest(seed:Int):Void {
        final rng = Random.create(seed);

        final str = 'abcde\nfghij\nklmno\npqrst\n';
        final textModelS0 = TestTextModel.createTextModel(str);

        final edits1 = getRandomEditInfos(textModelS0, rng.nextIntRange(1, 4), rng);
        final textModelS1 = TestTextModel.createTextModel(textModelS0.getValue());
        textModelS1.applyEdits([for (e in edits1) toEdit(e)]);

        final edits2 = getRandomEditInfos(textModelS1, rng.nextIntRange(1, 4), rng);
        final textModelS2 = TestTextModel.createTextModel(textModelS1.getValue());
        textModelS2.applyEdits([for (e in edits2) toEdit(e)]);

        final combinedEdits = CombineTextEditInfos.combineTextEditInfos(edits1, edits2);
        for (edit in combinedEdits) {
            final range = Range.fromPositions(Length.lengthToPosition(edit.startOffset), Length.lengthToPosition(Length.lengthAdd(edit.startOffset, edit.newLength)));
            final value = textModelS2.getValueInRange(range);
            if (!new RegExp("^(L|C|\\n)*$").test(value)) {
                throw 'Invalid edit: ' + value;
            }
            textModelS2.applyEdits([{
                range: range,
                text: textModelS0.getValueInRange(Range.fromPositions(Length.lengthToPosition(edit.startOffset), Length.lengthToPosition(edit.endOffset))),
            }]);
        }

        assertDeepEquals(textModelS2.getValue(), textModelS0.getValue());

        textModelS0.dispose();
        textModelS1.dispose();
        textModelS2.dispose();
    }

    public static function getRandomEditInfos(textModel:ITextModel, count:Int, rng:Random, disjoint:Bool = false):Array<TextEditInfo> {
        final edits:Array<TextEditInfo> = [];
        var i = 0;
        for (j in 0...count) {
            edits.push(getRandomEdit(textModel, i, rng));
            i = textModel.getOffsetAt(Length.lengthToPosition(edits[j].endOffset)) + (disjoint ? 1 : 0);
        }
        return edits;
    }

    static function getRandomEdit(textModel:ITextModel, rangeOffsetStart:Int, rng:Random):TextEditInfo {
        final textModelLength = textModel.getValueLength();
        final offsetStart = rng.nextIntRange(rangeOffsetStart, textModelLength);
        final offsetEnd = rng.nextIntRange(offsetStart, textModelLength);

        final lineCount = rng.nextIntRange(0, 3);
        final columnCount = rng.nextIntRange(0, 5);

        return new TextEditInfo(Length.positionToLength(textModel.getPositionAt(offsetStart)), Length.positionToLength(textModel.getPositionAt(offsetEnd)), Length.toLength(lineCount, columnCount));
    }

    static function toEdit(editInfo:TextEditInfo):IIdentifiedSingleEditOperation {
        final l = Length.lengthToObj(editInfo.newLength);
        var text = '';

        for (i in 0...l.lineCount) {
            text += 'LLL\n';
        }
        for (i in 0...l.columnCount) {
            text += 'C';
        }

        return {
            range: Range.fromPositions(
                Length.lengthToPosition(editInfo.startOffset),
                Length.lengthToPosition(editInfo.endOffset)
            ),
            text: text
        };
    }

}


