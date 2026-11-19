// Ported from vscode src/vs/editor/test/common/model/model.line.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.Cityscape;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.common.tokens.ContiguousMultilineTokensBuilder;
import cityscape.common.tokens.LineTokens;
import haxe.io.UInt32Array;
import testing.TestCase;
import tests.TestTextModel;

private typedef ILineEdit = {
    startColumn:Int,
    endColumn:Int,
    text:String
}

private typedef IBufferLineState = {
    text:String,
    tokens:Array<TestToken>
}

private typedef IEdit = {
    range:Range,
    text:String
}

private class TestToken {

    public final startOffset:Int;

    public final color:Int;

    public function new(startOffset:Int, color:Int) {
        this.startOffset = startOffset;
        this.color = color;
    }

    public static function toTokens(tokens:Array<TestToken>):UInt32Array {
        final tokensLen = tokens.length;
        final result = new UInt32Array((tokensLen << 1));
        for (i in 0...tokensLen) {
            final token = tokens[i];
            result[(i << 1)] = token.startOffset;
            result[(i << 1) + 1] = (
                token.color << MetadataConsts.FOREGROUND_OFFSET
            ) >>> 0;
        }
        return result;
    }

}

private class ManualTokenizationSupport implements ITokenizationSupport {

    final tokens = new Map<Int, UInt32Array>();

    final stores:Array<IBackgroundTokenizationStore> = [];

    public function new() {}

    public function setLineTokens(lineNumber:Int, tokens:UInt32Array):Void {
        final b = new ContiguousMultilineTokensBuilder();
        b.add(lineNumber, tokens);
        for (s in stores.copy()) {
            s.setTokens(b.finalize());
        }
    }

    public function getInitialState():IState {
        return new LineState(1);
    }

    public function tokenize(line:String, hasEOL:Bool, state:IState):TokenizationResult {
        throw 'Not supported';
    }

    public function tokenizeEncoded(line:String, hasEOL:Bool, state:IState):EncodedTokenizationResult {
        final s:LineState = cast state;
        return new EncodedTokenizationResult(tokens.get(s.lineNumber), new LineState(s.lineNumber + 1));
    }

    public function createBackgroundTokenizer(textModel:ITextModel, store:IBackgroundTokenizationStore):Null<IBackgroundTokenizer> {
        stores.push(store);
        return new ManualBackgroundTokenizer(() -> stores.remove(store));
    }

}

private class ManualBackgroundTokenizer implements IBackgroundTokenizer {

    final onDispose:() -> Void;

    public function new(onDispose:() -> Void) {
        this.onDispose = onDispose;
    }

    public function dispose():Void {
        onDispose();
    }

    public function requestTokens(startLineNumber:Int, endLineNumberExclusive:Int):Void {}

}

private class LineState implements IState {

    public final lineNumber:Int;

    public function new(lineNumber:Int) {
        this.lineNumber = lineNumber;
    }

    public function clone():IState {
        return this;
    }

    public function equals(other:IState):Bool {
        return (cast other : LineState).lineNumber == lineNumber;
    }

}

/**
 * vscode's `createTextModel(text, 'test')` with a `ManualTokenizationSupport`
 * registered for 'test' (`TokenizationRegistry.register('test', s)`), in a
 * context of its own.
 */
private class ModelLinesTokensHarness {

    public final model:TextModel;

    public final s = new ManualTokenizationSupport();

    final d:cityscape.base.common.Lifecycle.IDisposable;

    public function new(text:String) {
        final context = new Cityscape();
        d = context.tokenizationRegistry.register('test', s);
        model = TestTextModel.instantiateTextModel(context, text, 'test');
    }

    public function getLineContent(lineNumber:Int):String {
        return model.getLineContent(lineNumber);
    }

    public function getLineMaxColumn(lineNumber:Int):Int {
        return model.getLineMaxColumn(lineNumber);
    }

    public function setLineTokens(lineNumber:Int, tokens:UInt32Array):Void {
        s.setLineTokens(lineNumber, tokens);
    }

    public function applyEdits(edits:Array<IEdit>):Void {
        model.applyEdits([for (ed in edits) {
            identifier: null,
            range: ed.range,
            text: ed.text,
            forceMoveMarkers: false
        }]);
    }

    public function getLineTokens(lineNumber:Int):LineTokens {
        return model.tokenization.getLineTokens(lineNumber);
    }

    public function dispose():Void {
        model.dispose();
        d.dispose();
    }

}

/**
 * Suite 'ModelLinesTokens' of model.line.test.ts (the suite 'ModelLine -
 * getIndentLevel' is `ModelLineTest.ModelLineGetIndentLevelTest`). The
 * helpers `testApplyEdits`, `testLineEditTokens`, `testLineSplitTokens` and
 * `testLineAppendTokens` are named `check...` (the runner runs every method
 * starting with `test`).
 */
class ModelLinesTokensTest extends TestCase {

    function assertLineTokens(__actual:LineTokens, _expected:Array<TestToken>, ?pos:haxe.PosInfos):Void {
        final tmp = TestToken.toTokens(_expected);
        LineTokens.convertToEndOffset(tmp, __actual.getLineContent().length);
        // TestLineTokenFactory.inflateArr(tmp).map(decode)
        final expected:Array<{endIndex:Int, type:String}> = [];
        for (i in 0...(tmp.length >>> 1)) {
            final endOffset:Int = tmp[i << 1];
            final metadata:Int = tmp[(i << 1) + 1];
            expected.push({endIndex: endOffset, type: TokenMetadata.getClassNameFromMetadata(metadata)});
        }
        final _actual = __actual.inflate();
        final actual:Array<{endIndex:Int, type:String}> = [];
        for (i in 0..._actual.getCount()) {
            actual[i] = {
                endIndex: _actual.getEndOffset(i),
                type: _actual.getClassName(i)
            };
        }
        assertDeepEquals(expected, actual, null, pos);
    }

    function checkApplyEdits(initial:Array<IBufferLineState>, edits:Array<IEdit>, expected:Array<IBufferLineState>, ?pos:haxe.PosInfos):Void {
        final initialText = initial.map(el -> el.text).join('\n');

        final model = new ModelLinesTokensHarness(initialText);
        model.model.onBeforeAttached();
        for (lineIndex in 0...initial.length) {
            final lineTokens = initial[lineIndex].tokens;
            final lineTextLength = model.getLineMaxColumn(lineIndex + 1) - 1;
            final tokens = TestToken.toTokens(lineTokens);
            LineTokens.convertToEndOffset(tokens, lineTextLength);
            model.setLineTokens(lineIndex + 1, tokens);
        }

        model.applyEdits(edits);

        for (lineIndex in 0...expected.length) {
            final actualLine = model.getLineContent(lineIndex + 1);
            final actualTokens = model.getLineTokens(lineIndex + 1);
            assertEquals(expected[lineIndex].text, actualLine, null, pos);
            assertLineTokens(actualTokens, expected[lineIndex].tokens, pos);
        }

        model.dispose();
    }

    function checkLineEditTokens(initialText:String, initialTokens:Array<TestToken>, edits:Array<ILineEdit>, expectedText:String, expectedTokens:Array<TestToken>, ?pos:haxe.PosInfos):Void {
        checkApplyEdits(
            [{
                text: initialText,
                tokens: initialTokens
            }],
            edits.map((ed) -> ({
                range: new Range(1, ed.startColumn, 1, ed.endColumn),
                text: ed.text
            } : IEdit)),
            [{
                text: expectedText,
                tokens: expectedTokens
            }],
            pos
        );
    }

    function checkLineSplitTokens(initialText:String, initialTokens:Array<TestToken>, splitColumn:Int, expectedText1:String, expectedText2:String, expectedTokens:Array<TestToken>, ?pos:haxe.PosInfos):Void {
        checkApplyEdits(
            [{
                text: initialText,
                tokens: initialTokens
            }],
            [{
                range: new Range(1, splitColumn, 1, splitColumn),
                text: '\n'
            }],
            [{
                text: expectedText1,
                tokens: expectedTokens
            }, {
                text: expectedText2,
                tokens: [new TestToken(0, 1)]
            }],
            pos
        );
    }

    function checkLineAppendTokens(aText:String, aTokens:Array<TestToken>, bText:String, bTokens:Array<TestToken>, expectedText:String, expectedTokens:Array<TestToken>, ?pos:haxe.PosInfos):Void {
        checkApplyEdits(
            [{
                text: aText,
                tokens: aTokens
            }, {
                text: bText,
                tokens: bTokens
            }],
            [{
                range: new Range(1, aText.length + 1, 2, 1),
                text: ''
            }],
            [{
                text: expectedText,
                tokens: expectedTokens
            }],
            pos
        );
    }

    function testInsertionOnEmptyLine() {
        final model = new ModelLinesTokensHarness('some text');
        final tokens = TestToken.toTokens([new TestToken(0, 1)]);
        LineTokens.convertToEndOffset(tokens, model.getLineMaxColumn(1) - 1);
        model.setLineTokens(1, tokens);

        model.applyEdits([{
            range: new Range(1, 1, 1, 10),
            text: ''
        }]);

        model.setLineTokens(1, new UInt32Array(0));

        model.applyEdits([{
            range: new Range(1, 1, 1, 1),
            text: 'a'
        }]);

        final actualTokens = model.getLineTokens(1);
        assertLineTokens(actualTokens, [new TestToken(0, 1)]);

        model.dispose();
    }

    function testSingleDelete1() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 1, 1, 2), text: ''}],
            [{
                text: 'ello world',
                tokens: [new TestToken(0, 1), new TestToken(4, 2), new TestToken(5, 3)]
            }]
        );
    }

    function testSingleDelete2() {
        checkApplyEdits(
            [{
                text: 'helloworld',
                tokens: [new TestToken(0, 1), new TestToken(5, 2)]
            }],
            [{range: new Range(1, 3, 1, 8), text: ''}],
            [{
                text: 'herld',
                tokens: [new TestToken(0, 1), new TestToken(2, 2)]
            }]
        );
    }

    function testSingleDelete3() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 1, 1, 6), text: ''}],
            [{
                text: ' world',
                tokens: [new TestToken(0, 2), new TestToken(1, 3)]
            }]
        );
    }

    function testSingleDelete4() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 2, 1, 7), text: ''}],
            [{
                text: 'hworld',
                tokens: [new TestToken(0, 1), new TestToken(1, 3)]
            }]
        );
    }

    function testSingleDelete5() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 1, 1, 12), text: ''}],
            [{
                text: '',
                tokens: [new TestToken(0, 1)]
            }]
        );
    }

    function testMultiDelete6() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 4), new TestToken(5, 5), new TestToken(6, 6)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 7), new TestToken(5, 8), new TestToken(6, 9)]
            }],
            [{range: new Range(1, 6, 3, 6), text: ''}],
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 8), new TestToken(6, 9)]
            }]
        );
    }

    function testMultiDelete7() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 4), new TestToken(5, 5), new TestToken(6, 6)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 7), new TestToken(5, 8), new TestToken(6, 9)]
            }],
            [{range: new Range(1, 12, 3, 12), text: ''}],
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }]
        );
    }

    function testMultiDelete8() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 4), new TestToken(5, 5), new TestToken(6, 6)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 7), new TestToken(5, 8), new TestToken(6, 9)]
            }],
            [{range: new Range(1, 1, 3, 1), text: ''}],
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 7), new TestToken(5, 8), new TestToken(6, 9)]
            }]
        );
    }

    function testMultiDelete9() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 4), new TestToken(5, 5), new TestToken(6, 6)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 7), new TestToken(5, 8), new TestToken(6, 9)]
            }],
            [{range: new Range(1, 12, 3, 1), text: ''}],
            [{
                text: 'hello worldhello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3), new TestToken(11, 7), new TestToken(16, 8), new TestToken(17, 9)]
            }]
        );
    }

    function testSingleInsert1() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 1, 1, 1), text: 'xx'}],
            [{
                text: 'xxhello world',
                tokens: [new TestToken(0, 1), new TestToken(7, 2), new TestToken(8, 3)]
            }]
        );
    }

    function testSingleInsert2() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 2, 1, 2), text: 'xx'}],
            [{
                text: 'hxxello world',
                tokens: [new TestToken(0, 1), new TestToken(7, 2), new TestToken(8, 3)]
            }]
        );
    }

    function testSingleInsert3() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 6, 1, 6), text: 'xx'}],
            [{
                text: 'helloxx world',
                tokens: [new TestToken(0, 1), new TestToken(7, 2), new TestToken(8, 3)]
            }]
        );
    }

    function testSingleInsert4() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 7, 1, 7), text: 'xx'}],
            [{
                text: 'hello xxworld',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(8, 3)]
            }]
        );
    }

    function testSingleInsert5() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 12, 1, 12), text: 'xx'}],
            [{
                text: 'hello worldxx',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }]
        );
    }

    function testMultiInsert6() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 1, 1, 1), text: '\n'}],
            [{
                text: '',
                tokens: [new TestToken(0, 1)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 1)]
            }]
        );
    }

    function testMultiInsert7() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 12, 1, 12), text: '\n'}],
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }, {
                text: '',
                tokens: [new TestToken(0, 1)]
            }]
        );
    }

    function testMultiInsert8() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }],
            [{range: new Range(1, 7, 1, 7), text: '\n'}],
            [{
                text: 'hello ',
                tokens: [new TestToken(0, 1), new TestToken(5, 2)]
            }, {
                text: 'world',
                tokens: [new TestToken(0, 1)]
            }]
        );
    }

    function testMultiInsert9() {
        checkApplyEdits(
            [{
                text: 'hello world',
                tokens: [new TestToken(0, 1), new TestToken(5, 2), new TestToken(6, 3)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 4), new TestToken(5, 5), new TestToken(6, 6)]
            }],
            [{range: new Range(1, 7, 1, 7), text: 'xx\nyy'}],
            [{
                text: 'hello xx',
                tokens: [new TestToken(0, 1), new TestToken(5, 2)]
            }, {
                text: 'yyworld',
                tokens: [new TestToken(0, 1)]
            }, {
                text: 'hello world',
                tokens: [new TestToken(0, 4), new TestToken(5, 5), new TestToken(6, 6)]
            }]
        );
    }

    function testUpdatesTokensOnInsertion1() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 1,
                endColumn: 1,
                text: 'a'
            }],
            'aabcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(5, 2),
                new TestToken(6, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion2() {
        checkLineEditTokens(
            'aabcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(5, 2),
                new TestToken(6, 3)
            ],
            [{
                startColumn: 2,
                endColumn: 2,
                text: 'x'
            }],
            'axabcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(6, 2),
                new TestToken(7, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion3() {
        checkLineEditTokens(
            'axabcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(6, 2),
                new TestToken(7, 3)
            ],
            [{
                startColumn: 3,
                endColumn: 3,
                text: 'stu'
            }],
            'axstuabcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(9, 2),
                new TestToken(10, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion4() {
        checkLineEditTokens(
            'axstuabcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(9, 2),
                new TestToken(10, 3)
            ],
            [{
                startColumn: 10,
                endColumn: 10,
                text: '\t'
            }],
            'axstuabcd\t efgh',
            [
                new TestToken(0, 1),
                new TestToken(10, 2),
                new TestToken(11, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion5() {
        checkLineEditTokens(
            'axstuabcd\t efgh',
            [
                new TestToken(0, 1),
                new TestToken(10, 2),
                new TestToken(11, 3)
            ],
            [{
                startColumn: 12,
                endColumn: 12,
                text: 'dd'
            }],
            'axstuabcd\t ddefgh',
            [
                new TestToken(0, 1),
                new TestToken(10, 2),
                new TestToken(13, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion6() {
        checkLineEditTokens(
            'axstuabcd\t ddefgh',
            [
                new TestToken(0, 1),
                new TestToken(10, 2),
                new TestToken(13, 3)
            ],
            [{
                startColumn: 18,
                endColumn: 18,
                text: 'xyz'
            }],
            'axstuabcd\t ddefghxyz',
            [
                new TestToken(0, 1),
                new TestToken(10, 2),
                new TestToken(13, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion7() {
        checkLineEditTokens(
            'axstuabcd\t ddefghxyz',
            [
                new TestToken(0, 1),
                new TestToken(10, 2),
                new TestToken(13, 3)
            ],
            [{
                startColumn: 1,
                endColumn: 1,
                text: 'x'
            }],
            'xaxstuabcd\t ddefghxyz',
            [
                new TestToken(0, 1),
                new TestToken(11, 2),
                new TestToken(14, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion8() {
        checkLineEditTokens(
            'xaxstuabcd\t ddefghxyz',
            [
                new TestToken(0, 1),
                new TestToken(11, 2),
                new TestToken(14, 3)
            ],
            [{
                startColumn: 22,
                endColumn: 22,
                text: 'x'
            }],
            'xaxstuabcd\t ddefghxyzx',
            [
                new TestToken(0, 1),
                new TestToken(11, 2),
                new TestToken(14, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion9() {
        checkLineEditTokens(
            'xaxstuabcd\t ddefghxyzx',
            [
                new TestToken(0, 1),
                new TestToken(11, 2),
                new TestToken(14, 3)
            ],
            [{
                startColumn: 2,
                endColumn: 2,
                text: ''
            }],
            'xaxstuabcd\t ddefghxyzx',
            [
                new TestToken(0, 1),
                new TestToken(11, 2),
                new TestToken(14, 3)
            ]
        );
    }

    function testUpdatesTokensOnInsertion10() {
        checkLineEditTokens(
            '',
            [],
            [{
                startColumn: 1,
                endColumn: 1,
                text: 'a'
            }],
            'a',
            [
                new TestToken(0, 1)
            ]
        );
    }

    function testDeleteSecondToken2() {
        checkLineEditTokens(
            'abcdefghij',
            [
                new TestToken(0, 1),
                new TestToken(3, 2),
                new TestToken(6, 3)
            ],
            [{
                startColumn: 4,
                endColumn: 7,
                text: ''
            }],
            'abcghij',
            [
                new TestToken(0, 1),
                new TestToken(3, 3)
            ]
        );
    }

    function testInsertRightBeforeSecondToken() {
        checkLineEditTokens(
            'abcdefghij',
            [
                new TestToken(0, 1),
                new TestToken(3, 2),
                new TestToken(6, 3)
            ],
            [{
                startColumn: 4,
                endColumn: 4,
                text: 'hello'
            }],
            'abchellodefghij',
            [
                new TestToken(0, 1),
                new TestToken(8, 2),
                new TestToken(11, 3)
            ]
        );
    }

    function testDeleteFirstChar() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 1,
                endColumn: 2,
                text: ''
            }],
            'bcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(3, 2),
                new TestToken(4, 3)
            ]
        );
    }

    function testDelete2ndAnd3rdChars() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 2,
                endColumn: 4,
                text: ''
            }],
            'ad efgh',
            [
                new TestToken(0, 1),
                new TestToken(2, 2),
                new TestToken(3, 3)
            ]
        );
    }

    function testDeleteFirstToken() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 1,
                endColumn: 5,
                text: ''
            }],
            ' efgh',
            [
                new TestToken(0, 2),
                new TestToken(1, 3)
            ]
        );
    }

    function testDeleteSecondToken() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 5,
                endColumn: 6,
                text: ''
            }],
            'abcdefgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 3)
            ]
        );
    }

    function testDeleteSecondTokenABitOfTheThirdOne() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 5,
                endColumn: 7,
                text: ''
            }],
            'abcdfgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 3)
            ]
        );
    }

    function testDeleteSecondAndThirdToken() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 5,
                endColumn: 10,
                text: ''
            }],
            'abcd',
            [
                new TestToken(0, 1)
            ]
        );
    }

    function testDeleteEverything() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 1,
                endColumn: 10,
                text: ''
            }],
            '',
            [
                new TestToken(0, 1)
            ]
        );
    }

    function testNoop() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 1,
                endColumn: 1,
                text: ''
            }],
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ]
        );
    }

    function testEquivalentToDeletingFirstTwoChars() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 1,
                endColumn: 3,
                text: ''
            }],
            'cd efgh',
            [
                new TestToken(0, 1),
                new TestToken(2, 2),
                new TestToken(3, 3)
            ]
        );
    }

    function testEquivalentToDeletingFrom5ToTheEnd() {
        checkLineEditTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            [{
                startColumn: 5,
                endColumn: 10,
                text: ''
            }],
            'abcd',
            [
                new TestToken(0, 1)
            ]
        );
    }

    function testUpdatesTokensOnReplace1() {
        checkLineEditTokens(
            'Hello world, ciao',
            [
                new TestToken(0, 1),
                new TestToken(5, 0),
                new TestToken(6, 2),
                new TestToken(11, 0),
                new TestToken(13, 0)
            ],
            [{
                startColumn: 1,
                endColumn: 6,
                text: 'Hi'
            }],
            'Hi world, ciao',
            [
                new TestToken(0, 0),
                new TestToken(3, 2),
                new TestToken(8, 0),
                new TestToken(10, 0)
            ]
        );
    }

    function testUpdatesTokensOnReplace2() {
        checkLineEditTokens(
            'Hello world, ciao',
            [
                new TestToken(0, 1),
                new TestToken(5, 0),
                new TestToken(6, 2),
                new TestToken(11, 0),
                new TestToken(13, 0)
            ],
            [{
                startColumn: 1,
                endColumn: 6,
                text: 'Hi'
            }, {
                startColumn: 8,
                endColumn: 12,
                text: 'my friends'
            }],
            'Hi wmy friends, ciao',
            [
                new TestToken(0, 0),
                new TestToken(3, 2),
                new TestToken(14, 0),
                new TestToken(16, 0)
            ]
        );
    }

    function testSplitAtTheBeginning() {
        checkLineSplitTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            1,
            '',
            'abcd efgh',
            [
                new TestToken(0, 1)
            ]
        );
    }

    function testSplitAtTheEnd() {
        checkLineSplitTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            10,
            'abcd efgh',
            '',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ]
        );
    }

    function testSplitIntheMiddle1() {
        checkLineSplitTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            5,
            'abcd',
            ' efgh',
            [
                new TestToken(0, 1)
            ]
        );
    }

    function testSplitIntheMiddle2() {
        checkLineSplitTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            6,
            'abcd ',
            'efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2)
            ]
        );
    }

    function testAppendEmpty1() {
        checkLineAppendTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            '',
            [],
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ]
        );
    }

    function testAppendEmpty2() {
        checkLineAppendTokens(
            '',
            [],
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ]
        );
    }

    function testAppend1() {
        checkLineAppendTokens(
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ],
            'abcd efgh',
            [
                new TestToken(0, 4),
                new TestToken(4, 5),
                new TestToken(5, 6)
            ],
            'abcd efghabcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3),
                new TestToken(9, 4),
                new TestToken(13, 5),
                new TestToken(14, 6)
            ]
        );
    }

    function testAppend2() {
        checkLineAppendTokens(
            'abcd ',
            [
                new TestToken(0, 1),
                new TestToken(4, 2)
            ],
            'efgh',
            [
                new TestToken(0, 3)
            ],
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ]
        );
    }

    function testAppend3() {
        checkLineAppendTokens(
            'abcd',
            [
                new TestToken(0, 1)
            ],
            ' efgh',
            [
                new TestToken(0, 2),
                new TestToken(1, 3)
            ],
            'abcd efgh',
            [
                new TestToken(0, 1),
                new TestToken(4, 2),
                new TestToken(5, 3)
            ]
        );
    }
}
